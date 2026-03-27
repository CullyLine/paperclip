--!strict
--[[
	First-play-session onboarding copy: server-authoritative flags + hook line (at most once).
	Session-only pending flags (not persisted) gate prepare* calls after run/hatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local FirstSessionOnboardingService = {}

local pendingFirstPayout: { [number]: boolean } = {}
local pendingFirstHatch: { [number]: boolean } = {}

local function defaultFlags(): any
	return {
		firstPlaySessionEnded = false,
		hookLineConsumed = false,
		sessionWelcomeToastSeen = false,
		firstPayoutCopySeen = false,
		firstHatchCopySeen = false,
		emptyTrophyCaseCopySeen = false,
		dailyStreakFramingSeen = false,
	}
end

local function ensure(data: any)
	if type(data) ~= "table" then
		return nil
	end
	if type(data.firstSessionOnboarding) ~= "table" then
		data.firstSessionOnboarding = defaultFlags()
	end
	local o = data.firstSessionOnboarding
	local d = defaultFlags()
	for k, v in d do
		if o[k] == nil then
			o[k] = v
		end
	end
	return o
end

function FirstSessionOnboardingService.migrateForExistingPlayers(data: any)
	if type(data) ~= "table" then
		return
	end
	local stats = data.stats
	local runs = if type(stats) == "table" then tonumber(stats.totalRunsCompleted) or 0 else 0
	if runs <= 0 then
		ensure(data)
		return
	end
	local o = ensure(data)
	if not o then
		return
	end
	o.firstPlaySessionEnded = true
	o.hookLineConsumed = true
	o.sessionWelcomeToastSeen = true
	o.firstPayoutCopySeen = true
	o.firstHatchCopySeen = true
	o.emptyTrophyCaseCopySeen = true
	o.dailyStreakFramingSeen = true
end

function FirstSessionOnboardingService.markPendingFirstPayout(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	local o = ensure(data)
	if not o or o.firstPlaySessionEnded then
		return
	end
	pendingFirstPayout[player.UserId] = true
end

function FirstSessionOnboardingService.markPendingFirstHatch(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	local o = ensure(data)
	if not o or o.firstPlaySessionEnded then
		return
	end
	pendingFirstHatch[player.UserId] = true
end

function FirstSessionOnboardingService.onPlayerRemoving(player: Player)
	pendingFirstPayout[player.UserId] = nil
	pendingFirstHatch[player.UserId] = nil
end

local function maybeConsumeHook(o: any): string
	if o.firstPlaySessionEnded or o.hookLineConsumed then
		return ""
	end
	o.hookLineConsumed = true
	return MicrocopyConfig.FirstSessionTagline
end

function FirstSessionOnboardingService.prepareFirstPayout(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return { applied = false }
	end
	local uid = player.UserId
	if not pendingFirstPayout[uid] then
		return { applied = false }
	end
	pendingFirstPayout[uid] = nil
	local o = ensure(data)
	if not o then
		return { applied = false }
	end
	o.firstPayoutCopySeen = true
	local hookLine = maybeConsumeHook(o)
	local mainLine = MicrocopyConfig.pickVariant(MicrocopyConfig.FirstSessionPayoutBrag)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return { applied = true, mainLine = mainLine, hookLine = hookLine }
end

function FirstSessionOnboardingService.prepareFirstHatch(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return { applied = false }
	end
	local uid = player.UserId
	if not pendingFirstHatch[uid] then
		return { applied = false }
	end
	pendingFirstHatch[uid] = nil
	local o = ensure(data)
	if not o then
		return { applied = false }
	end
	o.firstHatchCopySeen = true
	-- First payout overlay has priority for the single hook line.
	local hookLine = ""
	if not pendingFirstPayout[uid] then
		hookLine = maybeConsumeHook(o)
	end
	local mainLine = MicrocopyConfig.pickVariant(MicrocopyConfig.FirstSessionHatchCopy)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return { applied = true, mainLine = mainLine, hookLine = hookLine }
end

function FirstSessionOnboardingService.ackWelcomeToast(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return { ok = false }
	end
	local o = ensure(data)
	if not o then
		return { ok = false }
	end
	if o.sessionWelcomeToastSeen then
		return { ok = true }
	end
	o.sessionWelcomeToastSeen = true
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return { ok = true }
end

function FirstSessionOnboardingService.prepareEmptyTrophy(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return { applied = false }
	end
	local o = ensure(data)
	if not o or o.firstPlaySessionEnded or o.emptyTrophyCaseCopySeen then
		return { applied = false }
	end
	o.emptyTrophyCaseCopySeen = true
	local stats = data.stats
	local runs = if type(stats) == "table" then tonumber(stats.totalRunsCompleted) or 0 else 0
	local hookLine = ""
	if runs >= 1 and not pendingFirstPayout[player.UserId] then
		hookLine = maybeConsumeHook(o)
	end
	local mainLine = MicrocopyConfig.pickVariant(MicrocopyConfig.FirstSessionEmptyTrophy)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return { applied = true, mainLine = mainLine, hookLine = hookLine }
end

function FirstSessionOnboardingService.prepareDailyStreak(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return { applied = false }
	end
	local o = ensure(data)
	if not o or o.firstPlaySessionEnded or o.dailyStreakFramingSeen then
		return { applied = false }
	end
	o.dailyStreakFramingSeen = true
	local stats = data.stats
	local runs = if type(stats) == "table" then tonumber(stats.totalRunsCompleted) or 0 else 0
	local hookLine = ""
	if runs >= 1 and not pendingFirstPayout[player.UserId] then
		hookLine = maybeConsumeHook(o)
	end
	local mainLine = MicrocopyConfig.pickVariant(MicrocopyConfig.FirstSessionDailyStreak)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return { applied = true, mainLine = mainLine, hookLine = hookLine }
end

function FirstSessionOnboardingService.init()
	Players.PlayerRemoving:Connect(function(player)
		FirstSessionOnboardingService.onPlayerRemoving(player)
	end)

	Remotes.getFunction("FirstSessionOnboarding").OnServerInvoke = function(player, payload: any): any
		if not ValidationService.checkRemoteRate(player, "FirstSessionOnboarding") then
			return nil
		end
		if type(payload) ~= "table" then
			return nil
		end
		local kind = payload.kind
		if kind == "prepareFirstPayout" then
			return FirstSessionOnboardingService.prepareFirstPayout(player)
		elseif kind == "prepareFirstHatch" then
			return FirstSessionOnboardingService.prepareFirstHatch(player)
		elseif kind == "ackWelcomeToast" then
			return FirstSessionOnboardingService.ackWelcomeToast(player)
		elseif kind == "prepareEmptyTrophy" then
			return FirstSessionOnboardingService.prepareEmptyTrophy(player)
		elseif kind == "prepareDailyStreak" then
			return FirstSessionOnboardingService.prepareDailyStreak(player)
		end
		if kind ~= nil then
			ValidationService.logAnomalyOncePerSession(player, "onboarding_unknown_kind", tostring(kind))
		end
		return nil
	end
end

return FirstSessionOnboardingService
