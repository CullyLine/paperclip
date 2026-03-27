--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

export type BattlePassXpSource = "run_distance" | "quest"

local BattlePassService = {}

-- In-memory per-session XP from each authoritative source (not persisted; POLA-527).
local sessionBpXpBySource: { [number]: { [string]: number } } = {}

local function sessionCapForSource(source: BattlePassXpSource): number
	if source == "run_distance" then
		return Constants.BATTLE_PASS_MAX_SESSION_XP_RUN_DISTANCE
	end
	return Constants.BATTLE_PASS_MAX_SESSION_XP_QUEST
end

local function clearSessionXp(userId: number)
	sessionBpXpBySource[userId] = nil
end

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
		bp.claimRevision = 0
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
	if type(bp.claimRevision) ~= "number" then
		bp.claimRevision = 0
	end
end

--[[
	Authoritative season XP — only call from server services (Run, Quest).
	`source` must match a known origin; unknown sources are ignored (anti-forge).
	Session totals are clamped per source (see Constants).
]]
function BattlePassService.awardXp(player: Player, amount: number, source: BattlePassXpSource)
	if amount <= 0 then
		return
	end
	if source ~= "run_distance" and source ~= "quest" then
		return
	end
	BattlePassService.ensureSeason(player)
	local data = DataManager.get(player)
	if not data or not data.battlePass then
		return
	end
	local cap = sessionCapForSource(source)
	local uid = player.UserId
	local track = sessionBpXpBySource[uid]
	if not track then
		track = {}
		sessionBpXpBySource[uid] = track
	end
	local soFar = track[source] or 0
	local room = math.max(0, cap - soFar)
	local apply = math.min(amount, room)
	if apply <= 0 then
		return
	end
	track[source] = soFar + apply
	data.battlePass.xp += apply
	syncData(player)
end

-- Passive distance XP: 1 Season XP per 100 studs. Season 1 totals 15,000 XP across 50 tiers
-- (BattlePassConfig); raw distance would trivialize the pass (e.g. one Neon run ~17.5k studs).
function BattlePassService.addXP(player: Player, distance: number)
	if distance <= 0 then
		return
	end
	local add = math.max(0, math.floor(distance / 100))
	BattlePassService.awardXp(player, add, "run_distance")
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
	if t == "coins" then
		local amt = reward.amount or 0
		if amt <= 0 then
			return false, "Bad amount"
		end
		CurrencyService.add(player, "coins", amt, "battle_pass")
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

local function appendRewardItems(reward: any, out: { any })
	if not reward or reward.type == nil or reward.type == "none" then
		return
	end
	local t = reward.type
	if t == "bundle" then
		local items = (reward :: any).items
		if type(items) == "table" then
			for _, sub in items do
				appendRewardItems(sub, out)
			end
		end
		return
	end
	if t == "coins" then
		local amt = reward.amount or 0
		table.insert(out, { label = "Coins", amount = amt, kind = "coins" })
		return
	end
	if t == "pet_egg" then
		local eggId = reward.eggId
		local eggName = (type(eggId) == "string" and EggConfig.Eggs[eggId]) and EggConfig.Eggs[eggId].name or tostring(eggId)
		table.insert(out, { label = eggName .. " Egg", amount = math.max(1, reward.amount or 1), kind = "egg" })
		return
	end
	if t == "exclusive_car" or t == "car_skin" then
		local carId = reward.carId
		local carName = (type(carId) == "string" and CarConfig.Cars[carId]) and CarConfig.Cars[carId].name or tostring(carId)
		table.insert(out, { label = carName, kind = "car" })
		return
	end
	if t == "exclusive_pet" or t == "pet" then
		local petId = reward.petId
		local petName = (type(petId) == "string" and PetConfig.Pets[petId]) and PetConfig.Pets[petId].name or tostring(petId)
		table.insert(out, { label = petName .. " Pet", kind = "pet" })
		return
	end
	if t == "cosmetic" then
		local cid = reward.cosmeticId
		table.insert(out, {
			label = if type(cid) == "string" then `Cosmetic: {cid}` else "Cosmetic",
			kind = "cosmetic",
		})
		return
	end
	if t == "speed_boost" then
		table.insert(out, { label = "Speed Boost", amount = math.max(1, reward.amount or 1), kind = "consumable" })
		return
	end
	if t == "luck_boost" then
		table.insert(out, { label = "Luck Boost", amount = math.max(1, reward.amount or 1), kind = "consumable" })
		return
	end
	if t == "title" then
		local tid = reward.titleId
		table.insert(out, {
			label = if type(tid) == "string" then `Title: {tid}` else "Title",
			kind = "title",
		})
		return
	end
end

local function rewardToItems(reward: any): { any }
	local out: { any } = {}
	appendRewardItems(reward, out)
	return out
end

local function canClaimTier(playerXp: number, tier: number): boolean
	if tier < 1 or tier > BattlePassConfig.TIER_COUNT then
		return false
	end
	return playerXp >= BattlePassConfig.tierStartXp(tier)
end

function BattlePassService.claimTier(player: Player, tier: number, track: string, clientRevision: number?): (boolean, string?)
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
	local serverRev = if type(bp.claimRevision) == "number" then bp.claimRevision else 0

	if not canClaimTier(xp, tier) then
		return false, "Tier not unlocked"
	end

	local row = BattlePassConfig.Tiers[tier]
	if not row then
		return false, "No tier row"
	end

	if track == "free" then
		if bp.claimedFree[tier] then
			-- Idempotent: duplicate claim after success must not error or re-grant.
			return true, nil
		end
		-- POLA-529: reject stale/out-of-order claim packets (replay with old revision after another claim).
		if type(clientRevision) ~= "number" or clientRevision ~= serverRev then
			return false, "Stale claim revision"
		end
		bp.claimedFree[tier] = true
		local ok, err = grantReward(player, row.freeReward)
		if not ok then
			bp.claimedFree[tier] = false
			return false, err
		end
	else
		if not bp.premium then
			return false, "Premium not owned"
		end
		if bp.claimedPremium[tier] then
			return true, nil
		end
		if type(clientRevision) ~= "number" or clientRevision ~= serverRev then
			return false, "Stale claim revision"
		end
		bp.claimedPremium[tier] = true
		local ok, err = grantReward(player, row.premiumReward)
		if not ok then
			bp.claimedPremium[tier] = false
			return false, err
		end
	end

	bp.claimRevision = (bp.claimRevision or 0) + 1

	local EconomyLogService = require(script.Parent:WaitForChild("EconomyLogService"))
	EconomyLogService.logBattlePassClaim(player, tier, track)

	DataManager.saveImmediate(player)
	syncData(player)
	EventService.syncPlayerTitleAttribute(player)

	local rewardRow = if track == "free" then row.freeReward else row.premiumReward
	local items = rewardToItems(rewardRow)
	NotificationDispatchService.notify(player, {
		type = "reward_claim",
		title = "Battle Pass",
		subtitle = `Tier {tier} ({track})`,
		message = `Tier {tier} claimed`,
		items = items,
	})

	return true, nil
end

function BattlePassService.init()
	Players.PlayerRemoving:Connect(function(player)
		clearSessionXp(player.UserId)
	end)

	Remotes.getEvent("ClaimBattlePassTier").OnServerEvent:Connect(function(player, tier, track, clientRevision)
		local ack = Remotes.getEvent("BattlePassClaimResult")
		local function ackFail()
			ack:FireClient(player, false)
		end
		if not ValidationService.checkRemoteRate(player, "ClaimBattlePassTier") then
			ackFail()
			return
		end
		if not ValidationService.canAct(player) then
			ackFail()
			return
		end
		if not RemoteCooldown.allow(player, "ClaimBattlePassTier", Constants.REMOTE_COOLDOWN_DEFAULT) then
			ackFail()
			return
		end
		if type(tier) ~= "number" or tier ~= math.floor(tier) then
			ValidationService.logAnomalyOncePerSession(player, "bp_bad_tier_type", "")
			ackFail()
			return
		end
		if tier < 1 or tier > BattlePassConfig.TIER_COUNT then
			ValidationService.logAnomalyOncePerSession(player, "bp_tier_out_of_range", tostring(tier))
			ackFail()
			return
		end
		if type(track) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "bp_bad_track_type", "")
			ackFail()
			return
		end
		if track ~= "free" and track ~= "premium" then
			ValidationService.logAnomalyOncePerSession(player, "bp_bad_track_value", track)
			ackFail()
			return
		end
		if clientRevision ~= nil and type(clientRevision) ~= "number" then
			ValidationService.logAnomalyOncePerSession(player, "bp_bad_revision_type", "")
			ackFail()
			return
		end
		local ok, err = BattlePassService.claimTier(player, tier, track, clientRevision)
		if not ok then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Cannot claim",
			})
			ack:FireClient(player, false)
		else
			ack:FireClient(player, true)
		end
	end)
end

return BattlePassService
