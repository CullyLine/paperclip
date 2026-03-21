--!nonstrict
--[[
  DAC — move Workspace export grids into the folders the game / tooling expects.

  Source (Workspace)              →  Destination
  ----------------                  ---------------
  _DAC_EggExportGrid              →  ReplicatedStorage.EggModels
  _DAC_PetExportGrid              →  ReplicatedStorage.PetModels
  _DAC_VehicleGrid                →  ServerStorage.CarModels

  Also ensures Workspace.ActivePets exists (empty folder for spawned pet clones).

  Run once in Studio (MCP execute_luau / Command Bar) on the new place after grids are laid out.
  If the destination folder already has a model with the same name, the **incoming** copy from
  `_DAC_*` is destroyed (no `name_2` duplicates). Otherwise the model is moved as-is.

  After this, you can delete any leftover empty _DAC_* folders (script destroys them if empty).
  If you already merged duplicates with suffixed names, run `roblox-dac-dedupe-models.luau`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local function uniqueName(parent, base)
	if not parent:FindFirstChild(base) then
		return base
	end
	local i = 2
	while parent:FindFirstChild(base .. "_" .. tostring(i)) do
		i = i + 1
	end
	return base .. "_" .. tostring(i)
end

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	if f then
		f:Destroy()
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

local function moveModels(src, dst)
	local moved = 0
	local skippedDup = 0
	for _, ch in ipairs(src:GetChildren()) do
		if ch:IsA("Model") then
			if dst:FindFirstChild(ch.Name) then
				ch:Destroy()
				skippedDup = skippedDup + 1
			else
				ch.Parent = dst
				moved = moved + 1
			end
		end
	end
	return moved, skippedDup
end

local mapping = {
	{ "_DAC_EggExportGrid", ReplicatedStorage, "EggModels" },
	{ "_DAC_PetExportGrid", ReplicatedStorage, "PetModels" },
	{ "_DAC_VehicleGrid", ServerStorage, "CarModels" },
}

local parts = {}
local selected = {}

for _, row in ipairs(mapping) do
	local srcName = row[1]
	local parent = row[2]
	local destName = row[3]
	local src = Workspace:FindFirstChild(srcName)
	if not src or not src:IsA("Folder") then
		table.insert(parts, "SKIP " .. srcName .. " (not in Workspace)")
	else
		local dst = ensureFolder(parent, destName)
		local n, skipped = moveModels(src, dst)
		table.insert(
			parts,
			string.format(
				"%s -> %s.%s (%d moved, %d dup skipped)",
				srcName,
				parent.Name,
				destName,
				n,
				skipped
			)
		)
		table.insert(selected, dst)
		if #src:GetChildren() == 0 then
			src:Destroy()
		else
			table.insert(parts, "WARN: " .. srcName .. " still has non-Model children - not destroyed")
		end
	end
end

local ap = ensureFolder(Workspace, "ActivePets")
table.insert(selected, ap)
table.insert(parts, "Workspace.ActivePets ensured")

if #selected > 0 then
	Selection:Set(selected)
end

return "OK: " .. table.concat(parts, " | ")
