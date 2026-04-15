--[[
	NodeManager
	Creates, deletes, moves, and manages terrain node Parts.
	Handles persistence folder structure and loading on startup.
]]

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TriangleEngine = require(script.Parent.TriangleEngine)

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

	if nodeData.part and nodeData.part.Parent then
		nodeData.part:Destroy()
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
function NodeManager:CreateTriangle(nodeA: string, nodeB: string, nodeC: string): string?
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
	local recording = ChangeHistoryService:TryBeginRecording("DrawTriangle")

	local triId = self._state:GenerateTriId()
	local color = self._state.settings.paintColor
	local material = self._state.settings.paintMaterial
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

	if triData.model and triData.model.Parent then
		triData.model:Destroy()
	end

	self._state:UnregisterTriangle(triId)
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
