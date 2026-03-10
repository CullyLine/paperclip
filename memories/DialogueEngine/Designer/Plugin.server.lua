------------------------------------------------------------------------
-- DialogueDesigner — Roblox Studio Plugin
-- Visual node-graph editor for the DialogueEngine system.
--
-- Install: Place this folder's contents as a Script + ModuleScript
-- hierarchy inside your Plugins folder. See INSTALL.md for details.
------------------------------------------------------------------------
print("[DialogueDesigner] Loading modules...")
local ok1, Theme          = pcall(require, script.Parent.DesignerTheme)
print("[DialogueDesigner] DesignerTheme:", ok1)
local ok2, AppState       = pcall(require, script.Parent.AppState)
print("[DialogueDesigner] AppState:", ok2)
local ok3, Canvas         = pcall(require, script.Parent.Canvas)
print("[DialogueDesigner] Canvas:", ok3, not ok3 and Canvas or "")
local ok4, PropertyPanel  = pcall(require, script.Parent.PropertyPanel)
print("[DialogueDesigner] PropertyPanel:", ok4, not ok4 and PropertyPanel or "")
local ok5, Toolbar        = pcall(require, script.Parent.Toolbar)
print("[DialogueDesigner] Toolbar:", ok5, not ok5 and Toolbar or "")

if not (ok1 and ok2 and ok3 and ok4 and ok5) then
	warn("[DialogueDesigner] Module load failed — aborting")
	return
end

print("[DialogueDesigner] All modules loaded, building UI...")

------------------------------------------------------------------------
-- Plugin toolbar button
------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("Dialogue Engine")
local toggleBtn = toolbar:CreateButton(
	"DesignerToggle",
	"Open the Dialogue Designer",
	"rbxassetid://6031075938",
	"Dialogue Designer"
)

------------------------------------------------------------------------
-- DockWidget
------------------------------------------------------------------------
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,  -- initially disabled
	false,  -- don't override saved state
	900, 560,  -- default float size
	700, 440   -- minimum size
)

local widget = plugin:CreateDockWidgetPluginGui("DialogueDesigner", widgetInfo)
widget.Title = "Dialogue Designer"
widget.Name  = "DialogueDesigner"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

------------------------------------------------------------------------
-- Root layout container
------------------------------------------------------------------------
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.Position = UDim2.fromOffset(0, 0)
root.AnchorPoint = Vector2.new(0, 0)
root.BackgroundTransparency = 1
root.Parent = widget

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local state = AppState.new()
print("[DialogueDesigner] State created, assembling UI...")

------------------------------------------------------------------------
-- Status bar (bottom strip)
------------------------------------------------------------------------
local function buildStatusBar(parent)
	local T = Theme
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.Size = UDim2.new(1, 0, 0, T.Sizes.StatusHeight)
	bar.Position = UDim2.new(0, 0, 1, -T.Sizes.StatusHeight)
	bar.BackgroundColor3 = T.Colors.StatusBar
	bar.BorderSizePixel = 0
	bar.ZIndex = 10
	bar.Parent = parent

	local lbl = Instance.new("TextLabel", bar)
	lbl.Name = "Label"
	lbl.Size = UDim2.new(1, -12, 1, 0)
	lbl.Position = UDim2.fromOffset(6, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.TextHeader
	lbl.TextSize = T.Sizes.SmallText
	lbl.Font = T.Fonts.Default
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local function refresh()
		local n = state:GetNodeCount()
		local start = state.startNodeId or "(none)"
		lbl.Text = string.format("Tree: %s  |  Nodes: %d  |  Start: %s", state.treeId, n, start)
	end

	state.treeChanged:Connect(refresh)
	state.nodeAdded:Connect(refresh)
	state.nodeRemoved:Connect(refresh)
	state.stateLoaded:Connect(refresh)
	refresh()
end

------------------------------------------------------------------------
-- Assemble the UI
------------------------------------------------------------------------
local toolbarUI    = Toolbar.new(root, state)
print("[DialogueDesigner] Toolbar built")
local canvas       = Canvas.new(root, state)
print("[DialogueDesigner] Canvas built")
local propPanel    = PropertyPanel.new(root, state)
print("[DialogueDesigner] PropertyPanel built")
buildStatusBar(root)
print("[DialogueDesigner] StatusBar built — fully loaded!")

------------------------------------------------------------------------
-- Toggle button
------------------------------------------------------------------------
toggleBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleBtn:SetActive(widget.Enabled)
end)

------------------------------------------------------------------------
-- Cleanup on unload
------------------------------------------------------------------------
plugin.Unloading:Connect(function()
	canvas:Destroy()
	propPanel:Destroy()
	toolbarUI:Destroy()
end)
