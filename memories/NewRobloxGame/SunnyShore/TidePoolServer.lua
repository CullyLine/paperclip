--[[
	TidePoolServer.lua — ServerScriptService
	Handles creature discovery rolls when a player activates a tide pool.
	Server-authoritative RNG prevents exploitation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------------
-- REMOTE EVENTS
----------------------------------------------------------------------
local discoverEvent = Instance.new("RemoteEvent")
discoverEvent.Name = "TidePoolDiscover"
discoverEvent.Parent = ReplicatedStorage

local resultEvent = Instance.new("RemoteEvent")
resultEvent.Name = "TidePoolResult"
resultEvent.Parent = ReplicatedStorage

----------------------------------------------------------------------
-- CREATURE TABLE (Sunny Shore = Common + Uncommon only)
----------------------------------------------------------------------
local CREATURES = {
	{ name = "Hermit Crab",     rarity = "Common",   weight = 30, color = {220, 140, 80}  },
	{ name = "Sand Dollar",     rarity = "Common",   weight = 25, color = {230, 220, 190} },
	{ name = "Starfish",        rarity = "Common",   weight = 25, color = {230, 120, 90}  },
	{ name = "Sea Snail",       rarity = "Common",   weight = 20, color = {180, 160, 140} },
	{ name = "Clownfish",       rarity = "Uncommon", weight = 12, color = {255, 140, 40}  },
	{ name = "Blue Crab",       rarity = "Uncommon", weight = 10, color = {60, 140, 200}  },
	{ name = "Sea Urchin",      rarity = "Uncommon", weight = 8,  color = {80, 50, 120}   },
	{ name = "Baby Octopus",    rarity = "Uncommon", weight = 6,  color = {200, 80, 140}  },
	{ name = "Coral Shrimp",    rarity = "Uncommon", weight = 5,  color = {240, 100, 100} },
	{ name = "Seahorse",        rarity = "Uncommon", weight = 4,  color = {255, 200, 60}  },
}

local totalWeight = 0
for _, c in ipairs(CREATURES) do
	totalWeight = totalWeight + c.weight
end

----------------------------------------------------------------------
-- COOLDOWNS (per-player, per-pool)
----------------------------------------------------------------------
local COOLDOWN_SECONDS = 15
local cooldowns = {} -- [playerId][poolId] = tick()

local function isOnCooldown(playerId, poolId)
	if not cooldowns[playerId] then return false end
	if not cooldowns[playerId][poolId] then return false end
	return (tick() - cooldowns[playerId][poolId]) < COOLDOWN_SECONDS
end

local function setCooldown(playerId, poolId)
	if not cooldowns[playerId] then cooldowns[playerId] = {} end
	cooldowns[playerId][poolId] = tick()
end

----------------------------------------------------------------------
-- ROLL LOGIC
----------------------------------------------------------------------
local rng = Random.new()

local function rollCreature()
	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0
	for _, c in ipairs(CREATURES) do
		cumulative = cumulative + c.weight
		if roll <= cumulative then
			return c
		end
	end
	return CREATURES[1]
end

----------------------------------------------------------------------
-- HANDLE DISCOVERY REQUEST
----------------------------------------------------------------------
discoverEvent.OnServerEvent:Connect(function(player, poolId)
	if not poolId or type(poolId) ~= "string" then return end
	if isOnCooldown(player.UserId, poolId) then
		resultEvent:FireClient(player, {
			success = false,
			reason = "cooldown",
			remaining = COOLDOWN_SECONDS - (tick() - (cooldowns[player.UserId] and cooldowns[player.UserId][poolId] or 0)),
		})
		return
	end

	setCooldown(player.UserId, poolId)
	local creature = rollCreature()

	resultEvent:FireClient(player, {
		success = true,
		creature = {
			name = creature.name,
			rarity = creature.rarity,
			color = creature.color,
		},
		poolId = poolId,
	})
end)

----------------------------------------------------------------------
-- CLEANUP on player leave
----------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	cooldowns[player.UserId] = nil
end)
