--[[
	Triangle Terrain Plugin
	A modern triangle-based terrain editor for Roblox Studio.
	Uses a DockWidget UI with mode-based workflow, persistent
	node/triangle data, sculpt tools, and auto-triangulation.
]]

local TerrainState    = require(script.TerrainState)
local NodeManager     = require(script.NodeManager)
local InputHandler    = require(script.InputHandler)
local AutoTriangulate = require(script.AutoTriangulate)
local WidgetUI        = require(script.WidgetUI)

------------------------------------------------------------------------
-- Plugin toolbar
------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("Triangle Terrain")
local toggleBtn = toolbar:CreateButton(
	"TriTerrainToggle",
	"Open the Triangle Terrain editor",
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
widget.Title = "Triangle Terrain"
widget.Name = "TriangleTerrain"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

------------------------------------------------------------------------
-- Core systems
------------------------------------------------------------------------
local state = TerrainState.new()
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

		local triangles = AutoTriangulate.triangulate(visibleNodes)

		local created = 0
		for _, tri in triangles do
			local id = nodeManager:CreateTriangle(tri[1], tri[2], tri[3])
			if id then created += 1 end
		end

		print(string.format("[TriTerrain] Auto-triangulated: %d triangles from %d nodes.", created, #visibleNodes))
	end,

	onDeleteSelected = function()
		for _, nodeId in state.selectedNodes do
			nodeManager:DeleteNode(nodeId)
		end
		for _, triId in state.selectedTriangles do
			nodeManager:DeleteTriangle(triId)
		end
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
-- Cleanup
------------------------------------------------------------------------
plugin.Unloading:Connect(function()
	inputHandler:Destroy()
	ui:Destroy()
	nodeManager:Destroy()
end)
