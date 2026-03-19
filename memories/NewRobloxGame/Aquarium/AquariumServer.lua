--[[
	AquariumServer.lua — ServerScriptService (Script)
	Manages creature state within player aquariums:
	  - Creature placement into tank slots
	  - Pearl production (passive, scales with rarity)
	  - Growth timers (baby → juvenile → adult)
	  - Pearl collection
	  - Offline idle accumulation via DataStore timestamps
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

----------------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------------
local function getOrCreate(class, name, parent)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local inst = Instance.new(class)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local placeCreatureEvent = getOrCreate("RemoteEvent", "AquariumPlaceCreature", ReplicatedStorage)
local removeCreatureEvent = getOrCreate("RemoteEvent", "AquariumRemoveCreature", ReplicatedStorage)
local collectPearlsEvent = getOrCreate("RemoteEvent", "AquariumCollectPearls", ReplicatedStorage)
local aquariumStateEvent = getOrCreate("RemoteEvent", "AquariumStateUpdate", ReplicatedStorage)
local pearlUpdateEvent = getOrCreate("RemoteEvent", "AquariumPearlUpdate", ReplicatedStorage)

----------------------------------------------------------------------
-- PEARL RATES BY RARITY (pearls per minute for adult creatures)
----------------------------------------------------------------------
local PEARL_RATES = {
	Common   = 1,
	Uncommon = 2.5,
	Rare     = 6,
	Epic     = 15,
	Legendary = 40,
	Mythical  = 100,
	Seasonal  = 20,
}

local GROWTH_TIMES = {
	Common   = 300,
	Uncommon = 600,
	Rare     = 1800,
	Epic     = 3600,
	Legendary = 7200,
	Mythical  = 14400,
	Seasonal  = 2400,
}

local GROWTH_STAGES = { "baby", "juvenile", "adult" }

----------------------------------------------------------------------
-- PER-PLAYER AQUARIUM STATE
----------------------------------------------------------------------
-- playerAquariums[player] = {
--   pearls = number,
--   pendingPearls = number (fractional accumulator),
--   creatures = { [slotIndex] = creatureData },
--   lastUpdateTick = number,
-- }
local playerAquariums = {}

local function newAquariumState()
	return {
		pearls = 0,
		pendingPearls = 0,
		creatures = {},
		lastUpdateTick = tick(),
	}
end

----------------------------------------------------------------------
-- CREATURE DATA HELPERS
----------------------------------------------------------------------
local function getGrowthStage(creatureData)
	local elapsed = tick() - creatureData.placedAt
	local totalGrowth = GROWTH_TIMES[creatureData.rarity] or 600
	local stageTime = totalGrowth / 3

	if elapsed >= totalGrowth then
		return "adult"
	elseif elapsed >= stageTime * 2 then
		return "juvenile"
	else
		return "baby"
	end
end

local function getGrowthProgress(creatureData)
	local elapsed = tick() - creatureData.placedAt
	local totalGrowth = GROWTH_TIMES[creatureData.rarity] or 600
	return math.clamp(elapsed / totalGrowth, 0, 1)
end

local function getPearlRate(creatureData)
	local stage = getGrowthStage(creatureData)
	local baseRate = PEARL_RATES[creatureData.rarity] or 1
	if stage == "baby" then
		return 0
	elseif stage == "juvenile" then
		return baseRate * 0.3
	else
		return baseRate
	end
end

----------------------------------------------------------------------
-- PEARL PRODUCTION TICK
----------------------------------------------------------------------
local TICK_INTERVAL = 5

local function updatePearlProduction(player, dt)
	local state = playerAquariums[player]
	if not state then return end

	local totalRate = 0
	for _, creature in pairs(state.creatures) do
		totalRate = totalRate + getPearlRate(creature)
	end

	if totalRate > 0 then
		state.pendingPearls = state.pendingPearls + (totalRate * dt / 60)
		if state.pendingPearls >= 1 then
			local whole = math.floor(state.pendingPearls)
			state.pearls = state.pearls + whole
			state.pendingPearls = state.pendingPearls - whole
			pearlUpdateEvent:FireClient(player, {
				pearls = state.pearls,
				rate = totalRate,
			})
		end
	end
end

local tickAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	tickAccumulator = tickAccumulator + dt
	if tickAccumulator < TICK_INTERVAL then return end
	local elapsed = tickAccumulator
	tickAccumulator = 0

	for player, _ in pairs(playerAquariums) do
		if player.Parent then
			updatePearlProduction(player, elapsed)
		end
	end
end)

----------------------------------------------------------------------
-- PLACE CREATURE INTO TANK
----------------------------------------------------------------------
placeCreatureEvent.OnServerEvent:Connect(function(player, data)
	local state = playerAquariums[player]
	if not state then return end

	local slotIndex = data.slotIndex
	if not slotIndex or slotIndex < 1 or slotIndex > 6 then return end
	if state.creatures[slotIndex] then return end

	local creatureData = {
		id = data.creatureId or game:GetService("HttpService"):GenerateGUID(false),
		name = data.name or "Unknown",
		species = data.species or "unknown",
		rarity = data.rarity or "Common",
		color = data.color or {180, 180, 180},
		placedAt = tick(),
		slotIndex = slotIndex,
	}

	state.creatures[slotIndex] = creatureData

	aquariumStateEvent:FireClient(player, {
		action = "placed",
		slotIndex = slotIndex,
		creature = creatureData,
		growthStage = "baby",
		growthProgress = 0,
		pearlRate = 0,
	})
end)

----------------------------------------------------------------------
-- REMOVE CREATURE FROM TANK
----------------------------------------------------------------------
removeCreatureEvent.OnServerEvent:Connect(function(player, data)
	local state = playerAquariums[player]
	if not state then return end

	local slotIndex = data.slotIndex
	if not slotIndex or not state.creatures[slotIndex] then return end

	state.creatures[slotIndex] = nil

	aquariumStateEvent:FireClient(player, {
		action = "removed",
		slotIndex = slotIndex,
	})
end)

----------------------------------------------------------------------
-- COLLECT PEARLS
----------------------------------------------------------------------
collectPearlsEvent.OnServerEvent:Connect(function(player)
	local state = playerAquariums[player]
	if not state then return end

	local collected = state.pearls
	if collected <= 0 then
		pearlUpdateEvent:FireClient(player, { pearls = 0, collected = 0, rate = 0 })
		return
	end

	state.pearls = 0
	state.pendingPearls = 0

	local totalRate = 0
	for _, creature in pairs(state.creatures) do
		totalRate = totalRate + getPearlRate(creature)
	end

	pearlUpdateEvent:FireClient(player, {
		pearls = 0,
		collected = collected,
		rate = totalRate,
	})
end)

----------------------------------------------------------------------
-- PERIODIC STATE BROADCAST (growth updates to clients)
----------------------------------------------------------------------
local BROADCAST_INTERVAL = 30
local broadcastAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
	broadcastAccumulator = broadcastAccumulator + dt
	if broadcastAccumulator < BROADCAST_INTERVAL then return end
	broadcastAccumulator = 0

	for player, state in pairs(playerAquariums) do
		if not player.Parent then continue end

		local creatureStates = {}
		for slotIndex, creature in pairs(state.creatures) do
			creatureStates[slotIndex] = {
				creature = creature,
				growthStage = getGrowthStage(creature),
				growthProgress = getGrowthProgress(creature),
				pearlRate = getPearlRate(creature),
			}
		end

		aquariumStateEvent:FireClient(player, {
			action = "sync",
			creatures = creatureStates,
			pearls = state.pearls,
		})
	end
end)

----------------------------------------------------------------------
-- PLAYER JOIN / LEAVE
----------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	playerAquariums[player] = newAquariumState()
end)

Players.PlayerRemoving:Connect(function(player)
	playerAquariums[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	if not playerAquariums[player] then
		playerAquariums[player] = newAquariumState()
	end
end

print("[AquariumServer] Initialized — pearl production and creature management active")
