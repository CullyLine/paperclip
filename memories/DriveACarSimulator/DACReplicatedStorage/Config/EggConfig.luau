--!strict

local EggConfig = {}

EggConfig.Eggs = {
	basic_egg = {
		id = "basic_egg",
		name = "Meadow Egg",
		modelName = "Basic",
		price = 1_500,
		currency = "coins",
		worldId = "grasslands",
		drops = {
			{ petId = "tabby_cat", rarity = "common", weight = 40 },
			{ petId = "puppy", rarity = "common", weight = 35 },
			{ petId = "hamster", rarity = "common", weight = 20 },
			{ petId = "fox", rarity = "uncommon", weight = 4 },
			{ petId = "wolf", rarity = "rare", weight = 1 },
		},
	},
	grass_egg = {
		id = "grass_egg",
		name = "Grass Egg",
		modelName = "Grass",
		price = 2_500,
		currency = "coins",
		worldId = "grasslands",
		drops = {
			{ petId = "puppy", rarity = "common", weight = 30 },
			{ petId = "fox", rarity = "uncommon", weight = 30 },
			{ petId = "owl", rarity = "uncommon", weight = 25 },
			{ petId = "wolf", rarity = "rare", weight = 10 },
			{ petId = "eagle", rarity = "rare", weight = 4 },
			{ petId = "dragon_hatchling", rarity = "epic", weight = 1 },
		},
	},

	desert_egg = {
		id = "desert_egg",
		name = "Desert Egg",
		modelName = "Desert",
		price = 50_000,
		currency = "coins",
		worldId = "desert",
		drops = {
			{ petId = "fox", rarity = "uncommon", weight = 30 },
			{ petId = "owl", rarity = "uncommon", weight = 25 },
			{ petId = "wolf", rarity = "rare", weight = 20 },
			{ petId = "eagle", rarity = "rare", weight = 15 },
			{ petId = "dragon_hatchling", rarity = "epic", weight = 7 },
			{ petId = "phoenix_chick", rarity = "epic", weight = 3 },
		},
	},
	scorching_egg = {
		id = "scorching_egg",
		name = "Scorching Egg",
		modelName = "Scorching",
		price = 2_000,
		currency = "gems",
		worldId = "desert",
		drops = {
			{ petId = "eagle", rarity = "rare", weight = 35 },
			{ petId = "dragon_hatchling", rarity = "epic", weight = 30 },
			{ petId = "phoenix_chick", rarity = "epic", weight = 20 },
			{ petId = "golden_dragon", rarity = "legendary", weight = 10 },
			{ petId = "unicorn", rarity = "legendary", weight = 5 },
		},
	},

	frozen_egg = {
		id = "frozen_egg",
		name = "Frozen Egg",
		modelName = "Frozen",
		price = 10_000,
		currency = "gems",
		worldId = "frozen",
		drops = {
			{ petId = "wolf", rarity = "rare", weight = 25 },
			{ petId = "eagle", rarity = "rare", weight = 20 },
			{ petId = "dragon_hatchling", rarity = "epic", weight = 20 },
			{ petId = "phoenix_chick", rarity = "epic", weight = 15 },
			{ petId = "golden_dragon", rarity = "legendary", weight = 12 },
			{ petId = "unicorn", rarity = "legendary", weight = 7 },
			{ petId = "void_serpent", rarity = "mythic", weight = 1 },
		},
	},

	neon_egg = {
		id = "neon_egg",
		name = "Neon Egg",
		modelName = "Neon",
		price = 5_000,
		currency = "crystals",
		worldId = "neon",
		drops = {
			{ petId = "phoenix_chick", rarity = "epic", weight = 35 },
			{ petId = "golden_dragon", rarity = "legendary", weight = 30 },
			{ petId = "unicorn", rarity = "legendary", weight = 28 },
			{ petId = "void_serpent", rarity = "mythic", weight = 4 },
			{ petId = "cosmic_whale", rarity = "mythic", weight = 3 },
		},
	},
}

function EggConfig.getEggTemplateName(eggId: string): string
	local def = EggConfig.Eggs[eggId]
	if def and def.modelName then
		return def.modelName
	end
	return eggId
end

function EggConfig.listEggIds(): { string }
	local ids = {}
	for id in EggConfig.Eggs do
		table.insert(ids, id)
	end
	return ids
end

return EggConfig
