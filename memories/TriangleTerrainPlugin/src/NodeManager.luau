--[[
	NodeManager
	Creates, deletes, moves, and manages terrain node Parts.
	Handles persistence folder structure and loading on startup.
]]

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TriangleEngine = require(script.Parent.TriangleEngine)
local SubdivisionEngine = require(script.Parent.SubdivisionEngine)

local TAG_PREFIX = "TT_"
local ROOT_NAME = "TriangleTerrain"
local NODES_FOLDER = "Nodes"
local MESH_FOLDER = "Mesh"
local SETTINGS_NAME = "Settings"

local NodeManager = {}
NodeManager.__index = NodeManager

function NodeManager.new(state)
	local self = setmetatable({}, NodeManager)
	self._state = state
	self._root = nil
	self._nodesFolder = nil
	self._meshFolder = nil
	self._settingsObj = nil
	self._moveConns = {} -- per-node connections for detecting manual moves
	return self
end

------------------------------------------------------------------------
-- Folder structure
------------------------------------------------------------------------
function NodeManager:EnsureFolders()
	self._root = workspace:FindFirstChild(ROOT_NAME)
	if not self._root then
		self._root = Instance.new("Folder")
		self._root.Name = ROOT_NAME
		self._root.Parent = workspace
	end

	self._nodesFolder = self._root:FindFirstChild(NODES_FOLDER)
	if not self._nodesFolder then
		self._nodesFolder = Instance.new("Folder")
		self._nodesFolder.Name = NODES_FOLDER
		self._nodesFolder.Parent = self._root
	end

	self._meshFolder = self._root:FindFirstChild(MESH_FOLDER)
	if not self._meshFolder then
		self._meshFolder = Instance.new("Folder")
		self._meshFolder.Name = MESH_FOLDER
		self._meshFolder.Parent = self._root
	end

	self._settingsObj = self._root:FindFirstChild(SETTINGS_NAME)
	if not self._settingsObj then
		self._settingsObj = Instance.new("Configuration")
		self._settingsObj.Name = SETTINGS_NAME
		self._settingsObj.Parent = self._root
	end
end

------------------------------------------------------------------------
-- Load existing data from workspace
------------------------------------------------------------------------
function NodeManager:LoadFromWorkspace()
	self:EnsureFolders()

	-- Load nodes
	for _, part in self._nodesFolder:GetChildren() do
		if part:IsA("BasePart") then
			local nodeId = part:GetAttribute("NodeId") or part.Name
			self._state:RegisterNode(nodeId, part, part.Position)
			self:_watchNodeMovement(nodeId, part)
		end
	end

	-- Load triangles
	for _, model in self._meshFolder:GetChildren() do
		if model:IsA("Model") then
			local triId = model:GetAttribute("TriId") or model.Name
			local nodeA = model:GetAttribute("NodeA")
			local nodeB = model:GetAttribute("NodeB")
			local nodeC = model:GetAttribute("NodeC")
			local colorAttr = model:GetAttribute("Color")
			local matAttr = model:GetAttribute("Material")

			local color = if typeof(colorAttr) == "Color3" then colorAttr else Color3.fromRGB(74, 124, 63)
			local material = Enum.Material.Grass
			if matAttr then
				local ok, mat = pcall(function() return Enum.Material[matAttr] end)
				if ok and mat then material = mat end
			end

			if nodeA and nodeB and nodeC then
				self._state:RegisterTriangle(triId, model, nodeA, nodeB, nodeC, color, material)
			end
		end
	end

	-- Load tags
	self:RefreshTagList()

	self._state:SyncIdCounters()
	self._state.stateLoaded:Fire()

	-- Bind safety-net folder watchers ONCE per session. These catch
	-- destructions we didn't drive ourselves — e.g. user deletes a node or
	-- triangle from the Studio Explorer / hits Delete on a selected
	-- TT_Triangles model. Without these, our state map would still claim
	-- the entity exists and hover/click/sculpt would silently misbehave.
	-- For plugin-driven deletes (DeleteNode/DeleteTriangle) the listener
	-- runs synchronously during Parent = nil and unregisters first; the
	-- subsequent UnregisterNode/Triangle call is then a no-op (idempotent).
	self:_bindFolderWatchers()
end

function NodeManager:_bindFolderWatchers()
	if self._folderWatchersBound then return end
	self._folderWatchersBound = true

	self._nodesFolder.ChildRemoved:Connect(function(child)
		if not child:IsA("BasePart") then return end
		local nodeId = child:GetAttribute("NodeId") or child.Name
		local nodeData = self._state.nodes[nodeId]
		-- Identity check: only react if the part that left IS the one we
		-- track for this id (defensive against id collisions or duplicate
		-- parts being re-parented around).
		if nodeData and nodeData.part == child then
			if self._moveConns[nodeId] then
				self._moveConns[nodeId]:Disconnect()
				self._moveConns[nodeId] = nil
			end
			self._state:UnregisterNode(nodeId)
		end
	end)

	self._meshFolder.ChildRemoved:Connect(function(child)
		if not child:IsA("Model") then return end
		local triId = child:GetAttribute("TriId") or child.Name
		local triData = self._state.triangles[triId]
		if triData and triData.model == child then
			self._state:UnregisterTriangle(triId)
		end
	end)
end

------------------------------------------------------------------------
-- Reconcile in-memory state with what's actually in the workspace folders.
--
-- Why this exists: when the user undoes a delete, ChangeHistoryService
-- restores the Parts/Models in workspace, but our self._state.nodes /
-- .triangles maps don't know about the resurrection. This walks the folders
-- and adds entries for instances that came back, and removes entries for
-- instances that disappeared (e.g. after a redo of a delete).
--
-- Diff-based so it's cheap on no-ops and doesn't re-fire every signal for
-- every existing item every time the user touches Ctrl+Z.
------------------------------------------------------------------------
-- Note: this resync intentionally does NOT push part.Position back into
-- state.position for already-known nodes. The _watchNodeMovement listener
-- fires synchronously when ChangeHistoryService restores a sculpt-undo's
-- positions, so state catches up there. Doing it again here would just be
-- redundant work on every undo (and there's no Studio path that mutates
-- Position without firing the property-changed signal).
function NodeManager:ResyncFromWorkspace()
	self:EnsureFolders()

	-- Snapshot what's in the workspace right now, by id.
	local presentNodes: { [string]: BasePart } = {}
	for _, part in self._nodesFolder:GetChildren() do
		if part:IsA("BasePart") then
			local nodeId = part:GetAttribute("NodeId") or part.Name
			presentNodes[nodeId] = part
		end
	end

	local presentTris: { [string]: Model } = {}
	for _, model in self._meshFolder:GetChildren() do
		if model:IsA("Model") then
			local triId = model:GetAttribute("TriId") or model.Name
			presentTris[triId] = model
		end
	end

	-- Drop state entries whose instance is no longer present (redo-of-delete).
	-- Triangles first so triangle-removed signals fire before their referenced
	-- nodes potentially go away.
	for id in self._state.triangles do
		if not presentTris[id] then
			self._state:UnregisterTriangle(id)
		end
	end
	for id in self._state.nodes do
		if not presentNodes[id] then
			-- Also drop the move watcher so a later restoration re-binds cleanly.
			if self._moveConns[id] then
				self._moveConns[id]:Disconnect()
				self._moveConns[id] = nil
			end
			self._state:UnregisterNode(id)
		end
	end

	-- Add state entries for instances that reappeared (undo-of-delete).
	for id, part in presentNodes do
		if not self._state.nodes[id] then
			self._state:RegisterNode(id, part, part.Position)
			self:_watchNodeMovement(id, part)
		end
	end
	for id, model in presentTris do
		if not self._state.triangles[id] then
			local nodeA = model:GetAttribute("NodeA")
			local nodeB = model:GetAttribute("NodeB")
			local nodeC = model:GetAttribute("NodeC")
			local colorAttr = model:GetAttribute("Color")
			local matAttr = model:GetAttribute("Material")

			local color = if typeof(colorAttr) == "Color3" then colorAttr else Color3.fromRGB(74, 124, 63)
			local material = Enum.Material.Grass
			if matAttr then
				local ok, mat = pcall(function() return Enum.Material[matAttr] end)
				if ok and mat then material = mat end
			end

			if nodeA and nodeB and nodeC then
				self._state:RegisterTriangle(id, model, nodeA, nodeB, nodeC, color, material)
			end
		end
	end
end

------------------------------------------------------------------------
-- Node CRUD
------------------------------------------------------------------------
function NodeManager:CreateNode(position: Vector3): string
	self:EnsureFolders()

	local recording = ChangeHistoryService:TryBeginRecording("PlaceNode")

	local nodeId = self._state:GenerateNodeId()

	local part = Instance.new("Part")
	part.Name = nodeId
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * self._state.settings.nodeSize
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = self._state.settings.nodeTransparency
	part.Color = Color3.fromRGB(255, 255, 100)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("NodeId", nodeId)
	part.Parent = self._nodesFolder

	-- Auto-tag with active tag filter
	if self._state.activeTag then
		CollectionService:AddTag(part, TAG_PREFIX .. self._state.activeTag)
	end

	self._state:RegisterNode(nodeId, part, position)
	self:_watchNodeMovement(nodeId, part)

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	return nodeId
end

function NodeManager:DeleteNode(nodeId: string)
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return end

	local recording = ChangeHistoryService:TryBeginRecording("DeleteNode")

	-- Remove connected triangles first
	local connected = self._state:GetConnectedTriangles(nodeId)
	for _, tri in connected do
		self:DeleteTriangle(tri.id)
	end

	-- Disconnect move watcher
	if self._moveConns[nodeId] then
		self._moveConns[nodeId]:Disconnect()
		self._moveConns[nodeId] = nil
	end

	-- IMPORTANT: detach via Parent = nil rather than :Destroy(). :Destroy()
	-- permanently locks the Parent property, so ChangeHistoryService can record
	-- the deletion but Roblox refuses to re-parent on undo (warns "Parent
	-- property of X is locked" and the visual undo silently fails). Using
	-- Parent = nil leaves the instance restorable; ChangeHistoryService keeps a
	-- reference until the entry falls out of the undo stack, then the GC
	-- reclaims it.
	if nodeData.part and nodeData.part.Parent then
		nodeData.part.Parent = nil
	end

	self._state:UnregisterNode(nodeId)

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

function NodeManager:MoveNode(nodeId: string, newPosition: Vector3)
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return end

	nodeData.part.Position = newPosition
	self._state:UpdateNodePosition(nodeId, newPosition)

	-- Update connected triangles in real time
	local connected = self._state:GetConnectedTriangles(nodeId)
	for _, tri in connected do
		self:_refreshTriangleGeometry(tri.id)
	end
end

------------------------------------------------------------------------
-- Triangle CRUD
------------------------------------------------------------------------
function NodeManager:CreateTriangle(nodeA: string, nodeB: string, nodeC: string, colorOverride: Color3?, materialOverride: Enum.Material?, suppressRecording: boolean?): string?
	local nA = self._state.nodes[nodeA]
	local nB = self._state.nodes[nodeB]
	local nC = self._state.nodes[nodeC]
	if not nA or not nB or not nC then return nil end

	-- Check for duplicate
	for _, tri in self._state.triangles do
		local refs = { tri.nodeA, tri.nodeB, tri.nodeC }
		local check = { nodeA, nodeB, nodeC }
		table.sort(refs)
		table.sort(check)
		if refs[1] == check[1] and refs[2] == check[2] and refs[3] == check[3] then
			return nil
		end
	end

	self:EnsureFolders()
	local recording = if suppressRecording then nil else ChangeHistoryService:TryBeginRecording("DrawTriangle")

	local triId = self._state:GenerateTriId()
	local color = colorOverride or self._state.settings.paintColor
	local material = materialOverride or self._state.settings.paintMaterial
	local thickness = self._state.settings.triangleThickness

	local w1, w2 = TriangleEngine.draw(nA.position, nB.position, nC.position, thickness)
	w1.Name = "Wedge1"
	w2.Name = "Wedge2"
	w1.Color = color
	w2.Color = color
	w1.Material = material
	w2.Material = material

	local model = Instance.new("Model")
	model.Name = triId
	model:SetAttribute("TriId", triId)
	model:SetAttribute("NodeA", nodeA)
	model:SetAttribute("NodeB", nodeB)
	model:SetAttribute("NodeC", nodeC)
	model:SetAttribute("Color", color)
	model:SetAttribute("Material", material.Name)

	w1.Parent = model
	w2.Parent = model
	model.Parent = self._meshFolder

	self._state:RegisterTriangle(triId, model, nodeA, nodeB, nodeC, color, material)

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	return triId
end

function NodeManager:DeleteTriangle(triId: string)
	local triData = self._state.triangles[triId]
	if not triData then return end

	-- See note in DeleteNode about Parent = nil vs :Destroy() — same reason
	-- here. :Destroy() locks Parent and breaks Studio's undo for this model.
	if triData.model and triData.model.Parent then
		triData.model.Parent = nil
	end

	self._state:UnregisterTriangle(triId)
end

------------------------------------------------------------------------
-- Delete a triangle and any of its 3 vertex nodes that are no longer
-- referenced by any other triangle (orphan cleanup).
--
-- Used by Delete mode when the "Delete Nodes" option is on, so users can
-- tear down triangulated areas without leaving stray dangling nodes
-- behind. Inner DeleteNode calls' own ChangeHistory recordings get
-- swallowed by any outer recording (e.g. the Delete-stroke recording in
-- InputHandler), so the whole sweep stays one undo step.
------------------------------------------------------------------------
function NodeManager:DeleteTriangleAndOrphans(triId: string)
	local triData = self._state.triangles[triId]
	if not triData then return end

	-- Snapshot the vertex IDs *before* deleting — UnregisterTriangle wipes
	-- the row from state.triangles.
	local vertexIds = { triData.nodeA, triData.nodeB, triData.nodeC }

	self:DeleteTriangle(triId)

	for _, nodeId in vertexIds do
		local connected = self._state:GetConnectedTriangles(nodeId)
		if #connected == 0 then
			self:DeleteNode(nodeId)
		end
	end
end

------------------------------------------------------------------------
-- Batch delete: nodes + triangles in one undoable step.
--
-- Wraps the whole batch in one ChangeHistoryService recording so:
--   * triangle-only deletes get an undo entry (DeleteTriangle alone doesn't
--     record on its own)
--   * node deletes don't produce N separate undo steps
-- Inner DeleteNode/DeleteTriangle calls' own TryBeginRecording will return
-- nil while ours is in progress and skip their own FinishRecording.
------------------------------------------------------------------------
function NodeManager:DeleteMany(nodeIds: { string }, triIds: { string })
	if #nodeIds == 0 and #triIds == 0 then return end

	local recording = ChangeHistoryService:TryBeginRecording("DeleteSelected")

	-- Snapshot defensively; deletes can mutate caller-owned tables (e.g.
	-- selectedNodes / selectedTriangles get cleared by SelectNode(nil)
	-- elsewhere, and DeleteNode cascades into connected-triangle deletes).
	local nodeSnapshot = table.clone(nodeIds)
	local triSnapshot = table.clone(triIds)

	for _, nodeId in nodeSnapshot do
		self:DeleteNode(nodeId)
	end
	for _, triId in triSnapshot do
		self:DeleteTriangle(triId)
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

------------------------------------------------------------------------
-- Subdivision
------------------------------------------------------------------------
-- Splits a triangle into (increment+1)^2 sub-triangles. Reuses existing
-- nodes within MERGE_THRESHOLD studs so adjacent subdivisions share edge
-- nodes cleanly. Inherits the original triangle's color/material and tags
-- on the new corner nodes (existing tags on the 3 original corners are
-- preserved automatically since those nodes are reused).
local SUBDIV_MERGE_THRESHOLD = 0.05  -- studs

function NodeManager:SubdivideTriangle(triId: string, increment: number): boolean
	local triData = self._state.triangles[triId]
	if not triData then return false end

	local nA = self._state.nodes[triData.nodeA]
	local nB = self._state.nodes[triData.nodeB]
	local nC = self._state.nodes[triData.nodeC]
	if not nA or not nB or not nC then return false end

	local K = math.max(1, math.floor(increment))
	local origA, origB, origC = triData.nodeA, triData.nodeB, triData.nodeC

	self:EnsureFolders()
	local recording = ChangeHistoryService:TryBeginRecording("SubdivideTriangle")

	local color = triData.color
	local material = triData.material

	-- Collect tags shared by all three corners — propagate to new nodes.
	local sharedTags = self:_intersectTags(origA, origB, origC)

	local verts, tris, edges = SubdivisionEngine.subdivide(nA.position, nB.position, nC.position, K)
	local corners = SubdivisionEngine.cornerIndices(K)

	-- Map vertex index -> nodeId. Seed the 3 corners with the existing nodeIds
	-- so we never accidentally create duplicates at A/B/C.
	local nodeIdAt: { [number]: string } = {}
	nodeIdAt[corners.A] = origA
	nodeIdAt[corners.B] = origB
	nodeIdAt[corners.C] = origC

	-- For each non-corner vertex, look for an existing node within threshold.
	-- Otherwise create a new one.
	local thresholdSq = SUBDIV_MERGE_THRESHOLD * SUBDIV_MERGE_THRESHOLD
	for vi, pos in verts do
		if nodeIdAt[vi] then continue end

		local foundId: string? = nil
		for nodeId, nodeData in self._state.nodes do
			local d = nodeData.position - pos
			if d:Dot(d) <= thresholdSq then
				foundId = nodeId
				break
			end
		end

		if foundId then
			nodeIdAt[vi] = foundId
		else
			local newId = self:_createNodeRaw(pos, sharedTags)
			nodeIdAt[vi] = newId
		end
	end

	-- Identify edge-neighbors BEFORE deleting anything, so we can re-fan them
	-- against the new subdivided edges. Only handles neighbors that share two
	-- of T1's three ORIGINAL corners (a full edge). Mixed-resolution borders
	-- where the neighbor was already subdivided into a finer fan are left
	-- alone — same-increment subdivision still aligns via the snap-merge above.
	local neighbors = self:_findEdgeNeighbors(triId, origA, origB, origC)

	-- Build the edge node-id lists in T1's canonical order (A->B, B->C, C->A).
	local function mapEdge(idxList: { number }): { string }
		local out = {}
		for _, vi in idxList do
			table.insert(out, nodeIdAt[vi])
		end
		return out
	end
	local edgeNodes = {
		AB = mapEdge(edges.AB),
		BC = mapEdge(edges.BC),
		CA = mapEdge(edges.CA),
	}

	-- Delete the original triangle BEFORE creating new ones.
	self:DeleteTriangle(triId)

	-- Re-fan each edge neighbor so it shares the new subdivision nodes.
	for _, n in neighbors do
		local list = edgeNodes[n.edge]
		if n.reversed then
			list = self:_reversedList(list)
		end
		self:_fanReplaceTriangle(n.triId, n.apex, list)
	end

	local created = 0
	for _, tri in tris do
		local idA = nodeIdAt[tri[1]]
		local idB = nodeIdAt[tri[2]]
		local idC = nodeIdAt[tri[3]]
		if idA and idB and idC then
			local newId = self:CreateTriangle(idA, idB, idC, color, material, true)
			if newId then created += 1 end
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	-- Refresh tags so any newly-introduced shared tags appear in the bar.
	if #sharedTags > 0 then
		self:RefreshTagList()
	end

	return created > 0
end

-- Find triangles that share exactly one full edge with the triangle defined
-- by (A, B, C). Returns a list of records describing each neighbor:
--   { triId, apex (the non-shared nodeId), edge ("AB"|"BC"|"CA"),
--     reversed (true if the neighbor walks the shared edge opposite to T1) }
function NodeManager:_findEdgeNeighbors(triId: string, A: string, B: string, C: string)
	local cornerSet = { [A] = true, [B] = true, [C] = true }
	local result = {}

	for otherId, other in self._state.triangles do
		if otherId == triId then continue end

		local refs = { other.nodeA, other.nodeB, other.nodeC }
		local apexPos: number? = nil
		local sharedCount = 0
		for i, r in refs do
			if cornerSet[r] then
				sharedCount += 1
			else
				apexPos = i
			end
		end

		if sharedCount ~= 2 or apexPos == nil then continue end

		-- In a 3-vertex triangle, the edge OPPOSITE the apex (in winding
		-- order) is (refs[apexPos+1], refs[apexPos+2]) cyclically. That tells
		-- us the direction the neighbor expects when we hand it edge nodes.
		local apex = refs[apexPos]
		local e1 = refs[(apexPos % 3) + 1]
		local e2 = refs[((apexPos + 1) % 3) + 1]
		if not (cornerSet[e1] and cornerSet[e2]) then continue end

		local edge: string?, reversed: boolean
		if e1 == A and e2 == B then edge, reversed = "AB", false
		elseif e1 == B and e2 == A then edge, reversed = "AB", true
		elseif e1 == B and e2 == C then edge, reversed = "BC", false
		elseif e1 == C and e2 == B then edge, reversed = "BC", true
		elseif e1 == C and e2 == A then edge, reversed = "CA", false
		elseif e1 == A and e2 == C then edge, reversed = "CA", true
		else continue end

		table.insert(result, { triId = otherId, apex = apex, edge = edge, reversed = reversed })
	end

	return result
end

-- Replace a triangle with a fan of smaller triangles sharing `apex` and
-- walking through `edgeList` (in winding order). Preserves the original
-- triangle's color/material.
function NodeManager:_fanReplaceTriangle(oldTriId: string, apex: string, edgeList: { string })
	local old = self._state.triangles[oldTriId]
	if not old then return end
	if #edgeList < 2 then return end

	local color = old.color
	local material = old.material

	self:DeleteTriangle(oldTriId)

	for i = 1, #edgeList - 1 do
		local a = apex
		local b = edgeList[i]
		local c = edgeList[i + 1]
		if a ~= b and b ~= c and a ~= c then
			self:CreateTriangle(a, b, c, color, material, true)
		end
	end
end

function NodeManager:_reversedList(list: { string }): { string }
	local out = {}
	for i = #list, 1, -1 do
		table.insert(out, list[i])
	end
	return out
end

-- Internal: create a node Part without its own undo recording (caller handles it).
function NodeManager:_createNodeRaw(position: Vector3, tags: { string }?): string
	self:EnsureFolders()

	local nodeId = self._state:GenerateNodeId()

	local part = Instance.new("Part")
	part.Name = nodeId
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * self._state.settings.nodeSize
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = self._state.settings.nodeTransparency
	part.Color = Color3.fromRGB(255, 255, 100)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("NodeId", nodeId)
	part.Parent = self._nodesFolder

	if tags then
		for _, tag in tags do
			CollectionService:AddTag(part, TAG_PREFIX .. tag)
		end
	end

	self._state:RegisterNode(nodeId, part, position)
	self:_watchNodeMovement(nodeId, part)

	return nodeId
end

function NodeManager:_intersectTags(nodeIdA: string, nodeIdB: string, nodeIdC: string): { string }
	local a = self:GetNodeTags(nodeIdA)
	local b = self:GetNodeTags(nodeIdB)
	local c = self:GetNodeTags(nodeIdC)

	local bSet, cSet = {}, {}
	for _, t in b do bSet[t] = true end
	for _, t in c do cSet[t] = true end

	local result = {}
	for _, t in a do
		if bSet[t] and cSet[t] then
			table.insert(result, t)
		end
	end
	return result
end

function NodeManager:PaintTriangle(triId: string, color: Color3?, material: Enum.Material?)
	local triData = self._state.triangles[triId]
	if not triData then return end

	local recording = ChangeHistoryService:TryBeginRecording("PaintTriangle")

	if color then
		triData.model:SetAttribute("Color", color)
	end
	if material then
		triData.model:SetAttribute("Material", material.Name)
	end

	TriangleEngine.setAppearance(
		triData.model,
		color or triData.color,
		material or triData.material
	)

	self._state:UpdateTriangleAppearance(triId, color, material)

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

------------------------------------------------------------------------
-- Tag operations
------------------------------------------------------------------------
function NodeManager:AddTagToNode(nodeId: string, tagName: string)
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return end
	CollectionService:AddTag(nodeData.part, TAG_PREFIX .. tagName)
	self:RefreshTagList()
end

function NodeManager:RemoveTagFromNode(nodeId: string, tagName: string)
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return end
	CollectionService:RemoveTag(nodeData.part, TAG_PREFIX .. tagName)
	self:RefreshTagList()
end

------------------------------------------------------------------------
-- Batch tag operations: assign or unassign one tag across many nodes in a
-- single undoable step. Without an outer recording, the "Add Tag" button
-- on N selected nodes would create N separate undo entries (each
-- CollectionService change is recorded individually by Studio).
------------------------------------------------------------------------
function NodeManager:AddTagToNodes(nodeIds: { string }, tagName: string)
	if #nodeIds == 0 or #tagName == 0 then return end
	local recording = ChangeHistoryService:TryBeginRecording("AddTag")
	for _, nodeId in nodeIds do
		self:AddTagToNode(nodeId, tagName)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

function NodeManager:RemoveTagFromNodes(nodeIds: { string }, tagName: string)
	if #nodeIds == 0 or #tagName == 0 then return end
	local recording = ChangeHistoryService:TryBeginRecording("RemoveTag")
	for _, nodeId in nodeIds do
		self:RemoveTagFromNode(nodeId, tagName)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

function NodeManager:GetNodeTags(nodeId: string): { string }
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return {} end
	local tags = {}
	for _, tag in CollectionService:GetTags(nodeData.part) do
		if tag:sub(1, #TAG_PREFIX) == TAG_PREFIX then
			table.insert(tags, tag:sub(#TAG_PREFIX + 1))
		end
	end
	return tags
end

function NodeManager:RefreshTagList()
	local seen = {}
	local tags = {}
	for _, nodeData in self._state.nodes do
		if nodeData.part then
			for _, tag in CollectionService:GetTags(nodeData.part) do
				if tag:sub(1, #TAG_PREFIX) == TAG_PREFIX then
					local name = tag:sub(#TAG_PREFIX + 1)
					if not seen[name] then
						seen[name] = true
						table.insert(tags, name)
					end
				end
			end
		end
	end
	table.sort(tags)
	self._state:RefreshTags(tags)
end

function NodeManager:NodePassesFilter(nodeId: string): boolean
	if not self._state.activeTag then return true end
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return false end
	return CollectionService:HasTag(nodeData.part, TAG_PREFIX .. self._state.activeTag)
end

function NodeManager:SetNodeVisibility(nodeId: string, visible: boolean)
	local nodeData = self._state.nodes[nodeId]
	if not nodeData then return end
	nodeData.part.Transparency = if visible then self._state.settings.nodeTransparency else 1
end

function NodeManager:SetTriangleVisibility(triId: string, visible: boolean)
	local triData = self._state.triangles[triId]
	if not triData then return end
	for _, child in triData.model:GetChildren() do
		if child:IsA("WedgePart") then
			child.Transparency = if visible then 0 else 1
		end
	end
end

function NodeManager:ApplyTagFilter()
	for nodeId in self._state.nodes do
		local passes = self:NodePassesFilter(nodeId)
		self:SetNodeVisibility(nodeId, passes)
	end
	for triId, tri in self._state.triangles do
		local aPass = self:NodePassesFilter(tri.nodeA)
		local bPass = self:NodePassesFilter(tri.nodeB)
		local cPass = self:NodePassesFilter(tri.nodeC)
		self:SetTriangleVisibility(triId, aPass or bPass or cPass)
	end
end

------------------------------------------------------------------------
-- Snapping
------------------------------------------------------------------------
function NodeManager:SnapPosition(position: Vector3): Vector3
	if not self._state.settings.snapEnabled then return position end

	local grid = self._state.settings.gridSize

	-- Grid snap
	local snapped = Vector3.new(
		math.round(position.X / grid) * grid,
		position.Y,
		math.round(position.Z / grid) * grid
	)

	-- Vertex snap: check if close to an existing node
	local vertexThreshold = grid * 0.4
	local closestDist = vertexThreshold
	local closestPos = nil
	for _, nodeData in self._state.nodes do
		local dist = (nodeData.position - position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestPos = nodeData.position
		end
	end

	return closestPos or snapped
end

------------------------------------------------------------------------
-- Sculpt helpers
------------------------------------------------------------------------
function NodeManager:GetNodesInRadius(center: Vector3, radius: number): { { id: string, distance: number } }
	local result = {}
	for nodeId, nodeData in self._state.nodes do
		if self:NodePassesFilter(nodeId) then
			local dist = (nodeData.position - center).Magnitude
			if dist <= radius then
				table.insert(result, { id = nodeId, distance = dist })
			end
		end
	end
	return result
end

function NodeManager:SculptRaise(center: Vector3, radius: number, strength: number, falloff: string)
	local recording = ChangeHistoryService:TryBeginRecording("Sculpt")
	local nodes = self:GetNodesInRadius(center, radius)
	for _, entry in nodes do
		local weight = self:_falloffWeight(entry.distance, radius, falloff)
		local nodeData = self._state.nodes[entry.id]
		if nodeData then
			local newPos = nodeData.position + Vector3.new(0, strength * weight, 0)
			self:MoveNode(entry.id, newPos)
		end
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

function NodeManager:SculptLower(center: Vector3, radius: number, strength: number, falloff: string)
	self:SculptRaise(center, radius, -strength, falloff)
end

function NodeManager:SculptSmooth(center: Vector3, radius: number, strength: number, falloff: string)
	local recording = ChangeHistoryService:TryBeginRecording("Sculpt")
	local nodes = self:GetNodesInRadius(center, radius)

	-- Calculate average height
	local totalY = 0
	local count = 0
	for _, entry in nodes do
		local nodeData = self._state.nodes[entry.id]
		if nodeData then
			totalY += nodeData.position.Y
			count += 1
		end
	end
	if count == 0 then return end
	local avgY = totalY / count

	for _, entry in nodes do
		local weight = self:_falloffWeight(entry.distance, radius, falloff) * strength * 0.1
		local nodeData = self._state.nodes[entry.id]
		if nodeData then
			local currentY = nodeData.position.Y
			local newY = currentY + (avgY - currentY) * weight
			self:MoveNode(entry.id, Vector3.new(nodeData.position.X, newY, nodeData.position.Z))
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

function NodeManager:SculptFlatten(center: Vector3, radius: number, _strength: number, falloff: string)
	local recording = ChangeHistoryService:TryBeginRecording("Sculpt")
	local nodes = self:GetNodesInRadius(center, radius)

	local totalY = 0
	local count = 0
	for _, entry in nodes do
		local nodeData = self._state.nodes[entry.id]
		if nodeData then
			totalY += nodeData.position.Y
			count += 1
		end
	end
	if count == 0 then return end
	local avgY = totalY / count

	for _, entry in nodes do
		local weight = self:_falloffWeight(entry.distance, radius, falloff)
		local nodeData = self._state.nodes[entry.id]
		if nodeData then
			local newY = nodeData.position.Y + (avgY - nodeData.position.Y) * weight
			self:MoveNode(entry.id, Vector3.new(nodeData.position.X, newY, nodeData.position.Z))
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

------------------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------------------
function NodeManager:_refreshTriangleGeometry(triId: string)
	local tri = self._state.triangles[triId]
	if not tri then return end
	local nA = self._state.nodes[tri.nodeA]
	local nB = self._state.nodes[tri.nodeB]
	local nC = self._state.nodes[tri.nodeC]
	if not nA or not nB or not nC then return end

	TriangleEngine.updateTriangle(tri.model, nA.position, nB.position, nC.position, self._state.settings.triangleThickness)
end

function NodeManager:_watchNodeMovement(nodeId: string, part: BasePart)
	if self._moveConns[nodeId] then
		self._moveConns[nodeId]:Disconnect()
	end
	self._moveConns[nodeId] = part:GetPropertyChangedSignal("Position"):Connect(function()
		local nodeData = self._state.nodes[nodeId]
		if nodeData and nodeData.position ~= part.Position then
			self._state:UpdateNodePosition(nodeId, part.Position)
			local connected = self._state:GetConnectedTriangles(nodeId)
			for _, tri in connected do
				self:_refreshTriangleGeometry(tri.id)
			end
		end
	end)
end

function NodeManager:_falloffWeight(distance: number, radius: number, falloff: string): number
	local t = math.clamp(distance / radius, 0, 1)
	if falloff == "Linear" then
		return 1 - t
	elseif falloff == "Flat" then
		return 1
	else -- "Smooth" (default, cosine)
		return (math.cos(t * math.pi) + 1) * 0.5
	end
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
function NodeManager:Destroy()
	for _, conn in self._moveConns do
		conn:Disconnect()
	end
	table.clear(self._moveConns)
end

return NodeManager
