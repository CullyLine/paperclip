--!strict
--[[
	New-player / low-session calm window (POLA-264).

	After client load, for players with few completed runs we suppress non-critical
	HUD noise (streak toasts, achievement progress nudges, optional milestone/social
	feed styles) for CALM_WINDOW_SECONDS. Suppressed items are queued and shown
	when the window ends. Critical gameplay feedback is unchanged.

	Tune duration and eligibility only here — do not scatter magic numbers.
]]

local NewPlayerCalmWindow = {}

-- How long after session UI init to keep the calm window (seconds). Target band ~45–90s.
NewPlayerCalmWindow.CALM_WINDOW_SECONDS = 60

-- Players with totalRunsCompleted >= this are treated as experienced; no calm gating.
NewPlayerCalmWindow.LOW_SESSION_MAX_RUNS = 5

local calmActive = false
local sessionStartClock = 0.0

local queuedNotifications: { any } = {}
local queuedAchievementProgress: { any } = {}
local queuedMilestones: { { text: string, style: string } } = {}
local queuedServerDrops: { any } = {}

local function clearQueues()
	table.clear(queuedNotifications)
	table.clear(queuedAchievementProgress)
	table.clear(queuedMilestones)
	table.clear(queuedServerDrops)
end

function NewPlayerCalmWindow.isCalmActive(): boolean
	return calmActive and (os.clock() - sessionStartClock) < NewPlayerCalmWindow.CALM_WINDOW_SECONDS
end

function NewPlayerCalmWindow.shouldApplyCalmForData(data: any): boolean
	if type(data) ~= "table" or type(data.stats) ~= "table" then
		return true
	end
	local runs = math.max(0, math.floor(tonumber((data.stats :: any).totalRunsCompleted) or 0))
	return runs < NewPlayerCalmWindow.LOW_SESSION_MAX_RUNS
end

--[[
	Call once after initial player data is available (Bootstrap), before welcome toast.
]]
function NewPlayerCalmWindow.initFromPlayerData(data: any)
	calmActive = NewPlayerCalmWindow.shouldApplyCalmForData(data)
	sessionStartClock = os.clock()
	if not calmActive then
		clearQueues()
		return
	end
	task.delay(NewPlayerCalmWindow.CALM_WINDOW_SECONDS, function()
		NewPlayerCalmWindow.flushDeferred()
	end)
end

local NOTIFICATION_DEFERRABLE_KINDS: { [string]: boolean } = {
	streak_nudge = true,
	streak_urgent = true,
	streak_critical = true,
	streak_celebrate = true,
}

function NewPlayerCalmWindow.shouldDeferHudToast(kind: string, notification: any): boolean
	if not calmActive or not NewPlayerCalmWindow.isCalmActive() then
		return false
	end
	if type(notification) == "table" and (notification :: any).critical == true then
		return false
	end
	return NOTIFICATION_DEFERRABLE_KINDS[kind] == true
end

function NewPlayerCalmWindow.enqueueNotification(notification: any)
	table.insert(queuedNotifications, notification)
end

function NewPlayerCalmWindow.shouldDeferAchievementProgress(): boolean
	return calmActive and NewPlayerCalmWindow.isCalmActive()
end

function NewPlayerCalmWindow.enqueueAchievementProgress(payload: any)
	table.insert(queuedAchievementProgress, payload)
end

-- Optional / FOMO milestone popups — not distance/combat/world unlock.
local MILESTONE_DEFERRABLE_STYLES: { [string]: boolean } = {
	almost_there = true,
	collection_toast = true,
	streak_milestone = true,
}

function NewPlayerCalmWindow.shouldDeferMilestoneStyle(style: string?): boolean
	if not calmActive or not NewPlayerCalmWindow.isCalmActive() then
		return false
	end
	local st = style or "small"
	return MILESTONE_DEFERRABLE_STYLES[st] == true
end

function NewPlayerCalmWindow.enqueueMilestone(text: string, style: string?)
	table.insert(queuedMilestones, { text = text, style = style or "small" })
end

function NewPlayerCalmWindow.shouldDeferServerFeed(): boolean
	return calmActive and NewPlayerCalmWindow.isCalmActive()
end

function NewPlayerCalmWindow.enqueueServerDrop(payload: any)
	table.insert(queuedServerDrops, payload)
end

--[[
	Runs once when the calm window ends. Uses lazy requires to avoid static cycles.
]]
function NewPlayerCalmWindow.flushDeferred()
	if not calmActive then
		return
	end
	-- Window ended for gating; clear calm so deferred handlers can show UI.
	calmActive = false

	local lp = game:GetService("Players").LocalPlayer
	if not lp or not lp.Parent then
		return
	end

	local DAC = game:GetService("ReplicatedStorage"):WaitForChild("DAC")
	local Controllers = lp:WaitForChild("PlayerScripts"):WaitForChild("DAC"):WaitForChild("Controllers")
	local UIController = require(Controllers:WaitForChild("UIController"))
	local AchievementController = require(Controllers:WaitForChild("AchievementController"))
	local VFXController = require(Controllers:WaitForChild("VFXController"))

	for _, n in queuedNotifications do
		UIController.showNotification(n)
	end
	table.clear(queuedNotifications)

	for _, p in queuedAchievementProgress do
		AchievementController.showQueuedAchievementProgress(p)
	end
	table.clear(queuedAchievementProgress)

	for _, item in queuedMilestones do
		VFXController.milestonePopup(item.text, item.style)
	end
	table.clear(queuedMilestones)

	for _, payload in queuedServerDrops do
		VFXController.serverDropFeedBanner(payload)
	end
	table.clear(queuedServerDrops)
end

return NewPlayerCalmWindow
