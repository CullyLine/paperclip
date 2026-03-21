--!nonstrict
--[[
  Drive A Car Simulator — vehicle grid helpers for Roblox Studio (MCP execute_luau / Command Bar).

  LIMITS:
  - Cannot clone instances across two open places with Luau alone; use clipboard between places.
  - Recommended: run SOURCE prep, select Workspace._DAC_VehicleGrid, then one roblox-studio-copy-paste.ps1 to the new place.

  Sections (paste ONE block at a time into execute_luau):
  1) SOURCE_PREP  — old place: clone CarModels → Workspace._DAC_VehicleGrid + grid layout + select folder
  2) TARGET_ORGANIZE — new place: re-layout pasted folder (if positions broke)
  3) FOCUS_CAMERA — new place: tween viewport camera toward grid (if CurrentCamera exists)

  GRID_SPACING: studs between vehicle pivots (default 16 — much tighter than old 70; increase if cars overlap).
]]

local GRID_SPACING = 16

-- ---------------------------------------------------------------------------
-- 1) SOURCE_PREP — run on OLD place (where ServerStorage.CarModels or Workspace.CarModels lives)
-- ---------------------------------------------------------------------------
local function sourcePrep()
	local Selection = game:GetService("Selection")
	local Workspace = game:GetService("Workspace")
	local ServerStorage = game:GetService("ServerStorage")

	local src = ServerStorage:FindFirstChild("CarModels") or Workspace:FindFirstChild("CarModels")
	if not src then
		return "ERROR: No CarModels in ServerStorage or Workspace."
	end

	local old = Workspace:FindFirstChild("_DAC_VehicleGrid")
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "_DAC_VehicleGrid"
	root.Parent = Workspace

	local models = {}
	for _, ch in ipairs(src:GetChildren()) do
		if ch:IsA("Model") then
			local m = ch:Clone()
			m.Name = ch.Name
			m.Parent = root
			table.insert(models, m)
		end
	end

	table.sort(models, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

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

	local spacing = GRID_SPACING
	local origin = Vector3.new(0, 120, 0)
	local cols = math.max(1, math.ceil(math.sqrt(#models)))

	for i, model in ipairs(models) do
		if ensurePrimaryPart(model) then
			local idx = i - 1
			local row = math.floor(idx / cols)
			local col = idx % cols
			local pos = origin + Vector3.new(col * spacing, 0, row * spacing)
			model:PivotTo(CFrame.new(pos))
		end
	end

	Selection:Set({ root })
	return string.format(
		"OK: %d vehicle models cloned to Workspace._DAC_VehicleGrid spacing=%d (selected). Next: Ctrl+C in source Studio, Ctrl+V in target, then TARGET_ORGANIZE + FOCUS_CAMERA.",
		#models,
		spacing
	)
end

-- ---------------------------------------------------------------------------
-- 2) TARGET_ORGANIZE — run on NEW place after paste (folder should be Workspace._DAC_VehicleGrid)
-- ---------------------------------------------------------------------------
local function targetOrganize()
	local Workspace = game:GetService("Workspace")
	local root = Workspace:FindFirstChild("_DAC_VehicleGrid")
	if not root then
		return "ERROR: Workspace._DAC_VehicleGrid not found (paste may have renamed it — rename folder to _DAC_VehicleGrid)."
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

	local spacing = GRID_SPACING
	local origin = Vector3.new(0, 120, 0)
	local cols = math.max(1, math.ceil(math.sqrt(#models)))

	for i, model in ipairs(models) do
		if ensurePrimaryPart(model) then
			local idx = i - 1
			local row = math.floor(idx / cols)
			local col = idx % cols
			local pos = origin + Vector3.new(col * spacing, 0, row * spacing)
			model:PivotTo(CFrame.new(pos))
		end
	end

	local Selection = game:GetService("Selection")
	Selection:Set({ root })

	return string.format("OK: Re-laid out %d models in _DAC_VehicleGrid spacing=%d (folder selected).", #models, spacing)
end

-- ---------------------------------------------------------------------------
-- 3) FOCUS_CAMERA — optional smooth move (edit-mode viewport when CurrentCamera is available)
-- ---------------------------------------------------------------------------
local function focusCamera()
	local Workspace = game:GetService("Workspace")
	local root = Workspace:FindFirstChild("_DAC_VehicleGrid")
	if not root then
		return "ERROR: Workspace._DAC_VehicleGrid missing."
	end

	local cam = Workspace.CurrentCamera
	if not cam then
		return "NO_CAMERA: workspace.CurrentCamera is nil in this context. Use scripts/roblox-studio-frame-selection.ps1 (sends F to frame selection) after selecting _DAC_VehicleGrid."
	end

	local models = {}
	for _, ch in ipairs(root:GetChildren()) do
		if ch:IsA("Model") then
			table.insert(models, ch)
		end
	end
	if #models == 0 then
		return "ERROR: No models under _DAC_VehicleGrid."
	end

	local minP = Vector3.new(math.huge, math.huge, math.huge)
	local maxP = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, model in ipairs(models) do
		local cf, sz = model:GetBoundingBox()
		local c = cf.Position
		local h = sz * 0.5
		local mn = c - h
		local mx = c + h
		minP = Vector3.new(math.min(minP.X, mn.X), math.min(minP.Y, mn.Y), math.min(minP.Z, mn.Z))
		maxP = Vector3.new(math.max(maxP.X, mx.X), math.max(maxP.Y, mx.Y), math.max(maxP.Z, mx.Z))
	end

	local center = (minP + maxP) * 0.5
	local size = maxP - minP

	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local dist = math.clamp(radius * 2.8, 80, 500)
	local targetPos = center + Vector3.new(dist * 0.85, dist * 0.45, dist * 0.85)
	local goal = CFrame.lookAt(targetPos, center)

	local start = cam.CFrame
	for t = 0, 1, 0.08 do
		cam.CFrame = start:Lerp(goal, t)
		task.wait(0.02)
	end
	cam.CFrame = goal

	local Selection = game:GetService("Selection")
	Selection:Set({ root })

	return "OK: Camera moved to focus _DAC_VehicleGrid (folder selected). If viewport did not move, use roblox-studio-frame-selection.ps1."
end

-- Which step to run when pasted into execute_luau (change this string):
local STEP = "SOURCE_PREP" -- "SOURCE_PREP" | "TARGET_ORGANIZE" | "FOCUS_CAMERA"

if STEP == "SOURCE_PREP" then
	return sourcePrep()
elseif STEP == "TARGET_ORGANIZE" then
	return targetOrganize()
elseif STEP == "FOCUS_CAMERA" then
	return focusCamera()
else
	return "ERROR: Unknown STEP."
end
