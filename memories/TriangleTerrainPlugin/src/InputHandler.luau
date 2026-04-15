--[[
	InputHandler
	Routes mouse/keyboard input to the correct mode behavior.
	Manages raycasting, hover highlights, and hotkeys.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(state, nodeManager, mouse)
	local self = setmetatable({}, InputHandler)
	self._state = state
	self._nodeManager = nodeManager
	self._mouse = mouse
	self._active = false
	self._conns = {}
	self._hoverHighlight = nil
	self._brushCircle = nil
	self._ghostNode = nil
	self._workPlane = nil
	self._altHeld = false
	self._sculpting = false
	return self
end

function InputHandler:Activate()
	self._active = true
	self:_bindInputs()
end

function InputHandler:Deactivate()
	self._active = false
	self:_unbindInputs()
	self:_clearHover()
	self:_clearBrush()
	self:_clearGhost()
	self:_clearWorkPlane()
end

------------------------------------------------------------------------
-- Raycasting
------------------------------------------------------------------------
function InputHandler:_raycast(filterDescendants: { Instance }?, allowWorkPlane: boolean?): RaycastResult?
	local ray = self._mouse.UnitRay
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = filterDescendants or {}
	if self._brushCircle then
		table.insert(exclude, self._brushCircle)
	end
	if self._ghostNode then
		table.insert(exclude, self._ghostNode)
	end
	if self._workPlane and not allowWorkPlane then
		table.insert(exclude, self._workPlane)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
end

function InputHandler:_raycastForNodes(): (BasePart?, string?)
	local ray = self._mouse.UnitRay
	local origin = ray.Origin
	local direction = ray.Direction * 5000

	local closest: BasePart? = nil
	local closestId: string? = nil
	local closestDist = math.huge

	for nodeId, nodeData in self._state.nodes do
		if not self._nodeManager:NodePassesFilter(nodeId) then continue end
		local part = nodeData.part
		if not part or not part.Parent then continue end

		local toNode = part.Position - origin
		local projLen = toNode:Dot(direction.Unit)
		if projLen < 0 then continue end

		local projected = origin + direction.Unit * projLen
		local dist = (projected - part.Position).Magnitude
		local hitRadius = part.Size.X * 0.5 + 1.5

		if dist < hitRadius and projLen < closestDist then
			closestDist = projLen
			closest = part
			closestId = nodeId
		end
	end

	return closest, closestId
end

function InputHandler:_raycastForTriangles(): (Model?, string?)
	local result = self:_raycast()
	if not result or not result.Instance then return nil, nil end

	local hit = result.Instance
	local parent = hit.Parent
	if parent and parent:IsA("Model") and parent:GetAttribute("TriId") then
		return parent, parent:GetAttribute("TriId")
	end
	return nil, nil
end

------------------------------------------------------------------------
-- Mode dispatch
------------------------------------------------------------------------
function InputHandler:_onClick()
	if not self._active then return end

	local mode = self._state.activeMode

	if mode == "Place" then
		self:_handlePlaceClick()
	elseif mode == "Draw" then
		self:_handleDrawClick()
	elseif mode == "Paint" then
		self:_handlePaintClick()
	elseif mode == "Select" then
		self:_handleSelectClick()
	end
	-- Sculpt is handled continuously via InputChanged
end

function InputHandler:_onShiftClick()
	if not self._active then return end

	local mode = self._state.activeMode

	if mode == "Place" then
		self:_handlePlaceShiftClick()
	end
end

------------------------------------------------------------------------
-- Place mode
------------------------------------------------------------------------
function InputHandler:_handlePlaceClick()
	local excludeParts = {}
	for _, nodeData in self._state.nodes do
		if nodeData.part then
			table.insert(excludeParts, nodeData.part)
		end
	end

	local result = self:_raycast(excludeParts, true)
	local pos
	if result then
		pos = result.Position
	else
		pos = self._mouse.Hit.Position
	end

	if not self._altHeld then
		pos = self._nodeManager:SnapPosition(pos)
	end
	self._nodeManager:CreateNode(pos)
end

function InputHandler:_handlePlaceShiftClick()
	local _, nodeId = self:_raycastForNodes()
	if nodeId then
		self._nodeManager:DeleteNode(nodeId)
	end
end

------------------------------------------------------------------------
-- Draw mode
------------------------------------------------------------------------
function InputHandler:_handleDrawClick()
	local _, nodeId = self:_raycastForNodes()
	if nodeId then
		self._state:ToggleDrawNode(nodeId)

		if self._state:IsDrawReady() then
			local sel = self._state.drawSelection
			self._nodeManager:CreateTriangle(sel[1], sel[2], sel[3])
			self._state:ClearDrawSelection()
		end
	end
end

------------------------------------------------------------------------
-- Paint mode
------------------------------------------------------------------------
function InputHandler:_handlePaintClick()
	local _, triId = self:_raycastForTriangles()
	if triId then
		self._nodeManager:PaintTriangle(
			triId,
			self._state.settings.paintColor,
			self._state.settings.paintMaterial
		)
	end
end

------------------------------------------------------------------------
-- Select mode
------------------------------------------------------------------------
function InputHandler:_handleSelectClick()
	local additive = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or
		UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

	local _, nodeId = self:_raycastForNodes()
	if nodeId then
		self._state:SelectNode(nodeId, additive)
		return
	end

	local _, triId = self:_raycastForTriangles()
	if triId then
		self._state:SelectTriangle(triId, additive)
		return
	end

	if not additive then
		self._state:SelectNode(nil)
	end
end

------------------------------------------------------------------------
-- Sculpt mode (continuous while mouse held)
------------------------------------------------------------------------
function InputHandler:_handleSculptTick()
	if not self._sculpting then return end

	local result = self:_raycast()
	if not result then return end

	local center = result.Position
	local radius = self._state.settings.brushRadius
	local strength = self._state.settings.brushStrength
	local falloff = self._state.settings.brushFalloff
	local tool = self._state.settings.sculptTool

	if tool == "Raise" then
		self._nodeManager:SculptRaise(center, radius, strength * 0.1, falloff)
	elseif tool == "Lower" then
		self._nodeManager:SculptLower(center, radius, strength * 0.1, falloff)
	elseif tool == "Smooth" then
		self._nodeManager:SculptSmooth(center, radius, strength, falloff)
	elseif tool == "Flatten" then
		self._nodeManager:SculptFlatten(center, radius, strength, falloff)
	end
end

------------------------------------------------------------------------
-- Work Plane (floating construction surface)
------------------------------------------------------------------------
function InputHandler:_updateWorkPlane()
	if not self._state.settings.workPlaneEnabled then
		self:_clearWorkPlane()
		return
	end

	if not self._workPlane then
		self._workPlane = Instance.new("Part")
		self._workPlane.Name = "TT_WorkPlane"
		self._workPlane.Anchored = true
		self._workPlane.CanCollide = false
		self._workPlane.CastShadow = false
		self._workPlane.Transparency = 0.85
		self._workPlane.Color = Color3.fromRGB(140, 180, 220)
		self._workPlane.Material = Enum.Material.SmoothPlastic
		self._workPlane.TopSurface = Enum.SurfaceType.Smooth
		self._workPlane.BottomSurface = Enum.SurfaceType.Smooth
		self._workPlane.Size = Vector3.new(512, 0.05, 512)
		self._workPlane.Parent = workspace

		local texture = Instance.new("Texture")
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU = self._state.settings.gridSize
		texture.StudsPerTileV = self._state.settings.gridSize
		texture.Transparency = 0.6
		texture.Color3 = Color3.fromRGB(180, 210, 240)
		texture.Parent = self._workPlane
		self._workPlaneTexture = texture
	end

	local cam = workspace.CurrentCamera
	if not cam then return end

	local camPos = cam.CFrame.Position
	local yOffset = self._state.settings.workPlaneYOffset
	local grid = self._state.settings.gridSize

	local snapX = math.round(camPos.X / grid) * grid
	local snapZ = math.round(camPos.Z / grid) * grid
	self._workPlane.Position = Vector3.new(snapX, camPos.Y - yOffset, snapZ)

	if self._workPlaneTexture then
		self._workPlaneTexture.StudsPerTileU = grid
		self._workPlaneTexture.StudsPerTileV = grid
	end
end

function InputHandler:_clearWorkPlane()
	if self._workPlane then
		self._workPlane:Destroy()
		self._workPlane = nil
		self._workPlaneTexture = nil
	end
end

------------------------------------------------------------------------
-- Ghost preview node (Place mode)
------------------------------------------------------------------------
function InputHandler:_updateGhostNode()
	if self._state.activeMode ~= "Place" then
		self:_clearGhost()
		return
	end

	local excludeParts = {}
	for _, nodeData in self._state.nodes do
		if nodeData.part then
			table.insert(excludeParts, nodeData.part)
		end
	end

	local result = self:_raycast(excludeParts, true)
	if not result then
		local hitPos = self._mouse.Hit.Position
		self:_showGhost(hitPos)
		return
	end

	local pos = result.Position
	if not self._altHeld then
		pos = self._nodeManager:SnapPosition(pos)
	end
	self:_showGhost(pos)
end

function InputHandler:_showGhost(position: Vector3)
	if not self._ghostNode then
		self._ghostNode = Instance.new("Part")
		self._ghostNode.Name = "TT_GhostNode"
		self._ghostNode.Shape = Enum.PartType.Ball
		self._ghostNode.Anchored = true
		self._ghostNode.CanCollide = false
		self._ghostNode.CastShadow = false
		self._ghostNode.Transparency = 0.6
		self._ghostNode.Color = Color3.fromRGB(255, 255, 100)
		self._ghostNode.Material = Enum.Material.Neon
		self._ghostNode.TopSurface = Enum.SurfaceType.Smooth
		self._ghostNode.BottomSurface = Enum.SurfaceType.Smooth
		self._ghostNode.Parent = workspace
	end
	self._ghostNode.Size = Vector3.one * self._state.settings.nodeSize
	self._ghostNode.Position = position
end

function InputHandler:_clearGhost()
	if self._ghostNode then
		self._ghostNode:Destroy()
		self._ghostNode = nil
	end
end

------------------------------------------------------------------------
-- Hover highlight
------------------------------------------------------------------------
function InputHandler:_updateHover()
	if not self._active then return end

	local mode = self._state.activeMode

	if mode == "Place" or mode == "Draw" or mode == "Select" then
		local part, nodeId = self:_raycastForNodes()
		self:_setHoverHighlight(part)
	elseif mode == "Paint" then
		local model, triId = self:_raycastForTriangles()
		if model then
			self:_setHoverHighlight(model)
		else
			self:_clearHover()
		end
	elseif mode == "Sculpt" then
		self:_clearHover()
		self:_updateBrushCircle()
	end
end

function InputHandler:_setHoverHighlight(target: Instance?)
	if not target then
		self:_clearHover()
		return
	end

	if not self._hoverHighlight then
		self._hoverHighlight = Instance.new("Highlight")
		self._hoverHighlight.FillTransparency = 0.7
		self._hoverHighlight.OutlineTransparency = 0
		self._hoverHighlight.OutlineColor = Color3.fromRGB(0, 162, 255)
		self._hoverHighlight.FillColor = Color3.fromRGB(0, 162, 255)
		self._hoverHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	if self._hoverHighlight.Adornee ~= target then
		self._hoverHighlight.Adornee = target
		self._hoverHighlight.Parent = target
	end
end

function InputHandler:_clearHover()
	if self._hoverHighlight then
		self._hoverHighlight.Parent = nil
		self._hoverHighlight.Adornee = nil
	end
end

------------------------------------------------------------------------
-- Brush circle (sculpt mode visual)
------------------------------------------------------------------------
function InputHandler:_updateBrushCircle()
	if self._state.activeMode ~= "Sculpt" then
		self:_clearBrush()
		return
	end

	local result = self:_raycast()
	if not result then
		self:_clearBrush()
		return
	end

	if not self._brushCircle then
		self._brushCircle = Instance.new("Part")
		self._brushCircle.Name = "TT_BrushCircle"
		self._brushCircle.Shape = Enum.PartType.Cylinder
		self._brushCircle.Anchored = true
		self._brushCircle.CanCollide = false
		self._brushCircle.CastShadow = false
		self._brushCircle.Transparency = 0.7
		self._brushCircle.Color = Color3.fromRGB(0, 162, 255)
		self._brushCircle.Material = Enum.Material.Neon
		self._brushCircle.TopSurface = Enum.SurfaceType.Smooth
		self._brushCircle.BottomSurface = Enum.SurfaceType.Smooth
		self._brushCircle.Parent = workspace
	end

	local r = self._state.settings.brushRadius
	self._brushCircle.Size = Vector3.new(0.2, r * 2, r * 2)
	self._brushCircle.CFrame = CFrame.new(result.Position) * CFrame.Angles(0, 0, math.rad(90))
end

function InputHandler:_clearBrush()
	if self._brushCircle then
		self._brushCircle:Destroy()
		self._brushCircle = nil
	end
end

------------------------------------------------------------------------
-- Hotkeys
------------------------------------------------------------------------
function InputHandler:_handleKey(keyCode: Enum.KeyCode)
	if keyCode == Enum.KeyCode.One then
		self._state:SetMode("Place")
	elseif keyCode == Enum.KeyCode.Two then
		self._state:SetMode("Draw")
	elseif keyCode == Enum.KeyCode.Three then
		self._state:SetMode("Paint")
	elseif keyCode == Enum.KeyCode.Four then
		self._state:SetMode("Sculpt")
	elseif keyCode == Enum.KeyCode.Five then
		self._state:SetMode("Select")
	elseif keyCode == Enum.KeyCode.G then
		local current = self._state.settings.showGrid
		self._state:SetSetting("showGrid", not current)
	elseif keyCode == Enum.KeyCode.Delete then
		self:_deleteSelected()
	end
end

function InputHandler:_deleteSelected()
	for _, nodeId in self._state.selectedNodes do
		self._nodeManager:DeleteNode(nodeId)
	end
	for _, triId in self._state.selectedTriangles do
		self._nodeManager:DeleteTriangle(triId)
	end
	self._state:SelectNode(nil)
end

------------------------------------------------------------------------
-- Input binding
------------------------------------------------------------------------
function InputHandler:_bindInputs()
	table.insert(self._conns, self._mouse.Button1Down:Connect(function()
		if self._state.activeMode == "Sculpt" then
			self._sculpting = true
		else
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or
				UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			if shift then
				self:_onShiftClick()
			else
				self:_onClick()
			end
		end
	end))

	table.insert(self._conns, self._mouse.Button1Up:Connect(function()
		self._sculpting = false
	end))

	table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
				self._altHeld = true
			else
				self:_handleKey(input.KeyCode)
			end
		end
	end))

	table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			self._altHeld = false
		end
	end))

	table.insert(self._conns, RunService.Heartbeat:Connect(function()
		self:_updateHover()
		self:_updateGhostNode()
		self:_updateWorkPlane()
		if self._sculpting then
			self:_handleSculptTick()
		end
	end))
end

function InputHandler:_unbindInputs()
	for _, conn in self._conns do
		conn:Disconnect()
	end
	table.clear(self._conns)
	self._sculpting = false
end

function InputHandler:Destroy()
	self:Deactivate()
	self:_clearHover()
	self:_clearBrush()
	self:_clearGhost()
	self:_clearWorkPlane()
	if self._hoverHighlight then
		self._hoverHighlight:Destroy()
		self._hoverHighlight = nil
	end
end

return InputHandler
