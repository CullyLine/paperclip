--!strict
--[[
	Daily streak rewards + Premium box.
	POLA-519: Authoritative claim cap is one per UTC calendar day via DataStore UpdateAsync;
	duplicate client retries get idempotent success (DataUpdate, no duplicate currency).
	Rollover: UTC midnight (see DailyRewardConfig header).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local AUTH_STORE_NAME = "DACDailyRewardAuth_v1"
local authStore = DataStoreService:GetDataStore(AUTH_STORE_NAME)

local DailyRewardService = {}

local STREAK_REWARDS = DailyRewardConfig.STREAK_REWARDS

-- Serialize concurrent ClaimDailyReward handling per player (DataStore + grant).
local claimBusy: { [number]: boolean } = {}

local function authKey(userId: number): string
	return "dr_" .. tostring(userId)
end

type AuthOutcome = {
	day: number,
	gen: number,
	migrated: boolean?,
}

--[[
	Atomically records today's UTC claim in DataStore. Returns outcome; caller decides grant vs duplicate vs migration seed.
]]
local function updateAuthStore(
	userId: number,
	todayEpochDay: number,
	profileClaimsToday: boolean
): (boolean, AuthOutcome?, string?)
	local key = authKey(userId)
	local ok, result = pcall(function()
		return authStore:UpdateAsync(key, function(old: any): any
			local o: AuthOutcome? = if type(old) == "table" then old :: any else nil
			if o and o.day == todayEpochDay then
				return o
			end
			if not o and profileClaimsToday then
				return {
					day = todayEpochDay,
					gen = 1,
					migrated = true,
				}
			end
			local prevGen = if o and type(o.gen) == "number" then o.gen else 0
			return {
				day = todayEpochDay,
				gen = prevGen + 1,
			}
		end)
	end)
	if not ok or type(result) ~= "table" then
		return false, nil, if type(result) == "string" then result else "DataStore unavailable"
	end
	local out = result :: AuthOutcome
	return true, out, nil
end

local function waitClaimLock(userId: number)
	while claimBusy[userId] do
		task.wait()
	end
	claimBusy[userId] = true
end

local function releaseClaimLock(userId: number)
	claimBusy[userId] = nil
end

local function applyMult(amount: number, mult: number): number
	return math.floor(amount * mult + 0.5)
end

local function cycleMultiplierFor(dailyCycle: number): number
	return DailyRewardConfig.getCycleMultiplier(dailyCycle)
end

local function totalEggs(data: any): number
	local n = 0
	for _, count in data.eggs do
		n += count :: number
	end
	return n
end

local function pickRandomEggForWorld(worldId: string, unlocked: { [string]: boolean }): string?
	local candidates: { string } = {}
	for eggId, egg in EggConfig.Eggs do
		if egg.worldId == worldId and unlocked[egg.worldId] then
			table.insert(candidates, eggId)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

--[[
	Premium gift box — separate from streak rewards. Returns a short summary line.
]]
local function grantPremiumGiftBox(player: Player): string
	local data = DataManager.get(player)
	if not data then
		return ""
	end

	local roll = math.random()
	local summary: string

	if roll < 0.50 then
		CurrencyService.add(player, "coins", 5000, "daily_reward")
		summary = "+5,000 coins (Premium Box)"
	elseif roll < 0.75 then
		CurrencyService.add(player, "coins", 10000, "daily_reward")
		summary = "+10,000 coins (Premium Box)"
	elseif roll < 0.90 then
		local eggId = pickRandomEggForWorld(data.currentWorld, data.unlockedWorlds)
		if eggId and totalEggs(data) < Constants.MAX_EGGS_INVENTORY then
			data.eggs[eggId] = (data.eggs[eggId] or 0) + 1
			local eggName = EggConfig.Eggs[eggId] and EggConfig.Eggs[eggId].name or eggId
			summary = `+1 {eggName} (Premium Box)`
		else
			CurrencyService.add(player, "coins", 5000, "daily_reward")
			summary = "+5,000 coins (Premium Box — egg inventory full)"
		end
	else
		data.consumables.speedBoosts = (data.consumables.speedBoosts or 0) + 1
		summary = "+1 Speed Boost (Premium Box)"
	end

	return summary
end

function DailyRewardService.canClaim(player: Player): boolean
	local data = DataManager.get(player)
	if not data then
		return false
	end
	local last = data.dailyReward.lastClaim or 0
	return DailyRewardConfig.canClaimNow(last)
end

function DailyRewardService.claim(player: Player): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end

	local userId = player.UserId
	local now = os.time()
	local todayD = DailyRewardConfig.utcEpochDay(now)
	local lastClaimUnix: number = data.dailyReward.lastClaim or 0
	local profileClaimsToday = lastClaimUnix > 0 and DailyRewardConfig.utcEpochDay(lastClaimUnix) == todayD

	waitClaimLock(userId)
	local okStore, outcome, storeErr = updateAuthStore(userId, todayD, profileClaimsToday)

	if okStore and outcome then
		local authGen = math.floor(tonumber(data.dailyReward.authClaimGen) or 0)

		if outcome.migrated == true then
			data.dailyReward.authClaimGen = outcome.gen
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
			DataManager.scheduleSave(player)
			releaseClaimLock(userId)
			return true, nil
		end

		if outcome.gen <= authGen then
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
			releaseClaimLock(userId)
			return true, nil
		end

		if outcome.gen > authGen + 1 then
			data.dailyReward.authClaimGen = outcome.gen
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
			DataManager.scheduleSave(player)
			releaseClaimLock(userId)
			return true, nil
		end

		if outcome.gen ~= authGen + 1 then
			releaseClaimLock(userId)
			return false, "Daily reward out of sync"
		end

		data.dailyReward.authClaimGen = outcome.gen
	else
		if not DailyRewardConfig.canClaimNow(lastClaimUnix) then
			releaseClaimLock(userId)
			return false, "Already claimed today"
		end
		warn("[DailyRewardService] DataStore unavailable, falling back to profile-only claim: " .. tostring(storeErr))
	end

	-- Streak: missed at least one UTC calendar day since last claim.
	local gapDays = 0
	if lastClaimUnix > 0 then
		gapDays = DailyRewardConfig.utcEpochDay(now) - DailyRewardConfig.utcEpochDay(lastClaimUnix)
	end
	local hadLongBreak = lastClaimUnix > 0 and gapDays >= 2

	local prevStreak: number = data.dailyReward.streak
	local simStreak = prevStreak
	local simCycle = data.dailyReward.dailyCycle or 1

	if hadLongBreak then
		simStreak = 0
		simCycle = 1
	end

	if not hadLongBreak and prevStreak == Constants.MAX_DAILY_STREAK then
		simCycle = simCycle + 1
	end

	simStreak = (simStreak % Constants.MAX_DAILY_STREAK) + 1
	local dayDef = STREAK_REWARDS[simStreak]
	if not dayDef then
		releaseClaimLock(userId)
		return false, "Invalid streak state"
	end

	if hadLongBreak then
		data.dailyReward.streak = 0
		data.dailyReward.dailyCycle = 1
	end

	if not hadLongBreak and prevStreak == Constants.MAX_DAILY_STREAK then
		data.dailyReward.dailyCycle = (data.dailyReward.dailyCycle or 1) + 1
	end

	data.dailyReward.streak = (data.dailyReward.streak % Constants.MAX_DAILY_STREAK) + 1
	data.dailyReward.lastClaim = now
	data.dailyReward.premiumBoxClaimed = false
	data.dailyReward.lastClaimLostStreak = if hadLongBreak then prevStreak else 0
	if outcome then
		data.dailyReward.authClaimGen = outcome.gen
	end

	MilestoneCeremonyService.checkStreakMilestones(player, data, data.dailyReward.streak)

	local dayIndex = data.dailyReward.streak

	local mult = cycleMultiplierFor(data.dailyReward.dailyCycle or 1) :: number

	local lines: { string } = {}
	local claimItems: { any } = {}
	for _, part in dayDef.rewards do
		local amt = applyMult(part.amount, mult)
		CurrencyService.add(player, part.currency, amt, "daily_reward")
		table.insert(lines, `+{amt} {part.currency}`)
		local cur = part.currency
		local label = cur:sub(1, 1):upper() .. cur:sub(2)
		table.insert(claimItems, { label = label, amount = amt, kind = cur })
	end

	local PremiumService = require(script.Parent:WaitForChild("PremiumService"))
	local premiumMsg = ""
	if PremiumService.isPremium(player) then
		data.dailyReward.premiumBoxClaimed = true
		premiumMsg = grantPremiumGiftBox(player)
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	AchievementService.onDailyClaimed(player)

	local summary = `Day {dayIndex} ({mult}x): ` .. table.concat(lines, ", ")
	if premiumMsg ~= "" then
		summary ..= " • " .. premiumMsg
		table.insert(claimItems, { label = premiumMsg, kind = "premium" })
	end

	NotificationDispatchService.notify(player, {
		type = "reward_claim",
		title = "Daily Reward",
		subtitle = `Day {dayIndex} ({mult}x)`,
		message = summary,
		items = claimItems,
	})

	DataManager.scheduleSave(player)
	releaseClaimLock(userId)
	return true, nil
end

function DailyRewardService.init()
	Remotes.getEvent("ClaimDailyReward").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "ClaimDailyReward") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "ClaimDailyReward", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = DailyRewardService.claim(player)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Cannot claim daily reward",
			})
		end
	end)
end

return DailyRewardService
