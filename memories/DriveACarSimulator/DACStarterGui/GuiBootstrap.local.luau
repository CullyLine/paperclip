--!strict
--[[
	StarterGui entry point — initializes all GUI modules.
	Runs as a LocalScript under StarterGui.DAC.

	Init order:
	1. MenuHub (finds DACMain, sets up panel container + ActionBar buttons)
	2. New feature panels (registered with MenuHub)
	3. HUD + DrivingHUD (existing)
	4. Standalone overlays (own ScreenGui, independent lifecycle)
]]

local parent = script.Parent

local MenuHub = require(parent:WaitForChild("MenuHub"))
MenuHub.init()

local DailyRewardPanel = require(parent:WaitForChild("DailyRewardPanel"))
local LeaderboardPanel = require(parent:WaitForChild("LeaderboardPanel"))
local WorldPanel = require(parent:WaitForChild("WorldPanel"))
local BattlePassPanel = require(parent:WaitForChild("BattlePassPanel"))
local QuestPanel = require(parent:WaitForChild("QuestPanel"))
local PetIndexPanel = require(parent:WaitForChild("PetIndexPanel"))

DailyRewardPanel.init()
LeaderboardPanel.init()
WorldPanel.init()
BattlePassPanel.init()
QuestPanel.init()
PetIndexPanel.init()

local function safeInit(name: string, initFn: () -> ())
	local ok, err = pcall(initFn)
	if not ok then
		warn("[DAC] " .. name .. " failed to init: " .. tostring(err))
	end
end

safeInit("InventoryPanel", function()
	require(parent:WaitForChild("InventoryPanel")).init()
end)
safeInit("StorePanel", function()
	require(parent:WaitForChild("StorePanel")).init()
end)
safeInit("EggShopPanel", function()
	require(parent:WaitForChild("EggShopPanel")).init()
end)
safeInit("RebirthPanel", function()
	require(parent:WaitForChild("RebirthPanel")).init()
end)
safeInit("SettingsPanel", function()
	require(parent:WaitForChild("SettingsPanel")).init()
end)
safeInit("CodesPanel", function()
	require(parent:WaitForChild("CodesPanel")).init()
end)

local HUD = require(parent:WaitForChild("HUD"))
local DrivingHUD = require(parent:WaitForChild("DrivingHUD"))

HUD.init()
DrivingHUD.init()

safeInit("PayoutPanel", function()
	require(parent:WaitForChild("PayoutPanel")).init()
end)
safeInit("PlaytimeGemHUD", function()
	require(parent:WaitForChild("PlaytimeGemHUD")).init()
end)
safeInit("EventBanner", function()
	require(parent:WaitForChild("EventBanner")).init()
end)
safeInit("TutorialOverlay", function()
	require(parent:WaitForChild("TutorialOverlay")).init()
end)

print("[DAC] GUI initialized (all modules)")
