--[[
	DriverHUD.client.luau — Listens for race events and drives the HUD.

	Wires CountdownUpdate, RaceStart, ProgressUpdate, RaceEnd
	RemoteEvents to the DriverHUDScreen UI module.
	Tracks elapsed race time client-side for smooth display.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StarterGui = game:GetService("StarterGui")
local dmGui = StarterGui:WaitForChild("DMStarterGui")
local DriverHUDScreen = require(dmGui:WaitForChild("DriverHUDScreen"))

local hud: any = nil
local isRacing = false
local raceStartTick = 0
local raceDuration = 120
local heartbeatConn: RBXScriptConnection? = nil

local function waitForRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:WaitForChild(name, 10)
	assert(remote, "[DriverHUD] Missing RemoteEvent: " .. name)
	return remote :: RemoteEvent
end

hud = DriverHUDScreen.new(playerGui)

-- CountdownUpdate (3, 2, 1, 0=GO)
local countdownEvent = waitForRemote("CountdownUpdate")
countdownEvent.OnClientEvent:Connect(function(value: number)
	if not hud then return end
	hud:setVisible(true)
	hud:showCountdown(value)
end)

-- RaceStart (raceDurationSeconds)
local raceStartEvent = waitForRemote("RaceStart")
raceStartEvent.OnClientEvent:Connect(function(duration: number)
	if not hud then return end

	raceDuration = duration or 120
	raceStartTick = tick()
	isRacing = true
	hud:setVisible(true)

	if heartbeatConn then heartbeatConn:Disconnect() end

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not isRacing then return end

		local elapsed = tick() - raceStartTick
		local remaining = math.max(0, raceDuration - elapsed)

		hud:setElapsedTime(elapsed)
		hud:setRaceTimer(remaining)
	end)
end)

-- ProgressUpdate (leaderboard entries, myProgress)
local progressEvent = waitForRemote("ProgressUpdate")
progressEvent.OnClientEvent:Connect(function(leaderboard: any, _myProgress: number)
	if not hud then return end

	hud:updateLeaderboard(leaderboard)

	for i, entry in leaderboard do
		if entry.userId == player.UserId then
			hud:setPlacement(i)
			break
		end
	end
end)

-- RaceEnd (results)
local raceEndEvent = waitForRemote("RaceEnd")
raceEndEvent.OnClientEvent:Connect(function(_results: any)
	isRacing = false

	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end

	task.delay(1, function()
		if hud then
			hud:setVisible(false)
		end
	end)
end)


return true
