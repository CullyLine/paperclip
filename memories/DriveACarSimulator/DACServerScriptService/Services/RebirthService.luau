--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Utils = require(DAC:WaitForChild("Utils"))
local Constants = require(DAC:WaitForChild("Constants"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local RebirthMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthMilestoneConfig"))
local EconomyLogService = require(script.Parent:WaitForChild("EconomyLogService"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local RebirthService = {}

function RebirthService.syncPrestigeAttributes(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	local rb = if type(data.rebirths) == "number" then math.max(0, math.floor(data.rebirths)) else 0
	player:SetAttribute("DAC_PrestigeTier", RebirthMilestoneConfig.getPrestigeTier(rb))
end

function RebirthService.getRebirthCost(rebirths: number): number
	return Utils.calculateRebirthCost(rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
end

function RebirthService.calculateRebirthCosts(currentRebirths: number, count: number): number
	local total = 0
	for i = 0, count - 1 do
		total += RebirthService.getRebirthCost(currentRebirths + i)
	end
	return total
end

function RebirthService.calculateMaxAffordable(coins: number, currentRebirths: number): number
	local count = 0
	local remaining = coins
	while true do
		local cost = RebirthService.getRebirthCost(currentRebirths + count)
		local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
		if GamePassService._cachedPasses and GamePassService._cachedPasses["rebirth_rush"] then
			cost = math.floor(cost * 0.75)
		end
		if remaining < cost then
			break
		end
		remaining -= cost
		count += 1
	end
	return count
end

function RebirthService.rebirth(player: Player, count: number?, skipCost: boolean?): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end

	local rebirthCount = math.max(1, math.floor(tonumber(count) or 1))

	if not skipCost then
		local totalCost = 0
		local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
		local hasRush = GamePassService.hasPass(player, "rebirth_rush")
		for i = 0, rebirthCount - 1 do
			local c = RebirthService.getRebirthCost(data.rebirths + i)
			if hasRush then
				c = math.floor(c * 0.75)
			end
			totalCost += c
		end
		if data.coins < totalCost then
			return false, "Not enough coins"
		end
	end

	local prevRebirths = data.rebirths
	local wasFirstRebirth = prevRebirths == 0

	data.rebirths += rebirthCount
	data.rebirthTrainingBonus = (data.rebirthTrainingBonus or 0) + (RebirthConfig.Rewards.trainingBonusPerRebirth * rebirthCount)
	data.gems = (data.gems or 0) + (RebirthConfig.Rewards.gemsGranted * rebirthCount)

	if RebirthConfig.ResetOnRebirth.coins then
		data.coins = 0
	end
	if RebirthConfig.ResetOnRebirth.trainedPower then
		data.trainedPower = 0
	end

	data.stats.totalRebirths += rebirthCount

	EconomyLogService.logRebirth(player, data.rebirths, 0)

	RebirthService.syncPrestigeAttributes(player)

	local mk = RebirthMilestoneConfig.getHighestMilestoneCrossed(prevRebirths, data.rebirths)
	if mk then
		MilestoneCeremonyService.fireRebirthTierCeremony(player, data.rebirths, mk)
	end

	if wasFirstRebirth then
		MilestoneCeremonyService.tryFirstTime(player, data, "FirstRebirth", nil)
	end

	AchievementService.onRebirth(player)

	DataManager.saveImmediate(player)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	local bonusGained = RebirthConfig.Rewards.trainingBonusPerRebirth * rebirthCount
	local gemsGained = RebirthConfig.Rewards.gemsGranted * rebirthCount
	if rebirthCount == 1 then
		NotificationDispatchService.notify(player, {
			type = "success",
			message = `Rebirth #{data.rebirths}! +{bonusGained}% training power, +{gemsGained} Gems`,
		})
	else
		NotificationDispatchService.notify(player, {
			type = "success",
			message = `{rebirthCount}x Rebirth! Now at #{data.rebirths}. +{bonusGained}% training power, +{gemsGained} Gems`,
		})
	end

	return true, nil
end

function RebirthService.init()
	Remotes.getEvent("Rebirth").OnServerEvent:Connect(function(player, requestedCount: any?)
		if not ValidationService.checkRemoteRate(player, "Rebirth") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "Rebirth", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end

		local count = 1
		if type(requestedCount) == "number" then
			count = math.max(1, math.floor(requestedCount))
		elseif requestedCount ~= nil then
			ValidationService.logAnomalyOncePerSession(player, "rebirth_bad_count_type", "")
			return
		end

		local data = DataManager.get(player)
		if not data then
			return
		end

		local maxSkipTier = 1
		local skips = (data.rebirthUpgrades and data.rebirthUpgrades.moreRebirthSkips) or 0
		local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
		local hasUnlimited = GamePassService.hasPass(player, "unlimited_rebirths")

		if hasUnlimited then
			maxSkipTier = math.huge
		else
			local tiers = RebirthConfig.SkipTiers
			local unlockedTiers = math.min(1 + skips, #tiers)
			maxSkipTier = tiers[unlockedTiers] or 1
		end

		if count > maxSkipTier and not hasUnlimited then
			count = maxSkipTier
		end

		if hasUnlimited and count > 1000 then
			local maxAffordable = RebirthService.calculateMaxAffordable(data.coins, data.rebirths)
			count = math.min(count, maxAffordable)
		end

		local success, err = RebirthService.rebirth(player, count, false)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Rebirth failed",
			})
		end
	end)
end

return RebirthService
