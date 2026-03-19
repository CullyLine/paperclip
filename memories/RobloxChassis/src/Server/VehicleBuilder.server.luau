--[[
	VehicleBuilder — Generates a complete test vehicle model at runtime.
	
	Place this in ServerScriptService. On startup it creates:
	  TestVehicle (Model)
	    ├── Body (Model, PrimaryPart = CarBody)
	    │     ├── CarBody (MeshPart — low-poly textured mesh)
	    │     └── CenterOfMass (Part — invisible, physics anchor)
	    ├── Wheels (Model)
	    │     ├── WheelFL (MeshPart — low-poly textured mesh)
	    │     ├── WheelFR (MeshPart)
	    │     ├── WheelRL (MeshPart)
	    │     └── WheelRR (MeshPart)
	    ├── DriverSeat (VehicleSeat)
	    ├── LiveValues (Configuration — populated by LiveValuesSync)
	    ├── ChassisConfig (ModuleScript)
	    ├── LiveValuesSync (ModuleScript)
	    ├── Drivetrain (ModuleScript)
	    └── ChassisController (Script)

	This is a DEVELOPMENT tool. For production, build the model in
	Roblox Studio and insert the scripts manually.
	
	MESH SETUP: Upload car-body-final.glb and wheel-final.glb to Roblox
	(via Asset Manager or MeshPart import), then paste the asset IDs below.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════════════════════════════
-- MESH ASSET IDS — Replace these after uploading GLBs to Roblox
-- ═══════════════════════════════════════════════════════════════════
local CAR_BODY_MESH_ID = "rbxassetid://0" -- car-body-final.glb
local WHEEL_MESH_ID    = "rbxassetid://0" -- wheel-final.glb

-- Body dimensions (bounding box of the mesh, used for physics sizing)
local BODY_SIZE = Vector3.new(9, 3.5, 18)
local WHEEL_SIZE = Vector3.new(1.5, 4.0, 4.0)

local SPAWN_POS = Vector3.new(0, 15, 0)

local function createMeshPart(name, meshId, size, cframe, color, parent)
	local part = Instance.new("MeshPart")
	part.Name = name
	part.MeshId = meshId
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(40, 40, 45)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CollisionFidelity = Enum.CollisionFidelity.Box
	part.RenderFidelity = Enum.RenderFidelity.Automatic
	part.Parent = parent
	return part
end

local function createPart(name, size, cframe, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

local function buildVehicle()
	local vehicle = Instance.new("Model")
	vehicle.Name = "TestVehicle"

	-- Body
	local bodyModel = Instance.new("Model")
	bodyModel.Name = "Body"
	bodyModel.Parent = vehicle

	local carBody = createMeshPart("CarBody", CAR_BODY_MESH_ID, BODY_SIZE,
		CFrame.new(SPAWN_POS),
		Color3.fromRGB(30, 35, 45), bodyModel)
	carBody.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0, 1, 1)
	bodyModel.PrimaryPart = carBody

	local centerOfMass = createPart("CenterOfMass", Vector3.new(1, 1, 1),
		CFrame.new(SPAWN_POS + Vector3.new(0, -0.5, 0)), bodyModel)

	-- Wheels
	local wheelsModel = Instance.new("Model")
	wheelsModel.Name = "Wheels"
	wheelsModel.Parent = vehicle

	local wheelPositions = {
		{ name = "WheelFL", offset = Vector3.new(-4.5, -0.5, 6.75) },
		{ name = "WheelFR", offset = Vector3.new(4.5, -0.5, 6.75) },
		{ name = "WheelRL", offset = Vector3.new(-4.5, -0.5, -6.75) },
		{ name = "WheelRR", offset = Vector3.new(4.5, -0.5, -6.75) },
	}

	for _, wp in wheelPositions do
		local wheel = createMeshPart(wp.name, WHEEL_MESH_ID, WHEEL_SIZE,
			CFrame.new(SPAWN_POS + wp.offset),
			Color3.fromRGB(25, 25, 30), wheelsModel)
	end

	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.5, 0.5, 2.5)
	seat.CFrame = CFrame.new(SPAWN_POS + Vector3.new(-1.8, 0.7, 0))
	seat.Color = Color3.fromRGB(20, 20, 25)
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = true
	seat.CanCollide = false
	seat.Parent = vehicle

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Vehicle"
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = seat

	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = carBody
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	vehicle.PrimaryPart = carBody
	vehicle.Parent = workspace

	return vehicle
end

local vehicle = buildVehicle()
print("[VehicleBuilder] Test vehicle spawned at", SPAWN_POS)
