--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local QuestConfig = require(DAC:WaitForChild("Config"):WaitForChild("QuestConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local _battlePassService: any = nil
local function getBattlePassService()
	if not _battlePassService then
		_battlePassService = require(script.Parent:WaitForChild("BattlePassService"))
	end
	return _battlePassService
end

local _validationService: any = nil
local function getValidationService()
	if not _validationService then
		_validationService = require(script.Parent:WaitForChild("ValidationService"))
	end
	return _validationService
end

local QuestService = {}

local function utcDayKey(): number
	return math.floor(os.time() / 86400)
end

local function utcMondayWeekKey(): number
	local t = os.date("!*t", os.time())
	local daysBack = (t.wday - 2) % 7
	local mondayYday = t.yday - daysBack
	return t.year * 1000 + mondayYday
end

local function sync(player: Player)
	local data = DataManager.get(player)
	if data then
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
	end
end

local function ensureQuestTable(data: any)
	if not data.quests then
		data.quests = {}
	end
	local q = data.quests
	if q.seasonPlayDays == nil then
		q.seasonPlayDays = {}
	end
	if q.worldsEarnedCoins == nil then
		q.worldsEarnedCoins = {}
	end
	if q.uniquePetEquipsSeason == nil then
		q.uniquePetEquipsSeason = {}
	end
	if q.worldsVisitedDay == nil then
		q.worldsVisitedDay = {}
	end
	if q.worldsVisitedWeek == nil then
		q.worldsVisitedWeek = {}
	end
	if q.milestone == nil then
		q.milestone = {}
	end
	if q.daily == nil then
		q.daily = {}
	end
	if q.weekly == nil then
		q.weekly = {}
	end
	if q.rebirthsWeek == nil then
		q.rebirthsWeek = 0
	end
	if q.eggsWeek == nil then
		q.eggsWeek = 0
	end
	if q.coinsEarnedWeek == nil then
		q.coinsEarnedWeek = 0
	end
end

local function resetSeasonQuestStats(q: any)
	q.seasonPlayDays = {}
	q.worldsEarnedCoinsDay = 0
	q.worldsEarnedCoins = {}
	q.seasonDistance = 0
	q.seasonLaps = 0
	q.seasonEggs = 0
	q.seasonCoins = 0
	q.seasonRebirths = 0
	q.seasonRuns = 0
	q.uniquePetEquipsSeason = {}
	q.coinsEarnedWeek = 0
	q.worldsVisitedDayKey = 0
	q.worldsVisitedDay = {}
	q.worldsVisitedWeekKey = 0
	q.worldsVisitedWeek = {}
	q.rebirthsWeek = 0
	q.eggsWeek = 0
	q.milestone = {}
end

local function pickRandom(pool: { any }, count: number): { any }
	local copy = table.clone(pool)
	local out = {}
	for _ = 1, math.min(count, #copy) do
		local idx = math.random(1, #copy)
		table.insert(out, copy[idx])
		table.remove(copy, idx)
	end
	return out
end

local function newSlot(defId: string): any
	return {
		defId = defId,
		progress = 0,
		completed = false,
	}
end

local function initMilestones(q: any)
	q.milestone = {}
	for _, def in QuestConfig.Milestones do
		q.milestone[def.id] = {
			progress = 0,
			completed = false,
		}
	end
end

local function milestoneTierOk(player: Player, def: any): boolean
	local data = DataManager.get(player)
	if not data or not data.battlePass then
		return false
	end
	local minT = def.minTier or 1
	local tier = select(1, BattlePassConfig.tierFromXp(data.battlePass.xp or 0))
	return tier >= minT
end

local function completeQuest(player: Player, slot: any, def: any)
	if slot.completed then
		return
	end
	slot.progress = def.target
	slot.completed = true
	getBattlePassService().awardXp(player, def.xpReward)
	Remotes.getEvent("Notification"):FireClient(player, {
		type = "reward_claim",
		title = "Quest Complete",
		subtitle = def.title,
		message = `Quest complete: {def.title} (+{def.xpReward} Season XP)`,
		items = {
			{ label = "Season XP", amount = def.xpReward or 0, kind = "xp" },
		},
	})

	local pdata = DataManager.get(player)
	if pdata then
		MilestoneCeremonyService.tryFirstTime(player, pdata, "FirstQuestCompleted", nil)
	end
end

local function bumpProgress(player: Player, slot: any, def: any, add: number)
	if slot.completed or not milestoneTierOk(player, def) then
		return
	end
	if def.id == "m_midnight_legend" then
		return
	end
	slot.progress = math.min(def.target, slot.progress + add)
	if slot.progress >= def.target then
		completeQuest(player, slot, def)
	end
end

local function countKeys(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function syncSeasonMilestones(player: Player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	local playDays = countKeys(q.seasonPlayDays)

	for _, def in QuestConfig.Milestones do
		local slot = q.milestone[def.id]
		if not slot or slot.completed then
			continue
		end
		if def.objectiveType == "season_runs" then
			slot.progress = q.seasonRuns
		elseif def.objectiveType == "unique_days" then
			slot.progress = playDays
		elseif def.objectiveType == "distance_driven" and def.scope == "season" then
			slot.progress = q.seasonDistance
		elseif def.objectiveType == "eggs_hatched" and def.scope == "season" then
			slot.progress = q.seasonEggs
		elseif def.objectiveType == "laps_completed" and def.scope == "season" then
			slot.progress = q.seasonLaps
		elseif def.objectiveType == "rebirths" and def.scope == "season" then
			slot.progress = q.seasonRebirths
		elseif def.objectiveType == "coins_earned_season" then
			slot.progress = q.seasonCoins
		elseif def.objectiveType == "worlds_coins_one_day" then
			slot.progress = countKeys(q.worldsEarnedCoins)
		elseif def.objectiveType == "all_milestones" then
			continue
		else
			continue
		end
		if slot.progress >= def.target and milestoneTierOk(player, def) then
			completeQuest(player, slot, def)
		end
	end
end

local function checkMidnightLegend(player: Player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	local legend = q.milestone["m_midnight_legend"]
	if not legend or legend.completed then
		return
	end
	local allDone = true
	for _, def in QuestConfig.Milestones do
		if def.id == "m_midnight_legend" then
			continue
		end
		local s = q.milestone[def.id]
		if not s or not s.completed then
			allDone = false
			break
		end
	end
	if allDone then
		local def = QuestConfig.getById("m_midnight_legend")
		if def then
			completeQuest(player, legend, def)
		end
	end
end

function QuestService.ensureQuests(player: Player)
	getBattlePassService().ensureSeason(player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	ensureQuestTable(data)
	local q = data.quests
	local sid = BattlePassConfig.Season.id
	if q.seasonId ~= sid then
		q.seasonId = sid
		q.lastDailyResetDay = 0
		q.lastWeeklyResetWeek = 0
		q.daily = {}
		q.weekly = {}
		resetSeasonQuestStats(q)
		initMilestones(q)
	end

	local day = utcDayKey()
	if q.lastDailyResetDay ~= day then
		q.lastDailyResetDay = day
		local picks = pickRandom(QuestConfig.DailyPool, 3)
		q.daily = {}
		for _, def in picks do
			table.insert(q.daily, newSlot(def.id))
		end
	end

	local wk = utcMondayWeekKey()
	if q.lastWeeklyResetWeek ~= wk then
		q.lastWeeklyResetWeek = wk
		local picks = pickRandom(QuestConfig.WeeklyPool, 3)
		q.weekly = {}
		for _, def in picks do
			table.insert(q.weekly, newSlot(def.id))
		end
		q.coinsEarnedWeek = 0
		q.rebirthsWeek = 0
		q.eggsWeek = 0
		q.worldsVisitedWeekKey = wk
		q.worldsVisitedWeek = {}
	end

	if q.worldsVisitedDayKey ~= day then
		q.worldsVisitedDayKey = day
		q.worldsVisitedDay = {}
	end

	if q.worldsEarnedCoinsDay ~= day then
		q.worldsEarnedCoinsDay = day
		q.worldsEarnedCoins = {}
	end

	q.seasonPlayDays[day] = true
end

local function applySlotRun(player: Player, slot: any, def: any, dist: number, laps: number, coins: number, worldId: string)
	if slot.completed then
		return
	end
	if def.objectiveType == "distance_driven" then
		if def.scope == "daily" or def.scope == "weekly" then
			bumpProgress(player, slot, def, dist)
		end
	elseif def.objectiveType == "distance_in_world" then
		if worldId == def.worldId and (def.scope == "daily" or def.scope == "weekly") then
			bumpProgress(player, slot, def, dist)
		end
	elseif def.objectiveType == "laps_completed" then
		if def.scope == "daily" or def.scope == "weekly" then
			bumpProgress(player, slot, def, laps)
		end
	elseif def.objectiveType == "coins_single_run" then
		if def.scope == "daily" or def.scope == "weekly" then
			if coins >= def.target then
				completeQuest(player, slot, def)
			end
		end
	elseif def.objectiveType == "coins_earned_week" then
		if def.scope == "weekly" then
			local data = DataManager.get(player)
			if data and data.quests then
				slot.progress = data.quests.coinsEarnedWeek
				if slot.progress >= def.target then
					completeQuest(player, slot, def)
				end
			end
		end
	end
end

function QuestService.onRunEnd(player: Player, payload: { [string]: any })
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	local dist = payload.distance or 0
	local laps = payload.laps or 0
	local coins = payload.coinsEarned or 0
	local worldId = payload.worldId or ""

	q.seasonRuns += 1
	q.seasonDistance += dist
	q.seasonLaps += laps
	q.seasonCoins += coins
	q.coinsEarnedWeek += coins

	if coins > 0 and worldId ~= "" then
		q.worldsEarnedCoins[worldId] = true
	end

	for _, slot in q.daily do
		local def = QuestConfig.getById(slot.defId)
		if def then
			applySlotRun(player, slot, def, dist, laps, coins, worldId)
		end
	end
	for _, slot in q.weekly do
		local def = QuestConfig.getById(slot.defId)
		if def then
			applySlotRun(player, slot, def, dist, laps, coins, worldId)
		end
	end

	syncSeasonMilestones(player)
	checkMidnightLegend(player)
	sync(player)
	DataManager.save(player)
end

function QuestService.onEggHatch(player: Player)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	q.seasonEggs += 1
	q.eggsWeek += 1

	for _, slot in q.daily do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "eggs_hatched" and def.scope == "daily" then
			bumpProgress(player, slot, def, 1)
		end
	end
	for _, slot in q.weekly do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "eggs_hatched" and def.scope == "weekly" then
			slot.progress = q.eggsWeek
			if slot.progress >= def.target and not slot.completed then
				completeQuest(player, slot, def)
			end
		end
	end

	syncSeasonMilestones(player)
	checkMidnightLegend(player)
	sync(player)
end

function QuestService.onRebirth(player: Player)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	q.seasonRebirths += 1
	q.rebirthsWeek += 1

	for _, slot in q.daily do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "rebirths" and def.scope == "daily" then
			bumpProgress(player, slot, def, 1)
		end
	end
	for _, slot in q.weekly do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "rebirths" and def.scope == "weekly" then
			slot.progress = q.rebirthsWeek
			if slot.progress >= def.target and not slot.completed then
				completeQuest(player, slot, def)
			end
		end
	end

	syncSeasonMilestones(player)
	checkMidnightLegend(player)
	sync(player)
end

function QuestService.onUpgrade(player: Player)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	for _, slot in data.quests.daily do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "upgrades" and def.scope == "daily" then
			bumpProgress(player, slot, def, 1)
		end
	end
	checkMidnightLegend(player)
	sync(player)
	DataManager.save(player)
end

function QuestService.onWorldChanged(player: Player, worldId: string)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	q.worldsVisitedDay[worldId] = true
	q.worldsVisitedWeek[worldId] = true

	local dayCount = countKeys(q.worldsVisitedDay)
	local weekCount = countKeys(q.worldsVisitedWeek)

	for _, slot in q.daily do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "worlds_unique_day" and def.scope == "daily" then
			slot.progress = dayCount
			if dayCount >= def.target and not slot.completed then
				completeQuest(player, slot, def)
			end
		end
	end
	for _, slot in q.weekly do
		local def = QuestConfig.getById(slot.defId)
		if def and def.objectiveType == "worlds_unique_week" and def.scope == "weekly" then
			slot.progress = weekCount
			if weekCount >= def.target and not slot.completed then
				completeQuest(player, slot, def)
			end
		end
	end

	checkMidnightLegend(player)
	sync(player)
end

function QuestService.evaluatePetArmy(player: Player)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	local equipped = 0
	for _, pet in data.pets do
		if pet.equipped then
			equipped += 1
		end
	end
	local slotArmy = q.milestone["m_pet_army"]
	local defArmy = QuestConfig.getById("m_pet_army")
	if slotArmy and defArmy and not slotArmy.completed then
		slotArmy.progress = equipped
		if equipped >= defArmy.target and milestoneTierOk(player, defArmy) then
			completeQuest(player, slotArmy, defArmy)
		end
	end
	syncSeasonMilestones(player)
	checkMidnightLegend(player)
	sync(player)
end

function QuestService.onPetEquip(player: Player, petUid: string)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return
	end
	local q = data.quests
	if not q.uniquePetEquipsSeason[petUid] then
		q.uniquePetEquipsSeason[petUid] = true
		for _, slot in q.daily do
			local def = QuestConfig.getById(slot.defId)
			if def and def.objectiveType == "pet_equip_unique" and def.scope == "daily" then
				bumpProgress(player, slot, def, 1)
			end
		end
	end

	QuestService.evaluatePetArmy(player)
end

function QuestService.init()
	Remotes.getFunction("GetQuests").OnServerInvoke = function(player: Player)
		if not getValidationService().checkRemoteRate(player, "GetQuests") then
			return nil
		end
		QuestService.ensureQuests(player)
		return DataManager.get(player)
	end
end

--[[
	Force-complete a quest that exists in current daily/weekly slots or milestone map (admin).
]]
function QuestService.adminForceCompleteQuest(player: Player, questKey: string): (boolean, string?)
	QuestService.ensureQuests(player)
	local data = DataManager.get(player)
	if not data or not data.quests then
		return false, "No data"
	end
	local def = QuestConfig.getById(questKey)
	if not def then
		return false, "Unknown quest id"
	end
	local q = data.quests
	local slot: any = nil
	for _, s in q.daily do
		if s.defId == questKey then
			slot = s
			break
		end
	end
	if not slot then
		for _, s in q.weekly do
			if s.defId == questKey then
				slot = s
				break
			end
		end
	end
	if not slot then
		slot = q.milestone[questKey]
	end
	if not slot then
		return false, "Quest not in active daily/weekly/milestone slots"
	end
	if slot.completed then
		return false, "Already completed"
	end
	completeQuest(player, slot, def)
	syncSeasonMilestones(player)
	checkMidnightLegend(player)
	sync(player)
	return true, nil
end

return QuestService
