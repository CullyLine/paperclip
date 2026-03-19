--[[
	ChassisConfig — Single source of truth for all vehicle tuning parameters.
	
	Every adjustable value lives here. External scripts modify LiveValues
	(ValueBase objects on the vehicle model), and the chassis reads from
	this config each physics frame. Changing a value here or via LiveValues
	takes effect instantly — no restart needed.
	
	Architecture:
	  LiveValues (ValueBase instances on vehicle model)
	       ↕  .Changed listeners keep this table in sync
	  ChassisConfig (this module — the runtime truth)
	       ↓  read each frame
	  ChassisController (physics loop)
]]

local ChassisConfig = {}
ChassisConfig.__index = ChassisConfig

export type WheelDef = {
	partName: string,
	isSteered: boolean,
	isDriven: boolean,
	axleId: number,
	suspensionOffset: Vector3,
}

export type DiffType = "open" | "locked" | "lsd"

export type DifferentialDef = {
	diffType: DiffType,
	preload: number,
	powerRamp: number,
	coastRamp: number,
}

export type Config = {
	-- Suspension
	suspensionRestLength: number,
	springStiffness: number,
	dampingCompression: number,
	dampingRebound: number,
	antiRollStiffness: number,
	suspensionMaxTravel: number,

	-- Steering
	maxSteerAngle: number,
	steerSpeed: number,
	steerReturnSpeed: number,
	counterSteerFactor: number,

	-- Engine & Drivetrain
	maxTorque: number,
	brakeTorque: number,
	reverseTorque: number,
	idleRPM: number,
	redlineRPM: number,
	shiftUpRPM: number,
	shiftDownRPM: number,
	gearRatios: { number },
	reverseGearRatio: number,
	finalDriveRatio: number,
	activeGearCount: number,
	transmissionEfficiency: number,

	-- Differential
	frontDiff: DifferentialDef,
	rearDiff: DifferentialDef,
	centerDiff: DifferentialDef,

	-- Tire / Friction
	tireFrictionCoefficient: number,
	tireSlipAnglepeak: number,
	lateralGripMultiplier: number,
	longitudinalGripMultiplier: number,
	lateralFalloffSpeed: number,
	surfaceFrictionMap: { [string]: number },

	-- Stability Limits
	maxSuspensionForceMultiplier: number,
	maxLateralForceClamp: number,
	angularDampingCoefficient: number,

	-- Wheel Visuals
	wheelRadius: number,

	-- Body Physics
	downforceCoefficient: number,
	dragCoefficient: number,
	centerOfMassOffset: Vector3,

	-- ABS (Anti-lock Braking System)
	absEnabled: boolean,
	absSlipThreshold: number,
	absCycleRate: number,

	-- TCS (Traction Control System)
	tcsEnabled: boolean,
	tcsSlipThreshold: number,
	tcsMinTorqueFraction: number,
	tcsFadeRate: number,

	-- Brake System
	brakeBiasFront: number,
	handbrakeForce: number,
	engineBrakingCoefficient: number,

	-- Limits
	maxSpeedStudsPerSec: number,

	-- Hydraulics (lowrider)
	hydraulicMaxLift: number,
	hydraulicPumpSpeed: number,
	hydraulicLowerSpeed: number,
	hydraulicBounceFrequency: number,
	hydraulicBounceAmplitude: number,

	-- Wheel Definitions
	wheels: { WheelDef },
}

local DEFAULT_CONFIG: Config = {
	-- Suspension — weight-relative base force handles weight-bearing;
	-- these values control ride feel on top of that.
	suspensionRestLength = 2.5,
	springStiffness = 3000,
	dampingCompression = 2500,
	dampingRebound = 3000,
	antiRollStiffness = 800,
	suspensionMaxTravel = 3.0,

	-- Steering
	maxSteerAngle = 35,
	steerSpeed = 6,
	steerReturnSpeed = 8,
	counterSteerFactor = 0.3,

	-- Engine & Drivetrain (scaled for ~1700 mass chassis, high performance)
	maxTorque = 12000,
	brakeTorque = 6000,
	reverseTorque = 4000,
	idleRPM = 800,
	redlineRPM = 7500,
	shiftUpRPM = 6800,
	shiftDownRPM = 3200,
	gearRatios = { 3.636, 2.375, 1.761, 1.346, 1.062, 0.848, 0.667, 0.553 },
	reverseGearRatio = 3.25,
	finalDriveRatio = 3.42,
	activeGearCount = 6,
	transmissionEfficiency = 0.85,

	-- Differential — per-axle limited-slip differentials.
	-- preload: fraction of torque always sent to slower wheel (0 = open, 1 = locked).
	-- powerRamp / coastRamp: multipliers that scale lock-up under accel / decel.
	frontDiff = { diffType = "open" :: any, preload = 0, powerRamp = 0, coastRamp = 0 },
	rearDiff  = { diffType = "lsd" :: any,  preload = 0.15, powerRamp = 1.0, coastRamp = 0.6 },
	centerDiff = { diffType = "open" :: any, preload = 0, powerRamp = 0, coastRamp = 0 },

	-- Tire / Friction
	tireFrictionCoefficient = 1.6,
	tireSlipAnglepeak = 8,
	lateralGripMultiplier = 1.0,
	longitudinalGripMultiplier = 1.0,
	lateralFalloffSpeed = 15,
	surfaceFrictionMap = {
		Asphalt = 1.0,
		Concrete = 0.95,
		Brick = 0.9,
		Cobblestone = 0.85,
		Wood = 0.8,
		WoodPlanks = 0.8,
		Metal = 0.75,
		DiamondPlate = 0.75,
		CorrodedMetal = 0.7,
		Slate = 0.7,
		Basalt = 0.7,
		Granite = 0.7,
		Limestone = 0.7,
		Sandstone = 0.65,
		Pavement = 0.95,
		Grass = 0.6,
		LeafyGrass = 0.55,
		Ground = 0.55,
		Mud = 0.35,
		Sand = 0.4,
		Snow = 0.3,
		Ice = 0.15,
		Glacier = 0.15,
		SmoothPlastic = 0.85,
		Neon = 0.9,
		Fabric = 0.65,
		Marble = 0.8,
		Pebble = 0.6,
		CrackedLava = 0.5,
		Salt = 0.6,
	},

	-- Stability Limits
	maxSuspensionForceMultiplier = 3.0,
	maxLateralForceClamp = 0.8,
	angularDampingCoefficient = 2.5,

	-- Wheel Visuals
	wheelRadius = 2.0,

	-- Body Physics
	downforceCoefficient = 0.3,
	dragCoefficient = 0.02,
	centerOfMassOffset = Vector3.new(0, -0.5, 0),

	-- ABS — pulses brake force to prevent wheel lockup
	absEnabled = true,
	absSlipThreshold = 0.15,
	absCycleRate = 15,

	-- TCS — reduces drive torque when wheels spin
	tcsEnabled = true,
	tcsSlipThreshold = 0.20,
	tcsMinTorqueFraction = 0.1,
	tcsFadeRate = 8,

	-- Brake System
	brakeBiasFront = 0.6,
	handbrakeForce = 5000,
	engineBrakingCoefficient = 0.4,

	-- Limits
	maxSpeedStudsPerSec = 500,

	-- Hydraulics (lowrider) — all offsets at 0 by default (invisible until activated)
	hydraulicMaxLift = 3.0,
	hydraulicPumpSpeed = 10,
	hydraulicLowerSpeed = 5,
	hydraulicBounceFrequency = 2.0,
	hydraulicBounceAmplitude = 1.5,

	-- Default 4-wheel layout (FL, FR, RL, RR)
	-- axleId groups left/right wheels for differential: 1 = front axle, 2 = rear axle
	-- Front (steered) wheels at -Z to match root LookVector direction
	wheels = {
		{ partName = "WheelFL", isSteered = true,  isDriven = false, axleId = 1, suspensionOffset = Vector3.new(-4.5, 0, -6.75) },
		{ partName = "WheelFR", isSteered = true,  isDriven = false, axleId = 1, suspensionOffset = Vector3.new(4.5, 0, -6.75)  },
		{ partName = "WheelRL", isSteered = false, isDriven = true,  axleId = 2, suspensionOffset = Vector3.new(-4.5, 0, 6.75)  },
		{ partName = "WheelRR", isSteered = false, isDriven = true,  axleId = 2, suspensionOffset = Vector3.new(4.5, 0, 6.75)   },
	},
}

function ChassisConfig.new(overrides: Config?): Config
	local config = table.clone(DEFAULT_CONFIG)
	-- Deep-clone nested tables so instances don't share diff/wheel refs
	config.frontDiff = table.clone(config.frontDiff)
	config.rearDiff = table.clone(config.rearDiff)
	config.centerDiff = table.clone(config.centerDiff)
	config.surfaceFrictionMap = table.clone(config.surfaceFrictionMap)
	config.gearRatios = table.clone(config.gearRatios)
	local clonedWheels = {}
	for i, w in config.wheels do
		clonedWheels[i] = table.clone(w)
	end
	config.wheels = clonedWheels
	if overrides then
		for key, value in overrides do
			if config[key] ~= nil then
				config[key] = value
			end
		end
	end
	-- Clamp activeGearCount
	config.activeGearCount = math.clamp(config.activeGearCount, 1, #config.gearRatios)
	return config
end

function ChassisConfig.getDefault(): Config
	local config = table.clone(DEFAULT_CONFIG)
	config.frontDiff = table.clone(config.frontDiff)
	config.rearDiff = table.clone(config.rearDiff)
	config.centerDiff = table.clone(config.centerDiff)
	config.surfaceFrictionMap = table.clone(config.surfaceFrictionMap)
	config.gearRatios = table.clone(config.gearRatios)
	local clonedWheels = {}
	for i, w in config.wheels do
		clonedWheels[i] = table.clone(w)
	end
	config.wheels = clonedWheels
	return config
end

function ChassisConfig.getSurfaceFriction(config: Config, material: Enum.Material): number
	local name = material.Name
	return config.surfaceFrictionMap[name] or 1.0
end

return ChassisConfig
