--[[
	PreRoundController — M1 client-side vehicle selection logic.

	Receives vehicle registry data + player level from server via
	PreRound_Start. Shows 3 vehicle type cards with stats/lock state.
	Syncs selection with server via RemoteEvents.
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

local cachedVehicles: { any } = {}
local cachedPlayerLevel: number = 0

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

local function refreshAllCardStates()
	if not screen then return end
	for _, vData in cachedVehicles do
		local isUnlocked = vData.unlockLevel <= cachedPlayerLevel
		if vData.id == selectedVehicle then
			screen:setVehicleState(vData.id, "selected")
		elseif not isUnlocked then
			screen:setVehicleState(vData.id, "locked")
		else
			screen:setVehicleState(vData.id, "available")
		end
	end
end

local function loadVehicleTemplate(vehicleId: string): Model?
	local templates = ReplicatedStorage:FindFirstChild("VehicleTemplates")
	if not templates then
		templates = ReplicatedStorage:WaitForChild("VehicleTemplates", 5)
	end
	if not templates then return nil end

	local template = templates:FindFirstChild("Template_" .. vehicleId)
	if not template then
		template = templates:FindFirstChild("TemplateVehicle")
	end
	return template :: Model?
end

local function selectVehicle(vehicleId: string)
	if isConfirmed then return end

	-- Check unlock
	local isUnlocked = false
	for _, vData in cachedVehicles do
		if vData.id == vehicleId then
			isUnlocked = vData.unlockLevel <= cachedPlayerLevel
			break
		end
	end
	if not isUnlocked then return end

	-- Toggle deselect
	if vehicleId == selectedVehicle then
		selectedVehicle = nil
		screen:setVehicleModel(nil)
		screen:setConfirmEnabled(false)
		screen.vehicleNameLabel.Visible = false
		screen.vehicleTaglineLabel.Visible = false
		screen.vehicleDescLabel.Visible = false
		refreshAllCardStates()
		if selectVehicleRemote then
			selectVehicleRemote:FireServer(nil)
		end
		return
	end

	selectedVehicle = vehicleId
	refreshAllCardStates()
	screen:setConfirmEnabled(true)

	-- Show vehicle info
	for _, vData in cachedVehicles do
		if vData.id == vehicleId then
			screen:setVehicleInfo(vData.displayName, vData.tagline, vData.description)
			break
		end
	end

	-- Load 3D preview
	local template = loadVehicleTemplate(vehicleId)
	if template then
		screen:setVehicleModel(template)
	end

	if selectVehicleRemote then
		selectVehicleRemote:FireServer(vehicleId)
	end
end

local function confirmSelection()
	if isConfirmed or not selectedVehicle then return end

	isConfirmed = true
	screen:setConfirmEnabled(false)
	screen.confirmButton.Text = "CONFIRMED"

	if confirmVehicleRemote then
		confirmVehicleRemote:FireServer(selectedVehicle)
	end
end

local function onVehicleUpdate(selections: { [string]: number }, confirmed: { [number]: boolean }, vehicles: { any }?)
	if vehicles and #vehicles > 0 then
		cachedVehicles = vehicles
	end
	refreshAllCardStates()
end

local function onPreRoundStart(duration: number, vehicles: { any }, playerLevel: number?)
	selectedVehicle = nil
	isConfirmed = false
	countdownActive = true
	countdownRemaining = duration or 10

	if vehicles then
		cachedVehicles = vehicles
	end
	cachedPlayerLevel = playerLevel or 0

	if not screen then
		screen = PreRoundScreen.new(playerGui)
		screen.onVehicleSelected.Event:Connect(selectVehicle)
		screen.onConfirm.Event:Connect(confirmSelection)
	end

	screen.confirmButton.Text = "CONFIRM"
	screen:setConfirmEnabled(false)
	screen:setVehicleModel(nil)
	screen.vehicleNameLabel.Visible = false
	screen.vehicleTaglineLabel.Visible = false
	screen.vehicleDescLabel.Visible = false
	screen:buildCards(cachedVehicles, cachedPlayerLevel)
	screen:setCountdown(countdownRemaining)
	screen:setVisible(true)

	-- Auto-select saved preference if server pre-selected for us
	-- The server fires VehicleUpdate shortly after Start with pre-selections
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
