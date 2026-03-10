local Theme = require(script.Parent.DesignerTheme)

local PropertyPanel = {}
PropertyPanel.__index = PropertyPanel

function PropertyPanel.new(parent, appState)
	local self = setmetatable({}, PropertyPanel)
	self._state      = appState
	self._conns      = {}
	self._frame      = nil
	self._scroll     = nil
	self._nodeId     = nil
	self._fieldOrder = {}
	self:_build(parent)
	self:_bindState()
	return self
end

------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------
local function makeLabel(parent, text, yOff)
	local T = Theme
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 18)
	lbl.Position = UDim2.new(0, 8, 0, yOff)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = T.Colors.TextDim
	lbl.TextSize = T.Sizes.SmallText
	lbl.Font = T.Fonts.Bold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

local function makeField(parent, yOff, placeholder, multiline)
	local T = Theme
	local h = multiline and 60 or T.Sizes.FieldHeight
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -16, 0, h)
	box.Position = UDim2.new(0, 8, 0, yOff)
	box.BackgroundColor3 = T.Colors.Field
	box.BorderSizePixel = 0
	box.TextColor3 = T.Colors.Text
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = T.Colors.TextPlaceholder
	box.TextSize = T.Sizes.Text
	box.Font = T.Fonts.Default
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.TextWrapped = multiline or false
	box.MultiLine = multiline or false
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", box).Color = T.Colors.FieldBorder
	return box
end

local function makeCheckbox(parent, text, yOff)
	local T = Theme
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 22)
	row.Position = UDim2.new(0, 8, 0, yOff)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local box = Instance.new("TextButton", row)
	box.Name = "Check"
	box.Size = UDim2.fromOffset(18, 18)
	box.Position = UDim2.fromOffset(0, 2)
	box.BackgroundColor3 = T.Colors.Field
	box.Text = ""
	box.BorderSizePixel = 0
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
	Instance.new("UIStroke", box).Color = T.Colors.FieldBorder

	local tick = Instance.new("TextLabel", box)
	tick.Name = "Tick"
	tick.Size = UDim2.fromScale(1, 1)
	tick.BackgroundTransparency = 1
	tick.Text = ""
	tick.TextColor3 = T.Colors.Text
	tick.TextSize = 14
	tick.Font = T.Fonts.Bold

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1, -24, 1, 0)
	lbl.Position = UDim2.fromOffset(24, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = T.Colors.Text
	lbl.TextSize = T.Sizes.Text
	lbl.Font = T.Fonts.Default
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	return row, box, tick
end

local function makeButton(parent, text, yOff, color)
	local T = Theme
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, T.Sizes.BtnHeight)
	btn.Position = UDim2.new(0, 8, 0, yOff)
	btn.BackgroundColor3 = color or T.Colors.BtnNormal
	btn.TextColor3 = T.Colors.Text
	btn.Text = text
	btn.TextSize = T.Sizes.Text
	btn.Font = T.Fonts.Default
	btn.BorderSizePixel = 0
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	return btn
end

local function makeSeparator(parent, yOff, text)
	local T = Theme
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 22)
	lbl.Position = UDim2.new(0, 8, 0, yOff)
	lbl.BackgroundTransparency = 1
	lbl.Text = "── " .. text .. " ──"
	lbl.TextColor3 = T.Colors.Accent
	lbl.TextSize = T.Sizes.SmallText
	lbl.Font = T.Fonts.Bold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

------------------------------------------------------------------------
-- Field navigation helpers
------------------------------------------------------------------------
function PropertyPanel:_registerField(box)
	table.insert(self._fieldOrder, box)
	table.insert(self._conns, box.FocusLost:Connect(function(enterPressed)
		if enterPressed and not box.MultiLine then
			self:_focusNextField(box)
		end
	end))
	table.insert(self._conns, box.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab then
			box:ReleaseFocus()
			self:_focusNextField(box)
		end
	end))
end

function PropertyPanel:_focusNextField(currentBox)
	for i, field in ipairs(self._fieldOrder) do
		if field == currentBox then
			local nextField = self._fieldOrder[i + 1]
			if nextField and nextField.Parent then
				task.defer(function()
					nextField:CaptureFocus()
				end)
			end
			return
		end
	end
end

------------------------------------------------------------------------
-- Build panel frame
------------------------------------------------------------------------
function PropertyPanel:_build(parent)
	local T = Theme

	local panel = Instance.new("Frame")
	panel.Name = "PropertyPanel"
	panel.Size = UDim2.new(0, T.Sizes.PanelWidth, 1, -T.Sizes.ToolbarHeight - T.Sizes.StatusHeight)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, 0, 0, T.Sizes.ToolbarHeight)
	panel.BackgroundColor3 = T.Colors.Panel
	panel.BorderSizePixel = 0
	panel.ZIndex = 5
	panel.Parent = parent
	self._frame = panel

	local scroll = Instance.new("ScrollingFrame", panel)
	scroll.Name = "Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.BorderSizePixel = 0
	self._scroll = scroll

	self:_showEmpty()
end

------------------------------------------------------------------------
-- Empty state / populated state
------------------------------------------------------------------------
function PropertyPanel:_showEmpty()
	self._nodeId = nil
	self:_clearScroll()
	local T = Theme
	local lbl = Instance.new("TextLabel", self._scroll)
	lbl.Size = UDim2.new(1, 0, 0, 40)
	lbl.Position = UDim2.fromOffset(0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Select a node to edit"
	lbl.TextColor3 = T.Colors.TextDim
	lbl.TextSize = T.Sizes.Text
	lbl.Font = T.Fonts.Default
	local w = math.max(200, T.Sizes.PanelWidth - 24)
	self._scroll.CanvasSize = UDim2.fromOffset(w, 60)
end

function PropertyPanel:_clearScroll()
	for _, c in ipairs(self._conns) do c:Disconnect() end
	self._conns = {}
	self._fieldOrder = {}
	for _, child in ipairs(self._scroll:GetChildren()) do
		child:Destroy()
	end
end

function PropertyPanel:_populateNode(nodeId)
	self._nodeId = nodeId
	self:_clearScroll()

	local node = self._state.nodes[nodeId]
	if not node then self:_showEmpty(); return end

	local T = Theme
	local y = 8

	-- Node ID
	makeLabel(self._scroll, "NODE ID", y); y = y + 18
	local idField = makeField(self._scroll, y, "node_id"); y = y + T.Sizes.FieldHeight + 8
	idField.Text = node.id
	self:_registerField(idField)
	table.insert(self._conns, idField.FocusLost:Connect(function()
		local newId = idField.Text:gsub("%s", "_"):gsub("[^%w_]", "")
		if newId == "" or newId == node.id then idField.Text = node.id; return end
		if self._state.nodes[newId] then idField.Text = node.id; return end
		self._state:UpdateNode(nodeId, { id = newId })
		self._nodeId = newId
	end))

	-- Speaker (dropdown with NPC configs + custom fallback)
	makeLabel(self._scroll, "SPEAKER (optional)", y); y = y + 18
	local npcs = self._state:GetNPCs()

	if #npcs > 0 then
		local speakerBtn = Instance.new("TextButton", self._scroll)
		speakerBtn.Size = UDim2.new(1, -16, 0, T.Sizes.FieldHeight)
		speakerBtn.Position = UDim2.new(0, 8, 0, y)
		speakerBtn.BackgroundColor3 = T.Colors.Field
		speakerBtn.TextColor3 = node.speaker and T.Colors.Text or T.Colors.TextPlaceholder
		speakerBtn.Text = node.speaker or "Select speaker..."
		speakerBtn.TextSize = T.Sizes.Text
		speakerBtn.Font = T.Fonts.Default
		speakerBtn.TextXAlignment = Enum.TextXAlignment.Left
		speakerBtn.BorderSizePixel = 0
		speakerBtn.AutoButtonColor = false
		Instance.new("UICorner", speakerBtn).CornerRadius = UDim.new(0, 4)
		Instance.new("UIStroke", speakerBtn).Color = T.Colors.FieldBorder
		Instance.new("UIPadding", speakerBtn).PaddingLeft = UDim.new(0, 6)
		y = y + T.Sizes.FieldHeight + 2

		local dropdown = nil
		table.insert(self._conns, speakerBtn.MouseButton1Click:Connect(function()
			if dropdown then dropdown:Destroy(); dropdown = nil; return end

			dropdown = Instance.new("Frame", self._scroll)
			dropdown.Size = UDim2.new(1, -16, 0, (#npcs + 2) * 24 + 4)
			dropdown.Position = UDim2.new(0, 8, 0, y)
			dropdown.BackgroundColor3 = T.Colors.Toolbar
			dropdown.BorderSizePixel = 0
			dropdown.ZIndex = 20
			Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 4)
			Instance.new("UIStroke", dropdown).Color = T.Colors.FieldBorder

			local dy = 2
			for _, npc in ipairs(npcs) do
				local opt = Instance.new("TextButton", dropdown)
				opt.Size = UDim2.new(1, -4, 0, 22)
				opt.Position = UDim2.fromOffset(2, dy)
				opt.BackgroundColor3 = T.Colors.BtnNormal
				opt.TextColor3 = T.Colors.Text
				opt.Text = npc.displayName
				opt.TextSize = T.Sizes.SmallText
				opt.Font = T.Fonts.Default
				opt.BorderSizePixel = 0
				opt.ZIndex = 21
				Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 3)
				opt.MouseButton1Click:Connect(function()
					self._state:UpdateNode(self._nodeId, { speaker = npc.displayName })
					if dropdown then dropdown:Destroy(); dropdown = nil end
				end)
				dy = dy + 24
			end

			-- "None" option
			local noneOpt = Instance.new("TextButton", dropdown)
			noneOpt.Size = UDim2.new(1, -4, 0, 22)
			noneOpt.Position = UDim2.fromOffset(2, dy)
			noneOpt.BackgroundColor3 = T.Colors.BtnNormal
			noneOpt.TextColor3 = T.Colors.TextDim
			noneOpt.Text = "(none)"
			noneOpt.TextSize = T.Sizes.SmallText
			noneOpt.Font = T.Fonts.Default
			noneOpt.BorderSizePixel = 0
			noneOpt.ZIndex = 21
			Instance.new("UICorner", noneOpt).CornerRadius = UDim.new(0, 3)
			noneOpt.MouseButton1Click:Connect(function()
				self._state:UpdateNode(self._nodeId, { speaker = nil })
				if dropdown then dropdown:Destroy(); dropdown = nil end
			end)
			dy = dy + 24

			-- "Custom..." option
			local customOpt = Instance.new("TextButton", dropdown)
			customOpt.Size = UDim2.new(1, -4, 0, 22)
			customOpt.Position = UDim2.fromOffset(2, dy)
			customOpt.BackgroundColor3 = T.Colors.BtnNormal
			customOpt.TextColor3 = T.Colors.ConnConditional
			customOpt.Text = "Custom..."
			customOpt.TextSize = T.Sizes.SmallText
			customOpt.Font = T.Fonts.Bold
			customOpt.BorderSizePixel = 0
			customOpt.ZIndex = 21
			Instance.new("UICorner", customOpt).CornerRadius = UDim.new(0, 3)
			customOpt.MouseButton1Click:Connect(function()
				if dropdown then dropdown:Destroy(); dropdown = nil end
				-- Replace button with a text field temporarily
				speakerBtn.Visible = false
				local customField = makeField(self._scroll, speakerBtn.Position.Y.Offset, "NPC name")
				customField.Text = node.speaker or ""
				customField:CaptureFocus()
				customField.FocusLost:Connect(function()
					local val = customField.Text ~= "" and customField.Text or nil
					self._state:UpdateNode(self._nodeId, { speaker = val })
					customField:Destroy()
				end)
			end)
		end))

		y = y + 6
	else
		local speakerField = makeField(self._scroll, y, "NPC name"); y = y + T.Sizes.FieldHeight + 8
		speakerField.Text = node.speaker or ""
		table.insert(self._conns, speakerField.FocusLost:Connect(function()
			local val = speakerField.Text ~= "" and speakerField.Text or nil
			self._state:UpdateNode(self._nodeId, { speaker = val })
		end))
	end

	-- Text
	makeLabel(self._scroll, "DIALOGUE TEXT", y); y = y + 18
	local textField = makeField(self._scroll, y, "What does the NPC say?", true); y = y + 68
	textField.Text = node.text or ""
	self:_registerField(textField)
	table.insert(self._conns, textField.FocusLost:Connect(function()
		self._state:UpdateNode(self._nodeId, { text = textField.Text })
	end))

	-- End Node checkbox
	local _, endCheck, endTick = makeCheckbox(self._scroll, "End node (closes dialogue)", y); y = y + 28
	endTick.Text = node.isEndNode and "✓" or ""
	table.insert(self._conns, endCheck.MouseButton1Click:Connect(function()
		local newVal = not node.isEndNode
		self._state:UpdateNode(self._nodeId, { isEndNode = newVal })
		endTick.Text = newVal and "✓" or ""
		node = self._state.nodes[self._nodeId]
	end))

	-- Auto-advance delay
	makeLabel(self._scroll, "AUTO-ADVANCE DELAY (seconds)", y); y = y + 18
	local autoField = makeField(self._scroll, y, "none"); y = y + T.Sizes.FieldHeight + 8
	autoField.Text = node.autoAdvanceDelay and tostring(node.autoAdvanceDelay) or ""
	self:_registerField(autoField)
	table.insert(self._conns, autoField.FocusLost:Connect(function()
		local val = tonumber(autoField.Text)
		self._state:UpdateNode(self._nodeId, { autoAdvanceDelay = val })
	end))

	-- Node actions
	makeSeparator(self._scroll, y, "Node Actions"); y = y + 26
	y = self:_buildActionList(node.actions, y, function(actions)
		self._state:UpdateNode(self._nodeId, { actions = actions })
	end)

	-- Choices
	makeSeparator(self._scroll, y, "Choices"); y = y + 26

	for i, choice in ipairs(node.choices or {}) do
		y = self:_buildChoiceEditor(i, choice, y)
	end

	local addChoiceBtn = makeButton(self._scroll, "+ Add Choice", y, T.Colors.Accent); y = y + T.Sizes.BtnHeight + 8
	table.insert(self._conns, addChoiceBtn.MouseButton1Click:Connect(function()
		self._state:AddChoice(self._nodeId)
	end))

	-- Set as start node
	makeSeparator(self._scroll, y, "Node"); y = y + 26
	local startBtn = makeButton(self._scroll, "Set as Start Node", y, T.Colors.BtnNormal); y = y + T.Sizes.BtnHeight + 6
	table.insert(self._conns, startBtn.MouseButton1Click:Connect(function()
		self._state:SetStartNode(self._nodeId)
	end))

	local delBtn = makeButton(self._scroll, "Delete Node", y, T.Colors.BtnDanger); y = y + T.Sizes.BtnHeight + 16
	table.insert(self._conns, delBtn.MouseButton1Click:Connect(function()
		self._state:RemoveNode(self._nodeId)
	end))

	local w = math.max(200, T.Sizes.PanelWidth - 24)
	self._scroll.CanvasSize = UDim2.fromOffset(w, y)
end

------------------------------------------------------------------------
-- Action list builder (reused for node-level and choice-level actions)
------------------------------------------------------------------------
function PropertyPanel:_buildActionList(actions, y, onChange)
	local T = Theme
	actions = actions or {}

	for i, action in ipairs(actions) do
		local row = Instance.new("Frame", self._scroll)
		row.Size = UDim2.new(1, -16, 0, T.Sizes.FieldHeight)
		row.Position = UDim2.new(0, 8, 0, y)
		row.BackgroundTransparency = 1

		local typeBtn = Instance.new("TextButton", row)
		typeBtn.Size = UDim2.fromOffset(40, T.Sizes.FieldHeight)
		typeBtn.BackgroundColor3 = action.type == "call" and T.Colors.ConnAction or T.Colors.ConnConditional
		typeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		typeBtn.Text = action.type
		typeBtn.TextSize = T.Sizes.SmallText
		typeBtn.Font = T.Fonts.Bold
		typeBtn.BorderSizePixel = 0
		Instance.new("UICorner", typeBtn).CornerRadius = UDim.new(0, 3)

		table.insert(self._conns, typeBtn.MouseButton1Click:Connect(function()
			action.type = action.type == "set" and "call" or "set"
			if action.type == "call" then action.value = nil end
			onChange(actions)
			self:_populateNode(self._nodeId)
		end))

		local keyBox = Instance.new("TextBox", row)
		keyBox.Size = UDim2.new(0.5, -30, 1, 0)
		keyBox.Position = UDim2.fromOffset(44, 0)
		keyBox.BackgroundColor3 = T.Colors.Field
		keyBox.TextColor3 = T.Colors.Text
		keyBox.PlaceholderText = "key"
		keyBox.PlaceholderColor3 = T.Colors.TextPlaceholder
		keyBox.Text = action.key or ""
		keyBox.TextSize = T.Sizes.SmallText
		keyBox.Font = T.Fonts.Mono
		keyBox.BorderSizePixel = 0
		keyBox.ClearTextOnFocus = false
		Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 3)

		table.insert(self._conns, keyBox.FocusLost:Connect(function()
			action.key = keyBox.Text
			onChange(actions)
		end))

		if action.type == "set" then
			local valBox = Instance.new("TextBox", row)
			valBox.Size = UDim2.new(0.3, -10, 1, 0)
			valBox.Position = UDim2.new(0.5, 18, 0, 0)
			valBox.BackgroundColor3 = T.Colors.Field
			valBox.TextColor3 = T.Colors.Text
			valBox.PlaceholderText = "value"
			valBox.PlaceholderColor3 = T.Colors.TextPlaceholder
			valBox.Text = action.value ~= nil and tostring(action.value) or ""
			valBox.TextSize = T.Sizes.SmallText
			valBox.Font = T.Fonts.Mono
			valBox.BorderSizePixel = 0
			valBox.ClearTextOnFocus = false
			Instance.new("UICorner", valBox).CornerRadius = UDim.new(0, 3)

			table.insert(self._conns, valBox.FocusLost:Connect(function()
				local raw = valBox.Text
				if raw == "true" then action.value = true
				elseif raw == "false" then action.value = false
				else action.value = tonumber(raw) or raw end
				onChange(actions)
			end))
		end

		local rmBtn = Instance.new("TextButton", row)
		rmBtn.Size = UDim2.fromOffset(20, T.Sizes.FieldHeight)
		rmBtn.Position = UDim2.new(1, -20, 0, 0)
		rmBtn.BackgroundColor3 = T.Colors.BtnDanger
		rmBtn.TextColor3 = T.Colors.Text
		rmBtn.Text = "X"
		rmBtn.TextSize = T.Sizes.SmallText
		rmBtn.Font = T.Fonts.Bold
		rmBtn.BorderSizePixel = 0
		Instance.new("UICorner", rmBtn).CornerRadius = UDim.new(0, 3)

		table.insert(self._conns, rmBtn.MouseButton1Click:Connect(function()
			table.remove(actions, i)
			onChange(actions)
			self:_populateNode(self._nodeId)
		end))

		y = y + T.Sizes.FieldHeight + 4
	end

	local addBtn = makeButton(self._scroll, "+ Action", y, T.Colors.BtnNormal)
	addBtn.Size = UDim2.new(0.4, 0, 0, 22)
	addBtn.Position = UDim2.new(0, 8, 0, y)
	addBtn.TextSize = T.Sizes.SmallText
	table.insert(self._conns, addBtn.MouseButton1Click:Connect(function()
		table.insert(actions, { type = "set", key = "", value = true })
		onChange(actions)
		self:_populateNode(self._nodeId)
	end))

	return y + 28
end

------------------------------------------------------------------------
-- Choice editor (one per choice)
------------------------------------------------------------------------
function PropertyPanel:_buildChoiceEditor(choiceIdx, choice, y)
	local T = Theme
	local nodeId = self._nodeId

	local container = Instance.new("Frame", self._scroll)
	container.Size = UDim2.new(1, -16, 0, 10) -- resized below
	container.Position = UDim2.new(0, 8, 0, y)
	container.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
	container.BorderSizePixel = 0
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)

	local innerY = 6

	-- Choice header
	local hdr = Instance.new("TextLabel", container)
	hdr.Size = UDim2.new(1, -30, 0, 16)
	hdr.Position = UDim2.fromOffset(6, innerY)
	hdr.BackgroundTransparency = 1
	hdr.Text = "Choice " .. choiceIdx
	hdr.TextColor3 = T.Colors.ChoiceDot
	hdr.TextSize = T.Sizes.SmallText
	hdr.Font = T.Fonts.Bold
	hdr.TextXAlignment = Enum.TextXAlignment.Left

	local rmChoice = Instance.new("TextButton", container)
	rmChoice.Size = UDim2.fromOffset(20, 16)
	rmChoice.Position = UDim2.new(1, -26, 0, innerY)
	rmChoice.BackgroundColor3 = T.Colors.BtnDanger
	rmChoice.TextColor3 = T.Colors.Text
	rmChoice.Text = "X"
	rmChoice.TextSize = 11
	rmChoice.Font = T.Fonts.Bold
	rmChoice.BorderSizePixel = 0
	Instance.new("UICorner", rmChoice).CornerRadius = UDim.new(0, 3)

	table.insert(self._conns, rmChoice.MouseButton1Click:Connect(function()
		self._state:RemoveChoice(nodeId, choiceIdx)
	end))

	innerY = innerY + 20

	-- Choice text
	local ctBox = Instance.new("TextBox", container)
	ctBox.Size = UDim2.new(1, -12, 0, T.Sizes.FieldHeight)
	ctBox.Position = UDim2.fromOffset(6, innerY)
	ctBox.BackgroundColor3 = T.Colors.Field
	ctBox.TextColor3 = T.Colors.Text
	ctBox.PlaceholderText = "Choice text"
	ctBox.PlaceholderColor3 = T.Colors.TextPlaceholder
	ctBox.Text = choice.text or ""
	ctBox.TextSize = T.Sizes.SmallText
	ctBox.Font = T.Fonts.Default
	ctBox.BorderSizePixel = 0
	ctBox.ClearTextOnFocus = false
	Instance.new("UICorner", ctBox).CornerRadius = UDim.new(0, 3)

	self:_registerField(ctBox)
	table.insert(self._conns, ctBox.FocusLost:Connect(function()
		self._state:UpdateChoice(nodeId, choiceIdx, { text = ctBox.Text })
	end))
	if choice.text == "New choice" then
		table.insert(self._conns, ctBox.Focused:Connect(function()
			if ctBox.Text == "New choice" then
				ctBox.CursorPosition = #ctBox.Text + 1
				ctBox.SelectionStart = 1
			end
		end))
	end
	innerY = innerY + T.Sizes.FieldHeight + 4

	-- Target node
	local tgtLabel = Instance.new("TextLabel", container)
	tgtLabel.Size = UDim2.fromOffset(14, 16)
	tgtLabel.Position = UDim2.fromOffset(6, innerY + 4)
	tgtLabel.BackgroundTransparency = 1
	tgtLabel.Text = "→"
	tgtLabel.TextColor3 = T.Colors.TextDim
	tgtLabel.TextSize = T.Sizes.Text
	tgtLabel.Font = T.Fonts.Bold

	local tgtBox = Instance.new("TextBox", container)
	tgtBox.Size = UDim2.new(1, -32, 0, T.Sizes.FieldHeight)
	tgtBox.Position = UDim2.fromOffset(22, innerY)
	tgtBox.BackgroundColor3 = T.Colors.Field
	tgtBox.TextColor3 = T.Colors.Text
	tgtBox.PlaceholderText = "target_node"
	tgtBox.PlaceholderColor3 = T.Colors.TextPlaceholder
	tgtBox.Text = choice.targetNodeId or ""
	tgtBox.TextSize = T.Sizes.SmallText
	tgtBox.Font = T.Fonts.Mono
	tgtBox.BorderSizePixel = 0
	tgtBox.ClearTextOnFocus = false
	Instance.new("UICorner", tgtBox).CornerRadius = UDim.new(0, 3)

	self:_registerField(tgtBox)
	table.insert(self._conns, tgtBox.FocusLost:Connect(function()
		local val = tgtBox.Text ~= "" and tgtBox.Text or nil
		self._state:UpdateChoice(nodeId, choiceIdx, { targetNodeId = val })
	end))
	innerY = innerY + T.Sizes.FieldHeight + 4

	-- Condition (single key=value for simplicity)
	local condKey = ""
	local condVal = ""
	if choice.conditions then
		for k, v in pairs(choice.conditions) do
			condKey = k; condVal = tostring(v); break
		end
	end

	local condLabel = Instance.new("TextLabel", container)
	condLabel.Size = UDim2.fromOffset(60, 16)
	condLabel.Position = UDim2.fromOffset(6, innerY + 4)
	condLabel.BackgroundTransparency = 1
	condLabel.Text = "if"
	condLabel.TextColor3 = T.Colors.ConnConditional
	condLabel.TextSize = T.Sizes.SmallText
	condLabel.Font = T.Fonts.Bold
	condLabel.TextXAlignment = Enum.TextXAlignment.Left

	local ckBox = Instance.new("TextBox", container)
	ckBox.Size = UDim2.new(0.4, -12, 0, 22)
	ckBox.Position = UDim2.fromOffset(22, innerY)
	ckBox.BackgroundColor3 = T.Colors.Field
	ckBox.TextColor3 = T.Colors.Text
	ckBox.PlaceholderText = "key"
	ckBox.PlaceholderColor3 = T.Colors.TextPlaceholder
	ckBox.Text = condKey
	ckBox.TextSize = T.Sizes.SmallText
	ckBox.Font = T.Fonts.Mono
	ckBox.BorderSizePixel = 0
	ckBox.ClearTextOnFocus = false
	Instance.new("UICorner", ckBox).CornerRadius = UDim.new(0, 3)

	local cvBox = Instance.new("TextBox", container)
	cvBox.Size = UDim2.new(0.4, -12, 0, 22)
	cvBox.Position = UDim2.new(0.45, 6, 0, innerY)
	cvBox.BackgroundColor3 = T.Colors.Field
	cvBox.TextColor3 = T.Colors.Text
	cvBox.PlaceholderText = "value"
	cvBox.PlaceholderColor3 = T.Colors.TextPlaceholder
	cvBox.Text = condVal
	cvBox.TextSize = T.Sizes.SmallText
	cvBox.Font = T.Fonts.Mono
	cvBox.BorderSizePixel = 0
	cvBox.ClearTextOnFocus = false
	Instance.new("UICorner", cvBox).CornerRadius = UDim.new(0, 3)

	local function updateCond()
		local k = ckBox.Text
		local v = cvBox.Text
		local cond = {}
		if k ~= "" and v ~= "" then
			local parsed = v
			if parsed == "true" then parsed = true
			elseif parsed == "false" then parsed = false
			else parsed = tonumber(parsed) or parsed end
			cond[k] = parsed
		end
		self._state:UpdateChoice(nodeId, choiceIdx, { conditions = cond })
	end
	table.insert(self._conns, ckBox.FocusLost:Connect(updateCond))
	table.insert(self._conns, cvBox.FocusLost:Connect(updateCond))

	innerY = innerY + 26

	-- Hide when unavailable
	local hideRow = Instance.new("Frame", container)
	hideRow.Size = UDim2.new(1, -12, 0, 20)
	hideRow.Position = UDim2.fromOffset(6, innerY)
	hideRow.BackgroundTransparency = 1

	local hideBox = Instance.new("TextButton", hideRow)
	hideBox.Size = UDim2.fromOffset(16, 16)
	hideBox.Position = UDim2.fromOffset(0, 2)
	hideBox.BackgroundColor3 = T.Colors.Field
	hideBox.Text = ""
	hideBox.BorderSizePixel = 0
	Instance.new("UICorner", hideBox).CornerRadius = UDim.new(0, 3)
	Instance.new("UIStroke", hideBox).Color = T.Colors.FieldBorder

	local hideTick = Instance.new("TextLabel", hideBox)
	hideTick.Size = UDim2.fromScale(1, 1)
	hideTick.BackgroundTransparency = 1
	hideTick.Text = choice.hideWhenUnavailable and "✓" or ""
	hideTick.TextColor3 = T.Colors.Text
	hideTick.TextSize = 12
	hideTick.Font = T.Fonts.Bold

	local hideLbl = Instance.new("TextLabel", hideRow)
	hideLbl.Size = UDim2.new(1, -22, 1, 0)
	hideLbl.Position = UDim2.fromOffset(22, 0)
	hideLbl.BackgroundTransparency = 1
	hideLbl.Text = "Hide when unavailable"
	hideLbl.TextColor3 = T.Colors.TextDim
	hideLbl.TextSize = T.Sizes.SmallText
	hideLbl.Font = T.Fonts.Default
	hideLbl.TextXAlignment = Enum.TextXAlignment.Left

	table.insert(self._conns, hideBox.MouseButton1Click:Connect(function()
		local newVal = not choice.hideWhenUnavailable
		self._state:UpdateChoice(nodeId, choiceIdx, { hideWhenUnavailable = newVal })
		hideTick.Text = newVal and "✓" or ""
		choice.hideWhenUnavailable = newVal
	end))

	innerY = innerY + 24

	-- Choice-level actions
	local actLabel = Instance.new("TextLabel", container)
	actLabel.Size = UDim2.new(1, -12, 0, 16)
	actLabel.Position = UDim2.fromOffset(6, innerY)
	actLabel.BackgroundTransparency = 1
	actLabel.Text = "Actions:"
	actLabel.TextColor3 = T.Colors.ConnAction
	actLabel.TextSize = T.Sizes.SmallText
	actLabel.Font = T.Fonts.Bold
	actLabel.TextXAlignment = Enum.TextXAlignment.Left
	innerY = innerY + 18

	local choiceActions = choice.actions or {}
	for ai, action in ipairs(choiceActions) do
		local aRow = Instance.new("Frame", container)
		aRow.Size = UDim2.new(1, -12, 0, 22)
		aRow.Position = UDim2.fromOffset(6, innerY)
		aRow.BackgroundTransparency = 1

		local summary = action.type .. " " .. (action.key or "")
		if action.type == "set" and action.value ~= nil then
			summary = summary .. " " .. tostring(action.value)
		end

		local aLbl = Instance.new("TextLabel", aRow)
		aLbl.Size = UDim2.new(1, -24, 1, 0)
		aLbl.BackgroundTransparency = 1
		aLbl.Text = summary
		aLbl.TextColor3 = T.Colors.Text
		aLbl.TextSize = T.Sizes.SmallText
		aLbl.Font = T.Fonts.Mono
		aLbl.TextXAlignment = Enum.TextXAlignment.Left

		local aRm = Instance.new("TextButton", aRow)
		aRm.Size = UDim2.fromOffset(18, 18)
		aRm.Position = UDim2.new(1, -18, 0, 2)
		aRm.BackgroundColor3 = T.Colors.BtnDanger
		aRm.TextColor3 = T.Colors.Text
		aRm.Text = "X"
		aRm.TextSize = 10
		aRm.Font = T.Fonts.Bold
		aRm.BorderSizePixel = 0
		Instance.new("UICorner", aRm).CornerRadius = UDim.new(0, 3)

		table.insert(self._conns, aRm.MouseButton1Click:Connect(function()
			table.remove(choiceActions, ai)
			self._state:UpdateChoice(nodeId, choiceIdx, { actions = choiceActions })
		end))

		innerY = innerY + 24
	end

	local addCA = Instance.new("TextButton", container)
	addCA.Size = UDim2.new(0.5, -6, 0, 20)
	addCA.Position = UDim2.fromOffset(6, innerY)
	addCA.BackgroundColor3 = T.Colors.BtnNormal
	addCA.TextColor3 = T.Colors.Text
	addCA.Text = "+ Action"
	addCA.TextSize = T.Sizes.SmallText
	addCA.Font = T.Fonts.Default
	addCA.BorderSizePixel = 0
	Instance.new("UICorner", addCA).CornerRadius = UDim.new(0, 3)

	table.insert(self._conns, addCA.MouseButton1Click:Connect(function()
		table.insert(choiceActions, { type = "set", key = "", value = true })
		self._state:UpdateChoice(nodeId, choiceIdx, { actions = choiceActions })
	end))

	innerY = innerY + 28

	container.Size = UDim2.new(1, -16, 0, innerY)
	return y + innerY + 6
end

------------------------------------------------------------------------
-- State binding
------------------------------------------------------------------------
function PropertyPanel:_bindState()
	self._state.selectionChanged:Connect(function(nodeId)
		if nodeId then
			self:_populateNode(nodeId)
		else
			self:_showEmpty()
		end
	end)

	self._state.nodeUpdated:Connect(function(nodeId)
		if nodeId == self._nodeId then
			self:_populateNode(nodeId)
		end
	end)

	self._state.nodeRemoved:Connect(function(nodeId)
		if nodeId == self._nodeId then
			self:_showEmpty()
		end
	end)

	self._state.stateLoaded:Connect(function()
		self:_showEmpty()
	end)
end

function PropertyPanel:Destroy()
	self:_clearScroll()
	if self._frame then self._frame:Destroy() end
end

return PropertyPanel
