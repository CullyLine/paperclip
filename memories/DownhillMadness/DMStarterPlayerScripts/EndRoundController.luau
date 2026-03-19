--[[
	EndRoundController.client.luau — Handles end-of-round UI logic.

	Listens for RaceEnd RemoteEvent, shows the results screen,
	manages Ready Up / Return to Hub button presses, and
	runs the 30s countdown timer client-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StarterGui = game:GetService("StarterGui")
local dmGui = StarterGui:WaitForChild("DMStarterGui")
local EndRoundScreen = require(dmGui:WaitForChild("EndRoundScreen"))

local screen: any = nil
local isReady = false
local timerThread: thread? = nil

local RESULTS_DURATION = 30

local function waitForRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:WaitForChild(name, 10)
	assert(remote, "[EndRoundController] Missing RemoteEvent: " .. name)
	return remote :: RemoteEvent
end

screen = EndRoundScreen.new(playerGui)

local readyUpEvent = waitForRemote("ReadyUp")
local returnToHubRequestEvent = waitForRemote("ReturnToHubRequest")

-- Wire button handlers
screen.readyUpButton.Activated:Connect(function()
	if isReady then return end
	isReady = true
	screen:setReadyState(true)
	readyUpEvent:FireServer()
end)

screen.returnToHubButton.Activated:Connect(function()
	screen:setVisible(false)
	returnToHubRequestEvent:FireServer()
end)

-- RaceEnd shows results
local raceEndEvent = waitForRemote("RaceEnd")
raceEndEvent.OnClientEvent:Connect(function(results: any)
	isReady = false
	screen:setReadyState(false)

	if results and type(results) == "table" then
		screen:setResults(results)
	end

	screen:setVisible(true)
	screen:setTimer(RESULTS_DURATION)

	if timerThread then
		task.cancel(timerThread)
	end

	timerThread = task.spawn(function()
		for remaining = RESULTS_DURATION, 0, -1 do
			screen:setTimer(remaining)
			if remaining > 0 then
				task.wait(1)
			end
		end
	end)
end)

-- Hide when lobby transitions back to pre-round or match starts
local lobbyStateEvent = waitForRemote("LobbyStateChanged")
lobbyStateEvent.OnClientEvent:Connect(function(newState: string)
	if newState == "pre_round" or newState == "idle" then
		screen:setVisible(false)
		if timerThread then
			task.cancel(timerThread)
			timerThread = nil
		end
	end
end)

local returnToHubEvent = waitForRemote("ReturnToHub")
returnToHubEvent.OnClientEvent:Connect(function()
	screen:setVisible(false)
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end
end)

-- XP Award event
local xpAwardEvent = waitForRemote("XPAward")
xpAwardEvent.OnClientEvent:Connect(function(data: any)
	if data and screen then
		screen:showXPAward(data)
	end
end)


return true
