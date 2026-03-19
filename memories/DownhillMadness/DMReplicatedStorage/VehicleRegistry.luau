--[[
	VehicleRegistry — Defines all vehicle types, their build specs, physics
	overrides, unlock requirements, and display metadata.

	Shared between server (building templates, spawning) and client (UI, physics).
]]

local VehicleRegistry = {}

export type VehicleStats = {
	speed: number,
	handling: number,
	weight: number,
	durability: number,
}

export type VehicleBuildSpec = {
	chassisSize: Vector3,
	chassisDensity: number,
	comDensity: number,
	comOffset: Vector3,
	collisionShellSize: Vector3,
	collisionShellOffset: Vector3,
	bodyColor: Color3,
	wheelRadius: number,
	wheelOffsets: { Vector3 },
	seatOffset: Vector3,
	panels: {
		{ name: string, size: Vector3, offset: CFrame, health: number }
	},
	windshield: {
		size: Vector3, offset: CFrame, angle: number, health: number,
	},
	extras: { { name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material } }?,
}

export type PhysicsOverrides = { [string]: any }

export type VehicleDef = {
	id: string,
	displayName: string,
	tagline: string,
	description: string,
	flavorText: string,
	stats: VehicleStats,
	unlockLevel: number,
	buildSpec: VehicleBuildSpec,
	physicsOverrides: PhysicsOverrides,
}

local VEHICLES: { VehicleDef } = {
	{
		id = "all_rounder",
		displayName = "Nomad",
		tagline = "Ready for anything.",
		description = "No glaring weaknesses, no flashy tricks. The Nomad handles every surface, every obstacle, every situation with quiet confidence. Your first car. Maybe your last.",
		flavorText = "It's not boring. It's reliable. There's a difference.",
		stats = { speed = 6, handling = 6, weight = 6, durability = 6 },
		unlockLevel = 0,
		buildSpec = {
			chassisSize = Vector3.new(10, 3, 18),
			chassisDensity = 1.5,
			comDensity = 40,
			comOffset = Vector3.new(0, 1.5, 0),
			collisionShellSize = Vector3.new(10, 2, 14),
			collisionShellOffset = Vector3.new(0, 0.5, 0),
			bodyColor = Color3.fromRGB(220, 60, 40),
			wheelRadius = 2.0,
			wheelOffsets = {
				Vector3.new(-4.5, -1, -6.75),
				Vector3.new(4.5, -1, -6.75),
				Vector3.new(-4.5, -1, 6.75),
				Vector3.new(4.5, -1, 6.75),
			},
			seatOffset = Vector3.new(0, 2, -1),
			panels = {
				{ name = "Hood",      size = Vector3.new(8, 0.4, 5),  offset = CFrame.new(0, 1.7, -5.5), health = 100 },
				{ name = "TrunkLid",  size = Vector3.new(8, 0.4, 4),  offset = CFrame.new(0, 1.7, 5),    health = 100 },
				{ name = "LeftDoor",  size = Vector3.new(0.4, 2, 8),  offset = CFrame.new(-5, 0.5, -1),  health = 100 },
				{ name = "RightDoor", size = Vector3.new(0.4, 2, 8),  offset = CFrame.new(5, 0.5, -1),   health = 100 },
				{ name = "Roof",      size = Vector3.new(8, 0.4, 6),  offset = CFrame.new(0, 2.8, -1),   health = 100 },
			},
			windshield = {
				size = Vector3.new(8, 2.5, 0.3),
				offset = CFrame.new(0, 1.5, -5),
				angle = 25,
				health = 50,
			},
		},
		physicsOverrides = {
			driveForce = 28000,
			maxSpeed = 400,
			downforceCoeff = 0.15,
			dragCoeff = 0.02,
			lateralGrip = 2.5,
			lateralGripFront = 3.0,
			suspStiffness = 4500,
			suspDampCompress = 3000,
			suspDampRebound = 3500,
		},
	},
	{
		id = "speedster",
		displayName = "Viper",
		tagline = "Built for one thing: speed.",
		description = "Paper-thin armor over a screaming engine. The Viper eats straights for breakfast but shatters on contact. One clean run and you're untouchable. One bad bump and you're done.",
		flavorText = "Speed has never killed anyone. Suddenly stopping, that's what gets you.",
		stats = { speed = 9, handling = 7, weight = 3, durability = 3 },
		unlockLevel = 5,
		buildSpec = {
			chassisSize = Vector3.new(10.5, 2.5, 20),
			chassisDensity = 1.0,
			comDensity = 28,
			comOffset = Vector3.new(0, 1.2, 0),
			collisionShellSize = Vector3.new(10.5, 1.8, 16),
			collisionShellOffset = Vector3.new(0, 0.3, 0),
			bodyColor = Color3.fromRGB(0, 119, 255),
			wheelRadius = 1.6,
			wheelOffsets = {
				Vector3.new(-4.5, -0.5, -7.5),
				Vector3.new(4.5, -0.5, -7.5),
				Vector3.new(-4.5, -0.5, 7.5),
				Vector3.new(4.5, -0.5, 7.5),
			},
			seatOffset = Vector3.new(0, 1.5, -1),
			panels = {
				{ name = "Hood",      size = Vector3.new(8.5, 0.3, 6.5), offset = CFrame.new(0, 1.3, -5.5), health = 60 },
				{ name = "TrunkLid",  size = Vector3.new(8.5, 0.3, 3),   offset = CFrame.new(0, 1.3, 6),    health = 60 },
				{ name = "LeftDoor",  size = Vector3.new(0.3, 1.5, 7),   offset = CFrame.new(-5.2, 0.3, -1), health = 60 },
				{ name = "RightDoor", size = Vector3.new(0.3, 1.5, 7),   offset = CFrame.new(5.2, 0.3, -1),  health = 60 },
				{ name = "Roof",      size = Vector3.new(8.5, 0.3, 5),   offset = CFrame.new(0, 2.2, -1),   health = 60 },
				{ name = "Spoiler",   size = Vector3.new(8, 0.5, 1),     offset = CFrame.new(0, 2.0, 8),    health = 40 },
			},
			windshield = {
				size = Vector3.new(8.5, 2.0, 0.3),
				offset = CFrame.new(0, 1.2, -5.5),
				angle = 35,
				health = 30,
			},
		},
		physicsOverrides = {
			driveForce = 34000,
			maxSpeed = 500,
			downforceCoeff = 0.22,
			dragCoeff = 0.015,
			lateralGrip = 2.8,
			lateralGripFront = 3.4,
			suspStiffness = 5200,
			suspDampCompress = 3200,
			suspDampRebound = 3800,
			maxSteerAngle = 38,
			steerSpeed = 7,
			counterSteerFactor = 0.3,
		},
	},
	{
		id = "tank",
		displayName = "Rhino",
		tagline = "Unstoppable force.",
		description = "Reinforced armor, massive wheels, and enough weight to shove anything out of the way. The Rhino doesn't dodge obstacles. It IS the obstacle. Slow to start, impossible to stop.",
		flavorText = "Other cars have crumple zones. This one has a bull bar.",
		stats = { speed = 4, handling = 4, weight = 9, durability = 9 },
		unlockLevel = 10,
		buildSpec = {
			chassisSize = Vector3.new(12, 4, 19),
			chassisDensity = 2.0,
			comDensity = 55,
			comOffset = Vector3.new(0, 2.0, 0),
			collisionShellSize = Vector3.new(12, 3, 15),
			collisionShellOffset = Vector3.new(0, 0.8, 0),
			bodyColor = Color3.fromRGB(85, 107, 47),
			wheelRadius = 2.8,
			wheelOffsets = {
				Vector3.new(-5.5, -1, -7),
				Vector3.new(5.5, -1, -7),
				Vector3.new(-5.5, -1, 7),
				Vector3.new(5.5, -1, 7),
			},
			seatOffset = Vector3.new(0, 3, -1),
			panels = {
				{ name = "Hood",      size = Vector3.new(10, 0.5, 5),  offset = CFrame.new(0, 2.2, -6),   health = 200 },
				{ name = "TrunkLid",  size = Vector3.new(10, 0.5, 5),  offset = CFrame.new(0, 2.2, 6),    health = 200 },
				{ name = "LeftDoor",  size = Vector3.new(0.5, 2.8, 9), offset = CFrame.new(-6, 0.8, -1),  health = 200 },
				{ name = "RightDoor", size = Vector3.new(0.5, 2.8, 9), offset = CFrame.new(6, 0.8, -1),   health = 200 },
				{ name = "Roof",      size = Vector3.new(10, 0.5, 7),  offset = CFrame.new(0, 3.8, -1),   health = 200 },
				{ name = "BullBar",   size = Vector3.new(10, 2.5, 1),  offset = CFrame.new(0, 1.5, -9.5), health = 300 },
			},
			windshield = {
				size = Vector3.new(10, 3.0, 0.4),
				offset = CFrame.new(0, 2.0, -5.5),
				angle = 20,
				health = 80,
			},
			extras = {
				{
					name = "LightBar",
					size = Vector3.new(8, 0.5, 0.8),
					offset = CFrame.new(0, 4.3, -1),
					color = Color3.fromRGB(255, 215, 0),
					material = Enum.Material.Neon,
				},
			},
		},
		physicsOverrides = {
			driveForce = 32000,
			maxSpeed = 300,
			downforceCoeff = 0.08,
			dragCoeff = 0.035,
			lateralGrip = 2.0,
			lateralGripFront = 2.4,
			suspStiffness = 3800,
			suspDampCompress = 4000,
			suspDampRebound = 4500,
			suspRestLength = 1.3,
			suspMaxTravel = 2.0,
			maxSteerAngle = 35,
			steerSpeed = 4.5,
			steerReturnSpeed = 6,
			counterSteerFactor = 0.4,
			antiRollStiffness = 600,
		},
	},
}

local vehicleById: { [string]: VehicleDef } = {}
for _, v in VEHICLES do
	vehicleById[v.id] = v
end

function VehicleRegistry.getAll(): { VehicleDef }
	return VEHICLES
end

function VehicleRegistry.getById(id: string): VehicleDef?
	return vehicleById[id]
end

function VehicleRegistry.getDefault(): VehicleDef
	return vehicleById["all_rounder"]
end

function VehicleRegistry.getUnlockedForLevel(level: number): { VehicleDef }
	local result = {}
	for _, v in VEHICLES do
		if v.unlockLevel <= level then
			table.insert(result, v)
		end
	end
	return result
end

function VehicleRegistry.isUnlocked(vehicleId: string, level: number): boolean
	local v = vehicleById[vehicleId]
	if not v then return false end
	return v.unlockLevel <= level
end

function VehicleRegistry.getVehicleIds(): { string }
	local ids = {}
	for _, v in VEHICLES do
		table.insert(ids, v.id)
	end
	return ids
end

return VehicleRegistry
