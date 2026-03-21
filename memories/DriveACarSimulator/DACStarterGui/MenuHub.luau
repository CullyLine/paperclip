--!strict
--[[
	Thin wrapper that delegates panel management to UIController.
	Feature panels (BattlePass, Quests, etc.) call MenuHub.registerPanel()
	which forwards to UIController.registerPanel(). All open/close/toggle
	goes through UIController so there is one unified panel system.
]]

local Players = game:GetService("Players")

local MenuHub = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local panelsFrame: Frame

local _uiController: any = nil

local function getUIController(): any?
	if _uiController then return _uiController end
	local ps = player:FindFirstChild("PlayerScripts")
	if not ps then return nil end
	local dac = ps:FindFirstChild("DAC")
	if not dac then return nil end
	local controllers = dac:FindFirstChild("Controllers")
	if not controllers then return nil end
	local mod = controllers:FindFirstChild("UIController")
	if not mod then return nil end
	local ok, result = pcall(require, mod :: ModuleScript)
	if ok then
		_uiController = result
		return _uiController
	end
	return nil
end

function MenuHub.getScreenGui(): any
	return panelsFrame
end

function MenuHub.registerPanel(id: string, frame: Frame)
	local uc = getUIController()
	if uc and uc.registerPanel then
		uc.registerPanel(id, frame)
	end
end

function MenuHub.open(id: string)
	local uc = getUIController()
	if uc and uc.openPanel then
		uc.openPanel(id)
	end
end

function MenuHub.closeAll()
	local uc = getUIController()
	if uc and uc.closeAll then
		uc.closeAll()
	end
end

function MenuHub.toggle(id: string)
	local uc = getUIController()
	if uc and uc.togglePanel then
		uc.togglePanel(id)
	end
end

function MenuHub.init()
	local screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	panelsFrame = screenGui:WaitForChild("Panels") :: Frame

	print("[DAC] MenuHub initialized (delegates to UIController)")
end

return MenuHub
