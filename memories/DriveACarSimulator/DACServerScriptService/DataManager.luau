--!strict
--[[
	Player data management using DataStoreService with session locking.
	Loading, persistence, and data access for all server services.

	Writes:
	- saveImmediate: synchronous SetAsync (monetization, unload, shutdown, rebirth).
	- scheduleSave: debounced coalesced write for high-frequency paths (lap PB, quest run sync).
	- Periodic safety flush (AUTO_SAVE_INTERVAL) only if dirty from scheduleSave.
	PlayerRemoving + BindToClose both call unload; unload is idempotent once playerData is cleared.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local DataManager = {}

-- POLA-516: strip invalid world ids from saves; keep currentWorld consistent with unlocks + WorldConfig.
local function sanitizeWorldState(d: any)
	if type(d) ~= "table" then
		return
	end
	if type(d.unlockedWorlds) ~= "table" then
		d.unlockedWorlds = { [Constants.STARTING_WORLD] = true }
	end
	local cleaned: { [string]: boolean } = {}
	for k, v in d.unlockedWorlds :: { [string]: any } do
		if type(k) == "string" and v == true and WorldConfig.Worlds[k] ~= nil then
			cleaned[k] = true
		end
	end
	cleaned[Constants.STARTING_WORLD] = true
	d.unlockedWorlds = cleaned
	if type(d.currentWorld) ~= "string" or WorldConfig.Worlds[d.currentWorld] == nil then
		d.currentWorld = Constants.STARTING_WORLD
	end
	if not cleaned[d.currentWorld] then
		d.currentWorld = Constants.STARTING_WORLD
	end
end

local DATA_STORE_NAME = "DACPlayerData_v7"
-- Periodic safety flush: players with unsaved dirty data (see scheduleSave).
local AUTO_SAVE_INTERVAL = 120
-- Coalesce rapid scheduleSave calls into one SetAsync after this delay (timer is not reset by repeats).
local SAVE_DEBOUNCE_SECONDS = 28
local SESSION_LOCK_EXPIRE = 1800

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerData: { [number]: any } = {}
local sessionLocks: { [number]: boolean } = {}
-- Pending debounced DataStore write (one task per userId; repeats while task runs merge into one flush).
local pendingSaveTasks: { [number]: thread } = {}
-- True when scheduleSave was called and the debounced flush has not run yet.
local dirtyForScheduledSave: { [number]: boolean } = {}

--[[
	Authoritative defaults for `settings` (player-facing). Used by SettingsService reset and new profiles.
]]
function DataManager.getDefaultSettings(): { [string]: any }
	local s = getDefaultData().settings
	return {
		autoCenter = s.autoCenter,
		otherPets = s.otherPets,
		otherPetAnimations = s.otherPetAnimations,
		tradeRequests = s.tradeRequests,
		particles = s.particles,
		sound = s.sound,
		musicVolume = s.musicVolume,
		sfxVolume = s.sfxVolume,
		graphicsQuality = s.graphicsQuality,
		steeringSensitivity = s.steeringSensitivity,
		reducedMotion = s.reducedMotion,
		particleDensity = s.particleDensity,
		showFps = s.showFps,
		petLock = s.petLock,
	}
end

local function getDefaultData()
	return {
		coins = Constants.STARTING_COINS,
		gems = Constants.STARTING_GEMS,

		cars = {
			[Constants.STARTING_CAR] = {
				id = Constants.STARTING_CAR,
			},
		},
		equippedCar = Constants.STARTING_CAR,

		pets = {},
		maxPetSlots = Constants.MAX_PET_SLOTS_DEFAULT,

		eggs = { basic_egg = 5 },

		rebirths = 0,
		rebirthTrainingBonus = 0,
		trainedPower = 0,

		rebirthUpgrades = {
			moreGas = 0,
			moreCurrency = 0,
			moreLuck = 0,
			moreAcceleration = 0,
			moreEggsAtOnce = 0,
			moreInventorySpace = 0,
			moreRebirthSkips = 0,
		},

		potions = {},

		currentWorld = Constants.STARTING_WORLD,
		unlockedWorlds = { [Constants.STARTING_WORLD] = true },

		dailyReward = {
			lastClaim = 0,
			streak = 0,
			dailyCycle = 1,
			premiumBoxClaimed = false,
			lastClaimLostStreak = 0,
			authClaimGen = 0,
		},
		redeemedCodes = {},
		settings = {
			autoCenter = true,
			otherPets = true,
			otherPetAnimations = true,
			tradeRequests = true,
			particles = true,
			sound = true,
			musicVolume = 0.7,
			sfxVolume = 0.8,
			graphicsQuality = 1,
			steeringSensitivity = 1,
			reducedMotion = false,
			particleDensity = 2,
			showFps = false,
			petLock = false,
		},
		stats = {
			totalDistance = 0,
			totalRebirths = 0,
			totalEggsHatched = 0,
			totalLaps = 0,
			bestSingleRun = 0,
			totalRunsCompleted = 0,
			bestLapSeconds = nil,
			totalCoinsEarned = 0,
			totalPlaytimeSeconds = 0,
			questsCompletedTotal = 0,
			lastSessionEndUnix = 0,
		},

		milestoneCopyClaimed = {
			collection = {} :: { [number]: boolean? },
			worldMastery = {} :: { [string]: boolean? },
			totalRuns = {} :: { [number]: boolean? },
		},

		playtimeSecondsSinceBonus = 0,
		joinedDuringLaunch = false,
		lastRunOfDayDate = "",
		founderBonusNotified = false,
		groupRewardClaimed = false,
		groupJoinPromptDismissed = false,
		starterPackPurchased = false,
		discoveredPets = {},
		discoveredEasterEggs = {} :: { [string]: boolean },

		titles = {},

		leaderboardRankSnapshot = {
			totalDistance = nil,
			totalRebirths = nil,
		},

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
			claimRevision = 0,
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

		processedReceiptIds = {},

		tutorialStep = 6,
		tutorialComplete = true,

		firstSessionOnboarding = {
			firstPlaySessionEnded = false,
			hookLineConsumed = false,
			sessionWelcomeToastSeen = false,
			firstPayoutCopySeen = false,
			firstHatchCopySeen = false,
			emptyTrophyCaseCopySeen = false,
			dailyStreakFramingSeen = false,
		},

		_version = 2,
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

	if d then
		sanitizeWorldState(d)
	end

	sessionLocks[userId] = true
	return true
end

--[[
	Client-only fields (not persisted): data.retention
]]
function DataManager.stripClientSessionFields(data: any)
	if type(data) == "table" then
		data.retention = nil
	end
end

function DataManager.injectClientSessionFields(data: any)
	if type(data) ~= "table" or type(data.stats) ~= "table" then
		return
	end
	local last = tonumber(data.stats.lastSessionEndUnix) or 0
	local days = 0
	if last > 0 then
		days = math.floor((os.time() - last) / 86400)
	end
	data.retention = {
		daysSinceLastSession = days,
	}
end

local function cancelPendingScheduledSave(userId: number)
	local t = pendingSaveTasks[userId]
	if t then
		task.cancel(t)
		pendingSaveTasks[userId] = nil
	end
end

--[[
	Synchronous DataStore write. Use for: monetization receipts, unload, shutdown flush.
	Cancels any in-flight debounced save for this player so we do not double-write.
]]
function DataManager.saveImmediate(player: Player): boolean
	local userId = player.UserId
	cancelPendingScheduledSave(userId)
	dirtyForScheduledSave[userId] = nil

	local data = playerData[userId]
	if not data then
		return false
	end

	DataManager.stripClientSessionFields(data)

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

--[[
	Restore session profile from a deep snapshot (e.g. dev product receipt grant rollback on failed save).
]]
function DataManager.revertProfile(player: Player, snapshot: any)
	local userId = player.UserId
	if type(snapshot) ~= "table" then
		return
	end
	playerData[userId] = Utils.deepCopy(snapshot)
end

--[[
	Coalesce writes: first call starts a timer; further calls before the timer fires only mark dirty
	(so rapid lap PBs / run-end quest syncs become one SetAsync). Timer is not extended by repeats.
]]
function DataManager.scheduleSave(player: Player)
	local userId = player.UserId
	if not playerData[userId] then
		return
	end
	dirtyForScheduledSave[userId] = true
	if pendingSaveTasks[userId] then
		return
	end
	pendingSaveTasks[userId] = task.delay(SAVE_DEBOUNCE_SECONDS, function()
		pendingSaveTasks[userId] = nil
		if not playerData[userId] or not dirtyForScheduledSave[userId] then
			return
		end
		dirtyForScheduledSave[userId] = nil
		DataManager.saveImmediate(player)
	end)
end

--[[
	@deprecated Prefer saveImmediate (critical) or scheduleSave (high-frequency). Kept as alias for saveImmediate.
]]
function DataManager.save(player: Player): boolean
	return DataManager.saveImmediate(player)
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
	-- POLA-561: End driving run + payout while profile exists (before save/clear).
	local DACRunService = require(script.Parent:WaitForChild("Services"):WaitForChild("RunService"))
	DACRunService.finalizeRunOnLeave(player)

	local userId = player.UserId
	if playerData[userId] then
		local data = playerData[userId]
		if type(data) == "table" and type(data.firstSessionOnboarding) == "table" then
			local o = data.firstSessionOnboarding
			if o.firstPlaySessionEnded == false then
				o.firstPlaySessionEnded = true
			end
		end
		if type(data) == "table" and type(data.stats) == "table" then
			data.stats.lastSessionEndUnix = os.time()
		end
		cancelPendingScheduledSave(userId)
		dirtyForScheduledSave[userId] = nil
		DataManager.saveImmediate(player)
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
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return false
	end
	if amount < 0 then return false end
	data[currency] = (data[currency] or 0) + amount
	local EconomyLogService = require(script.Parent:WaitForChild("Services"):WaitForChild("EconomyLogService"))
	EconomyLogService.onCurrencyAdded(player, currency, amount, source)
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

	-- Safety flush: persist debounced dirty data at least every AUTO_SAVE_INTERVAL (covers long gaps between events).
	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				local uid = player.UserId
				if playerData[uid] and dirtyForScheduledSave[uid] then
					cancelPendingScheduledSave(uid)
					dirtyForScheduledSave[uid] = nil
					DataManager.saveImmediate(player)
				end
			end
		end
	end)
end

return DataManager
