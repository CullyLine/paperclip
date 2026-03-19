--[[
	HubController — Manages the Hub UI, queue state, and camera.

	Shows the Hub screen on load (no character, fixed camera),
	hides it during matches, and restores it on return.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local dmGui = StarterGui:WaitForChild("DMStarterGui")
local HubScreen = require(dmGui:WaitForChild("HubScreen"))

local hub: any = nil
local isInMatch = false
local isQueued = false

-- Fixed camera position for the Hub (looking at the skybox)
local HUB_CAMERA_CF = CFrame.new(0, 50, 0) * CFrame.Angles(math.rad(-15), 0, 0)

local function waitForRemoteEvent(name: string): RemoteEvent
	local event = ReplicatedStorage:WaitForChild(name, 15)
	if not event then
		warn("[HubController] RemoteEvent '" .. name .. "' not found")
	end
	return event :: RemoteEvent
end

-- ═══════════════════════════════════════════════════════════════════
-- HUB STATE
-- ═══════════════════════════════════════════════════════════════════

local function setHubCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = HUB_CAMERA_CF
end

local function restoreGameCamera()
	camera.CameraType = Enum.CameraType.Custom
end

local function refreshProgression()
	task.spawn(function()
		local remote = ReplicatedStorage:FindFirstChild("GetProgression")
		if not remote then
			remote = ReplicatedStorage:WaitForChild("GetProgression", 5)
		end
		if remote then
			local ok, data = pcall(function()
				return (remote :: RemoteFunction):InvokeServer()
			end)
			if ok and data and hub then
				hub:setProgression(data.level, data.xp, data.xpNeeded)
			end
		end
	end)
end

local function showHub()
	isInMatch = false
	isQueued = false

	if hub then
		hub:setVisible(true)
		hub:setPlayButtonQueued(false)
	end

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	setHubCamera()
	refreshProgression()
end

local function hideHub()
	isInMatch = true

	if hub then
		hub:setVisible(false)
	end

	restoreGameCamera()
end

-- ═══════════════════════════════════════════════════════════════════
-- BUTTON HANDLERS
-- ═══════════════════════════════════════════════════════════════════

local function showComingSoon()
	if hub then
		hub:showNotification("Coming Soon!")
	end
end

local function onPlayClicked()
	if isInMatch then return end

	isQueued = not isQueued

	if hub then
		hub:setPlayButtonQueued(isQueued)
		if isQueued then
			hub:showNotification("Queued for next round!")
		end
	end

	local playerQueueEvent = waitForRemoteEvent("PlayerQueue")
	if playerQueueEvent then
		playerQueueEvent:FireServer()
	end
end

local function setupButtonHandlers()
	if not hub then return end

	hub.buttons.Play.Activated:Connect(onPlayClicked)
	hub.buttons.PartyMode.Activated:Connect(showComingSoon)
	hub.buttons.Garage.Activated:Connect(showComingSoon)
	hub.buttons.Shop.Activated:Connect(showComingSoon)
	hub.buttons.Settings.Activated:Connect(showComingSoon)
end

-- ═══════════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════════

hub = HubScreen.new(playerGui)
setupButtonHandlers()
showHub()

-- Listen for queue updates (player list refresh)
local queueUpdateEvent = waitForRemoteEvent("QueueUpdate")
if queueUpdateEvent then
	queueUpdateEvent.OnClientEvent:Connect(function(playerList, queuedCount, totalCount, _serverState)
		if hub then
			hub:updatePlayerList(playerList, queuedCount, totalCount)
		end
	end)
end

-- Listen for match start (hide Hub, restore game camera)
local matchStartEvent = waitForRemoteEvent("MatchStart")
if matchStartEvent then
	matchStartEvent.OnClientEvent:Connect(hideHub)
end

-- Listen for return to Hub
local returnToHubEvent = waitForRemoteEvent("ReturnToHub")
if returnToHubEvent then
	returnToHubEvent.OnClientEvent:Connect(showHub)
end

-- Listen for character despawn (server tells us to go back to Hub camera)
local despawnEvent = waitForRemoteEvent("DespawnCharacter")
if despawnEvent then
	despawnEvent.OnClientEvent:Connect(function()
		setHubCamera()
	end)
end

return true
