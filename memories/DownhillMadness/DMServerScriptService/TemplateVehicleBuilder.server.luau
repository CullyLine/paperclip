--[[
	TemplateVehicleBuilder — Creates the TemplateVehicle in ReplicatedStorage.

	Runs once at server start. Builds a downhill-optimised vehicle with:
	  - Lightweight chassis (low density, no CanCollide on physics root)
	  - Separate CollisionShell for impacts (massless, CanCollide)
	  - CenterOfMass part for mass distribution
	  - BodyPanels model with individual parts for future damage system
	  - 4 wheel parts (invisible, welded — visuals driven by client)
	  - Plain Seat (avoids VehicleSeat built-in forces)

	Vehicle hierarchy:
	  TemplateVehicle (Model, PrimaryPart = Chassis)
	    Body (Model, PrimaryPart = Chassis)
	      Chassis (Part) — physics root
	      CenterOfMass (Part) — dense invisible mass anchor
	      CollisionShell (Part) — invisible collision box
	    BodyPanels (Model) — modular damage-ready panels
	      Hood (Part)
	      TrunkLid (Part)
	      LeftDoor (Part)
	      RightDoor (Part)
	      Roof (Part)
	    Wheels (Model)
	      WheelFL / WheelFR / WheelRL / WheelRR (Part)
	    DriverSeat (Seat)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local existing = ReplicatedStorage:FindFirstChild("TemplateVehicle")
if existing then existing:Destroy() end

local vehicle = Instance.new("Model")
vehicle.Name = "TemplateVehicle"

----------------------------------------------------------------
-- Body model
----------------------------------------------------------------
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = vehicle

-- Chassis — physics root, invisible to collisions (shell handles that)
local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Size = Vector3.new(10, 3, 18)
chassis.Color = Color3.fromRGB(45, 45, 48)
chassis.Material = Enum.Material.SmoothPlastic
chassis.Anchored = false
chassis.CanCollide = false
chassis.CanQuery = false
chassis.CFrame = CFrame.new(0, 5, 0)
chassis.CustomPhysicalProperties = PhysicalProperties.new(
	1.5,  -- low density for light responsive feel
	0.3,
	0.1,
	1, 1
)
chassis.Parent = body
body.PrimaryPart = chassis

-- CenterOfMass — dense invisible nugget that lowers effective center of mass
local com = Instance.new("Part")
com.Name = "CenterOfMass"
com.Size = Vector3.new(0.1, 0.1, 0.1)
com.Transparency = 1
com.CanCollide = false
com.CanQuery = false
com.Massless = false
com.Anchored = false
com.CustomPhysicalProperties = PhysicalProperties.new(40, 0, 0, 0, 0)
com.CFrame = chassis.CFrame * CFrame.new(0, 1.5, 0)
com.Parent = body
local comWeld = Instance.new("WeldConstraint")
comWeld.Part0 = chassis
comWeld.Part1 = com
comWeld.Parent = com

-- CollisionShell — thin invisible box for collisions, shorter than chassis
-- so it doesn't scrape on steep slopes
local shell = Instance.new("Part")
shell.Name = "CollisionShell"
shell.Size = Vector3.new(10, 2, 14)
shell.Transparency = 1
shell.Anchored = false
shell.CanCollide = true
shell.CanQuery = false
shell.Massless = true
shell.CFrame = chassis.CFrame * CFrame.new(0, 0.5, 0)
shell.Parent = body
local shellWeld = Instance.new("WeldConstraint")
shellWeld.Part0 = chassis
shellWeld.Part1 = shell
shellWeld.Parent = shell

----------------------------------------------------------------
-- BodyPanels — modular parts for future damage / destruction
----------------------------------------------------------------
local panels = Instance.new("Model")
panels.Name = "BodyPanels"
panels.Parent = vehicle

local PANEL_DEFS = {
	{ name = "Hood",      size = Vector3.new(8, 0.4, 5),   offset = CFrame.new(0, 1.7, -5.5) },
	{ name = "TrunkLid",  size = Vector3.new(8, 0.4, 4),   offset = CFrame.new(0, 1.7, 5) },
	{ name = "LeftDoor",  size = Vector3.new(0.4, 2, 8),   offset = CFrame.new(-5, 0.5, -1) },
	{ name = "RightDoor", size = Vector3.new(0.4, 2, 8),   offset = CFrame.new(5, 0.5, -1) },
	{ name = "Roof",      size = Vector3.new(8, 0.4, 6),   offset = CFrame.new(0, 2.8, -1) },
}

for _, def in PANEL_DEFS do
	local panel = Instance.new("Part")
	panel.Name = def.name
	panel.Size = def.size
	panel.Color = Color3.fromRGB(200, 60, 60)
	panel.Material = Enum.Material.SmoothPlastic
	panel.Anchored = false
	panel.CanCollide = false
	panel.CanQuery = false
	panel.Massless = true
	panel.CFrame = chassis.CFrame * def.offset
	panel.Parent = panels

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = panel
	weld.Parent = panel

	panel:SetAttribute("MaxHealth", 100)
	panel:SetAttribute("Health", 100)
end

-- Windshield (glass visual, part of panels for damage)
local windshield = Instance.new("Part")
windshield.Name = "Windshield"
windshield.Size = Vector3.new(8, 2.5, 0.3)
windshield.Color = Color3.fromRGB(150, 200, 255)
windshield.Material = Enum.Material.Glass
windshield.Transparency = 0.5
windshield.Anchored = false
windshield.CanCollide = false
windshield.CanQuery = false
windshield.Massless = true
windshield.CFrame = chassis.CFrame * CFrame.new(0, 1.5, -5) * CFrame.Angles(math.rad(25), 0, 0)
windshield.Parent = panels
local wsWeld = Instance.new("WeldConstraint")
wsWeld.Part0 = chassis
wsWeld.Part1 = windshield
wsWeld.Parent = windshield
windshield:SetAttribute("MaxHealth", 50)
windshield:SetAttribute("Health", 50)

----------------------------------------------------------------
-- DriverSeat — plain Seat avoids VehicleSeat built-in driving forces
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Wheels — invisible physics markers welded to chassis.
-- The client creates separate anchored visual wheels each frame
-- so there is zero jitter (visual parts are outside the assembly).
----------------------------------------------------------------
local wheelsModel = Instance.new("Model")
wheelsModel.Name = "Wheels"
wheelsModel.Parent = vehicle

local WHEEL_DEFS = {
	{ name = "WheelFL", offset = Vector3.new(-4.5, -1, -6.75) },
	{ name = "WheelFR", offset = Vector3.new(4.5, -1, -6.75) },
	{ name = "WheelRL", offset = Vector3.new(-4.5, -1, 6.75) },
	{ name = "WheelRR", offset = Vector3.new(4.5, -1, 6.75) },
}

for _, def in WHEEL_DEFS do
	local wheel = Instance.new("Part")
	wheel.Name = def.name
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(2, 4, 4)
	wheel.Color = Color3.fromRGB(25, 25, 25)
	wheel.Material = Enum.Material.SmoothPlastic
	wheel.Transparency = 1  -- invisible: visual wheels live on the client
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
end

vehicle.PrimaryPart = chassis
vehicle.Parent = ReplicatedStorage
