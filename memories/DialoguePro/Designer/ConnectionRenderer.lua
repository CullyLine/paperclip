local Theme = require(script.Parent.DesignerTheme)

local ConnectionRenderer = {}
ConnectionRenderer.__index = ConnectionRenderer

local STEP = 4
local THICK = Theme.Sizes.ConnThickness

function ConnectionRenderer.new(canvasFrame, scrollFrame)
	local self = setmetatable({}, ConnectionRenderer)
	self._canvas   = canvasFrame
	self._scroll   = scrollFrame
	self._lines    = {}   -- flat list of frame instances
	self._dragParts = {}
	self._dragFrom  = nil
	return self
end

------------------------------------------------------------------------
-- Get canvas-space center of a dot element using its frame hierarchy
------------------------------------------------------------------------
function ConnectionRenderer:_dotCanvasCenter(dot)
	local x = 0
	local y = 0
	local obj = dot
	while obj and obj ~= self._canvas do
		local pos = obj.Position
		local parentSz = obj.Parent and obj.Parent.AbsoluteSize or Vector2.new(0, 0)
		x = x + pos.X.Scale * parentSz.X + pos.X.Offset
		y = y + pos.Y.Scale * parentSz.Y + pos.Y.Offset
		obj = obj.Parent
	end
	x = x + dot.Size.X.Offset / 2
	y = y + dot.Size.Y.Offset / 2
	return Vector2.new(x, y)
end

------------------------------------------------------------------------
-- Draw a dotted/segmented line from A to B (no rotation, no anchor)
------------------------------------------------------------------------
function ConnectionRenderer:_drawSegments(from, to, color, list)
	local dx = to.X - from.X
	local dy = to.Y - from.Y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 1 then return end
	local steps = math.max(math.floor(dist / STEP), 1)
	local sx = dx / steps
	local sy = dy / steps
	for s = 0, steps do
		local px = from.X + sx * s
		local py = from.Y + sy * s
		local seg = Instance.new("Frame")
		seg.Size = UDim2.fromOffset(STEP, THICK)
		seg.Position = UDim2.fromOffset(px, py)
		seg.BackgroundColor3 = color
		seg.BorderSizePixel = 0
		seg.ZIndex = 1
		seg.Parent = self._canvas
		table.insert(list, seg)
	end
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
-- Render all connections
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
			local fromDot = fromW:GetChoiceDot(i)
			local toDot   = toW:GetInputDot()
			if not fromDot or not toDot then continue end
			local fp = self:_dotCanvasCenter(fromDot)
			local tp = self:_dotCanvasCenter(toDot)
			self:_drawSegments(fp, tp, self:_lineColor(choice), self._lines)
		end
	end
end

------------------------------------------------------------------------
-- Drag line
------------------------------------------------------------------------
function ConnectionRenderer:StartDrag(fromPos)
	self:CancelDrag()
	self._dragFrom = fromPos
end

function ConnectionRenderer:UpdateDrag(toPos)
	for _, p in ipairs(self._dragParts) do p:Destroy() end
	self._dragParts = {}
	if self._dragFrom then
		self:_drawSegments(self._dragFrom, toPos, Theme.Colors.ConnDragging, self._dragParts)
	end
end

function ConnectionRenderer:CancelDrag()
	for _, p in ipairs(self._dragParts) do p:Destroy() end
	self._dragParts = {}
	self._dragFrom  = nil
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
function ConnectionRenderer:Clear()
	for _, f in ipairs(self._lines) do f:Destroy() end
	self._lines = {}
end

function ConnectionRenderer:Destroy()
	self:Clear()
	self:CancelDrag()
end

return ConnectionRenderer
