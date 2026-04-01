--!strict
--[[
	Shared daily streak schedule + cycle multiplier (server + client UI).

	Rollover rule (POLA-519, server-authoritative):
	- One claim per UTC calendar day (midnight UTC boundary).
	- Eligibility and duplicate detection use UTC, not local timezone or rolling 24h windows.
	- Streak "missed day" = gap of 2+ UTC epoch days since last claim (not 48h wall-clock).
]]

local Constants = require(script.Parent.Parent:WaitForChild("Constants"))

export type RewardPart = { currency: string, amount: number }
export type DayReward = { rewards: { RewardPart } }

local DailyRewardConfig = {}

-- Legacy display: ~48h wall-clock; streak reset is driven by UTC day gap (>= 2 days) on server.
DailyRewardConfig.STREAK_RESET_HOURS = 48
DailyRewardConfig.STREAK_RESET_SECONDS = Constants.DAILY_REWARD_COOLDOWN * 2

--[[
	UTC calendar day id YYYYMMDD (for display / client preview only; server uses DataStore + epoch day).
]]
function DailyRewardConfig.utcCalendarDayId(unixTime: number): number
	local u = os.date("!*t", unixTime) :: any
	return u.year * 10000 + u.month * 100 + u.day
end

--[[
	Whole UTC days since Unix epoch (matches server streak gap / claim eligibility).
]]
function DailyRewardConfig.utcEpochDay(unixTime: number): number
	return math.floor(unixTime / 86400)
end

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
	{ rewards = { { currency = "coins", amount = 800 } } },
	{ rewards = { { currency = "coins", amount = 2000 } } },
	{ rewards = { { currency = "coins", amount = 3500 } } },
	{ rewards = { { currency = "coins", amount = 5500 } } },
	{ rewards = { { currency = "coins", amount = 8000 } } },
	{ rewards = { { currency = "coins", amount = 12000 } } },
	{ rewards = { { currency = "coins", amount = 28000 } } },
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

export type StreakFlameStyle = {
	fillColor: Color3,
	fillColorEnd: Color3,
	strokeColor: Color3,
	strokeThickness: number,
	titlePrefix: string,
}

-- Tier thresholds by inclusive streak length (days). Drives streak meter + title chrome in DailyRewardPanel.
local FLAME_TIERS: { { minStreak: number, style: StreakFlameStyle } } = {
	{
		minStreak = 1,
		style = {
			fillColor = Color3.fromRGB(255, 200, 120),
			fillColorEnd = Color3.fromRGB(255, 160, 70),
			strokeColor = Color3.fromRGB(255, 190, 100),
			strokeThickness = 1,
			titlePrefix = "",
		},
	},
	{
		minStreak = 3,
		style = {
			fillColor = Color3.fromRGB(255, 170, 80),
			fillColorEnd = Color3.fromRGB(255, 120, 40),
			strokeColor = Color3.fromRGB(255, 140, 60),
			strokeThickness = 2,
			titlePrefix = "🔥 ",
		},
	},
	{
		minStreak = 5,
		style = {
			fillColor = Color3.fromRGB(255, 120, 40),
			fillColorEnd = Color3.fromRGB(255, 70, 20),
			strokeColor = Color3.fromRGB(255, 200, 80),
			strokeThickness = 2,
			titlePrefix = "🔥🔥 ",
		},
	},
	{
		minStreak = 7,
		style = {
			fillColor = Color3.fromRGB(255, 90, 30),
			fillColorEnd = Color3.fromRGB(255, 40, 10),
			strokeColor = Color3.fromRGB(255, 230, 120),
			strokeThickness = 3,
			titlePrefix = "🔥🔥🔥 ",
		},
	},
}

local COLD_FILL = Color3.fromRGB(255, 188, 72)
local COLD_FILL_END = Color3.fromRGB(255, 150, 55)

function DailyRewardConfig.streakFlameStyleForStreak(streak: number): StreakFlameStyle
	if streak <= 0 then
		return {
			fillColor = COLD_FILL,
			fillColorEnd = COLD_FILL_END,
			strokeColor = Color3.fromRGB(255, 170, 80),
			strokeThickness = 0,
			titlePrefix = "",
		}
	end
	local chosen = FLAME_TIERS[1].style
	for _, row in FLAME_TIERS do
		if streak >= row.minStreak then
			chosen = row.style
		end
	end
	return chosen
end

function DailyRewardConfig.canClaimNow(lastClaimUnix: number): boolean
	local last = lastClaimUnix
	if last <= 0 then
		return true
	end
	local now = os.time()
	return DailyRewardConfig.utcEpochDay(now) > DailyRewardConfig.utcEpochDay(last)
end

--[[
	Seconds until the next UTC midnight when a new calendar-day claim is allowed
	(last claim was already on today's UTC date).
]]
function DailyRewardConfig.secondsUntilNextUtcClaimWindow(lastClaimUnix: number): number
	if lastClaimUnix <= 0 then
		return 0
	end
	if DailyRewardConfig.canClaimNow(lastClaimUnix) then
		return 0
	end
	local now = os.time()
	local nowDay = math.floor(now / 86400)
	local nextUtcMidnight = (nowDay + 1) * 86400
	return math.max(0, nextUtcMidnight - now)
end

return DailyRewardConfig
