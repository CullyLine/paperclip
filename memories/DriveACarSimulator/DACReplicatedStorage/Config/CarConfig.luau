--!strict

local CarConfig = {}

CarConfig.Cars = {
	starter = {
		id = "starter",
		name = "Rusty Runabout",
		modelName = "Travel",
		baseStats = { gas = 50, power = 10, speed = 30 },
		price = 0,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1, -- budget: minimal trail / rush juice
		description = "Your first ride. Slow, leaky, but it moves.",
	},
	sedan = {
		id = "sedan",
		name = "Street Cruiser",
		modelName = "Blue",
		baseStats = { gas = 70, power = 15, speed = 45 },
		price = 5_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1,
		description = "A reliable daily driver with room to grow.",
	},
	muscle = {
		id = "muscle",
		name = "Green Demon",
		modelName = "Green",
		baseStats = { gas = 60, power = 25, speed = 65 },
		price = 25_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Raw American muscle. Drinks gas like water.",
	},
	sports = {
		id = "sports",
		name = "Venom GT",
		modelName = "Orange",
		baseStats = { gas = 55, power = 35, speed = 90 },
		price = 100_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 3,
		description = "Built for speed. Not built for fuel economy.",
	},
	suv = {
		id = "suv",
		name = "Tank Roller",
		modelName = "Red",
		baseStats = { gas = 120, power = 20, speed = 40 },
		price = 50_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Massive gas tank. Goes forever, just not fast.",
	},

	dune_buggy = {
		id = "dune_buggy",
		name = "Sand Scorpion",
		modelName = "Yellow",
		baseStats = { gas = 80, power = 30, speed = 55 },
		price = 200_000,
		currency = "sandGranules",
		worldId = "desert",
		vfxTier = 3,
		description = "Desert-tuned and sun-hardened.",
	},
	hot_rod = {
		id = "hot_rod",
		name = "Inferno Rod",
		modelName = "Purple",
		baseStats = { gas = 50, power = 50, speed = 110 },
		price = 500_000,
		currency = "sandGranules",
		worldId = "desert",
		vfxTier = 4,
		description = "Barely street legal. Actually not street legal.",
	},

	snowmobile = {
		id = "snowmobile",
		name = "Frost Glider",
		modelName = "White",
		baseStats = { gas = 100, power = 40, speed = 70 },
		price = 5_000,
		currency = "icycles",
		worldId = "ice",
		vfxTier = 2,
		description = "Cuts through snow like butter.",
	},
	ice_racer = {
		id = "ice_racer",
		name = "Glacier Phantom",
		modelName = "Silver",
		baseStats = { gas = 75, power = 60, speed = 140 },
		price = 25_000,
		currency = "icycles",
		worldId = "ice",
		vfxTier = 4,
		description = "So fast it leaves frost trails.",
	},

	cyber_car = {
		id = "cyber_car",
		name = "Neon Pulse",
		modelName = "Cyan",
		baseStats = { gas = 90, power = 80, speed = 180 },
		price = 10_000,
		currency = "magmaCores",
		worldId = "volcano",
		vfxTier = 4,
		description = "From the future. Runs on pure energy.",
	},
	hyper_car = {
		id = "hyper_car",
		name = "Void Runner",
		modelName = "Black",
		baseStats = { gas = 70, power = 100, speed = 250 },
		price = 50_000,
		currency = "magmaCores",
		worldId = "volcano",
		vfxTier = 5,
		description = "The fastest thing on any highway. Period.",
	},

	midnight_drifter = {
		id = "midnight_drifter",
		name = "Midnight Drifter",
		modelName = "midnight_drifter",
		baseStats = { gas = 85, power = 55, speed = 120 },
		price = 0,
		currency = "coins",
		worldId = "forest",
		vfxTier = 5,
		description = "The crown jewel of Season 1. Matte black with electric-blue underglow. Usable in all worlds.",
	},
}

--[[
	1–5 scale for driving VFX (wheel trails, speed rush, boost stars, underglow).
	Higher tiers read as more "power" without changing physics — keeps monetized cars feel special.
]]
function CarConfig.getVehicleVfxTier(carId: string): number
	local def = CarConfig.Cars[carId]
	if def and type((def :: any).vfxTier) == "number" then
		return math.clamp((def :: any).vfxTier :: number, 1, 5)
	end
	if def and def.baseStats and type(def.baseStats.speed) == "number" then
		local s = def.baseStats.speed
		if s <= 40 then
			return 1
		elseif s <= 55 then
			return 2
		elseif s <= 95 then
			return 3
		elseif s <= 140 then
			return 4
		end
		return 5
	end
	return 2
end

function CarConfig.getCarTemplateName(carId: string): string
	local def = CarConfig.Cars[carId]
	if def and def.modelName then
		return def.modelName
	end
	return carId
end

function CarConfig.listCarIds(): { string }
	local ids = {}
	for id in CarConfig.Cars do
		table.insert(ids, id)
	end
	return ids
end

return CarConfig
