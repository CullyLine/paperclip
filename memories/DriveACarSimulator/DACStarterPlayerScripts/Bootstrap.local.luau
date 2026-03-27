--!strict
--[[
	Client entry point. Initializes controllers and listens for server data.

	Studio hot reload / script re-execution would otherwise stack RemoteEvent
	connections and duplicate controller init — guard once per session via _G.
]]

local _gg = _G :: any
if _gg.__DAC_ClientBootstrapDone == true then
	return
end
_gg.__DAC_ClientBootstrapDone = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local IapPromptGuard = require(DAC:WaitForChild("IapPromptGuard"))
local ClientRemoteDebounce = require(DAC:WaitForChild("ClientRemoteDebounce"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local FailureFeedback = require(DAC:WaitForChild("FailureFeedback"))

local Controllers = script.Parent:WaitForChild("Controllers")
local DrivingController = require(Controllers:WaitForChild("DrivingController"))
local PetController = require(Controllers:WaitForChild("PetController"))
local EggViewController = require(Controllers:WaitForChild("EggViewController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local VFXController = require(Controllers:WaitForChild("VFXController"))
local RetentionController = require(Controllers:WaitForChild("RetentionController"))
local VehicleEnterJuiceController = require(Controllers:WaitForChild("VehicleEnterJuiceController"))
local AchievementController = require(Controllers:WaitForChild("AchievementController"))
local PurchaseThankYouController = require(Controllers:WaitForChild("PurchaseThankYouController"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local ClientUiLifecycle = require(DAC:WaitForChild("ClientUiLifecycle"))
local NewPlayerCalmWindow = require(DAC:WaitForChild("NewPlayerCalmWindow"))
VFXFacade.bind(VFXController)

local player = Players.LocalPlayer

ClientPerformanceProfile.startFpsTracking(player)

pcall(function()
	local TitleNametag = require(script.Parent:WaitForChild("TitleNametag"))
	TitleNametag.init()
end)

Constants.bootLog("[DAC] Client initializing...")

-- Gamepad / d-pad UI navigation (focus rings + Selectable need this on some platforms).
GuiService.GuiNavigationEnabled = true

SoundController.init()

local lastEquippedPetSet: { string } = {}

local function syncEquippedPets(data: any)
	if type(data) ~= "table" or type(data.pets) ~= "table" then
		if #lastEquippedPetSet > 0 then
			PetController.clearAll()
			table.clear(lastEquippedPetSet)
		end
		return
	end
	local sorted: { { uid: string, id: string, power: number, rarity: string } } = {}
	for uid, pet in pairs(data.pets) do
		if type(pet) == "table" and pet.equipped and type(pet.id) == "string" then
			local def = PetConfig.Pets[pet.id]
			local rarity = def and def.rarity or "common"
			table.insert(sorted, { uid = uid, id = pet.id, power = pet.power or 0, rarity = rarity })
		end
	end
	table.sort(sorted, function(a, b)
		return a.power > b.power
	end)

	local newSet: { string } = {}
	for i, entry in sorted do
		if i > PetConfig.MAX_FOLLOWING then
			break
		end
		table.insert(newSet, entry.uid .. ":" .. entry.id)
	end

	local changed = #newSet ~= #lastEquippedPetSet
	if not changed then
		for i, key in newSet do
			if lastEquippedPetSet[i] ~= key then
				changed = true
				break
			end
		end
	end
	if not changed then
		return
	end

	PetController.clearAll()
	lastEquippedPetSet = newSet
	for i, entry in sorted do
		if i > PetConfig.MAX_FOLLOWING then
			break
		end
		PetController.spawnPet(entry.uid, entry.id, entry.rarity)
	end
end

Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
	RemoteFailSafe.setPlayerDataCache(data)
	syncEquippedPets(data)
	if type(data) == "table" and data.settings then
		ClientPerformanceProfile.syncFromSettings(data.settings)
		ClientPerformanceProfile.applyAttributes(player)
	end
	UIController.onDataUpdate(data)
	VFXController.onPlayerDataUpdate(data)
	if type(data) == "table" and data.settings then
		DrivingController.setFromSettings(data.settings)
		SoundController.applySettings(data.settings)
		PetController.applySettings(data.settings)
	end
	if type(data) == "table" and type(data.currentWorld) == "string" then
		SoundController.onWorldEnter(data.currentWorld)
		VFXFacade.finishWorldTravel(data.currentWorld)
	end
end)

Remotes.getEvent("CurrencyUpdate").OnClientEvent:Connect(function(currencies)
	UIController.onCurrencyUpdate(currencies)
end)

Remotes.getEvent("Notification").OnClientEvent:Connect(function(notification)
	if type(notification) == "table" and notification.type == "premium_welcome" then
		VFXFacade.premiumWelcomeFanfare()
		return
	end
	if type(notification) == "table" and notification.code == "fuel_empty" then
		FailureFeedback.show("fuelEmpty", {})
		return
	end
	UIController.showNotification(notification)
end)

Remotes.getEvent("ServerDropFeed").OnClientEvent:Connect(function(payload: any)
	VFXFacade.serverDropFeedBanner(payload)
end)

Remotes.getEvent("FusionResult").OnClientEvent:Connect(function(payload: any)
	SoundFacade.playOneShot("fusion")
	VFXFacade.fusionReveal(payload)
end)

Remotes.getEvent("EasterEggDiscovered").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
Remotes.getEvent("RankUpNotification").OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" then
		return
	end
	VFXFacade.leaderboardRankFanfare(data)
end)

		return
	end
	local msg = MicrocopyConfig.EasterEggDiscoveryDefaultToast
	if type(payload.hint) == "string" and payload.hint ~= "" then
		msg = payload.hint
	end
	SoundFacade.playOneShot("quest_complete")
	VFXFacade.rewardChestBurst()
	VFXFacade.milestonePopup(MicrocopyConfig.EasterEggSecretFoundHeadline, "first_time_ceremony")
	UIController.showNotification({
		type = "success",
		message = msg,
	})
end)

Remotes.getEvent("StartRun").OnClientEvent:Connect(function(runInfo)
	DrivingController.startRun(runInfo)
	VFXController.onRunStarted(runInfo)
	VFXFacade.ambientStop()
	if type(runInfo) == "table" and runInfo.isFirstRunOfDay == true then
		VFXFacade.firstRunEntrance()
	end
end)

Remotes.getEvent("EndRun").OnClientEvent:Connect(function(results)
	DrivingController.endRun(results)
	VFXController.onRunEnded()
	VFXFacade.ambientStart()
	PurchaseThankYouController.onRunEnded()
	UIController.flushDeferredRunToasts()
	UIController.showRunResults(results)
end)

Remotes.getEvent("RunUpdate").OnClientEvent:Connect(function(update)
	DrivingController.onRunUpdate(update)
end)

local lastClientIapPromptFire = { 0 }

local function runPurchasePrompt(promptFn: () -> (), finishedEvent: RBXScriptSignal)
	if not ClientRemoteDebounce.allow(lastClientIapPromptFire, ClientRemoteDebounce.IAP_PROMPT_COOLDOWN_SEC) then
		UIController.showNotification({
			type = "info",
			message = MicrocopyConfig.pickVariant(MicrocopyConfig.IapPurchasePromptBusy),
		})
		return
	end
	if not IapPromptGuard.tryBegin() then
		UIController.showNotification({
			type = "info",
			message = MicrocopyConfig.pickVariant(MicrocopyConfig.IapPurchasePromptBusy),
		})
		return
	end
	local conn: RBXScriptConnection?
	local finished = false
	local function cleanup()
		if finished then
			return
		end
		finished = true
		IapPromptGuard.endPrompt()
		if conn then
			conn:Disconnect()
		end
	end
	conn = finishedEvent:Connect(function(plr: Player, _productOrPassId: number, didPurchase: boolean?)
		if plr ~= player then
			return
		end
		if didPurchase == false then
			local msg = MicrocopyConfig.pickVariant(MicrocopyConfig.SoftFailPurchaseCancelled)
			UIController.showNotification({
				type = "info",
				message = msg,
			})
		end
		cleanup()
	end)
	local ok, err = pcall(promptFn)
	if not ok then
		warn("[DAC] Purchase prompt failed:", err)
		cleanup()
	end
end

Remotes.getEvent("ClientPromptGamePass").OnClientEvent:Connect(function(gamePassId: number)
	if type(gamePassId) ~= "number" then
		return
	end
	runPurchasePrompt(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end, MarketplaceService.PromptGamePassPurchaseFinished)
end)

Remotes.getEvent("ClientPromptDevProduct").OnClientEvent:Connect(function(productId: number)
	if type(productId) ~= "number" then
		return
	end
	runPurchasePrompt(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end, MarketplaceService.PromptProductPurchaseFinished)
end)

VFXController.init()
ClientUiLifecycle.init(player)
DrivingController.init()
PurchaseThankYouController.init()
PetController.init()
EggViewController.init()
UIController.init()
AchievementController.init(player:WaitForChild("PlayerGui"):WaitForChild("DACMain") :: ScreenGui)
RetentionController.init()
VehicleEnterJuiceController.init()

Remotes.getEvent("FirstTimeCeremony").OnClientEvent:Connect(function(payload: any)
	VFXController.ceremonyFirstTime(payload)
end)
Remotes.getEvent("SpendMilestone").OnClientEvent:Connect(function(payload: any)
	VFXController.ceremonySpendMilestone(payload)
end)
Remotes.getEvent("StreakMilestone").OnClientEvent:Connect(function(payload: any)
	VFXController.ceremonyStreakMilestone(payload)
end)
Remotes.getEvent("NearMissClaim").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local amt = tonumber(payload.amount)
	if amt == nil or amt <= 0 then
		return
	end
	local streak = math.floor(tonumber(payload.streak) or 1)
	local mult = tonumber(payload.multiplier) or 1
	local flavor = MicrocopyConfig.NearMissCurrencyFlavorFormat:gsub("{MULT}", string.format("%.2g", mult)):gsub(
		"{STREAK}",
		tostring(streak)
	)
	VFXFacade.currencyPopup("coins", math.floor(amt), flavor)
	DrivingController.recordNearMissGrant(math.floor(amt))
end)

local ok, initialData = pcall(function()
	return Remotes.getFunction("GetPlayerData"):InvokeServer()
end)
if ok and initialData then
	UIController.onDataUpdate(initialData)
	syncEquippedPets(initialData)
	Constants.bootLog("[DAC] Initial data loaded from server")
	NewPlayerCalmWindow.initFromPlayerData(initialData)
	local streak = 0
	if type(initialData.dailyReward) == "table" then
		streak = math.floor(tonumber(initialData.dailyReward.streak) or 0)
	end
	local daysAway = 0
	local retAny = (initialData :: any).retention
	if type(retAny) == "table" then
		daysAway = math.floor(tonumber(retAny.daysSinceLastSession) or 0)
	end
	local fso = (initialData :: any).firstSessionOnboarding
	local welcomeLine: string
	if type(fso) == "table" and fso.firstPlaySessionEnded == false and fso.sessionWelcomeToastSeen == false then
		welcomeLine = MicrocopyConfig.FirstSessionWelcomeToast
		pcall(function()
			Remotes.getFunction("FirstSessionOnboarding"):InvokeServer({ kind = "ackWelcomeToast" })
		end)
	elseif daysAway >= 14 then
		welcomeLine = MicrocopyConfig.SessionWinback14d[math.random(1, #MicrocopyConfig.SessionWinback14d)]
	elseif daysAway >= 7 then
		welcomeLine = MicrocopyConfig.SessionWinback7d[math.random(1, #MicrocopyConfig.SessionWinback7d)]
	elseif streak >= 2 and daysAway >= 1 then
		welcomeLine = MicrocopyConfig.ReturnStreakWelcome[math.random(1, #MicrocopyConfig.ReturnStreakWelcome)]:gsub(
			"{STREAK}",
			tostring(streak)
		)
	elseif streak >= 2 then
		welcomeLine = MicrocopyConfig.SessionWelcomeStreak[math.random(1, #MicrocopyConfig.SessionWelcomeStreak)]:gsub(
			"{STREAK}",
			tostring(streak)
		)
	else
		welcomeLine = MicrocopyConfig.SessionWelcome[math.random(1, #MicrocopyConfig.SessionWelcome)]
	end
	UIController.showNotification({
		type = "success",
		message = welcomeLine,
	})
end

Constants.bootLog("[DAC] Client initialized!")
