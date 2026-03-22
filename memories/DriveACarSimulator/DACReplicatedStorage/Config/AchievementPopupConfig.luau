--!strict
--[[
	Achievement popup text for the notification HUD.

	Covers every category of unlockable achievement: driving, collection,
	economy, social, and secret achievements. Each achievement has a short
	title (<=20 chars, ALL CAPS), a description (<=60 chars), and a
	celebratory toast line (flat variant pool picked randomly).

	Placeholders: {COUNT}, {SPEED}, {WORLD}, {PET}, {COINS}, {PERCENT}.
]]

local AchievementPopupConfig = {}

--------------------------------------------------------------------------
-- ACHIEVEMENT DEFINITIONS
-- id = internal key, title = display name, description = unlock criteria.
--------------------------------------------------------------------------

AchievementPopupConfig.Achievements = {
	-- DRIVING
	{
		id = "first_drive",
		title = "FIRST DRIVE!",
		description = "Complete your very first run.",
		category = "driving",
	},
	{
		id = "speed_demon",
		title = "SPEED DEMON!",
		description = "Reach 100 studs/s in a single run.",
		category = "driving",
	},
	{
		id = "centurion_runs",
		title = "CENTURION!",
		description = "Complete 100 runs. The road warrior awakens!",
		category = "driving",
	},
	{
		id = "marathon_driver",
		title = "MARATHON DRIVER!",
		description = "Complete 1,000 runs. Tireless legend!",
		category = "driving",
	},
	{
		id = "near_miss_king",
		title = "NEAR MISS KING!",
		description = "Chain 10 near-misses in a single run.",
		category = "driving",
	},
	{
		id = "combo_master",
		title = "COMBO MASTER!",
		description = "Reach a x20 combo multiplier. Legendary chain!",
		category = "driving",
	},
	{
		id = "world_tourer",
		title = "WORLD TOURER!",
		description = "Complete a run in every unlocked world.",
		category = "driving",
	},
	{
		id = "speed_god",
		title = "SPEED GOD!",
		description = "Hit 1,000 studs/s. Simulation broken!",
		category = "driving",
	},

	-- COLLECTION
	{
		id = "first_hatch",
		title = "EGG CRACKER!",
		description = "Hatch your very first pet.",
		category = "collection",
	},
	{
		id = "rare_find",
		title = "RARE FIND!",
		description = "Hatch a Rare pet. The luck begins!",
		category = "collection",
	},
	{
		id = "epic_moment",
		title = "EPIC MOMENT!",
		description = "Hatch an Epic pet. Against the odds!",
		category = "collection",
	},
	{
		id = "legendary_pull",
		title = "LEGENDARY PULL!",
		description = "Hatch a Legendary pet. 0.5% odds crushed!",
		category = "collection",
	},
	{
		id = "mythic_miracle",
		title = "MYTHIC MIRACLE!",
		description = "Hatch a Mythical pet. One in ten thousand!",
		category = "collection",
	},
	{
		id = "half_index",
		title = "HALF THE INDEX!",
		description = "Collect 50% of all pets. Dedicated curator!",
		category = "collection",
	},
	{
		id = "full_index",
		title = "COMPLETIONIST!",
		description = "Collect 100% of all pets. Every. Single. One!",
		category = "collection",
	},

	-- ECONOMY
	{
		id = "first_million",
		title = "MILLIONAIRE!",
		description = "Earn 1,000,000 total coins. Money moves!",
		category = "economy",
	},
	{
		id = "gem_hoarder",
		title = "GEM HOARDER!",
		description = "Accumulate 500 gems. Sparkling!",
		category = "economy",
	},
	{
		id = "big_spender",
		title = "BIG SPENDER!",
		description = "Spend 500,000 coins in the shop. Baller!",
		category = "economy",
	},
	{
		id = "rebirth_one",
		title = "REBORN!",
		description = "Complete your first rebirth. Power surge!",
		category = "economy",
	},
	{
		id = "rebirth_ten",
		title = "ELITE REBIRTHER!",
		description = "Reach 10 rebirths. Top-tier commitment!",
		category = "economy",
	},
	{
		id = "rebirth_hundred",
		title = "IMMORTAL!",
		description = "100 rebirths. Nothing left to prove!",
		category = "economy",
	},

	-- SOCIAL
	{
		id = "leaderboard_debut",
		title = "ON THE BOARD!",
		description = "Appear on any leaderboard for the first time.",
		category = "social",
	},
	{
		id = "top_ten",
		title = "TOP TEN!",
		description = "Reach top 10 on any leaderboard. Elite!",
		category = "social",
	},
	{
		id = "number_one",
		title = "#1 DRIVER!",
		description = "Claim the #1 spot on a leaderboard. KING!",
		category = "social",
	},
	{
		id = "daily_streak_7",
		title = "WEEK WARRIOR!",
		description = "Maintain a 7-day login streak.",
		category = "social",
	},
	{
		id = "daily_streak_30",
		title = "MONTHLY MASTER!",
		description = "30-day login streak. True dedication!",
		category = "social",
	},
	{
		id = "quest_grinder",
		title = "QUEST GRINDER!",
		description = "Complete 50 quests. Mission machine!",
		category = "social",
	},

	-- SECRET
	{
		id = "easter_egg",
		title = "EGG HUNTER!",
		description = "Find a hidden easter egg. Sharp eyes!",
		category = "secret",
	},
	{
		id = "max_car",
		title = "GARAGE KING!",
		description = "Own every car in the game. Full fleet!",
		category = "secret",
	},
	{
		id = "world_master",
		title = "WORLD MASTER!",
		description = "Master every world. Total domination!",
		category = "secret",
	},
}

--------------------------------------------------------------------------
-- UNLOCK TOAST LINES
-- Shown in the popup when any achievement unlocks.
-- {TITLE} = achievement title.
--------------------------------------------------------------------------

AchievementPopupConfig.UnlockToastLines = {
	"ACHIEVEMENT UNLOCKED! {TITLE}",
	"NEW ACHIEVEMENT! {TITLE}",
	"🏆 UNLOCKED: {TITLE}",
	"YOU DID IT! {TITLE}",
	"TROPHY EARNED! {TITLE}",
	"ACHIEVEMENT GET! {TITLE}",
}

--------------------------------------------------------------------------
-- CATEGORY CELEBRATION COPY
-- Shown when ALL achievements in a category are complete.
--------------------------------------------------------------------------

AchievementPopupConfig.CategoryComplete = {
	driving = {
		"ALL DRIVING ACHIEVEMENTS COMPLETE! You own the road!",
		"Every driving challenge CRUSHED. Nothing left on asphalt!",
		"Full driving sweep! The ultimate road warrior!",
	},
	collection = {
		"FULL COLLECTION SWEEP! Every pet, every rarity — YOURS!",
		"Collection achievements DONE. The index has been CONQUERED!",
		"All collection trophies earned. Hatch master CONFIRMED!",
	},
	economy = {
		"ECONOMY MASTERED! Coins, gems, rebirths — ALL conquered!",
		"Every economy achievement unlocked. You're the TYCOON!",
		"Full economy sweep! The vault overflows with your legacy!",
	},
	social = {
		"SOCIAL LEGEND! Leaderboards, streaks, quests — ALL DONE!",
		"Every social achievement earned. The server knows your NAME!",
		"Social sweep complete! Community ROYALTY!",
	},
	secret = {
		"ALL SECRETS FOUND! Nothing is hidden from you!",
		"Secret achievements COMPLETE. You found EVERYTHING!",
		"The last secret falls. True completionist energy!",
	},
}

--------------------------------------------------------------------------
-- TOTAL COMPLETION
-- Shown when every single achievement is unlocked.
--------------------------------------------------------------------------

AchievementPopupConfig.TotalCompletion = {
	"🏆 100% ACHIEVEMENTS! Every challenge, every secret, every trophy — YOURS!",
	"TOTAL COMPLETION! You've done EVERYTHING. The game bows to you!",
	"ALL ACHIEVEMENTS UNLOCKED! The rarest accomplishment in the game!",
	"PERFECTION! Every achievement earned. You are the ULTIMATE driver!",
	"100% COMPLETE! Fewer than 0.01% of players will EVER stand here!",
}

--------------------------------------------------------------------------
-- PROGRESS NUDGE — shown when a player is close to an achievement
-- {TITLE} = achievement title, {PERCENT} = progress %.
--------------------------------------------------------------------------

AchievementPopupConfig.ProgressNudge = {
	"Almost there! {PERCENT}% to {TITLE}! Keep pushing!",
	"So CLOSE to {TITLE}! Just a little more!",
	"{PERCENT}% to {TITLE}! Don't stop now!",
	"The {TITLE} achievement is WITHIN REACH! ({PERCENT}%)",
	"Nearly {TITLE}! Finish what you started!",
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------

function AchievementPopupConfig.pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

function AchievementPopupConfig.getAchievementById(id: string): { id: string, title: string, description: string, category: string }?
	for _, ach in AchievementPopupConfig.Achievements do
		if ach.id == id then
			return ach
		end
	end
	return nil
end

function AchievementPopupConfig.getAchievementsByCategory(category: string): { { id: string, title: string, description: string, category: string } }
	local results = {}
	for _, ach in AchievementPopupConfig.Achievements do
		if ach.category == category then
			table.insert(results, ach)
		end
	end
	return results
end

return AchievementPopupConfig
