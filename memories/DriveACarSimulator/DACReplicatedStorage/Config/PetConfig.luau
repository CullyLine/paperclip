--!strict

local PetConfig = {}

PetConfig.MAX_FOLLOWING = 8

PetConfig.Pets = {
	tabby_cat = {
		id = "tabby_cat",
		name = "Tabby Cat",
		modelName = "tabby",
		basePower = 5,
		rarity = "common",
		locomotion = "ground",
		description = "Friendly face. Small boost to earnings.",
	},
	puppy = {
		id = "puppy",
		name = "Puppy",
		modelName = "puppy",
		basePower = 5,
		rarity = "common",
		locomotion = "ground",
		description = "Man's best friend. And your wallet's.",
	},
	dachshund = {
		id = "dachshund",
		name = "Dachshund",
		modelName = "dachshund",
		basePower = 6,
		rarity = "common",
		locomotion = "ground",
		description = "Long boy. Short legs. Big heart.",
	},

	fox = {
		id = "fox",
		name = "Fox",
		modelName = "fox",
		basePower = 12,
		rarity = "uncommon",
		locomotion = "ground",
		description = "Clever and quick. Good for business.",
	},
	owl = {
		id = "owl",
		name = "Owl",
		modelName = "owl",
		basePower = 14,
		rarity = "uncommon",
		locomotion = "ground",
		description = "Sharp eyes. Better returns the longer you run.",
	},

	dragon_hatchling = {
		id = "dragon_hatchling",
		name = "Dragon Hatchling",
		modelName = "dragon",
		basePower = 60,
		rarity = "epic",
		locomotion = "ground",
		description = "Baby dragon. Big power.",
	},
	phoenix_chick = {
		id = "phoenix_chick",
		name = "Phoenix Chick",
		modelName = "phoenix",
		basePower = 65,
		rarity = "epic",
		locomotion = "flying",
		description = "Rises from flame. Extra spark every time you rebirth.",
	},
	jellyfish = {
		id = "jellyfish",
		name = "Glowing Jellyfish",
		modelName = "jellyfish",
		basePower = 70,
		rarity = "epic",
		locomotion = "flying",
		description = "Bioluminescent drifter. Pulses with every coin collected.",
	},

	shadow_panther = {
		id = "shadow_panther",
		name = "Shadow Panther",
		modelName = "panther",
		basePower = 175,
		rarity = "legendary",
		locomotion = "ground",
		description = "Built for empty highways. Hunts coins, not traffic.",
	},
	unicorn = {
		id = "unicorn",
		name = "Unicorn",
		modelName = "unicorn",
		basePower = 140,
		rarity = "legendary",
		locomotion = "ground",
		description = "Legendary find. Huge boost to your earning power.",
	},

	cosmic_whale = {
		id = "cosmic_whale",
		name = "Cosmic Whale",
		modelName = "whale",
		basePower = 550,
		rarity = "mythic",
		locomotion = "flying",
		description = "Swims through space. Floods your run with coins.",
	},

	-- Exclusive: granted once when player joins the game's Roblox group (GroupRewardService)
	group_member = {
		id = "group_member",
		name = "Group Pup",
		modelName = "puppy",
		basePower = 18,
		rarity = "uncommon",
		locomotion = "ground",
		description = "Uncommon boost for joining the game's Roblox group.",
		source = "group",
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

function PetConfig.getTotalSpeciesCount(): number
	local n = 0
	for _ in PetConfig.Pets do
		n += 1
	end
	return n
end

return PetConfig
