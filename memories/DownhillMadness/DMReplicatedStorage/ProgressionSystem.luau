--[[
	ProgressionSystem — XP, Scrap, leveling, and reward calculations.

	Shared between server (awarding at race end) and client (UI display).
	All numbers are driven by the spec in POL-154 economy design.
]]

local ProgressionSystem = {}

-- ═══════════════════════════════════════════════════════════════════
-- XP CURVE
-- ═══════════════════════════════════════════════════════════════════

local BASE_XP = 100
local XP_INCREMENT = 50

function ProgressionSystem.xpForLevel(level: number): number
	return BASE_XP + (level - 1) * XP_INCREMENT
end

-- ═══════════════════════════════════════════════════════════════════
-- XP EARNING (per race)
-- ═══════════════════════════════════════════════════════════════════

local XP_RACE_FINISH = 50
local XP_PLACEMENT: { [number]: number } = {
	[1] = 100,
	[2] = 60,
	[3] = 30,
}
local XP_PER_100_STUDS = 1
local XP_PER_PANEL_DESTROYED = 5
local XP_CLEAN_DRIVING = 25
local XP_PER_TRICK = 5

-- Trick thresholds
local AIRTIME_TRICK_THRESHOLD = 1.5
local DRIFT_TRICK_THRESHOLD = 2.0
local NEAR_MISS_DISTANCE = 5

export type RaceStats = {
	placement: number,
	finished: boolean,
	distanceTraveled: number,
	panelsDestroyed: number,
	damageTaken: number,
	airtimeTricks: number,
	driftTricks: number,
	nearMissTricks: number,
}

export type XPBreakdown = {
	raceFinish: number,
	placementBonus: number,
	distance: number,
	destruction: number,
	cleanDriving: number,
	stylePoints: number,
	total: number,
}

function ProgressionSystem.calculateXP(stats: RaceStats): XPBreakdown
	local breakdown: XPBreakdown = {
		raceFinish = 0,
		placementBonus = 0,
		distance = 0,
		destruction = 0,
		cleanDriving = 0,
		stylePoints = 0,
		total = 0,
	}

	if stats.finished then
		breakdown.raceFinish = XP_RACE_FINISH
	end

	breakdown.placementBonus = XP_PLACEMENT[stats.placement] or 0
	breakdown.distance = math.floor(stats.distanceTraveled / 100) * XP_PER_100_STUDS
	breakdown.destruction = stats.panelsDestroyed * XP_PER_PANEL_DESTROYED

	if stats.damageTaken == 0 then
		breakdown.cleanDriving = XP_CLEAN_DRIVING
	end

	local trickCount = stats.airtimeTricks + stats.driftTricks + stats.nearMissTricks
	breakdown.stylePoints = trickCount * XP_PER_TRICK

	breakdown.total = breakdown.raceFinish
		+ breakdown.placementBonus
		+ breakdown.distance
		+ breakdown.destruction
		+ breakdown.cleanDriving
		+ breakdown.stylePoints

	return breakdown
end

-- ═══════════════════════════════════════════════════════════════════
-- SCRAP EARNING (per race)
-- ═══════════════════════════════════════════════════════════════════

local SCRAP_BY_PLACEMENT: { [number]: number } = {
	[1] = 100,
	[2] = 75,
	[3] = 50,
}
local SCRAP_DEFAULT = 30
local SCRAP_DNF = 15

function ProgressionSystem.calculateScrap(placement: number, finished: boolean): number
	if not finished then
		return SCRAP_DNF
	end
	return SCRAP_BY_PLACEMENT[placement] or SCRAP_DEFAULT
end

-- ═══════════════════════════════════════════════════════════════════
-- LEVEL-UP REWARDS
-- ═══════════════════════════════════════════════════════════════════

local LEVEL_UP_SCRAP_BASE = 50
local LEVEL_UP_SCRAP_PER_LEVEL = 25

function ProgressionSystem.levelUpScrapBonus(newLevel: number): number
	return LEVEL_UP_SCRAP_BASE + (newLevel - 1) * LEVEL_UP_SCRAP_PER_LEVEL
end

-- ═══════════════════════════════════════════════════════════════════
-- DAILY LOGIN
-- ═══════════════════════════════════════════════════════════════════

local DAILY_REWARDS: { number } = {
	25,   -- Day 1
	50,   -- Day 2
	50,   -- Day 3
	75,   -- Day 4
	100,  -- Day 5
	100,  -- Day 6
	200,  -- Day 7
}

function ProgressionSystem.getDailyReward(day: number): number
	local idx = math.clamp(day, 1, 7)
	return DAILY_REWARDS[idx]
end

function ProgressionSystem.getDailyRewardsTable(): { number }
	return DAILY_REWARDS
end

-- ═══════════════════════════════════════════════════════════════════
-- VEHICLE UNLOCK CHECK (requires both level AND scrap)
-- ═══════════════════════════════════════════════════════════════════

function ProgressionSystem.canUnlockVehicle(
	playerLevel: number,
	playerScrap: number,
	requiredLevel: number,
	scrapCost: number
): (boolean, string?)
	if playerLevel < requiredLevel then
		return false, "Reach Level " .. requiredLevel
	end
	if playerScrap < scrapCost then
		return false, "Need " .. scrapCost .. " Scrap"
	end
	return true, nil
end

-- ═══════════════════════════════════════════════════════════════════
-- TRICK DETECTION THRESHOLDS (exported for client use)
-- ═══════════════════════════════════════════════════════════════════

ProgressionSystem.AIRTIME_TRICK_THRESHOLD = AIRTIME_TRICK_THRESHOLD
ProgressionSystem.DRIFT_TRICK_THRESHOLD = DRIFT_TRICK_THRESHOLD
ProgressionSystem.NEAR_MISS_DISTANCE = NEAR_MISS_DISTANCE

return ProgressionSystem
