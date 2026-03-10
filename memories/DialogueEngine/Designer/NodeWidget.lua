local Theme = require(script.Parent.DesignerTheme)

local NodeWidget = {}
NodeWidget.__index = NodeWidget

function NodeWidget.new(nodeData, canvasFrame, appState)
	local self = setmetatable({}, NodeWidget)
	self._data       = nodeData
	self._canvas     = canvasFrame
	self._state      = appState
	self._choiceDots = {}
	self._frame      = nil
	self._inputDot   = nil
	self._dragHandle = nil
	self:_build()
	return self
end

------------------------------------------------------------------------
-- Build the visual node card
------------------------------------------------------------------------
function NodeWidget:_build()
	local T = Theme
	local d = self._data

	local frame = Instance.new("Frame")
	frame.Name = "Node_" .. d.id
	frame.Size = UDim2.fromOffset(T.Sizes.NodeWidth, T.Sizes.NodeMinHeight)
	frame.Position = UDim2.fromOffset(d.x, d.y)
	frame.BackgroundColor3 = T.Colors.NodeBg
	frame.BorderSizePixel = 0
	frame.ZIndex = 2
	frame.Parent = self._canvas
	self._frame = frame

	Instance.new("UICorner", frame).CornerRadius = T.Sizes.NodeCorner

	local stroke = Instance.new("UIStroke", frame)
	stroke.Name = "Border"
	stroke.Thickness = 1
	stroke.Color = T.Colors.NodeBorder

	-- Header
	local header = Instance.new("Frame", frame)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, T.Sizes.HeaderHeight)
	header.BackgroundColor3 = self:_headerColor()
	header.BorderSizePixel = 0
	header.ZIndex = 3

	Instance.new("UICorner", header).CornerRadius = T.Sizes.NodeCorner

	local hFill = Instance.new("Frame", header)
	hFill.Name = "Fill"
	hFill.Size = UDim2.new(1, 0, 0, T.Sizes.NodeCorner.Offset)
	hFill.Position = UDim2.new(0, 0, 1, -T.Sizes.NodeCorner.Offset)
	hFill.BackgroundColor3 = header.BackgroundColor3
	hFill.BorderSizePixel = 0
	hFill.ZIndex = 3

	local label = Instance.new("TextLabel", header)
	label.Name = "Label"
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.fromOffset(5, 0)
	label.BackgroundTransparency = 1
	label.Text = d.id
	label.TextColor3 = T.Colors.TextHeader
	label.TextSize = T.Sizes.HeaderText
	label.Font = T.Fonts.Bold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 4

	-- Text preview
	local preview = Instance.new("TextLabel", frame)
	preview.Name = "Preview"
	preview.Size = UDim2.new(1, -14, 0, 36)
	preview.Position = UDim2.new(0, 7, 0, T.Sizes.HeaderHeight + 4)
	preview.BackgroundTransparency = 1
	preview.TextColor3 = d.text ~= "" and T.Colors.TextDim or T.Colors.TextPlaceholder
	preview.Text = d.text ~= "" and d.text:sub(1, 80) or "(empty)"
	preview.TextSize = T.Sizes.SmallText
	preview.Font = T.Fonts.Default
	preview.TextXAlignment = Enum.TextXAlignment.Left
	preview.TextYAlignment = Enum.TextYAlignment.Top
	preview.TextWrapped = true
	preview.TextTruncate = Enum.TextTruncate.AtEnd
	preview.ZIndex = 3

	-- Interaction handle — covers entire node; Canvas decides drag vs connect
	local dragH = Instance.new("Frame", frame)
	dragH.Name = "DragHandle"
	dragH.Size = UDim2.fromScale(1, 1)
	dragH.Position = UDim2.fromOffset(0, 0)
	dragH.BackgroundTransparency = 1
	dragH.ZIndex = 6
	self._dragHandle = dragH

	-- Input anchor (top center)
	self._inputDot = self:_makeDot("InputDot", T.Colors.InputDot,
		UDim2.new(0.5, -T.Sizes.DotRadius, 0, -T.Sizes.DotRadius), frame)

	self:_buildChoiceDots()
	self:_resize()

	-- Click to select
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._state:SelectNode(d.id)
		end
	end)
end

function NodeWidget:_makeDot(name, color, position, parent)
	local T = Theme
	local dot = Instance.new("TextButton", parent)
	dot.Name = name
	dot.Size = UDim2.fromOffset(T.Sizes.DotRadius * 2, T.Sizes.DotRadius * 2)
	dot.Position = position
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Text = ""
	dot.AutoButtonColor = false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	return dot
end

function NodeWidget:_headerColor()
	local T = Theme
	if self._state.startNodeId == self._data.id then return T.Colors.HeaderStart end
	if self._data.isEndNode then return T.Colors.HeaderEnd end
	return T.Colors.HeaderNormal
end

function NodeWidget:_buildChoiceDots()
	for _, dot in ipairs(self._choiceDots) do dot:Destroy() end
	self._choiceDots = {}

	local choices = self._data.choices or {}
	if #choices == 0 then return end

	local spacing = Theme.Sizes.NodeWidth / (#choices + 1)
	for i = 1, #choices do
		local dot = self:_makeDot("CDot_" .. i, Theme.Colors.ChoiceDot,
			UDim2.new(0, spacing * i - Theme.Sizes.DotRadius, 1, -Theme.Sizes.DotRadius),
			self._frame)
		table.insert(self._choiceDots, dot)
	end
end

function NodeWidget:_resize()
	local T = Theme
	local nChoices = #(self._data.choices or {})
	local h = T.Sizes.HeaderHeight + 44 + (nChoices > 0 and 14 or 0)
	self._frame.Size = UDim2.fromOffset(T.Sizes.NodeWidth, math.max(T.Sizes.NodeMinHeight, h))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
function NodeWidget:GetFrame() return self._frame end
function NodeWidget:GetInputDot() return self._inputDot end
function NodeWidget:GetChoiceDot(i) return self._choiceDots[i] end

function NodeWidget:GetInputDotCenter()
	return Vector2.new(self._data.x + Theme.Sizes.NodeWidth / 2, self._data.y)
end

function NodeWidget:GetChoiceDotCenter(i)
	local choices = self._data.choices or {}
	if i > #choices then return nil end
	local spacing = Theme.Sizes.NodeWidth / (#choices + 1)
	return Vector2.new(
		self._data.x + spacing * i,
		self._data.y + self._frame.AbsoluteSize.Y
	)
end

function NodeWidget:HitTestChoiceDot(localX, localY)
	local choices = self._data.choices or {}
	if #choices == 0 then return nil end
	local frameH = self._frame.AbsoluteSize.Y
	local spacing = Theme.Sizes.NodeWidth / (#choices + 1)
	local hitR = Theme.Sizes.DotRadius + 4
	for i = 1, #choices do
		local cx = spacing * i
		local cy = frameH - Theme.Sizes.DotRadius
		local dx = localX - cx
		local dy = localY - cy
		if dx * dx + dy * dy <= hitR * hitR then
			return i
		end
	end
	return nil
end

function NodeWidget:GetHeaderFrame()
	return self._frame and self._frame:FindFirstChild("Header")
end

function NodeWidget:GetDragHandleFrame()
	return self._dragHandle
end

function NodeWidget:UpdateData(nodeData)
	self._data = nodeData
	self._frame.Name = "Node_" .. nodeData.id
	self._frame.Position = UDim2.fromOffset(nodeData.x, nodeData.y)

	local header = self._frame:FindFirstChild("Header")
	if header then
		local c = self:_headerColor()
		header.BackgroundColor3 = c
		local fill = header:FindFirstChild("Fill")
		if fill then fill.BackgroundColor3 = c end
		local lbl = header:FindFirstChild("Label")
		if lbl then lbl.Text = nodeData.id end
	end

	local preview = self._frame:FindFirstChild("Preview")
	if preview then
		preview.Text = nodeData.text ~= "" and nodeData.text:sub(1, 80) or "(empty)"
		preview.TextColor3 = nodeData.text ~= "" and Theme.Colors.TextDim or Theme.Colors.TextPlaceholder
	end

	self:_buildChoiceDots()
	self:_resize()
end

function NodeWidget:SetSelected(selected)
	local s = self._frame:FindFirstChild("Border")
	if s then
		s.Color = selected and Theme.Colors.NodeSelected or Theme.Colors.NodeBorder
		s.Thickness = selected and 2 or 1
	end
end

function NodeWidget:SetPosition(x, y)
	self._frame.Position = UDim2.fromOffset(x, y)
end

function NodeWidget:Destroy()
	if self._frame then self._frame:Destroy(); self._frame = nil end
end

return NodeWidget
