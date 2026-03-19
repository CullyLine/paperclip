--[[
	RoundController.server.luau — Manages race lifecycle within a lobby.

	M1: Passes vehicle selections to VehicleSpawner and awards XP at race end.

	Listens for StartRace BindableEvent from MatchManager, then:
	  1. Spawns vehicles via VehicleSpawner (with per-player vehicle types)
	  2. Runs 3-2-1-GO countdown
	  3. Unlocks vehicles on GO
	  4. Tracks progress % per player
	  5. Detects finishes via FinishZone Touched event
	  6. Ends race when all finish OR 120s timer expires
	  7. Awards XP via ProfileManager
	  8. Fires RaceEnd_Server BindableEvent with results
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VehicleSpawner = require(script.Parent:WaitForChild("VehicleSpawner"))

local COUNTDOWN_SECONDS = 3
local RACE_DURATION = 120

-- XP awards
local XP_BASE = 50
local XP_PLACEMENT_MULTIPLIER = { [1] = 3.0, [2] = 2.0, [3] = 1.5 }
local XP_FINISH_BONUS = 25

-- ═══════════════════════════════════════════════════════════════════
-- EVENTS
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

local countdownEvent = ensureRemoteEvent("CountdownUpdate")
local raceStartEvent = ensureRemoteEvent("RaceStart")
local raceEndClientEvent = ensureRemoteEvent("RaceEnd")
local progressUpdateEvent = ensureRemoteEvent("ProgressUpdate")
local xpAwardEvent = ensureRemoteEvent("XPAward")

local startRaceBindable = ensureBindableEvent("StartRace")
local raceEndServerBindable = ensureBindableEvent("RaceEnd_Server")

-- ═══════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════

type PlayerResult = {
	player: Player,
	userId: number,
	playerName: string,
	finishTime: number?,
	progress: number,
	placement: number,
	xpAwarded: number?,
}

local isRaceActive = false
local raceStartTime = 0
local racePlayers: { Player } = {}
local playerProgress: { [number]: number } = {}
local playerFinishTimes: { [number]: number } = {}
local finishedPlayers: { [number]: boolean } = {}
local finishConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil

local startY = 0
local finishY = 0

-- ═══════════════════════════════════════════════════════════════════
-- MAP GEOMETRY HELPERS
-- ═══════════════════════════════════════════════════════════════════

local function calculateStartFinishY()
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return end

	local startZone = mapFolder:FindFirstChild("StartZone")
	local finishZone = mapFolder:FindFirstChild("FinishZone")

	if startZone then
		local platform = startZone:FindFirstChild("StartPlatform")
		if platform and platform:IsA("BasePart") then
			startY = platform.Position.Y
		end
	end

	if finishZone then
		local platform = finishZone:FindFirstChild("FinishPlatform")
		if platform and platform:IsA("BasePart") then
			finishY = platform.Position.Y
		end
	end
end

local function calculateProgress(vehicleY: number): number
	if startY == finishY then return 0 end
	local raw = (startY - vehicleY) / (startY - finishY)
	return math.clamp(raw * 100, 0, 100)
end

-- ═══════════════════════════════════════════════════════════════════
-- FINISH DETECTION
-- ═══════════════════════════════════════════════════════════════════

local function setupFinishDetection()
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return end

	local finishZone = mapFolder:FindFirstChild("FinishZone")
	if not finishZone then return end

	local finishPlatform = finishZone:FindFirstChild("FinishPlatform")
	if not finishPlatform or not finishPlatform:IsA("BasePart") then return end

	finishConnection = finishPlatform.Touched:Connect(function(hit: BasePart)
		if not isRaceActive then return end

		local vehicleModel = hit.Parent
		if not vehicleModel then return end

		while vehicleModel and not string.find(vehicleModel.Name, "Vehicle_") do
			vehicleModel = vehicleModel.Parent :: Instance
			if vehicleModel == workspace then
				vehicleModel = nil
				break
			end
		end

		if not vehicleModel then return end

		for _, player in racePlayers do
			if vehicleModel.Name == "Vehicle_" .. player.Name then
				if not finishedPlayers[player.UserId] then
					finishedPlayers[player.UserId] = true
					playerFinishTimes[player.UserId] = tick() - raceStartTime
					playerProgress[player.UserId] = 100
				end
				break
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════
-- PROGRESS TRACKING
-- ═══════════════════════════════════════════════════════════════════

local function updateProgress()
	for _, player in racePlayers do
		if finishedPlayers[player.UserId] then continue end
		if not player:IsDescendantOf(Players) then continue end

		local sv = VehicleSpawner.getVehicleForPlayer(player)
		if sv and sv.chassis and sv.chassis.Parent then
			local progress = calculateProgress(sv.chassis.Position.Y)
			playerProgress[player.UserId] = progress
		end
	end
end

local function buildLeaderboard(): { { userId: number, name: string, progress: number, finishTime: number? } }
	local entries = {}
	for _, player in racePlayers do
		table.insert(entries, {
			userId = player.UserId,
			name = player.Name,
			progress = playerProgress[player.UserId] or 0,
			finishTime = playerFinishTimes[player.UserId],
		})
	end

	table.sort(entries, function(a, b)
		if a.finishTime and b.finishTime then
			return a.finishTime < b.finishTime
		end
		if a.finishTime then return true end
		if b.finishTime then return false end
		return a.progress > b.progress
	end)

	return entries
end

local function broadcastProgress()
	local leaderboard = buildLeaderboard()
	for _, player in racePlayers do
		if player:IsDescendantOf(Players) then
			progressUpdateEvent:FireClient(player, leaderboard, playerProgress[player.UserId] or 0)
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════
-- XP AWARD
-- ═══════════════════════════════════════════════════════════════════

local function awardXP(results: { PlayerResult })
	local PM = _G.ProfileManager
	if not PM then return end

	for _, result in results do
		if not result.player or not result.player:IsDescendantOf(Players) then continue end

		local xp = XP_BASE
		local multiplier = XP_PLACEMENT_MULTIPLIER[result.placement] or 1.0
		xp = math.floor(xp * multiplier)

		if result.finishTime then
			xp = xp + XP_FINISH_BONUS
		end

		result.xpAwarded = xp

		local awardResult = PM.AwardXP(result.player, xp)
		PM.RecordRace(result.player, result.placement, result.finishTime ~= nil)

		xpAwardEvent:FireClient(result.player, {
			xpGained = xp,
			placement = result.placement,
			leveledUp = awardResult.leveledUp,
			newLevel = awardResult.newLevel,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════════
-- RACE LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════

local function buildFinalResults(): { PlayerResult }
	local leaderboard = buildLeaderboard()
	local results: { PlayerResult } = {}

	for i, entry in leaderboard do
		local player: Player? = nil
		for _, p in racePlayers do
			if p.UserId == entry.userId then
				player = p
				break
			end
		end

		table.insert(results, {
			player = player :: any,
			userId = entry.userId,
			playerName = entry.name,
			finishTime = entry.finishTime,
			progress = entry.progress,
			placement = i,
			xpAwarded = 0,
		})
	end

	return results
end

local function endRace()
	if not isRaceActive then return end
	isRaceActive = false

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if finishConnection then
		finishConnection:Disconnect()
		finishConnection = nil
	end

	local results = buildFinalResults()

	awardXP(results)

	VehicleSpawner.cleanup()

	raceEndServerBindable:Fire(results)
end

local function checkAllFinished(): boolean
	for _, player in racePlayers do
		if player:IsDescendantOf(Players) and not finishedPlayers[player.UserId] then
			return false
		end
	end
	return true
end

local function startRace(players: { Player }, playerVehicles: { [number]: string })
	if isRaceActive then return end

	calculateStartFinishY()

	racePlayers = players
	playerProgress = {}
	playerFinishTimes = {}
	finishedPlayers = {}

	for _, player in racePlayers do
		playerProgress[player.UserId] = 0
	end

	local spawnedVehicles = VehicleSpawner.spawnVehicles(racePlayers, playerVehicles)
	if #spawnedVehicles == 0 then
		warn("[RoundController] No vehicles spawned, aborting race")
		return
	end

	VehicleSpawner.lockAll()

	for i = COUNTDOWN_SECONDS, 1, -1 do
		for _, player in racePlayers do
			if player:IsDescendantOf(Players) then
				countdownEvent:FireClient(player, i)
			end
		end
		task.wait(1)
	end

	for _, player in racePlayers do
		if player:IsDescendantOf(Players) then
			countdownEvent:FireClient(player, 0)
		end
	end

	VehicleSpawner.unlockAll()

	isRaceActive = true
	raceStartTime = tick()

	for _, player in racePlayers do
		if player:IsDescendantOf(Players) then
			raceStartEvent:FireClient(player, RACE_DURATION)
		end
	end

	setupFinishDetection()

	local lastBroadcast = 0
	local BROADCAST_INTERVAL = 0.5

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not isRaceActive then return end

		local elapsed = tick() - raceStartTime

		updateProgress()

		if elapsed - lastBroadcast >= BROADCAST_INTERVAL then
			lastBroadcast = elapsed
			broadcastProgress()
		end

		if checkAllFinished() then
			endRace()
			return
		end

		if elapsed >= RACE_DURATION then
			endRace()
			return
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════
-- WIRE UP
-- ═══════════════════════════════════════════════════════════════════

startRaceBindable.Event:Connect(startRace)

Players.PlayerRemoving:Connect(function(player: Player)
	if not isRaceActive then return end

	local sv = VehicleSpawner.getVehicleForPlayer(player)
	if sv and sv.model and sv.model.Parent then
		sv.model:Destroy()
	end

	if checkAllFinished() then
		endRace()
	end
end)

print("[RoundController] Initialized — waiting for StartRace event")
