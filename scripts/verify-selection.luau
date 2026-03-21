--!nonstrict
--[[
  Run via MCP execute_luau (or Command Bar) to see what Explorer / Studio currently has selected.
  Compare to what you intend before Ctrl+C. Does not read the OS clipboard.

  return value example:
  OK: 1 selected: _DAC_VehicleGrid (Folder)
]]
local Selection = game:GetService("Selection")
local sel = Selection:Get()
if #sel == 0 then
	return "SELECTION: (empty)"
end
local parts = {}
for _, inst in ipairs(sel) do
	table.insert(parts, inst.Name .. " (" .. inst.ClassName .. ")")
end
return "OK: " .. tostring(#sel) .. " selected: " .. table.concat(parts, " | ")
