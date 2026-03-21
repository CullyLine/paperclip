--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Types = require(DAC:WaitForChild("Types"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local Constants = require(DAC:WaitForChild("Constants"))

local CarService = {}

function CarService.buyCar(player: Player, carId: string): (boolean, string?)
	local carDef = CarConfig.Cars[carId]
	if not carDef then
		return false, "Car not found"
	end

	local data = DataManager.get(player)
	if not data then return false, "No data" end

	if data.cars[carId] then
		return false, "Already owned"
	end

	-- Check world unlock
	if not data.unlockedWorlds[carDef.worldId] then
		return false, "World not unlocked"
	end

	if carDef.price > 0 then
		if not CurrencyService.spend(player, carDef.currency, carDef.price) then
			return false, "Not enough " .. carDef.currency
		end
	end

	data.cars[carId] = {
		id = carId,
		gasLevel = 0,
		powerLevel = 0,
		speedLevel = 0,
	}

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function CarService.equipCar(player: Player, carId: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	if not data.cars[carId] then
		return false, "Car not owned"
	end

	data.equippedCar = carId
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function CarService.getEffectiveStats(player: Player, carId: string): Types.EffectiveCarStats?
	local data = DataManager.get(player)
	if not data then return nil end

	local ownedCar = data.cars[carId]
	if not ownedCar then return nil end

	local carDef = CarConfig.Cars[carId]
	if not carDef then return nil end

	local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))

	local gasUpgrade = ownedCar.gasLevel * UpgradeConfig.Stats.gas.perLevel
	local powerUpgrade = ownedCar.powerLevel * UpgradeConfig.Stats.power.perLevel
	local speedUpgrade = ownedCar.speedLevel * UpgradeConfig.Stats.speed.perLevel

	-- Add rebirth bonuses
	local rebirthGas = data.rebirthStats.gas
	local rebirthPower = data.rebirthStats.power
	local rebirthSpeed = data.rebirthStats.speed

	local gas = carDef.baseStats.gas + gasUpgrade + rebirthGas
	local power = carDef.baseStats.power + powerUpgrade + rebirthPower
	local speed = carDef.baseStats.speed + speedUpgrade + rebirthSpeed

	-- Apply game pass bonuses
	local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
	if GamePassService.hasPass(player, "double_speed") then
		speed = speed * 2
	end
	if GamePassService.hasPass(player, "gas_3x") then
		gas = gas * 3
	end
	if GamePassService.hasPass(player, "infinite_gas") then
		gas = math.huge
	end

	local vipExclusiveSkin = GamePassService.hasPass(player, "vip")

	return { gas = gas, power = power, speed = speed, vipExclusiveSkin = vipExclusiveSkin }
end

function CarService.init()
	Remotes.getEvent("BuyCar").OnServerEvent:Connect(function(player, carId)
		if type(carId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "BuyCar") then
			return
		end
		if not RemoteCooldown.allow(player, "BuyCar", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = CarService.buyCar(player, carId)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Failed to buy car",
			})
		end
	end)

	Remotes.getEvent("EquipCar").OnServerEvent:Connect(function(player, carId)
		if type(carId) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "EquipCar") then
			return
		end
		if not RemoteCooldown.allow(player, "EquipCar", 0.2) then
			return
		end
		CarService.equipCar(player, carId)
	end)
end

return CarService
