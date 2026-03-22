--!strict
--[[
	Combo multiplier celebration copy.

	Shown when the player builds coin-multiplier combos during a run by
	chaining near-misses, collecting pickups, or maintaining speed streaks.
	Escalates from casual encouragement to full screaming hype as the combo
	climbs.

	Tiers:  x2-x4  (Building)
	        x5-x9  (Hot)
	        x10-x19 (On Fire)
	        x20-x49 (Legendary)
	        x50+    (Godlike)

	Placeholders: {COMBO} = current multiplier, {COINS} = bonus coins earned.
	Headlines: <=18 chars, ALL CAPS. Bodies: <=45 chars, mixed case.
]]

local ComboCelebrationConfig = {}

--------------------------------------------------------------------------
-- COMBO TIER THRESHOLDS
--------------------------------------------------------------------------

ComboCelebrationConfig.Tiers = {
	{ min = 2,  max = 4,  key = "building",  label = "BUILDING" },
	{ min = 5,  max = 9,  key = "hot",       label = "HOT" },
	{ min = 10, max = 19, key = "onFire",    label = "ON FIRE" },
	{ min = 20, max = 49, key = "legendary", label = "LEGENDARY" },
	{ min = 50, max = 999, key = "godlike",  label = "GODLIKE" },
}

--------------------------------------------------------------------------
-- COMBO HEADLINES — shown in the HUD combo toast
--------------------------------------------------------------------------

ComboCelebrationConfig.Headlines = {
	building = {
		"COMBO x{COMBO}!",
		"STACKING!",
		"KEEP IT UP!",
		"CHAIN STARTED!",
		"MULTIPLYING!",
		"NICE CHAIN!",
	},
	hot = {
		"x{COMBO} COMBO!",
		"HEATING UP!",
		"COMBO SURGE!",
		"COINS FLOWING!",
		"CAN'T STOP!",
		"ON A ROLL!",
	},
	onFire = {
		"x{COMBO}! ON FIRE!",
		"UNSTOPPABLE!",
		"BLAZING COMBO!",
		"MEGA CHAIN!",
		"COMBO INFERNO!",
		"DOUBLE DIGITS!",
	},
	legendary = {
		"x{COMBO}! LEGENDARY!",
		"COMBO LEGEND!",
		"INSANE CHAIN!",
		"COIN VOLCANO!",
		"UNTOUCHABLE!",
		"HISTORIC COMBO!",
	},
	godlike = {
		"x{COMBO}! GODLIKE!",
		"IMPOSSIBLE COMBO!",
		"COMBO GOD!",
		"BEYOND MORTAL!",
		"EXISTENCE: COMBO!",
		"SIMULATION ERROR!",
	},
}

--------------------------------------------------------------------------
-- COMBO BODIES — subtext beneath the headline
--------------------------------------------------------------------------

ComboCelebrationConfig.Bodies = {
	building = {
		"Chain those near-misses for BIGGER multipliers!",
		"Every dodge stacks your coins higher!",
		"The combo is building — don't crash NOW!",
		"x{COMBO} and climbing! Keep the streak alive!",
		"Multiplier active — every coin is worth MORE!",
		"Combo started! Drive clean to keep it going!",
	},
	hot = {
		"x{COMBO} multiplier! Your coins are STACKING!",
		"The combo is heating up — one mistake ends it!",
		"FIVE and beyond! The pressure is ON!",
		"Your wallet is getting HEAVIER by the second!",
		"Hot streak! Don't even THINK about crashing!",
		"Coins are POURING in at x{COMBO}! Stay focused!",
	},
	onFire = {
		"x{COMBO}! The server is tracking YOUR combo right now!",
		"Double-digit combo! Other players WISH they could do this!",
		"Your combo is writing history — DO NOT CRASH!",
		"x{COMBO} multiplier means INSANE payouts this run!",
		"The coin counter can barely keep up at x{COMBO}!",
		"ON FIRE! Every second at x{COMBO} is pure GOLD!",
	},
	legendary = {
		"x{COMBO}! This combo is now LEGENDARY. Hold on!",
		"Fewer than 1% of runs ever see x{COMBO}. YOU did!",
		"LEGENDARY combo — your run payout just EXPLODED!",
		"x{COMBO} multiplier! The game is MELTING for you!",
		"Combo so big the leaderboard is WATCHING. Don't drop!",
		"At x{COMBO}, every SECOND earns a normal player's run!",
	},
	godlike = {
		"x{COMBO}! The devs didn't plan for this. You BROKE it!",
		"GODLIKE! This combo is the stuff of LEGEND!",
		"x{COMBO} multiplier — your payout is ASTRONOMICAL!",
		"No one has EVER gone this long. You're making HISTORY!",
		"The coin explosion at x{COMBO} is off EVERY chart!",
		"SIMULATION can't handle x{COMBO}. This is GODLIKE!",
	},
}

--------------------------------------------------------------------------
-- COMBO BREAK / LOST COPY
-- Shown when the player crashes or the timer expires.
-- {COMBO} = final combo before break, {COINS} = bonus coins earned.
--------------------------------------------------------------------------

ComboCelebrationConfig.ComboBreak = {
	"x{COMBO} combo broken! But you banked +{COINS} bonus coins!",
	"COMBO LOST at x{COMBO}! Still earned +{COINS} extra. Not bad!",
	"Streak snapped at x{COMBO}! +{COINS} bonus coins secured.",
	"The combo falls at x{COMBO}! You still pocketed +{COINS}!",
	"x{COMBO} combo gone — but +{COINS} coins say it was WORTH IT!",
	"CRASH! x{COMBO} ended! The +{COINS} bonus lives on, though!",
}

ComboCelebrationConfig.ComboBreakMotivation = {
	"Build it back! The next combo could be BIGGER!",
	"One crash doesn't define you — GO AGAIN!",
	"Reset and RUN! Your best combo is still ahead!",
	"Combo down, but your skills are UP! Chain it back!",
	"That was JUST the warm-up. The real combo starts NOW!",
	"Pick it up! The road forgives — start another chain!",
}

--------------------------------------------------------------------------
-- COMBO PERSONAL BEST
-- {COMBO} = new best combo, {OLD} = previous best.
--------------------------------------------------------------------------

ComboCelebrationConfig.NewPersonalBest = {
	"NEW PERSONAL BEST! x{COMBO} combo! (was x{OLD})",
	"RECORD SHATTERED! x{COMBO} beats your old x{OLD}!",
	"PB BROKEN! x{COMBO} — you just outdid YOURSELF!",
	"YOUR BEST COMBO EVER! x{COMBO} obliterates x{OLD}!",
	"PERSONAL RECORD! x{COMBO}! The old you could never!",
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------

function ComboCelebrationConfig.getTierKey(combo: number): string
	for _, tier in ComboCelebrationConfig.Tiers do
		if combo >= tier.min and combo <= tier.max then
			return tier.key
		end
	end
	return "building"
end

function ComboCelebrationConfig.pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

return ComboCelebrationConfig
