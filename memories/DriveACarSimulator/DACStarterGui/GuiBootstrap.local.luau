--!strict
--[[
	StarterGui entry point — initializes all GUI modules.
	Runs as a LocalScript under StarterGui.DAC.

	Studio hot reload would stack duplicate UI button / RemoteEvent listeners —
	guard once per session via _G.

	Init order (POLA-513 lazy-load pass):
	1. MenuHub (finds DACMain, sets up panel container + ActionBar shell reference)
	2. HUD + DrivingHUD — immediate (first-touch / driving responsiveness)
	3. Deferred: all other feature panels + TrophyCase grid mount after the first
	   character spawn OR first user input (whichever comes first), then task.defer.
	   Default extra delay: 0s (next scheduler tick only).
]]

local _gg = _G :: any
if _gg.__DAC_GuiBootstrapDone == true then
	return
end
_gg.__DAC_GuiBootstrapDone = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))

local parent = script.Parent
local player = Players.LocalPlayer

local MenuHub = require(parent:WaitForChild("MenuHub"))
MenuHub.init()

local HUD = require(parent:WaitForChild("HUD"))
local DrivingHUD = require(parent:WaitForChild("DrivingHUD"))

HUD.init()
DrivingHUD.init()

-- POLA-513: optional extra seconds after trigger before loading heavy UI (0 = defer one tick only).
local DEFER_HEAVY_GUI_EXTRA_SEC = 0

--- If `UIController` never becomes require-able (replication edge case or require error), unbounded
--- `task.wait()` would stall deferred panels forever. Cap the spin so Studio Output shows a warn.
local UI_CONTROLLER_WAIT_TIMEOUT_SEC = 60

local deferredGuiDone = false

local function runDeferredGuiModules()
	if deferredGuiDone then
		return
	end
	if not player.Parent then
		return
	end

	local deadline = os.clock() + UI_CONTROLLER_WAIT_TIMEOUT_SEC
	repeat
		if not player.Parent then
			return
		end
		if MenuHub.getUIController() ~= nil then
			break
		end
		if os.clock() >= deadline then
			warn(
				"[DAC] GuiBootstrap: UIController not ready after "
					.. tostring(UI_CONTROLLER_WAIT_TIMEOUT_SEC)
					.. "s; continuing deferred init (hub wiring may be incomplete)."
			)
			break
		end
		task.wait()
	until false

	if DEFER_HEAVY_GUI_EXTRA_SEC > 0 then
		task.wait(DEFER_HEAVY_GUI_EXTRA_SEC)
	end

	local DailyRewardPanel = require(parent:WaitForChild("DailyRewardPanel"))
	local WorldPanel = require(parent:WaitForChild("WorldPanel"))
	local BattlePassPanel = require(parent:WaitForChild("BattlePassPanel"))
	local QuestPanel = require(parent:WaitForChild("QuestPanel"))
	local PetIndexPanel = require(parent:WaitForChild("PetIndexPanel"))

	DailyRewardPanel.init()
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

	safeInit("PayoutPanel", function()
		require(parent:WaitForChild("PayoutPanel")).init()
	end)
	safeInit("PlaytimeGemHUD", function()
		require(parent:WaitForChild("PlaytimeGemHUD")).init()
	end)
	safeInit("EventBanner", function()
		require(parent:WaitForChild("EventBanner")).init()
	end)
	safeInit("GroupJoinBanner", function()
		require(parent:WaitForChild("GroupJoinBanner")).init()
	end)
	safeInit("FriendBonusHUD", function()
		require(parent:WaitForChild("FriendBonusHUD")).init()
	end)
	safeInit("TutorialOverlay", function()
		require(parent:WaitForChild("TutorialOverlay")).init()
	end)

	safeInit("AdminPanel", function()
		require(parent:WaitForChild("AdminPanel")).init()
	end)
	safeInit("PotionsPanel", function()
		require(parent:WaitForChild("PotionsPanel")).init()
	end)
	safeInit("ItemsPanel", function()
		require(parent:WaitForChild("ItemsPanel")).init()
	end)
	safeInit("RebirthUpgradesPanel", function()
		require(parent:WaitForChild("RebirthUpgradesPanel")).init()
	end)

	safeInit("LeaderboardPanel", function()
		require(parent:WaitForChild("LeaderboardPanel")).init()
	end)

	-- Trophy case: heavy grid build — runs after menu panels so hub buttons resolve.
	if _gg.__DAC_TrophyCaseMounted ~= true then
		local okT, errT = pcall(function()
			local playerGui = player:WaitForChild("PlayerGui")
			local screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
			local dacGui = playerGui:WaitForChild("DAC")
			local tp = dacGui:WaitForChild("TrophyCasePanel")
			if not tp:IsA("ModuleScript") then
				return
			end
			local TrophyCasePanel = require(tp :: ModuleScript)
			local uc = MenuHub.getUIController()
			if uc then
				TrophyCasePanel.mount(screenGui, uc)
				_gg.__DAC_TrophyCaseMounted = true
			end
		end)
		if not okT then
			warn("[DAC] TrophyCasePanel mount failed:", errT)
		end
	end

	deferredGuiDone = true
	Constants.bootLog("[DAC] GUI initialized (deferred modules + trophy case)")
end

local function scheduleDeferredGui()
	local fired = false
	local function once()
		if fired then
			return
		end
		fired = true
		task.defer(runDeferredGuiModules)
	end

	if player.Character then
		once()
	else
		player.CharacterAdded:Connect(function()
			once()
		end)
	end

	UserInputService.InputBegan:Connect(function()
		once()
	end)
end

scheduleDeferredGui()

Constants.bootLog("[DAC] GUI shell ready (HUD + DrivingHUD); deferring feature panels")
