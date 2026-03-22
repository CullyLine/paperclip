--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local DailyRewardService = {}

local STREAK_REWARDS = DailyRewardConfig.STREAK_REWARDS

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

	if roll < 0.40 then
		CurrencyService.add(player, "coins", 5000, "daily_reward")
		summary = "+5,000 coins (Premium Box)"
	elseif roll < 0.65 then
		CurrencyService.add(player, "gems", 50, "daily_reward")
		summary = "+50 gems (Premium Box)"
	elseif roll < 0.80 then
		CurrencyService.add(player, "crystals", 10, "daily_reward")
		summary = "+10 crystals (Premium Box)"
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
	elseif roll < 0.97 then
		data.consumables.speedBoosts = (data.consumables.speedBoosts or 0) + 1
		summary = "+1 Speed Boost (Premium Box)"
	else
		CurrencyService.add(player, "skulls", 5, "daily_reward")
		summary = "+5 skulls (Premium Box)"
	end

	return summary
end

function DailyRewardService.canClaim(player: Player): boolean
	local data = DataManager.get(player)
	if not data then
		return false
	end

	local now = os.time()
	local elapsed = now - data.dailyReward.lastClaim
	return elapsed >= Constants.DAILY_REWARD_COOLDOWN
end

function DailyRewardService.claim(player: Player): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end

	if not DailyRewardService.canClaim(player) then
		return false, "Daily reward not ready yet"
	end

	local now = os.time()
	local elapsed = now - data.dailyReward.lastClaim

	local prevStreak: number = data.dailyReward.streak
	local hadLongBreak = elapsed > Constants.DAILY_REWARD_COOLDOWN * 2

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

	MilestoneCeremonyService.checkStreakMilestones(player, data, data.dailyReward.streak)

	local dayIndex = data.dailyReward.streak
	local dayDef = STREAK_REWARDS[dayIndex]
	if not dayDef then
		return false, "Invalid streak state"
	end

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

	Remotes.getEvent("Notification"):FireClient(player, {
		type = "reward_claim",
		title = "Daily Reward",
		subtitle = `Day {dayIndex} ({mult}x)`,
		message = summary,
		items = claimItems,
	})

	return true, nil
end

function DailyRewardService.init()
	Remotes.getEvent("ClaimDailyReward").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "ClaimDailyReward") then
			return
		end
		if not RemoteCooldown.allow(player, "ClaimDailyReward", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = DailyRewardService.claim(player)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Cannot claim daily reward",
			})
		end
	end)
end

return DailyRewardService
