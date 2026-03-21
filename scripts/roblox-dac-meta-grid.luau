--!nonstrict
--[[
  DAC — arrange the three export grids (egg / pet / vehicle) as one meta-layout in Workspace.

  Run in Studio (MCP execute_luau) or Command Bar after each grid folder exists on the new place.
  Translates every Model under each folder in world space (Model:TranslateBy).

  Re-running pet/egg/vehicle TARGET_ORGANIZE scripts resets those models to local origins — run this
  meta script again afterward if needed.

  Tweak META_SPACING and LAYOUT below.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

-- Distance between the *centers* of adjacent grids (studs). Increase if grids overlap.
local META_SPACING = 250

-- "ROW_X" = one row along +X | "ROW_Z" = one row along +Z | "GRID_2x2" = 2 cols, wrap row (3 items)
local LAYOUT = "ROW_X"

-- World anchor: first grid’s center is placed here (XZ); each grid keeps its own average Y.
local ANCHOR = Vector3.new(0, 0, 0)

-- Order left-to-right (ROW_X) or front-to-back (ROW_Z)
local GRID_FOLDERS = {
	"_DAC_EggExportGrid",
	"_DAC_PetExportGrid",
	"_DAC_VehicleGrid",
}

local function avgPivotPosition(folder)
	local sum = Vector3.zero
	local n = 0
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			sum = sum + ch:GetPivot().Position
			n = n + 1
		end
	end
	if n == 0 then
		return nil
	end
	return sum / n
end

local function translateGroup(folder, delta)
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			ch:TranslateBy(delta)
		end
	end
end

local function slotPosition(index0)
	if LAYOUT == "ROW_X" then
		return Vector3.new(ANCHOR.X + index0 * META_SPACING, ANCHOR.Y, ANCHOR.Z)
	elseif LAYOUT == "ROW_Z" then
		return Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z + index0 * META_SPACING)
	elseif LAYOUT == "GRID_2x2" then
		local col = index0 % 2
		local row = math.floor(index0 / 2)
		return Vector3.new(ANCHOR.X + col * META_SPACING, ANCHOR.Y, ANCHOR.Z + row * META_SPACING)
	else
		return ANCHOR
	end
end

local folders = {}
local missing = {}
for _, name in ipairs(GRID_FOLDERS) do
	local f = Workspace:FindFirstChild(name)
	if f and f:IsA("Folder") then
		table.insert(folders, f)
	else
		table.insert(missing, name)
	end
end

if #missing > 0 then
	return "ERROR: Missing folder(s): " .. table.concat(missing, ", ")
end

local parts = {}
for i, folder in ipairs(folders) do
	local center = avgPivotPosition(folder)
	if not center then
		return "ERROR: No models in " .. folder.Name
	end
	local idx = i - 1
	local slot = slotPosition(idx)
	-- Keep each grid’s vertical level (eggs/pets vs vehicles).
	slot = Vector3.new(slot.X, center.Y, slot.Z)
	local delta = slot - center
	translateGroup(folder, delta)
	table.insert(
		parts,
		string.format("%s → center ~(%.0f,%.0f,%.0f)", folder.Name, slot.X, slot.Y, slot.Z)
	)
end

Selection:Set(folders)
return "OK: meta grid (" .. LAYOUT .. ", spacing=" .. tostring(META_SPACING) .. "): " .. table.concat(parts, " | ")
