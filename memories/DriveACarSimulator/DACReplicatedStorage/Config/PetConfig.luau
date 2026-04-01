--!strict

local PetConfig = {}

PetConfig.MAX_FOLLOWING = 8

PetConfig.Pets = {
	tabby_cat = {
		id = "tabby_cat",
		name = "Tabby Cat",
		modelName = "tabby",
		basePower = 4,
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
		basePower = 11,
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
		basePower = 58,
		rarity = "epic",
		locomotion = "ground",
		description = "Baby dragon. Big power.",
	},
	phoenix_chick = {
		id = "phoenix_chick",
		name = "Phoenix Chick",
		modelName = "phoenix",
		basePower = 62,
		rarity = "epic",
		locomotion = "flying",
		description = "Rises from flame. Extra spark every time you rebirth.",
	},
	jellyfish = {
		id = "jellyfish",
		name = "Glowing Jellyfish",
		modelName = "jellyfish",
		basePower = 66,
		rarity = "epic",
		locomotion = "flying",
		description = "Bioluminescent drifter. Pulses with every coin collected.",
	},

	shadow_panther = {
		id = "shadow_panther",
		name = "Shadow Panther",
		modelName = "panther",
		basePower = 170,
		rarity = "legendary",
		locomotion = "ground",
		description = "Built for empty highways. Hunts coins, not traffic.",
	},
	unicorn = {
		id = "unicorn",
		name = "Unicorn",
		modelName = "unicorn",
		basePower = 135,
		rarity = "legendary",
		locomotion = "ground",
		description = "Legendary find. Huge boost to your earning power.",
	},

	golden_dragon = {
		id = "golden_dragon",
		name = "Golden Dragon",
		modelName = "dragon",
		basePower = 155,
		rarity = "legendary",
		locomotion = "flying",
		description = "Shiny scales, serious training power.",
	},

	void_serpent = {
		id = "void_serpent",
		name = "Void Serpent",
		modelName = "dragon",
		basePower = 400,
		rarity = "mythic",
		locomotion = "flying",
		description = "Coils through empty space.",
	},

	cosmic_whale = {
		id = "cosmic_whale",
		name = "Cosmic Whale",
		modelName = "whale",
		basePower = 520,
		rarity = "mythic",
		locomotion = "flying",
		description = "Swims through space. Floods your run with coins.",
	},

	-- Italian Brainrot egg pets
	tung_tung = {
		id = "tung_tung",
		name = "Tung Tung Tung Sahur",
		modelName = "tungtung",
		basePower = 15,
		rarity = "common",
		locomotion = "ground",
		description = "Wooden stick figure with a bat. Ugly cute.",
	},
	tralalero = {
		id = "tralalero",
		name = "Tralalero Tralala",
		modelName = "tralalero",
		basePower = 28,
		rarity = "uncommon",
		locomotion = "ground",
		description = "Shark with sneakers. Drips harder than the ocean.",
	},
	bombardiro = {
		id = "bombardiro",
		name = "Bombardiro Crocodilo",
		modelName = "bombardiro",
		basePower = 48,
		rarity = "rare",
		locomotion = "flying",
		description = "Crocodile bomber. Delivers payloads from above.",
	},
	cappuccino = {
		id = "cappuccino",
		name = "Cappuccino Assassino",
		modelName = "cappuccino",
		basePower = 85,
		rarity = "epic",
		locomotion = "ground",
		description = "Coffee cup ninja. Dual katanas, whipped cream dome.",
	},
	bombombini = {
		id = "bombombini",
		name = "Bombombini Gusini",
		modelName = "bombombini",
		basePower = 220,
		rarity = "legendary",
		locomotion = "flying",
		description = "Goose-fighter jet hybrid. Honks at Mach 2.",
	},

	-- Exclusive: granted once when player joins the game's Roblox group (GroupRewardService)
	group_member = {
		id = "group_member",
		name = "Group Pup",
		modelName = "puppy",
		basePower = 20,
		rarity = "uncommon",
		locomotion = "ground",
		description = "Uncommon boost for joining the game's Roblox group.",
		source = "group",
	},
}

PetConfig.FuseCost = {
	petsRequired = 3,
	coinCost = 50_000,
	coinCostMultiplier = 4,
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
