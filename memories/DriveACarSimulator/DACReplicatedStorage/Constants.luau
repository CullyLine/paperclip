--!strict

local Constants = {}

Constants.MAX_PET_SLOTS_DEFAULT = 8
Constants.MAX_PET_SLOTS_GAMEPASS = 16
Constants.MAX_EGGS_INVENTORY = 200

Constants.REBIRTH_BASE_COST = 1_000_000
Constants.REBIRTH_COST_MULTIPLIER = 1.5
Constants.REBIRTH_STAT_REWARD = 5

Constants.STARTING_COINS = 500
Constants.STARTING_SAND_GRANULES = 0
Constants.STARTING_ICYCLES = 0
Constants.STARTING_MAGMA_CORES = 0
Constants.STARTING_INFINITIUM = 0
Constants.STARTING_CAR = "starter"
Constants.STARTING_WORLD = "forest"

Constants.PREMIUM_COIN_BONUS = 0.5 -- +50%

Constants.DISTANCE_TO_COINS_RATE = 1 -- 1 coin per unit of distance (base)
Constants.GAS_DRAIN_RATE = 1 -- gas units consumed per second (base)

-- Run payout (POLA-539): max plausible distance vs elapsed wall time × equipped speed (frame slack).
Constants.RUN_PAYOUT_MAX_DISTANCE_VS_ELAPSED_SLACK = 1.42
-- Defense-in-depth caps on stats used only for payout if save data is corrupted.
Constants.RUN_PAYOUT_MAX_PET_COIN_MODIFIER = 100
Constants.RUN_PAYOUT_MAX_POWER_STAT = 10000

Constants.LAP_TELEPORT_OFFSET = 10 -- studs past start line on lap reset

Constants.DAILY_REWARD_COOLDOWN = 86400 -- 24 hours in seconds
Constants.MAX_DAILY_STREAK = 7

Constants.PLAYTIME_BONUS_INTERVAL = 900 -- 15 minutes active play -> coin bonus
Constants.PLAYTIME_BONUS_BASE_COINS = 75
Constants.REMOTE_COOLDOWN_DEFAULT = 0.35
-- Promo / code redemption (server sliding window — see CodeService)
Constants.CODE_REDEEM_WINDOW_SEC = 60
Constants.CODE_REDEEM_MAX_ATTEMPTS_PER_MINUTE = 12
Constants.CODE_REDEEM_MIN_LEN = 1
Constants.CODE_REDEEM_MAX_LEN = 32
-- Client: max wait for DataUpdate after Rebirth:FireServer before re-enabling confirm (failure path).
Constants.REBIRTH_CLIENT_PENDING_TIMEOUT_SEC = 8

-- Battle Pass: server-only XP sources (BattlePassService.awardXp) clamp per-session gains in memory (POLA-527).
-- Season total XP curve is 15,000 across 50 tiers (BattlePassConfig); caps allow a full pass from one source + margin.
Constants.BATTLE_PASS_MAX_SESSION_XP_RUN_DISTANCE = 20000
Constants.BATTLE_PASS_MAX_SESSION_XP_QUEST = 12000

-- Leaderboard: server caches OrderedDataStore reads; per-player cooldown applies only on cache miss (see LeaderboardService).
Constants.LEADERBOARD_DATASTORE_CACHE_TTL_SEC = 12
Constants.LEADERBOARD_REMOTE_COOLDOWN_ON_FETCH_SEC = 2.5
-- Client: min time between automatic polling refreshes (manual / rank-up always requests immediately).
Constants.LEADERBOARD_CLIENT_AUTO_REFRESH_SEC = 30

Constants.AUTO_COLLECT_LAPS_BEFORE_BANK = 3

-- Near-miss combo chain reset window (server + client; see NearMissComboRewardDesignSpec §A, DrivingController, RunService.claimNearMiss)
Constants.NEAR_MISS_CHAIN_RESET_SEC = 4.0
Constants.NEAR_MISS_BASE_COINS = 5
Constants.NEAR_MISS_CLAIM_MIN_INTERVAL = 0.12
-- Client: min seconds between near-miss *edge* processing + NearMissClaim:FireServer (must be >= NEAR_MISS_CLAIM_MIN_INTERVAL)
Constants.NEAR_MISS_CLIENT_LATERAL_DEBOUNCE_SEC = 0.15
Constants.NEAR_MISS_MAX_COINS_PER_RUN = 600

-- Lane snap / "unstick" (server + client; see RequestVehicleReset, DrivingController)
Constants.VEHICLE_RESET_COOLDOWN_SEC = 8
Constants.VEHICLE_RESET_CONFIRM_WINDOW_SEC = 2.5

-- Run physics recovery (POLA-628): auto unstick + cooldown between attempts
Constants.RUN_POSITION_RECOVERY_COOLDOWN_SEC = 5
Constants.RUN_POSITION_MAX_ABS_STUDS = 1_000_000

-- POLA-95: `icon` wired after Board upload — see `LaunchAssets/AssetIdChecklist.md` §1 (POLA-546 sweep).
Constants.CURRENCY_DISPLAY = {
	coins = { icon = "rbxassetid://0", color = Color3.fromRGB(255, 200, 50), name = "Coins" },
	sandGranules = { icon = "rbxassetid://0", color = Color3.fromRGB(220, 180, 100), name = "Sand Granules" },
	icycles = { icon = "rbxassetid://0", color = Color3.fromRGB(130, 210, 255), name = "Icycles" },
	magmaCores = { icon = "rbxassetid://0", color = Color3.fromRGB(255, 80, 30), name = "Magma Cores" },
	infinitium = { icon = "rbxassetid://0", color = Color3.fromRGB(160, 120, 255), name = "Infinitium" },
}

Constants.ALL_CURRENCY_KEYS = { "coins", "sandGranules", "icycles", "magmaCores", "infinitium" }

-- POLA-568: Body / section text on light panel surfaces (pastel pink–lavender per DAC design guide).
-- Gold-on-pink for full-width headers fails WCAG (~1:1); use dark body text instead.
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

-- When false, suppress [DAC] boot/initialization prints (cleaner Studio Output; POLA-595). Set true only when debugging load order.
Constants.DEBUG_BOOT_LOG = false

function Constants.bootLog(...: any)
	if Constants.DEBUG_BOOT_LOG then
		print(...)
	end
end

return Constants
