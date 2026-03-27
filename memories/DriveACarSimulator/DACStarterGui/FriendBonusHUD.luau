--!strict
--[[
	Small lobby HUD chip for friend play coin bonus.
	UI shell: StarterGui.DACFriendBonusHUD (see default.project.json).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))

local FriendBonusHUD = {}

function FriendBonusHUD.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("DACFriendBonusHUD", 30) :: ScreenGui?
	if not gui then
		warn("[DAC] DACFriendBonusHUD missing under PlayerGui — sync default.project.json / Rojo")
		return
	end

	gui.DisplayOrder = UILayerStack.screenGui.hudChrome

	local root = gui:WaitForChild("Root") :: Frame
	local label = root:WaitForChild("Label") :: TextLabel

	-- Top-left under safe area; avoids center DrivingHUD speed readout (POLA-246).
	local function layoutRoot()
		if not player.Parent then
			return
		end
		local insetLeft, insetTop = HudSafeArea.getManualInsetForScreenGui(gui)
		local vw = HudSafeArea.getViewportWidth()
		local margin = HudLayoutConfig.edgeMarginPx
		local maxW = if HudSafeArea.isCompactWidth(HudLayoutConfig.compactViewportWidth) then HudLayoutConfig.friendBonusMaxWidthCompactPx else HudLayoutConfig.friendBonusMaxWidthPx
		local sidePad = insetLeft + margin
		local usableW = math.max(120, vw - sidePad - margin)
		local w = math.min(maxW, usableW)
		root.Position = UDim2.new(0, sidePad, 0, insetTop + HudLayoutConfig.friendBonusBelowInsetPx)
		root.Size = UDim2.new(0, w, 0, math.max(HudLayoutConfig.minTouchPx, 36))
	end

	layoutRoot()
	local disconnectLayout = HudSafeArea.onLayoutChanged(layoutRoot)

	local function apply(payload: any)
		if not player.Parent then
			return
		end
		if type(payload) ~= "table" then
			return
		end
		local active = payload.active == true
		root.Visible = active
		if not active then
			return
		end
		local pct = if type(payload.percentLabel) == "string" then payload.percentLabel else "+10%"
		label.Text = MicrocopyConfig.FriendBonusHudLabelFormat:gsub("{PCT}", pct)
	end

	local friendConn = Remotes.getEvent("FriendBonusUpdate").OnClientEvent:Connect(apply)

	Players.PlayerRemoving:Connect(function(leaving)
		if leaving ~= player then
			return
		end
		disconnectLayout()
		friendConn:Disconnect()
	end)

	gui.Enabled = true
	root.Visible = false
end

return FriendBonusHUD
