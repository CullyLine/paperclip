--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local BattlePassService = {}

local function syncData(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
end

function BattlePassService.ensureSeason(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	if not data.battlePass then
		data.battlePass = {
			seasonId = "",
			xp = 0,
			premium = false,
			claimedFree = {},
			claimedPremium = {},
		}
	end
	local bp = data.battlePass
	local sid = BattlePassConfig.Season.id
	if bp.seasonId ~= sid then
		bp.seasonId = sid
		bp.xp = 0
		bp.premium = false
		bp.claimedFree = {}
		bp.claimedPremium = {}
	end
	if not bp.claimedFree then
		bp.claimedFree = {}
	end
	if not bp.claimedPremium then
		bp.claimedPremium = {}
	end
	if not data.titles then
		data.titles = {}
	end
	if not data.cosmetics then
		data.cosmetics = {}
	end
	if not data.consumables then
		data.consumables = { speedBoosts = 0, luckBoosts = 0 }
	end
end

-- Season XP from any source (quests, distance, etc.)
function BattlePassService.awardXp(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	BattlePassService.ensureSeason(player)
	local data = DataManager.get(player)
	if not data or not data.battlePass then
		return
	end
	data.battlePass.xp += amount
	syncData(player)
end

-- Passive distance XP: 1 Season XP per 100 studs. Season 1 totals 15,000 XP across 50 tiers
-- (BattlePassConfig); raw distance would trivialize the pass (e.g. one Neon run ~17.5k studs).
function BattlePassService.addXP(player: Player, distance: number)
	if distance <= 0 then
		return
	end
	local add = math.max(0, math.floor(distance / 100))
	BattlePassService.awardXp(player, add)
end

local function grantReward(player: Player, reward: any): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end

	if not reward or reward.type == nil or reward.type == "none" then
		return true, nil
	end

	local t = reward.type
	if t == "bundle" then
		local items = reward.items
		if type(items) ~= "table" then
			return false, "Bad bundle"
		end
		for _, sub in items do
			local ok, err = grantReward(player, sub)
			if not ok then
				return ok, err
			end
		end
		return true, nil
	end
	if t == "coins" or t == "gems" or t == "crystals" or t == "skulls" then
		local amt = reward.amount or 0
		if amt <= 0 then
			return false, "Bad amount"
		end
		CurrencyService.add(player, t, amt, "battle_pass")
	elseif t == "pet_egg" then
		local eggId = reward.eggId
		if type(eggId) ~= "string" then
			return false, "Bad egg"
		end
		data.eggs[eggId] = (data.eggs[eggId] or 0) + math.max(1, reward.amount or 1)
	elseif t == "exclusive_car" then
		local carId = reward.carId
		if type(carId) ~= "string" or not CarConfig.Cars[carId] then
			return false, "Bad car"
		end
		if not data.cars[carId] then
			data.cars[carId] = {
				id = carId,
				gasLevel = 0,
				powerLevel = 0,
				speedLevel = 0,
			}
		end
	elseif t == "exclusive_pet" or t == "pet" then
		local petId = reward.petId
		local petDef = if type(petId) == "string" then PetConfig.Pets[petId] else nil
		if not petDef then
			return false, "Bad pet"
		end
		local petUid = Utils.generateUID()
		data.pets[petUid] = {
			uid = petUid,
			id = petId,
			power = petDef.basePower,
			equipped = false,
		}
		data.discoveredPets[petId] = true
	elseif t == "car_skin" then
		local carId = reward.carId
		if type(carId) ~= "string" or not CarConfig.Cars[carId] then
			return false, "Bad car skin"
		end
		if not data.cars[carId] then
			data.cars[carId] = {
				id = carId,
				gasLevel = 0,
				powerLevel = 0,
				speedLevel = 0,
			}
		end
	elseif t == "cosmetic" then
		local cosmeticId = reward.cosmeticId
		if type(cosmeticId) ~= "string" then
			return false, "Bad cosmetic"
		end
		data.cosmetics[cosmeticId] = true
	elseif t == "speed_boost" then
		local n = math.max(1, reward.amount or 1)
		data.consumables.speedBoosts = (data.consumables.speedBoosts or 0) + n
	elseif t == "luck_boost" then
		local n = math.max(1, reward.amount or 1)
		data.consumables.luckBoosts = (data.consumables.luckBoosts or 0) + n
	elseif t == "title" then
		local titleId = reward.titleId
		if type(titleId) ~= "string" then
			return false, "Bad title"
		end
		data.titles[titleId] = true
	else
		return false, "Unknown reward"
	end

	return true, nil
end

local function canClaimTier(playerXp: number, tier: number): boolean
	if tier < 1 or tier > BattlePassConfig.TIER_COUNT then
		return false
	end
	return playerXp >= BattlePassConfig.tierStartXp(tier)
end

function BattlePassService.claimTier(player: Player, tier: number, track: string): (boolean, string?)
	if type(tier) ~= "number" or tier ~= math.floor(tier) then
		return false, "Bad tier"
	end
	if track ~= "free" and track ~= "premium" then
		return false, "Bad track"
	end
	BattlePassService.ensureSeason(player)
	local data = DataManager.get(player)
	if not data or not data.battlePass then
		return false, "No data"
	end
	local bp = data.battlePass
	local xp = bp.xp

	if not canClaimTier(xp, tier) then
		return false, "Tier not unlocked"
	end

	local row = BattlePassConfig.Tiers[tier]
	if not row then
		return false, "No tier row"
	end

	if track == "free" then
		if bp.claimedFree[tier] then
			return false, "Already claimed"
		end
		local ok, err = grantReward(player, row.freeReward)
		if not ok then
			return false, err
		end
		bp.claimedFree[tier] = true
	else
		if not bp.premium then
			return false, "Premium not owned"
		end
		if bp.claimedPremium[tier] then
			return false, "Already claimed"
		end
		local ok, err = grantReward(player, row.premiumReward)
		if not ok then
			return false, err
		end
		bp.claimedPremium[tier] = true
	end

	DataManager.save(player)
	syncData(player)
	EventService.syncPlayerTitleAttribute(player)
	return true, nil
end

function BattlePassService.init()
	Remotes.getEvent("ClaimBattlePassTier").OnServerEvent:Connect(function(player, tier, track)
		if not ValidationService.checkRemoteRate(player, "ClaimBattlePassTier") then
			return
		end
		if not RemoteCooldown.allow(player, "ClaimBattlePassTier", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		if type(tier) ~= "number" then
			return
		end
		if type(track) ~= "string" then
			return
		end
		local ok, err = BattlePassService.claimTier(player, tier, track)
		if not ok then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Cannot claim",
			})
		end
	end)
end

return BattlePassService
