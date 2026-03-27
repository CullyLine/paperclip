--!strict
--[[
	Privacy-safe, rate-limited structured logging for economy / monetization investigations.
	Logs only numeric UserIds and non-PII fields (ids, tiers, product keys, amounts).

	Verbose mode (Studio / live debugging):
	- Select ServerScriptService → DAC (folder) in Explorer
	- Attributes → add Boolean attribute "EconomyLogVerbose" = true
	- When true, also logs medium-sized currency grants (see MEDIUM_* thresholds below)
	- Remove or set false for default anomaly-only logging

	No player names or chat text are ever emitted.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyLogService = {}

local PREFIX = "[DAC][Economy]"

-- Sliding windows (seconds)
local GLOBAL_WINDOW_SEC = 60
local GLOBAL_MAX_PER_WINDOW = 96
local PLAYER_WINDOW_SEC = 60
local PLAYER_MAX_PER_WINDOW = 18

-- "Large" always logged (when rate limit allows), unless source is filtered
local LARGE_THRESHOLDS: { [string]: number } = {
	coins = 50_000,
	sandGranules = 50_000,
	icycles = 50_000,
	magmaCores = 50_000,
	infinitium = 50_000,
}

local MEDIUM_VERBOSE_THRESHOLDS: { [string]: number } = {
	coins = 10_000,
	sandGranules = 10_000,
	icycles = 10_000,
	magmaCores = 10_000,
	infinitium = 10_000,
}

-- Never spam these (high frequency)
local IGNORE_SOURCES: { [string]: boolean } = {
	playtime = true,
}

local globalStampTimes: { number } = {}
local playerStampTimes: { [number]: { [string]: { number } } } = {}

local function trimWindow(times: { number }, windowSec: number, now: number)
	local cutoff = now - windowSec
	local i = 1
	while i <= #times do
		if times[i] < cutoff then
			table.remove(times, i)
		else
			i += 1
		end
	end
end

local function allowGlobal(now: number): boolean
	trimWindow(globalStampTimes, GLOBAL_WINDOW_SEC, now)
	if #globalStampTimes >= GLOBAL_MAX_PER_WINDOW then
		return false
	end
	table.insert(globalStampTimes, now)
	return true
end

local function allowPlayer(uid: number, category: string, now: number): boolean
	local byCat = playerStampTimes[uid]
	if not byCat then
		byCat = {}
		playerStampTimes[uid] = byCat
	end
	local times = byCat[category]
	if not times then
		times = {}
		byCat[category] = times
	end
	trimWindow(times, PLAYER_WINDOW_SEC, now)
	if #times >= PLAYER_MAX_PER_WINDOW then
		return false
	end
	table.insert(times, now)
	return true
end

function EconomyLogService.isVerboseEnabled(): boolean
	local dac = ServerScriptService:FindFirstChild("DAC")
	if dac and dac:GetAttribute("EconomyLogVerbose") == true then
		return true
	end
	return false
end

export type FieldMap = { [string]: number | string | boolean }

function EconomyLogService.emit(category: string, userId: number, fields: FieldMap)
	local now = os.clock()
	if not allowGlobal(now) then
		return
	end
	if not allowPlayer(userId, category, now) then
		return
	end
	local parts = { PREFIX, `cat={category}`, `uid={userId}` }
	for k, v in fields do
		local t = type(v)
		if t == "number" or t == "boolean" then
			table.insert(parts, `{k}={v}`)
		elseif t == "string" then
			-- keep short; no freeform user text
			local s = v
			if #s > 120 then
				s = string.sub(s, 1, 117) .. "..."
			end
			table.insert(parts, `{k}={s}`)
		end
	end
	print(table.concat(parts, " "))
end

function EconomyLogService.onCurrencyAdded(player: Player, currency: string, amount: number, source: string)
	if IGNORE_SOURCES[source] then
		return
	end
	if amount <= 0 then
		return
	end
	local uid = player.UserId
	local thresh = LARGE_THRESHOLDS[currency]
	local medium = MEDIUM_VERBOSE_THRESHOLDS[currency]
	local verbose = EconomyLogService.isVerboseEnabled()
	local isLarge = thresh ~= nil and amount >= thresh
	local isMedium = verbose and medium ~= nil and amount >= medium
	local isAdmin = source == "admin" or source == "admin_global"
	-- dev_product purchases are logged once in DevProductService.finalizePurchase (avoids duplicate lines per currency line)
	local isSensitive = source == "code_redemption"
	if not isLarge and not isMedium and not isAdmin and not isSensitive then
		return
	end
	EconomyLogService.emit("currency_grant", uid, {
		currency = currency,
		amt = amount,
		src = source,
	})
end

function EconomyLogService.logRareHatch(player: Player, eggId: string, petId: string, rarity: string)
	EconomyLogService.emit("hatch_rare", player.UserId, {
		egg = eggId,
		pet = petId,
		rar = rarity,
	})
end

function EconomyLogService.logRebirth(player: Player, rebirthCount: number, crystalsGranted: number)
	EconomyLogService.emit("rebirth", player.UserId, {
		n = rebirthCount,
		cr = crystalsGranted,
	})
end

function EconomyLogService.logDevProductPurchase(player: Player, productKey: string, productId: number, robuxSpent: number)
	EconomyLogService.emit("dev_product", player.UserId, {
		pkey = productKey,
		pid = productId,
		rbx = robuxSpent,
	})
end

function EconomyLogService.logCodeRedeem(player: Player, codeKey: string)
	EconomyLogService.emit("code_redeem", player.UserId, {
		code = codeKey,
	})
end

function EconomyLogService.logBattlePassClaim(player: Player, tier: number, track: string)
	EconomyLogService.emit("bp_claim", player.UserId, {
		tier = tier,
		tr = track,
	})
end

function EconomyLogService.init()
	Players.PlayerRemoving:Connect(function(player)
		playerStampTimes[player.UserId] = nil
	end)
end

return EconomyLogService
