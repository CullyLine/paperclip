--!strict
--[[
	AFK Training Service.
	Players stand in a Training zone to accumulate power (trainedPower).
	Power per tick = TRAINING_BASE_POWER_PER_TICK * (1 + rebirthTrainingBonus/100) * petModifier.
	trainedPower resets on rebirth; rebirthTrainingBonus is permanent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local TrainingService = {}

local activeTrainers: { [number]: thread } = {}
local TICK_INTERVAL = Constants.TRAINING_TICK_INTERVAL
local BASE_POWER = Constants.TRAINING_BASE_POWER_PER_TICK
local SYNC_INTERVAL = 2.0

local function getPetModifier(data: any): number
	if type(data.pets) ~= "table" then
		return 1
	end
	local totalPower = 0
	for _, pet in data.pets do
		if pet.equipped then
			totalPower += (pet.power or 0)
		end
	end
	return 1 + totalPower / 100
end

function TrainingService.startTraining(player: Player)
	local userId = player.UserId
	if activeTrainers[userId] then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	activeTrainers[userId] = true
	local thread = task.spawn(function()
		local ticksSincSync = 0
		local accumulatedPower = 0

		while activeTrainers[userId] and DataManager.get(player) do
			task.wait(TICK_INTERVAL)

			local d = DataManager.get(player)
			if not d then
				break
			end

			local ok, err = pcall(function()
				local rebirthBonus = d.rebirthTrainingBonus or 0
				local petMod = getPetModifier(d)
				local powerPerTick = BASE_POWER * (1 + rebirthBonus / 100) * petMod

				d.trainedPower = (d.trainedPower or 0) + powerPerTick
				accumulatedPower += powerPerTick
				ticksSincSync += 1

				if ticksSincSync * TICK_INTERVAL >= SYNC_INTERVAL then
					Remotes.getEvent("DataUpdate"):FireClient(player, d)
					Remotes.getEvent("TrainingTick"):FireClient(player, {
						powerPerTick = powerPerTick,
						trainedPower = d.trainedPower,
						petModifier = petMod,
					})
					ticksSincSync = 0
				end
			end)
			if not ok then
				warn("[TrainingService] Training tick error for " .. player.Name .. ": " .. tostring(err))
				break
			end
		end

		activeTrainers[userId] = nil
	end)
	activeTrainers[userId] = thread
end

function TrainingService.stopTraining(player: Player)
	local userId = player.UserId
	local thread = activeTrainers[userId]
	if thread then
		task.cancel(thread)
		activeTrainers[userId] = nil
	end

	local data = DataManager.get(player)
	if data then
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
		DataManager.scheduleSave(player)
	end
end

function TrainingService.isTraining(player: Player): boolean
	return activeTrainers[player.UserId] ~= nil
end

function TrainingService.init()
	Remotes.getEvent("StartTraining").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "StartTraining") then
			return
		end
		if not RemoteCooldown.allow(player, "StartTraining", 1.0) then
			return
		end
		TrainingService.startTraining(player)
	end)

	Remotes.getEvent("StopTraining").OnServerEvent:Connect(function(player)
		if not RemoteCooldown.allow(player, "StopTraining", 0.5) then
			return
		end
		TrainingService.stopTraining(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		TrainingService.stopTraining(player)
	end)
end

return TrainingService
