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

	local modes = { "Place", "Draw", "Paint", "Sculpt", "Select" }
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
	for mode, btn in self._modeButtons do
		if mode == activeMode then
			btn.BackgroundColor3 = T.Colors.Accent
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
			-- Tag all selected nodes, or if none selected, just register the tag
			for _, nodeId in self._state.selectedNodes do
				self._nodeManager:AddTagToNode(nodeId, name)
			end
			self._nodeManager:RefreshTagList()
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

	-- Work Plane section
	self:_addLabel(frame, "WPHeader", "Work Plane", T.Fonts.Bold, T.Sizes.FontSizeNormal, 10)

	self:_addToggleRow(frame, "WorkPlaneToggle", "Show Work Plane", self._state.settings.workPlaneEnabled, 11, function(val)
		self._state:SetSetting("workPlaneEnabled", val)
	end)

	self:_addSliderRow(frame, "WPYOffset", "Height Below Cam", 5, 100, self._state.settings.workPlaneYOffset, 12, function(val)
		self._state:SetSetting("workPlaneYOffset", math.round(val))
	end)

	return frame
end

function WidgetUI:_buildDrawPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "DrawPanel", 2)

	self:_addLabel(frame, "DrawTitle", "Draw Triangles", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "DrawHelp", "Click 3 nodes to form a triangle.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	local statusLabel = self:_addLabel(frame, "DrawStatus", "Selected: 0/3 nodes", T.Fonts.Semi, T.Sizes.FontSizeNormal, 3)
	self._drawStatusLabel = statusLabel

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
	autoBtn.LayoutOrder = 4
	autoBtn.Parent = frame
	Instance.new("UICorner", autoBtn).CornerRadius = T.Sizes.SmallCorner

	autoBtn.MouseButton1Click:Connect(function()
		if self._callbacks.onAutoTriangulate then
			self._callbacks.onAutoTriangulate()
		end
	end)

	local clearBtn = Instance.new("TextButton", frame)
	clearBtn.Name = "ClearSelBtn"
	clearBtn.Size = UDim2.new(1, 0, 0, 28)
	clearBtn.BackgroundColor3 = T.Colors.ButtonNormal
	clearBtn.TextColor3 = T.Colors.Text
	clearBtn.Text = "Clear Selection"
	clearBtn.FontFace = T.Fonts.Semi
	clearBtn.TextSize = T.Sizes.FontSizeSmall
	clearBtn.BorderSizePixel = 0
	clearBtn.LayoutOrder = 5
	clearBtn.Parent = frame
	Instance.new("UICorner", clearBtn).CornerRadius = T.Sizes.SmallCorner

	clearBtn.MouseButton1Click:Connect(function()
		self._state:ClearDrawSelection()
	end)

	return frame
end

function WidgetUI:_buildPaintPanel(parent): Frame
	local T = self._theme
	local frame = self:_panelFrame(parent, "PaintPanel", 3)

	self:_addLabel(frame, "PaintTitle", "Paint Triangles", T.Fonts.Bold, T.Sizes.FontSizeLarge, 1)
	self:_addLabel(frame, "PaintHelp", "Click a triangle to apply color & material.", T.Fonts.Default, T.Sizes.FontSizeSmall, 2)

	-- Color preview + picker trigger
	local colorRow = Instance.new("Frame", frame)
	colorRow.Name = "ColorRow"
	colorRow.Size = UDim2.new(1, 0, 0, 28)
	colorRow.BackgroundTransparency = 1
	colorRow.LayoutOrder = 3
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

	colorPreview.MouseButton1Click:Connect(function()
		self:_showColorGrid(frame)
	end)

	-- Material dropdown
	self:_addMaterialDropdown(frame, 4)

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
		for _, nodeId in self._state.selectedNodes do
			self._nodeManager:AddTagToNode(nodeId, name)
		end
		self._nodeManager:RefreshTagList()
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
		for _, nodeId in self._state.selectedNodes do
			self._nodeManager:RemoveTagFromNode(nodeId, name)
		end
		self._nodeManager:RefreshTagList()
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
-- Color Grid (simple palette picker)
------------------------------------------------------------------------
function WidgetUI:_showColorGrid(parent)
	local T = self._theme

	if parent:FindFirstChild("ColorGrid") then
		parent:FindFirstChild("ColorGrid"):Destroy()
		return
	end

	local grid = Instance.new("Frame", parent)
	grid.Name = "ColorGrid"
	grid.Size = UDim2.new(1, 0, 0, 120)
	grid.BackgroundColor3 = T.Colors.Surface
	grid.BorderSizePixel = 0
	grid.LayoutOrder = 10
	Instance.new("UICorner", grid).CornerRadius = T.Sizes.SmallCorner
	Instance.new("UIStroke", grid).Color = T.Colors.Border

	local gridLayout = Instance.new("UIGridLayout", grid)
	gridLayout.CellSize = UDim2.fromOffset(20, 20)
	gridLayout.CellPadding = UDim2.fromOffset(2, 2)

	local gridPad = Instance.new("UIPadding", grid)
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingLeft = UDim.new(0, 4)

	local colors = {
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

	for i, color in colors do
		local swatch = Instance.new("TextButton", grid)
		swatch.Name = "Color_" .. i
		swatch.BackgroundColor3 = color
		swatch.Text = ""
		swatch.BorderSizePixel = 0
		Instance.new("UICorner", swatch).CornerRadius = T.Sizes.SmallCorner

		swatch.MouseButton1Click:Connect(function()
			self._state:SetSetting("paintColor", color)
			if self._colorPreview then
				self._colorPreview.BackgroundColor3 = color
			end
			grid:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- Material Dropdown
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

	local materials = {
		Enum.Material.Grass, Enum.Material.Sand, Enum.Material.Rock,
		Enum.Material.Ground, Enum.Material.Mud, Enum.Material.Slate,
		Enum.Material.Concrete, Enum.Material.Brick, Enum.Material.Cobblestone,
		Enum.Material.Snow, Enum.Material.Ice, Enum.Material.Glacier,
		Enum.Material.SmoothPlastic, Enum.Material.Pavement, Enum.Material.Limestone,
		Enum.Material.Basalt, Enum.Material.Asphalt, Enum.Material.Salt,
		Enum.Material.CrackedLava, Enum.Material.LeafyGrass,
	}

	dropdown.MouseButton1Click:Connect(function()
		if parent:FindFirstChild("MaterialList") then
			parent:FindFirstChild("MaterialList"):Destroy()
			return
		end

		local list = Instance.new("ScrollingFrame", parent)
		list.Name = "MaterialList"
		list.Size = UDim2.new(1, 0, 0, 150)
		list.BackgroundColor3 = T.Colors.Surface
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.CanvasSize = UDim2.fromOffset(0, 0)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.LayoutOrder = layoutOrder + 1
		list.ZIndex = 10
		Instance.new("UICorner", list).CornerRadius = T.Sizes.SmallCorner
		Instance.new("UIStroke", list).Color = T.Colors.Border

		local listLayout = Instance.new("UIListLayout", list)
		listLayout.Padding = UDim.new(0, 1)

		for _, mat in materials do
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
				self._state:SetSetting("paintMaterial", mat)
				dropdown.Text = mat.Name
				list:Destroy()
			end)
		end
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

function WidgetUI:_addSliderRow(parent, name, label, min, max, default, order, callback)
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

	local dragging = false
	handle.MouseButton1Down:Connect(function()
		dragging = true
	end)

	handle.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local abs = sliderBg.AbsolutePosition
			local sizeX = sliderBg.AbsoluteSize.X
			local relX = math.clamp((input.Position.X - abs.X) / sizeX, 0, 1)
			local val = min + relX * (max - min)
			fill.Size = UDim2.new(relX, 0, 1, 0)
			handle.Position = UDim2.new(relX, -6, 0.5, -6)
			valLabel.Text = tostring(math.round(val * 10) / 10)
			callback(val)
		end
	end)

	sliderBg.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local abs = sliderBg.AbsolutePosition
			local sizeX = sliderBg.AbsoluteSize.X
			local relX = math.clamp((input.Position.X - abs.X) / sizeX, 0, 1)
			local val = min + relX * (max - min)
			fill.Size = UDim2.new(relX, 0, 1, 0)
			handle.Position = UDim2.new(relX, -6, 0.5, -6)
			valLabel.Text = tostring(math.round(val * 10) / 10)
			callback(val)
		end
	end)

	handle.MouseButton1Up:Connect(function() dragging = false end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

function WidgetUI:_addToggleRow(parent, name, label, default, order, callback)
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
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.BackgroundColor3 = if state then T.Colors.Positive else T.Colors.Border
		btn.Text = if state then "ON" else "OFF"
		callback(state)
	end)
end

------------------------------------------------------------------------
-- State bindings
------------------------------------------------------------------------
function WidgetUI:_bindState()
	table.insert(self._conns, self._state.modeChanged:Connect(function(mode)
		self:_highlightActiveMode(mode)
		self:_showModePanel(mode)
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
