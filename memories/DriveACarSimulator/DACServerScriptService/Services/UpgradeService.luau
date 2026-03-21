--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Utils = require(DAC:WaitForChild("Utils"))
local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local Constants = require(DAC:WaitForChild("Constants"))

local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local UpgradeService = {}

function UpgradeService.upgrade(player: Player, carId: string, stat: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local ownedCar = data.cars[carId]
	if not ownedCar then return false, "Car not owned" end

	local statConfig = UpgradeConfig.Stats[stat]
	if not statConfig then return false, "Invalid stat" end

	local levelKey = stat .. "Level"
	local currentLevel = ownedCar[levelKey]
	if currentLevel >= statConfig.maxLevel then
		return false, "Max level reached"
	end

	local cost = Utils.getUpgradeCost(statConfig.baseCost, statConfig.costMultiplier, currentLevel)
	if not CurrencyService.spend(player, statConfig.currency, cost) then
		return false, "Not enough " .. statConfig.currency
	end

	ownedCar[levelKey] = currentLevel + 1

	QuestService.onUpgrade(player)
	TutorialService.onUpgrade(player, stat)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function UpgradeService.init()
	Remotes.getEvent("UpgradeStat").OnServerEvent:Connect(function(player, carId, stat)
		if type(carId) ~= "string" or type(stat) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "UpgradeStat") then
			return
		end
		if not RemoteCooldown.allow(player, "UpgradeStat", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = UpgradeService.upgrade(player, carId, stat)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Upgrade failed",
			})
		end
	end)
end

return UpgradeService
