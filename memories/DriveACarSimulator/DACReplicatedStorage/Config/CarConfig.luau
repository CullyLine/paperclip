--!strict
--[[
	All playable cars match ReplicatedStorage / ServerStorage CarModels by modelName (folder name).
	Progression: hatchback (free) → classics/drifters/sports ladder → delorean, hummer, special.
	Prices scale with world unlock (forest → desert → ice → volcano).
]]

local CarConfig = {}

--[[
	Vehicle stats:
	  gas          – fuel capacity; how far you can drive before the run ends.
	  power        – base top speed contribution; effective speed uses trainedPower too.
	  acceleration – seconds to reach top speed (lower = snappier).
]]
CarConfig.Cars = {
	hatchback = {
		id = "hatchback",
		name = "Hatchback",
		modelName = "hatchback",
		baseStats = { gas = 48, power = 35, acceleration = 28 },
		price = 0,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1,
		description = "Your first ride. Light on fuel, easy to drive.",
	},
	classic = {
		id = "classic",
		name = "Classic",
		modelName = "classic",
		baseStats = { gas = 47, power = 42, acceleration = 27 },
		price = 6_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1,
		description = "Timeless lines and a steady engine.",
	},
	drifter = {
		id = "drifter",
		name = "Drifter",
		modelName = "drifter",
		baseStats = { gas = 46, power = 49, acceleration = 26 },
		price = 12_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 1,
		description = "Loose rear, happy slides.",
	},
	sport = {
		id = "sport",
		name = "Sport",
		modelName = "sport",
		baseStats = { gas = 44, power = 56, acceleration = 25 },
		price = 22_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Sharper handling without breaking the bank.",
	},
	classic2 = {
		id = "classic2",
		name = "Classic Mk II",
		modelName = "classic2",
		baseStats = { gas = 43, power = 62, acceleration = 25 },
		price = 38_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Refined chrome, stronger pull.",
	},
	drifter2 = {
		id = "drifter2",
		name = "Drifter Mk II",
		modelName = "drifter2",
		baseStats = { gas = 42, power = 69, acceleration = 24 },
		price = 60_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "More angle, more smoke.",
	},
	sport2 = {
		id = "sport2",
		name = "Sport Mk II",
		modelName = "sport2",
		baseStats = { gas = 41, power = 76, acceleration = 23 },
		price = 90_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Track-tuned suspension.",
	},
	classic3 = {
		id = "classic3",
		name = "Classic Mk III",
		modelName = "classic3",
		baseStats = { gas = 40, power = 83, acceleration = 22 },
		price = 140_000,
		currency = "coins",
		worldId = "forest",
		vfxTier = 2,
		description = "Forest highway kingpin.",
	},

	drifter3 = {
		id = "drifter3",
		name = "Drifter Mk III",
		modelName = "drifter3",
		baseStats = { gas = 39, power = 90, acceleration = 21 },
		price = 240_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Desert heat, cool slides.",
	},
	sport3 = {
		id = "sport3",
		name = "Sport Mk III",
		modelName = "sport3",
		baseStats = { gas = 37, power = 97, acceleration = 20 },
		price = 400_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Starts to bite on long straights.",
	},
	classic4 = {
		id = "classic4",
		name = "Classic Mk IV",
		modelName = "classic4",
		baseStats = { gas = 36, power = 104, acceleration = 19 },
		price = 680_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Heavy cruiser energy.",
	},
	drifter4 = {
		id = "drifter4",
		name = "Drifter Mk IV",
		modelName = "drifter4",
		baseStats = { gas = 35, power = 110, acceleration = 19 },
		price = 1_100_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Sand who?",
	},
	sport4 = {
		id = "sport4",
		name = "Sport Mk IV",
		modelName = "sport4",
		baseStats = { gas = 34, power = 117, acceleration = 18 },
		price = 1_800_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Serious straight-line speed.",
	},
	classic5 = {
		id = "classic5",
		name = "Classic Mk V",
		modelName = "classic5",
		baseStats = { gas = 33, power = 124, acceleration = 17 },
		price = 2_800_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 3,
		description = "Built for long dunes.",
	},
	drifter5 = {
		id = "drifter5",
		name = "Drifter Mk V",
		modelName = "drifter5",
		baseStats = { gas = 31, power = 131, acceleration = 16 },
		price = 4_500_000,
		currency = "coins",
		worldId = "desert",
		vfxTier = 4,
		description = "Grip optional.",
	},

	sport5 = {
		id = "sport5",
		name = "Sport Mk V",
		modelName = "sport5",
		baseStats = { gas = 30, power = 138, acceleration = 15 },
		price = 8_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Cold air, hot lap times.",
	},
	classic6 = {
		id = "classic6",
		name = "Classic Mk VI",
		modelName = "classic6",
		baseStats = { gas = 29, power = 145, acceleration = 14 },
		price = 14_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Ice-road cruiser.",
	},
	drifter6 = {
		id = "drifter6",
		name = "Drifter Mk VI",
		modelName = "drifter6",
		baseStats = { gas = 28, power = 151, acceleration = 14 },
		price = 24_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Frozen lake hero.",
	},
	sport6 = {
		id = "sport6",
		name = "Sport Mk VI",
		modelName = "sport6",
		baseStats = { gas = 27, power = 158, acceleration = 13 },
		price = 40_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Low temps, high RPM.",
	},
	classic7 = {
		id = "classic7",
		name = "Classic Mk VII",
		modelName = "classic7",
		baseStats = { gas = 25, power = 165, acceleration = 12 },
		price = 68_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Elegant and vicious.",
	},
	drifter7 = {
		id = "drifter7",
		name = "Drifter Mk VII",
		modelName = "drifter7",
		baseStats = { gas = 24, power = 172, acceleration = 11 },
		price = 110_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 4,
		description = "Tail happy on frost.",
	},
	sport7 = {
		id = "sport7",
		name = "Sport Mk VII",
		modelName = "sport7",
		baseStats = { gas = 23, power = 179, acceleration = 10 },
		price = 180_000_000,
		currency = "coins",
		worldId = "ice",
		vfxTier = 5,
		description = "Endgame ice sprinter.",
	},

	classic8 = {
		id = "classic8",
		name = "Classic Mk VIII",
		modelName = "classic8",
		baseStats = { gas = 22, power = 186, acceleration = 9 },
		price = 280_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "Volcano boulevard bruiser.",
	},
	drifter8 = {
		id = "drifter8",
		name = "Drifter Mk VIII",
		modelName = "drifter8",
		baseStats = { gas = 21, power = 193, acceleration = 8 },
		price = 480_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "Ash trails for days.",
	},
	drifter9 = {
		id = "drifter9",
		name = "Drifter Mk IX",
		modelName = "drifter9",
		baseStats = { gas = 20, power = 199, acceleration = 8 },
		price = 800_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "Peak drift weapon.",
	},
	delorean = {
		id = "delorean",
		name = "Time Runner",
		modelName = "delorean",
		baseStats = { gas = 18, power = 206, acceleration = 7 },
		price = 1_400_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "Stainless attitude. Feels like the future.",
	},
	hummer = {
		id = "hummer",
		name = "Colossus",
		modelName = "hummer",
		baseStats = { gas = 52, power = 213, acceleration = 6 },
		price = 2_400_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "Absurd tank range. Eats highways.",
	},
	special = {
		id = "special",
		name = "Prototype X",
		modelName = "special",
		baseStats = { gas = 16, power = 220, acceleration = 5 },
		price = 4_000_000_000,
		currency = "coins",
		worldId = "volcano",
		vfxTier = 5,
		description = "The garage ceiling. Nothing left to prove.",
	},
}

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
