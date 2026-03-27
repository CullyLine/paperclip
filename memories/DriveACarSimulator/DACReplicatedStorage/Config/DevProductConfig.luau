--!strict

local DevProductConfig = {}

DevProductConfig.Products = {
	coins_1k = {
		id = "coins_1k",
		name = "1,000 Coins",
		robuxPrice = 49,
		description = "Instant: 1,000 coins. Top up fast for upgrades and keep your run streak going.",
		productId = 0,
		reward = { currency = "coins", amount = 1_000 },
	},
	coins_10k = {
		id = "coins_10k",
		name = "10,000 Coins",
		robuxPrice = 149,
		description = "Instant: 10,000 coins. Enough for cars, eggs, and rebirth fuel without the grind.",
		productId = 0,
		reward = { currency = "coins", amount = 10_000 },
	},
	coins_100k = {
		id = "coins_100k",
		name = "100,000 Coins",
		robuxPrice = 399,
		description = "Instant: 100,000 coins. Skip tiers and buy what others are still saving for.",
		productId = 0,
		reward = { currency = "coins", amount = 100_000 },
	},
	coins_1m = {
		id = "coins_1m",
		name = "1,000,000 Coins",
		robuxPrice = 999,
		description = "Instant: 1,000,000 coins. Maximum coin power — compete with the heaviest spenders in the server.",
		productId = 0,
		reward = { currency = "coins", amount = 1_000_000 },
	},

	instant_rebirth = {
		id = "instant_rebirth",
		name = "Instant Rebirth",
		robuxPrice = 299,
		description = "Instant: rebirth now with no coin requirement. Reach the next multiplier while others are still saving.",
		productId = 0,
		reward = { type = "instant_rebirth" },
	},
	auto_hatch_3 = {
		id = "auto_hatch_3",
		name = "Auto-Hatch 3 Eggs",
		robuxPrice = 99,
		description = "Instant: open three eggs from inventory immediately. More chances at your best pets.",
		productId = 0,
		reward = { type = "auto_hatch", count = 3 },
	},
	skip_world = {
		id = "skip_world",
		name = "Skip World Unlock",
		robuxPrice = 499,
		description = "Instant: unlock the next world with no currency gate. Race ahead on progression and leaderboards.",
		productId = 0,
		reward = { type = "skip_world" },
	},

	starter_pack = {
		id = "starter_pack",
		name = "Starter Pack",
		robuxPrice = 199,
		description = "One-time bundle: 50K coins + 3 Meadow Eggs. Strongest day-one jump start (one purchase per account).",
		productId = 0,
		reward = { type = "starter_pack" },
	},
	battle_pass_premium = {
		id = "battle_pass_premium",
		name = "Battle Pass Premium Track",
		robuxPrice = 749,
		description = "Unlocks the premium column for Season 1: Midnight Velocity (one purchase per season). Everyone earns the same Pass XP; free rewards stay on the left, bonus rewards on the right — cosmetics, pets, titles, currency boosts, and the season car. Does not grant Pass XP by itself.",
		productId = 0,
		reward = { type = "battle_pass_premium" },
		-- Limited-time FOMO badge label (StorePanel EventExpiring row)
		eventBadgeLabel = "LAUNCH DRIVER",
		eventBadgeExpiresAt = 2000000000,
	},
}

return DevProductConfig
