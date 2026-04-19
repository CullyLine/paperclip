--[[
	WidgetUI
	Builds the entire DockWidget interface: mode toolbar, tag bar,
	mode-specific panels, and status bar.
]]

local Theme = require(script.Parent.Theme)

local WidgetUI = {}
WidgetUI.__index = WidgetUI

function WidgetUI.new(widget, state, nodeManager, callbacks)
	local self = setmetatable({}, WidgetUI)
	self._widget = widget
	self._state = state
	self._nodeManager = nodeManager
	self._callbacks = callbacks or {}
	self._theme = Theme.get()
	self._modeButtons = {}
	self._tagButtons = {}
	self._modePanel = nil
	self._modePanels = {}
	self._statusLabel = nil
	self._conns = {}
	-- All preset-dropdown rows register a refresh fn here so they all stay
	-- in sync when presets change or paint settings change elsewhere.
	self._presetDropdownRefreshers = {}
	self._materialDropdownRefreshers = {}
	self._colorPreviewRefreshers = {}
	self:_build()
	self:_bindState()
	return self
end

------------------------------------------------------------------------
-- UI Construction
------------------------------------------------------------------------
function WidgetUI:_build()
	local T = self._theme

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = T.Colors.Background
	root.BorderSizePixel = 0
	root.Parent = self._widget
	self._root = root

	self:_buildToolbar(root)
	self:_buildTagBar(root)
	self:_buildModePanel(root)
	self:_buildStatusBar(root)

	self:_showModePanel(self._state.activeMode)
end

------------------------------------------------------------------------
-- Mode Toolbar
------------------------------------------------------------------------
function WidgetUI:_buildToolbar(parent)
	local T = self._theme

	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Size = UDim2.new(1, 0, 0, T.Sizes.ToolbarHeight)
	toolbar.Position = UDim2.fromOffset(0, 0)
	toolbar.BackgroundColor3 = T.Colors.Surface
	toolbar.BorderSizePixel = 0
	toolbar.Parent = parent

	local sep = Instance.new("Frame", toolbar)
	sep.Name = "Sep"
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Position = UDim2.new(0, 0, 1, -1)
	sep.BackgroundColor3 = T.Colors.Border
	sep.BorderSizePixel = 0

	local modes = { "Place", "Draw", "Paint", "Sculpt", "Select", "Delete", "Presets" }
	local count = #modes
	local gap = 3
	local pad = 4

	for i, mode in modes do
		local btn = Instance.new("TextButton")
		btn.Name = "Mode_" .. mode
		btn.Size = UDim2.new(1 / count, -(gap + pad * 2 / count), 0, T.Sizes.ToolbarHeight - 8)
		btn.Position = UDim2.new((i - 1) / count, pad + (i - 1) * gap / (count - 1), 0.5, -(T.Sizes.ToolbarHeight - 8) / 2)
		btn.BackgroundColor3 = T.Colors.ButtonNormal
		btn.TextColor3 = T.Colors.Text
		btn.Text = mode
		btn.FontFace = T.Fonts.Semi
		btn.TextSize = T.Sizes.FontSizeSmall
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Parent = toolbar
		Instance.new("UICorner", btn).CornerRadius = T.Sizes.SmallCorner

		btn.MouseButton1Click:Connect(function()
			self._state:SetMode(mode)
		end)

		self._modeButtons[mode] = btn
	end

	self:_highlightActiveMode(self._state.activeMode)
end

function WidgetUI:_highlightActiveMode(activeMode)
	local T = self._theme
	-- Most modes get the standard accent when active. Delete gets the
	-- negative/red color instead, because being in Delete mode is a
	-- "watch out, clicks destroy things" state and the toolbar should
	-- make that obvious without requiring a glance at the mode panel.
	for mode, btn in self._modeButtons do
		if mode == activeMode then
			btn.BackgroundColor3 = if mode == "Delete" then T.Colors.Negative else T.Colors.Accent
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			btn.BackgroundColor3 = T.Colors.ButtonNormal
			btn.TextColor3 = T.Colors.Text
		end
	end
end

------------------------------------------------------------------------
-- Tag Filter Bar
------------------------------------------------------------------------
function WidgetUI:_buildTagBar(parent)
	local T = self._theme

	local tagBar = Instance.new("Frame")
	tagBar.Name = "TagBar"
	tagBar.Size = UDim2.new(1, 0, 0, T.Sizes.TagBarHeight)
	tagBar.Position = UDim2.new(0, 0, 0, T.Sizes.ToolbarHeight)
	tagBar.BackgroundColor3 = T.Colors.Background
	tagBar.BorderSizePixel = 0
	tagBar.Parent = parent
	self._tagBar = tagBar

	local sep = Instance.new("Frame", tagBar)
	sep.Name = "Sep"
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Position = UDim2.new(0, 0, 1, -1)
	sep.BackgroundColor3 = T.Colors.Border
	sep.BorderSizePixel = 0

	local scroll = Instance.new("ScrollingFrame", tagBar)
	scroll.Name = "TagScroll"
	scroll.Size = UDim2.new(1, -4, 1, -4)
	scroll.Position = UDim2.fromOffset(2, 2)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	self._tagScroll = scroll

	local layout = Instance.new("UIListLayout", scroll)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)

	self:_refreshTagButtons()
end

function WidgetUI:_refreshTagButtons()
	local T = self._theme

	-- Clear old
	for _, btn in self._tagButtons do
		btn:Destroy()
	end
	table.clear(self._tagButtons)

	local scroll = self._tagScroll

	-- "All" button
	local allBtn = self:_createTagPill(scroll, "All", nil)
	allBtn.LayoutOrder = 1
	table.insert(self._tagButtons, allBtn)

	-- Tag pills
	for i, tag in self._state.tags do
		local pill = self:_createTagPill(scroll, tag, tag)
		pill.LayoutOrder = i + 1
		table.insert(self._tagButtons, pill)
	end

	-- "+" button
	local addBtn = Instance.new("TextButton", scroll)
	addBtn.Name = "AddTag"
	addBtn.Size = UDim2.fromOffset(24, 22)
	addBtn.BackgroundColor3 = T.Colors.ButtonNormal
	addBtn.TextColor3 = T.Colors.Accent
	addBtn.Text = "+"
	addBtn.FontFace = T.Fonts.Bold
	addBtn.TextSize = T.Sizes.FontSizeLarge
	addBtn.BorderSizePixel = 0
	addBtn.LayoutOrder = 9999
	addBtn.Parent = scroll
	Instance.new("UICorner", addBtn).CornerRadius = T.Sizes.SmallCorner

	addBtn.MouseButton1Click:Connect(function()
		self:_showTagInput()
	end)
	table.insert(self._tagButtons, addBtn)

	self:_highlightActiveTag()
end

function WidgetUI:_createTagPill(parent, label, tagValue)
	local T = self._theme

	local btn = Instance.new("TextButton")
	btn.Name = "Tag_" .. label
	btn.Size = UDim2.fromOffset(0, 22)
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.BackgroundColor3 = T.Colors.ButtonNormal
	btn.TextColor3 = T.Colors.Text
	btn.Text = "  " .. label .. "  "
	btn.FontFace = T.Fonts.Semi
	btn.TextSize = T.Sizes.FontSizeSmall
	btn.BorderSizePixel = 0
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)

	btn.MouseButton1Click:Connect(function()
		self._state:SetTagFilter(tagValue)
		self._nodeManager:ApplyTagFilter()
	end)

	btn:SetAttribute("TagValue", tagValue or "")
	return btn
end

function WidgetUI:_highlightActiveTag()
	local T = self._theme
	local active = self._state.activeTag

	for _, btn in self._tagButtons do
		if not btn:IsA("TextButton") then continue end
		local tagVal = btn:GetAttribute("TagValue")
		if tagVal == "" then tagVal = nil end

		if tagVal == active then
			btn.BackgroundColor3 = T.Colors.Accent
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			btn.BackgroundColor3 = T.Colors.ButtonNormal
			btn.TextColor3 = T.Colors.Text
		end
	end
end

function WidgetUI:_showTagInput()
	local T = self._theme

	if self._tagBar:FindFirstChild("TagInput") then return end

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "TagInput"
	inputFrame.Size = UDim2.new(1, -8, 0, 24)
	inputFrame.Position = UDim2.fromOffset(4, 2)
	inputFrame.BackgroundColor3 = T.Colors.Surface
	inputFrame.BorderSizePixel = 0
	inputFrame.ZIndex = 10
	inputFrame.Parent = self._tagBar
	Instance.new("UICorner", inputFrame).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", inputFrame).Color = T.Colors.Accent

	local box = Instance.new("TextBox", inputFrame)
	box.Size = UDim2.new(1, -8, 1, 0)
	box.Position = UDim2.fromOffset(4, 0)
	box.BackgroundTransparency = 1
	box.TextColor3 = T.Colors.Text
	box.PlaceholderText = "Tag name..."
	box.PlaceholderColor3 = T.Colors.TextDim
	box.FontFace = T.Fonts.Default
	box.TextSize = T.Sizes.FontSizeSmall
	box.ClearTextOnFocus = true
	box.ZIndex = 11
	box.Text = ""

	box.FocusLost:Connect(function(enterPressed)
		local name = box.Text:gsub("%s+", "_"):gsub("[^%w_]", "")
		if enterPressed and #name > 0 then
			self._nodeManager:AddTagToNodes(self._state.selectedNodes, name)
		end
		inputFrame:Destroy()
	end)

	box:CaptureFocus()
end

------------------------------------------------------------------------
-- Mode-specific Panels
------------------------------------------------------------------------
function WidgetUI:_buildModePanel(parent)
	local T = self._theme

	local yOffset = T.Sizes.ToolbarHeight + T.Sizes.TagBarHeight
	local height = -yOffset - T.Sizes.StatusHeight

	local container = Instance.new("ScrollingFrame")
	container.Name = "ModePanel"
	container.Size = UDim2.new(1, 0, 1, height)
	container.Position = UDim2.fromOffset(0, yOffset)
	container.BackgroundColor3 = T.Colors.Background
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 4
	container.ScrollBarImageColor3 = T.Colors.ScrollBar
	container.CanvasSize = UDim2.fromOffset(0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.Parent = parent
	self._modePanel = container

	local padding = Instance.new("UIPadding", container)
	padding.PaddingTop = UDim.new(0, T.Sizes.Padding)
	padding.PaddingBottom = UDim.new(0, T.Sizes.Padding)
	padding.PaddingLeft = UDim.new(0, T.Sizes.Padding)
	padding.PaddingRight = UDim.new(0, T.Sizes.Padding)

	local layout = Instance.new("UIListLayout", container)
	layout.Padding = UDim.new(0, T.Sizes.Padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	self._modePanels["Place"] = self:_buildPlacePanel(container)
	self._modePanels["Draw"] = self:_buildDrawPanel(container)
	self._modePanels["Paint"] = self:_buildPaintPanel(container)
	self._modePanels["Sculpt"] = self:_buildSculptPanel(container)
	self._modePanels["Select"] = self:_buildSelectPanel(container)
	self._modePanels["Delete"] = self:_buildDeletePanel(container)
	self._modePanels["Presets"] = self:_buildPresetsPanel(container)
end

function WidgetUI:_showModePanel(mode)
	for name, frame in self._modePanels do
		frame.Visible = (name == mode)
	end
end

------------------------------------------------------------------------
-- Panel builders
------------------------------------------------------------------------
function WidgetUI:_buildPlacePanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "PlacePanel", 1)

	self:_addLabel(frame, "PlaceTitle", "Place Nodes", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "PlaceHelp", "Click to place. Shift+Click to remove.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	self:_addSliderRow(frame, "GridSize", "Grid Size", 1, 32, self._state.settings.gridSize, 3, function(val)
		self._state:SetSetting("gridSize", math.round(val))
	end)

	self:_addToggleRow(frame, "SnapToggle", "Snap Enabled", self._state.settings.snapEnabled, 4, function(val)
		self._state:SetSetting("snapEnabled", val)
	end)

	self:_addSliderRow(frame, "NodeSize", "Node Size", 0.5, 5, self._state.settings.nodeSize, 5, function(val)
		self._state:SetSetting("nodeSize", math.round(val * 10) / 10)
	end)

	-- ----------------------------------------------------------------
	-- Work Plane section
	--
	-- Layout:
	--   "Show Work Plane"   — master toggle. When OFF, every other row
	--                         in this section is greyed out.
	--   "Lock Work Plane"   — pins Y at the current value (or whatever's
	--                         in workPlaneFixedY). When ON, the offset
	--                         slider becomes meaningless and gets disabled.
	--   "Y Position"        — live readout + manual entry. Typing here
	--                         auto-locks at the typed value.
	--   "Height Below Cam"  — only used when unlocked.
	-- ----------------------------------------------------------------
	self:_addLabel(frame, "WPHeader", "Work Plane", T.Fonts.Bold, T.Sizes.FontSizeNormal, 10)

	local showCtrl = self:_addToggleRow(frame, "WorkPlaneToggle", "Show Work Plane",
		self._state.settings.workPlaneEnabled, 11, function(val)
			self._state:SetSetting("workPlaneEnabled", val)
		end)

	local lockCtrl = self:_addToggleRow(frame, "WorkPlaneLock", "Lock Work Plane",
		self._state.settings.workPlaneLocked, 12, function(val)
			if val then
				-- Capture the plane's current Y at the moment of locking so
				-- it stays where the user can see it (no jump).
				local currentY = self._state.workPlaneCurrentY or 0
				self._state:SetSetting("workPlaneFixedY", currentY)
			end
			self._state:SetSetting("workPlaneLocked", val)
		end)

	local yCtrl = self:_addTextInputRow(frame, "WorkPlaneY", "Y Position",
		string.format("%.1f", self._state.workPlaneCurrentY or 0),
		13,
		function(raw) -- validate
			return tonumber(raw)
		end,
		function(val) -- onCommit
			self._state:SetSetting("workPlaneFixedY", val)
			-- Typing a Y value implies "I want the plane HERE" — auto-lock.
			self._state:SetSetting("workPlaneLocked", true)
		end)

	local offsetCtrl = self:_addSliderRow(frame, "WPYOffset", "Height Below Cam",
		5, 100, self._state.settings.workPlaneYOffset, 14, function(val)
			self._state:SetSetting("workPlaneYOffset", math.round(val))
		end)

	-- Cascade-disable: dependent rows follow the master toggle, and the
	-- offset slider additionally disables when locked (it doesn't do
	-- anything in locked mode).
	local function refreshWorkPlaneRows()
		local on = self._state.settings.workPlaneEnabled
		local locked = self._state.settings.workPlaneLocked
		lockCtrl:SetEnabled(on)
		yCtrl:SetEnabled(on)
		offsetCtrl:SetEnabled(on and not locked)
	end
	refreshWorkPlaneRows()
	self._refreshWorkPlaneRows = refreshWorkPlaneRows

	-- Live-update the Y textbox as the plane moves under the camera, and
	-- keep the lock toggle visual in sync if it changes via the textbox
	-- auto-lock path.
	self._workPlaneCtrls = {
		showCtrl = showCtrl,
		lockCtrl = lockCtrl,
		yCtrl = yCtrl,
		offsetCtrl = offsetCtrl,
	}

	return frame
end

function WidgetUI:_buildDrawPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "DrawPanel", 2)

	self:_addLabel(frame, "DrawTitle", "Draw Triangles", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "DrawHelp", "Click 3 nodes to form a triangle.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	local statusLabel = self:_addLabel(frame, "DrawStatus", "Selected: 0/3 nodes", T.Fonts.Semi, T.Sizes.FontSizeNormal, 3)
	self._drawStatusLabel = statusLabel

	-- Material preset selector — picks the color+material for new triangles.
	self:_addLabel(frame, "DrawMatLabel", "New triangle material:", T.Fonts.Default, T.Sizes.FontSizeSmall, 4)
	self:_addPresetDropdown(frame, 5)

	-- Auto-Triangulate button (not a hotkey!)
	local autoBtn = Instance.new("TextButton", frame)
	autoBtn.Name = "AutoTriBtn"
	autoBtn.Size = UDim2.new(1, 0, 0, 32)
	autoBtn.BackgroundColor3 = T.Colors.Accent
	autoBtn.TextColor3 = Color3.new(1, 1, 1)
	autoBtn.Text = "Auto-Triangulate All Visible Nodes"
	autoBtn.FontFace = T.Fonts.Bold
	autoBtn.TextSize = T.Sizes.FontSizeNormal
	autoBtn.BorderSizePixel = 0
	autoBtn.LayoutOrder = 6
	autoBtn.Parent = frame
	Instance.new("UICorner", autoBtn).CornerRadius = T.Sizes.SmallCorner

	autoBtn.MouseButton1Click:Connect(function()
		if self._callbacks.onAutoTriangulate then
			self._callbacks.onAutoTriangulate()
		end
	end)

	-- Alpha-shape filter strength for Auto-Triangulate. Lower = stricter,
	-- follows non-convex shapes (curves, rings) more tightly. Higher = closer
	-- to raw Delaunay (fills the convex hull). Explained inline so users
	-- don't have to guess what "shape tightness" means.
	self:_addLabel(frame, "AutoTriShapeHelp",
		"Shape tightness controls how aggressively bridge triangles across empty space (e.g. inside a curve) get culled. Lower = tighter shape; higher = fills more.",
		T.Fonts.Default, T.Sizes.FontSizeSmall, 7)
	self:_addSliderRow(frame, "AutoTriShape", "Shape Tightness",
		1.5, 8, self._state.settings.autoTriMaxEdgeFactor, 7,
		function(val)
			self._state:SetSetting("autoTriMaxEdgeFactor", math.round(val * 10) / 10)
		end)

	-- (Removed in 0.8.1) The "Clear Selection" button used to live here for
	-- the in-progress 3-vertex picker. It's redundant — clicking the same
	-- node again toggles it off, and Escape now aborts the whole pick.

	-- ----------------------------------------------------------------
	-- Sub-Divide section
	-- ----------------------------------------------------------------
	self:_addLabel(frame, "SubDivHeader", "Sub-Divide", T.Fonts.Bold, T.Sizes.FontSizeNormal, 8)
	self:_addLabel(frame, "SubDivHelp",
		"Toggle on, hover a triangle to preview, click to split it into 4 smaller triangles. Neighboring triangles are re-fanned to share the new edge nodes.",
		T.Fonts.Default, T.Sizes.FontSizeSmall, 9)

	local subBtn = Instance.new("TextButton", frame)
	subBtn.Name = "SubDivToggleBtn"
	subBtn.Size = UDim2.new(1, 0, 0, 30)
	subBtn.BackgroundColor3 = T.Colors.ButtonNormal
	subBtn.TextColor3 = T.Colors.Text
	subBtn.Text = "Sub-Divide Mode: OFF"
	subBtn.FontFace = T.Fonts.Bold
	subBtn.TextSize = T.Sizes.FontSizeNormal
	subBtn.BorderSizePixel = 0
	subBtn.LayoutOrder = 10
	Instance.new("UICorner", subBtn).CornerRadius = T.Sizes.SmallCorner
	self._subDivToggleBtn = subBtn

	subBtn.MouseButton1Click:Connect(function()
		local target: any = if self._state.drawSubMode == "SubDivide" then "Triangulate" else "SubDivide"
		self._state:SetDrawSubMode(target)
	end)

	return frame
end

function WidgetUI:_refreshSubDivToggle()
	if not self._subDivToggleBtn then return end
	local T = self._theme
	if self._state.drawSubMode == "SubDivide" then
		self._subDivToggleBtn.BackgroundColor3 = T.Colors.Accent
		self._subDivToggleBtn.TextColor3 = Color3.new(1, 1, 1)
		self._subDivToggleBtn.Text = "Sub-Divide Mode: ON"
	else
		self._subDivToggleBtn.BackgroundColor3 = T.Colors.ButtonNormal
		self._subDivToggleBtn.TextColor3 = T.Colors.Text
		self._subDivToggleBtn.Text = "Sub-Divide Mode: OFF"
	end
end

function WidgetUI:_buildPaintPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "PaintPanel", 3)

	self:_addLabel(frame, "PaintTitle", "Paint Triangles", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "PaintHelp", "Click a triangle to apply color & material.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	-- Material preset selector (sets paintColor + paintMaterial in one click).
	self:_addPresetDropdown(frame, 3)

	self:_addLabel(frame, "CustomLabel", "Or customize:", T.Fonts.Default, T.Sizes.FontSizeSmall, 4)

	-- Color preview + picker trigger
	local colorRow = Instance.new("Frame", frame)
	colorRow.Name = "ColorRow"
	colorRow.Size = UDim2.new(1, 0, 0, 28)
	colorRow.BackgroundTransparency = 1
	colorRow.LayoutOrder = 5
	colorRow.Parent = frame

	local colorLabel = Instance.new("TextLabel", colorRow)
	colorLabel.Size = UDim2.new(0.5, 0, 1, 0)
	colorLabel.BackgroundTransparency = 1
	colorLabel.TextColor3 = T.Colors.Text
	colorLabel.Text = "Color"
	colorLabel.FontFace = T.Fonts.Semi
	colorLabel.TextSize = T.Sizes.FontSizeNormal
	colorLabel.TextXAlignment = Enum.TextXAlignment.Left

	local colorPreview = Instance.new("TextButton", colorRow)
	colorPreview.Name = "ColorPreview"
	colorPreview.Size = UDim2.new(0.5, -4, 0, 24)
	colorPreview.Position = UDim2.new(0.5, 4, 0, 2)
	colorPreview.BackgroundColor3 = self._state.settings.paintColor
	colorPreview.Text = ""
	colorPreview.BorderSizePixel = 0
	Instance.new("UICorner", colorPreview).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", colorPreview).Color = T.Colors.Border
	self._colorPreview = colorPreview

	-- Register so settingsChanged binding keeps it in sync (e.g. when a
	-- preset is picked elsewhere).
	table.insert(self._colorPreviewRefreshers, function()
		colorPreview.BackgroundColor3 = self._state.settings.paintColor
	end)

	colorPreview.MouseButton1Click:Connect(function()
		self:_showColorGrid(frame)
	end)

	-- Material dropdown
	self:_addMaterialDropdown(frame, 6)

	return frame
end

function WidgetUI:_buildSculptPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "SculptPanel", 4)

	self:_addLabel(frame, "SculptTitle", "Sculpt Terrain", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "SculptHelp", "Click and drag to sculpt node heights.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	-- Tool selector
	local toolRow = Instance.new("Frame", frame)
	toolRow.Name = "ToolRow"
	toolRow.Size = UDim2.new(1, 0, 0, 28)
	toolRow.BackgroundTransparency = 1
	toolRow.LayoutOrder = 3

	local toolLayout = Instance.new("UIListLayout", toolRow)
	toolLayout.FillDirection = Enum.FillDirection.Horizontal
	toolLayout.Padding = UDim.new(0, 3)

	local sculptTools = { "Raise", "Lower", "Smooth", "Flatten" }
	local sculptBtns = {}
	for i, tool in sculptTools do
		local btn = Instance.new("TextButton", toolRow)
		btn.Name = "Sculpt_" .. tool
		btn.Size = UDim2.new(0.25, -3, 1, 0)
		btn.BackgroundColor3 = if tool == self._state.settings.sculptTool then T.Colors.Accent else T.Colors.ButtonNormal
		btn.TextColor3 = if tool == self._state.settings.sculptTool then Color3.new(1, 1, 1) else T.Colors.Text
		btn.Text = tool
		btn.FontFace = T.Fonts.Semi
		btn.TextSize = T.Sizes.FontSizeSmall
		btn.BorderSizePixel = 0
		Instance.new("UICorner", btn).CornerRadius = T.Sizes.SmallCorner

		btn.MouseButton1Click:Connect(function()
			self._state:SetSetting("sculptTool", tool)
			for _, b in sculptBtns do
				b.BackgroundColor3 = T.Colors.ButtonNormal
				b.TextColor3 = T.Colors.Text
			end
			btn.BackgroundColor3 = T.Colors.Accent
			btn.TextColor3 = Color3.new(1, 1, 1)
		end)

		table.insert(sculptBtns, btn)
	end

	self:_addSliderRow(frame, "BrushRadius", "Radius", 2, 100, self._state.settings.brushRadius, 4, function(val)
		self._state:SetSetting("brushRadius", math.round(val))
	end)

	self:_addSliderRow(frame, "BrushStrength", "Strength", 0.1, 10, self._state.settings.brushStrength, 5, function(val)
		self._state:SetSetting("brushStrength", math.round(val * 10) / 10)
	end)

	-- Falloff selector
	local falloffRow = Instance.new("Frame", frame)
	falloffRow.Name = "FalloffRow"
	falloffRow.Size = UDim2.new(1, 0, 0, 28)
	falloffRow.BackgroundTransparency = 1
	falloffRow.LayoutOrder = 6

	self:_addLabel(falloffRow, "FalloffLabel", "Falloff", T.Fonts.Semi, T.Sizes.FontSizeNormal, 0)

	local falloffs = { "Smooth", "Linear", "Flat" }
	local falloffBtns = {}
	local fbtnContainer = Instance.new("Frame", falloffRow)
	fbtnContainer.Size = UDim2.new(0.6, 0, 1, 0)
	fbtnContainer.Position = UDim2.new(0.4, 0, 0, 0)
	fbtnContainer.BackgroundTransparency = 1

	local fbtnLayout = Instance.new("UIListLayout", fbtnContainer)
	fbtnLayout.FillDirection = Enum.FillDirection.Horizontal
	fbtnLayout.Padding = UDim.new(0, 3)

	for _, fo in falloffs do
		local btn = Instance.new("TextButton", fbtnContainer)
		btn.Size = UDim2.new(1 / 3, -2, 1, 0)
		btn.BackgroundColor3 = if fo == self._state.settings.brushFalloff then T.Colors.Accent else T.Colors.ButtonNormal
		btn.TextColor3 = if fo == self._state.settings.brushFalloff then Color3.new(1, 1, 1) else T.Colors.Text
		btn.Text = fo
		btn.FontFace = T.Fonts.Semi
		btn.TextSize = T.Sizes.FontSizeSmall
		btn.BorderSizePixel = 0
		Instance.new("UICorner", btn).CornerRadius = T.Sizes.SmallCorner

		btn.MouseButton1Click:Connect(function()
			self._state:SetSetting("brushFalloff", fo)
			for _, b in falloffBtns do
				b.BackgroundColor3 = T.Colors.ButtonNormal
				b.TextColor3 = T.Colors.Text
			end
			btn.BackgroundColor3 = T.Colors.Accent
			btn.TextColor3 = Color3.new(1, 1, 1)
		end)

		table.insert(falloffBtns, btn)
	end

	return frame
end

function WidgetUI:_buildDeletePanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "DeletePanel", 6)

	self:_addLabel(frame, "DeleteTitle", "Delete Triangles", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "DeleteHelp",
		"Hover a triangle to highlight it red. Click to delete. " ..
		"Click and drag to delete multiple in one stroke. Each stroke is one undo step.",
		T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	-- Live counter for the current drag stroke. Useful feedback during a
	-- sweep so the user knows how many they've nuked. Resets on Button1Up.
	local counter = self:_addLabel(frame, "DeleteCounter", "", T.Fonts.Semi, T.Sizes.FontSizeNormal, 3)
	counter.TextColor3 = T.Colors.Negative
	self._deleteCounterLabel = counter

	-- "Delete Nodes" option. Off by default. When on:
	--   * Delete-mode hover prefers nodes (they're smaller/more precise),
	--     falling back to triangles if nothing's under the cursor — same
	--     priority logic Select mode uses.
	--   * Clicking a node deletes the node directly (cascading any
	--     connected triangles, since DeleteNode already does that).
	--   * Deleting a triangle additionally cleans up any of its 3 vertex
	--     nodes that are no longer used by any other triangle ("orphan
	--     nodes"), so tear-down doesn't leave stray dangling nodes.
	self:_addToggleRow(frame, "DeleteNodesToggle", "Delete Nodes",
		self._state.settings.deleteNodesEnabled, 4, function(val)
			self._state:SetSetting("deleteNodesEnabled", val)
		end)

	self:_addLabel(frame, "DeleteNodesHelp",
		"When on: clicks also delete nodes, and deleting a triangle " ..
		"also removes any of its corner nodes left orphan.",
		T.Fonts.Default, T.Sizes.FontSizeSmall, 5)

	-- Caution banner so the destructive intent of this mode is unmistakable.
	local warn = Instance.new("Frame", frame)
	warn.Name = "CautionBanner"
	warn.Size = UDim2.new(1, 0, 0, 36)
	warn.BackgroundColor3 = T.Colors.Negative
	warn.BackgroundTransparency = 0.85
	warn.BorderSizePixel = 0
	warn.LayoutOrder = 6
	Instance.new("UICorner", warn).CornerRadius = T.Sizes.SmallCorner
	local stroke = Instance.new("UIStroke", warn)
	stroke.Color = T.Colors.Negative
	stroke.Transparency = 0.4

	local warnLabel = Instance.new("TextLabel", warn)
	warnLabel.Size = UDim2.new(1, -16, 1, 0)
	warnLabel.Position = UDim2.fromOffset(8, 0)
	warnLabel.BackgroundTransparency = 1
	warnLabel.TextColor3 = T.Colors.Text
	warnLabel.Text = "Destructive mode — clicks delete what they hit."
	warnLabel.FontFace = T.Fonts.Semi
	warnLabel.TextSize = T.Sizes.FontSizeSmall
	warnLabel.TextXAlignment = Enum.TextXAlignment.Left
	warnLabel.TextWrapped = true

	return frame
end

function WidgetUI:_buildSelectPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "SelectPanel", 5)

	self:_addLabel(frame, "SelectTitle", "Select & Inspect", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "SelectHelp", "Click nodes/triangles. Ctrl+click for multi.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	local selInfo = self:_addLabel(frame, "SelInfo", "Nothing selected", T.Fonts.Default, T.Sizes.FontSizeNormal, 3)
	self._selInfoLabel = selInfo

	-- Tag assignment for selected nodes
	local tagLabel = self:_addLabel(frame, "TagLabel", "Assign tag to selected:", T.Fonts.Semi, T.Sizes.FontSizeSmall, 4)

	local tagBox = Instance.new("TextBox", frame)
	tagBox.Name = "TagAssignBox"
	tagBox.Size = UDim2.new(1, 0, 0, 26)
	tagBox.BackgroundColor3 = T.Colors.Surface
	tagBox.TextColor3 = T.Colors.Text
	tagBox.PlaceholderText = "tag_name"
	tagBox.PlaceholderColor3 = T.Colors.TextDim
	tagBox.FontFace = T.Fonts.Default
	tagBox.TextSize = T.Sizes.FontSizeSmall
	tagBox.BorderSizePixel = 0
	tagBox.LayoutOrder = 5
	tagBox.Text = ""
	Instance.new("UICorner", tagBox).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", tagBox).Color = T.Colors.Border

	local assignBtn = Instance.new("TextButton", frame)
	assignBtn.Name = "AssignTagBtn"
	assignBtn.Size = UDim2.new(0.48, 0, 0, 26)
	assignBtn.BackgroundColor3 = T.Colors.Positive
	assignBtn.TextColor3 = Color3.new(1, 1, 1)
	assignBtn.Text = "Add Tag"
	assignBtn.FontFace = T.Fonts.Bold
	assignBtn.TextSize = T.Sizes.FontSizeSmall
	assignBtn.BorderSizePixel = 0
	assignBtn.LayoutOrder = 6
	Instance.new("UICorner", assignBtn).CornerRadius = T.Sizes.SmallCorner

	assignBtn.MouseButton1Click:Connect(function()
		local name = tagBox.Text:gsub("%s+", "_"):gsub("[^%w_]", "")
		if #name == 0 then return end
		self._nodeManager:AddTagToNodes(self._state.selectedNodes, name)
		tagBox.Text = ""
	end)

	local removeBtn = Instance.new("TextButton", frame)
	removeBtn.Name = "RemoveTagBtn"
	removeBtn.Size = UDim2.new(0.48, 0, 0, 26)
	removeBtn.BackgroundColor3 = T.Colors.Negative
	removeBtn.TextColor3 = Color3.new(1, 1, 1)
	removeBtn.Text = "Remove Tag"
	removeBtn.FontFace = T.Fonts.Bold
	removeBtn.TextSize = T.Sizes.FontSizeSmall
	removeBtn.BorderSizePixel = 0
	removeBtn.LayoutOrder = 7
	Instance.new("UICorner", removeBtn).CornerRadius = T.Sizes.SmallCorner

	removeBtn.MouseButton1Click:Connect(function()
		local name = tagBox.Text:gsub("%s+", "_"):gsub("[^%w_]", "")
		if #name == 0 then return end
		self._nodeManager:RemoveTagFromNodes(self._state.selectedNodes, name)
		tagBox.Text = ""
	end)

	-- Delete selected button
	local deleteBtn = Instance.new("TextButton", frame)
	deleteBtn.Name = "DeleteBtn"
	deleteBtn.Size = UDim2.new(1, 0, 0, 30)
	deleteBtn.BackgroundColor3 = T.Colors.Negative
	deleteBtn.TextColor3 = Color3.new(1, 1, 1)
	deleteBtn.Text = "Delete Selected"
	deleteBtn.FontFace = T.Fonts.Bold
	deleteBtn.TextSize = T.Sizes.FontSizeNormal
	deleteBtn.BorderSizePixel = 0
	deleteBtn.LayoutOrder = 10
	Instance.new("UICorner", deleteBtn).CornerRadius = T.Sizes.SmallCorner

	deleteBtn.MouseButton1Click:Connect(function()
		if self._callbacks.onDeleteSelected then
			self._callbacks.onDeleteSelected()
		end
	end)

	return frame
end

------------------------------------------------------------------------
-- Palette + material catalogs (used by both paint settings and presets)
------------------------------------------------------------------------
local PALETTE = {
	Color3.fromRGB(74, 124, 63),   -- grass green
	Color3.fromRGB(34, 85, 28),    -- dark green
	Color3.fromRGB(120, 160, 90),  -- light green
	Color3.fromRGB(85, 65, 40),    -- dirt brown
	Color3.fromRGB(140, 110, 70),  -- sand
	Color3.fromRGB(200, 180, 140), -- light sand
	Color3.fromRGB(100, 100, 100), -- gray rock
	Color3.fromRGB(60, 60, 65),    -- dark rock
	Color3.fromRGB(160, 160, 160), -- light rock
	Color3.fromRGB(50, 90, 140),   -- water blue
	Color3.fromRGB(70, 130, 180),  -- light blue
	Color3.fromRGB(200, 200, 210), -- snow
	Color3.fromRGB(240, 230, 200), -- pale
	Color3.fromRGB(180, 60, 40),   -- red clay
	Color3.fromRGB(60, 40, 30),    -- dark earth
	Color3.fromRGB(150, 130, 100), -- limestone
	Color3.fromRGB(80, 70, 60),    -- slate
	Color3.fromRGB(110, 90, 70),   -- mud
	Color3.fromRGB(40, 60, 40),    -- deep forest
	Color3.fromRGB(170, 140, 90),  -- mesa
}

local MATERIALS = {
	Enum.Material.Grass, Enum.Material.Sand, Enum.Material.Rock,
	Enum.Material.Ground, Enum.Material.Mud, Enum.Material.Slate,
	Enum.Material.Concrete, Enum.Material.Brick, Enum.Material.Cobblestone,
	Enum.Material.Snow, Enum.Material.Ice, Enum.Material.Glacier,
	Enum.Material.SmoothPlastic, Enum.Material.Pavement, Enum.Material.Limestone,
	Enum.Material.Basalt, Enum.Material.Asphalt, Enum.Material.Salt,
	Enum.Material.CrackedLava, Enum.Material.LeafyGrass, Enum.Material.Water,
}

------------------------------------------------------------------------
-- Material thumbnail (small ViewportFrame with a wedge inside, used in
-- preset dropdowns and the preset manager).
------------------------------------------------------------------------
function WidgetUI:_buildMaterialThumbnail(parent, color: Color3, material: Enum.Material, sizePx: number): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Thumbnail"
	vf.Size = UDim2.fromOffset(sizePx, sizePx)
	vf.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	vf.BorderSizePixel = 0
	vf.LightDirection = Vector3.new(-0.4, -1, -0.3).Unit
	vf.Ambient = Color3.fromRGB(120, 120, 120)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	Instance.new("UICorner", vf).CornerRadius = UDim.new(0, 3)

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.lookAt(Vector3.new(2.4, 1.8, 2.6), Vector3.new(0, 0.3, 0))
	vf.CurrentCamera = cam
	cam.Parent = vf

	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Size = Vector3.new(2.2, 1.6, 2.2)
	wedge.Color = color
	wedge.Material = material
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = vf

	if parent then vf.Parent = parent end
	return vf
end

------------------------------------------------------------------------
-- Generic color grid: drops a palette grid into `container`. Closes if
-- one already exists (toggle). Calls `callback(color)` on selection.
------------------------------------------------------------------------
function WidgetUI:_showColorGridForCallback(container: Instance, layoutOrder: number, callback)
	local T = self._theme

	if container:FindFirstChild("ColorGrid") then
		container:FindFirstChild("ColorGrid"):Destroy()
		return
	end

	local grid = Instance.new("Frame", container)
	grid.Name = "ColorGrid"
	grid.Size = UDim2.new(1, 0, 0, 120)
	grid.BackgroundColor3 = T.Colors.Surface
	grid.BorderSizePixel = 0
	grid.LayoutOrder = layoutOrder
	grid.ZIndex = 10
	Instance.new("UICorner", grid).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", grid).Color = T.Colors.Border

	local gridLayout = Instance.new("UIGridLayout", grid)
	gridLayout.CellSize = UDim2.fromOffset(20, 20)
	gridLayout.CellPadding = UDim2.fromOffset(2, 2)

	local gridPad = Instance.new("UIPadding", grid)
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingLeft = UDim.new(0, 4)

	for i, color in PALETTE do
		local swatch = Instance.new("TextButton", grid)
		swatch.Name = "Color_" .. i
		swatch.BackgroundColor3 = color
		swatch.Text = ""
		swatch.BorderSizePixel = 0
		swatch.ZIndex = 11
		Instance.new("UICorner", swatch).CornerRadius = T.Sizes.SmallCorner

		swatch.MouseButton1Click:Connect(function()
			callback(color)
			grid:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- Generic material list: drops a scrolling list of materials into
-- `container`. Calls `callback(material)` on selection.
------------------------------------------------------------------------
function WidgetUI:_showMaterialListForCallback(container: Instance, layoutOrder: number, callback)
	local T = self._theme

	if container:FindFirstChild("MaterialList") then
		container:FindFirstChild("MaterialList"):Destroy()
		return
	end

	local list = Instance.new("ScrollingFrame", container)
	list.Name = "MaterialList"
	list.Size = UDim2.new(1, 0, 0, 150)
	list.BackgroundColor3 = T.Colors.Surface
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.LayoutOrder = layoutOrder
	list.ZIndex = 10
	Instance.new("UICorner", list).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", list).Color = T.Colors.Border

	local listLayout = Instance.new("UIListLayout", list)
	listLayout.Padding = UDim.new(0, 1)

	for _, mat in MATERIALS do
		local matBtn = Instance.new("TextButton", list)
		matBtn.Size = UDim2.new(1, 0, 0, 22)
		matBtn.BackgroundColor3 = T.Colors.Surface
		matBtn.TextColor3 = T.Colors.Text
		matBtn.Text = "  " .. mat.Name
		matBtn.FontFace = T.Fonts.Default
		matBtn.TextSize = T.Sizes.FontSizeSmall
		matBtn.TextXAlignment = Enum.TextXAlignment.Left
		matBtn.BorderSizePixel = 0
		matBtn.ZIndex = 11

		matBtn.MouseButton1Click:Connect(function()
			callback(mat)
			list:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- Color Grid (paint-settings shorthand). Used by the Paint panel's
-- color preview button.
------------------------------------------------------------------------
function WidgetUI:_showColorGrid(parent)
	self:_showColorGridForCallback(parent, 999, function(color)
		self._state:SetSetting("paintColor", color)
	end)
end

------------------------------------------------------------------------
-- Material Dropdown (paint-settings shorthand). Tracks itself in
-- _materialDropdownRefreshers so it stays in sync when settings change.
------------------------------------------------------------------------
function WidgetUI:_addMaterialDropdown(parent, layoutOrder)
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = "MaterialRow"
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	local label = Instance.new("TextLabel", row)
	label.Size = UDim2.new(0.35, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = T.Colors.Text
	label.Text = "Material"
	label.FontFace = T.Fonts.Semi
	label.TextSize = T.Sizes.FontSizeNormal
	label.TextXAlignment = Enum.TextXAlignment.Left

	local dropdown = Instance.new("TextButton", row)
	dropdown.Name = "MaterialDropdown"
	dropdown.Size = UDim2.new(0.65, -4, 1, 0)
	dropdown.Position = UDim2.new(0.35, 4, 0, 0)
	dropdown.BackgroundColor3 = T.Colors.Surface
	dropdown.TextColor3 = T.Colors.Text
	dropdown.Text = self._state.settings.paintMaterial.Name
	dropdown.FontFace = T.Fonts.Default
	dropdown.TextSize = T.Sizes.FontSizeSmall
	dropdown.BorderSizePixel = 0
	Instance.new("UICorner", dropdown).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", dropdown).Color = T.Colors.Border
	self._materialDropdown = dropdown

	dropdown.MouseButton1Click:Connect(function()
		self:_showMaterialListForCallback(parent, layoutOrder + 1, function(mat)
			self._state:SetSetting("paintMaterial", mat)
		end)
	end)

	-- Register for the paintMaterial->UI sync.
	table.insert(self._materialDropdownRefreshers, function()
		dropdown.Text = self._state.settings.paintMaterial.Name
	end)
end

------------------------------------------------------------------------
-- Preset dropdown row (used in Paint and Draw panels)
-- Shows the matching preset's thumbnail and name, or "Custom" if the
-- current paint settings don't match any preset. Click opens the list.
------------------------------------------------------------------------
function WidgetUI:_addPresetDropdown(parent, layoutOrder: number)
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = "PresetRow"
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	local label = Instance.new("TextLabel", row)
	label.Size = UDim2.new(0.3, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = T.Colors.Text
	label.Text = "Preset"
	label.FontFace = T.Fonts.Semi
	label.TextSize = T.Sizes.FontSizeNormal
	label.TextXAlignment = Enum.TextXAlignment.Left

	local btn = Instance.new("TextButton", row)
	btn.Name = "PresetDropdown"
	btn.Size = UDim2.new(0.7, -4, 1, -4)
	btn.Position = UDim2.new(0.3, 4, 0, 2)
	btn.BackgroundColor3 = T.Colors.Surface
	btn.Text = ""
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	Instance.new("UICorner", btn).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", btn).Color = T.Colors.Border

	-- Inner layout: thumbnail | name | chevron
	local pad = Instance.new("UIPadding", btn)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 6)

	local thumbHolder = Instance.new("Frame", btn)
	thumbHolder.Name = "ThumbHolder"
	thumbHolder.Size = UDim2.fromOffset(28, 28)
	thumbHolder.Position = UDim2.fromOffset(0, 2)
	thumbHolder.BackgroundTransparency = 1

	local nameLbl = Instance.new("TextLabel", btn)
	nameLbl.Name = "Name"
	nameLbl.Size = UDim2.new(1, -52, 1, 0)
	nameLbl.Position = UDim2.fromOffset(34, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = T.Colors.Text
	nameLbl.FontFace = T.Fonts.Semi
	nameLbl.TextSize = T.Sizes.FontSizeNormal
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = "Custom"

	local chevron = Instance.new("TextLabel", btn)
	chevron.Name = "Chevron"
	chevron.Size = UDim2.fromOffset(14, 28)
	chevron.Position = UDim2.new(1, -16, 0, 2)
	chevron.BackgroundTransparency = 1
	chevron.TextColor3 = T.Colors.TextDim
	chevron.FontFace = T.Fonts.Bold
	chevron.TextSize = T.Sizes.FontSizeSmall
	chevron.Text = "v"

	local function rebuildThumbnail()
		thumbHolder:ClearAllChildren()
		local color = self._state.settings.paintColor
		local mat = self._state.settings.paintMaterial
		self:_buildMaterialThumbnail(thumbHolder, color, mat, 28)
	end

	local function refresh()
		if not row.Parent then return end
		local presets = self._state.materialPresets
		if not presets then
			nameLbl.Text = "Custom"
			rebuildThumbnail()
			return
		end
		local match = presets:FindByAppearance(
			self._state.settings.paintColor,
			self._state.settings.paintMaterial
		)
		nameLbl.Text = if match then match.name else "Custom"
		rebuildThumbnail()
	end

	refresh()

	btn.MouseButton1Click:Connect(function()
		self:_showPresetListForRow(row, layoutOrder + 1)
	end)

	table.insert(self._presetDropdownRefreshers, refresh)
end

------------------------------------------------------------------------
-- Preset list (the dropdown that opens under a preset row)
------------------------------------------------------------------------
function WidgetUI:_showPresetListForRow(row: GuiObject, layoutOrder: number)
	local T = self._theme
	local parent = row.Parent
	if not parent then return end

	if parent:FindFirstChild("PresetList") then
		parent:FindFirstChild("PresetList"):Destroy()
		return
	end

	local presets = self._state.materialPresets
	if not presets then return end

	local list = Instance.new("ScrollingFrame", parent)
	list.Name = "PresetList"
	list.Size = UDim2.new(1, 0, 0, 180)
	list.BackgroundColor3 = T.Colors.Surface
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.LayoutOrder = layoutOrder
	list.ZIndex = 10
	Instance.new("UICorner", list).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", list).Color = T.Colors.Border

	local listLayout = Instance.new("UIListLayout", list)
	listLayout.Padding = UDim.new(0, 2)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local order = 0
	for _, preset in presets:GetAll() do
		order += 1
		local item = Instance.new("TextButton", list)
		item.Name = "Preset_" .. preset.id
		item.Size = UDim2.new(1, 0, 0, 32)
		item.BackgroundColor3 = T.Colors.Surface
		item.Text = ""
		item.BorderSizePixel = 0
		item.LayoutOrder = order
		item.ZIndex = 11
		item.AutoButtonColor = true

		local thumb = self:_buildMaterialThumbnail(item, preset.color, preset.material, 26)
		thumb.Position = UDim2.fromOffset(3, 3)
		thumb.ZIndex = 12

		local nameLbl = Instance.new("TextLabel", item)
		nameLbl.Size = UDim2.new(1, -36, 1, 0)
		nameLbl.Position = UDim2.fromOffset(34, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = T.Colors.Text
		nameLbl.FontFace = T.Fonts.Semi
		nameLbl.TextSize = T.Sizes.FontSizeNormal
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = preset.name
		nameLbl.ZIndex = 12

		item.MouseButton1Click:Connect(function()
			self._state:SetSetting("paintColor", preset.color)
			self._state:SetSetting("paintMaterial", preset.material)
			list:Destroy()
		end)
	end

	-- Footer: jump to the Presets manager tab.
	local sep = Instance.new("Frame", list)
	sep.Name = "Separator"
	sep.Size = UDim2.new(1, -8, 0, 1)
	sep.Position = UDim2.fromOffset(4, 0)
	sep.BackgroundColor3 = T.Colors.Border
	sep.BorderSizePixel = 0
	sep.LayoutOrder = order + 1
	sep.ZIndex = 11

	order += 2
	local manageBtn = Instance.new("TextButton", list)
	manageBtn.Name = "ManageBtn"
	manageBtn.Size = UDim2.new(1, 0, 0, 26)
	manageBtn.BackgroundColor3 = T.Colors.Surface
	manageBtn.TextColor3 = T.Colors.Accent
	manageBtn.Text = "+ Manage Presets"
	manageBtn.FontFace = T.Fonts.Bold
	manageBtn.TextSize = T.Sizes.FontSizeSmall
	manageBtn.BorderSizePixel = 0
	manageBtn.LayoutOrder = order
	manageBtn.ZIndex = 11

	manageBtn.MouseButton1Click:Connect(function()
		list:Destroy()
		self._state:SetMode("Presets")
	end)
end

------------------------------------------------------------------------
-- Presets panel (the 6th tab) — full CRUD UI
------------------------------------------------------------------------
function WidgetUI:_buildPresetsPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "PresetsPanel", 6)

	self:_addLabel(frame, "PresetsTitle", "Material Presets", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "PresetsHelp",
		"Reusable color+material pairs. Pick one in the Draw or Paint panel " ..
		"to instantly set the next triangle's appearance.",
		T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	local addBtn = Instance.new("TextButton", frame)
	addBtn.Name = "AddPresetBtn"
	addBtn.Size = UDim2.new(1, 0, 0, 30)
	addBtn.BackgroundColor3 = T.Colors.Positive
	addBtn.TextColor3 = Color3.new(1, 1, 1)
	addBtn.Text = "+ New Preset"
	addBtn.FontFace = T.Fonts.Bold
	addBtn.TextSize = T.Sizes.FontSizeNormal
	addBtn.BorderSizePixel = 0
	addBtn.LayoutOrder = 3
	Instance.new("UICorner", addBtn).CornerRadius = T.Sizes.SmallCorner

	addBtn.MouseButton1Click:Connect(function()
		local presets = self._state.materialPresets
		if not presets then return end
		local n = #presets:GetAll() + 1
		local newId = presets:Add(
			"Preset " .. n,
			self._state.settings.paintColor,
			self._state.settings.paintMaterial
		)
		-- presets:Add() fires `changed` synchronously *before* returning, so
		-- the manager has already refreshed by the time we get here and the
		-- new row exists in the list. Spotlight it directly: scroll-into-view,
		-- focus its name box, and flash its outline. Otherwise the new row
		-- appears off-screen at the bottom of the list and the click feels
		-- like a no-op.
		self:_spotlightPresetRow(newId)
	end)

	-- Export / Import row
	local transferRow = Instance.new("Frame", frame)
	transferRow.Name = "TransferRow"
	transferRow.Size = UDim2.new(1, 0, 0, 28)
	transferRow.BackgroundTransparency = 1
	transferRow.LayoutOrder = 4

	local transferLayout = Instance.new("UIListLayout", transferRow)
	transferLayout.FillDirection = Enum.FillDirection.Horizontal
	transferLayout.Padding = UDim.new(0, 4)
	transferLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local exportBtn = Instance.new("TextButton", transferRow)
	exportBtn.Name = "ExportBtn"
	exportBtn.Size = UDim2.new(0.5, -2, 1, 0)
	exportBtn.BackgroundColor3 = T.Colors.ButtonNormal
	exportBtn.TextColor3 = T.Colors.Text
	exportBtn.Text = "Export"
	exportBtn.FontFace = T.Fonts.Semi
	exportBtn.TextSize = T.Sizes.FontSizeSmall
	exportBtn.BorderSizePixel = 0
	exportBtn.LayoutOrder = 1
	Instance.new("UICorner", exportBtn).CornerRadius = T.Sizes.SmallCorner

	local importBtn = Instance.new("TextButton", transferRow)
	importBtn.Name = "ImportBtn"
	importBtn.Size = UDim2.new(0.5, -2, 1, 0)
	importBtn.BackgroundColor3 = T.Colors.ButtonNormal
	importBtn.TextColor3 = T.Colors.Text
	importBtn.Text = "Import"
	importBtn.FontFace = T.Fonts.Semi
	importBtn.TextSize = T.Sizes.FontSizeSmall
	importBtn.BorderSizePixel = 0
	importBtn.LayoutOrder = 2
	Instance.new("UICorner", importBtn).CornerRadius = T.Sizes.SmallCorner

	-- Inline transfer panels (LayoutOrder 5). Each is its own frame, only
	-- one is visible at a time. Build lazily on first open so they aren't
	-- cluttering the layout when unused.
	exportBtn.MouseButton1Click:Connect(function()
		self:_toggleExportFrame(frame, 5)
	end)
	importBtn.MouseButton1Click:Connect(function()
		self:_toggleImportFrame(frame, 5)
	end)

	local listContainer = Instance.new("Frame", frame)
	listContainer.Name = "ListContainer"
	listContainer.Size = UDim2.new(1, 0, 0, 0)
	listContainer.AutomaticSize = Enum.AutomaticSize.Y
	listContainer.BackgroundTransparency = 1
	listContainer.LayoutOrder = 6

	local listLayout = Instance.new("UIListLayout", listContainer)
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	self._presetManagerList = listContainer

	-- Initial populate (and re-populate any time presets change).
	self:_refreshPresetManager()

	return frame
end

------------------------------------------------------------------------
-- Export / Import inline panels
------------------------------------------------------------------------
function WidgetUI:_destroyTransferFrames(parent: Instance)
	local existing = parent:FindFirstChild("ExportFrame")
	if existing then existing:Destroy() end
	existing = parent:FindFirstChild("ImportFrame")
	if existing then existing:Destroy() end
end

function WidgetUI:_toggleExportFrame(parent: Instance, layoutOrder: number)
	if parent:FindFirstChild("ExportFrame") then
		parent:FindFirstChild("ExportFrame"):Destroy()
		return
	end
	-- Hide import frame if it's open — only one transfer panel at a time.
	local imp = parent:FindFirstChild("ImportFrame")
	if imp then imp:Destroy() end

	self:_buildExportFrame(parent, layoutOrder)
end

function WidgetUI:_toggleImportFrame(parent: Instance, layoutOrder: number)
	if parent:FindFirstChild("ImportFrame") then
		parent:FindFirstChild("ImportFrame"):Destroy()
		return
	end
	local exp = parent:FindFirstChild("ExportFrame")
	if exp then exp:Destroy() end

	self:_buildImportFrame(parent, layoutOrder)
end

function WidgetUI:_buildExportFrame(parent, layoutOrder: number)
	local T = self._theme
	local presets = self._state.materialPresets
	if not presets then return end

	local frame = Instance.new("Frame", parent)
	frame.Name = "ExportFrame"
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = T.Colors.Surface
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	Instance.new("UICorner", frame).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", frame).Color = T.Colors.Border

	local pad = Instance.new("UIPadding", frame)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)

	local layout = Instance.new("UIListLayout", frame)
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.TextColor3 = T.Colors.Text
	title.Text = "Export presets"
	title.FontFace = T.Fonts.Bold
	title.TextSize = T.Sizes.FontSizeNormal
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 1

	local hint = Instance.new("TextLabel", frame)
	hint.Size = UDim2.new(1, 0, 0, 32)
	hint.AutomaticSize = Enum.AutomaticSize.Y
	hint.BackgroundTransparency = 1
	hint.TextColor3 = T.Colors.TextDim
	hint.Text = "Copy this JSON and share it. Your friend can paste it into the Import box."
	hint.FontFace = T.Fonts.Default
	hint.TextSize = T.Sizes.FontSizeSmall
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.LayoutOrder = 2

	local jsonText = presets:ExportToJSON()

	local box = Instance.new("TextBox", frame)
	box.Name = "ExportBox"
	box.Size = UDim2.new(1, 0, 0, 160)
	box.BackgroundColor3 = T.Colors.Background
	box.TextColor3 = T.Colors.Text
	box.Text = jsonText
	box.FontFace = T.Fonts.Default  -- monospace would be nicer; theme doesn't define one
	box.TextSize = T.Sizes.FontSizeSmall
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.TextWrapped = true
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.LayoutOrder = 3
	Instance.new("UICorner", box).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", box).Color = T.Colors.Border

	local boxPad = Instance.new("UIPadding", box)
	boxPad.PaddingTop = UDim.new(0, 4)
	boxPad.PaddingBottom = UDim.new(0, 4)
	boxPad.PaddingLeft = UDim.new(0, 6)
	boxPad.PaddingRight = UDim.new(0, 6)

	local btnRow = Instance.new("Frame", frame)
	btnRow.Size = UDim2.new(1, 0, 0, 28)
	btnRow.BackgroundTransparency = 1
	btnRow.LayoutOrder = 4

	local rowLayout = Instance.new("UIListLayout", btnRow)
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 4)

	local copyBtn = Instance.new("TextButton", btnRow)
	copyBtn.Name = "CopyBtn"
	copyBtn.Size = UDim2.new(0.5, -2, 1, 0)
	copyBtn.BackgroundColor3 = T.Colors.Accent
	copyBtn.TextColor3 = Color3.new(1, 1, 1)
	copyBtn.Text = "Copy to Clipboard"
	copyBtn.FontFace = T.Fonts.Bold
	copyBtn.TextSize = T.Sizes.FontSizeSmall
	copyBtn.BorderSizePixel = 0
	Instance.new("UICorner", copyBtn).CornerRadius = T.Sizes.SmallCorner

	local closeBtn = Instance.new("TextButton", btnRow)
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0.5, -2, 1, 0)
	closeBtn.BackgroundColor3 = T.Colors.ButtonNormal
	closeBtn.TextColor3 = T.Colors.Text
	closeBtn.Text = "Close"
	closeBtn.FontFace = T.Fonts.Semi
	closeBtn.TextSize = T.Sizes.FontSizeSmall
	closeBtn.BorderSizePixel = 0
	Instance.new("UICorner", closeBtn).CornerRadius = T.Sizes.SmallCorner

	local status = Instance.new("TextLabel", frame)
	status.Size = UDim2.new(1, 0, 0, 16)
	status.BackgroundTransparency = 1
	status.TextColor3 = T.Colors.TextDim
	status.Text = ""
	status.FontFace = T.Fonts.Default
	status.TextSize = T.Sizes.FontSizeSmall
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.LayoutOrder = 5

	-- Studio-only clipboard API. Some builds expose `setclipboard` globally;
	-- StudioService:CopyToClipboard is the official path. Try both.
	local function copyToClipboard(text: string): (boolean, string?)
		local ok, err = pcall(function()
			local StudioService = game:GetService("StudioService") :: any
			if StudioService and StudioService.CopyToClipboard then
				StudioService:CopyToClipboard(text)
				return
			end
			local sc = (rawget(getfenv(0), "setclipboard") :: any)
			if sc then
				sc(text)
				return
			end
			error("No clipboard API available", 0)
		end)
		return ok, if ok then nil else tostring(err)
	end

	copyBtn.MouseButton1Click:Connect(function()
		local ok, err = copyToClipboard(box.Text)
		if ok then
			status.Text = "Copied to clipboard."
			status.TextColor3 = T.Colors.Positive
		else
			status.Text = "Couldn't auto-copy. Click the box, Ctrl+A, Ctrl+C. (" .. (err or "?") .. ")"
			status.TextColor3 = T.Colors.Negative
			-- Best we can do as a fallback: focus the box for the user.
			box:CaptureFocus()
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		frame:Destroy()
	end)
end

function WidgetUI:_buildImportFrame(parent, layoutOrder: number)
	local T = self._theme
	local presets = self._state.materialPresets
	if not presets then return end

	local frame = Instance.new("Frame", parent)
	frame.Name = "ImportFrame"
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = T.Colors.Surface
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	Instance.new("UICorner", frame).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", frame).Color = T.Colors.Border

	local pad = Instance.new("UIPadding", frame)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)

	local layout = Instance.new("UIListLayout", frame)
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.TextColor3 = T.Colors.Text
	title.Text = "Import presets"
	title.FontFace = T.Fonts.Bold
	title.TextSize = T.Sizes.FontSizeNormal
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 1

	local hint = Instance.new("TextLabel", frame)
	hint.Size = UDim2.new(1, 0, 0, 32)
	hint.AutomaticSize = Enum.AutomaticSize.Y
	hint.BackgroundTransparency = 1
	hint.TextColor3 = T.Colors.TextDim
	hint.Text = "Paste preset JSON below. 'Add' merges into your library; 'Replace All' wipes it first."
	hint.FontFace = T.Fonts.Default
	hint.TextSize = T.Sizes.FontSizeSmall
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.LayoutOrder = 2

	local box = Instance.new("TextBox", frame)
	box.Name = "ImportBox"
	box.Size = UDim2.new(1, 0, 0, 160)
	box.BackgroundColor3 = T.Colors.Background
	box.TextColor3 = T.Colors.Text
	box.Text = ""
	box.PlaceholderText = '[ { "name": "Grass", "color": [74, 124, 63], "material": "Grass" } ]'
	box.PlaceholderColor3 = T.Colors.TextDim
	box.FontFace = T.Fonts.Default
	box.TextSize = T.Sizes.FontSizeSmall
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.TextWrapped = true
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.LayoutOrder = 3
	Instance.new("UICorner", box).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", box).Color = T.Colors.Border

	local boxPad = Instance.new("UIPadding", box)
	boxPad.PaddingTop = UDim.new(0, 4)
	boxPad.PaddingBottom = UDim.new(0, 4)
	boxPad.PaddingLeft = UDim.new(0, 6)
	boxPad.PaddingRight = UDim.new(0, 6)

	local status = Instance.new("TextLabel", frame)
	status.Size = UDim2.new(1, 0, 0, 16)
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.BackgroundTransparency = 1
	status.TextColor3 = T.Colors.TextDim
	status.Text = ""
	status.FontFace = T.Fonts.Default
	status.TextSize = T.Sizes.FontSizeSmall
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextWrapped = true
	status.LayoutOrder = 4

	local btnRow = Instance.new("Frame", frame)
	btnRow.Size = UDim2.new(1, 0, 0, 28)
	btnRow.BackgroundTransparency = 1
	btnRow.LayoutOrder = 5

	local rowLayout = Instance.new("UIListLayout", btnRow)
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 4)

	local addBtn = Instance.new("TextButton", btnRow)
	addBtn.Name = "AddBtn"
	addBtn.Size = UDim2.new(0.4, -2, 1, 0)
	addBtn.BackgroundColor3 = T.Colors.Positive
	addBtn.TextColor3 = Color3.new(1, 1, 1)
	addBtn.Text = "Add"
	addBtn.FontFace = T.Fonts.Bold
	addBtn.TextSize = T.Sizes.FontSizeSmall
	addBtn.BorderSizePixel = 0
	Instance.new("UICorner", addBtn).CornerRadius = T.Sizes.SmallCorner

	local replaceBtn = Instance.new("TextButton", btnRow)
	replaceBtn.Name = "ReplaceBtn"
	replaceBtn.Size = UDim2.new(0.4, -2, 1, 0)
	replaceBtn.BackgroundColor3 = T.Colors.Negative
	replaceBtn.TextColor3 = Color3.new(1, 1, 1)
	replaceBtn.Text = "Replace All"
	replaceBtn.FontFace = T.Fonts.Bold
	replaceBtn.TextSize = T.Sizes.FontSizeSmall
	replaceBtn.BorderSizePixel = 0
	Instance.new("UICorner", replaceBtn).CornerRadius = T.Sizes.SmallCorner

	local cancelBtn = Instance.new("TextButton", btnRow)
	cancelBtn.Name = "CancelBtn"
	cancelBtn.Size = UDim2.new(0.2, -2, 1, 0)
	cancelBtn.BackgroundColor3 = T.Colors.ButtonNormal
	cancelBtn.TextColor3 = T.Colors.Text
	cancelBtn.Text = "Cancel"
	cancelBtn.FontFace = T.Fonts.Semi
	cancelBtn.TextSize = T.Sizes.FontSizeSmall
	cancelBtn.BorderSizePixel = 0
	Instance.new("UICorner", cancelBtn).CornerRadius = T.Sizes.SmallCorner

	local function tryImport(replace: boolean)
		local count, err = presets:ImportFromJSON(box.Text, replace)
		if err then
			status.Text = "Import failed: " .. err
			status.TextColor3 = T.Colors.Negative
			return
		end
		status.Text = string.format(
			"Imported %d preset%s%s.",
			count,
			if count == 1 then "" else "s",
			if replace then " (replaced existing library)" else ""
		)
		status.TextColor3 = T.Colors.Positive
		box.Text = ""
	end

	-- Replace All wipes the entire preset library — one misclick can torch
	-- a lot of work. Two-step confirm: first click flips the button into
	-- a hot "Confirm" state for 3s, second click commits. If the user
	-- moves on (or hits Add/Cancel/anywhere else), it auto-resets.
	local replaceArmed = false
	local replaceArmToken = 0
	local origReplaceText = replaceBtn.Text
	local origReplaceColor = replaceBtn.BackgroundColor3

	local function disarmReplace()
		replaceArmed = false
		replaceArmToken += 1
		replaceBtn.Text = origReplaceText
		replaceBtn.BackgroundColor3 = origReplaceColor
	end

	addBtn.MouseButton1Click:Connect(function()
		disarmReplace()
		tryImport(false)
	end)

	replaceBtn.MouseButton1Click:Connect(function()
		if replaceArmed then
			disarmReplace()
			tryImport(true)
			return
		end
		replaceArmed = true
		replaceArmToken += 1
		local myToken = replaceArmToken
		replaceBtn.Text = "Confirm replace?"
		-- Slightly darker red so the second state reads as "really sure?"
		replaceBtn.BackgroundColor3 = Color3.fromRGB(
			math.clamp(math.round(origReplaceColor.R * 255 * 0.75), 0, 255),
			math.clamp(math.round(origReplaceColor.G * 255 * 0.75), 0, 255),
			math.clamp(math.round(origReplaceColor.B * 255 * 0.75), 0, 255)
		)
		task.delay(3, function()
			-- Token guards against a stale timer disarming a freshly-armed
			-- button (user clicks twice within 3s -> second click resets
			-- the timer; old timer's disarm should be a no-op).
			if myToken == replaceArmToken and replaceArmed then
				disarmReplace()
			end
		end)
	end)

	cancelBtn.MouseButton1Click:Connect(function() frame:Destroy() end)
end

function WidgetUI:_refreshPresetManager()
	local container = self._presetManagerList
	if not container or not container.Parent then return end

	-- Clear existing rows except the UIListLayout.
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local presets = self._state.materialPresets
	if not presets then return end

	local order = 0
	for _, preset in presets:GetAll() do
		order += 1
		-- Multiply by 10 so popup pickers (color grid / material list) have
		-- room to slot in just after their row via LayoutOrder = row + 1.
		self:_buildPresetEditorRow(container, preset, order * 10)
	end

	if order == 0 then
		local empty = Instance.new("TextLabel", container)
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = self._theme.Colors.TextDim
		empty.FontFace = self._theme.Fonts.Default
		empty.TextSize = self._theme.Sizes.FontSizeSmall
		empty.Text = "No presets yet. Click + New Preset above to add one."
		empty.LayoutOrder = 1
	end
end

------------------------------------------------------------------------
-- Spotlight a preset row by id: scroll the mode panel so the row is on
-- screen, focus the row's name TextBox so the user can rename right away,
-- and briefly flash its outline. Deferred a frame so the UIListLayout
-- has settled into final positions.
------------------------------------------------------------------------
function WidgetUI:_spotlightPresetRow(presetId: string)
	task.defer(function()
		local container = self._presetManagerList
		if not container or not container.Parent then return end
		local row = container:FindFirstChild("Row_" .. presetId)
		if not row or not row:IsA("GuiObject") then return end

		-- Scroll the mode panel so the new row is visible (with some headroom
		-- so the user can see the row above it for context).
		local panel = self._modePanel
		if panel then
			local rowAbsY = row.AbsolutePosition.Y
			local panelAbsY = panel.AbsolutePosition.Y
			local relY = rowAbsY - panelAbsY + panel.CanvasPosition.Y
			panel.CanvasPosition = Vector2.new(0, math.max(0, relY - 60))
		end

		-- Focus the name TextBox and select-all so typing immediately
		-- replaces the placeholder name.
		local nameBox = row:FindFirstChild("Name")
		if nameBox and nameBox:IsA("TextBox") then
			pcall(function()
				nameBox:CaptureFocus()
				nameBox.SelectionStart = 1
				nameBox.CursorPosition = #nameBox.Text + 1
			end)
		end

		-- Outline flash: thicker accent stroke for ~1.2s, then back to the
		-- default border. Find the row's stroke (we created exactly one).
		local stroke = row:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			local origColor = stroke.Color
			local origThickness = stroke.Thickness
			stroke.Color = self._theme.Colors.Accent
			stroke.Thickness = 2
			task.delay(1.2, function()
				if stroke.Parent then
					stroke.Color = origColor
					stroke.Thickness = origThickness
				end
			end)
		end
	end)
end

function WidgetUI:_buildPresetEditorRow(parent, preset, order: number)
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = "Row_" .. preset.id
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundColor3 = T.Colors.Surface
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	Instance.new("UICorner", row).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", row).Color = T.Colors.Border

	-- Thumbnail (left)
	local thumbHolder = Instance.new("Frame", row)
	thumbHolder.Name = "ThumbHolder"
	thumbHolder.Size = UDim2.fromOffset(48, 48)
	thumbHolder.Position = UDim2.fromOffset(8, 8)
	thumbHolder.BackgroundTransparency = 1

	self:_buildMaterialThumbnail(thumbHolder, preset.color, preset.material, 48)

	-- Name (top right)
	local nameBox = Instance.new("TextBox", row)
	nameBox.Name = "Name"
	nameBox.Size = UDim2.new(1, -180, 0, 24)
	nameBox.Position = UDim2.new(0, 64, 0, 6)
	nameBox.BackgroundColor3 = T.Colors.Background
	nameBox.TextColor3 = T.Colors.Text
	nameBox.PlaceholderText = "Preset name"
	nameBox.PlaceholderColor3 = T.Colors.TextDim
	nameBox.Text = preset.name
	nameBox.FontFace = T.Fonts.Semi
	nameBox.TextSize = T.Sizes.FontSizeNormal
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ClearTextOnFocus = false
	nameBox.BorderSizePixel = 0
	Instance.new("UICorner", nameBox).CornerRadius = T.Sizes.SmallCorner

	local namePad = Instance.new("UIPadding", nameBox)
	namePad.PaddingLeft = UDim.new(0, 6)
	namePad.PaddingRight = UDim.new(0, 6)

	nameBox.FocusLost:Connect(function()
		local presets = self._state.materialPresets
		if not presets then return end
		local trimmed = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if #trimmed == 0 then
			nameBox.Text = preset.name
			return
		end
		presets:Update(preset.id, { name = trimmed })
	end)

	-- Color swatch (bottom-left under name)
	local colorBtn = Instance.new("TextButton", row)
	colorBtn.Name = "ColorBtn"
	colorBtn.Size = UDim2.fromOffset(28, 24)
	colorBtn.Position = UDim2.new(0, 64, 0, 34)
	colorBtn.BackgroundColor3 = preset.color
	colorBtn.Text = ""
	colorBtn.BorderSizePixel = 0
	Instance.new("UICorner", colorBtn).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", colorBtn).Color = T.Colors.Border

	-- Material dropdown (right of color, takes the rest of the row width up
	-- to the delete button area).
	local matBtn = Instance.new("TextButton", row)
	matBtn.Name = "MatBtn"
	matBtn.Size = UDim2.new(1, -176, 0, 24)
	matBtn.Position = UDim2.new(0, 100, 0, 34)
	matBtn.BackgroundColor3 = T.Colors.Background
	matBtn.TextColor3 = T.Colors.Text
	matBtn.Text = "  " .. preset.material.Name
	matBtn.FontFace = T.Fonts.Default
	matBtn.TextSize = T.Sizes.FontSizeSmall
	matBtn.TextXAlignment = Enum.TextXAlignment.Left
	matBtn.BorderSizePixel = 0
	Instance.new("UICorner", matBtn).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", matBtn).Color = T.Colors.Border

	-- Delete button (top right, small)
	local delBtn = Instance.new("TextButton", row)
	delBtn.Name = "DeleteBtn"
	delBtn.Size = UDim2.fromOffset(60, 24)
	delBtn.Position = UDim2.new(1, -68, 0, 6)
	delBtn.BackgroundColor3 = T.Colors.Negative
	delBtn.TextColor3 = Color3.new(1, 1, 1)
	delBtn.Text = "Delete"
	delBtn.FontFace = T.Fonts.Bold
	delBtn.TextSize = T.Sizes.FontSizeSmall
	delBtn.BorderSizePixel = 0
	Instance.new("UICorner", delBtn).CornerRadius = T.Sizes.SmallCorner

	delBtn.MouseButton1Click:Connect(function()
		local presets = self._state.materialPresets
		if not presets then return end
		presets:Remove(preset.id)
	end)

	-- Color picker (drops into the manager's list container, sandwiched
	-- between rows via a layout order that places it directly after this row).
	colorBtn.MouseButton1Click:Connect(function()
		local container = parent  -- the ListContainer of the Presets panel
		self:_showColorGridForCallback(container, order + 1, function(c)
			local presets = self._state.materialPresets
			if not presets then return end
			presets:Update(preset.id, { color = c })
		end)
	end)

	-- Material picker — same pattern.
	matBtn.MouseButton1Click:Connect(function()
		local container = parent
		self:_showMaterialListForCallback(container, order + 1, function(mat)
			local presets = self._state.materialPresets
			if not presets then return end
			presets:Update(preset.id, { material = mat })
		end)
	end)
end

------------------------------------------------------------------------
-- Status Bar
------------------------------------------------------------------------
function WidgetUI:_buildStatusBar(parent)
	local T = self._theme

	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.Size = UDim2.new(1, 0, 0, T.Sizes.StatusHeight)
	bar.Position = UDim2.new(0, 0, 1, -T.Sizes.StatusHeight)
	bar.BackgroundColor3 = T.Colors.Surface
	bar.BorderSizePixel = 0
	bar.Parent = parent

	local sep = Instance.new("Frame", bar)
	sep.Name = "Sep"
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Position = UDim2.fromOffset(0, 0)
	sep.BackgroundColor3 = T.Colors.Border
	sep.BorderSizePixel = 0

	local lbl = Instance.new("TextLabel", bar)
	lbl.Name = "Label"
	lbl.Size = UDim2.new(1, -12, 1, -1)
	lbl.Position = UDim2.fromOffset(6, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.TextDim
	lbl.FontFace = T.Fonts.Default
	lbl.TextSize = T.Sizes.FontSizeSmall
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	self._statusLabel = lbl

	self:_refreshStatus()
end

function WidgetUI:_refreshStatus()
	if not self._statusLabel then return end
	local nodes = self._state:GetNodeCount()
	local tris = self._state:GetTriangleCount()
	local tag = self._state.activeTag or "All"
	self._statusLabel.Text = string.format("Nodes: %d  |  Triangles: %d  |  Tag: %s", nodes, tris, tag)
end

------------------------------------------------------------------------
-- Generic UI helpers
------------------------------------------------------------------------
function WidgetUI:_panelFrame(parent, name, order): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Visible = false
	frame.Parent = parent

	local layout = Instance.new("UIListLayout", frame)
	layout.Padding = UDim.new(0, self._theme.Sizes.Padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	return frame
end

function WidgetUI:_addLabel(parent, name, text, font, size, order): TextLabel
	local T = self._theme
	local lbl = Instance.new("TextLabel", parent)
	lbl.Name = name
	lbl.Size = UDim2.new(1, 0, 0, size + 4)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.Text
	lbl.Text = text
	lbl.FontFace = font
	lbl.TextSize = size
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.LayoutOrder = order
	return lbl
end

-- Returned by row helpers so external code can:
--   * SetEnabled(bool)  — grey out and gate input (used to cascade-disable
--                         dependent options when a parent toggle is off)
--   * SetValue(value)   — push an external value into the row (used when
--                         settings change via another control)
type RowController = {
	SetEnabled: (self: any, enabled: boolean) -> (),
	SetValue: (self: any, value: any) -> (),
}

local DISABLED_ALPHA = 0.55

function WidgetUI:_addSliderRow(parent, name, label, min, max, default, order, callback): RowController
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.35, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.Text
	lbl.Text = label
	lbl.FontFace = T.Fonts.Semi
	lbl.TextSize = T.Sizes.FontSizeNormal
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local valLabel = Instance.new("TextLabel", row)
	valLabel.Name = "Value"
	valLabel.Size = UDim2.fromOffset(40, 28)
	valLabel.Position = UDim2.new(1, -40, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.TextColor3 = T.Colors.TextDim
	valLabel.Text = tostring(math.round(default * 10) / 10)
	valLabel.FontFace = T.Fonts.Default
	valLabel.TextSize = T.Sizes.FontSizeSmall
	valLabel.TextXAlignment = Enum.TextXAlignment.Right

	local sliderBg = Instance.new("Frame", row)
	sliderBg.Name = "SliderBg"
	sliderBg.Size = UDim2.new(0.65, -48, 0, 6)
	sliderBg.Position = UDim2.new(0.35, 4, 0.5, -3)
	sliderBg.BackgroundColor3 = T.Colors.Border
	sliderBg.BorderSizePixel = 0
	Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0.5, 0)

	local fill = Instance.new("Frame", sliderBg)
	fill.Name = "Fill"
	fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = T.Colors.Accent
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)

	local handle = Instance.new("TextButton", sliderBg)
	handle.Name = "Handle"
	handle.Size = UDim2.fromOffset(12, 12)
	handle.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
	handle.BackgroundColor3 = Color3.new(1, 1, 1)
	handle.Text = ""
	handle.BorderSizePixel = 0
	handle.ZIndex = 5
	Instance.new("UICorner", handle).CornerRadius = UDim.new(0.5, 0)

	local enabled = true
	local dragging = false

	local function setVisualFromValue(val)
		local rel = math.clamp((val - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		handle.Position = UDim2.new(rel, -6, 0.5, -6)
		valLabel.Text = tostring(math.round(val * 10) / 10)
	end

	handle.MouseButton1Down:Connect(function()
		if not enabled then return end
		dragging = true
	end)

	handle.InputChanged:Connect(function(input)
		if not enabled or not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local abs = sliderBg.AbsolutePosition
			local sizeX = sliderBg.AbsoluteSize.X
			local relX = math.clamp((input.Position.X - abs.X) / sizeX, 0, 1)
			local val = min + relX * (max - min)
			setVisualFromValue(val)
			callback(val)
		end
	end)

	sliderBg.InputChanged:Connect(function(input)
		if not enabled or not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local abs = sliderBg.AbsolutePosition
			local sizeX = sliderBg.AbsoluteSize.X
			local relX = math.clamp((input.Position.X - abs.X) / sizeX, 0, 1)
			local val = min + relX * (max - min)
			setVisualFromValue(val)
			callback(val)
		end
	end)

	handle.MouseButton1Up:Connect(function() dragging = false end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	local controller = {}
	function controller:SetEnabled(v: boolean)
		enabled = v
		if not v then dragging = false end
		local trans = if v then 0 else DISABLED_ALPHA
		lbl.TextTransparency = trans
		valLabel.TextTransparency = trans
		sliderBg.BackgroundTransparency = trans
		fill.BackgroundTransparency = trans
		handle.BackgroundTransparency = trans
		handle.AutoButtonColor = v
	end
	function controller:SetValue(val: number)
		setVisualFromValue(val)
	end
	return controller
end

function WidgetUI:_addToggleRow(parent, name, label, default, order, callback): RowController
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.7, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.Text
	lbl.Text = label
	lbl.FontFace = T.Fonts.Semi
	lbl.TextSize = T.Sizes.FontSizeNormal
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.fromOffset(44, 22)
	btn.Position = UDim2.new(1, -44, 0.5, -11)
	btn.BackgroundColor3 = if default then T.Colors.Positive else T.Colors.Border
	btn.Text = if default then "ON" else "OFF"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.FontFace = T.Fonts.Bold
	btn.TextSize = T.Sizes.FontSizeSmall
	btn.BorderSizePixel = 0
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)

	local state = default
	local enabled = true

	local function applyVisual()
		btn.BackgroundColor3 = if state then T.Colors.Positive else T.Colors.Border
		btn.Text = if state then "ON" else "OFF"
	end

	btn.MouseButton1Click:Connect(function()
		if not enabled then return end
		state = not state
		applyVisual()
		callback(state)
	end)

	local controller = {}
	function controller:SetEnabled(v: boolean)
		enabled = v
		local trans = if v then 0 else DISABLED_ALPHA
		lbl.TextTransparency = trans
		btn.TextTransparency = trans
		btn.BackgroundTransparency = trans
		btn.AutoButtonColor = v
	end
	function controller:SetValue(v: boolean)
		if state ~= v then
			state = v
			applyVisual()
		end
	end
	return controller
end

------------------------------------------------------------------------
-- Editable text input row. Used for things like the work plane Y position
-- where we want both a live-updating display AND user editability.
--
-- The callback receives the parsed value (after passing the optional
-- validate fn). Commit fires on Enter or focus loss with valid input.
-- SetValue updates the visible text but only if the box isn't currently
-- focused, so we don't overwrite what the user is typing.
------------------------------------------------------------------------
function WidgetUI:_addTextInputRow(parent, name, label, default, order, validate, onCommit): RowController
	local T = self._theme

	local row = Instance.new("Frame", parent)
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.5, -4, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = T.Colors.Text
	lbl.Text = label
	lbl.FontFace = T.Fonts.Semi
	lbl.TextSize = T.Sizes.FontSizeNormal
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local boxFrame = Instance.new("Frame", row)
	boxFrame.Size = UDim2.new(0.5, 0, 0, 22)
	boxFrame.Position = UDim2.new(0.5, 0, 0.5, -11)
	boxFrame.BackgroundColor3 = T.Colors.Surface
	boxFrame.BorderSizePixel = 0
	Instance.new("UICorner", boxFrame).CornerRadius = T.Sizes.SmallCorner
	local stroke = Instance.new("UIStroke", boxFrame)
	stroke.Color = T.Colors.Border

	local box = Instance.new("TextBox", boxFrame)
	box.Size = UDim2.new(1, -8, 1, 0)
	box.Position = UDim2.fromOffset(4, 0)
	box.BackgroundTransparency = 1
	box.TextColor3 = T.Colors.Text
	box.PlaceholderColor3 = T.Colors.TextDim
	box.FontFace = T.Fonts.Default
	box.TextSize = T.Sizes.FontSizeSmall
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = tostring(default)

	local enabled = true
	-- Last value pushed via SetValue (or the initial default). On rejection
	-- we revert to this rather than the original default, so a "bad input"
	-- snaps back to whatever the live value currently is.
	local lastGoodText = tostring(default)

	box.FocusLost:Connect(function(enterPressed)
		if not enabled then return end
		local raw = box.Text
		stroke.Color = T.Colors.Border
		-- No-op if the user didn't actually change anything. Without this,
		-- focus-without-edit would still re-fire onCommit -> SetSetting ->
		-- settingsChanged cascade, which on the work plane Y would race
		-- with the live-Y broadcaster pushing back the same value.
		if raw == lastGoodText then return end
		local parsed = if validate then validate(raw) else tonumber(raw)
		if parsed ~= nil then
			onCommit(parsed)
		else
			box.Text = lastGoodText
		end
	end)

	box.Focused:Connect(function()
		if not enabled then box:ReleaseFocus() return end
		stroke.Color = T.Colors.Accent
	end)

	local controller = {}
	function controller:SetEnabled(v: boolean)
		enabled = v
		local trans = if v then 0 else DISABLED_ALPHA
		lbl.TextTransparency = trans
		box.TextTransparency = trans
		boxFrame.BackgroundTransparency = trans
		stroke.Transparency = trans
		box.TextEditable = v
		if not v then
			box:ReleaseFocus()
		end
	end
	function controller:SetValue(val: any)
		local s = tostring(val)
		lastGoodText = s
		if not box:IsFocused() then
			box.Text = s
		end
	end
	return controller
end

------------------------------------------------------------------------
-- State bindings
------------------------------------------------------------------------
function WidgetUI:_bindState()
	table.insert(self._conns, self._state.modeChanged:Connect(function(mode)
		self:_highlightActiveMode(mode)
		self:_showModePanel(mode)
	end))

	table.insert(self._conns, self._state.drawSubModeChanged:Connect(function()
		self:_refreshSubDivToggle()
	end))

	table.insert(self._conns, self._state.nodeAdded:Connect(function()
		self:_refreshStatus()
	end))

	table.insert(self._conns, self._state.nodeRemoved:Connect(function()
		self:_refreshStatus()
	end))

	table.insert(self._conns, self._state.triangleAdded:Connect(function()
		self:_refreshStatus()
	end))

	table.insert(self._conns, self._state.triangleRemoved:Connect(function()
		self:_refreshStatus()
	end))

	table.insert(self._conns, self._state.tagFilterChanged:Connect(function()
		self:_highlightActiveTag()
		self:_refreshStatus()
	end))

	table.insert(self._conns, self._state.tagsChanged:Connect(function()
		self:_refreshTagButtons()
	end))

	table.insert(self._conns, self._state.drawSelectionChanged:Connect(function(sel)
		if self._drawStatusLabel then
			self._drawStatusLabel.Text = string.format("Selected: %d/3 nodes", #sel)
		end
	end))

	table.insert(self._conns, self._state.settingsChanged:Connect(function(key)
		if key == "paintColor" or key == "paintMaterial" then
			-- Refresh paint UI surfaces
			for _, refresh in self._colorPreviewRefreshers do refresh() end
			for _, refresh in self._materialDropdownRefreshers do refresh() end
			for _, refresh in self._presetDropdownRefreshers do refresh() end
		elseif key == "workPlaneEnabled" or key == "workPlaneLocked" then
			-- Refresh disable cascade and keep the lock toggle visual in
			-- sync with the underlying setting (the textbox auto-lock path
			-- changes workPlaneLocked without going through the toggle).
			if self._refreshWorkPlaneRows then
				self._refreshWorkPlaneRows()
			end
			if self._workPlaneCtrls then
				self._workPlaneCtrls.lockCtrl:SetValue(self._state.settings.workPlaneLocked)
				self._workPlaneCtrls.showCtrl:SetValue(self._state.settings.workPlaneEnabled)
			end
		elseif key == "workPlaneFixedY" then
			-- When the user toggles lock or types a Y, push the new fixed
			-- value into the textbox immediately (so it doesn't have to wait
			-- for the next workPlaneYChanged tick from InputHandler).
			if self._workPlaneCtrls then
				self._workPlaneCtrls.yCtrl:SetValue(string.format("%.1f", self._state.settings.workPlaneFixedY))
			end
		elseif key == "workPlaneYOffset" then
			-- Slider moves change the Y when unlocked; the slider's own
			-- visual already reflects this, so nothing extra needed here.
		end
	end))

	-- Live Y readout in the textbox. Throttled at the source; safe to
	-- listen every tick.
	table.insert(self._conns, self._state.workPlaneYChanged:Connect(function(y)
		if self._workPlaneCtrls then
			self._workPlaneCtrls.yCtrl:SetValue(string.format("%.1f", y))
		end
	end))

	-- Delete-stroke live counter. Show "Deleted: N" while a drag is in
	-- progress, and clear the label when the stroke ends (count reset to 0).
	table.insert(self._conns, self._state.deleteStrokeChanged:Connect(function(n)
		if not self._deleteCounterLabel then return end
		if n > 0 then
			self._deleteCounterLabel.Text = string.format("Deleted: %d", n)
		else
			self._deleteCounterLabel.Text = ""
		end
	end))

	-- Material presets are wired up post-construction (Plugin.server sets
	-- state.materialPresets after instantiation). Bind lazily on first use.
	local function bindPresets()
		if not self._state.materialPresets or self._presetsBound then return end
		self._presetsBound = true
		table.insert(self._conns, self._state.materialPresets.changed:Connect(function()
			-- Any open preset dropdown (Paint / Draw panel) is now showing
			-- a stale list — clicking a row could apply a deleted preset
			-- or skip a newly-renamed one. Close them so the user re-opens
			-- and gets fresh data. Search recursively because the dropdown
			-- is parented to the row's container, which lives inside a
			-- mode panel.
			for _, panel in self._modePanels do
				local d = panel:FindFirstChild("PresetList", true)
				while d do
					d:Destroy()
					d = panel:FindFirstChild("PresetList", true)
				end
			end
			for _, refresh in self._presetDropdownRefreshers do refresh() end
			self:_refreshPresetManager()
		end))
		-- Initial sync now that presets exist.
		for _, refresh in self._presetDropdownRefreshers do refresh() end
		self:_refreshPresetManager()
	end
	bindPresets()
	-- Defensive: if presets weren't attached to state yet at WidgetUI.new()
	-- time, the caller can invoke ui:_tryBindPresets() once they are.
	self._tryBindPresets = bindPresets

	table.insert(self._conns, self._state.selectionChanged:Connect(function()
		if self._selInfoLabel then
			local nn = #self._state.selectedNodes
			local nt = #self._state.selectedTriangles
			if nn == 0 and nt == 0 then
				self._selInfoLabel.Text = "Nothing selected"
			else
				local parts = {}
				if nn > 0 then table.insert(parts, nn .. " node" .. (nn > 1 and "s" or "")) end
				if nt > 0 then table.insert(parts, nt .. " triangle" .. (nt > 1 and "s" or "")) end
				self._selInfoLabel.Text = table.concat(parts, ", ") .. " selected"
			end
		end
	end))
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
function WidgetUI:Destroy()
	for _, conn in self._conns do
		conn:Disconnect()
	end
	if self._root then
		self._root:Destroy()
	end
end

return WidgetUI
