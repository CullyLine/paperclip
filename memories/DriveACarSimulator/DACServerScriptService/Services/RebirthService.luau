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
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
-- local QuestService = require(script.Parent:WaitForChild("QuestService"))

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

-- expectedRebirths: client snapshot of `data.rebirths` before requesting. Enables idempotent duplicate handling:
-- if server already applied (rebirths == expected + 1), return success without re-running rewards/quests.
function RebirthService.rebirth(player: Player, skipCost: boolean?, expectedRebirths: number?): (boolean, string?, boolean?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data", false
	end

	if type(expectedRebirths) == "number" then
		local exp = math.max(0, math.floor(expectedRebirths))
		local cur = math.max(0, math.floor(data.rebirths))
		if cur ~= exp then
			if cur == exp + 1 then
				-- Duplicate request after successful rebirth; keep client in sync without double rewards.
				Remotes.getEvent("DataUpdate"):FireClient(player, data)
				return true, nil, true
			end
			return false, "Out of sync — try again.", false
		end
	end

	if not skipCost then
		local cost = RebirthService.getRebirthCost(data.rebirths)
		local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
		if GamePassService.hasPass(player, "rebirth_rush") then
			cost = math.floor(cost * 0.75)
		end
		if data.coins < cost then
			return false, "Not enough coins", false
		end
	end

	local prevRebirths = data.rebirths
	local wasFirstRebirth = prevRebirths == 0

	-- Apply rebirth rewards
	data.rebirths += 1
	data.rebirthStats.gas += RebirthConfig.Rewards.gasBoost
	data.rebirthStats.power += RebirthConfig.Rewards.powerBoost
	data.rebirthStats.speed += RebirthConfig.Rewards.speedBoost

	-- Reset according to config
	if RebirthConfig.ResetOnRebirth.coins then
		data.coins = 0
	end
	if RebirthConfig.ResetOnRebirth.eggs then
		data.eggs = {}
	end
	if RebirthConfig.ResetOnRebirth.carUpgrades then
		for _, car in data.cars do
			car.gasLevel = 0
			car.powerLevel = 0
			car.speedLevel = 0
		end
	end

	data.stats.totalRebirths += 1

	EconomyLogService.logRebirth(player, data.rebirths, 0)

	-- QuestService.onRebirth(player)

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
	NotificationDispatchService.notify(player, {
		type = "success",
		message = `Rebirth #{data.rebirths}! +{RebirthConfig.Rewards.gasBoost} Gas, +{RebirthConfig.Rewards.powerBoost} Power, +{RebirthConfig.Rewards.speedBoost} Speed`,
	})

	return true, nil, false
end

function RebirthService.init()
	Remotes.getEvent("Rebirth").OnServerEvent:Connect(function(player, expectedRebirths: any?)
		if not ValidationService.checkRemoteRate(player, "Rebirth") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "Rebirth", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local exp: number? = nil
		if type(expectedRebirths) == "number" then
			exp = math.max(0, math.floor(expectedRebirths))
		elseif expectedRebirths ~= nil then
			ValidationService.logAnomalyOncePerSession(player, "rebirth_bad_expected_type", "")
			return
		end
		local success, err, dup = RebirthService.rebirth(player, false, exp)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Rebirth failed",
			})
		elseif dup then
			-- Idempotent replay: DataUpdate already fired inside rebirth(); no toast spam.
		end
	end)
end

return RebirthService
