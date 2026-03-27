--!strict
--[[
	Launch window: Founder's Bonus (2x coins), Early Driver title for joiners in window.
	Edit FOUNDER_WINDOW_* in Config/EventWindowConfig.luau (UTC Unix seconds) before go-live.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local EventWindowConfig = require(DAC:WaitForChild("Config"):WaitForChild("EventWindowConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))

local FOUNDER_WINDOW_START_UTC = EventWindowConfig.FOUNDER_WINDOW_START_UTC
local FOUNDER_WINDOW_END_UTC = EventWindowConfig.FOUNDER_WINDOW_END_UTC

local EventService = {}

local function nowUnix(): number
	return os.time()
end

function EventService.isLaunchWindowActive(): boolean
	local t = nowUnix()
	return t >= FOUNDER_WINDOW_START_UTC and t < FOUNDER_WINDOW_END_UTC
end

function EventService.getFounderWindowEndUnix(): number
	return FOUNDER_WINDOW_END_UTC
end

function EventService.getFounderCoinMultiplier(): number
	if EventService.isLaunchWindowActive() then
		return 2
	end
	return 1
end

function EventService.syncPlayerTitleAttribute(player: Player)
	local data = DataManager.get(player)
	local titleText: string? = nil
	if data and data.titles then
		local bestPriority = -math.huge
		local bestId: string? = nil
		for titleId, owned in pairs(data.titles) do
			if owned and type(titleId) == "string" then
				local def = Constants.TITLES[titleId]
				if def and type(def.priority) == "number" then
					local p = def.priority
					if p > bestPriority then
						bestPriority = p
						bestId = titleId
					end
				end
			end
		end
		if bestId then
			local chosen = Constants.TITLES[bestId]
			if chosen then
				titleText = chosen.displayName
			end
		end
	end
	player:SetAttribute("DAC_PlayerTitle", titleText)
end

function EventService.handlePlayerJoin(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end

	if not data.titles then
		data.titles = {}
	end

	if EventService.isLaunchWindowActive() and not data.joinedDuringLaunch then
		data.joinedDuringLaunch = true
		data.titles["early_driver"] = true
	end

	if EventService.isLaunchWindowActive() and not data.founderBonusNotified then
		data.founderBonusNotified = true
		NotificationDispatchService.notify(player, {
			type = "info",
			message = MicrocopyConfig.FounderBonusJoinNotification,
		})
	end

	EventService.syncPlayerTitleAttribute(player)

	Remotes.getEvent("LaunchEventState"):FireClient(player, {
		founderActive = EventService.isLaunchWindowActive(),
		founderEndsAtUnix = FOUNDER_WINDOW_END_UTC,
		serverTimeUnix = nowUnix(),
	})
end

function EventService.broadcastLaunchState()
	if not EventService.isLaunchWindowActive() then
		return
	end
	local payload = {
		founderActive = true,
		founderEndsAtUnix = FOUNDER_WINDOW_END_UTC,
		serverTimeUnix = nowUnix(),
	}
	for _, p in Players:GetPlayers() do
		Remotes.getEvent("LaunchEventState"):FireClient(p, payload)
	end
end

function EventService.init()
	task.spawn(function()
		while true do
			task.wait(30)
			EventService.broadcastLaunchState()
		end
	end)
end

return EventService
