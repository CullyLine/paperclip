--!strict
--[[
	Phase 4 (POLA-351): ~44px minimum touch targets + visible gamepad / GUI selection focus rings.
	Uses HudLayoutConfig.minTouchPx (Apple HIG–style minimum). Focus ring uses AGENTS.md accent colors.
]]

local GuiService = game:GetService("GuiService")

local HudLayoutConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))

local MenuInputAccessibility = {}

-- Positive / focus accent from AGENTS.md (emerald); charcoal used for subtle rings.
MenuInputAccessibility.focusRingColor = Color3.fromRGB(46, 204, 113) -- #2ECC71
MenuInputAccessibility.focusRingColorNeutral = Color3.fromRGB(42, 42, 64) -- #2A2A40

function MenuInputAccessibility.getMinTouchPx(): number
	return HudLayoutConfig.minTouchPx
end

function MenuInputAccessibility.ensureMinTouchConstraint(gui: GuiObject, minPx: number?)
	local m = minPx or HudLayoutConfig.minTouchPx
	local c = gui:FindFirstChild("_DACMinTouch")
	if c and c:IsA("UISizeConstraint") then
		c.MinSize = Vector2.new(m, m)
		return
	end
	local cons = Instance.new("UISizeConstraint")
	cons.Name = "_DACMinTouch"
	cons.MinSize = Vector2.new(m, m)
	cons.Parent = gui
end

local function selectedMatches(target: GuiObject, sel: GuiObject?): boolean
	if sel == nil then
		return false
	end
	return sel == target or sel:IsDescendantOf(target)
end

--[[
	Adds a dedicated focus ring stroke; keeps existing strokes (e.g. rarity) unchanged.
	Call once per navigable GuiObject. Safe for dynamic instances (Destroying disconnects).
]]
function MenuInputAccessibility.wireSelectableFocusRing(target: GuiObject, ringColor: Color3?)
	if not target:IsA("GuiObject") then
		return
	end
	if target:GetAttribute("DACFocusRingWired") == true then
		return
	end
	target:SetAttribute("DACFocusRingWired", true)
	target.Selectable = true

	local color = ringColor or MenuInputAccessibility.focusRingColor
	local stroke = target:FindFirstChild("_DACFocusRing")
	if not stroke or not stroke:IsA("UIStroke") then
		stroke = Instance.new("UIStroke")
		stroke.Name = "_DACFocusRing"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = target
	end
	stroke.Color = color
	stroke.Thickness = 0
	stroke.Transparency = 1

	local function sync()
		local sel = GuiService.SelectedObject
		local on = selectedMatches(target, sel)
		stroke.Thickness = if on then 3 else 0
		stroke.Transparency = if on then 0.08 else 1
	end

	sync()
	local connSel = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(sync)
	local connVis = target:GetPropertyChangedSignal("Visible"):Connect(sync)
	target.Destroying:Connect(function()
		if connSel.Connected then
			connSel:Disconnect()
		end
		if connVis.Connected then
			connVis:Disconnect()
		end
	end)
end

function MenuInputAccessibility.applyPrimaryNavDefaults(gui: GuiObject, minPx: number?, ringColor: Color3?)
	MenuInputAccessibility.ensureMinTouchConstraint(gui, minPx)
	MenuInputAccessibility.wireSelectableFocusRing(gui, ringColor)
end

return MenuInputAccessibility
