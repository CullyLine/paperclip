--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
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

	if not data.unlockedWorlds[carDef.worldId] then
		return false, "World not unlocked"
	end

	if carDef.price > 0 then
		if not CurrencyService.spend(player, carDef.currency, carDef.price) then
			return false, "Not enough " .. carDef.currency
		end
	end

	local carCountBefore = 0
	for _ in data.cars do
		carCountBefore += 1
	end

	data.cars[carId] = {
		id = carId,
	}

	if carCountBefore == 1 then
		MilestoneCeremonyService.tryFirstTime(player, data, "FirstCarPurchased", nil)
	end

	AchievementService.onGarageMaybeComplete(player)

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

function CarService.getEffectiveStats(player: Player, carId: string): { gas: number, power: number, acceleration: number }?
	local data = DataManager.get(player)
	if not data then return nil end

	if not data.cars[carId] then return nil end

	local carDef = CarConfig.Cars[carId]
	if not carDef then return nil end

	local upgrades = data.rebirthUpgrades or {}
	local gasMultiplier = 1 + ((upgrades :: any).moreGas or 0) * 5 / 100
	local accelMultiplier = 1 + ((upgrades :: any).moreAcceleration or 0) * 5 / 100

	local gas = carDef.baseStats.gas * gasMultiplier
	local power = carDef.baseStats.power + (data.trainedPower or 0)
	local acceleration = carDef.baseStats.acceleration / accelMultiplier

	local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
	if GamePassService.hasPass(player, "double_speed") then
		power = power * 2
	end
	if GamePassService.hasPass(player, "infinite_gas") then
		gas = math.huge
	end

	return { gas = gas, power = power, acceleration = acceleration }
end

function CarService.init()
	Remotes.getEvent("BuyCar").OnServerEvent:Connect(function(player, carId)
		if not ValidationService.checkRemoteRate(player, "BuyCar") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		local maxId = ValidationService.MAX_REMOTE_STRING_ID_LEN
		if not ValidationService.isBoundedStringId(carId, maxId) then
			if type(carId) ~= "string" then
				ValidationService.logAnomalyOncePerSession(player, "buy_car_bad_type", "")
			else
				ValidationService.logAnomalyOncePerSession(player, "buy_car_bad_id_len", "")
			end
			return
		end
		if not RemoteCooldown.allow(player, "BuyCar", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = CarService.buyCar(player, carId)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Failed to buy car",
			})
		end
	end)

	Remotes.getEvent("EquipCar").OnServerEvent:Connect(function(player, carId)
		if not ValidationService.checkRemoteRate(player, "EquipCar") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		local maxId = ValidationService.MAX_REMOTE_STRING_ID_LEN
		if not ValidationService.isBoundedStringId(carId, maxId) then
			if type(carId) ~= "string" then
				ValidationService.logAnomalyOncePerSession(player, "equip_car_bad_type", "")
			else
				ValidationService.logAnomalyOncePerSession(player, "equip_car_bad_id_len", "")
			end
			return
		end
		if not RemoteCooldown.allow(player, "EquipCar", 0.2) then
			return
		end
		CarService.equipCar(player, carId)
	end)
end

return CarService
