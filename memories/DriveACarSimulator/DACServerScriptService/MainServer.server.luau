--!strict
--[[
	Server entry point. Initializes all systems in order.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local ServerRoot = script.Parent
local DataManager = require(ServerRoot:WaitForChild("DataManager"))

-- Services
local Services = ServerRoot:WaitForChild("Services")
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local CarService = require(Services:WaitForChild("CarService"))
local RunService = require(Services:WaitForChild("RunService"))
local UpgradeService = require(Services:WaitForChild("UpgradeService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local EggService = require(Services:WaitForChild("EggService"))
local PetService = require(Services:WaitForChild("PetService"))
local GamePassService = require(Services:WaitForChild("GamePassService"))
local DevProductService = require(Services:WaitForChild("DevProductService"))
local PremiumService = require(Services:WaitForChild("PremiumService"))
local DailyRewardService = require(Services:WaitForChild("DailyRewardService"))
local CodeService = require(Services:WaitForChild("CodeService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local BattlePassService = require(Services:WaitForChild("BattlePassService"))
local QuestService = require(Services:WaitForChild("QuestService"))
local EventService = require(Services:WaitForChild("EventService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local PlaytimeService = require(Services:WaitForChild("PlaytimeService"))
local SettingsService = require(Services:WaitForChild("SettingsService"))
local TradeService = require(Services:WaitForChild("TradeService"))
local ValidationService = require(Services:WaitForChild("ValidationService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local VipEffectsService = require(Services:WaitForChild("VipEffectsService"))
local EasterEggService = require(Services:WaitForChild("EasterEggService"))
local AchievementService = require(Services:WaitForChild("AchievementService"))

print("[DAC] Server initializing...")

-- 1. Create remote events/functions
Remotes.init()

-- 2. Initialize data manager (auto-save, bind-to-close)
DataManager.init()

-- 3. Initialize all services
CurrencyService.init()
CarService.init()
RunService.init()
UpgradeService.init()
RebirthService.init()
WorldService.init()
EggService.init()
PetService.init()
GamePassService.init()
DevProductService.init()
PremiumService.init()
DailyRewardService.init()
CodeService.init()
LeaderboardService.init()
ValidationService.init()
BattlePassService.init()
QuestService.init()
SettingsService.init()
EventService.init()
TutorialService.init()
PlaytimeService.init()
TradeService.init()
AdminService.init()
VipEffectsService.init()
EasterEggService.init()
AchievementService.init()

-- 4. Wire GetPlayerData so clients can request their data at any time
Remotes.getFunction("GetPlayerData").OnServerInvoke = function(player)
	local data = DataManager.get(player)
	return data
end

-- 5. Handle player connections
Players.PlayerAdded:Connect(function(player)
	local loaded = DataManager.load(player)
	if not loaded then
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	local data = DataManager.get(player)

	RebirthService.syncPrestigeAttributes(player)

	GamePassService.checkAllPasses(player)
	BattlePassService.ensureSeason(player)
	QuestService.ensureQuests(player)

	Remotes.getEvent("DataUpdate"):FireClient(player, data)

	task.defer(function()
		LeaderboardService.updatePlayer(player)
	end)

	AchievementService.syncProgressNudges(player)

	EventService.handlePlayerJoin(player)
	task.defer(TutorialService.handlePlayerJoin, player)
	QuestService.onWorldChanged(player, data.currentWorld)

	print(`[DAC] {player.Name} loaded successfully`)
end)

-- Handle players already in game (Studio edge case)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		local loaded = DataManager.load(player)
		if loaded then
			local data = DataManager.get(player)
			RebirthService.syncPrestigeAttributes(player)
			GamePassService.checkAllPasses(player)
			BattlePassService.ensureSeason(player)
			QuestService.ensureQuests(player)
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
			task.defer(function()
				LeaderboardService.updatePlayer(player)
			end)
			AchievementService.syncProgressNudges(player)
			EventService.handlePlayerJoin(player)
			task.defer(TutorialService.handlePlayerJoin, player)
			QuestService.onWorldChanged(player, data.currentWorld)
		end
	end)
end

print("[DAC] Server initialized!")
