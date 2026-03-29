--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local RebirthUpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthUpgradeConfig"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local RebirthUpgradeService = {}

function RebirthUpgradeService.buyUpgrade(player: Player, statId: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end

	local statDef = RebirthUpgradeConfig.Stats[statId]
	if not statDef then
		return false, "Unknown upgrade"
	end

	local upgrades = data.rebirthUpgrades
	if not upgrades then
		return false, "No upgrades data"
	end

	local currentPoints = upgrades[statId] or 0
	local maxPoints = RebirthUpgradeConfig.getMaxPoints(statId)
	if currentPoints >= maxPoints then
		return false, "Already maxed"
	end

	local cost = statDef.costPerPoint
	if (data.gems or 0) < cost then
		return false, "Not enough gems"
	end

	data.gems = (data.gems or 0) - cost
	upgrades[statId] = currentPoints + 1

	DataManager.scheduleSave(player)
	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	local newPct = RebirthUpgradeConfig.getCurrentPercent(statId, currentPoints + 1)
	NotificationDispatchService.notify(player, {
		type = "success",
		message = `{statDef.name} upgraded to +{newPct}%!`,
	})

	return true, nil
end

function RebirthUpgradeService.init()
	Remotes.getEvent("BuyRebirthUpgrade").OnServerEvent:Connect(function(player, statId: any?)
		if not ValidationService.checkRemoteRate(player, "BuyRebirthUpgrade") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "BuyRebirthUpgrade", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		if type(statId) ~= "string" then
			return
		end

		local success, err = RebirthUpgradeService.buyUpgrade(player, statId)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Upgrade failed",
			})
		end
	end)
end

return RebirthUpgradeService
