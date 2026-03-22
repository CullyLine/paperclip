--!strict
--[[
	Player data management using DataStoreService with session locking.
	Handles loading, saving, auto-saving, and data access for all server services.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("DAC"):WaitForChild("Constants"))

local DataManager = {}

local DATA_STORE_NAME = "DACPlayerData_v3"
local AUTO_SAVE_INTERVAL = 120
local SESSION_LOCK_EXPIRE = 1800

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerData: { [number]: any } = {}
local sessionLocks: { [number]: boolean } = {}

local function getDefaultData()
	return {
		coins = Constants.STARTING_COINS,
		gems = Constants.STARTING_GEMS,
		crystals = Constants.STARTING_CRYSTALS,
		skulls = Constants.STARTING_SKULLS,

		cars = {
			[Constants.STARTING_CAR] = {
				id = Constants.STARTING_CAR,
				gasLevel = 0,
				powerLevel = 0,
				speedLevel = 0,
			},
		},
		equippedCar = Constants.STARTING_CAR,

		pets = {},
		maxPetSlots = Constants.MAX_PET_SLOTS_DEFAULT,

		eggs = {},

		rebirths = 0,
		rebirthStats = { gas = 0, power = 0, speed = 0 },

		currentWorld = Constants.STARTING_WORLD,
		unlockedWorlds = { [Constants.STARTING_WORLD] = true },

		dailyReward = {
			lastClaim = 0,
			streak = 0,
			dailyCycle = 1,
			premiumBoxClaimed = false,
			lastClaimLostStreak = 0,
		},
		redeemedCodes = {},
		settings = {
			autoCenter = true,
			otherPets = true,
			tradeRequests = true,
			particles = true,
			sound = true,
			musicVolume = 0.7,
			sfxVolume = 0.8,
			graphicsQuality = 1,
			steeringSensitivity = 1,
		},
		stats = {
			totalDistance = 0,
			totalRebirths = 0,
			totalEggsHatched = 0,
			totalLaps = 0,
			bestSingleRun = 0,
			totalRunsCompleted = 0,
			bestLapSeconds = nil,
		},

		-- One-shot flags for MilestoneCeremonyCopyConfig-driven celebrations (server)
		milestoneCopyClaimed = {
			collection = {} :: { [number]: boolean? },
			worldMastery = {} :: { [string]: boolean? },
			totalRuns = {} :: { [number]: boolean? },
		},

		playtimeSecondsSinceGem = 0,
		joinedDuringLaunch = false,
		lastRunOfDayDate = "",
		founderBonusNotified = false,
		starterPackPurchased = false,
		discoveredPets = {},
		-- Easter egg ids discovered (POLA easter egg system)
		discoveredEasterEggs = {} :: { [string]: boolean },

		titles = {},

		-- Last known global leaderboard ranks (lower = better). Used for rank-up fanfare.
		leaderboardRankSnapshot = {
			totalDistance = nil,
			totalRebirths = nil,
		},

		-- One-shot ceremony flags + cumulative monetization (FirstTimeConfig consumers)
		firstTimeCeremony = {
			FirstCarPurchased = false,
			FirstPetHatched = false,
			FirstRebirth = false,
			FirstWorldUnlocked = false,
			FirstQuestCompleted = false,
			FirstGamePassPurchase = false,
			FirstLeaderboardEntry = false,
		},
		totalRobuxSpent = 0,
		spendMilestonesClaimed = {} :: { [number]: boolean },
		streakMilestonesClaimed = {} :: { [number]: boolean },

		-- Achievements (AchievementService)
		achievementsUnlocked = {} :: { [string]: boolean },
		achievementsSeen = {} :: { [string]: boolean },
		coinsSpentTotal = 0,
		worldsWithCompletedRun = {} :: { [string]: boolean },
		achievementMeta = {
			categoryToastFired = {} :: { [string]: boolean },
			totalToastFired = false,
		},

		battlePass = {
			seasonId = "",
			xp = 0,
			premium = false,
			claimedFree = {},
			claimedPremium = {},
		},

		cosmetics = {},
		consumables = {
			speedBoosts = 0,
			luckBoosts = 0,
		},

		quests = {
			seasonId = "",
			lastDailyResetDay = 0,
			lastWeeklyResetWeek = 0,
			daily = {},
			weekly = {},
			milestone = {},
			seasonPlayDays = {},
			worldsEarnedCoinsDay = 0,
			worldsEarnedCoins = {},
			seasonDistance = 0,
			seasonLaps = 0,
			seasonEggs = 0,
			seasonCoins = 0,
			seasonRebirths = 0,
			seasonRuns = 0,
			uniquePetEquipsSeason = {},
			rebirthsWeek = 0,
			eggsWeek = 0,
			coinsEarnedWeek = 0,
			worldsVisitedDayKey = 0,
			worldsVisitedDay = {},
			worldsVisitedWeekKey = 0,
			worldsVisitedWeek = {},
		},

		-- Dev product receipt ids already fulfilled (ProcessReceipt idempotency)
		processedReceiptIds = {},

		tutorialStep = 6,
		tutorialComplete = true,

		_version = 1,
		_lastSave = 0,
	}
end

local function reconcile(saved: any, template: any): any
	local result = {}
	for key, defaultValue in template do
		if saved[key] == nil then
			if type(defaultValue) == "table" then
				result[key] = table.clone(defaultValue)
			else
				result[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(saved[key]) == "table" then
			-- Empty `{}` in the template means "opaque map" (pets, eggs, etc.), not "no keys".
			-- Recursing with an empty template would drop every entry — preserve saved keys.
			if next(defaultValue) == nil then
				local merged: any = {}
				for k, v in saved[key] do
					if type(v) == "table" then
						merged[k] = table.clone(v)
					else
						merged[k] = v
					end
				end
				result[key] = merged
			else
				result[key] = reconcile(saved[key], defaultValue)
			end
		else
			result[key] = saved[key]
		end
	end
	return result
end

function DataManager.load(player: Player): boolean
	local userId = player.UserId
	local key = "player_" .. userId

	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if not success then
		warn(`[DataManager] Failed to load data for {player.Name}: {result}`)
		return false
	end

	local template = getDefaultData()
	if result then
		playerData[userId] = reconcile(result, template)
	else
		playerData[userId] = template
	end

	local d = playerData[userId]
	-- String-key maps (empty default template) are not merged by reconcile — restore from raw save.
	if d and result and type(result.discoveredEasterEggs) == "table" then
		if not d.discoveredEasterEggs then
			d.discoveredEasterEggs = {}
		end
		for k, v in result.discoveredEasterEggs do
			if v == true then
				d.discoveredEasterEggs[k] = true
			end
		end
	end

	-- Pet index: mark pets already owned as discovered
	if d and d.pets and d.discoveredPets then
		for _, pet in d.pets do
			d.discoveredPets[pet.id] = true
		end
	end

	sessionLocks[userId] = true
	return true
end

function DataManager.save(player: Player): boolean
	local userId = player.UserId
	local data = playerData[userId]
	if not data then
		return false
	end

	data._lastSave = os.time()

	local ValidationService = require(script.Parent:WaitForChild("Services"):WaitForChild("ValidationService"))
	ValidationService.validatePlayerDataForSave(player, data)

	local key = "player_" .. userId
	local success, err = pcall(function()
		dataStore:SetAsync(key, data)
	end)

	if not success then
		warn(`[DataManager] Failed to save data for {player.Name}: {err}`)
		return false
	end

	return true
end

function DataManager.get(player: Player): any?
	return playerData[player.UserId]
end

--[[
	Replace session data with a fresh default profile (admin / QA). Does not touch DataStore until next save.
]]
function DataManager.resetToDefault(player: Player)
	local userId = player.UserId
	local template = getDefaultData()
	playerData[userId] = template
	local d = playerData[userId]
	if d and d.pets and d.discoveredPets then
		for _, pet in d.pets do
			d.discoveredPets[pet.id] = true
		end
	end
end

function DataManager.unload(player: Player)
	local userId = player.UserId
	if playerData[userId] then
		DataManager.save(player)
		playerData[userId] = nil
		sessionLocks[userId] = nil
	end
end

function DataManager.getCurrency(player: Player, currency: string): number
	local data = playerData[player.UserId]
	if not data then return 0 end
	return data[currency] or 0
end

function DataManager.addCurrency(player: Player, currency: string, amount: number, source: string): boolean
	local ValidationService = require(script.Parent:WaitForChild("Services"):WaitForChild("ValidationService"))
	if not ValidationService.validateCurrencySource(source) then
		ValidationService.logViolation(player, "invalid_currency_source", "critical", source)
		return false
	end
	local data = playerData[player.UserId]
	if not data then return false end
	if amount < 0 then return false end
	data[currency] = (data[currency] or 0) + amount
	return true
end

function DataManager.spendCurrency(player: Player, currency: string, amount: number): boolean
	local data = playerData[player.UserId]
	if not data then return false end
	if (data[currency] or 0) < amount then return false end
	data[currency] = data[currency] - amount
	return true
end

function DataManager.init()
	Players.PlayerRemoving:Connect(function(player)
		DataManager.unload(player)
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataManager.unload(player)
		end
	end)

	-- Auto-save loop
	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				if playerData[player.UserId] then
					DataManager.save(player)
				end
			end
		end
	end)
end

return DataManager
