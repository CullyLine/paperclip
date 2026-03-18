--[[
	TemplateVehicleBuilder — Creates a placeholder TemplateVehicle in ReplicatedStorage.
	
	Runs once at server start. Builds a simple box-car with 4 wheels and a VehicleSeat.
	In production, this would be replaced by actual vehicle meshes imported from FBX/GLB.
	
	Vehicle model structure (Polaris-compatible):
	  TemplateVehicle (Model)
	    Body (Model, PrimaryPart = Chassis)
	      Chassis (Part) — main body
	      CenterOfMass (Part) — invisible dense anchor, offsets mass upward
	      Windshield (Part) — glass visual
	    Wheels (Model)
	      WheelFL (Part)
	      WheelFR (Part)
	      WheelRL (Part)
	      WheelRR (Part)
	    DriverSeat (Seat)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

if ReplicatedStorage:FindFirstChild("TemplateVehicle") then
	return
end

local vehicle = Instance.new("Model")
vehicle.Name = "TemplateVehicle"

-- Body
local bodyModel = Instance.new("Model")
bodyModel.Name = "Body"
bodyModel.Parent = vehicle

local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Size = Vector3.new(10, 3, 18)
chassis.Color = Color3.fromRGB(45, 45, 48)
chassis.Material = Enum.Material.SmoothPlastic
chassis.Anchored = false
chassis.CanCollide = false
chassis.CanQuery = false
chassis.CFrame = CFrame.new(0, 5, 0)
chassis.Parent = bodyModel
-- Mass distribution: CustomPhysicalProperties to raise center of mass feel
chassis.CustomPhysicalProperties = PhysicalProperties.new(
	3,    -- density (heavier = more momentum)
	0.3,  -- friction
	0.1,  -- elasticity
	1,    -- frictionWeight
	1     -- elasticityWeight
)
bodyModel.PrimaryPart = chassis

-- Windshield visual
local windshield = Instance.new("Part")
windshield.Name = "Windshield"
windshield.Size = Vector3.new(8, 2.5, 0.3)
windshield.Color = Color3.fromRGB(150, 200, 255)
windshield.Material = Enum.Material.Glass
windshield.Transparency = 0.5
windshield.Anchored = false
windshield.CanCollide = false
windshield.CanQuery = false
windshield.Parent = bodyModel
local windshieldWeld = Instance.new("WeldConstraint")
windshieldWeld.Part0 = chassis
windshieldWeld.Part1 = windshield
windshieldWeld.Parent = windshield
windshield.CFrame = chassis.CFrame * CFrame.new(0, 1.5, -5) * CFrame.Angles(math.rad(25), 0, 0)

-- CenterOfMass — dense invisible part that shifts the effective center of mass
-- Offset matches ChassisConfig.centerOfMassOffset (0, 1.5, 0)
local centerOfMass = Instance.new("Part")
centerOfMass.Name = "CenterOfMass"
centerOfMass.Size = Vector3.new(0.1, 0.1, 0.1)
centerOfMass.Transparency = 1
centerOfMass.CanCollide = false
centerOfMass.CanQuery = false
centerOfMass.Massless = false
centerOfMass.Anchored = false
centerOfMass.CustomPhysicalProperties = PhysicalProperties.new(50, 0, 0, 0, 0)
centerOfMass.CFrame = chassis.CFrame * CFrame.new(0, 1.5, 0)
centerOfMass.Parent = bodyModel
local comWeld = Instance.new("WeldConstraint")
comWeld.Part0 = chassis
comWeld.Part1 = centerOfMass
comWeld.Parent = centerOfMass

-- Bumper — thin collision shell for obstacle/vehicle impacts
-- Shorter than chassis so it doesn't scrape the road on slopes
local bumper = Instance.new("Part")
bumper.Name = "Bumper"
bumper.Size = Vector3.new(10, 2, 10)
bumper.Transparency = 1
bumper.Anchored = false
bumper.CanCollide = true
bumper.CanQuery = false
bumper.Massless = true
bumper.CFrame = chassis.CFrame * CFrame.new(0, 0.5, 0)
bumper.Parent = bodyModel
local bumperWeld = Instance.new("WeldConstraint")
bumperWeld.Part0 = chassis
bumperWeld.Part1 = bumper
bumperWeld.Parent = bumper

-- DriverSeat — plain Seat avoids VehicleSeat's built-in driving forces
-- that conflict with the custom raycast suspension
local seat = Instance.new("Seat")
seat.Name = "DriverSeat"
seat.Size = Vector3.new(3, 1, 3)
seat.Color = Color3.fromRGB(30, 30, 32)
seat.Material = Enum.Material.Fabric
seat.Anchored = false
seat.CanCollide = false
seat.CanQuery = false
seat.CFrame = chassis.CFrame * CFrame.new(0, 2, -1)
seat.Parent = vehicle
local seatWeld = Instance.new("WeldConstraint")
seatWeld.Part0 = chassis
seatWeld.Part1 = seat
seatWeld.Parent = seat

-- Wheels
local wheelsModel = Instance.new("Model")
wheelsModel.Name = "Wheels"
wheelsModel.Parent = vehicle

local WHEEL_DEFS = {
	{ name = "WheelFL", offset = Vector3.new(-4.5, -1, -6.75) },
	{ name = "WheelFR", offset = Vector3.new(4.5, -1, -6.75) },
	{ name = "WheelRL", offset = Vector3.new(-4.5, -1, 6.75) },
	{ name = "WheelRR", offset = Vector3.new(4.5, -1, 6.75) },
}

-- Wheels: physical part (welded, hidden) keeps assembly stable; visual proxy
-- (anchored) is positioned each frame by ChassisClient — avoids constraint
-- violations that cause nose-dive when setting CFrame on welded parts.
for _, def in WHEEL_DEFS do
	-- Physical: welded to chassis, never touched by client — stable assembly
	local wheel = Instance.new("Part")
	wheel.Name = def.name
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(2, 4, 4) -- cylinder: height is X, diameter is Y/Z
	wheel.Color = Color3.fromRGB(25, 25, 25)
	wheel.Material = Enum.Material.SmoothPlastic
	wheel.Transparency = 1
	wheel.Anchored = false
	wheel.CanCollide = false
	wheel.CanQuery = false
	wheel.Massless = true
	wheel.CFrame = chassis.CFrame * CFrame.new(def.offset)
	wheel.Parent = wheelsModel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = wheel
	weld.Parent = wheel

	-- Visual: anchored proxy, client positions via CFrame each frame
	local visual = Instance.new("Part")
	visual.Name = "Visual"
	visual.Shape = Enum.PartType.Cylinder
	visual.Size = wheel.Size
	visual.Color = wheel.Color
	visual.Material = wheel.Material
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CFrame = wheel.CFrame
	visual.Parent = wheel
end

vehicle.PrimaryPart = chassis
vehicle.Parent = ReplicatedStorage
