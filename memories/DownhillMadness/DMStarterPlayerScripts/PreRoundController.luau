--[[
	PreRoundController — Client-side logic for the Pre-Round vehicle selection.

	Listens for server signals to show/hide the selection screen, manages
	local selection state, syncs with server via RemoteEvents, and handles
	the 10-second countdown + confirm flow.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StarterGui = game:GetService("StarterGui")
local dmGui = StarterGui:WaitForChild("DMStarterGui")
local PreRoundScreen = require(dmGui:WaitForChild("PreRoundScreen"))

local screen: any = nil
local selectedVehicle: string? = nil
local isConfirmed = false
local countdownActive = false
local countdownRemaining = 10

-- Tracks which vehicles are taken by other players: vehicleName -> playerId
local takenVehicles: { [string]: number } = {}

local function waitForRemote(name: string, class: string): any
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = ReplicatedStorage:WaitForChild(name, 10)
	end
	return remote
end

local selectVehicleRemote: RemoteEvent = nil :: any
local confirmVehicleRemote: RemoteEvent = nil :: any
local vehicleUpdateRemote: RemoteEvent = nil :: any
local preRoundStartRemote: RemoteEvent = nil :: any
local preRoundEndRemote: RemoteEvent = nil :: any
local preRoundCountdownRemote: RemoteEvent = nil :: any

local function refreshAllCellStates()
	if not screen then return end
	for _, vehicleName in ipairs(PreRoundScreen.VEHICLE_NAMES) do
		if vehicleName == selectedVehicle then
			screen:setVehicleState(vehicleName, "selected")
		elseif takenVehicles[vehicleName] then
			screen:setVehicleState(vehicleName, "taken")
		else
			screen:setVehicleState(vehicleName, "available")
		end
	end
end

local function loadTemplateModel(): Model?
	local template = ReplicatedStorage:FindFirstChild("TemplateVehicle")
	if not template then
		template = ReplicatedStorage:WaitForChild("TemplateVehicle", 5)
	end
	return template :: Model?
end

local function selectVehicle(vehicleName: string)
	if isConfirmed then return end

	-- Check if vehicle is taken
	if takenVehicles[vehicleName] and takenVehicles[vehicleName] ~= player.UserId then
		return
	end

	-- If re-selecting the same vehicle, deselect
	if vehicleName == selectedVehicle then
		selectedVehicle = nil
		screen:setVehicleModel(nil)
		screen:setConfirmEnabled(false)
		refreshAllCellStates()
		if selectVehicleRemote then
			selectVehicleRemote:FireServer(nil)
		end
		return
	end

	selectedVehicle = vehicleName
	refreshAllCellStates()
	screen:setConfirmEnabled(true)

	-- Load 3D preview
	local template = loadTemplateModel()
	if template then
		screen:setVehicleModel(template)
	end

	-- Notify server
	if selectVehicleRemote then
		selectVehicleRemote:FireServer(vehicleName)
	end
end

local function confirmSelection()
	if isConfirmed or not selectedVehicle then return end

	-- Check vehicle is still available
	if takenVehicles[selectedVehicle] and takenVehicles[selectedVehicle] ~= player.UserId then
		selectedVehicle = nil
		screen:setVehicleModel(nil)
		screen:setConfirmEnabled(false)
		refreshAllCellStates()
		return
	end

	isConfirmed = true
	screen:setConfirmEnabled(false)
	screen.confirmButton.Text = "CONFIRMED ✓"

	if confirmVehicleRemote then
		confirmVehicleRemote:FireServer(selectedVehicle)
	end
end

local function onVehicleUpdate(selections: { [string]: number }, confirmed: { [number]: boolean })
	takenVehicles = {}
	for vehicleName, playerId in pairs(selections) do
		if playerId ~= player.UserId then
			takenVehicles[vehicleName] = playerId
		end
	end

	-- If our selected vehicle was taken by someone else, clear it
	if selectedVehicle and takenVehicles[selectedVehicle] then
		selectedVehicle = nil
		if screen then
			screen:setVehicleModel(nil)
			screen:setConfirmEnabled(false)
		end
	end

	refreshAllCellStates()
end

local function onPreRoundStart(duration: number)
	-- Reset state for new round
	selectedVehicle = nil
	isConfirmed = false
	countdownActive = true
	countdownRemaining = duration or 10
	takenVehicles = {}

	if not screen then
		screen = PreRoundScreen.new(playerGui)
		screen.onVehicleSelected.Event:Connect(selectVehicle)
		screen.onConfirm.Event:Connect(confirmSelection)
	end

	screen.confirmButton.Text = "CONFIRM"
	screen:setConfirmEnabled(false)
	screen:setVehicleModel(nil)
	screen:setCountdown(countdownRemaining)
	refreshAllCellStates()
	screen:setVisible(true)
end

local function onPreRoundEnd()
	countdownActive = false
	if screen then
		screen:setVisible(false)
	end
end

local function onCountdownTick(remaining: number)
	countdownRemaining = remaining
	if screen then
		screen:setCountdown(remaining)
	end
end

-- Wire up remote events
task.spawn(function()
	selectVehicleRemote = waitForRemote("PreRound_SelectVehicle", "RemoteEvent") :: RemoteEvent
	confirmVehicleRemote = waitForRemote("PreRound_ConfirmVehicle", "RemoteEvent") :: RemoteEvent
	vehicleUpdateRemote = waitForRemote("PreRound_VehicleUpdate", "RemoteEvent") :: RemoteEvent
	preRoundStartRemote = waitForRemote("PreRound_Start", "RemoteEvent") :: RemoteEvent
	preRoundEndRemote = waitForRemote("PreRound_End", "RemoteEvent") :: RemoteEvent
	preRoundCountdownRemote = waitForRemote("PreRound_Countdown", "RemoteEvent") :: RemoteEvent

	if vehicleUpdateRemote then
		vehicleUpdateRemote.OnClientEvent:Connect(onVehicleUpdate)
	end

	if preRoundStartRemote then
		preRoundStartRemote.OnClientEvent:Connect(onPreRoundStart)
	end

	if preRoundEndRemote then
		preRoundEndRemote.OnClientEvent:Connect(onPreRoundEnd)
	end

	if preRoundCountdownRemote then
		preRoundCountdownRemote.OnClientEvent:Connect(onCountdownTick)
	end
end)


return true
