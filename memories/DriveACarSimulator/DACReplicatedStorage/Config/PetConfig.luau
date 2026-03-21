--!strict

local PetConfig = {}

PetConfig.Pets = {
	tabby_cat = {
		id = "tabby_cat",
		name = "Tabby Cat",
		modelName = "Cat",
		basePower = 5,
		rarity = "common",
		description = "A friendly cat. Boosts your earnings a little.",
	},
	puppy = {
		id = "puppy",
		name = "Puppy",
		modelName = "Dog",
		basePower = 5,
		rarity = "common",
		description = "Man's best friend. And your wallet's.",
	},
	hamster = {
		id = "hamster",
		name = "Hamster",
		modelName = "Hamster",
		basePower = 4,
		rarity = "common",
		description = "Small but determined.",
	},

	fox = {
		id = "fox",
		name = "Fox",
		modelName = "Fox",
		basePower = 12,
		rarity = "uncommon",
		description = "Clever and quick. Good for business.",
	},
	owl = {
		id = "owl",
		name = "Owl",
		modelName = "Owl",
		basePower = 14,
		rarity = "uncommon",
		description = "Wise investments lead to wise returns.",
	},

	wolf = {
		id = "wolf",
		name = "Wolf",
		modelName = "Wolf",
		basePower = 25,
		rarity = "rare",
		description = "Pack hunter. Multiplies your pack's power.",
	},
	eagle = {
		id = "eagle",
		name = "Eagle",
		modelName = "Eagle",
		basePower = 30,
		rarity = "rare",
		description = "Soars above the competition.",
	},

	dragon_hatchling = {
		id = "dragon_hatchling",
		name = "Dragon Hatchling",
		modelName = "Dragon",
		basePower = 60,
		rarity = "epic",
		description = "Baby dragon. Big power.",
	},
	phoenix_chick = {
		id = "phoenix_chick",
		name = "Phoenix Chick",
		modelName = "Phoenix",
		basePower = 65,
		rarity = "epic",
		description = "Reborn from flames. Reborn from rebirths.",
	},

	golden_dragon = {
		id = "golden_dragon",
		name = "Golden Dragon",
		modelName = "GoldenDragon",
		basePower = 150,
		rarity = "legendary",
		description = "Breathes fire and money.",
	},
	unicorn = {
		id = "unicorn",
		name = "Unicorn",
		modelName = "Unicorn",
		basePower = 140,
		rarity = "legendary",
		description = "Mythical. Magical. Monetizable.",
	},

	void_serpent = {
		id = "void_serpent",
		name = "Void Serpent",
		modelName = "VoidSerpent",
		basePower = 500,
		rarity = "mythic",
		description = "From beyond the known worlds. Absurd power.",
	},
	cosmic_whale = {
		id = "cosmic_whale",
		name = "Cosmic Whale",
		modelName = "CosmicWhale",
		basePower = 550,
		rarity = "mythic",
		description = "Swims through space. Prints through cash.",
	},

	neon_firefly = {
		id = "neon_firefly",
		name = "Neon Firefly",
		modelName = "neon_firefly",
		basePower = 70,
		rarity = "epic",
		description = "A tiny spark of midnight magic. Lights up the dark and lights up your earnings.",
	},
	shadow_panther = {
		id = "shadow_panther",
		name = "Shadow Panther",
		modelName = "shadow_panther",
		basePower = 175,
		rarity = "legendary",
		description = "Born from midnight highways. Stalks the dark, hunts coins. Season 1 exclusive.",
	},
}

PetConfig.FuseCost = {
	petsRequired = 3,
	coinCost = 10_000,
	coinCostMultiplier = 5,
}

function PetConfig.getPetTemplateName(petId: string): string
	local def = PetConfig.Pets[petId]
	if def and def.modelName then
		return def.modelName
	end
	return petId
end

function PetConfig.listPetIds(): { string }
	local ids = {}
	for id in PetConfig.Pets do
		table.insert(ids, id)
	end
	return ids
end

return PetConfig
