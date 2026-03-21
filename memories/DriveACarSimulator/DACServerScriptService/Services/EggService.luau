--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local EggService = {}

local function rollDrop(drops: { any }, luckyEggs: boolean, ultraLucky: boolean): any
	local totalWeight = 0
	for _, drop in drops do
		local weight = drop.weight
		if luckyEggs and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
			weight = weight * 2
		end
		if ultraLucky and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
			weight = weight * 3
		end
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, drop in drops do
		local weight = drop.weight
		if luckyEggs and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
			weight = weight * 2
		end
		if ultraLucky and drop.rarity ~= "common" and drop.rarity ~= "uncommon" then
			weight = weight * 3
		end
		cumulative += weight
		if roll <= cumulative then
			return drop
		end
	end

	return drops[#drops]
end

function EggService.buyEgg(player: Player, eggId: string): (boolean, string?)
	local eggDef = EggConfig.Eggs[eggId]
	if not eggDef then return false, "Egg not found" end

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
	if not eggDef then return false, "Egg not found", nil end

	local data = DataManager.get(player)
	if not data then return false, "No data", nil end

	if not data.eggs[eggId] or data.eggs[eggId] <= 0 then
		return false, "No eggs of this type", nil
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
	data.discoveredPets[drop.petId] = true

	QuestService.onEggHatch(player)
	TutorialService.onHatch(player)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	local result = {
		eggId = eggId,
		petUid = petUid,
		petId = drop.petId,
		petName = petDef.name,
		rarity = drop.rarity,
		power = petDef.basePower,
	}

	return true, nil, result
end

function EggService.init()
	Remotes.getEvent("BuyEgg").OnServerEvent:Connect(function(player, eggId)
		if type(eggId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "BuyEgg") then
			return
		end
		if not RemoteCooldown.allow(player, "BuyEgg", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = EggService.buyEgg(player, eggId)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Failed to buy egg",
			})
		end
	end)

	Remotes.getEvent("HatchEgg").OnServerEvent:Connect(function(player, eggId)
		if type(eggId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "HatchEgg") then
			return
		end
		if not RemoteCooldown.allow(player, "HatchEgg", 0.25) then
			return
		end
		local success, err, result = EggService.hatchEgg(player, eggId)
		if success and result then
			Remotes.getEvent("HatchEgg"):FireClient(player, result)
		elseif not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Failed to hatch egg",
			})
		end
	end)
end

return EggService
