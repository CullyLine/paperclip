--!strict
--[[
	POLA-344 alias: same module as UILayerStack.luau (DisplayOrder + ZIndex bands).
	Prefer `require(...UILayerStack)` in existing code; either path returns one table.
]]
return require(script.Parent:WaitForChild("UILayerStack"))
