--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
-- local QuestService = require(script.Parent:WaitForChild("QuestService"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local PetService = {}

local function broadcastEquippedPets(player: Player)
	local data = DataManager.get(player)
	if not data or type(data.pets) ~= "table" then
		return
	end
	local equipped = {}
	for uid, pet in data.pets do
		if type(pet) == "table" and pet.equipped then
			local def = PetConfig.Pets[pet.id]
			local rarity = if def then def.rarity else "common"
			table.insert(equipped, { uid = uid, id = pet.id, rarity = rarity })
		end
	end
	Remotes.getEvent("PetEquipSync"):FireAllClients(player.UserId, equipped)
end

-- Roblox GUIDs are short ASCII; reject absurd client strings before table lookups.
local MAX_PET_UID_LEN = 128
-- Client-generated idempotency token (UUID); replay within TTL returns cached FusionResult only.
local MAX_FUSE_REQUEST_TOKEN_LEN = 48
local FUSE_IDEMPOTENCY_TTL_SEC = 180

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

local fusionInFlight: { [number]: boolean } = {}
local fusionIdempotencyCache: { [number]: { [string]: { payload: any, expiresAt: number } } } = {}

local function cleanupFusionState(userId: number)
	fusionInFlight[userId] = nil
	fusionIdempotencyCache[userId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	cleanupFusionState(player.UserId)
end)

local function isValidFuseRequestToken(token: string): boolean
	if #token == 0 or #token > MAX_FUSE_REQUEST_TOKEN_LEN then
		return false
	end
	for i = 1, #token do
		local b = string.byte(token, i)
		local ok = (b >= 48 and b <= 57) -- 0-9
			or (b >= 65 and b <= 90)
			or (b >= 97 and b <= 122)
			or b == 45 -- hyphen
		if not ok then
			return false
		end
	end
	return true
end

local function pruneExpiredFusionCache(uid: number)
	local bucket = fusionIdempotencyCache[uid]
	if not bucket then
		return
	end
	local now = os.clock()
	for token, entry in bucket do
		if entry.expiresAt <= now then
			bucket[token] = nil
		end
	end
end

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
	Pet training modifier: 1 + sum(equippedPetPower)/100.
	Used by TrainingService for power per tick. Pets no longer affect run payouts.
]]
function PetService.getEffectivePetTrainingModifier(player: Player, equippedPets: { { power: number } }): number
	local base = Utils.calculatePetModifier(equippedPets)
	if GamePassService.hasPass(player, "training_boost") then
		return base * 1.15
	end
	return base
end

function PetService.unequipAll(player: Player)
	local data = DataManager.get(player)
	if not data or type(data.pets) ~= "table" then
		return
	end
	if data.settings and data.settings.petLock then
		NotificationDispatchService.notify(player, {
			type = "error",
			message = "Pets are locked. Disable pet lock first.",
		})
		return
	end
	for _, pet in data.pets do
		pet.equipped = false
	end
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	broadcastEquippedPets(player)
end

function PetService.deletePet(player: Player, petUid: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data or type(data.pets) ~= "table" then
		return false, "No data"
	end
	if data.settings and data.settings.petLock then
		return false, "Pets are locked"
	end
	local pet = data.pets[petUid]
	if not pet then
		return false, "Pet not found"
	end
	if pet.equipped then
		return false, "Unequip pet before deleting"
	end
	data.pets[petUid] = nil
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	broadcastEquippedPets(player)
	return true, nil
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
	-- QuestService.onPetEquip(player, petUid)
	TutorialService.onEquipPet(player)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	broadcastEquippedPets(player)
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
	broadcastEquippedPets(player)
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

	-- QuestService.evaluatePetArmy(player)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	broadcastEquippedPets(player)
end

function PetService.fusePets(player: Player, petUids: { string }, requestToken: string?): (boolean, string?)
	local uid = player.UserId
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	if fusionInFlight[uid] then
		return false, "Fusion already in progress"
	end

	local tokenKey: string? = nil
	if requestToken ~= nil and requestToken ~= "" then
		if type(requestToken) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "fuse_bad_token_type", "")
			return false, "Invalid fusion request"
		end
		if not isValidFuseRequestToken(requestToken) then
			ValidationService.logAnomalyOncePerSession(player, "fuse_bad_token_shape", "")
			return false, "Invalid fusion request"
		end
		tokenKey = requestToken
		pruneExpiredFusionCache(uid)
		local cached = fusionIdempotencyCache[uid] and fusionIdempotencyCache[uid][requestToken]
		if cached and cached.expiresAt > os.clock() then
			Remotes.getEvent("FusionResult"):FireClient(player, cached.payload)
			return true, nil
		end
	end

	local requiredCount = PetConfig.FuseCost.petsRequired
	if #petUids ~= requiredCount then
		ValidationService.logAnomalyOncePerSession(player, "fuse_wrong_count", `expected {requiredCount} got {#petUids}`)
		return false, `Need exactly {requiredCount} pets to fuse`
	end

	local seenUid: { [string]: boolean } = {}
	for _, petUid in petUids do
		if type(petUid) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "fuse_bad_uid_type", "")
			return false, "Invalid pet selection"
		end
		if petUid == "" or #petUid > MAX_PET_UID_LEN then
			ValidationService.logAnomalyOncePerSession(player, "fuse_bad_uid_len", "")
			return false, "Invalid pet selection"
		end
		if seenUid[petUid] then
			ValidationService.logAnomalyOncePerSession(player, "fuse_duplicate_uid", petUid)
			return false, "Invalid pet selection"
		end
		seenUid[petUid] = true
	end

	-- Validate all pets exist, templates are authoritative, same rarity; reject equipped (server-owned state).
	local targetRarity: string? = nil
	local sacrificedNames: { string } = {}
	for _, petUid in petUids do
		local pet = data.pets[petUid]
		if not pet then return false, "Pet not found" end

		if type(pet.id) ~= "string" or pet.id == "" or #pet.id > 64 then
			ValidationService.logAnomalyOncePerSession(player, "fuse_bad_pet_id_field", petUid)
			return false, "Invalid pet"
		end

		local petDef = PetConfig.Pets[pet.id]
		if not petDef then
			ValidationService.logAnomalyOncePerSession(player, "fuse_unknown_template", pet.id)
			return false, "Invalid pet"
		end
		if petDef.id ~= pet.id then
			return false, "Invalid pet"
		end

		if pet.equipped == true then
			return false, "Unequip pets before fusing"
		end

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

	local candidates: { string } = {}
	for petId, def in PetConfig.Pets do
		if def.rarity == nextRarity then
			table.insert(candidates, petId)
		end
	end
	if #candidates == 0 then
		ValidationService.logViolation(player, "fuse_no_candidates", "critical", nextRarity)
		return false, "No pets available at next rarity"
	end

	-- Calculate and charge fuse cost (server-side only; client never sends a price).
	local rarityIdx = getRarityIndex(targetRarity)
	local fuseCost = PetConfig.FuseCost.coinCost * (PetConfig.FuseCost.coinCostMultiplier ^ (rarityIdx - 1))
	local fuseCostInt = math.floor(fuseCost)

	fusionInFlight[uid] = true

	if not CurrencyService.spend(player, "coins", fuseCostInt) then
		fusionInFlight[uid] = nil
		return false, "Not enough coins"
	end

	-- Snapshot power then remove all (no partial delete if a pet disappears mid-flight).
	local totalPower = 0
	for _, petUid in petUids do
		local p = data.pets[petUid]
		if not p then
			CurrencyService.add(player, "coins", fuseCostInt, "admin")
			fusionInFlight[uid] = nil
			ValidationService.logViolation(player, "fuse_pet_vanished", "high", petUid)
			return false, "Pet not found"
		end
		totalPower += p.power
	end
	for _, petUid in petUids do
		data.pets[petUid] = nil
	end

	local chosenPetId = candidates[math.random(#candidates)]
	local chosenDef = PetConfig.Pets[chosenPetId]

	local newUid = HttpService:GenerateGUID(false)

	-- Fused pet gets a power bonus from the sacrificed pets
	local fusedPower = chosenDef.basePower + math.floor(totalPower * 0.1)

	data.pets[newUid] = {
		uid = newUid,
		id = chosenPetId,
		power = fusedPower,
		equipped = false,
	}

	local fusionPayload = {
		petId = chosenPetId,
		petName = chosenDef.name,
		modelName = chosenDef.modelName,
		rarity = chosenDef.rarity,
		power = fusedPower,
		previousPowerTotal = totalPower,
		sourceRarity = targetRarity,
		sacrificedNames = sacrificedNames,
	}

	if tokenKey then
		if not fusionIdempotencyCache[uid] then
			fusionIdempotencyCache[uid] = {}
		end
		fusionIdempotencyCache[uid][tokenKey] = {
			payload = fusionPayload,
			expiresAt = os.clock() + FUSE_IDEMPOTENCY_TTL_SEC,
		}
	end

	fusionInFlight[uid] = nil

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	Remotes.getEvent("FusionResult"):FireClient(player, fusionPayload)
	broadcastEquippedPets(player)

	return true, nil
end

function PetService.init()
	Remotes.getEvent("EquipPet").OnServerEvent:Connect(function(player, petUid)
		if not ValidationService.checkRemoteRate(player, "EquipPet") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(petUid) ~= "string" then
			return
		end
		if not RemoteCooldown.allow(player, "EquipPet", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		if petUid == "" then
			ValidationService.logAnomalyOncePerSession(player, "equip_empty_uid", "")
			return
		end
		if petUid ~= "__BEST__" and #petUid > MAX_PET_UID_LEN then
			ValidationService.logAnomalyOncePerSession(player, "equip_uid_len", "")
			return
		end
		if petUid == "__BEST__" then
			PetService.equipBest(player)
			return
		end
		local ok, err = PetService.equipPet(player, petUid)
		if not ok and err == "Pet not found" then
			ValidationService.logAnomalyOncePerSession(player, "equip_unknown_pet", petUid)
		end
	end)

	Remotes.getEvent("UnequipPet").OnServerEvent:Connect(function(player, petUid)
		if not ValidationService.checkRemoteRate(player, "UnequipPet") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(petUid) ~= "string" then
			return
		end
		if not RemoteCooldown.allow(player, "UnequipPet", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		if petUid == "" or #petUid > MAX_PET_UID_LEN then
			if petUid == "" then
				ValidationService.logAnomalyOncePerSession(player, "unequip_empty_uid", "")
			else
				ValidationService.logAnomalyOncePerSession(player, "unequip_uid_len", "")
			end
			return
		end
		local ok, err = PetService.unequipPet(player, petUid)
		if not ok and err == "Pet not found" then
			ValidationService.logAnomalyOncePerSession(player, "unequip_unknown_pet", petUid)
		end
	end)

	Remotes.getEvent("UnequipAllPets").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "UnequipAllPets") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "UnequipAllPets", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		PetService.unequipAll(player)
	end)

	Remotes.getEvent("DeletePet").OnServerEvent:Connect(function(player, petUid)
		if not ValidationService.checkRemoteRate(player, "DeletePet") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(petUid) ~= "string" then
			return
		end
		if petUid == "" or #petUid > MAX_PET_UID_LEN then
			return
		end
		if not RemoteCooldown.allow(player, "DeletePet", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = PetService.deletePet(player, petUid)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Failed to delete pet",
			})
		end
	end)

	Players.PlayerAdded:Connect(function(newPlayer)
		task.defer(function()
			task.wait(2)
			if not newPlayer.Parent then
				return
			end
			for _, existing in Players:GetPlayers() do
				if existing ~= newPlayer then
					local eData = DataManager.get(existing)
					if eData and type(eData.pets) == "table" then
						local equipped = {}
						for uid, pet in eData.pets do
							if type(pet) == "table" and pet.equipped then
								local def = PetConfig.Pets[pet.id]
								local rarity = if def then def.rarity else "common"
								table.insert(equipped, { uid = uid, id = pet.id, rarity = rarity })
							end
						end
						if #equipped > 0 then
							Remotes.getEvent("PetEquipSync"):FireClient(newPlayer, existing.UserId, equipped)
						end
					end
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		Remotes.getEvent("PetEquipSync"):FireAllClients(leaving.UserId, {})
	end)

	Remotes.getEvent("FusePets").OnServerEvent:Connect(function(player, petUids, requestToken)
		if not ValidationService.checkRemoteRate(player, "FusePets") then
			return
		end
		local canAct = ValidationService.canActWithReason(player)
		if not canAct then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = "Cannot fuse right now",
			})
			return
		end
		if type(petUids) ~= "table" then
			return
		end
		if requestToken ~= nil and type(requestToken) ~= "string" then
			return
		end
		if not RemoteCooldown.allow(player, "FusePets", 1) then
			return
		end
		local success, err = PetService.fusePets(player, petUids, requestToken :: string?)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Fuse failed",
			})
		end
	end)
end

return PetService
