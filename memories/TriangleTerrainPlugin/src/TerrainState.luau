local Signal = require(script.Parent.Signal)

export type Mode = "Place" | "Draw" | "Paint" | "Sculpt" | "Select" | "Delete" | "Presets"
export type DrawSubMode = "Triangulate" | "SubDivide"

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
	self.drawSubMode = "Triangulate" :: DrawSubMode
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
		-- When locked, the plane stays at workPlaneFixedY and ignores the
		-- camera-relative offset. When unlocked, it tracks the camera as
		-- camPos.Y - workPlaneYOffset.
		workPlaneLocked = false,
		workPlaneFixedY = 0,
		-- Delete-mode option. When true, Delete mode also targets nodes
		-- directly, and deleting a triangle additionally cleans up any of
		-- its 3 vertex nodes that are no longer used by any other triangle
		-- ("orphan nodes"). Off by default — additive feature, conservative
		-- default to avoid surprising the user.
		deleteNodesEnabled = false,
		-- Auto-Triangulate alpha-shape filter strength. The threshold for
		-- "this triangle is a convex-hull bridge artifact" is
		--   (longest edge) > autoTriMaxEdgeFactor * (median nearest-neighbor)
		-- 3.0 is a sweet spot for typical irregular layouts (curves, rings).
		-- Bump higher (5+) if you want raw Delaunay; drop to ~2 for very
		-- conservative shape-following on dense point clouds. 0 disables
		-- the filter entirely.
		autoTriMaxEdgeFactor = 3.0,
	}

	-- Live Y of the work plane in the world. Updated by InputHandler each
	-- frame the plane is visible. Not part of `settings` because it's a
	-- *computed* value, not a user preference, so we don't want it firing
	-- the broadly-listened settingsChanged signal every frame.
	self.workPlaneCurrentY = 0

	-- Signals
	self.modeChanged = Signal.new()
	self.drawSubModeChanged = Signal.new()
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
	self.workPlaneYChanged = Signal.new()
	self.deleteStrokeChanged = Signal.new()
	self.deleteStrokeCount = 0

	self._nextNodeId = 1
	self._nextTriId = 1

	-- Material preset library (set externally by Plugin.server.luau because
	-- it needs the `plugin` handle for SetSetting/GetSetting). UI code reads
	-- from here. May be nil during very early construction.
	self.materialPresets = nil

	return self
end

------------------------------------------------------------------------
-- Mode
------------------------------------------------------------------------
function TerrainState:SetMode(mode: Mode)
	if self.activeMode == mode then return end
	self.activeMode = mode
	-- Switching modes also clears any in-progress 3-vertex Draw pick. Must
	-- fire drawSelectionChanged so the Draw panel's "selected nodes" visual
	-- doesn't lie about a partial pick the user can no longer complete.
	if #self.drawSelection > 0 then
		table.clear(self.drawSelection)
		self.drawSelectionChanged:Fire(self.drawSelection)
	end
	self.modeChanged:Fire(mode)
end

function TerrainState:SetDrawSubMode(mode: DrawSubMode)
	if self.drawSubMode == mode then return end
	self.drawSubMode = mode
	-- Switching sub-mode also clears any partial draw selection so the user
	-- doesn't end up with stale 1-or-2-node picks when toggling.
	if #self.drawSelection > 0 then
		table.clear(self.drawSelection)
		self.drawSelectionChanged:Fire(self.drawSelection)
	end
	self.drawSubModeChanged:Fire(mode)
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

	-- Prune the id from any selection/pick lists so dead ids don't pile up.
	-- Without this:
	--   * selectedNodes count ("3 nodes selected") lies after deletes
	--   * Delete Selected silently no-ops on dead ids
	--   * drawSelection in Draw mode keeps a stale partial pick that
	--     CreateTriangle silently rejects (frustrating "click does nothing")
	local sIdx = table.find(self.selectedNodes, id)
	if sIdx then
		table.remove(self.selectedNodes, sIdx)
		self.selectionChanged:Fire()
	end
	local dIdx = table.find(self.drawSelection, id)
	if dIdx then
		table.remove(self.drawSelection, dIdx)
		self.drawSelectionChanged:Fire(self.drawSelection)
	end
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

	-- Same prune-on-removal contract as UnregisterNode — keeps
	-- selectedTriangles honest after any cascade delete.
	local sIdx = table.find(self.selectedTriangles, id)
	if sIdx then
		table.remove(self.selectedTriangles, sIdx)
		self.selectionChanged:Fire()
	end
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
-- Work plane live-Y broadcast. Throttles to 0.05-stud changes to avoid
-- per-frame spam (Heartbeat fires ~60 Hz; without this, listeners would
-- update 60 times/sec while the camera moves vertically).
------------------------------------------------------------------------
function TerrainState:SetWorkPlaneCurrentY(y: number)
	if math.abs((self.workPlaneCurrentY or 0) - y) < 0.05 then return end
	self.workPlaneCurrentY = y
	self.workPlaneYChanged:Fire(y)
end

------------------------------------------------------------------------
-- Delete-mode stroke counter. Fired by InputHandler when an in-progress
-- delete drag adds a triangle, and again with 0 when the stroke ends.
-- The Delete panel listens to this to show "Deleted: N" mid-stroke.
------------------------------------------------------------------------
function TerrainState:SetDeleteStrokeCount(n: number)
	if self.deleteStrokeCount == n then return end
	self.deleteStrokeCount = n
	self.deleteStrokeChanged:Fire(n)
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
