--!strict

local Constants = {}

Constants.MAX_PET_SLOTS_DEFAULT = 8
Constants.MAX_PET_SLOTS_GAMEPASS = 16
Constants.MAX_EGGS_INVENTORY = 200

Constants.REBIRTH_BASE_COST = 400_000
Constants.REBIRTH_COST_MULTIPLIER = 1.45

Constants.STARTING_COINS = 2_500
Constants.STARTING_GEMS = 0
Constants.STARTING_CAR = "starter"
Constants.STARTING_WORLD = "forest"

Constants.PREMIUM_COIN_BONUS = 0.5

Constants.GAS_DRAIN_RATE = 1

Constants.TRAINING_TICK_INTERVAL = 0.3
Constants.TRAINING_BASE_POWER_PER_TICK = 1.15

Constants.CHECKPOINT_COUNT = 10

Constants.BASE_HATCH_COUNT = 10
Constants.MAX_HATCH_COUNT = 35

Constants.RUN_PAYOUT_MAX_DISTANCE_VS_ELAPSED_SLACK = 1.42
Constants.RUN_PAYOUT_MAX_POWER_STAT = 10000

Constants.LAP_TELEPORT_OFFSET = 10

Constants.DAILY_REWARD_COOLDOWN = 86400
Constants.MAX_DAILY_STREAK = 7

Constants.PLAYTIME_BONUS_INTERVAL = 900
Constants.PLAYTIME_BONUS_BASE_COINS = 75
Constants.REMOTE_COOLDOWN_DEFAULT = 0.35

Constants.CODE_REDEEM_WINDOW_SEC = 60
Constants.CODE_REDEEM_MAX_ATTEMPTS_PER_MINUTE = 12
Constants.CODE_REDEEM_MIN_LEN = 1
Constants.CODE_REDEEM_MAX_LEN = 32

Constants.REBIRTH_CLIENT_PENDING_TIMEOUT_SEC = 8

Constants.BATTLE_PASS_MAX_SESSION_XP_RUN_DISTANCE = 20000
Constants.BATTLE_PASS_MAX_SESSION_XP_QUEST = 12000

Constants.LEADERBOARD_DATASTORE_CACHE_TTL_SEC = 12
Constants.LEADERBOARD_REMOTE_COOLDOWN_ON_FETCH_SEC = 2.5
Constants.LEADERBOARD_CLIENT_AUTO_REFRESH_SEC = 30

Constants.AUTO_COLLECT_LAPS_BEFORE_BANK = 3

Constants.NEAR_MISS_CHAIN_RESET_SEC = 4.0
Constants.NEAR_MISS_BASE_COINS = 8
Constants.NEAR_MISS_CLAIM_MIN_INTERVAL = 0.12
Constants.NEAR_MISS_CLIENT_LATERAL_DEBOUNCE_SEC = 0.15
Constants.NEAR_MISS_MAX_COINS_PER_RUN = 800

Constants.VEHICLE_RESET_COOLDOWN_SEC = 8
Constants.VEHICLE_RESET_CONFIRM_WINDOW_SEC = 2.5

Constants.RUN_POSITION_RECOVERY_COOLDOWN_SEC = 5
Constants.RUN_POSITION_MAX_ABS_STUDS = 1_000_000

Constants.CURRENCY_DISPLAY = {
	coins = { icon = "rbxassetid://0", color = Color3.fromRGB(255, 200, 50), name = "Coins" },
}

Constants.ALL_CURRENCY_KEYS = { "coins" }

Constants.UI_TEXT_ON_LIGHT = {
	SectionHeader = Color3.fromRGB(30, 30, 30),
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

Constants.DEBUG_BOOT_LOG = false

function Constants.bootLog(...: any)
	if Constants.DEBUG_BOOT_LOG then
		print(...)
	end
end

return Constants
