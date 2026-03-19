--[[
	PreRoundServer — Server-side Pre-Round vehicle selection authority.

	M1: Players select from 3 vehicle types (all_rounder, speedster, tank).
	Validates unlock status via ProfileManager. Multiple players can pick
	the same vehicle type. Manages 10-second countdown and fires
	PreRound_Complete with final selections.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMReplicatedStorage = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local VehicleRegistry = require(DMReplicatedStorage:WaitForChild("VehicleRegistry"))

local COUNTDOWN_DURATION = 10

local validVehicleIds: { [string]: boolean } = {}
for _, id in VehicleRegistry.getVehicleIds() do
	validVehicleIds[id] = true
end

-- RemoteEvents
local function createRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then existing:Destroy() end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local selectVehicleEvent = createRemoteEvent("PreRound_SelectVehicle")
local confirmVehicleEvent = createRemoteEvent("PreRound_ConfirmVehicle")
local vehicleUpdateEvent = createRemoteEvent("PreRound_VehicleUpdate")
local preRoundStartEvent = createRemoteEvent("PreRound_Start")
local preRoundEndEvent = createRemoteEvent("PreRound_End")
local countdownEvent = createRemoteEvent("PreRound_Countdown")

-- State: playerId -> vehicleId
local playerSelections: { [number]: string } = {}
-- State: playerId -> true if confirmed
local confirmedPlayers: { [number]: boolean } = {}

local isPreRoundActive = false

local function getProfileManager()
	return _G.ProfileManager
end

local function broadcastSelections()
	local allVehicles = VehicleRegistry.getAll()
	vehicleUpdateEvent:FireAllClients(playerSelections, confirmedPlayers, allVehicles)
end

local function onSelectVehicle(player: Player, vehicleId: string?)
	if not isPreRoundActive then return end
	if confirmedPlayers[player.UserId] then return end

	if vehicleId == nil then
		playerSelections[player.UserId] = nil
		broadcastSelections()
		return
	end

	if type(vehicleId) ~= "string" then return end
	if not validVehicleIds[vehicleId] then return end

	local PM = getProfileManager()
	if PM and not PM.IsVehicleUnlocked(player, vehicleId) then
		return
	end

	playerSelections[player.UserId] = vehicleId
	broadcastSelections()
end

local function onConfirmVehicle(player: Player, vehicleId: string?)
	if not isPreRoundActive then return end
	if confirmedPlayers[player.UserId] then return end

	if type(vehicleId) ~= "string" then return end
	if not validVehicleIds[vehicleId] then return end

	if playerSelections[player.UserId] ~= vehicleId then return end

	local PM = getProfileManager()
	if PM and not PM.IsVehicleUnlocked(player, vehicleId) then
		return
	end

	confirmedPlayers[player.UserId] = true
	broadcastSelections()
end

local function assignDefaultVehicles()
	local defaultId = VehicleRegistry.getDefault().id
	for _, player in ipairs(Players:GetPlayers()) do
		if not confirmedPlayers[player.UserId] then
			if not playerSelections[player.UserId] then
				playerSelections[player.UserId] = defaultId
			end
			confirmedPlayers[player.UserId] = true
		end
	end
end

local function resetPreRoundState()
	playerSelections = {}
	confirmedPlayers = {}
	isPreRoundActive = false
end

local function getPlayerFinalSelections(): { [number]: string }
	local result: { [number]: string } = {}
	for playerId, vehicleId in pairs(playerSelections) do
		result[playerId] = vehicleId
	end
	return result
end

local function allPlayersConfirmed(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then return false end
	for _, player in ipairs(players) do
		if not confirmedPlayers[player.UserId] then
			return false
		end
	end
	return true
end

local function finishPreRound()
	if not isPreRoundActive then return end
	assignDefaultVehicles()
	broadcastSelections()

	task.wait(0.5)

	isPreRoundActive = false

	local finalSelections = getPlayerFinalSelections()
	preRoundEndEvent:FireAllClients()

	local preRoundComplete = ReplicatedStorage:FindFirstChild("PreRound_Complete")
	if not preRoundComplete then
		preRoundComplete = Instance.new("BindableEvent")
		preRoundComplete.Name = "PreRound_Complete"
		preRoundComplete.Parent = ReplicatedStorage
	end
	(preRoundComplete :: BindableEvent):Fire(finalSelections)
end

local function startPreRound()
	resetPreRoundState()
	isPreRoundActive = true

	-- Pre-select each player's saved vehicle preference
	local PM = getProfileManager()
	if PM then
		for _, player in ipairs(Players:GetPlayers()) do
			local saved = PM.GetSelectedVehicle(player)
			if saved and validVehicleIds[saved] and PM.IsVehicleUnlocked(player, saved) then
				playerSelections[player.UserId] = saved
			else
				playerSelections[player.UserId] = VehicleRegistry.getDefault().id
			end
		end
	end

	local allVehicles = VehicleRegistry.getAll()
	for _, p in ipairs(Players:GetPlayers()) do
		local level = if PM then PM.GetLevel(p) else 0
		preRoundStartEvent:FireClient(p, COUNTDOWN_DURATION, allVehicles, level)
	end

	for i = COUNTDOWN_DURATION, 1, -1 do
		if not isPreRoundActive then return end
		if allPlayersConfirmed() then
			finishPreRound()
			return
		end
		countdownEvent:FireAllClients(i)
		task.wait(1)
	end

	if not isPreRoundActive then return end
	finishPreRound()
end

selectVehicleEvent.OnServerEvent:Connect(onSelectVehicle)
confirmVehicleEvent.OnServerEvent:Connect(onConfirmVehicle)

Players.PlayerRemoving:Connect(function(player)
	if isPreRoundActive then
		playerSelections[player.UserId] = nil
		confirmedPlayers[player.UserId] = nil
		broadcastSelections()
	end
end)

local startPreRoundEvent = ReplicatedStorage:FindFirstChild("StartPreRound")
if not startPreRoundEvent then
	startPreRoundEvent = Instance.new("BindableEvent")
	startPreRoundEvent.Name = "StartPreRound"
	startPreRoundEvent.Parent = ReplicatedStorage
end

(startPreRoundEvent :: BindableEvent).Event:Connect(function()
	startPreRound()
end)
