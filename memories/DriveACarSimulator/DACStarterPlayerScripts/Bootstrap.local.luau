--!strict
--[[
	Client entry point. Initializes controllers and listens for server data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local Controllers = script.Parent:WaitForChild("Controllers")
local DrivingController = require(Controllers:WaitForChild("DrivingController"))
local PetController = require(Controllers:WaitForChild("PetController"))
local EggViewController = require(Controllers:WaitForChild("EggViewController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local VFXController = require(Controllers:WaitForChild("VFXController"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
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
			PetController.spawnPet(uid, pet.id)
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
	UIController.showNotification(notification)
end)

Remotes.getEvent("EasterEggDiscovered").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local msg = "You found a hidden image!"
	if type(payload.hint) == "string" and payload.hint ~= "" then
		msg = payload.hint
	end
	UIController.showNotification({
		type = "success",
		message = msg,
	})
end)

Remotes.getEvent("StartRun").OnClientEvent:Connect(function(runInfo)
	DrivingController.startRun(runInfo)
	VFXController.onRunStarted(runInfo)
end)

Remotes.getEvent("EndRun").OnClientEvent:Connect(function(results)
	DrivingController.endRun(results)
	VFXController.onRunEnded()
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
PetController.init()
EggViewController.init()
UIController.init()

local ok, initialData = pcall(function()
	return Remotes.getFunction("GetPlayerData"):InvokeServer()
end)
if ok and initialData then
	UIController.onDataUpdate(initialData)
	syncEquippedPets(initialData)
	print("[DAC] Initial data loaded from server")
end

print("[DAC] Client initialized!")
