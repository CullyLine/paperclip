--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local Constants = require(DAC:WaitForChild("Constants"))

local WorldService = {}

function WorldService.unlockWorld(player: Player, worldId: string): (boolean, string?)
	local world = WorldConfig.Worlds[worldId]
	if not world then return false, "World not found" end

	local data = DataManager.get(player)
	if not data then return false, "No data" end

	if data.unlockedWorlds[worldId] then
		return false, "Already unlocked"
	end

	-- Check that the previous world is unlocked (must progress in order)
	local sortedWorlds = WorldConfig.getWorldsSorted()
	for i, w in sortedWorlds do
		if w.id == worldId and i > 1 then
			local prevWorld = sortedWorlds[i - 1]
			if not data.unlockedWorlds[prevWorld.id] then
				return false, "Unlock the previous world first"
			end
		end
	end

	if world.unlockCost > 0 then
		if not CurrencyService.spend(player, world.unlockCurrency, world.unlockCost) then
			return false, "Not enough " .. world.unlockCurrency
		end
	end

	local unlockedBefore = 0
	for _ in data.unlockedWorlds do
		unlockedBefore += 1
	end

	data.unlockedWorlds[worldId] = true

	MilestoneCeremonyService.tryWorldMasteryForUnlock(player, data, worldId)

	if unlockedBefore == 1 and worldId ~= Constants.STARTING_WORLD then
		local wname = world.name or worldId
		MilestoneCeremonyService.tryFirstTime(player, data, "FirstWorldUnlocked", { WorldName = wname })
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function WorldService.changeWorld(player: Player, worldId: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	if not data.unlockedWorlds[worldId] then
		return false, "World not unlocked"
	end

	data.currentWorld = worldId
	QuestService.onWorldChanged(player, worldId)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function WorldService.skipWorldUnlock(player: Player): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	-- Find the next locked world
	local sortedWorlds = WorldConfig.getWorldsSorted()
	for _, world in sortedWorlds do
		if not data.unlockedWorlds[world.id] then
			local unlockedBefore = 0
			for _ in data.unlockedWorlds do
				unlockedBefore += 1
			end
			data.unlockedWorlds[world.id] = true
			MilestoneCeremonyService.tryWorldMasteryForUnlock(player, data, world.id)
			if unlockedBefore == 1 and world.id ~= Constants.STARTING_WORLD then
				local wname = world.name or world.id
				MilestoneCeremonyService.tryFirstTime(player, data, "FirstWorldUnlocked", { WorldName = wname })
			end
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
			return true, nil
		end
	end

	return false, "All worlds already unlocked"
end

function WorldService.init()
	Remotes.getEvent("UnlockWorld").OnServerEvent:Connect(function(player, worldId)
		if type(worldId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "UnlockWorld") then
			return
		end
		if not RemoteCooldown.allow(player, "UnlockWorld", 1) then
			return
		end
		local success, err = WorldService.unlockWorld(player, worldId)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Failed to unlock world",
			})
		end
	end)

	Remotes.getEvent("ChangeWorld").OnServerEvent:Connect(function(player, worldId)
		if type(worldId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "ChangeWorld") then
			return
		end
		if not RemoteCooldown.allow(player, "ChangeWorld", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		WorldService.changeWorld(player, worldId)
	end)
end

return WorldService
