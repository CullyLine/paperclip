--!strict
--[[
	Bonus run coins when the player has Roblox friends in the same server.
	Uses Player:GetFriendsOnline() cross-referenced with Players in this server.

	Anti-exploit:
	  - In-server friend count cannot exceed the number of other players in the
	    lobby (rejects impossible overlaps / malformed lists).
	  - Multiplier is clamped to FriendBonusConfig.maxFriendBonusMultiplier.
	  - Run payouts call authoritative recompute (no stale-cache coins).
	  - HUD/cache refresh: join/leave + throttled Heartbeat (serverRefreshIntervalSec).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local FriendBonusConfig = require(DAC:WaitForChild("Config"):WaitForChild("FriendBonusConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))

local FriendBonusService = {}

type FriendState = {
	friendCount: number,
	multiplier: number,
	percentLabel: string,
	sampleFriendName: string?,
}

local cache: { [number]: FriendState } = {}
local prevFriendCount: { [number]: number } = {}
local lastFeedAt: { [number]: number } = {}
local pendingRefresh: boolean = false

local function clampMultiplier(mult: number): number
	local cap = FriendBonusConfig.maxFriendBonusMultiplier
	if cap ~= cap or cap < 1 then
		cap = 1.2
	end
	if mult ~= mult or mult < 1 then
		return 1
	end
	return math.min(mult, cap)
end

local function multiplierForCount(count: number): (number, string)
	local t1 = FriendBonusConfig.tierOneMultiplier
	local t2 = FriendBonusConfig.tierTwoMultiplier
	if t1 ~= t1 or t1 < 1 then
		t1 = 1
	end
	if t2 ~= t2 or t2 < t1 then
		t2 = t1
	end
	if count >= FriendBonusConfig.tierTwoMinFriends then
		return clampMultiplier(t2), "+20%"
	elseif count >= FriendBonusConfig.tierOneMinFriends then
		return clampMultiplier(t1), "+10%"
	end
	return 1, "+0%"
end

--- Other players in this server (upper bound for in-server friend count).
local function maxInServerFriends(player: Player): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p ~= player then
			n += 1
		end
	end
	return n
end

--- Raw count cannot exceed how many non-self players exist (anti-exploit).
local function sanitizeFriendCount(player: Player, raw: number): number
	local maxOther = maxInServerFriends(player)
	if raw ~= raw or raw < 0 then
		return 0
	end
	local c = math.floor(raw + 0.5)
	return math.clamp(c, 0, maxOther)
end

local function firstFriendInServer(player: Player, friendIdSet: { [number]: boolean }): Player?
	for _, p in Players:GetPlayers() do
		if p ~= player and friendIdSet[p.UserId] then
			return p
		end
	end
	return nil
end

--- Normalize GetFriendsOnline entries (number, OnlineFriendInfo.Id, or legacy string ids).
local function friendUserIdFromOnlineEntry(entry: any): number?
	if type(entry) == "number" then
		return if entry > 0 then entry else nil
	end
	if type(entry) == "string" then
		local n = tonumber(entry)
		return if n and n > 0 then n else nil
	end
	if type(entry) == "table" then
		local raw = (entry :: any).Id
		if raw == nil then
			raw = (entry :: any).UserId
		end
		if type(raw) == "number" and raw > 0 then
			return raw
		end
		if type(raw) == "string" then
			local n = tonumber(raw)
			if n and n > 0 then
				return n
			end
		end
	end
	return nil
end

local function computeForPlayer(player: Player): FriendState
	local ok, onlineFriends = pcall(function()
		return (player :: any):GetFriendsOnline(200)
	end)
	local friendList: { any } = if ok and type(onlineFriends) == "table" then onlineFriends else {}
	local friendIdSet: { [number]: boolean } = {}
	for _, entry in friendList do
		local n = friendUserIdFromOnlineEntry(entry)
		if n then
			friendIdSet[n] = true
		end
	end

	local count = 0
	for _, p in Players:GetPlayers() do
		if p ~= player and friendIdSet[p.UserId] then
			count += 1
		end
	end
	count = sanitizeFriendCount(player, count)

	local mult, pct = multiplierForCount(count)
	mult = clampMultiplier(mult)
	local buddy = if count >= 1 then firstFriendInServer(player, friendIdSet) else nil
	return {
		friendCount = count,
		multiplier = mult,
		percentLabel = pct,
		sampleFriendName = if buddy then buddy.DisplayName else nil,
	}
end

local function maybeFireSocialFeed(player: Player, state: FriendState, prevCount: number)
	if state.friendCount < FriendBonusConfig.tierOneMinFriends then
		return
	end
	if prevCount >= FriendBonusConfig.tierOneMinFriends then
		return
	end

	local now = os.clock()
	local last = lastFeedAt[player.UserId] or 0
	if now - last < FriendBonusConfig.socialFeedCooldownSec then
		return
	end

	local buddyName = state.sampleFriendName
	if type(buddyName) ~= "string" or buddyName == "" then
		return
	end

	local tpl = SocialFeedConfig.pickLine("FriendPlayFeed")
	if tpl == "" then
		tpl = "{PLAYER} is playing with {FRIEND}! {PERCENT} coins!"
	end
	local bonusPct = if state.friendCount >= FriendBonusConfig.tierTwoMinFriends then 20 else 10
	local line = tpl
		:gsub("{PLAYER}", player.DisplayName)
		:gsub("{FRIEND}", buddyName)
		:gsub("{PERCENT}", "+" .. tostring(bonusPct) .. "%")

	lastFeedAt[player.UserId] = now

	Remotes.getEvent("ServerDropFeed"):FireAllClients({
		kind = "friend_play",
		line = line,
		userId = player.UserId,
	})
end

local function pushToClient(player: Player, state: FriendState)
	Remotes.getEvent("FriendBonusUpdate"):FireClient(player, {
		active = state.friendCount >= FriendBonusConfig.tierOneMinFriends,
		friendCount = state.friendCount,
		multiplier = state.multiplier,
		percentLabel = state.percentLabel,
	})
end

function FriendBonusService.getRunCoinMultiplier(player: Player): number
	-- Authoritative path for economy: always recompute; never trust HUD cache for coins.
	if not player.Parent then
		return 1
	end
	local state = computeForPlayer(player)
	local prev = cache[player.UserId]
	cache[player.UserId] = state
	prevFriendCount[player.UserId] = state.friendCount
	if not prev or prev.multiplier ~= state.multiplier or prev.friendCount ~= state.friendCount then
		pushToClient(player, state)
	end
	return state.multiplier
end

function FriendBonusService.refreshPlayer(player: Player)
	if not player.Parent then
		return
	end
	local uid = player.UserId
	local before = prevFriendCount[uid] or 0
	local state = computeForPlayer(player)
	cache[uid] = state
	prevFriendCount[uid] = state.friendCount
	pushToClient(player, state)
	maybeFireSocialFeed(player, state, before)
end

local function refreshAllPlayers()
	for _, player in Players:GetPlayers() do
		task.spawn(FriendBonusService.refreshPlayer, player)
	end
end

local function scheduleRefresh()
	if pendingRefresh then
		return
	end
	pendingRefresh = true
	task.defer(function()
		pendingRefresh = false
		refreshAllPlayers()
	end)
end

function FriendBonusService.onPlayerReady(player: Player)
	FriendBonusService.refreshPlayer(player)
	scheduleRefresh()
end

function FriendBonusService.init()
	Players.PlayerAdded:Connect(function()
		scheduleRefresh()
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player.UserId] = nil
		prevFriendCount[player.UserId] = nil
		lastFeedAt[player.UserId] = nil
		scheduleRefresh()
	end)

	local acc = 0.0
	local interval = FriendBonusConfig.serverRefreshIntervalSec
	if interval ~= interval or interval < 1 then
		interval = 4
	end
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= interval then
			acc = 0
			refreshAllPlayers()
		end
	end)
end

return FriendBonusService
