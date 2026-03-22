--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local PetService = {}

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

local function getNextRarity(rarity: string): string?
	for i, r in RARITY_ORDER do
		if r == rarity and i < #RARITY_ORDER then
			return RARITY_ORDER[i + 1]
		end
	end
	return nil
end

local function getRarityIndex(rarity: string): number
	for i, r in RARITY_ORDER do
		if r == rarity then return i end
	end
	return 0
end

local function countEquippedPets(data: any): number
	local count = 0
	for _, pet in data.pets do
		if pet.equipped then
			count += 1
		end
	end
	return count
end

--[[
	Effective pet coin multiplier for run payout (base modifier + pet_magnet +10%).
]]
function PetService.getEffectivePetCoinModifier(player: Player, equippedPets: { { power: number } }): number
	local base = Utils.calculatePetModifier(equippedPets)
	if GamePassService.hasPass(player, "pet_magnet") then
		return base * 1.1
	end
	return base
end

function PetService.equipPet(player: Player, petUid: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local pet = data.pets[petUid]
	if not pet then return false, "Pet not found" end

	if pet.equipped then return false, "Already equipped" end

	local maxSlots = data.maxPetSlots
	if countEquippedPets(data) >= maxSlots then
		return false, "All pet slots full"
	end

	pet.equipped = true
	QuestService.onPetEquip(player, petUid)
	TutorialService.onEquipPet(player)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function PetService.unequipPet(player: Player, petUid: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local pet = data.pets[petUid]
	if not pet then return false, "Pet not found" end

	if not pet.equipped then return false, "Not equipped" end

	pet.equipped = false
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function PetService.equipBest(player: Player)
	local data = DataManager.get(player)
	if not data then return end

	-- Unequip all
	for _, pet in data.pets do
		pet.equipped = false
	end

	-- Sort pets by power descending
	local sorted = {}
	for uid, pet in data.pets do
		table.insert(sorted, { uid = uid, power = pet.power })
	end
	table.sort(sorted, function(a, b)
		return a.power > b.power
	end)

	-- Equip the top N
	local maxSlots = data.maxPetSlots
	for i = 1, math.min(#sorted, maxSlots) do
		data.pets[sorted[i].uid].equipped = true
	end

	QuestService.evaluatePetArmy(player)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
end

function PetService.fusePets(player: Player, petUids: { string }): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local requiredCount = PetConfig.FuseCost.petsRequired
	if #petUids ~= requiredCount then
		return false, `Need exactly {requiredCount} pets to fuse`
	end

	-- Validate all pets exist and share a rarity tier
	local targetRarity: string? = nil
	local sacrificedNames: { string } = {}
	for _, uid in petUids do
		local pet = data.pets[uid]
		if not pet then return false, "Pet not found" end

		local petDef = PetConfig.Pets[pet.id]
		if not petDef then return false, "Invalid pet" end

		table.insert(sacrificedNames, petDef.name)

		if not targetRarity then
			targetRarity = petDef.rarity
		elseif petDef.rarity ~= targetRarity then
			return false, "All pets must be the same rarity"
		end
	end

	if not targetRarity then return false, "No pets selected" end

	local nextRarity = getNextRarity(targetRarity)
	if not nextRarity then return false, "Cannot fuse mythic pets" end

	-- Calculate and charge fuse cost
	local rarityIdx = getRarityIndex(targetRarity)
	local fuseCost = PetConfig.FuseCost.coinCost * (PetConfig.FuseCost.coinCostMultiplier ^ (rarityIdx - 1))
	if not CurrencyService.spend(player, "coins", math.floor(fuseCost)) then
		return false, "Not enough coins"
	end

	-- Remove fused pets
	local totalPower = 0
	for _, uid in petUids do
		totalPower += data.pets[uid].power
		data.pets[uid] = nil
	end

	-- Find a random pet of the next rarity
	local candidates = {}
	for petId, petDef in PetConfig.Pets do
		if petDef.rarity == nextRarity then
			table.insert(candidates, petId)
		end
	end

	if #candidates == 0 then return false, "No pets available at next rarity" end

	local chosenPetId = candidates[math.random(#candidates)]
	local chosenDef = PetConfig.Pets[chosenPetId]

	local HttpService = game:GetService("HttpService")
	local newUid = HttpService:GenerateGUID(false)

	-- Fused pet gets a power bonus from the sacrificed pets
	local fusedPower = chosenDef.basePower + math.floor(totalPower * 0.1)

	data.pets[newUid] = {
		uid = newUid,
		id = chosenPetId,
		power = fusedPower,
		equipped = false,
	}

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	Remotes.getEvent("FusionResult"):FireClient(player, {
		petId = chosenPetId,
		petName = chosenDef.name,
		modelName = chosenDef.modelName,
		rarity = chosenDef.rarity,
		power = fusedPower,
		previousPowerTotal = totalPower,
		sourceRarity = targetRarity,
		sacrificedNames = sacrificedNames,
	})

	return true, nil
end

function PetService.init()
	Remotes.getEvent("EquipPet").OnServerEvent:Connect(function(player, petUid)
		if type(petUid) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "EquipPet") then
			return
		end
		if not RemoteCooldown.allow(player, "EquipPet", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		if petUid == "__BEST__" then
			PetService.equipBest(player)
			return
		end
		PetService.equipPet(player, petUid)
	end)

	Remotes.getEvent("UnequipPet").OnServerEvent:Connect(function(player, petUid)
		if type(petUid) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "UnequipPet") then
			return
		end
		if not RemoteCooldown.allow(player, "UnequipPet", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		PetService.unequipPet(player, petUid)
	end)

	Remotes.getEvent("FusePets").OnServerEvent:Connect(function(player, petUids)
		if type(petUids) ~= "table" then return end
		if not ValidationService.checkRemoteRate(player, "FusePets") then
			return
		end
		if not RemoteCooldown.allow(player, "FusePets", 1) then
			return
		end
		local success, err = PetService.fusePets(player, petUids)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Fuse failed",
			})
		end
	end)
end

return PetService
