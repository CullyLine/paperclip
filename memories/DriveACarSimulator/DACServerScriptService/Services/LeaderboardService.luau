--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local LeaderboardService = {}

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

function LeaderboardService.updatePlayer(player: Player)
	local data = DataManager.get(player)
	if not data then return end

	for stat, store in BOARDS do
		local value = data.stats[stat]
		if value and value > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
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
		if not ValidationService.checkRemoteRate(player, "GetLeaderboard") then
			return {}
		end
		if not RemoteCooldown.allow(player, "GetLeaderboard", 1) then
			return {}
		end
		if type(stat) ~= "string" then return {} end
		return LeaderboardService.getTop(stat, 25)
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
