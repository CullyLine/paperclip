--!strict

local CarConfig = {}

--[[
	Vehicle stats:
	  gas          – fuel capacity in gallons; determines how far you can drive before the run ends.
	  power        – base top speed contribution; effective speed = car.power + trainedPower.
	  acceleration – seconds to reach top speed; hidden from player, not upgradeable per-car.
]]
CarConfig.Cars = {
	starter = {
		id = "starter",
		name = "Rusty Runabout",
		modelName = "Travel",
		baseStats = { gas = 20, power = 35, acceleration = 30 },
		price = 0,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1,
		description = "Your first ride. Slow, leaky, but it moves.",
	},
	sedan = {
		id = "sedan",
		name = "Street Cruiser",
		modelName = "Blue",
		baseStats = { gas = 28, power = 45, acceleration = 25 },
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
		baseStats = { gas = 22, power = 60, acceleration = 20 },
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
		baseStats = { gas = 18, power = 80, acceleration = 14 },
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
		baseStats = { gas = 45, power = 40, acceleration = 28 },
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
		baseStats = { gas = 30, power = 70, acceleration = 18 },
		price = 200_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Desert-tuned and sun-hardened.",
	},
	hot_rod = {
		id = "hot_rod",
		name = "Inferno Rod",
		modelName = "Purple",
		baseStats = { gas = 16, power = 110, acceleration = 10 },
		price = 500_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 4,
		description = "Barely street legal. Actually not street legal.",
	},

	snowmobile = {
		id = "snowmobile",
		name = "Frost Glider",
		modelName = "White",
		baseStats = { gas = 35, power = 85, acceleration = 16 },
		price = 2_500_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 2,
		description = "Cuts through snow like butter.",
	},
	ice_racer = {
		id = "ice_racer",
		name = "Glacier Phantom",
		modelName = "Silver",
		baseStats = { gas = 25, power = 130, acceleration = 8 },
		price = 5_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "So fast it leaves frost trails.",
	},

	cyber_car = {
		id = "cyber_car",
		name = "Neon Pulse",
		modelName = "Cyan",
		baseStats = { gas = 32, power = 160, acceleration = 7 },
		price = 15_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 4,
		description = "From the future. Runs on pure energy.",
	},
	hyper_car = {
		id = "hyper_car",
		name = "Void Runner",
		modelName = "Black",
		baseStats = { gas = 24, power = 220, acceleration = 5 },
		price = 60_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "The fastest thing on any highway. Period.",
	},

	midnight_drifter = {
		id = "midnight_drifter",
		name = "Midnight Drifter",
		modelName = "midnight_drifter",
		baseStats = { gas = 30, power = 120, acceleration = 9 },
		price = 0,
		currency = "coins",
		worldId = "forest",
		vfxTier = 5,
		description = "The crown jewel of Season 1. Matte black with electric-blue underglow. Usable in all worlds.",
	},
}

--[[
	1-5 scale for driving VFX (wheel trails, speed rush, boost stars, underglow).
	Higher tiers read as more "power" without changing physics.
]]
function CarConfig.getVehicleVfxTier(carId: string): number
	local def = CarConfig.Cars[carId]
	if def and type((def :: any).vfxTier) == "number" then
		return math.clamp((def :: any).vfxTier :: number, 1, 5)
	end
	if def and def.baseStats and type(def.baseStats.power) == "number" then
		local p = def.baseStats.power
		if p <= 40 then
			return 1
		elseif p <= 70 then
			return 2
		elseif p <= 120 then
			return 3
		elseif p <= 180 then
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
