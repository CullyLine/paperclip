--!strict
--[[
	Achievement popup text for the notification HUD.

	**IDs must match AchievementService.tryUnlock** — only server-backed
	achievements appear here so the trophy grid stays honest.

	Each achievement: short title (<=20 chars, ALL CAPS), description (<=60 chars).

	Placeholders: {COUNT}, {SPEED}, {WORLD}, {PET}, {COINS}, {PERCENT}.

	Trophy metallic tiers (border/toast intensity) are NOT pet egg rarities
	(common…mythic). Use RarityTiers for display labels + voice.
]]

local AchievementPopupConfig = {}

--[[
	Metallic trophy tier → HUD label + optional subtitle pattern (whale-forward).
	Keys match server RARITY_BY_ID / client rarityForId (bronze | silver | gold | diamond).
]]
AchievementPopupConfig.RarityTiers = {
	bronze = { label = "BRONZE", subtitle = "Starter shine — first milestones & quick wins" },
	silver = { label = "SILVER", subtitle = "Mid grind — streaks, spends, and flex" },
	gold = { label = "GOLD", subtitle = "Heavy flex — grinds, prestige beats, top ranks" },
	diamond = { label = "DIAMOND", subtitle = "Crown jewels — completionist endgame" },
}

--------------------------------------------------------------------------
-- ACHIEVEMENT DEFINITIONS
-- id = internal key (must match AchievementService.tryUnlock), title, description.
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
		id = "world_tourer",
		title = "WORLD TOURER!",
		description = "Complete a run in every world you've unlocked.",
		category = "driving",
	},
	{
		id = "runs_10",
		title = "ROAD REGULAR!",
		description = "Complete 10 runs. You're getting the hang of it!",
		category = "driving",
	},
	{
		id = "runs_100",
		title = "HIGHWAY VETERAN!",
		description = "Complete 100 runs. The asphalt knows your name!",
		category = "driving",
	},
	{
		id = "combo_inferno",
		title = "COMBO INFERNO!",
		description = "Hit a ×20 near-miss chain in a single run. Untouchable!",
		category = "driving",
	},
	{
		id = "garage_full",
		title = "FULL GARAGE!",
		description = "Own every car in the showroom. Collector supreme!",
		category = "driving",
	},
	{
		id = "world_elite",
		title = "WORLD ELITE!",
		description = "Complete world mastery for the final map. End of the road!",
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
		id = "hatch_100",
		title = "HATCH CENTURY!",
		description = "Hatch 100 eggs total. Keep cracking!",
		category = "collection",
	},
	{
		id = "full_index",
		title = "COMPLETIONIST!",
		description = "Discover every pet in the index. Every. Single. One!",
		category = "collection",
	},
	{
		id = "legendary_hatch",
		title = "JACKPOT HATCH!",
		description = "Hatch a Legendary or Mythic pet from an egg!",
		category = "collection",
	},

	-- ECONOMY
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
		id = "coin_tycoon",
		title = "COIN TYCOON!",
		description = "Earn 1,000,000 lifetime coins. The economy runs through you!",
		category = "economy",
	},

	-- SOCIAL
	{
		id = "daily_streak_7",
		title = "WEEK WARRIOR!",
		description = "Hit a 7-day login streak.",
		category = "social",
	},
	{
		id = "number_one",
		title = "#1 DRIVER!",
		description = "Reach #1 on a leaderboard. KING!",
		category = "social",
	},
	{
		id = "top_ten",
		title = "TOP 10 TITAN!",
		description = "Break into the top 10 on a global leaderboard!",
		category = "social",
	},
	{
		id = "daily_streak_30",
		title = "MONTH MONSTER!",
		description = "Maintain a 30-day login streak. Dedication!",
		category = "social",
	},
	{
		id = "quest_veteran",
		title = "QUEST VETERAN!",
		description = "Complete 10 quests total. Always on the board!",
		category = "social",
	},

	-- SECRET
	{
		id = "egg_hunter",
		title = "EGG HUNTER!",
		description = "Discover a hidden easter egg in the world!",
		category = "secret",
	},
	{
		id = "night_owl",
		title = "NIGHT OWL!",
		description = "60+ minutes in one session — the road never sleeps!",
		category = "secret",
	},
	{
		id = "secret_speed_demon",
		title = "MACH 500!",
		description = "Hit 500+ speed in one run. Pure engine violence!",
		category = "secret",
	},
	{
		id = "egg_straordinary",
		title = "EGG-STRAORDINARY!",
		description = "Legendary/Mythic from a Basic Egg. Luck on a budget!",
		category = "secret",
	},
	{
		id = "lap_legend",
		title = "LAP LEGEND!",
		description = "100 laps in one run. The highway is your treadmill!",
		category = "secret",
	},
	{
		id = "rebirth_royalty",
		title = "REBIRTH ROYALTY!",
		description = "Reach Rebirth 10. The crown belongs to the persistent!",
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
	"TROPHY UNLOCKED: {TITLE}",
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
		"FULL COLLECTION SWEEP! Every species in the index — YOURS!",
		"Collection achievements DONE. The index has been CONQUERED!",
		"All collection trophies earned. Hatch master CONFIRMED!",
	},
	economy = {
		"ECONOMY MASTERED! Spending and rebirths — ALL conquered!",
		"Every economy achievement unlocked. You're the TYCOON!",
		"Full economy sweep! The vault overflows with your legacy!",
	},
	social = {
		"SOCIAL LEGEND! Leaderboards and streaks — ALL DONE!",
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
	"100% ACHIEVEMENTS! Every challenge, every trophy — YOURS!",
	"TOTAL COMPLETION! You've done EVERYTHING. The game bows to you!",
	"ALL ACHIEVEMENTS UNLOCKED! The rarest accomplishment in the game!",
	"PERFECTION! Every achievement earned. You are the ULTIMATE driver!",
	"100% COMPLETE! Full trophy sweep — one of the rarest flexes in the game!",
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
