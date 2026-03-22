--!strict
--[[
	Shared daily streak schedule + cycle multiplier (server + client UI).
]]

local Constants = require(script.Parent.Parent:WaitForChild("Constants"))

export type RewardPart = { currency: string, amount: number }
export type DayReward = { rewards: { RewardPart } }

local DailyRewardConfig = {}

-- Must match DailyRewardService: streak resets if claim gap exceeds 2× daily cooldown (48h).
DailyRewardConfig.STREAK_RESET_HOURS = 48
DailyRewardConfig.STREAK_RESET_SECONDS = Constants.DAILY_REWARD_COOLDOWN * 2

local function formatNumber(n: number): string
	local s = tostring(n)
	local pattern = "^(-?%d+)(%d%d%d)"
	while true do
		local k
		s, k = s:gsub(pattern, "%1,%2")
		if k == 0 then
			break
		end
	end
	return s
end

DailyRewardConfig.STREAK_REWARDS = {
	{ rewards = { { currency = "coins", amount = 1000 } } },
	{ rewards = { { currency = "gems", amount = 25 } } },
	{ rewards = { { currency = "coins", amount = 3000 } } },
	{
		rewards = {
			{ currency = "coins", amount = 2000 },
			{ currency = "gems", amount = 50 },
		},
	},
	{ rewards = { { currency = "crystals", amount = 10 } } },
	{ rewards = { { currency = "gems", amount = 100 } } },
	{
		rewards = {
			{ currency = "coins", amount = 10000 },
			{ currency = "gems", amount = 200 },
			{ currency = "crystals", amount = 25 },
		},
	},
} :: { DayReward }

function DailyRewardConfig.getCycleMultiplier(dailyCycle: number): number
	local c = math.max(1, dailyCycle)
	return math.min(1 + 0.25 * (c - 1), 2.0)
end

function DailyRewardConfig.nextDayIndex(streak: number): number
	return streak % Constants.MAX_DAILY_STREAK + 1
end

function DailyRewardConfig.formatRewardLine(day: DayReward, mult: number): string
	local parts = {}
	for _, r in day.rewards do
		local amt = math.floor(r.amount * mult + 0.5)
		table.insert(parts, `{formatNumber(amt)} {r.currency}`)
	end
	return table.concat(parts, " + ")
end

return DailyRewardConfig
