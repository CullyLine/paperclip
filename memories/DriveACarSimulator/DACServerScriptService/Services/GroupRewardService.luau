--!strict
--[[
	Roblox group membership: join bonus, +5% run coins, nametag attribute, join prompt.

	Membership uses Player:IsInGroup on the server (authoritative). Results are cached
	(GroupRewardConfig.membershipCacheTtlSeconds, default 120s) to avoid hammering the API
	on every run end. Grant path always re-verifies with a fresh IsInGroup before paying out.
	GroupService:GetGroupInfoAsync validates groupId once at init when enabled.
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local GroupRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("GroupRewardConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local Utils = require(DAC:WaitForChild("Utils"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local GroupRewardService = {}

type MembershipCacheEntry = {
	inGroup: boolean,
	expiresAt: number,
}

local membershipCache: { [number]: MembershipCacheEntry } = {}

local function cacheTtl(): number
	local t = GroupRewardConfig.membershipCacheTtlSeconds
	if type(t) ~= "number" or t < 10 then
		return 120
	end
	return math.min(600, math.max(10, t))
end

local function enabled(): boolean
	return type(GroupRewardConfig.groupId) == "number" and GroupRewardConfig.groupId > 0
end

local function pcallIsInGroup(player: Player, gid: number): (boolean, boolean?)
	local ok, res = pcall(function()
		return player:IsInGroup(gid)
	end)
	if not ok then
		return false, nil
	end
	return true, res == true
end

local function applyMembership(player: Player, inGroup: boolean)
	player:SetAttribute("DAC_GroupMember", if inGroup then true else false)
	local uid = player.UserId
	membershipCache[uid] = {
		inGroup = inGroup,
		expiresAt = os.clock() + cacheTtl(),
	}
end

--[[
	Updates DAC_GroupMember from cache or a live IsInGroup (when cache expired).
	On API failure, keeps previous attribute when it was true (fail-open for coin mult); otherwise false.

	Returns: (inGroup, usedLiveIsInGroupCall) — used to avoid a duplicate IsInGroup in tryGrant when cache just missed.
]]
function GroupRewardService.syncGroupMembership(player: Player): (boolean, boolean)
	if not enabled() then
		player:SetAttribute("DAC_GroupMember", nil)
		membershipCache[player.UserId] = nil
		return false, false
	end
	local gid = GroupRewardConfig.groupId :: number
	local uid = player.UserId
	local now = os.clock()
	local entry = membershipCache[uid]
	if entry and now < entry.expiresAt then
		player:SetAttribute("DAC_GroupMember", if entry.inGroup then true else false)
		return entry.inGroup, false
	end

	local ok, inGroup = pcallIsInGroup(player, gid)
	if not ok then
		warn("[GroupRewardService] IsInGroup failed during sync (userId=" .. tostring(uid) .. ")")
		local prev = player:GetAttribute("DAC_GroupMember")
		if prev == true then
			return true, false
		end
		player:SetAttribute("DAC_GroupMember", false)
		return false, false
	end

	applyMembership(player, inGroup == true)
	return inGroup == true, true
end

--[[
	Second IsInGroup when sync used cache hit — grant must not rely on stale cache alone.
]]
local function verifyMembershipForGrant(player: Player): boolean
	local gid = GroupRewardConfig.groupId :: number
	local ok, inGroup = pcallIsInGroup(player, gid)
	if not ok then
		warn("[GroupRewardService] IsInGroup failed during grant verify (userId=" .. tostring(player.UserId) .. ")")
		return false
	end
	applyMembership(player, inGroup == true)
	return inGroup == true
end

local function hasGroupMemberPet(data: any): boolean
	if type(data.pets) ~= "table" then
		return false
	end
	for _, pet in data.pets :: { [any]: any } do
		if type(pet) == "table" and pet.id == "group_member" then
			return true
		end
	end
	return false
end

function GroupRewardService.getRunCoinMultiplier(player: Player): number
	if not enabled() then
		return 1
	end
	if player:GetAttribute("DAC_GroupMember") == true then
		return 1 + GroupRewardConfig.coinBonusMultiplier
	end
	return 1
end

function GroupRewardService.tryGrantJoinRewards(player: Player)
	if not enabled() then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end
	if data.groupRewardClaimed == true then
		return
	end

	-- Duplicate pet without flag (data anomaly): seal profile, do not pay out again.
	if hasGroupMemberPet(data) then
		warn("[GroupRewardService] group_member pet present but groupRewardClaimed false; sealing (userId=" .. tostring(player.UserId) .. ")")
		data.groupRewardClaimed = true
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
		return
	end

	local member, syncLive = GroupRewardService.syncGroupMembership(player)
	if not member then
		return
	end
	-- Cache hit: require a live check before currency/pet. Cache miss: sync already called IsInGroup this frame.
	if not syncLive then
		if not verifyMembershipForGrant(player) then
			return
		end
	end

	local petDef = PetConfig.Pets.group_member
	if not petDef then
		warn("[GroupRewardService] PetConfig.group_member missing")
	end

	if petDef then
		local petUid = Utils.generateUID()
		data.pets[petUid] = {
			uid = petUid,
			id = "group_member",
			power = petDef.basePower,
			equipped = false,
		}
		data.discoveredPets["group_member"] = true
	end

	CurrencyService.add(player, "coins", GroupRewardConfig.joinRewardCoins, "group_join")

	-- Idempotent: only after payouts
	data.groupRewardClaimed = true

	NotificationDispatchService.notify(player, {
		type = "success",
		message = "Group welcome bundle claimed! Coins added — check inventory for the Group Pup. +5% run bonus stays on while you're in the group.",
	})

	Remotes.getEvent("GroupRewardClaimed"):FireClient(player, {
		coins = GroupRewardConfig.joinRewardCoins,
		petId = "group_member",
	})

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
end

function GroupRewardService.onPlayerReady(player: Player)
	if not enabled() then
		return
	end
	GroupRewardService.syncGroupMembership(player)
	GroupRewardService.tryGrantJoinRewards(player)
end

function GroupRewardService.init()
	if enabled() then
		local gid = GroupRewardConfig.groupId :: number
		task.defer(function()
			local ok, err = pcall(function()
				return GroupService:GetGroupInfoAsync(gid)
			end)
			if not ok then
				warn("[GroupRewardService] GetGroupInfoAsync failed groupId=" .. tostring(gid) .. " err=" .. tostring(err))
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		membershipCache[player.UserId] = nil
	end)

	Remotes.getEvent("DismissGroupJoinPrompt").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "DismissGroupJoinPrompt") then
			return
		end
		local data = DataManager.get(player)
		if not data then
			return
		end
		data.groupJoinPromptDismissed = true
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
	end)
end

return GroupRewardService
