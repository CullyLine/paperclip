--!strict

local DevProductConfig = {}

DevProductConfig.Products = {
	coins_1k = {
		id = "coins_1k",
		name = "1,000 Coins",
		robuxPrice = 49,
		description = "A quick boost to get started.",
		productId = 0,
		reward = { currency = "coins", amount = 1_000 },
	},
	coins_10k = {
		id = "coins_10k",
		name = "10,000 Coins",
		robuxPrice = 149,
		description = "Enough to buy your next car.",
		productId = 0,
		reward = { currency = "coins", amount = 10_000 },
	},
	coins_100k = {
		id = "coins_100k",
		name = "100,000 Coins",
		robuxPrice = 399,
		description = "Skip the grind. Get straight to upgrades.",
		productId = 0,
		reward = { currency = "coins", amount = 100_000 },
	},
	coins_1m = {
		id = "coins_1m",
		name = "1,000,000 Coins",
		robuxPrice = 999,
		description = "Millionaire status. Instant.",
		productId = 0,
		reward = { currency = "coins", amount = 1_000_000 },
	},

	gems_100 = {
		id = "gems_100",
		name = "100 Gems",
		robuxPrice = 99,
		description = "A handful of gems.",
		productId = 0,
		reward = { currency = "gems", amount = 100 },
	},
	gems_1k = {
		id = "gems_1k",
		name = "1,000 Gems",
		robuxPrice = 399,
		description = "Serious gem investment.",
		productId = 0,
		reward = { currency = "gems", amount = 1_000 },
	},
	gems_pack_m = {
		id = "gems_pack_m",
		name = "3,000 Gems",
		robuxPrice = 599,
		description = "Mid-tier gem pack.",
		productId = 0,
		reward = { currency = "gems", amount = 3_000 },
	},

	crystals_50 = {
		id = "crystals_50",
		name = "50 Crystals",
		robuxPrice = 199,
		description = "Premium currency for premium players.",
		productId = 0,
		reward = { currency = "crystals", amount = 50 },
	},
	crystals_500 = {
		id = "crystals_500",
		name = "500 Crystals",
		robuxPrice = 799,
		description = "Enough crystals to unlock anything.",
		productId = 0,
		reward = { currency = "crystals", amount = 500 },
	},

	instant_rebirth = {
		id = "instant_rebirth",
		name = "Instant Rebirth",
		robuxPrice = 299,
		description = "Rebirth immediately without meeting the coin requirement.",
		productId = 0,
		reward = { type = "instant_rebirth" },
	},
	auto_hatch_3 = {
		id = "auto_hatch_3",
		name = "Auto-Hatch 3 Eggs",
		robuxPrice = 99,
		description = "Instantly hatch 3 eggs from your inventory.",
		productId = 0,
		reward = { type = "auto_hatch", count = 3 },
	},
	skip_world = {
		id = "skip_world",
		name = "Skip World Unlock",
		robuxPrice = 499,
		description = "Instantly unlock the next world without meeting the currency requirement.",
		productId = 0,
		reward = { type = "skip_world" },
	},

	gems_pack_l = {
		id = "gems_pack_l",
		name = "Gem Pack L",
		robuxPrice = 999,
		description = "10,000 gems.",
		productId = 0,
		reward = { currency = "gems", amount = 10_000 },
	},
	crystals_pack_l = {
		id = "crystals_pack_l",
		name = "Crystal Pack L",
		robuxPrice = 1999,
		description = "5,000 crystals.",
		productId = 0,
		reward = { currency = "crystals", amount = 5_000 },
	},
	starter_pack = {
		id = "starter_pack",
		name = "Starter Pack",
		robuxPrice = 199,
		description = "One-time: 25K coins, 500 gems, 3 Meadow Eggs.",
		productId = 0,
		reward = { type = "starter_pack" },
	},
	battle_pass_premium = {
		id = "battle_pass_premium",
		name = "Battle Pass Premium",
		robuxPrice = 749,
		description = "Unlock the premium reward track for Season 1: Midnight Velocity.",
		productId = 0,
		reward = { type = "battle_pass_premium" },
	},
}

return DevProductConfig
