--[[
	MatchManager.server.luau — Server-local game loop manager.

	Every Roblox server is its own lobby. Players join the server,
	see the Hub UI, and click "Play" to queue for the next round.
	Rounds loop automatically for queued players.

	State machine:  idle → pre_round → racing → results → (loop)

	- idle:      Waiting for players to click Play. Map not loaded.
	- pre_round: Map built, vehicle selection countdown running.
	- racing:    Race active (120s max).
	- results:   30s results/ready-up screen, then loops or goes idle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local MAX_PLAYERS = 16
local QUEUE_DELAY = 3
local RESULTS_DURATION = 30

local STATES = {
	Idle = "idle",
	PreRound = "pre_round",
	Racing = "racing",
	Results = "results",
}

-- ═══════════════════════════════════════════════════════════════════
-- REMOTE & BINDABLE EVENTS
-- ═══════════════════════════════════════════════════════════════════

local function ensureRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local function ensureBindableEvent(name: string): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing :: BindableEvent end
	local bindable = Instance.new("BindableEvent")
	bindable.Name = name
	bindable.Parent = ReplicatedStorage
	return bindable
end

-- Client <-> Server
local playerQueueEvent = ensureRemoteEvent("PlayerQueue")
local queueUpdateEvent = ensureRemoteEvent("QueueUpdate")
local matchStartEvent = ensureRemoteEvent("MatchStart")
local returnToHubEvent = ensureRemoteEvent("ReturnToHub")
local stateChangedEvent = ensureRemoteEvent("LobbyStateChanged")
local readyUpEvent = ensureRemoteEvent("ReadyUp")
local returnToHubRequestEvent = ensureRemoteEvent("ReturnToHubRequest")
local spectatorAssignEvent = ensureRemoteEvent("SpectatorAssign")
local despawnCharacterEvent = ensureRemoteEvent("DespawnCharacter")

-- Server-internal
local startPreRoundEvent = ensureBindableEvent("StartPreRound")
local preRoundCompleteEvent = ensureBindableEvent("PreRound_Complete")
local startRaceEvent = ensureBindableEvent("StartRace")
local raceEndEvent = ensureBindableEvent("RaceEnd_Server")
local showResultsEvent = ensureRemoteEvent("RaceEnd")

-- ═══════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════

local currentState = STATES.Idle
local queuedPlayers: { [number]: boolean } = {}
local racingPlayers: { [number]: boolean } = {}
local playerVehicleSelections: { [number]: string } = {}
local roundNumber = 0
local queueThread: thread? = nil
local resultsThread: thread? = nil

-- ═══════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════

local function getQueuedPlayerList(): { Player }
	local result = {}
	for userId, _ in queuedPlayers do
		local player = Players:GetPlayerByUserId(userId)
		if player and player:IsDescendantOf(Players) then
			table.insert(result, player)
		end
	end
	return result
end

local function getQueuedCount(): number
	local count = 0
	for userId, _ in queuedPlayers do
		local player = Players:GetPlayerByUserId(userId)
		if player and player:IsDescendantOf(Players) then
			count += 1
		end
	end
	return count
end

local function getRacingPlayerList(): { Player }
	local result = {}
	for userId, _ in racingPlayers do
		local player = Players:GetPlayerByUserId(userId)
		if player and player:IsDescendantOf(Players) then
			table.insert(result, player)
		end
	end
	return result
end

type PlayerInfo = {
	userId: number,
	name: string,
	status: string, -- "hub" | "queued" | "racing" | "spectating"
}

local function buildPlayerList(): { PlayerInfo }
	local list: { PlayerInfo } = {}
	for _, player in Players:GetPlayers() do
		local status = "hub"
		if racingPlayers[player.UserId] then
			status = "racing"
		elseif queuedPlayers[player.UserId] then
			status = "queued"
		end
		table.insert(list, {
			userId = player.UserId,
			name = player.DisplayName,
			status = status,
		})
	end
	return list
end

local function broadcastQueueUpdate()
	local playerList = buildPlayerList()
	local qCount = getQueuedCount()
	local totalCount = #Players:GetPlayers()
	queueUpdateEvent:FireAllClients(playerList, qCount, totalCount, currentState)
end

local function broadcastState(newState: string)
	currentState = newState
	stateChangedEvent:FireAllClients(newState)
	broadcastQueueUpdate()
end

local function despawnCharacter(player: Player)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
	despawnCharacterEvent:FireClient(player)
end

-- ═══════════════════════════════════════════════════════════════════
-- STATE MACHINE
-- ═══════════════════════════════════════════════════════════════════

local function startPreRound()
	if currentState ~= STATES.Idle then return end

	local players = getQueuedPlayerList()
	if #players == 0 then return end

	roundNumber += 1
	broadcastState(STATES.PreRound)

	local biomeId = MapBuilder.getNextBiome()
	MapBuilder.build(biomeId)

	-- Move queued players into racing set
	racingPlayers = {}
	for _, player in players do
		racingPlayers[player.UserId] = true
	end
	queuedPlayers = {}

	broadcastQueueUpdate()

	startPreRoundEvent:Fire()
end

local function tryStartQueue()
	if currentState ~= STATES.Idle then return end
	if getQueuedCount() == 0 then return end
	if queueThread then return end

	queueThread = task.spawn(function()
		task.wait(QUEUE_DELAY)
		queueThread = nil

		if currentState ~= STATES.Idle then return end
		if getQueuedCount() == 0 then return end

		startPreRound()
	end)
end

local function onPreRoundComplete(finalSelections: { [number]: string })
	if currentState ~= STATES.PreRound then return end

	playerVehicleSelections = finalSelections
	broadcastState(STATES.Racing)

	local players = getRacingPlayerList()
	matchStartEvent:FireAllClients()

	startRaceEvent:Fire(players, playerVehicleSelections)
end

local function onRaceEnd(raceResults: any?)
	if currentState ~= STATES.Racing then return end

	broadcastState(STATES.Results)

	-- Unload every racing player's character so they don't fall through the world when the map is removed
	for _, player in getRacingPlayerList() do
		despawnCharacter(player)
	end

	MapBuilder.cleanup()

	showResultsEvent:FireAllClients(raceResults)

	-- Reset racing players — they go back to hub unless they ready up
	local readiedPlayers: { [number]: boolean } = {}

	resultsThread = task.spawn(function()
		local elapsed = 0
		while elapsed < RESULTS_DURATION do
			task.wait(1)
			elapsed += 1

			if currentState ~= STATES.Results then return end

			-- Check if all remaining players are ready
			local allReady = true
			local count = 0
			for userId, _ in racingPlayers do
				local player = Players:GetPlayerByUserId(userId)
				if player and player:IsDescendantOf(Players) then
					count += 1
					if not readiedPlayers[userId] then
						allReady = false
					end
				end
			end

			if count > 0 and allReady then
				break
			end
		end

		if currentState ~= STATES.Results then return end
		resultsThread = nil

		-- Players who readied up get queued for next round
		for userId, _ in readiedPlayers do
			local player = Players:GetPlayerByUserId(userId)
			if player and player:IsDescendantOf(Players) then
				queuedPlayers[userId] = true
			end
		end

		-- Players who didn't ready up go back to Hub
		for userId, _ in racingPlayers do
			if not readiedPlayers[userId] then
				local player = Players:GetPlayerByUserId(userId)
				if player and player:IsDescendantOf(Players) then
					returnToHubEvent:FireClient(player)
					despawnCharacter(player)
				end
			end
		end

		racingPlayers = {}
		playerVehicleSelections = {}

		broadcastState(STATES.Idle)

		-- Auto-start next round if anyone queued
		if getQueuedCount() > 0 then
			tryStartQueue()
		end
	end)

	-- Wire up ready-up handler for this results phase
	local readyConnection: RBXScriptConnection? = nil
	readyConnection = readyUpEvent.OnServerEvent:Connect(function(player: Player)
		if currentState ~= STATES.Results then
			if readyConnection then readyConnection:Disconnect() end
			return
		end

		if racingPlayers[player.UserId] then
			readiedPlayers[player.UserId] = true
			broadcastQueueUpdate()
		end
	end)

	-- Clean up connection when we leave results
	task.spawn(function()
		while currentState == STATES.Results do
			task.wait(0.5)
		end
		if readyConnection then readyConnection:Disconnect() end
	end)
end

-- ═══════════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════

local function onPlayerQueue(player: Player)
	if queuedPlayers[player.UserId] then
		-- Toggle off — unqueue
		queuedPlayers[player.UserId] = nil
		broadcastQueueUpdate()
		return
	end

	if racingPlayers[player.UserId] then return end

	if getQueuedCount() >= MAX_PLAYERS then
		return
	end

	queuedPlayers[player.UserId] = true
	broadcastQueueUpdate()

	tryStartQueue()
end

local function onReturnToHubRequest(player: Player)
	queuedPlayers[player.UserId] = nil
	racingPlayers[player.UserId] = nil

	returnToHubEvent:FireClient(player)
	despawnCharacter(player)
	broadcastQueueUpdate()
end

local function onPlayerAdded(player: Player)
	despawnCharacter(player)

	stateChangedEvent:FireClient(player, currentState)
	broadcastQueueUpdate()
end

local function onPlayerRemoving(player: Player)
	queuedPlayers[player.UserId] = nil
	racingPlayers[player.UserId] = nil
	broadcastQueueUpdate()
end

-- ═══════════════════════════════════════════════════════════════════
-- WIRE UP
-- ═══════════════════════════════════════════════════════════════════

playerQueueEvent.OnServerEvent:Connect(onPlayerQueue)
returnToHubRequestEvent.OnServerEvent:Connect(onReturnToHubRequest)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in the server (if script loads late)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

preRoundCompleteEvent.Event:Connect(onPreRoundComplete)
raceEndEvent.Event:Connect(onRaceEnd)

_G.MatchManager = {
	getState = function() return currentState end,
	getRacingPlayers = getRacingPlayerList,
	STATES = STATES,
}

print("[MatchManager] Initialized — server-local lobby ready")
