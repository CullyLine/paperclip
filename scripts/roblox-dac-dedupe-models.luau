--!nonstrict
--[[
  DAC — remove duplicate template models left after a merge (e.g. promote ran when
  ReplicatedStorage.PetModels already had copies, so exports became name_2, name_3).

  Rule: if a Model is named "<base>_<n>" where <n> is a positive integer, and a sibling
  Model named "<base>" exists, destroy "<base>_<n>" (keep the unsuffixed one).

  Targets (edit FOLDERS below if needed):
  - ReplicatedStorage.PetModels
  - ReplicatedStorage.EggModels
  - ServerStorage.CarModels (optional)

  Run in Studio MCP execute_luau or Command Bar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")

-- Folders to clean: { parent, folderName }
local FOLDER_SPECS = {
	{ ReplicatedStorage, "PetModels" },
	{ ReplicatedStorage, "EggModels" },
	{ ServerStorage, "CarModels" },
}

local function dedupeFolder(folder)
	if not folder or not folder:IsA("Folder") then
		return 0, "missing"
	end
	local destroyed = 0
	local toDestroy = {}
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			local base = ch.Name:match("^(.+)_(%d+)$")
			if base then
				if folder:FindFirstChild(base) then
					table.insert(toDestroy, ch)
				end
			end
		end
	end
	for _, ch in ipairs(toDestroy) do
		ch:Destroy()
		destroyed = destroyed + 1
	end
	return destroyed, folder:GetFullName()
end

local parts = {}
local selected = {}
for _, spec in ipairs(FOLDER_SPECS) do
	local parent, fname = spec[1], spec[2]
	local f = parent:FindFirstChild(fname)
	local n, info = dedupeFolder(f)
	if info == "missing" then
		table.insert(parts, string.format("SKIP %s.%s (not found)", parent.Name, fname))
	else
		table.insert(parts, string.format("%s: removed %d dup(s)", info, n))
		table.insert(selected, f)
	end
end

if #selected > 0 then
	Selection:Set(selected)
end

return "OK: " .. table.concat(parts, " | ")
