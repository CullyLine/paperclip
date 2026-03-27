--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
-- local QuestService = require(script.Parent:WaitForChild("QuestService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local FirstSessionOnboardingService = require(script.Parent:WaitForChild("FirstSessionOnboardingService"))

local EggService = {}

-- Config egg ids are short snake_case; reject garbage from remotes.
local MAX_EGG_ID_LEN = 64

local function countDiscoveredSpecies(map: { [string]: boolean }): number
	local n = 0
	for _, v in pairs(map) do
		if v then
			n += 1
		end
	end
	return n
end

local RARE_PLUS_RARITIES: { [string]: boolean } = {
	rare = true,
	epic = true,
	legendary = true,
	mythic = true,
}

local function effectiveDropWeight(drop: any, luckyEggs: boolean, ultraLucky: boolean): number
	local weight = drop.weight
	if luckyEggs and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
		weight = weight * 2
	end
	if ultraLucky and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
		weight = weight * 3
	end
	return weight
end

-- Shown on server drop feed; matches the same weight rules as the roll (passes, pity not modeled here).
local function formatDropOddsLabel(drop: any, eggDef: any, luckyEggs: boolean, ultraLucky: boolean): string
	local total = 0
	for _, d in eggDef.drops do
		total += effectiveDropWeight(d, luckyEggs, ultraLucky)
	end
	local w = effectiveDropWeight(drop, luckyEggs, ultraLucky)
	if total <= 0 or w <= 0 then
		return ""
	end
	local pct = w / total * 100
	if pct >= 10 then
		return string.format("~%.0f%%", pct)
	elseif pct >= 1 then
		return string.format("~%.1f%%", pct)
	elseif pct >= 0.01 then
		return string.format("~%.2f%%", pct)
	else
		return "~<0.01%"
	end
end

local function rollDrop(drops: { any }, luckyEggs: boolean, ultraLucky: boolean): any
	local totalWeight = 0
	for _, drop in drops do
		totalWeight += effectiveDropWeight(drop, luckyEggs, ultraLucky)
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, drop in drops do
		local weight = effectiveDropWeight(drop, luckyEggs, ultraLucky)
		cumulative += weight
		if roll <= cumulative then
			return drop
		end
	end

	return drops[#drops]
end

function EggService.buyEgg(player: Player, eggId: string): (boolean, string?)
	local eggDef = EggConfig.Eggs[eggId]
	if not eggDef then
		ValidationService.logAnomalyOncePerSession(player, "buy_unknown_egg", eggId)
		return false, "Egg not found"
	end

	local data = DataManager.get(player)
	if not data then return false, "No data" end

	-- Check world unlock
	if not data.unlockedWorlds[eggDef.worldId] then
		return false, "World not unlocked"
	end

	-- Check inventory capacity
	local totalEggs = 0
	for _, count in data.eggs do
		totalEggs += count
	end
	if totalEggs >= Constants.MAX_EGGS_INVENTORY then
		return false, "Egg inventory full"
	end

	if not CurrencyService.spend(player, eggDef.currency, eggDef.price) then
		return false, "Not enough " .. eggDef.currency
	end

	data.eggs[eggId] = (data.eggs[eggId] or 0) + 1
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function EggService.hatchEgg(player: Player, eggId: string): (boolean, string?, any?)
	local eggDef = EggConfig.Eggs[eggId]
	if not eggDef then
		ValidationService.logAnomalyOncePerSession(player, "hatch_unknown_egg", eggId)
		return false, "Egg not found", nil
	end

	local data = DataManager.get(player)
	if not data then return false, "No data", nil end

	if not data.eggs[eggId] or data.eggs[eggId] <= 0 then
		return false, "No eggs of this type", nil
	end

	local petCountBefore = 0
	for _ in data.pets do
		petCountBefore += 1
	end

	-- Consume egg
	data.eggs[eggId] -= 1
	if data.eggs[eggId] <= 0 then
		data.eggs[eggId] = nil
	end

	-- Roll for pet
	local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
	local luckyEggs = GamePassService.hasPass(player, "lucky_eggs")
	local ultraLucky = GamePassService.hasPass(player, "ultra_lucky")
	local drop = rollDrop(eggDef.drops, luckyEggs, ultraLucky)

	local petDef = PetConfig.Pets[drop.petId]
	if not petDef then return false, "Invalid pet drop", nil end

	-- Create pet instance
	local petUid = Utils.generateUID()
	data.pets[petUid] = {
		uid = petUid,
		id = drop.petId,
		power = petDef.basePower,
		equipped = false,
	}

	data.stats.totalEggsHatched += 1
	local prevIndexCount = countDiscoveredSpecies(data.discoveredPets)
	data.discoveredPets[drop.petId] = true
	local newIndexCount = countDiscoveredSpecies(data.discoveredPets)

	-- QuestService.onEggHatch(player)
	TutorialService.onHatch(player)

	if petCountBefore == 0 then
		FirstSessionOnboardingService.markPendingFirstHatch(player)
		MilestoneCeremonyService.tryFirstTime(player, data, "FirstPetHatched", { PetName = petDef.name })
	end
	MilestoneCeremonyService.tryPetIndexMilestones(player, data, prevIndexCount, newIndexCount)

	AchievementService.onEggHatched(player)
	if eggId == "basic_egg" and (drop.rarity == "legendary" or drop.rarity == "mythic") then
		AchievementService.tryUnlock(player, "egg_straordinary")
	end
	if drop.rarity == "legendary" or drop.rarity == "mythic" then
		AchievementService.tryUnlock(player, "legendary_hatch")
	end

	if drop.rarity == "legendary" or drop.rarity == "mythic" then
		local EconomyLogService = require(script.Parent:WaitForChild("EconomyLogService"))
		EconomyLogService.logRareHatch(player, eggId, drop.petId, drop.rarity)
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	local feedOddsLabel = formatDropOddsLabel(drop, eggDef, luckyEggs, ultraLucky)

	local result = {
		eggId = eggId,
		petUid = petUid,
		petId = drop.petId,
		petName = petDef.name,
		rarity = drop.rarity,
		power = petDef.basePower,
		feedOddsLabel = feedOddsLabel,
	}

	return true, nil, result
end

function EggService.init()
	Remotes.getEvent("BuyEgg").OnServerEvent:Connect(function(player, eggId)
		if not ValidationService.checkRemoteRate(player, "BuyEgg") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(eggId) ~= "string" then
			return
		end
		if eggId == "" or #eggId > MAX_EGG_ID_LEN then
			if eggId == "" then
				ValidationService.logAnomalyOncePerSession(player, "buy_empty_egg_id", "")
			else
				ValidationService.logAnomalyOncePerSession(player, "buy_egg_id_len", "")
			end
			return
		end
		if not RemoteCooldown.allow(player, "BuyEgg", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = EggService.buyEgg(player, eggId)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Failed to buy egg",
			})
		end
	end)

	Remotes.getEvent("HatchEgg").OnServerEvent:Connect(function(player, eggId)
		if not ValidationService.checkRemoteRate(player, "HatchEgg") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(eggId) ~= "string" then
			return
		end
		if eggId == "" or #eggId > MAX_EGG_ID_LEN then
			if eggId == "" then
				ValidationService.logAnomalyOncePerSession(player, "hatch_empty_egg_id", "")
			else
				ValidationService.logAnomalyOncePerSession(player, "hatch_egg_id_len", "")
			end
			return
		end
		if not RemoteCooldown.allow(player, "HatchEgg", 0.25) then
			return
		end
		local success, err, result = EggService.hatchEgg(player, eggId)
		if success and result then
			Remotes.getEvent("HatchEgg"):FireClient(player, result)
			if type(result.rarity) == "string" and RARE_PLUS_RARITIES[string.lower(result.rarity)] then
				local oddsText = if type(result.feedOddsLabel) == "string" then result.feedOddsLabel else ""
				Remotes.getEvent("ServerDropFeed"):FireAllClients({
					playerName = player.DisplayName,
					petName = result.petName,
					rarity = result.rarity,
					userId = player.UserId,
					oddsText = oddsText,
				})
			end
		elseif not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Failed to hatch egg",
			})
		end
	end)
end

return EggService
