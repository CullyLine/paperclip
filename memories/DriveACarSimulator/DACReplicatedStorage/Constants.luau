--!strict

local Constants = {}

Constants.MAX_PET_SLOTS_DEFAULT = 8
Constants.MAX_PET_SLOTS_GAMEPASS = 16
Constants.MAX_EGGS_INVENTORY = 200

Constants.REBIRTH_BASE_COST = 1_000_000
Constants.REBIRTH_COST_MULTIPLIER = 1.5
Constants.REBIRTH_STAT_REWARD = 5

Constants.STARTING_COINS = 500
Constants.STARTING_GEMS = 0
Constants.STARTING_CRYSTALS = 0
Constants.STARTING_SKULLS = 0
Constants.STARTING_CAR = "starter"
Constants.STARTING_WORLD = "grasslands"

Constants.PREMIUM_COIN_BONUS = 0.5 -- +50%

Constants.DISTANCE_TO_COINS_RATE = 1 -- 1 coin per unit of distance (base)
Constants.GAS_DRAIN_RATE = 1 -- gas units consumed per second (base)

Constants.LAP_TELEPORT_OFFSET = 10 -- studs past start line on lap reset

Constants.DAILY_REWARD_COOLDOWN = 86400 -- 24 hours in seconds
Constants.MAX_DAILY_STREAK = 7

Constants.PLAYTIME_GEM_INTERVAL = 900 -- 15 minutes active play -> 1 gem
Constants.REMOTE_COOLDOWN_DEFAULT = 0.35

Constants.AUTO_COLLECT_LAPS_BEFORE_BANK = 3

-- Near-miss chain (server must match client lateral debounce; see DrivingController)
Constants.NEAR_MISS_CHAIN_RESET_SEC = 3.0
Constants.NEAR_MISS_BASE_COINS = 5
Constants.NEAR_MISS_CLAIM_MIN_INTERVAL = 0.12
Constants.NEAR_MISS_MAX_COINS_PER_RUN = 600

Constants.CURRENCY_DISPLAY = {
	coins = { icon = "rbxassetid://0", color = Color3.fromRGB(255, 200, 50) },
	gems = { icon = "rbxassetid://0", color = Color3.fromRGB(200, 100, 255) },
	crystals = { icon = "rbxassetid://0", color = Color3.fromRGB(255, 120, 50) },
	skulls = { icon = "rbxassetid://0", color = Color3.fromRGB(80, 180, 255) },
}

Constants.RARITY_COLORS = {
	common = Color3.fromRGB(180, 180, 180),
	uncommon = Color3.fromRGB(80, 200, 80),
	rare = Color3.fromRGB(60, 130, 255),
	epic = Color3.fromRGB(180, 60, 255),
	legendary = Color3.fromRGB(255, 200, 50),
	mythic = Color3.fromRGB(255, 50, 80),
}

Constants.RARITY_ORDER = {
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
	mythic = 6,
}

Constants.TITLES = {
	early_driver = {
		id = "early_driver",
		displayName = "Early Driver",
		color = Color3.fromRGB(255, 200, 80),
		priority = 10,
	},
	night_rider = {
		id = "night_rider",
		displayName = "Night Rider",
		color = Color3.fromRGB(120, 90, 255),
		priority = 50,
	},
	s1_veteran = {
		id = "s1_veteran",
		displayName = "S1 Veteran",
		color = Color3.fromRGB(255, 220, 120),
		priority = 100,
	},
}

return Constants
