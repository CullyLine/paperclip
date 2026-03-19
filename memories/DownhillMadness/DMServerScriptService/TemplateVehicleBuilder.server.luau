--[[
	TemplateVehicleBuilder — Creates vehicle templates in ReplicatedStorage.

	Runs once at server start. Reads VehicleRegistry for all vehicle
	definitions, builds a template Model for each one:
	  VehicleTemplates (Folder)
	    Template_all_rounder (Model)
	    Template_speedster (Model)
	    Template_tank (Model)

	Each template follows the same hierarchy as the original TemplateVehicle
	but with dimensions, colors, and part counts driven by the VehicleDef.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMReplicatedStorage = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local VehicleRegistry = require(DMReplicatedStorage:WaitForChild("VehicleRegistry"))

local existing = ReplicatedStorage:FindFirstChild("VehicleTemplates")
if existing then existing:Destroy() end

-- Keep legacy TemplateVehicle removed to avoid confusion
local legacy = ReplicatedStorage:FindFirstChild("TemplateVehicle")
if legacy then legacy:Destroy() end

local templatesFolder = Instance.new("Folder")
templatesFolder.Name = "VehicleTemplates"
templatesFolder.Parent = ReplicatedStorage

for _, vehicleDef in VehicleRegistry.getAll() do
	local spec = vehicleDef.buildSpec

	local vehicle = Instance.new("Model")
	vehicle.Name = "Template_" .. vehicleDef.id
	vehicle:SetAttribute("VehicleId", vehicleDef.id)

	----------------------------------------------------------------
	-- Body model
	----------------------------------------------------------------
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = vehicle

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = spec.chassisSize
	chassis.Color = Color3.fromRGB(45, 45, 48)
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.Anchored = false
	chassis.CanCollide = false
	chassis.CanQuery = false
	chassis.CFrame = CFrame.new(0, 5, 0)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(
		spec.chassisDensity, 0.3, 0.1, 1, 1
	)
	chassis.Parent = body
	body.PrimaryPart = chassis

	local com = Instance.new("Part")
	com.Name = "CenterOfMass"
	com.Size = Vector3.new(0.1, 0.1, 0.1)
	com.Transparency = 1
	com.CanCollide = false
	com.CanQuery = false
	com.Massless = false
	com.Anchored = false
	com.CustomPhysicalProperties = PhysicalProperties.new(spec.comDensity, 0, 0, 0, 0)
	com.CFrame = chassis.CFrame * CFrame.new(spec.comOffset)
	com.Parent = body
	local comWeld = Instance.new("WeldConstraint")
	comWeld.Part0 = chassis
	comWeld.Part1 = com
	comWeld.Parent = com

	local shell = Instance.new("Part")
	shell.Name = "CollisionShell"
	shell.Size = spec.collisionShellSize
	shell.Transparency = 1
	shell.Anchored = false
	shell.CanCollide = true
	shell.CanQuery = false
	shell.Massless = true
	shell.CFrame = chassis.CFrame * CFrame.new(spec.collisionShellOffset)
	shell.Parent = body
	local shellWeld = Instance.new("WeldConstraint")
	shellWeld.Part0 = chassis
	shellWeld.Part1 = shell
	shellWeld.Parent = shell

	----------------------------------------------------------------
	-- BodyPanels
	----------------------------------------------------------------
	local panels = Instance.new("Model")
	panels.Name = "BodyPanels"
	panels.Parent = vehicle

	for _, panelDef in spec.panels do
		local panel = Instance.new("Part")
		panel.Name = panelDef.name
		panel.Size = panelDef.size
		panel.Color = spec.bodyColor
		panel.Material = Enum.Material.SmoothPlastic
		panel.Anchored = false
		panel.CanCollide = false
		panel.CanQuery = false
		panel.Massless = true
		panel.CFrame = chassis.CFrame * panelDef.offset
		panel.Parent = panels

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = panel
		weld.Parent = panel

		panel:SetAttribute("MaxHealth", panelDef.health)
		panel:SetAttribute("Health", panelDef.health)
	end

	-- Windshield
	local wsDef = spec.windshield
	local windshield = Instance.new("Part")
	windshield.Name = "Windshield"
	windshield.Size = wsDef.size
	windshield.Color = Color3.fromRGB(150, 200, 255)
	windshield.Material = Enum.Material.Glass
	windshield.Transparency = 0.5
	windshield.Anchored = false
	windshield.CanCollide = false
	windshield.CanQuery = false
	windshield.Massless = true
	windshield.CFrame = chassis.CFrame * wsDef.offset * CFrame.Angles(math.rad(wsDef.angle), 0, 0)
	windshield.Parent = panels
	local wsWeld = Instance.new("WeldConstraint")
	wsWeld.Part0 = chassis
	wsWeld.Part1 = windshield
	wsWeld.Parent = windshield
	windshield:SetAttribute("MaxHealth", wsDef.health)
	windshield:SetAttribute("Health", wsDef.health)

	-- Extra decorative parts (e.g. Tank light bar)
	if spec.extras then
		for _, extra in spec.extras do
			local part = Instance.new("Part")
			part.Name = extra.name
			part.Size = extra.size
			part.Color = extra.color
			part.Material = extra.material
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			part.CFrame = chassis.CFrame * extra.offset
			part.Parent = panels

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = part
		end
	end

	----------------------------------------------------------------
	-- DriverSeat
	----------------------------------------------------------------
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(3, 1, 3)
	seat.Color = Color3.fromRGB(30, 30, 32)
	seat.Material = Enum.Material.Fabric
	seat.Anchored = false
	seat.CanCollide = false
	seat.CanQuery = false
	seat.CFrame = chassis.CFrame * CFrame.new(spec.seatOffset)
	seat.Parent = vehicle
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	----------------------------------------------------------------
	-- Wheels
	----------------------------------------------------------------
	local wheelsModel = Instance.new("Model")
	wheelsModel.Name = "Wheels"
	wheelsModel.Parent = vehicle

	local wheelNames = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }
	for i, offset in spec.wheelOffsets do
		local wheel = Instance.new("Part")
		wheel.Name = wheelNames[i]
		wheel.Shape = Enum.PartType.Cylinder
		local d = spec.wheelRadius * 2
		wheel.Size = Vector3.new(d, d, d)
		wheel.Color = Color3.fromRGB(25, 25, 25)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.Transparency = 1
		wheel.Anchored = false
		wheel.CanCollide = false
		wheel.CanQuery = false
		wheel.Massless = true
		wheel.CFrame = chassis.CFrame * CFrame.new(offset)
		wheel.Parent = wheelsModel

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = wheel
		weld.Parent = wheel
	end

	vehicle.PrimaryPart = chassis
	vehicle.Parent = templatesFolder

	print("[TemplateVehicleBuilder] Built template: " .. vehicleDef.id
		.. " (" .. vehicleDef.displayName .. ")")
end

print("[TemplateVehicleBuilder] All " .. #VehicleRegistry.getAll() .. " vehicle templates built")
