--!strict
--[[
	Ceremony copy for major milestone celebrations.

	Triggered by MilestoneCeremonyService and VFX systems when a player
	crosses a rebirth tier, pet collection threshold, world mastery level,
	or total-runs landmark. Each category is a flat array of variant strings
	picked randomly at runtime. Placeholders: {COUNT}, {TIER}, {WORLD},
	{PERCENT}.

	Headlines: <=20 chars, ALL CAPS. Bodies: <=50 chars, sentence-case.
]]

local MilestoneCeremonyCopyConfig = {}

--------------------------------------------------------------------------
-- REBIRTH TIER CEREMONIES
-- Fired when a player crosses into a new prestige tier (5/10/25/50/100).
-- {TIER} = ceremonyTier from RebirthMilestoneConfig (short rank name, no "!").
-- {COUNT} = rebirth count. Economy: next rebirth cost = base × mult^rebirths (see RebirthConfig).
--------------------------------------------------------------------------

MilestoneCeremonyCopyConfig.RebirthCeremonyHeadlines = {
	"PRESTIGE UNLOCKED!",
	"NEW TIER REACHED!",
	"RANK UP!",
	"EVOLUTION!",
	"TIER ASCENSION!",
	"POWER SURGE!",
}

MilestoneCeremonyCopyConfig.RebirthCeremonyBodies = {
	"Rebirth {COUNT} — {TIER} status unlocked. That grind paid off!",
	"{TIER} rank at rebirth {COUNT}! Every reset cost more coins — you kept paying.",
	"You just crossed into {TIER}. Only drivers who reinvest hit this bar.",
	"Rebirth #{COUNT}: new title, permanent stat stack grows. The lobby notices.",
	"From starter to {TIER} — each rebirth asked more coins than the last. You delivered.",
	"Most accounts never reach {TIER}. You're funding the endgame fair and square.",
}

--------------------------------------------------------------------------
-- PET COLLECTION CEREMONIES
-- Fired at 25%, 50%, 75%, 100% pet index completion.
-- {PERCENT} = index completion %.
--------------------------------------------------------------------------

MilestoneCeremonyCopyConfig.CollectionCeremonyHeadlines = {
	"COLLECTOR STATUS!",
	"INDEX MILESTONE!",
	"GOTTA HATCH 'EM ALL!",
	"PET EMPIRE!",
	"HATCH MASTER!",
}

MilestoneCeremonyCopyConfig.CollectionCeremonyBodies = {
	"{PERCENT}% of every pet EVER! The index bows to you!",
	"Pet index at {PERCENT}% — most players never crack 10%.",
	"Your collection is at {PERCENT}%. That's not luck, that's GRIND.",
	"{PERCENT}% complete! The rarest hatches still await — keep cracking!",
	"Index milestone: {PERCENT}%! Other players are checking YOUR stats.",
	"At {PERCENT}% you've seen things most trainers only dream of!",
}

--------------------------------------------------------------------------
-- WORLD MASTERY CEREMONIES
-- Fired when a player completes all quests + coins threshold in a world.
-- {WORLD} = world display name.
--------------------------------------------------------------------------

MilestoneCeremonyCopyConfig.WorldMasteryCeremonyHeadlines = {
	"WORLD MASTERED!",
	"MAP CONQUERED!",
	"TOTAL DOMINION!",
	"WORLD COMPLETE!",
	"ROAD KING!",
}

MilestoneCeremonyCopyConfig.WorldMasteryCeremonyBodies = {
	"Every road in {WORLD} knows your name. Absolute domination!",
	"{WORLD} — fully conquered! Nothing left to prove here.",
	"You've squeezed every coin out of {WORLD}. Perfection!",
	"{WORLD} mastered! The map just got a whole lot smaller.",
	"Total domination of {WORLD}! Time to set your sights higher.",
	"Not a single corner of {WORLD} left untouched. RESPECT.",
}

--------------------------------------------------------------------------
-- TOTAL RUNS CEREMONIES
-- Fired at major run milestones: 100, 500, 1000, 5000, 10000.
-- {COUNT} = total completed runs.
--------------------------------------------------------------------------

MilestoneCeremonyCopyConfig.TotalRunsCeremonyHeadlines = {
	"ROAD WARRIOR!",
	"MILES LOGGED!",
	"ENDLESS DRIVER!",
	"MARATHON MODE!",
	"TIRELESS!",
}

MilestoneCeremonyCopyConfig.TotalRunsCeremonyBodies = {
	"{COUNT} runs complete! Your tires should be dust by now.",
	"Run #{COUNT} in the books. The asphalt remembers every one.",
	"{COUNT} runs — that's not a hobby, that's a CAREER.",
	"You've finished {COUNT} runs — long-haul dedication, front and center!",
	"{COUNT} laps around the simulator. You're basically PART of the road.",
	"Run milestone: {COUNT}! The engine never stops for you.",
}

--------------------------------------------------------------------------
-- TOTAL RUNS THRESHOLDS + SOCIAL PROOF
--------------------------------------------------------------------------

MilestoneCeremonyCopyConfig.TotalRunsFlexText = {
	[100]   = "Top 30% of drivers hit 100 runs. You're in the club!",
	[500]   = "Only 10% of players ever complete 500 runs. You're elite!",
	[1000]  = "1,000 runs — fewer than 3% reach this. Walking legend!",
	[5000]  = "5K runs! Under 0.5% of ALL players. Hall of fame material!",
	[10000] = "TEN THOUSAND RUNS. The rarest milestone in the game. Eternal!",
}

--------------------------------------------------------------------------
-- HELPER
--------------------------------------------------------------------------

function MilestoneCeremonyCopyConfig.pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

return MilestoneCeremonyCopyConfig
