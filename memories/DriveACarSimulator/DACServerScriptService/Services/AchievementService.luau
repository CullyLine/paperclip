--!strict
--[[
	Starter achievement unlocks, progress sync, and meta toasts (category / 100%).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local AchievementPopupConfig = require(DAC:WaitForChild("Config"):WaitForChild("AchievementPopupConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))

local AchievementService = {}

local BIG_SPENDER_TARGET = 500_000
local HATCH_100_TARGET = 100
local SPEED_DEMON_THRESHOLD = 100
local DAILY_STREAK_TARGET = 7
local DAILY_STREAK_30_TARGET = 30
local RUNS_10_TARGET = 10
local RUNS_100_TARGET = 100
local COMBO_INFERNO_THRESHOLD = 20
local COIN_TYCOON_TARGET = 1_000_000
local QUEST_VETERAN_TARGET = 10
local NIGHT_OWL_SESSION_SEC = 60 * 60
local SECRET_SPEED_THRESHOLD = 500
local LAP_LEGEND_THRESHOLD = 100
local REBIRTH_ROYALTY_THRESHOLD = 10

-- Server session join time (unix) for single-session achievements.
local sessionStartUnix: { [number]: number } = {}

local RARITY_BY_ID: { [string]: string } = {
	first_drive = "bronze",
	first_hatch = "bronze",
	rebirth_one = "bronze",
	speed_demon = "bronze",
	runs_10 = "bronze",
	hatch_100 = "silver",
	big_spender = "silver",
	daily_streak_7 = "silver",
	top_ten = "silver",
	quest_veteran = "silver",
	world_tourer = "gold",
	number_one = "gold",
	runs_100 = "gold",
	combo_inferno = "gold",
	legendary_hatch = "gold",
	coin_tycoon = "gold",
	daily_streak_30 = "gold",
	world_elite = "gold",
	full_index = "diamond",
	garage_full = "diamond",
	egg_hunter = "diamond",
	night_owl = "silver",
	secret_speed_demon = "gold",
	egg_straordinary = "gold",
	lap_legend = "diamond",
	rebirth_royalty = "gold",
}

local function ensureAchievementTables(data: any)
	if type(data.achievementsUnlocked) ~= "table" then
		data.achievementsUnlocked = {}
	end
	if type(data.achievementsSeen) ~= "table" then
		data.achievementsSeen = {}
	end
	if type(data.worldsWithCompletedRun) ~= "table" then
		data.worldsWithCompletedRun = {}
	end
	if type(data.achievementMeta) ~= "table" then
		data.achievementMeta = { categoryToastFired = {}, totalToastFired = false }
	end
	local meta = data.achievementMeta :: any
	if type(meta.categoryToastFired) ~= "table" then
		meta.categoryToastFired = {}
	end
	if type(data.coinsSpentTotal) ~= "number" then
		data.coinsSpentTotal = 0
	end
end

local function countPetDefinitions(): number
	local n = 0
	for _ in PetConfig.Pets do
		n += 1
	end
	return n
end

local TOTAL_PET_DEFS = countPetDefinitions()

local function countDiscoveredPets(data: any): number
	if type(data.discoveredPets) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in data.discoveredPets do
		if v == true then
			n += 1
		end
	end
	return n
end

local function countUnlockedWorlds(data: any): number
	if type(data.unlockedWorlds) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in data.unlockedWorlds do
		if v == true then
			n += 1
		end
	end
	return n
end

local function countWorldsRun(data: any): number
	if type(data.worldsWithCompletedRun) ~= "table" then
		return 0
	end
	local n = 0
	for wid, v in data.worldsWithCompletedRun do
		if v == true and type(data.unlockedWorlds) == "table" and data.unlockedWorlds[wid] == true then
			n += 1
		end
	end
	return n
end

function AchievementService.fireProgress(player: Player, id: string, current: number, target: number)
	Remotes.getEvent("AchievementProgress"):FireClient(player, {
		id = id,
		current = current,
		target = target,
	})
end

local function tryCategoryCompleteToast(player: Player, data: any, category: string)
	ensureAchievementTables(data)
	local meta = data.achievementMeta :: any
	local catFired = meta.categoryToastFired :: { [string]: boolean }
	if catFired[category] then
		return
	end
	local list = AchievementPopupConfig.getAchievementsByCategory(category)
	for _, ach in list do
		if not data.achievementsUnlocked[ach.id] then
			return
		end
	end
	if #list == 0 then
		return
	end
	catFired[category] = true
	local pool = (AchievementPopupConfig.CategoryComplete :: any)[category]
	local line = ""
	if type(pool) == "table" and #pool > 0 then
		line = AchievementPopupConfig.pickVariant(pool)
	end
	Remotes.getEvent("AchievementUnlocked"):FireClient(player, {
		kind = "category_complete",
		category = category,
		line = line,
	})
end

local function tryTotalCompletionToast(player: Player, data: any)
	ensureAchievementTables(data)
	local meta = data.achievementMeta :: any
	if meta.totalToastFired then
		return
	end
	for _, ach in AchievementPopupConfig.Achievements do
		if not data.achievementsUnlocked[ach.id] then
			return
		end
	end
	meta.totalToastFired = true
	Remotes.getEvent("AchievementUnlocked"):FireClient(player, {
		kind = "total_completion",
		line = AchievementPopupConfig.pickVariant(AchievementPopupConfig.TotalCompletion),
	})
end

function AchievementService.tryUnlock(player: Player, id: string)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)
	if data.achievementsUnlocked[id] then
		return
	end

	data.achievementsUnlocked[id] = true
	local rarity = RARITY_BY_ID[id] or "bronze"
	Remotes.getEvent("AchievementUnlocked"):FireClient(player, {
		kind = "unlock",
		id = id,
		rarity = rarity,
	})
	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	local def = AchievementPopupConfig.getAchievementById(id)
	if def and type(def.category) == "string" then
		tryCategoryCompleteToast(player, data, def.category)
	end
	tryTotalCompletionToast(player, data)
end

local function pushProgressBigSpender(player: Player, data: any)
	ensureAchievementTables(data)
	local cur = math.min(data.coinsSpentTotal, BIG_SPENDER_TARGET)
	AchievementService.fireProgress(player, "big_spender", cur, BIG_SPENDER_TARGET)
end

local function pushProgressHatch100(player: Player, data: any)
	local hatched = 0
	if type(data.stats) == "table" and type(data.stats.totalEggsHatched) == "number" then
		hatched = data.stats.totalEggsHatched
	end
	AchievementService.fireProgress(player, "hatch_100", math.min(hatched, HATCH_100_TARGET), HATCH_100_TARGET)
end

local function pushProgressDailyStreak(player: Player, data: any)
	local streak = 0
	if type(data.dailyReward) == "table" and type(data.dailyReward.streak) == "number" then
		streak = data.dailyReward.streak
	end
	AchievementService.fireProgress(player, "daily_streak_7", math.min(streak, DAILY_STREAK_TARGET), DAILY_STREAK_TARGET)
end

local function pushProgressFullIndex(player: Player, data: any)
	local cur = countDiscoveredPets(data)
	AchievementService.fireProgress(player, "full_index", math.min(cur, TOTAL_PET_DEFS), TOTAL_PET_DEFS)
end

local function pushProgressWorldTourer(player: Player, data: any)
	local need = countUnlockedWorlds(data)
	local have = countWorldsRun(data)
	AchievementService.fireProgress(player, "world_tourer", math.min(have, math.max(need, 1)), math.max(need, 1))
end

local function pushProgressRuns100(player: Player, data: any)
	local tr = 0
	if type(data.stats) == "table" and type(data.stats.totalRunsCompleted) == "number" then
		tr = data.stats.totalRunsCompleted
	end
	AchievementService.fireProgress(player, "runs_100", math.min(tr, RUNS_100_TARGET), RUNS_100_TARGET)
end

local function pushProgressCoinTycoon(player: Player, data: any)
	local cur = 0
	if type(data.stats) == "table" and type(data.stats.totalCoinsEarned) == "number" then
		cur = data.stats.totalCoinsEarned
	end
	AchievementService.fireProgress(player, "coin_tycoon", math.min(cur, COIN_TYCOON_TARGET), COIN_TYCOON_TARGET)
end

function AchievementService.onCoinsSpent(player: Player, data: any)
	ensureAchievementTables(data)
	pushProgressBigSpender(player, data)
	if data.coinsSpentTotal >= BIG_SPENDER_TARGET then
		AchievementService.tryUnlock(player, "big_spender")
	end
end

function AchievementService.noteSessionStart(player: Player)
	sessionStartUnix[player.UserId] = os.time()
end

function AchievementService.checkNightOwlSession(player: Player)
	local t0 = sessionStartUnix[player.UserId]
	if not t0 then
		return
	end
	if os.time() - t0 >= NIGHT_OWL_SESSION_SEC then
		AchievementService.tryUnlock(player, "night_owl")
	end
end

function AchievementService.onRunEnded(player: Player, run: { worldId: string, speed: number, maxNearMissChain: number?, laps: number? })
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)

	local totalRuns = 0
	if type(data.stats) == "table" and type(data.stats.totalRunsCompleted) == "number" then
		totalRuns = data.stats.totalRunsCompleted
		if totalRuns >= 1 then
			AchievementService.tryUnlock(player, "first_drive")
		end
		if totalRuns >= RUNS_10_TARGET then
			AchievementService.tryUnlock(player, "runs_10")
		end
		if totalRuns >= RUNS_100_TARGET then
			AchievementService.tryUnlock(player, "runs_100")
		end
	end

	local chain = if type(run.maxNearMissChain) == "number" then run.maxNearMissChain else 0
	if chain >= COMBO_INFERNO_THRESHOLD then
		AchievementService.tryUnlock(player, "combo_inferno")
	end

	if run.speed >= SPEED_DEMON_THRESHOLD then
		AchievementService.tryUnlock(player, "speed_demon")
	end
	if run.speed >= SECRET_SPEED_THRESHOLD then
		AchievementService.tryUnlock(player, "secret_speed_demon")
	end
	local lapsInRun = if type(run.laps) == "number" then run.laps else 0
	if lapsInRun >= LAP_LEGEND_THRESHOLD then
		AchievementService.tryUnlock(player, "lap_legend")
	end

	data.worldsWithCompletedRun[run.worldId] = true

	local need = countUnlockedWorlds(data)
	local have = countWorldsRun(data)
	pushProgressWorldTourer(player, data)
	if need > 0 and have >= need then
		AchievementService.tryUnlock(player, "world_tourer")
	end
end

function AchievementService.onEggHatched(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)

	local hatched = 0
	if type(data.stats) == "table" and type(data.stats.totalEggsHatched) == "number" then
		hatched = data.stats.totalEggsHatched
	end

	if hatched >= 1 then
		AchievementService.tryUnlock(player, "first_hatch")
	end
	pushProgressHatch100(player, data)
	if hatched >= HATCH_100_TARGET then
		AchievementService.tryUnlock(player, "hatch_100")
	end

	local discovered = countDiscoveredPets(data)
	pushProgressFullIndex(player, data)
	if TOTAL_PET_DEFS > 0 and discovered >= TOTAL_PET_DEFS then
		AchievementService.tryUnlock(player, "full_index")
	end
end

function AchievementService.onRebirth(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)
	if type(data.rebirths) == "number" and data.rebirths >= 1 then
		AchievementService.tryUnlock(player, "rebirth_one")
	end
	if type(data.rebirths) == "number" and data.rebirths >= REBIRTH_ROYALTY_THRESHOLD then
		AchievementService.tryUnlock(player, "rebirth_royalty")
	end
end

function AchievementService.onDailyClaimed(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)
	pushProgressDailyStreak(player, data)
	if type(data.dailyReward) == "table" and type(data.dailyReward.streak) == "number" then
		if data.dailyReward.streak >= DAILY_STREAK_TARGET then
			AchievementService.tryUnlock(player, "daily_streak_7")
		end
		if data.dailyReward.streak >= DAILY_STREAK_30_TARGET then
			AchievementService.tryUnlock(player, "daily_streak_30")
		end
	end
end

function AchievementService.onLeaderboardRank(player: Player, newRank: number?, prevRank: number?)
	if type(newRank) ~= "number" then
		return
	end
	if newRank == 1 then
		AchievementService.tryUnlock(player, "number_one")
	end
	if newRank <= 10 and newRank >= 1 and (prevRank == nil or prevRank > 10) then
		AchievementService.tryUnlock(player, "top_ten")
	end
end

function AchievementService.syncProgressNudges(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)
	pushProgressBigSpender(player, data)
	pushProgressHatch100(player, data)
	pushProgressDailyStreak(player, data)
	pushProgressFullIndex(player, data)
	pushProgressWorldTourer(player, data)
	pushProgressRuns100(player, data)
	pushProgressCoinTycoon(player, data)
	AchievementService.onGarageMaybeComplete(player)

	if type(data.stats) == "table" and type(data.stats.totalRunsCompleted) == "number" then
		local tr = data.stats.totalRunsCompleted
		if tr >= RUNS_10_TARGET then
			AchievementService.tryUnlock(player, "runs_10")
		end
		if tr >= RUNS_100_TARGET then
			AchievementService.tryUnlock(player, "runs_100")
		end
	end
	if type(data.dailyReward) == "table" and type(data.dailyReward.streak) == "number" then
		if data.dailyReward.streak >= DAILY_STREAK_30_TARGET then
			AchievementService.tryUnlock(player, "daily_streak_30")
		end
	end
	if type(data.milestoneCopyClaimed) == "table" then
		local sorted = WorldConfig.getWorldsSorted()
		if #sorted > 0 then
			local lastId = sorted[#sorted].id
			local wm = (data.milestoneCopyClaimed :: any).worldMastery
			if type(wm) == "table" and wm[lastId] == true then
				AchievementService.tryUnlock(player, "world_elite")
			end
		end
	end
	if type(data.discoveredEasterEggs) == "table" then
		for _, v in data.discoveredEasterEggs do
			if v == true then
				AchievementService.tryUnlock(player, "egg_hunter")
				break
			end
		end
	end
	if type(data.stats) == "table" and type(data.stats.questsCompletedTotal) == "number" then
		if data.stats.questsCompletedTotal >= QUEST_VETERAN_TARGET then
			AchievementService.tryUnlock(player, "quest_veteran")
		end
	end
	if type(data.stats) == "table" and type(data.stats.totalCoinsEarned) == "number" then
		if data.stats.totalCoinsEarned >= COIN_TYCOON_TARGET then
			AchievementService.tryUnlock(player, "coin_tycoon")
		end
	end
	if type(data.rebirths) == "number" and data.rebirths >= REBIRTH_ROYALTY_THRESHOLD then
		AchievementService.tryUnlock(player, "rebirth_royalty")
	end
	AchievementService.checkNightOwlSession(player)
end

function AchievementService.onTotalCoinsEarned(player: Player, data: any)
	ensureAchievementTables(data)
	pushProgressCoinTycoon(player, data)
	local cur = 0
	if type(data.stats) == "table" and type(data.stats.totalCoinsEarned) == "number" then
		cur = data.stats.totalCoinsEarned
	end
	if cur >= COIN_TYCOON_TARGET then
		AchievementService.tryUnlock(player, "coin_tycoon")
	end
end

function AchievementService.onQuestCompleted(player: Player, data: any)
	ensureAchievementTables(data)
	local n = 0
	if type(data.stats) == "table" and type(data.stats.questsCompletedTotal) == "number" then
		n = data.stats.questsCompletedTotal
	end
	if n >= QUEST_VETERAN_TARGET then
		AchievementService.tryUnlock(player, "quest_veteran")
	end
end

function AchievementService.onEasterEggFound(player: Player)
	AchievementService.tryUnlock(player, "egg_hunter")
end

function AchievementService.onGarageMaybeComplete(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureAchievementTables(data)
	local need = 0
	for _ in CarConfig.Cars do
		need += 1
	end
	local have = 0
	for _ in data.cars do
		have += 1
	end
	if need > 0 and have >= need then
		AchievementService.tryUnlock(player, "garage_full")
	end
end

function AchievementService.buildSnapshot(player: Player): any
	local data = DataManager.get(player)
	if not data then
		return {}
	end
	ensureAchievementTables(data)

	local hatched = 0
	if type(data.stats) == "table" and type(data.stats.totalEggsHatched) == "number" then
		hatched = data.stats.totalEggsHatched
	end
	local streak = 0
	if type(data.dailyReward) == "table" and type(data.dailyReward.streak) == "number" then
		streak = data.dailyReward.streak
	end

	return {
		unlocked = data.achievementsUnlocked,
		seen = data.achievementsSeen,
		coinsSpentTotal = data.coinsSpentTotal,
		worldsWithCompletedRun = data.worldsWithCompletedRun,
		totalEggsHatched = hatched,
		dailyStreak = streak,
		discoveredPetCount = countDiscoveredPets(data),
		totalPetDefs = TOTAL_PET_DEFS,
		unlockedWorldCount = countUnlockedWorlds(data),
		worldsRunCount = countWorldsRun(data),
	}
end

function AchievementService.init()
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player: Player)
		sessionStartUnix[player.UserId] = nil
	end)

	Remotes.getFunction("GetAchievementData").OnServerInvoke = function(player: Player)
		if not ValidationService.checkRemoteRate(player, "GetAchievementData") then
			return nil
		end
		return AchievementService.buildSnapshot(player)
	end

	Remotes.getEvent("MarkAchievementsSeen").OnServerEvent:Connect(function(player: Player)
		if not ValidationService.checkRemoteRate(player, "MarkAchievementsSeen") then
			return
		end
		if not RemoteCooldown.allow(player, "MarkAchievementsSeen", 0.5) then
			return
		end
		local data = DataManager.get(player)
		if not data then
			return
		end
		ensureAchievementTables(data)
		for id, v in data.achievementsUnlocked do
			if v == true then
				data.achievementsSeen[id] = true
			end
		end
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
	end)
end

return AchievementService
