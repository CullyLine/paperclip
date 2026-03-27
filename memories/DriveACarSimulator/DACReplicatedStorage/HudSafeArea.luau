--!strict
--[[
	Helpers for GuiInsets + viewport width (mobile notches, narrow phones).

	GuiService:GetGuiInset() returns two Vector2 values: insets from the top-left
	and from the bottom-right of the screen (see Roblox GuiService API). Use
	getRawInsets / getManualInsetsForScreenGui for full LTRB padding when
	ScreenGui.IgnoreGuiInset is true.
]]

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local HudSafeArea = {}

--[[
	Raw device safe-area insets in pixels: left, top, right, bottom.
	Falls back to (inset.X, inset.Y, 0, 0) if the engine returns only one Vector2.
]]
function HudSafeArea.getRawInsets(): (number, number, number, number)
	local topLeft, bottomRight = GuiService:GetGuiInset()
	if bottomRight == nil then
		return topLeft.X, topLeft.Y, 0, 0
	end
	return topLeft.X, topLeft.Y, bottomRight.X, bottomRight.Y
end

function HudSafeArea.getTopLeft(): (number, number)
	local left, top, _, _ = HudSafeArea.getRawInsets()
	return left, top
end

function HudSafeArea.getViewportWidth(): number
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.ViewportSize.X
	end
	return 800
end

--[[
	When IgnoreGuiInset is false, Roblox lays out in the safe area already — return 0,0.
	When true, add manual top-left inset in offset pixels.
]]
function HudSafeArea.getManualInsetForScreenGui(screenGui: ScreenGui?): (number, number)
	if screenGui and screenGui.IgnoreGuiInset then
		return HudSafeArea.getTopLeft()
	end
	return 0, 0
end

--[[
	Full LTRB insets when the host ScreenGui uses IgnoreGuiInset (manual layout);
	otherwise Roblox already lays out in the safe rect — return zeros.
]]
function HudSafeArea.getManualInsetsForScreenGui(screenGui: ScreenGui?): (number, number, number, number)
	if screenGui and screenGui.IgnoreGuiInset then
		return HudSafeArea.getRawInsets()
	end
	return 0, 0, 0, 0
end

function HudSafeArea.isCompactWidth(threshold: number?): boolean
	local t = threshold or 520
	return HudSafeArea.getViewportWidth() <= t
end

--[[
	Horizontal space inside the full screen after subtracting left/right GuiInsets
	and symmetric edge margins (same convention as HUD / Panels UIPadding).
]]
function HudSafeArea.getContentWidthAfterScreenInsets(screenGui: ScreenGui?, edgeMarginPx: number?): number
	local vw = HudSafeArea.getViewportWidth()
	local l, _, r, _ = HudSafeArea.getManualInsetsForScreenGui(screenGui)
	local em = edgeMarginPx or 0
	return math.max(0, vw - l - r - 2 * em)
end

function HudSafeArea.onLayoutChanged(callback: () -> ())
	callback()
	local connGui: RBXScriptConnection? = nil
	pcall(function()
		connGui = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(callback)
	end)
	local connVp: RBXScriptConnection? = nil
	local function attachViewportListener()
		if connVp then
			connVp:Disconnect()
			connVp = nil
		end
		local cam = Workspace.CurrentCamera
		if cam and cam.Parent then
			connVp = cam:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
		end
	end
	attachViewportListener()
	local connCam = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		attachViewportListener()
		callback()
	end)
	return function()
		if connGui then connGui:Disconnect() end
		connCam:Disconnect()
		if connVp then
			connVp:Disconnect()
		end
	end
end

return HudSafeArea
