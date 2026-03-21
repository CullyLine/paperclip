--!nonstrict
--[[
  DAC — find pet Models across Workspace + ServerStorage + ReplicatedStorage, clone into one folder,
  tight grid, select folder for clipboard copy (use -SkipExplorerClick with MCP Selection).

  Set STEP below, then run via MCP execute_luau on OLD place, then verify-loop on NEW place.

  STEP: "SOURCE_PREP" | "TARGET_ORGANIZE"
]]

local STEP = "SOURCE_PREP"

-- Match egg grid density (studs between model pivots)
local GRID_SPACING = 8

-- Known pet ids from PetConfig (snake_case) — matches model names in many games
local KNOWN_PET_IDS = {
	tabby_cat = true,
	puppy = true,
	hamster = true,
	fox = true,
	owl = true,
	wolf = true,
	eagle = true,
	dragon_hatchling = true,
	phoenix_chick = true,
	golden_dragon = true,
	unicorn = true,
	void_serpent = true,
	cosmic_whale = true,
}

local function parentChainHasPetFolder(inst)
	local p = inst.Parent
	while p do
		local n = string.lower(p.Name)
		if string.find(n, "petmodels", 1, true) or string.find(n, "activepets", 1, true) then
			return true
		end
		p = p.Parent
	end
	return false
end

local function looksLikePetModel(m)
	local n = string.lower(m.Name)
	local slug = string.gsub(n, "%s+", "_")
	if KNOWN_PET_IDS[m.Name] or KNOWN_PET_IDS[n] or KNOWN_PET_IDS[slug] then
		return true
	end
	if string.find(n, "pet", 1, true) then
		return true
	end
	if parentChainHasPetFolder(m) then
		return true
	end
	return false
end

local function gatherPetModels()
	local found = {}
	local seen = {}

	local function consider(m)
		if not looksLikePetModel(m) then
			return
		end
		local key = m:GetFullName()
		if seen[key] then
			return
		end
		seen[key] = true
		table.insert(found, m)
	end

	-- Priority: explicit pet folders (clone children Models)
	local folderNames = { "PetModels", "ActivePets" }
	local services = {
		game:GetService("Workspace"),
		game:GetService("ServerStorage"),
		game:GetService("ReplicatedStorage"),
	}

	for _, svc in ipairs(services) do
		for _, fname in ipairs(folderNames) do
			local f = svc:FindFirstChild(fname, true)
			if f then
				for _, ch in ipairs(f:GetDescendants()) do
					if ch:IsA("Model") then
						consider(ch)
					end
				end
			end
		end
	end

	-- Broad scan: any Model under Workspace that looks like a pet
	for _, d in ipairs(game:GetService("Workspace"):GetDescendants()) do
		if d:IsA("Model") then
			consider(d)
		end
	end

	return found
end

local function ensurePrimaryPart(model)
	if model.PrimaryPart then
		return true
	end
	local p = model:FindFirstChildWhichIsA("BasePart", true)
	if p and p:IsA("BasePart") then
		model.PrimaryPart = p
		return true
	end
	return false
end

local function uniqueName(folder, base)
	if not folder:FindFirstChild(base) then
		return base
	end
	local i = 2
	while folder:FindFirstChild(base .. "_" .. tostring(i)) do
		i = i + 1
	end
	return base .. "_" .. tostring(i)
end

local function sourcePrep()
	local Selection = game:GetService("Selection")
	local Workspace = game:GetService("Workspace")

	local old = Workspace:FindFirstChild("_DAC_PetExportGrid")
	if old then
		old:Destroy()
	end

	local sources = gatherPetModels()
	if #sources == 0 then
		return "ERROR: No pet models found (check PetModels/ActivePets folders or model names)."
	end

	table.sort(sources, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	local root = Instance.new("Folder")
	root.Name = "_DAC_PetExportGrid"
	root.Parent = Workspace

	local spacing = GRID_SPACING
	local origin = Vector3.new(0, 50, 0)
	local cols = math.max(1, math.ceil(math.sqrt(#sources)))

	for i, src in ipairs(sources) do
		local clone = src:Clone()
		clone.Name = uniqueName(root, src.Name)
		clone.Parent = root
		if ensurePrimaryPart(clone) then
			local idx = i - 1
			local row = math.floor(idx / cols)
			local col = idx % cols
			local pos = origin + Vector3.new(col * spacing, 0, row * spacing)
			clone:PivotTo(CFrame.new(pos))
		end
	end

	Selection:Set({ root })
	return string.format(
		"OK: %d pet models -> Workspace._DAC_PetExportGrid (selected). MCP Selection:Set + copy-verify-loop -SkipExplorerClick.",
		#sources
	)
end

local function targetOrganize()
	local Workspace = game:GetService("Workspace")
	local Selection = game:GetService("Selection")
	local root = Workspace:FindFirstChild("_DAC_PetExportGrid")
	if not root then
		return "ERROR: Workspace._DAC_PetExportGrid not found (paste first)."
	end

	local models = {}
	for _, ch in ipairs(root:GetChildren()) do
		if ch:IsA("Model") then
			table.insert(models, ch)
		end
	end
	table.sort(models, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	local spacing = GRID_SPACING
	local origin = Vector3.new(0, 50, 0)
	local cols = math.max(1, math.ceil(math.sqrt(#models)))

	for i, model in ipairs(models) do
		local function ensurePrimaryPart(m)
			if m.PrimaryPart then
				return true
			end
			local p = m:FindFirstChildWhichIsA("BasePart", true)
			if p and p:IsA("BasePart") then
				m.PrimaryPart = p
				return true
			end
			return false
		end
		if ensurePrimaryPart(model) then
			local idx = i - 1
			local row = math.floor(idx / cols)
			local col = idx % cols
			model:PivotTo(CFrame.new(origin + Vector3.new(col * spacing, 0, row * spacing)))
		end
	end

	Selection:Set({ root })
	return string.format("OK: Re-laid out %d pets in _DAC_PetExportGrid (spacing=%d).", #models, spacing)
end

if STEP == "SOURCE_PREP" then
	return sourcePrep()
elseif STEP == "TARGET_ORGANIZE" then
	return targetOrganize()
else
	return "ERROR: Set STEP to SOURCE_PREP or TARGET_ORGANIZE."
end
