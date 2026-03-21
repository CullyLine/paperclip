--!strict

local GamePassConfig = {}

GamePassConfig.Passes = {
	double_coins = {
		id = "double_coins",
		name = "2x Coins",
		robuxPrice = 399,
		description = "Double ALL coin earnings. Forever. The single best investment you can make.",
		gamePassId = 0,
	},
	double_speed = {
		id = "double_speed",
		name = "2x Speed",
		robuxPrice = 499,
		description = "Double your base speed stat on every car. Go twice as far in the same tank of gas.",
		gamePassId = 0,
	},
	auto_collect = {
		id = "auto_collect",
		name = "Auto-Collect",
		robuxPrice = 299,
		description = "Automatically bank your distance earnings. No need to end your run manually.",
		gamePassId = 0,
	},
	vip = {
		id = "vip",
		name = "VIP",
		robuxPrice = 799,
		description = "VIP chat tag, exclusive car skin, name glow. Show everyone you mean business.",
		gamePassId = 0,
	},
	extra_pet_slots = {
		id = "extra_pet_slots",
		name = "Extra Pet Slots",
		robuxPrice = 499,
		description = "Double your active pet team from 8 to 16. Double the pets, double the modifier.",
		gamePassId = 0,
	},
	lucky_eggs = {
		id = "lucky_eggs",
		name = "Lucky Eggs",
		robuxPrice = 599,
		description = "2x chance for rare, epic, legendary, and mythic pets from all eggs.",
		gamePassId = 0,
	},
	infinite_gas = {
		id = "infinite_gas",
		name = "Infinite Gas",
		robuxPrice = 999,
		description = "Your gas never depletes. Drive forever. The ultimate power move.",
		gamePassId = 0,
	},
	ultra_lucky = {
		id = "ultra_lucky",
		name = "Ultra Lucky",
		robuxPrice = 1299,
		description = "Massively increased rare+ pet odds from eggs. Stacks with Lucky Eggs.",
		gamePassId = 0,
	},
	auto_drive = {
		id = "auto_drive",
		name = "Auto-Drive",
		robuxPrice = 699,
		description = "Smooth auto-steering assist. Easier runs on mobile.",
		gamePassId = 0,
	},
	gas_3x = {
		id = "gas_3x",
		name = "3x Gas",
		robuxPrice = 799,
		description = "Triple your gas tank size on every car (before Infinite Gas).",
		gamePassId = 0,
	},
	pet_magnet = {
		id = "pet_magnet",
		name = "Pet Magnet",
		robuxPrice = 399,
		description = "+10% effective pet coin modifier from your team.",
		gamePassId = 0,
	},
	rebirth_rush = {
		id = "rebirth_rush",
		name = "Rebirth Rush",
		robuxPrice = 599,
		description = "Rebirth coin costs are 25% cheaper.",
		gamePassId = 0,
	},
	coin_boost = {
		id = "coin_boost",
		name = "Coin Boost",
		robuxPrice = 349,
		description = "+10% coins from every run completion.",
		gamePassId = 0,
	},
}

return GamePassConfig
