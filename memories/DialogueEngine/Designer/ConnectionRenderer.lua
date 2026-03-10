local Theme = require(script.Parent.DesignerTheme)

local ConnectionRenderer = {}
ConnectionRenderer.__index = ConnectionRenderer

function ConnectionRenderer.new(canvasFrame)
	local self = setmetatable({}, ConnectionRenderer)
	self._canvas   = canvasFrame
	self._lines    = {}
	self._dragLine = nil
	self._dragFrom = nil
	return self
end

function ConnectionRenderer:_createLine(from, to, color)
	local delta  = to - from
	local length = math.max(delta.Magnitude, 1)
	local angle  = math.atan2(delta.Y, delta.X)

	local line = Instance.new("Frame")
	line.Size            = UDim2.fromOffset(length, Theme.Sizes.ConnThickness)
	line.Position        = UDim2.fromOffset(from.X, from.Y)
	line.AnchorPoint     = Vector2.new(0, 0.5)
	line.Rotation        = math.deg(angle)
	line.BackgroundColor3 = color or Theme.Colors.ConnNormal
	line.BorderSizePixel = 0
	line.ZIndex          = 1
	line.Parent          = self._canvas
	return line
end

function ConnectionRenderer:_lineColor(choice)
	if choice.actions and #choice.actions > 0 then
		return Theme.Colors.ConnAction
	end
	if choice.conditions and next(choice.conditions) then
		return Theme.Colors.ConnConditional
	end
	return Theme.Colors.ConnNormal
end

------------------------------------------------------------------------
-- Render all connections from current state
------------------------------------------------------------------------
function ConnectionRenderer:RenderAll(nodeWidgets, state)
	self:Clear()
	for nodeId, node in pairs(state.nodes) do
		local fromW = nodeWidgets[nodeId]
		if not fromW or not node.choices then continue end
		for i, choice in ipairs(node.choices) do
			if not choice.targetNodeId then continue end
			local toW = nodeWidgets[choice.targetNodeId]
			if not toW then continue end
			local fp = fromW:GetChoiceDotCenter(i)
			local tp = toW:GetInputDotCenter()
			if not fp or not tp then continue end
			local line = self:_createLine(fp, tp, self:_lineColor(choice))
			table.insert(self._lines, line)
		end
	end
end

------------------------------------------------------------------------
-- Drag line (while user is creating a connection)
------------------------------------------------------------------------
function ConnectionRenderer:StartDrag(fromPos)
	self:CancelDrag()
	self._dragFrom = fromPos
	self._dragLine = self:_createLine(fromPos, fromPos, Theme.Colors.ConnDragging)
end

function ConnectionRenderer:UpdateDrag(toPos)
	if not self._dragLine then return end
	self._dragLine:Destroy()
	self._dragLine = self:_createLine(self._dragFrom, toPos, Theme.Colors.ConnDragging)
end

function ConnectionRenderer:CancelDrag()
	if self._dragLine then self._dragLine:Destroy(); self._dragLine = nil end
	self._dragFrom = nil
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
function ConnectionRenderer:Clear()
	for _, l in ipairs(self._lines) do l:Destroy() end
	self._lines = {}
end

function ConnectionRenderer:Destroy()
	self:Clear()
	self:CancelDrag()
end

return ConnectionRenderer
