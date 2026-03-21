--!strict
--[[
	Season 1 battle pass: 50 tiers, 15,000 total XP curve per Season1_ContentPlan.md
]]

local BattlePassConfig = {}

BattlePassConfig.Season = {
	id = "s1_midnight_velocity",
	name = "Season 1: Midnight Velocity",
	startDate = 0,
	endDate = 0,
	premiumRobuxPrice = 749,
}

BattlePassConfig.TIER_COUNT = 50

local function buildXpPerTier(): { number }
	local t: { number } = {}
	for i = 1, 10 do
		t[i] = 150
	end
	for i = 11, 20 do
		t[i] = 200
	end
	for i = 21, 30 do
		t[i] = 300
	end
	for i = 31, 40 do
		t[i] = 400
	end
	for i = 41, 50 do
		t[i] = 450
	end
	return t
end

BattlePassConfig.xpPerTier = buildXpPerTier()

local function C(n: number)
	return { type = "coins", amount = n }
end
local function G(n: number)
	return { type = "gems", amount = n }
end
local function Cr(n: number)
	return { type = "crystals", amount = n }
end
local function N()
	return { type = "none" }
end
local function SB(n: number)
	return { type = "speed_boost", amount = n }
end
local function LB(n: number)
	return { type = "luck_boost", amount = n }
end
local function COS(id: string)
	return { type = "cosmetic", cosmeticId = id }
end
local function PET(id: string)
	return { type = "pet", petId = id }
end
local function CAR(id: string)
	return { type = "exclusive_car", carId = id }
end
local function TI(id: string)
	return { type = "title", titleId = id }
end
local function BD()
	return { type = "bundle", items = { SB(10), LB(10) } }
end

-- Full table from Season1_ContentPlan.md §2 "Full 50-Tier Reward Table"
BattlePassConfig.Tiers = {
	{ freeReward = C(2500), premiumReward = C(5000) },
	{ freeReward = N(), premiumReward = G(25) },
	{ freeReward = C(1000), premiumReward = SB(1) },
	{ freeReward = N(), premiumReward = G(50) },
	{ freeReward = COS("midnight_trail"), premiumReward = C(5000) },
	{ freeReward = C(2500), premiumReward = LB(1) },
	{ freeReward = N(), premiumReward = G(75) },
	{ freeReward = C(5000), premiumReward = C(10000) },
	{ freeReward = N(), premiumReward = SB(2) },
	{ freeReward = C(10000), premiumReward = Cr(10) },
	{ freeReward = N(), premiumReward = G(100) },
	{ freeReward = C(5000), premiumReward = COS("starlight_trail") },
	{ freeReward = N(), premiumReward = C(15000) },
	{ freeReward = C(2500), premiumReward = LB(2) },
	{ freeReward = C(10000), premiumReward = G(150) },
	{ freeReward = N(), premiumReward = SB(3) },
	{ freeReward = C(5000), premiumReward = C(20000) },
	{ freeReward = N(), premiumReward = G(200) },
	{ freeReward = C(7500), premiumReward = LB(3) },
	{ freeReward = C(15000), premiumReward = TI("night_rider") },
	{ freeReward = N(), premiumReward = Cr(25) },
	{ freeReward = C(10000), premiumReward = G(250) },
	{ freeReward = N(), premiumReward = C(30000) },
	{ freeReward = C(5000), premiumReward = SB(5) },
	{ freeReward = PET("neon_firefly"), premiumReward = G(300) },
	{ freeReward = N(), premiumReward = C(50000) },
	{ freeReward = C(10000), premiumReward = LB(5) },
	{ freeReward = N(), premiumReward = Cr(50) },
	{ freeReward = C(15000), premiumReward = G(400) },
	{ freeReward = COS("headlight_glow_trail"), premiumReward = C(75000) },
	{ freeReward = N(), premiumReward = Cr(75) },
	{ freeReward = C(10000), premiumReward = SB(5) },
	{ freeReward = N(), premiumReward = G(500) },
	{ freeReward = C(20000), premiumReward = LB(5) },
	{ freeReward = N(), premiumReward = COS("neon_streak_trail") },
	{ freeReward = C(15000), premiumReward = C(100000) },
	{ freeReward = N(), premiumReward = Cr(100) },
	{ freeReward = C(25000), premiumReward = G(750) },
	{ freeReward = N(), premiumReward = BD() },
	{ freeReward = C(20000), premiumReward = PET("shadow_panther") },
	{ freeReward = N(), premiumReward = Cr(150) },
	{ freeReward = C(30000), premiumReward = G(1000) },
	{ freeReward = N(), premiumReward = C(200000) },
	{ freeReward = C(25000), premiumReward = LB(10) },
	{ freeReward = N(), premiumReward = TI("s1_veteran") },
	{ freeReward = C(50000), premiumReward = Cr(200) },
	{ freeReward = N(), premiumReward = G(1500) },
	{ freeReward = C(40000), premiumReward = C(500000) },
	{ freeReward = N(), premiumReward = Cr(300) },
	{ freeReward = C(75000), premiumReward = CAR("midnight_drifter") },
}

function BattlePassConfig.tierStartXp(tier: number): number
	if tier <= 1 then
		return 0
	end
	local sum = 0
	for i = 1, tier - 1 do
		sum += BattlePassConfig.xpPerTier[i]
	end
	return sum
end

function BattlePassConfig.tierFromXp(totalXp: number): (number, number)
	local xp = math.max(0, totalXp)
	local acc = 0
	for i = 1, BattlePassConfig.TIER_COUNT do
		local need = BattlePassConfig.xpPerTier[i]
		if xp < acc + need then
			return i, (xp - acc) / need
		end
		acc += need
	end
	return BattlePassConfig.TIER_COUNT, 1
end

return BattlePassConfig
