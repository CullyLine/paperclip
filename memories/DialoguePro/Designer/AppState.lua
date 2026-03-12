------------------------------------------------------------------------
-- Signal: lightweight event emitter
------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({ _listeners = {} }, Signal)
	return self
end

function Signal:Connect(fn)
	local conn = { _fn = fn, Connected = true }
	function conn:Disconnect()
		conn.Connected = false
	end
	table.insert(self._listeners, conn)
	return conn
end

function Signal:Fire(...)
	for i = #self._listeners, 1, -1 do
		local c = self._listeners[i]
		if c.Connected then
			c._fn(...)
		else
			table.remove(self._listeners, i)
		end
	end
end

------------------------------------------------------------------------
-- AppState: single source of truth for the designer
------------------------------------------------------------------------
local AppState = {}
AppState.__index = AppState

function AppState.new()
	local self = setmetatable({}, AppState)

	self.treeId      = "untitled"
	self.startNodeId = nil
	self.nodes       = {} -- [nodeId] → { id, x, y, speaker, text, isEndNode, autoAdvanceDelay, actions{}, choices{} }
	self.selectedId  = nil

	self._undoStack = {}
	self._redoStack = {}
	self._maxUndo   = 50

	self.nodeAdded        = Signal.new()
	self.nodeRemoved      = Signal.new()
	self.nodeMoved        = Signal.new()
	self.nodeUpdated       = Signal.new()
	self.selectionChanged = Signal.new()
	self.treeChanged      = Signal.new()
	self.stateLoaded      = Signal.new()

	return self
end

------------------------------------------------------------------------
-- Snapshot helpers (deep-copy for undo)
------------------------------------------------------------------------
local function deepCopyActions(actions)
	if not actions then return {} end
	local out = {}
	for _, a in ipairs(actions) do
		table.insert(out, { type = a.type, key = a.key, value = a.value })
	end
	return out
end

local function deepCopyConditions(cond)
	if not cond then return {} end
	local out = {}
	for k, v in pairs(cond) do out[k] = v end
	return out
end

local function deepCopyChoices(choices)
	if not choices then return {} end
	local out = {}
	for _, c in ipairs(choices) do
		table.insert(out, {
			text                = c.text,
			targetNodeId        = c.targetNodeId,
			conditions          = deepCopyConditions(c.conditions),
			hideWhenUnavailable = c.hideWhenUnavailable,
			actions             = deepCopyActions(c.actions),
		})
	end
	return out
end

local function deepCopyNode(n)
	return {
		id                = n.id,
		x                 = n.x,
		y                 = n.y,
		speaker           = n.speaker,
		text              = n.text,
		isEndNode         = n.isEndNode,
		autoAdvanceDelay  = n.autoAdvanceDelay,
		actions           = deepCopyActions(n.actions),
		choices           = deepCopyChoices(n.choices),
	}
end

function AppState:_snapshot()
	local data = { treeId = self.treeId, startNodeId = self.startNodeId, nodes = {} }
	for id, n in pairs(self.nodes) do
		data.nodes[id] = deepCopyNode(n)
	end
	return data
end

function AppState:_restore(data)
	self.treeId      = data.treeId
	self.startNodeId = data.startNodeId
	self.nodes       = data.nodes
	self.selectedId  = nil
end

function AppState:_pushUndo()
	table.insert(self._undoStack, self:_snapshot())
	if #self._undoStack > self._maxUndo then
		table.remove(self._undoStack, 1)
	end
	self._redoStack = {}
end

function AppState:Undo()
	if #self._undoStack == 0 then return end
	table.insert(self._redoStack, self:_snapshot())
	self:_restore(table.remove(self._undoStack))
	self.stateLoaded:Fire()
end

function AppState:Redo()
	if #self._redoStack == 0 then return end
	table.insert(self._undoStack, self:_snapshot())
	self:_restore(table.remove(self._redoStack))
	self.stateLoaded:Fire()
end

------------------------------------------------------------------------
-- Node CRUD
------------------------------------------------------------------------
function AppState:AddNode(nodeId, x, y)
	self:_pushUndo()
	local node = {
		id               = nodeId,
		x                = x or 100,
		y                = y or 100,
		speaker          = nil,
		text             = "",
		isEndNode        = false,
		autoAdvanceDelay = nil,
		actions          = {},
		choices          = {},
	}
	self.nodes[nodeId] = node
	if not self.startNodeId then
		self.startNodeId = nodeId
	end
	self.nodeAdded:Fire(nodeId, node)
	self.treeChanged:Fire()
	return node
end

function AppState:RemoveNode(nodeId)
	if not self.nodes[nodeId] then return end
	self:_pushUndo()
	for _, n in pairs(self.nodes) do
		for _, c in ipairs(n.choices or {}) do
			if c.targetNodeId == nodeId then c.targetNodeId = nil end
		end
	end
	self.nodes[nodeId] = nil
	if self.startNodeId == nodeId then
		self.startNodeId = next(self.nodes)
	end
	if self.selectedId == nodeId then
		self.selectedId = nil
		self.selectionChanged:Fire(nil)
	end
	self.nodeRemoved:Fire(nodeId)
	self.treeChanged:Fire()
end

function AppState:MoveNode(nodeId, x, y)
	local n = self.nodes[nodeId]
	if not n then return end
	n.x, n.y = x, y
	self.nodeMoved:Fire(nodeId, x, y)
end

function AppState:CommitMove()
	self:_pushUndo()
end

function AppState:UpdateNode(nodeId, changes)
	local node = self.nodes[nodeId]
	if not node then return end
	self:_pushUndo()

	local oldId = nodeId
	for k, v in pairs(changes) do
		node[k] = v
	end

	if changes.id and changes.id ~= oldId then
		self.nodes[oldId] = nil
		self.nodes[changes.id] = node
		for _, n in pairs(self.nodes) do
			for _, c in ipairs(n.choices or {}) do
				if c.targetNodeId == oldId then c.targetNodeId = changes.id end
			end
		end
		if self.startNodeId == oldId then self.startNodeId = changes.id end
		if self.selectedId  == oldId then self.selectedId  = changes.id end
	end

	self.nodeUpdated:Fire(changes.id or oldId, node)
	self.treeChanged:Fire()
end

function AppState:SelectNode(nodeId)
	if self.selectedId == nodeId then return end
	self.selectedId = nodeId
	self.selectionChanged:Fire(nodeId)
end

function AppState:SetStartNode(nodeId)
	if not self.nodes[nodeId] then return end
	self:_pushUndo()
	self.startNodeId = nodeId
	self.treeChanged:Fire()
end

function AppState:SetTreeId(id)
	self:_pushUndo()
	self.treeId = id
	self.treeChanged:Fire()
end

------------------------------------------------------------------------
-- Choice CRUD
------------------------------------------------------------------------
function AppState:AddChoice(nodeId)
	local node = self.nodes[nodeId]
	if not node then return end
	self:_pushUndo()
	table.insert(node.choices, {
		text                = "New choice",
		targetNodeId        = nil,
		conditions          = {},
		hideWhenUnavailable = false,
		actions             = {},
	})
	self.nodeUpdated:Fire(nodeId, node)
	self.treeChanged:Fire()
end

function AppState:RemoveChoice(nodeId, idx)
	local node = self.nodes[nodeId]
	if not node or not node.choices[idx] then return end
	self:_pushUndo()
	table.remove(node.choices, idx)
	self.nodeUpdated:Fire(nodeId, node)
	self.treeChanged:Fire()
end

function AppState:UpdateChoice(nodeId, idx, changes)
	local node = self.nodes[nodeId]
	if not node or not node.choices[idx] then return end
	self:_pushUndo()
	for k, v in pairs(changes) do
		node.choices[idx][k] = v
	end
	self.nodeUpdated:Fire(nodeId, node)
	self.treeChanged:Fire()
end

------------------------------------------------------------------------
-- Bulk operations
------------------------------------------------------------------------
function AppState:Clear()
	self:_pushUndo()
	self.nodes       = {}
	self.startNodeId = nil
	self.selectedId  = nil
	self.treeId      = "untitled"
	self.stateLoaded:Fire()
end

function AppState:LoadData(data)
	self:_pushUndo()
	self:_restore(data)
	self.stateLoaded:Fire()
end

function AppState:GetNodeCount()
	local c = 0
	for _ in pairs(self.nodes) do c = c + 1 end
	return c
end

function AppState:GetSortedNodeIds()
	local ids = {}
	for id in pairs(self.nodes) do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

return AppState
