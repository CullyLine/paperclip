--!strict
--[[
	Run in Roblox Studio (Command Bar or MCP execute_luau), Edit mode.

	Clones every Model under ReplicatedStorage.CarModels into Workspace.CarModelsGrid
	in a sorted name grid with a floor + billboard labels. Safe for viewing only —
	delete Workspace.CarModelsGrid when done; originals are unchanged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local srcFolder = ReplicatedStorage:FindFirstChild("CarModels")
if not srcFolder then
	warn("[CarGrid] ReplicatedStorage.CarModels missing")
	return
end

local old = Workspace:FindFirstChild("CarModelsGrid")
if old then
	old:Destroy()
end

local grid = Instance.new("Folder")
grid.Name = "CarModelsGrid"
grid.Parent = Workspace

local models: { Model } = {}
for _, ch in srcFolder:GetChildren() do
	if ch:IsA("Model") and ch.Name ~= "New cars" then
		table.insert(models, ch)
	end
end
table.sort(models, function(a, b)
	return a.Name:lower() < b.Name:lower()
end)

local n = #models
if n == 0 then
	warn("[CarGrid] No car models found")
	return
end

local cols = math.ceil(math.sqrt(n))
local spacing = 48
local pad = 8

local floor = Instance.new("Part")
floor.Name = "CarGridFloor"
floor.Anchored = true
floor.CanCollide = true
floor.Material = Enum.Material.SmoothPlastic
floor.Color = Color3.fromRGB(52, 58, 72)
floor.Size = Vector3.new(cols * spacing + pad * 2, 1, math.ceil(n / cols) * spacing + pad * 2)
floor.CFrame = CFrame.new(0, -0.5, 0)
floor.Parent = grid

for i, src in ipairs(models) do
	local idx = i - 1
	local row = math.floor(idx / cols)
	local col = idx % cols
	local x = (col - (cols - 1) * 0.5) * spacing
	local z = row * spacing

	local clone = src:Clone()
	clone.Name = src.Name
	clone.Parent = grid

	if not clone.PrimaryPart then
		local p = clone:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			clone.PrimaryPart = p
		end
	end

	if clone.PrimaryPart then
		clone:PivotTo(CFrame.new(x, 8, z))
		local _, size = clone:GetBoundingBox()
		local lift = size.Y * 0.5 + 0.6
		clone:PivotTo(CFrame.new(x, lift, z))

		local bb = Instance.new("BillboardGui")
		bb.Name = "NameTag"
		bb.Size = UDim2.new(0, 160, 0, 36)
		bb.StudsOffset = Vector3.new(0, size.Y * 0.5 + 2, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0

		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		tl.BackgroundTransparency = 0.15
		tl.TextColor3 = Color3.fromRGB(255, 255, 255)
		tl.Font = Enum.Font.GothamBold
		tl.TextScaled = true
		tl.Text = src.Name
		tl.Parent = bb

		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0, 6)
		cr.Parent = tl

		bb.Parent = clone.PrimaryPart
	end
end

print("[CarGrid] Placed", n, "cars under Workspace.CarModelsGrid")
