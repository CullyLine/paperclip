--[[
	PreRoundServer — Server-side Pre-Round vehicle selection authority.

	Creates RemoteEvents, validates exclusivity (one vehicle per player),
	manages the 10-second countdown, and assigns random vehicles to
	unconfirmed players when the timer expires.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COUNTDOWN_DURATION = 10

local VEHICLE_NAMES = {
	"Roadster", "Cruiser", "Hauler", "Speedster", "Buggy",
	"Rally", "Muscle", "Compact", "Pickup", "SUV",
	"Racer", "Drifter", "Offroad", "Sedan", "Coupe",
	"Hatchback", "Minivan", "Jeep", "Wagon", "Hotrod",
}

local validVehicleSet: { [string]: boolean } = {}
for _, name in ipairs(VEHICLE_NAMES) do
	validVehicleSet[name] = true
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

-- State: vehicleName -> playerId (who currently has it selected/confirmed)
local currentSelections: { [string]: number } = {}
-- State: playerId -> vehicleName (reverse lookup)
local playerSelections: { [number]: string } = {}
-- State: playerId -> true if confirmed
local confirmedPlayers: { [number]: boolean } = {}

local isPreRoundActive = false

local function getAvailableVehicles(): { string }
	local available = {}
	for _, name in ipairs(VEHICLE_NAMES) do
		if not currentSelections[name] then
			table.insert(available, name)
		end
	end
	return available
end

local function broadcastSelections()
	vehicleUpdateEvent:FireAllClients(currentSelections, confirmedPlayers)
end

local function releasePlayerSelection(playerId: number)
	local currentVehicle = playerSelections[playerId]
	if currentVehicle then
		if currentSelections[currentVehicle] == playerId then
			currentSelections[currentVehicle] = nil
		end
		playerSelections[playerId] = nil
	end
end

local function onSelectVehicle(player: Player, vehicleName: string?)
	if not isPreRoundActive then return end
	if confirmedPlayers[player.UserId] then return end

	-- Deselection
	if vehicleName == nil then
		releasePlayerSelection(player.UserId)
		broadcastSelections()
		return
	end

	if type(vehicleName) ~= "string" then return end
	if not validVehicleSet[vehicleName] then return end

	-- Check if vehicle is taken by another player
	local currentOwner = currentSelections[vehicleName]
	if currentOwner and currentOwner ~= player.UserId then
		return
	end

	-- Release previous selection
	releasePlayerSelection(player.UserId)

	-- Assign new selection
	currentSelections[vehicleName] = player.UserId
	playerSelections[player.UserId] = vehicleName

	broadcastSelections()
end

local function onConfirmVehicle(player: Player, vehicleName: string?)
	if not isPreRoundActive then return end
	if confirmedPlayers[player.UserId] then return end

	if type(vehicleName) ~= "string" then return end
	if not validVehicleSet[vehicleName] then return end

	-- Must have this vehicle currently selected
	local currentVehicle = playerSelections[player.UserId]
	if currentVehicle ~= vehicleName then return end

	-- Verify ownership
	if currentSelections[vehicleName] ~= player.UserId then return end

	confirmedPlayers[player.UserId] = true
	broadcastSelections()
end

local function assignRandomVehicles()
	for _, player in ipairs(Players:GetPlayers()) do
		if not confirmedPlayers[player.UserId] then
			local available = getAvailableVehicles()
			if #available > 0 then
				local randomIndex = math.random(1, #available)
				local vehicleName = available[randomIndex]

				releasePlayerSelection(player.UserId)
				currentSelections[vehicleName] = player.UserId
				playerSelections[player.UserId] = vehicleName
				confirmedPlayers[player.UserId] = true
			end
		end
	end
end

local function resetPreRoundState()
	currentSelections = {}
	playerSelections = {}
	confirmedPlayers = {}
	isPreRoundActive = false
end

local function getPlayerFinalSelections(): { [number]: string }
	local result: { [number]: string } = {}
	for playerId, vehicleName in pairs(playerSelections) do
		result[playerId] = vehicleName
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
	-- Assign random vehicles to any unconfirmed players
	assignRandomVehicles()
	broadcastSelections()

	-- Small delay so clients can see final state
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

	preRoundStartEvent:FireAllClients(COUNTDOWN_DURATION)

	-- Countdown loop; exit early if everyone confirms
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

-- Wire up remote event listeners
selectVehicleEvent.OnServerEvent:Connect(onSelectVehicle)
confirmVehicleEvent.OnServerEvent:Connect(onConfirmVehicle)

-- Clean up when a player leaves during pre-round
Players.PlayerRemoving:Connect(function(player)
	if isPreRoundActive then
		releasePlayerSelection(player.UserId)
		confirmedPlayers[player.UserId] = nil
		broadcastSelections()
	end
end)

-- Listen for pre-round trigger from MatchManager or other systems
local startPreRoundEvent = ReplicatedStorage:FindFirstChild("StartPreRound")
if not startPreRoundEvent then
	startPreRoundEvent = Instance.new("BindableEvent")
	startPreRoundEvent.Name = "StartPreRound"
	startPreRoundEvent.Parent = ReplicatedStorage
end

(startPreRoundEvent :: BindableEvent).Event:Connect(function()
	startPreRound()
end)
