--!strict

local GamePassConfig = {}

GamePassConfig.Passes = {
	double_coins = {
		id = "double_coins",
		name = "2x Coins",
		robuxPrice = 399,
		description = "Permanent: double every coin you earn. Buy this first for the fastest long-term account growth in the server.",
		gamePassId = 0,
	},
	double_speed = {
		id = "double_speed",
		name = "2x Speed",
		robuxPrice = 499,
		description = "Permanent: double base speed on every car. Same fuel, more distance per run — more coins, more drops, faster prestige.",
		gamePassId = 0,
	},
	auto_collect = {
		id = "auto_collect",
		name = "Auto-Collect",
		robuxPrice = 299,
		description = "Permanent: bank distance earnings automatically. Never stop to collect coins — stay in the run.",
		gamePassId = 0,
	},
	vip = {
		id = "vip",
		name = "VIP",
		robuxPrice = 799,
		description = "Permanent: VIP chat tag, exclusive car skin, and name glow. Stand out the moment you join.",
		gamePassId = 0,
	},
	extra_pet_slots = {
		id = "extra_pet_slots",
		name = "Extra Pet Slots",
		robuxPrice = 499,
		description = "Permanent: equip up to 16 pets at once (up from 8). More modifiers and rarer combos on every run.",
		gamePassId = 0,
	},
	lucky_eggs = {
		id = "lucky_eggs",
		name = "Lucky Eggs",
		robuxPrice = 599,
		description = "Permanent: double the odds of Rare through Mythic pets from every egg. Hatch faster toward a top-tier collection.",
		gamePassId = 0,
	},
	infinite_gas = {
		id = "infinite_gas",
		name = "Infinite Gas",
		robuxPrice = 999,
		description = "Permanent: fuel never runs out. Nonstop runs and longer streaks — built for players who never want to park.",
		gamePassId = 0,
	},
	ultra_lucky = {
		id = "ultra_lucky",
		name = "Ultra Lucky",
		robuxPrice = 1299,
		description = "Permanent: stronger Rare+ odds from eggs. Stacks with Lucky Eggs — push for the best possible pet lineup.",
		gamePassId = 0,
	},
	auto_drive = {
		id = "auto_drive",
		name = "Auto-Drive",
		robuxPrice = 699,
		description = "Permanent: smooth auto-steering assist. Easier personal bests on mobile, cleaner lines on desktop.",
		gamePassId = 0,
	},
	gas_3x = {
		id = "gas_3x",
		name = "3x Gas",
		robuxPrice = 799,
		description = "Permanent: triple fuel on every car. Longer runs between refills — best paired with Infinite Gas for maximum distance.",
		gamePassId = 0,
	},
	pet_magnet = {
		id = "pet_magnet",
		name = "Pet Magnet",
		robuxPrice = 399,
		description = "Permanent: +10% effective pet coin power from your team. Small pass, big payoff when your roster is full.",
		gamePassId = 0,
	},
	rebirth_rush = {
		id = "rebirth_rush",
		name = "Rebirth Rush",
		robuxPrice = 599,
		description = "Permanent: rebirths cost 25% fewer coins. Reach the next multiplier tier before the rest of the lobby.",
		gamePassId = 0,
	},
	unlimited_rebirths = {
		id = "unlimited_rebirths",
		name = "Unlimited Rebirths",
		robuxPrice = 999,
		description = "Permanent: unlock the 'Max Rebirths' button — rebirth as many times as you can afford in one click.",
		gamePassId = 0,
	},
	coin_boost = {
		id = "coin_boost",
		name = "Coin Boost",
		robuxPrice = 349,
		description = "Permanent: +10% coins every time you finish a run. Always-on value that stacks with 2x Coins.",
		gamePassId = 0,
	},
}

return GamePassConfig
