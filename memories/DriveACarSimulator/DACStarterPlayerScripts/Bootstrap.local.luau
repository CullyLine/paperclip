--!strict
--[[
	Client entry point. Initializes controllers and listens for server data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local FailureFeedback = require(DAC:WaitForChild("FailureFeedback"))

local Controllers = script.Parent:WaitForChild("Controllers")
local DrivingController = require(Controllers:WaitForChild("DrivingController"))
local PetController = require(Controllers:WaitForChild("PetController"))
local EggViewController = require(Controllers:WaitForChild("EggViewController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local VFXController = require(Controllers:WaitForChild("VFXController"))
local RetentionController = require(Controllers:WaitForChild("RetentionController"))
local AchievementController = require(Controllers:WaitForChild("AchievementController"))
local PurchaseThankYouController = require(Controllers:WaitForChild("PurchaseThankYouController"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
VFXFacade.bind(VFXController)

local player = Players.LocalPlayer

pcall(function()
	local TitleNametag = require(script.Parent:WaitForChild("TitleNametag"))
	TitleNametag.init()
end)

print("[DAC] Client initializing...")

SoundController.init()

local function syncEquippedPets(data: any)
	PetController.clearAll()
	if type(data) ~= "table" or type(data.pets) ~= "table" then
		return
	end
	for uid, pet in pairs(data.pets) do
		if type(pet) == "table" and pet.equipped and type(pet.id) == "string" then
			local PetConfigMod = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
			local def = PetConfigMod.Pets[pet.id]
			local rarity = def and def.rarity or "common"
			PetController.spawnPet(uid, pet.id, rarity)
		end
	end
end

Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
	syncEquippedPets(data)
	UIController.onDataUpdate(data)
	VFXController.onPlayerDataUpdate(data)
	if type(data) == "table" and data.settings then
		DrivingController.setFromSettings(data.settings)
		SoundController.applySettings(data.settings)
	end
	if type(data) == "table" and type(data.currentWorld) == "string" then
		SoundController.setWorld(data.currentWorld)
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
		return
	end
	local msg = "You found a hidden image!"
	if type(payload.hint) == "string" and payload.hint ~= "" then
		msg = payload.hint
	end
	SoundFacade.playOneShot("quest_complete")
	VFXFacade.rewardChestBurst()
	VFXFacade.milestonePopup("SECRET FOUND!", "first_time_ceremony")
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
	UIController.showRunResults(results)
end)

Remotes.getEvent("RunUpdate").OnClientEvent:Connect(function(update)
	DrivingController.onRunUpdate(update)
end)

Remotes.getEvent("ClientPromptGamePass").OnClientEvent:Connect(function(gamePassId: number)
	if type(gamePassId) ~= "number" then
		return
	end
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)
end)

Remotes.getEvent("ClientPromptDevProduct").OnClientEvent:Connect(function(productId: number)
	if type(productId) ~= "number" then
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end)

VFXController.init()
DrivingController.init()
PurchaseThankYouController.init()
PetController.init()
EggViewController.init()
UIController.init()
AchievementController.init(player:WaitForChild("PlayerGui"):WaitForChild("DACMain") :: ScreenGui)
RetentionController.init()

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
	local flavor = string.format("Near miss · x%.2g · streak %d", mult, streak)
	VFXFacade.currencyPopup("coins", math.floor(amt), flavor)
	DrivingController.recordNearMissGrant(math.floor(amt))
end)

local ok, initialData = pcall(function()
	return Remotes.getFunction("GetPlayerData"):InvokeServer()
end)
if ok and initialData then
	UIController.onDataUpdate(initialData)
	syncEquippedPets(initialData)
	print("[DAC] Initial data loaded from server")
	local streak = 0
	if type(initialData.dailyReward) == "table" then
		streak = math.floor(tonumber(initialData.dailyReward.streak) or 0)
	end
	local welcomeLine: string
	if streak >= 2 then
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

print("[DAC] Client initialized!")
