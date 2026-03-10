local Theme                = require(script.Parent.DesignerTheme)
local NodeWidget           = require(script.Parent.NodeWidget)
local ConnectionRenderer   = require(script.Parent.ConnectionRenderer)
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")

local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(parent, appState)
	local self = setmetatable({}, Canvas)
	self._state       = appState
	self._widgets     = {}   -- [nodeId] → NodeWidget
	self._conns       = nil  -- ConnectionRenderer
	self._scroll      = nil
	self._inner       = nil
	self._widget      = parent
	self._drag        = nil  -- { nodeId, startMouse: Vector2, startPos: Vector2 }
	self._connecting  = nil  -- { nodeId, choiceIndex }
	self._overlay     = nil
	self._uisConn     = nil  -- UserInputService.InputEnded fallback
	self._heartbeat   = nil  -- RunService.Heartbeat for mouse-position polling
	self:_build(parent)
	self:_bindState()
	return self
end

------------------------------------------------------------------------
-- Build the scrollable canvas
------------------------------------------------------------------------
function Canvas:_build(parent)
	local T = Theme
	local CS = T.Sizes.CanvasSize

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Canvas"
	scroll.Size = UDim2.new(1, -T.Sizes.PanelWidth, 1, -T.Sizes.ToolbarHeight - T.Sizes.StatusHeight)
	scroll.Position = UDim2.fromOffset(0, T.Sizes.ToolbarHeight)
	scroll.BackgroundColor3 = T.Colors.Canvas
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
	scroll.CanvasSize = UDim2.fromOffset(CS, CS)
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.CanvasPosition = Vector2.new(CS / 2 - 300, CS / 2 - 200)
	scroll.ZIndex = 1
	scroll.Parent = parent
	self._scroll = scroll

	local inner = Instance.new("Frame", scroll)
	inner.Name = "Inner"
	inner.Size = UDim2.fromOffset(CS, CS)
	inner.BackgroundTransparency = 1
	inner.ZIndex = 1
	self._inner = inner

	self:_drawGrid()

	self._conns = ConnectionRenderer.new(inner)

	-- Right-click context menu
	scroll.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local cx, cy = self:_screenToCanvas(input.Position.X, input.Position.Y)
			self:_showContextMenu(cx, cy)
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_dismissContextMenu()
			if not self._drag and not self._connecting then
				self._state:SelectNode(nil)
			end
		end
	end)
end

------------------------------------------------------------------------
-- Coordinate helpers
------------------------------------------------------------------------
function Canvas:_screenToCanvas(sx, sy)
	local abs = self._scroll.AbsolutePosition
	local cp  = self._scroll.CanvasPosition
	return sx - abs.X + cp.X, sy - abs.Y + cp.Y
end

------------------------------------------------------------------------
-- Drag overlay — captures all mouse input during a drag
------------------------------------------------------------------------
function Canvas:_createOverlay()
	if self._overlay then return end
	local ov = Instance.new("Frame")
	ov.Name = "DragOverlay"
	ov.Size = UDim2.fromScale(1, 1)
	ov.BackgroundTransparency = 0.999
	ov.BackgroundColor3 = Color3.new(0, 0, 0)
	ov.Active = true
	ov.ZIndex = 40
	ov.Parent = self._widget
	self._overlay = ov

	ov.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_onMouseMove(input.Position.X, input.Position.Y)
		end
	end)
	ov.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_onMouseUp(input.Position.X, input.Position.Y)
		end
	end)

	-- Heartbeat fallback: poll mouse position via the DockWidgetPluginGui
	-- in case overlay InputChanged doesn't fire (known Studio quirk)
	local pluginWidget = self._widget.Parent
	if pluginWidget and pluginWidget:IsA("DockWidgetPluginGui") then
		self._heartbeat = RunService.Heartbeat:Connect(function()
			if self._drag or self._connecting then
				local rel = pluginWidget:GetRelativeMousePosition()
				local abs = pluginWidget.AbsolutePosition
				self:_onMouseMove(rel.X + abs.X, rel.Y + abs.Y)
			end
		end)
	end

	-- Fallback: mouse up may not fire on overlay if released outside GUI
	self._uisConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and (self._drag or self._connecting) then
			self:_onMouseUp(0, 0)
		end
	end)
end

function Canvas:_removeOverlay()
	if self._heartbeat then self._heartbeat:Disconnect(); self._heartbeat = nil end
	if self._uisConn then self._uisConn:Disconnect(); self._uisConn = nil end
	if self._overlay then self._overlay:Destroy(); self._overlay = nil end
end

------------------------------------------------------------------------
-- Mouse handlers (routed through overlay during drags)
------------------------------------------------------------------------
function Canvas:_onMouseMove(sx, sy)
	if self._drag then
		local d = self._drag
		local dx = sx - d.startMouse.X
		local dy = sy - d.startMouse.Y
		local nx = d.startPos.X + dx
		local ny = d.startPos.Y + dy
		self._state:MoveNode(d.nodeId, nx, ny)
		local w = self._widgets[d.nodeId]
		if w then w:SetPosition(nx, ny) end
		self._conns:RenderAll(self._widgets, self._state)
	end

	if self._connecting then
		local cx, cy = self:_screenToCanvas(sx, sy)
		self._conns:UpdateDrag(Vector2.new(cx, cy))
	end
end

function Canvas:_onMouseUp(sx, sy)
	if self._drag then
		local d = self._drag
		self._drag = nil
		self._state:CommitMove()
		self:_removeOverlay()
	end

	if self._connecting then
		self._conns:CancelDrag()
		self._connecting = nil
		self:_removeOverlay()
	end
end

------------------------------------------------------------------------
-- Node widget creation + input wiring
------------------------------------------------------------------------
function Canvas:_createWidget(nodeId)
	local node = self._state.nodes[nodeId]
	if not node then return end

	local w = NodeWidget.new(node, self._inner, self._state)
	self._widgets[nodeId] = w

	local dragHandle = w:GetDragHandleFrame()
	if dragHandle then
		dragHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self._state:SelectNode(nodeId)
				self._drag = {
					nodeId     = nodeId,
					startMouse = Vector2.new(input.Position.X, input.Position.Y),
					startPos   = Vector2.new(node.x, node.y),
				}
				self:_createOverlay()
			end
		end)
	end

	self:_wireChoiceDots(w, nodeId)
	self:_wireInputDot(w, nodeId)
end

function Canvas:_wireChoiceDots(w, nodeId)
	local node = self._state.nodes[nodeId]
	if not node then return end
	for i = 1, #(node.choices or {}) do
		local dot = w:GetChoiceDot(i)
		if dot then
			dot.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					local fromPos = w:GetChoiceDotCenter(i)
					if fromPos then
						self._connecting = { nodeId = nodeId, choiceIndex = i }
						self._conns:StartDrag(fromPos)
						self:_createOverlay()
					end
				end
			end)
		end
	end
end

function Canvas:_wireInputDot(w, targetNodeId)
	local dot = w:GetInputDot()
	if not dot then return end
	dot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self._connecting then
			local from = self._connecting
			self._state:UpdateChoice(from.nodeId, from.choiceIndex, { targetNodeId = targetNodeId })
			self._conns:CancelDrag()
			self._connecting = nil
			self:_removeOverlay()
			self:RefreshConnections()
		end
	end)
end

------------------------------------------------------------------------
-- Context menu
------------------------------------------------------------------------
function Canvas:_dismissContextMenu()
	local old = self._scroll:FindFirstChild("ContextMenu")
	if old then old:Destroy() end
end

function Canvas:_showContextMenu(cx, cy)
	self:_dismissContextMenu()
	local T = Theme

	local menu = Instance.new("Frame")
	menu.Name = "ContextMenu"
	menu.Size = UDim2.fromOffset(150, 64)
	menu.Position = UDim2.fromOffset(cx, cy)
	menu.BackgroundColor3 = T.Colors.Toolbar
	menu.BorderSizePixel = 0
	menu.ZIndex = 30
	menu.Parent = self._scroll
	Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", menu).Color = T.Colors.FieldBorder

	local function menuBtn(text, yOff, isEnd)
		local b = Instance.new("TextButton", menu)
		b.Size = UDim2.new(1, -8, 0, 24)
		b.Position = UDim2.fromOffset(4, yOff)
		b.BackgroundColor3 = T.Colors.BtnNormal
		b.TextColor3 = T.Colors.Text
		b.Text = text
		b.TextSize = T.Sizes.SmallText
		b.Font = T.Fonts.Default
		b.BorderSizePixel = 0
		b.ZIndex = 31
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
		b.MouseButton1Click:Connect(function()
			menu:Destroy()
			self:_addNodeAt(cx, cy, isEnd)
		end)
	end

	menuBtn("+ Add Node", 4, false)
	menuBtn("+ Add End Node", 32, true)

	task.delay(6, function()
		if menu.Parent then menu:Destroy() end
	end)
end

function Canvas:_addNodeAt(cx, cy, isEnd)
	local count = self._state:GetNodeCount()
	local id = "node_" .. (count + 1)
	while self._state.nodes[id] do
		count = count + 1
		id = "node_" .. (count + 1)
	end
	local node = self._state:AddNode(id, cx, cy)
	if isEnd then
		self._state:UpdateNode(id, { isEndNode = true })
	end
	self._state:SelectNode(id)
end

------------------------------------------------------------------------
-- Grid
------------------------------------------------------------------------
function Canvas:_drawGrid()
	local T = Theme
	local CS = T.Sizes.CanvasSize
	local sp = T.Sizes.GridSpacing
	local center = CS / 2
	local range = 1200

	local grid = Instance.new("Frame", self._inner)
	grid.Name = "Grid"
	grid.Size = UDim2.fromScale(1, 1)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 0

	for x = center - range, center + range, sp do
		for y = center - range, center + range, sp do
			local dot = Instance.new("Frame", grid)
			dot.Size = UDim2.fromOffset(2, 2)
			dot.Position = UDim2.fromOffset(x, y)
			dot.BackgroundColor3 = T.Colors.GridDot
			dot.BorderSizePixel = 0
			dot.ZIndex = 0
		end
	end
end

------------------------------------------------------------------------
-- Refresh connections
------------------------------------------------------------------------
function Canvas:RefreshConnections()
	self._conns:RenderAll(self._widgets, self._state)
end

------------------------------------------------------------------------
-- Full rebuild (after undo/redo/import)
------------------------------------------------------------------------
function Canvas:_rebuildAll()
	for _, w in pairs(self._widgets) do w:Destroy() end
	self._widgets = {}
	self._conns:Clear()
	for nodeId in pairs(self._state.nodes) do
		self:_createWidget(nodeId)
	end
	self:RefreshConnections()

	if self._state.selectedId then
		local w = self._widgets[self._state.selectedId]
		if w then w:SetSelected(true) end
	end
end

------------------------------------------------------------------------
-- State binding
------------------------------------------------------------------------
function Canvas:_bindState()
	local s = self._state

	s.nodeAdded:Connect(function(nodeId)
		self:_createWidget(nodeId)
		self:RefreshConnections()
	end)

	s.nodeRemoved:Connect(function(nodeId)
		local w = self._widgets[nodeId]
		if w then w:Destroy(); self._widgets[nodeId] = nil end
		self:RefreshConnections()
	end)

	s.nodeMoved:Connect(function()
		self:RefreshConnections()
	end)

	s.nodeUpdated:Connect(function(nodeId, nodeData)
		local w = self._widgets[nodeId]
		if w then
			w:UpdateData(nodeData)
			self:_wireChoiceDots(w, nodeId)
			self:_wireInputDot(w, nodeId)
		end
		-- Handle renames: widget might be under old key
		for id, widget in pairs(self._widgets) do
			if id ~= nodeData.id and not self._state.nodes[id] then
				self._widgets[id] = nil
				self._widgets[nodeData.id] = widget
				break
			end
		end
		self:RefreshConnections()
	end)

	s.selectionChanged:Connect(function(selectedId)
		for id, w in pairs(self._widgets) do
			w:SetSelected(id == selectedId)
		end
	end)

	s.stateLoaded:Connect(function()
		self:_rebuildAll()
	end)

	s.treeChanged:Connect(function()
		for id, w in pairs(self._widgets) do
			local node = s.nodes[id]
			if node then w:UpdateData(node) end
		end
		self:RefreshConnections()
	end)
end

function Canvas:Destroy()
	for _, w in pairs(self._widgets) do w:Destroy() end
	self._conns:Destroy()
	self:_removeOverlay()
	if self._scroll then self._scroll:Destroy() end
end

return Canvas
