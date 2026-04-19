--[[
	InputHandler
	Routes mouse/keyboard input to the correct mode behavior.
	Manages raycasting, hover highlights, and hotkeys.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SubdivisionEngine = require(script.Parent.SubdivisionEngine)
local TriangleEngine = require(script.Parent.TriangleEngine)

-- Sub-Divide always splits into the classic 1->4 (each edge bisected once).
-- Was a configurable 1-50 in earlier versions; reverted in 0.5.0 because the
-- single-step split + neighbor re-fan handles the common case cleanly and
-- variable-resolution borders introduce T-junction problems.
local SUBDIV_INCREMENT = 1

-- Hover-highlight palette. Declared at module top so EVERY method can see them
-- as upvalues. Previously these lived next to _ensureHoverHighlight (further
-- down the file), but Luau locals are lexically scoped from their declaration
-- onwards — methods defined above the declaration (like _updateHover) saw
-- HOVER_COLOR_DELETE as a global and got `nil`, which fell back to blue. That
-- silent fallback is exactly the "red highlight is not happening, it's blue"
-- bug that 0.10.2 fixes.
local HOVER_COLOR_DEFAULT = Color3.fromRGB(0, 162, 255)
local HOVER_COLOR_DELETE = Color3.fromRGB(220, 60, 60)

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
	self._subdivPreview = nil :: Folder?
	self._subdivPreviewKey = nil :: string?
	-- Persistent highlights showing what's currently selected. One per
	-- selected item, keyed by id ("node:<id>" or "tri:<id>") so we can
	-- diff-rebuild instead of nuking + recreating every selection change.
	self._selectionHighlights = {} :: { [string]: Highlight }
	-- Outer ChangeHistory recording held for the duration of one sculpt
	-- drag. Without this, each Heartbeat tick records its own entry, so a
	-- 2-second stroke produces ~120 separate undo steps.
	self._sculptRecording = nil
	-- Same idea for Delete drag-strokes: one outer recording wraps every
	-- triangle nuked between Button1Down and Button1Up so the whole sweep
	-- collapses into one undo step.
	self._deleteRecording = nil
	self._deleting = false
	self._deleteStrokeCount = 0
	-- Connections kept open only during a delete drag — count every
	-- nodeRemoved / triangleRemoved fire in the stroke window so the
	-- panel's "Deleted: N" reflects ALL victims, including cascades from
	-- DeleteNode (1 node click can wipe ~6 connected triangles + orphan
	-- neighbors). Without this the counter undercounts and lies to the
	-- user about how much disappeared.
	self._deleteWatchConns = nil :: { RBXScriptConnection }?
	return self
end

function InputHandler:Activate()
	-- Safe to call after a Deactivate that closed an in-progress sculpt or
	-- delete recording. Deactivate clears self._sculpting/_deleting and
	-- nils both recording handles, so a fresh Activate doesn't inherit any
	-- half-open ChangeHistoryService state. Double-Activate without
	-- Deactivate would double-bind inputs — guarded against here too.
	if self._active then return end
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
	self:_clearSubdivPreview()
	self:_clearSelectionHighlights()
	-- If we deactivate mid-sculpt-stroke, close the open recording so it
	-- doesn't leak (and so the partial stroke stays undoable).
	if self._sculptRecording then
		ChangeHistoryService:FinishRecording(self._sculptRecording, Enum.FinishRecordingOperation.Commit)
		self._sculptRecording = nil
	end
	-- Same for an in-progress delete drag. Cancel if no actual deletes
	-- happened (user pressed mouse over empty space then deactivated).
	if self._deleteWatchConns then
		for _, c in self._deleteWatchConns do c:Disconnect() end
		self._deleteWatchConns = nil
	end
	if self._deleteRecording then
		local op = if self._deleteStrokeCount > 0
			then Enum.FinishRecordingOperation.Commit
			else Enum.FinishRecordingOperation.Cancel
		ChangeHistoryService:FinishRecording(self._deleteRecording, op)
		self._deleteRecording = nil
	end
	self._deleting = false
	if self._deleteStrokeCount > 0 then
		self._deleteStrokeCount = 0
		self._state:SetDeleteStrokeCount(0)
	end
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
	if self._subdivPreview then
		table.insert(exclude, self._subdivPreview)
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
	elseif mode == "Delete" then
		self:_handleDeleteClick()
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
	if self._state.drawSubMode == "SubDivide" then
		local _, triId = self:_raycastForTriangles()
		if triId then
			self._nodeManager:SubdivideTriangle(triId, SUBDIV_INCREMENT)
			self:_clearSubdivPreview()
		end
		return
	end

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
-- Delete mode
--
-- Click deletes the hovered triangle. Holding the mouse opens a single
-- ChangeHistoryService recording (see Button1Down handler below) so a
-- whole sweep collapses into one undo step. The actual per-frame delete
-- during a drag happens inside _updateHover so triangles can be picked
-- off as the cursor moves over them — there's no need to re-click.
------------------------------------------------------------------------
function InputHandler:_handleDeleteClick()
	local nodesEnabled = self._state.settings.deleteNodesEnabled

	-- Same prefer-node-then-triangle priority as the hover handler so the
	-- click and hover always agree on what's about to die.
	-- The "Deleted: N" counter is bumped by nodeRemoved/triangleRemoved
	-- subscriptions opened in Button1Down — no manual increments here so
	-- cascades (DeleteNode killing 6 connected tris) get counted too.
	if nodesEnabled then
		local _, nodeId = self:_raycastForNodes()
		if nodeId then
			self._nodeManager:DeleteNode(nodeId)
			return
		end
	end

	local _, triId = self:_raycastForTriangles()
	if triId then
		if nodesEnabled then
			self._nodeManager:DeleteTriangleAndOrphans(triId)
		else
			self._nodeManager:DeleteTriangle(triId)
		end
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
--
-- Visual layout (one Model rooted at TT_WorkPlane):
--   * "Slab"        — the main translucent cyan plate (raycast target for
--                     placing nodes in mid-air). Bottom surface is what
--                     the user looks at, but the raycast uses the top.
--   * "Edges"       — SelectionBox adornee'd to the slab for crisp,
--                     always-readable borders no matter the view angle.
--   * "CrossX"/"CrossZ" — thin Neon ribbons forming a "+" at the centre
--                     so the user immediately sees where the camera
--                     column intersects the plane.
--   * "Label"       — SurfaceGui hovering on top of the slab showing the
--                     live Y value (and "LOCKED" tag when locked), so the
--                     user can read the plane's height directly in 3D.
--
-- When workPlaneLocked is true, the Y stays at workPlaneFixedY and the
-- camera-relative Y offset is ignored. X/Z still snap to the grid under
-- the camera so the plane stays useful as the user pans around.
------------------------------------------------------------------------
local WORK_PLANE_SIZE = 512
local WORK_PLANE_FILL = Color3.fromRGB(70, 190, 230)
local WORK_PLANE_EDGE = Color3.fromRGB(120, 220, 255)
local WORK_PLANE_LOCKED_EDGE = Color3.fromRGB(255, 200, 70)

function InputHandler:_buildWorkPlane()
	local model = Instance.new("Model")
	model.Name = "TT_WorkPlane"

	local slab = Instance.new("Part")
	slab.Name = "Slab"
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanTouch = false
	slab.CastShadow = false
	slab.Transparency = 0.7
	slab.Color = WORK_PLANE_FILL
	slab.Material = Enum.Material.SmoothPlastic
	slab.TopSurface = Enum.SurfaceType.Smooth
	slab.BottomSurface = Enum.SurfaceType.Smooth
	slab.Size = Vector3.new(WORK_PLANE_SIZE, 0.05, WORK_PLANE_SIZE)
	slab.Parent = model

	local texture = Instance.new("Texture")
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = self._state.settings.gridSize
	texture.StudsPerTileV = self._state.settings.gridSize
	texture.Transparency = 0.35
	texture.Color3 = Color3.fromRGB(220, 240, 255)
	texture.Parent = slab
	self._workPlaneTexture = texture

	local edges = Instance.new("SelectionBox")
	edges.Name = "Edges"
	edges.Adornee = slab
	edges.Color3 = WORK_PLANE_EDGE
	edges.LineThickness = 0.06
	edges.SurfaceTransparency = 1
	edges.Transparency = 0
	edges.Parent = model
	self._workPlaneEdges = edges

	-- Centre crosshair — two thin neon ribbons. Slightly raised so they
	-- don't z-fight with the slab top surface.
	local function makeCrossArm(name, sizeVec)
		local arm = Instance.new("Part")
		arm.Name = name
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanTouch = false
		arm.CanQuery = false
		arm.CastShadow = false
		arm.Material = Enum.Material.Neon
		arm.Color = WORK_PLANE_EDGE
		arm.Transparency = 0.3
		arm.Size = sizeVec
		arm.Parent = model
		return arm
	end
	self._workPlaneCrossX = makeCrossArm("CrossX", Vector3.new(WORK_PLANE_SIZE * 0.18, 0.06, 0.18))
	self._workPlaneCrossZ = makeCrossArm("CrossZ", Vector3.new(0.18, 0.06, WORK_PLANE_SIZE * 0.18))

	-- Floating Y readout. Sized in studs (PixelsPerStud) so it reads at a
	-- consistent physical size regardless of camera distance.
	local labelHost = Instance.new("Part")
	labelHost.Name = "LabelHost"
	labelHost.Anchored = true
	labelHost.CanCollide = false
	labelHost.CanTouch = false
	labelHost.CanQuery = false
	labelHost.CastShadow = false
	labelHost.Transparency = 1
	labelHost.Size = Vector3.new(8, 0.05, 2)
	labelHost.Parent = model

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.AlwaysOnTop = true
	sg.PixelsPerStud = 50
	sg.Parent = labelHost

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Y: 0.0"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 30, 60)
	lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	lbl.TextScaled = true
	lbl.Parent = sg

	self._workPlaneLabelHost = labelHost
	self._workPlaneLabel = lbl

	model.Parent = workspace
	self._workPlane = model
	self._workPlaneSlab = slab
end

function InputHandler:_updateWorkPlane()
	if not self._state.settings.workPlaneEnabled then
		self:_clearWorkPlane()
		return
	end

	if not self._workPlane or not self._workPlane.Parent then
		self:_buildWorkPlane()
	end

	local cam = workspace.CurrentCamera
	if not cam then return end

	local s = self._state.settings
	local camPos = cam.CFrame.Position
	local grid = s.gridSize

	local snapX = math.round(camPos.X / grid) * grid
	local snapZ = math.round(camPos.Z / grid) * grid

	local y
	if s.workPlaneLocked then
		y = s.workPlaneFixedY
	else
		y = camPos.Y - s.workPlaneYOffset
	end

	local centre = Vector3.new(snapX, y, snapZ)
	self._workPlaneSlab.Position = centre

	-- Crosshair arms sit a hair above the slab top to avoid z-fighting.
	local crossY = y + 0.04
	self._workPlaneCrossX.Position = Vector3.new(snapX, crossY, snapZ)
	self._workPlaneCrossZ.Position = Vector3.new(snapX, crossY, snapZ)

	-- Label hovers a few studs above the centre so it never disappears
	-- behind the slab when looking from below.
	self._workPlaneLabelHost.Position = Vector3.new(snapX, y + 0.08, snapZ)

	-- Edge color flips to amber when locked so the lock state is obvious
	-- at a glance, even without looking at the panel.
	local edgeColor = s.workPlaneLocked and WORK_PLANE_LOCKED_EDGE or WORK_PLANE_EDGE
	self._workPlaneEdges.Color3 = edgeColor
	self._workPlaneCrossX.Color = edgeColor
	self._workPlaneCrossZ.Color = edgeColor

	if self._workPlaneLabel then
		self._workPlaneLabel.Text = string.format(
			"%sY: %.1f",
			if s.workPlaneLocked then "LOCKED  " else "",
			y
		)
		self._workPlaneLabel.TextColor3 = if s.workPlaneLocked
			then Color3.fromRGB(255, 220, 140)
			else Color3.fromRGB(255, 255, 255)
	end

	if self._workPlaneTexture then
		self._workPlaneTexture.StudsPerTileU = grid
		self._workPlaneTexture.StudsPerTileV = grid
	end

	-- Broadcast live Y to the UI (throttled inside SetWorkPlaneCurrentY).
	self._state:SetWorkPlaneCurrentY(y)
end

function InputHandler:_clearWorkPlane()
	if self._workPlane then
		self._workPlane:Destroy()
		self._workPlane = nil
		self._workPlaneSlab = nil
		self._workPlaneTexture = nil
		self._workPlaneEdges = nil
		self._workPlaneCrossX = nil
		self._workPlaneCrossZ = nil
		self._workPlaneLabel = nil
		self._workPlaneLabelHost = nil
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

	if mode == "Draw" and self._state.drawSubMode == "SubDivide" then
		local model, triId = self:_raycastForTriangles()
		if model and triId then
			self:_setHoverHighlight(model)
			self:_updateSubdivPreview(triId)
		else
			self:_clearHover()
			self:_clearSubdivPreview()
		end
		return
	else
		-- Make sure preview disappears when leaving SubDivide mode.
		if self._subdivPreview then
			self:_clearSubdivPreview()
		end
	end

	if mode == "Place" or mode == "Draw" then
		local part, _ = self:_raycastForNodes()
		self:_setHoverHighlight(part)
	elseif mode == "Select" then
		-- Select can target either nodes or triangles, so hover should reflect
		-- whichever is under the cursor. Prefer nodes (smaller, more precise)
		-- and fall back to the underlying triangle.
		local part, _ = self:_raycastForNodes()
		if part then
			self:_setHoverHighlight(part)
		else
			local model, _ = self:_raycastForTriangles()
			if model then
				self:_setHoverHighlight(model)
			else
				self:_clearHover()
			end
		end
	elseif mode == "Paint" then
		local model, _ = self:_raycastForTriangles()
		if model then
			self:_setHoverHighlight(model)
		else
			self:_clearHover()
		end
	elseif mode == "Delete" then
		-- Hover paints the target red so the user knows what'll die. If a
		-- delete drag is in progress (mouse held), every new target the
		-- cursor sweeps over also gets deleted in the same undo recording.
		--
		-- When "Delete Nodes" is on we prefer nodes over triangles (smaller
		-- hit target, more precise), falling back to triangles — same
		-- priority logic Select mode uses.
		local nodesEnabled = self._state.settings.deleteNodesEnabled

		-- Counter is bumped by nodeRemoved/triangleRemoved subscriptions in
		-- the Button1Down handler — no manual SetDeleteStrokeCount here.
		if nodesEnabled then
			local part, nodeId = self:_raycastForNodes()
			if part and nodeId then
				self:_setHoverHighlight(part, HOVER_COLOR_DELETE)
				if self._deleting then
					-- DeleteNode cascades to its connected triangles already.
					self._nodeManager:DeleteNode(nodeId)
					self:_clearHover()
				end
				return
			end
		end

		local model, triId = self:_raycastForTriangles()
		if model and triId then
			self:_setHoverHighlight(model, HOVER_COLOR_DELETE)
			if self._deleting then
				if nodesEnabled then
					self._nodeManager:DeleteTriangleAndOrphans(triId)
				else
					self._nodeManager:DeleteTriangle(triId)
				end
				-- Triangle is gone now — kill the highlight this tick so it
				-- doesn't briefly orphan onto the destroyed model.
				self:_clearHover()
			end
		else
			self:_clearHover()
		end
	elseif mode == "Sculpt" then
		self:_clearHover()
		self:_updateBrushCircle()
	else
		-- "Presets" or any unknown mode: pure UI, no world interaction.
		self:_clearHover()
		self:_clearBrush()
	end
end

-- Build (or rebuild) the hover highlight. We parent it to workspace once and
-- only ever change Adornee/Enabled, so the highlight's lifetime is decoupled
-- from any specific instance it adorns. Without this, deleting a hovered
-- triangle (e.g. during SubdivideTriangle) would destroy the highlight, and
-- the next frame's reparent would throw "Parent property is locked". We also
-- toggle Enabled instead of nilling Adornee, because a Highlight with
-- Adornee=nil falls back to adorning its Parent — which would light up the
-- entire workspace.
-- (HOVER_COLOR_* constants live at the top of this file — see note there.)
function InputHandler:_ensureHoverHighlight()
	if self._hoverHighlight and self._hoverHighlight.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "TT_HoverHighlight"
	h.FillTransparency = 0.7
	h.OutlineTransparency = 0
	h.OutlineColor = HOVER_COLOR_DEFAULT
	h.FillColor = HOVER_COLOR_DEFAULT
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = false
	h.Parent = workspace
	self._hoverHighlight = h
end

-- Optional `color` overrides the default blue. Used by Delete mode to
-- signal "click and this dies" with a red fill, and bumps the fill
-- transparency lower so the warning reads strongly.
function InputHandler:_setHoverHighlight(target: Instance?, color: Color3?)
	if not target then
		self:_clearHover()
		return
	end
	-- Bail if the target is no longer in the data model (raced deletion).
	if not target.Parent then
		self:_clearHover()
		return
	end

	self:_ensureHoverHighlight()
	local c = color or HOVER_COLOR_DEFAULT
	if self._hoverHighlight.FillColor ~= c then
		self._hoverHighlight.FillColor = c
		self._hoverHighlight.OutlineColor = c
	end
	-- Stronger fill for destructive (red) state so the user can't miss it.
	local desiredFillT = if color == HOVER_COLOR_DELETE then 0.45 else 0.7
	if self._hoverHighlight.FillTransparency ~= desiredFillT then
		self._hoverHighlight.FillTransparency = desiredFillT
	end
	if self._hoverHighlight.Adornee ~= target then
		self._hoverHighlight.Adornee = target
	end
	if not self._hoverHighlight.Enabled then
		self._hoverHighlight.Enabled = true
	end
end

function InputHandler:_clearHover()
	if self._hoverHighlight and self._hoverHighlight.Parent then
		self._hoverHighlight.Enabled = false
	end
end

------------------------------------------------------------------------
-- Selection visualization
--
-- Two layers of feedback for selected nodes/triangles in Select mode:
--   1. Our own gold Highlight overlays (always-on-top, depth-independent)
--      so the user can see at a glance what's selected even through
--      occluding geometry.
--   2. Studio's native Selection service is also synced, so the user gets
--      the familiar selection box + can see attributes/properties of the
--      selected parts in Studio's Properties panel. (Answers the common
--      question "is this selection like Studio's regular selection?" — yes,
--      we mirror to it.)
--
-- Both are cleared when the user leaves Select mode or the plugin tool is
-- deactivated, so they don't pollute the workspace.
------------------------------------------------------------------------
local SELECTION_COLOR = Color3.fromRGB(255, 200, 50)

function InputHandler:_refreshSelectionHighlights()
	-- Build the desired set of (key -> instance) for the current selection.
	local desired: { [string]: Instance } = {}

	if self._state.activeMode == "Select" then
		for _, nodeId in self._state.selectedNodes do
			local nd = self._state.nodes[nodeId]
			if nd and nd.part and nd.part.Parent then
				desired["node:" .. nodeId] = nd.part
			end
		end
		for _, triId in self._state.selectedTriangles do
			local td = self._state.triangles[triId]
			if td and td.model and td.model.Parent then
				desired["tri:" .. triId] = td.model
			end
		end
	end

	-- Drop highlights that are no longer wanted.
	for key, hl in self._selectionHighlights do
		if not desired[key] then
			pcall(function() hl:Destroy() end)
			self._selectionHighlights[key] = nil
		end
	end

	-- Add highlights for newly-selected items.
	for key, target in desired do
		local existing = self._selectionHighlights[key]
		if existing and existing.Parent then
			if existing.Adornee ~= target then
				existing.Adornee = target
			end
		else
			local hl = Instance.new("Highlight")
			hl.Name = "TT_SelectionHighlight"
			hl.FillColor = SELECTION_COLOR
			hl.OutlineColor = SELECTION_COLOR
			hl.FillTransparency = 0.55
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = target
			hl.Parent = workspace
			self._selectionHighlights[key] = hl
		end
	end

	-- Mirror to Studio's Selection. Replaces whatever the user had selected
	-- before — that's intentional, since we own the active tool.
	local studioPick: { Instance } = {}
	for _, target in desired do
		table.insert(studioPick, target)
	end
	pcall(function()
		Selection:Set(studioPick)
	end)
end

function InputHandler:_clearSelectionHighlights()
	for key, hl in self._selectionHighlights do
		pcall(function() hl:Destroy() end)
		self._selectionHighlights[key] = nil
	end
	-- Only clear Studio's Selection if it's currently holding what we put
	-- there; don't stomp on the user's selection from other tools.
	pcall(function()
		Selection:Set({})
	end)
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
-- Sub-Divide preview (Draw mode, sub-mode = SubDivide)
------------------------------------------------------------------------
function InputHandler:_updateSubdivPreview(triId: string)
	local triData = self._state.triangles[triId]
	if not triData then
		self:_clearSubdivPreview()
		return
	end

	local key = triId
	if self._subdivPreviewKey == key and self._subdivPreview then
		return -- cached preview is still valid
	end

	local nA = self._state.nodes[triData.nodeA]
	local nB = self._state.nodes[triData.nodeB]
	local nC = self._state.nodes[triData.nodeC]
	if not nA or not nB or not nC then
		self:_clearSubdivPreview()
		return
	end

	self:_clearSubdivPreview()

	local folder = Instance.new("Folder")
	folder.Name = "TT_SubdividePreview"
	folder.Parent = workspace
	self._subdivPreview = folder
	self._subdivPreviewKey = key

	local verts, tris = SubdivisionEngine.subdivide(nA.position, nB.position, nC.position, SUBDIV_INCREMENT)

	-- A bright cyan, semi-transparent, slightly raised triangle for each sub-tri.
	-- We lift the previews along the parent's normal a hair to avoid z-fighting
	-- with the original wedge faces.
	local normal = TriangleEngine.getNormal(nA.position, nB.position, nC.position)
	local lift = normal * 0.05

	for _, tri in tris do
		local a = verts[tri[1]] + lift
		local b = verts[tri[2]] + lift
		local c = verts[tri[3]] + lift
		local w1, w2 = TriangleEngine.draw(a, b, c, 0.08)
		for _, w in { w1, w2 } do
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Transparency = 0.4
			w.Color = Color3.fromRGB(0, 230, 255)
			w.Material = Enum.Material.Neon
			w.Parent = folder
		end
	end

	-- Bright outline for each sub-edge so the topology is obvious even from
	-- shallow viewing angles. We use small thin parts for edges.
	local edgeSet: { [string]: boolean } = {}
	local function addEdge(i: number, j: number)
		local lo, hi = math.min(i, j), math.max(i, j)
		local k = lo .. "-" .. hi
		if edgeSet[k] then return end
		edgeSet[k] = true

		local p1 = verts[lo] + lift
		local p2 = verts[hi] + lift
		local diff = p2 - p1
		local len = diff.Magnitude
		if len < 0.01 then return end

		local edge = Instance.new("Part")
		edge.Name = "Edge"
		edge.Anchored = true
		edge.CanCollide = false
		edge.CanQuery = false
		edge.CanTouch = false
		edge.CastShadow = false
		edge.Material = Enum.Material.Neon
		edge.Color = Color3.fromRGB(255, 255, 255)
		edge.Transparency = 0.1
		edge.Size = Vector3.new(0.08, 0.08, len)
		edge.CFrame = CFrame.lookAt(p1 + diff * 0.5, p2)
		edge.Parent = folder
	end

	for _, tri in tris do
		addEdge(tri[1], tri[2])
		addEdge(tri[2], tri[3])
		addEdge(tri[3], tri[1])
	end
end

function InputHandler:_clearSubdivPreview()
	if self._subdivPreview then
		self._subdivPreview:Destroy()
		self._subdivPreview = nil
	end
	self._subdivPreviewKey = nil
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
	elseif keyCode == Enum.KeyCode.Six then
		self._state:SetMode("Delete")
	elseif keyCode == Enum.KeyCode.G then
		local current = self._state.settings.showGrid
		self._state:SetSetting("showGrid", not current)
	elseif keyCode == Enum.KeyCode.Delete then
		self:_deleteSelected()
	elseif keyCode == Enum.KeyCode.Escape then
		-- Abort an in-progress 3-vertex draw pick. Replaces the old
		-- "Clear Selection" panel button (removed in 0.8.1).
		if self._state.activeMode == "Draw" and #self._state.drawSelection > 0 then
			self._state:ClearDrawSelection()
		end
	end
end

function InputHandler:_deleteSelected()
	self._nodeManager:DeleteMany(self._state.selectedNodes, self._state.selectedTriangles)
	self._state:SelectNode(nil)
end

------------------------------------------------------------------------
-- Input binding
------------------------------------------------------------------------
function InputHandler:_bindInputs()
	table.insert(self._conns, self._mouse.Button1Down:Connect(function()
		if self._state.activeMode == "Sculpt" then
			self._sculpting = true
			-- Open one outer recording for the whole drag. Inner per-tick
			-- Sculpt* calls' TryBeginRecording will return nil while ours is
			-- in flight, batching the entire stroke into one undo step.
			self._sculptRecording = ChangeHistoryService:TryBeginRecording("SculptStroke")
		elseif self._state.activeMode == "Delete" then
			-- Same recording-batch pattern as Sculpt: one undo step per drag.
			self._deleting = true
			self._deleteStrokeCount = 0
			self._state:SetDeleteStrokeCount(0)
			self._deleteRecording = ChangeHistoryService:TryBeginRecording("DeleteStroke")
			-- Subscribe to removal signals so cascade-deleted triangles
			-- (DeleteNode wipes connected tris) and orphan-deleted nodes
			-- (DeleteTriangleAndOrphans) get counted too. Inner _handleDelete*
			-- code no longer touches the counter directly — single source of
			-- truth = "actually removed from state".
			local handleRemoved = function()
				self._deleteStrokeCount += 1
				self._state:SetDeleteStrokeCount(self._deleteStrokeCount)
			end
			self._deleteWatchConns = {
				self._state.nodeRemoved:Connect(handleRemoved),
				self._state.triangleRemoved:Connect(handleRemoved),
			}
			-- Delete the triangle directly under the cursor on press, so a
			-- single click (no drag) still works.
			self:_onClick()
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
		if self._sculptRecording then
			ChangeHistoryService:FinishRecording(self._sculptRecording, Enum.FinishRecordingOperation.Commit)
			self._sculptRecording = nil
		end
		if self._deleting then
			self._deleting = false
			-- Tear down the per-stroke removal-watchers BEFORE finishing the
			-- recording. A late removal during the post-stroke logic would
			-- otherwise bump the counter we're about to reset.
			if self._deleteWatchConns then
				for _, c in self._deleteWatchConns do c:Disconnect() end
				self._deleteWatchConns = nil
			end
			if self._deleteRecording then
				-- If the user clicked Delete on empty space (or released
				-- before the cursor swept across anything), the recording
				-- captured zero mutations. Cancel it so the undo stack
				-- doesn't fill with no-op "DeleteStroke" entries.
				local op = if self._deleteStrokeCount > 0
					then Enum.FinishRecordingOperation.Commit
					else Enum.FinishRecordingOperation.Cancel
				ChangeHistoryService:FinishRecording(self._deleteRecording, op)
				self._deleteRecording = nil
			end
			-- Clear the panel counter on stroke end. The "n triangles deleted"
			-- info the user cares about post-stroke is the undo entry name +
			-- visible terrain change; no need to leave a stale label.
			self._deleteStrokeCount = 0
			self._state:SetDeleteStrokeCount(0)
		end
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

	-- Selection visuals: rebuild whenever selection changes, and clear when
	-- leaving Select mode (the highlights/Studio selection only make sense
	-- there).
	table.insert(self._conns, self._state.selectionChanged:Connect(function()
		self:_refreshSelectionHighlights()
	end))
	table.insert(self._conns, self._state.modeChanged:Connect(function(mode)
		if mode == "Select" then
			self:_refreshSelectionHighlights()
		else
			self:_clearSelectionHighlights()
		end
	end))
	-- Initial sync in case we activate while already in Select mode.
	self:_refreshSelectionHighlights()
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
	self:_clearSubdivPreview()
	self:_clearSelectionHighlights()
	if self._hoverHighlight then
		pcall(function() self._hoverHighlight:Destroy() end)
		self._hoverHighlight = nil
	end
end

return InputHandler
