--[[
	Triangle Terrain Plugin
	A modern triangle-based terrain editor for Roblox Studio.
	Uses a DockWidget UI with mode-based workflow, persistent
	node/triangle data, sculpt tools, and auto-triangulation.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TerrainState    = require(script.TerrainState)
local NodeManager     = require(script.NodeManager)
local InputHandler    = require(script.InputHandler)
local AutoTriangulate = require(script.AutoTriangulate)
local WidgetUI        = require(script.WidgetUI)
local MaterialPresets = require(script.MaterialPresets)
local Version         = require(script.Version)

local TITLE = "Triangle Terrain v" .. Version.STRING

------------------------------------------------------------------------
-- Plugin toolbar
------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("Triangle Terrain")
local toggleBtn = toolbar:CreateButton(
	"TriTerrainToggle",
	"Open the Triangle Terrain editor (" .. TITLE .. ")",
	"rbxassetid://6034818372",
	"Triangle Terrain"
)

------------------------------------------------------------------------
-- DockWidget
------------------------------------------------------------------------
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	340, 550,
	320, 400
)

local widget = plugin:CreateDockWidgetPluginGui("TriangleTerrain", widgetInfo)
widget.Title = TITLE
widget.Name = "TriangleTerrain"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

print(string.format("[TriTerrain] Loaded %s", TITLE))

------------------------------------------------------------------------
-- Core systems
------------------------------------------------------------------------
local state = TerrainState.new()
state.materialPresets = MaterialPresets.new(plugin)
local nodeManager = NodeManager.new(state)
local mouse = plugin:GetMouse()
local inputHandler = InputHandler.new(state, nodeManager, mouse)

------------------------------------------------------------------------
-- Callbacks for WidgetUI
------------------------------------------------------------------------
local callbacks = {
	onAutoTriangulate = function()
		local visibleNodes = {}
		for nodeId, nodeData in state.nodes do
			if nodeManager:NodePassesFilter(nodeId) then
				table.insert(visibleNodes, {
					nodeId = nodeId,
					position = nodeData.position,
				})
			end
		end

		if #visibleNodes < 3 then
			warn("[TriTerrain] Need at least 3 visible nodes to auto-triangulate.")
			return
		end

		local triangles = AutoTriangulate.triangulate(
			visibleNodes,
			state.settings.autoTriMaxEdgeFactor
		)

		-- One outer recording so the whole batch is a single undo step.
		-- CreateTriangle's own TryBeginRecording will return nil while ours
		-- is in flight, so we don't get N separate undo entries.
		local recording = ChangeHistoryService:TryBeginRecording("AutoTriangulate")

		local created = 0
		for _, tri in triangles do
			local id = nodeManager:CreateTriangle(tri[1], tri[2], tri[3])
			if id then created += 1 end
		end

		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end

		print(string.format("[TriTerrain] Auto-triangulated: %d triangles from %d nodes.", created, #visibleNodes))
	end,

	onDeleteSelected = function()
		-- Routed through NodeManager:DeleteMany so this matches the keyboard
		-- delete path (single undo step covering both nodes and triangles).
		nodeManager:DeleteMany(state.selectedNodes, state.selectedTriangles)
		state:SelectNode(nil)
	end,
}

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local ui = WidgetUI.new(widget, state, nodeManager, callbacks)

------------------------------------------------------------------------
-- Activation
------------------------------------------------------------------------
local function onActivate()
	plugin:Activate(true)
	inputHandler:Activate()
end

local function onDeactivate()
	plugin:Deactivate()
	inputHandler:Deactivate()
end

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled then
		onActivate()
	else
		onDeactivate()
	end
end)

toggleBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

------------------------------------------------------------------------
-- Load persisted data from workspace
------------------------------------------------------------------------
nodeManager:LoadFromWorkspace()

if widget.Enabled then
	onActivate()
end

------------------------------------------------------------------------
-- Tag filter reactivity
------------------------------------------------------------------------
state.tagFilterChanged:Connect(function()
	nodeManager:ApplyTagFilter()
end)

------------------------------------------------------------------------
-- Undo/redo state reconciliation
--
-- Studio's ChangeHistoryService restores the workspace instances on Ctrl+Z,
-- but our self._state.nodes / .triangles maps don't know that the
-- previously-deleted parts came back (or that previously-restored parts
-- went away again on redo). Resync after every undo/redo so hover, paint,
-- delete and selection all act on what's actually in the scene.
------------------------------------------------------------------------
ChangeHistoryService.OnUndo:Connect(function()
	nodeManager:ResyncFromWorkspace()
end)
ChangeHistoryService.OnRedo:Connect(function()
	nodeManager:ResyncFromWorkspace()
end)

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
plugin.Unloading:Connect(function()
	inputHandler:Destroy()
	ui:Destroy()
	nodeManager:Destroy()
end)
