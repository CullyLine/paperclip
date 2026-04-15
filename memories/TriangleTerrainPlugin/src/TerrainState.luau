local Signal = require(script.Parent.Signal)

export type Mode = "Place" | "Draw" | "Paint" | "Sculpt" | "Select"

export type NodeData = {
	id: string,
	part: BasePart,
	position: Vector3,
}

export type TriData = {
	id: string,
	model: Model,
	nodeA: string,
	nodeB: string,
	nodeC: string,
	color: Color3,
	material: Enum.Material,
}

local TerrainState = {}
TerrainState.__index = TerrainState

function TerrainState.new()
	local self = setmetatable({}, TerrainState)

	self.nodes = {} :: { [string]: NodeData }
	self.triangles = {} :: { [string]: TriData }

	self.activeMode = "Place" :: Mode
	self.activeTag = nil :: string?
	self.tags = {} :: { string }

	self.selectedNodes = {} :: { string }
	self.selectedTriangles = {} :: { string }

	self.drawSelection = {} :: { string }

	self.settings = {
		gridSize = 4,
		snapEnabled = true,
		nodeSize = 1.5,
		nodeTransparency = 0.3,
		brushRadius = 20,
		brushStrength = 2,
		brushFalloff = "Smooth",
		paintColor = Color3.fromRGB(74, 124, 63),
		paintMaterial = Enum.Material.Grass,
		sculptTool = "Raise",
		showGrid = false,
		triangleThickness = 0.1,
		workPlaneEnabled = false,
		workPlaneYOffset = 20,
	}

	-- Signals
	self.modeChanged = Signal.new()
	self.nodeAdded = Signal.new()
	self.nodeRemoved = Signal.new()
	self.nodeMoved = Signal.new()
	self.triangleAdded = Signal.new()
	self.triangleRemoved = Signal.new()
	self.triangleUpdated = Signal.new()
	self.selectionChanged = Signal.new()
	self.drawSelectionChanged = Signal.new()
	self.tagFilterChanged = Signal.new()
	self.tagsChanged = Signal.new()
	self.settingsChanged = Signal.new()
	self.stateLoaded = Signal.new()

	self._nextNodeId = 1
	self._nextTriId = 1

	return self
end

------------------------------------------------------------------------
-- Mode
------------------------------------------------------------------------
function TerrainState:SetMode(mode: Mode)
	if self.activeMode == mode then return end
	self.activeMode = mode
	self.drawSelection = {}
	self.modeChanged:Fire(mode)
end

------------------------------------------------------------------------
-- Nodes
------------------------------------------------------------------------
function TerrainState:GenerateNodeId(): string
	local id = string.format("Node_%04d", self._nextNodeId)
	self._nextNodeId += 1
	while self.nodes[id] do
		id = string.format("Node_%04d", self._nextNodeId)
		self._nextNodeId += 1
	end
	return id
end

function TerrainState:RegisterNode(id: string, part: BasePart, position: Vector3)
	local data: NodeData = { id = id, part = part, position = position }
	self.nodes[id] = data
	self.nodeAdded:Fire(id, data)
end

function TerrainState:UnregisterNode(id: string)
	if not self.nodes[id] then return end
	self.nodes[id] = nil
	self.nodeRemoved:Fire(id)
end

function TerrainState:UpdateNodePosition(id: string, position: Vector3)
	local node = self.nodes[id]
	if not node then return end
	node.position = position
	self.nodeMoved:Fire(id, position)
end

------------------------------------------------------------------------
-- Triangles
------------------------------------------------------------------------
function TerrainState:GenerateTriId(): string
	local id = string.format("Tri_%04d", self._nextTriId)
	self._nextTriId += 1
	while self.triangles[id] do
		id = string.format("Tri_%04d", self._nextTriId)
		self._nextTriId += 1
	end
	return id
end

function TerrainState:RegisterTriangle(id: string, model: Model, nodeA: string, nodeB: string, nodeC: string, color: Color3, material: Enum.Material)
	local data: TriData = {
		id = id,
		model = model,
		nodeA = nodeA,
		nodeB = nodeB,
		nodeC = nodeC,
		color = color,
		material = material,
	}
	self.triangles[id] = data
	self.triangleAdded:Fire(id, data)
end

function TerrainState:UnregisterTriangle(id: string)
	if not self.triangles[id] then return end
	self.triangles[id] = nil
	self.triangleRemoved:Fire(id)
end

function TerrainState:UpdateTriangleAppearance(id: string, color: Color3?, material: Enum.Material?)
	local tri = self.triangles[id]
	if not tri then return end
	if color then tri.color = color end
	if material then tri.material = material end
	self.triangleUpdated:Fire(id, tri)
end

------------------------------------------------------------------------
-- Draw selection (accumulates 3 nodes)
------------------------------------------------------------------------
function TerrainState:ToggleDrawNode(nodeId: string)
	local idx = table.find(self.drawSelection, nodeId)
	if idx then
		table.remove(self.drawSelection, idx)
	else
		if #self.drawSelection < 3 then
			table.insert(self.drawSelection, nodeId)
		end
	end
	self.drawSelectionChanged:Fire(self.drawSelection)
end

function TerrainState:ClearDrawSelection()
	table.clear(self.drawSelection)
	self.drawSelectionChanged:Fire(self.drawSelection)
end

function TerrainState:IsDrawReady(): boolean
	return #self.drawSelection == 3
end

------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------
function TerrainState:SelectNode(nodeId: string?, additive: boolean?)
	if not additive then
		table.clear(self.selectedNodes)
		table.clear(self.selectedTriangles)
	end
	if nodeId then
		local idx = table.find(self.selectedNodes, nodeId)
		if idx and additive then
			table.remove(self.selectedNodes, idx)
		elseif not idx then
			table.insert(self.selectedNodes, nodeId)
		end
	end
	self.selectionChanged:Fire()
end

function TerrainState:SelectTriangle(triId: string?, additive: boolean?)
	if not additive then
		table.clear(self.selectedNodes)
		table.clear(self.selectedTriangles)
	end
	if triId then
		local idx = table.find(self.selectedTriangles, triId)
		if idx and additive then
			table.remove(self.selectedTriangles, idx)
		elseif not idx then
			table.insert(self.selectedTriangles, triId)
		end
	end
	self.selectionChanged:Fire()
end

------------------------------------------------------------------------
-- Tags
------------------------------------------------------------------------
function TerrainState:SetTagFilter(tag: string?)
	self.activeTag = tag
	self.tagFilterChanged:Fire(tag)
end

function TerrainState:RefreshTags(tagList: { string })
	self.tags = tagList
	self.tagsChanged:Fire(tagList)
end

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------
function TerrainState:SetSetting(key: string, value: any)
	self.settings[key] = value
	self.settingsChanged:Fire(key, value)
end

------------------------------------------------------------------------
-- Counts
------------------------------------------------------------------------
function TerrainState:GetNodeCount(): number
	local c = 0
	for _ in self.nodes do c += 1 end
	return c
end

function TerrainState:GetTriangleCount(): number
	local c = 0
	for _ in self.triangles do c += 1 end
	return c
end

------------------------------------------------------------------------
-- Node neighbor queries
------------------------------------------------------------------------
function TerrainState:GetConnectedTriangles(nodeId: string): { TriData }
	local result = {}
	for _, tri in self.triangles do
		if tri.nodeA == nodeId or tri.nodeB == nodeId or tri.nodeC == nodeId then
			table.insert(result, tri)
		end
	end
	return result
end

function TerrainState:GetNeighborNodes(nodeId: string): { string }
	local neighbors = {}
	local seen = {}
	for _, tri in self.triangles do
		local refs = { tri.nodeA, tri.nodeB, tri.nodeC }
		local isConnected = false
		for _, r in refs do
			if r == nodeId then isConnected = true; break end
		end
		if isConnected then
			for _, r in refs do
				if r ~= nodeId and not seen[r] then
					seen[r] = true
					table.insert(neighbors, r)
				end
			end
		end
	end
	return neighbors
end

------------------------------------------------------------------------
-- Sync IDs from existing instances (for persistence loading)
------------------------------------------------------------------------
function TerrainState:SyncIdCounters()
	for id in self.nodes do
		local num = tonumber(id:match("Node_(%d+)"))
		if num and num >= self._nextNodeId then
			self._nextNodeId = num + 1
		end
	end
	for id in self.triangles do
		local num = tonumber(id:match("Tri_(%d+)"))
		if num and num >= self._nextTriId then
			self._nextTriId = num + 1
		end
	end
end

return TerrainState
