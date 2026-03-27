--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local LeaderboardService = {}

-- Max pages to scan when resolving rank (100 entries per page).
local MAX_RANK_PAGES = 40

local function titleForUserId(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	if p then
		local t = p:GetAttribute("DAC_PlayerTitle")
		if type(t) == "string" and t ~= "" then
			return t
		end
	end
	return ""
end

local BOARDS = {
	totalDistance = DataStoreService:GetOrderedDataStore("DAC_Leaderboard_Distance"),
	totalRebirths = DataStoreService:GetOrderedDataStore("DAC_Leaderboard_Rebirths"),
}

local UPDATE_INTERVAL = 60

-- Shared cache: bounds OrderedDataStore reads across all players (TTL in Constants).
-- Cleared when a stat is written so runs propagate to the in-world board quickly.
type LeaderboardCacheEntry = { rows: { any }, expiresAt: number, updatedAtUnix: number }
local leaderboardTopCache: { [string]: LeaderboardCacheEntry } = {}

local function computeRankForUser(store, userId: number): number?
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, 100)
	end)
	if not success or not pages then
		return nil
	end

	local rank = 0
	local pageCount = 0
	while pageCount < MAX_RANK_PAGES do
		pageCount += 1
		local page = pages:GetCurrentPage()
		for _, entry in page do
			rank += 1
			if tonumber(entry.key) == userId then
				return rank
			end
		end
		if pages.IsFinished then
			break
		end
		local ok = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not ok then
			break
		end
	end
	return nil
end

local function tierForRankChange(oldRank: number, newRank: number): string
	if newRank == 1 and oldRank ~= 1 then
		return "champion"
	end
	if oldRank > 10 and newRank <= 10 and newRank > 1 then
		return "top10"
	end
	return "rankup"
end

local function evaluateRankAfterUpdate(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	if type(data.leaderboardRankSnapshot) ~= "table" then
		data.leaderboardRankSnapshot = {
			totalDistance = nil,
			totalRebirths = nil,
		}
	end
	local snap = data.leaderboardRankSnapshot :: any

	for stat, store in BOARDS do
		local value = data.stats and data.stats[stat]
		if type(value) ~= "number" or value <= 0 then
			continue
		end

		local newRank = computeRankForUser(store, player.UserId)
		if newRank == nil then
			continue
		end

		local prevAny = snap[stat]
		local prevRank = if type(prevAny) == "number" then prevAny else nil

		if prevRank == nil then
			snap[stat] = newRank
			AchievementService.onLeaderboardRank(player, newRank, nil)
			MilestoneCeremonyService.tryFirstTime(player, data, "FirstLeaderboardEntry", {
				n = tostring(newRank),
			})
			Remotes.getEvent("RankUpNotification"):FireClient(player, {
				stat = stat,
				newRank = newRank,
				oldRank = nil,
				isFirstPlacement = true,
				tier = "first_placement",
			})
			continue
		end

		if newRank < prevRank then
			local tier = tierForRankChange(prevRank, newRank)
			AchievementService.onLeaderboardRank(player, newRank, prevRank)
			Remotes.getEvent("RankUpNotification"):FireClient(player, {
				stat = stat,
				oldRank = prevRank,
				newRank = newRank,
				tier = tier,
			})
		end

		snap[stat] = newRank
	end
end

function LeaderboardService.updatePlayer(player: Player)
	if not player.Parent then
		return
	end
	local data = DataManager.get(player)
	if not data then return end

	for stat, store in BOARDS do
		local value = data.stats[stat]
		if value and value > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
			leaderboardTopCache[stat] = nil
		end
	end

	evaluateRankAfterUpdate(player)
end

function LeaderboardService.getTop(stat: string, count: number?): { { userId: number, value: number, name: string } }
	local store = BOARDS[stat]
	if not store then return {} end

	local topCount = count or 10
	local results = {}

	local success, pages = pcall(function()
		return store:GetSortedAsync(false, topCount)
	end)

	if not success or not pages then return {} end

	local page = pages:GetCurrentPage()
	for rank, entry in page do
		local userId = tonumber(entry.key) or 0
		local name = "[Unknown]"
		pcall(function()
			name = Players:GetNameFromUserIdAsync(userId)
		end)
		table.insert(results, {
			userId = userId,
			value = entry.value,
			name = name,
			title = titleForUserId(userId),
		})
	end

	return results
end

function LeaderboardService.init()
	Remotes.getFunction("GetLeaderboard").OnServerInvoke = function(player, stat)
		if type(stat) ~= "string" then
			return { ok = false, reason = "bad_args" }
		end
		local store = BOARDS[stat]
		if not store then
			return { ok = true, rows = {}, updatedAt = os.time(), fromCache = false, stale = false }
		end

		if not ValidationService.checkRemoteRate(player, "GetLeaderboard") then
			local c = leaderboardTopCache[stat]
			if c and c.rows then
				return {
					ok = true,
					rows = c.rows,
					updatedAt = c.updatedAtUnix,
					fromCache = true,
					stale = true,
				}
			end
			return { ok = false, reason = "rate_limit" }
		end

		local nowClock = os.clock()
		local ttl = Constants.LEADERBOARD_DATASTORE_CACHE_TTL_SEC
		local cached = leaderboardTopCache[stat]
		if cached and nowClock < cached.expiresAt then
			return {
				ok = true,
				rows = cached.rows,
				updatedAt = cached.updatedAtUnix,
				fromCache = true,
				stale = false,
			}
		end

		if not RemoteCooldown.allow(player, "GetLeaderboard", Constants.LEADERBOARD_REMOTE_COOLDOWN_ON_FETCH_SEC) then
			if cached and cached.rows then
				return {
					ok = true,
					rows = cached.rows,
					updatedAt = cached.updatedAtUnix,
					fromCache = true,
					stale = true,
				}
			end
			return { ok = false, reason = "rate_limit" }
		end

		local rows = LeaderboardService.getTop(stat, 25)
		local unix = os.time()
		leaderboardTopCache[stat] = {
			rows = rows,
			expiresAt = nowClock + ttl,
			updatedAtUnix = unix,
		}
		return {
			ok = true,
			rows = rows,
			updatedAt = unix,
			fromCache = false,
			stale = false,
		}
	end

	-- Periodic leaderboard updates
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					LeaderboardService.updatePlayer(player)
				end)
			end
		end
	end)
end

return LeaderboardService
