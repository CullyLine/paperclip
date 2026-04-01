--!strict
--[[
	Permanent game passes — keys MUST match GamePassService / CarService / PetService / etc.

	Economy context: main coin flow is checkpoints + near-miss + playtime (see CurrencyService).
	Removed: gas_3x (redundant with Infinite Gas), pet_magnet (merged into training_boost).

	Assign real gamePassId in Creator Dashboard before live; 0 = unlinked (Studio shows dev note).
]]

local GamePassConfig = {}

GamePassConfig.Passes = {
	-- Coin flow (stacks with Roblox Premium +50% in CurrencyService on the same sources)
	coin_boost = {
		id = "coin_boost",
		name = "Coin Boost",
		robuxPrice = 299,
		description = "Permanent: +10% coins from checkpoints, near-miss chains, and playtime bonuses. Stacks with 2x Coins and Roblox Premium.",
		gamePassId = 0,
	},
	double_coins = {
		id = "double_coins",
		name = "2x Coins",
		robuxPrice = 449,
		description = "Permanent: 2× coins from checkpoints, near-miss chains, and playtime bonuses. Best value for long-term progression. Stacks with Coin Boost and Premium.",
		gamePassId = 0,
	},

	-- Pets / eggs (EggService)
	training_boost = {
		id = "training_boost",
		name = "Training Boost",
		robuxPrice = 349,
		description = "Permanent: +15% to your pet training multiplier at the auto-train station (AFK power). Pets still do not affect driving payouts.",
		gamePassId = 0,
	},
	lucky_eggs = {
		id = "lucky_eggs",
		name = "Lucky Eggs",
		robuxPrice = 599,
		description = "Permanent: doubled odds for Rare through Mythic pets from every egg hatch.",
		gamePassId = 0,
	},
	ultra_lucky = {
		id = "ultra_lucky",
		name = "Ultra Lucky",
		robuxPrice = 1199,
		description = "Permanent: even stronger Rare+ pet odds from eggs. Stacks with Lucky Eggs for the best hatch rates.",
		gamePassId = 0,
	},

	-- Driving (CarService + client DrivingController)
	double_speed = {
		id = "double_speed",
		name = "2x Speed",
		robuxPrice = 499,
		description = "Permanent: 2× effective top-speed contribution from every car (Power stat). Same gas curve, more distance per run.",
		gamePassId = 0,
	},
	infinite_gas = {
		id = "infinite_gas",
		name = "Infinite Gas",
		robuxPrice = 849,
		description = "Permanent: fuel never runs out — nonstop laps for checkpoint grinding. Replaces the old “3× gas” pass.",
		gamePassId = 0,
	},
	auto_collect = {
		id = "auto_collect",
		name = "Auto-Collect",
		robuxPrice = 349,
		description = "Permanent: after enough laps in one run, you auto-bank and return to lobby — no manual stop. Great for long sessions.",
		gamePassId = 0,
	},
	auto_drive = {
		id = "auto_drive",
		name = "Auto-Drive",
		robuxPrice = 649,
		description = "Permanent: smoother steering assist for cleaner lines (especially on mobile).",
		gamePassId = 0,
	},

	-- Progression (RebirthService)
	rebirth_rush = {
		id = "rebirth_rush",
		name = "Rebirth Rush",
		robuxPrice = 599,
		description = "Permanent: rebirths cost 25% fewer coins. Reach the next training tier faster after each reset.",
		gamePassId = 0,
	},
	unlimited_rebirths = {
		id = "unlimited_rebirths",
		name = "Unlimited Rebirths",
		robuxPrice = 999,
		description = "Permanent: unlocks the bulk “Max Rebirths” purchase on the Rebirth panel when you can afford multiple at once.",
		gamePassId = 0,
	},

	-- Social / slots
	extra_pet_slots = {
		id = "extra_pet_slots",
		name = "Extra Pet Slots",
		robuxPrice = 549,
		description = "Permanent: equip up to 16 pets at once (up from 8) for a stronger training multiplier.",
		gamePassId = 0,
	},
	vip = {
		id = "vip",
		name = "VIP",
		robuxPrice = 749,
		description = "Permanent: VIP chat tag, cosmetic flair, and name glow. Supports the game — thank you!",
		gamePassId = 0,
	},
}

return GamePassConfig
