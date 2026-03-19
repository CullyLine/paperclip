--[[
	⚠️ DEPRECATED — This module is NOT currently used by Downhill Madness.
	The active chassis system uses DownhillConfig.luau + DownhillPhysics.luau instead.
	Kept as reference for the original Polaris-based approach.

	ChassisConfig — Single source of truth for all vehicle tuning parameters.
	
	Based on the Polaris chassis system with DM-specific tuning:
	- AWD (all 4 wheels driven) for chaotic fun
	- Low grip / low angular damping for easy slides and flips
	- Reduced gravity (120) for floaty jumps
	- ABS/TCS disabled by default
	- Open differentials everywhere
	
	Every adjustable value lives here. External scripts modify LiveValues
	(ValueBase objects on the vehicle model), and the chassis reads from
	this config each physics frame. Changing a value here or via LiveValues
	takes effect instantly — no restart needed.
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
	frontLateralGripMultiplier: number,
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

	-- Hydraulics (lowrider) — kept for Polaris compatibility, not used in DM
	hydraulicMaxLift: number,
	hydraulicPumpSpeed: number,
	hydraulicLowerSpeed: number,
	hydraulicBounceFrequency: number,
	hydraulicBounceAmplitude: number,

	-- Gravity override (set in Workspace.Gravity at round start)
	gravity: number,

	-- Wheel Definitions
	wheels: { WheelDef },
}

local DEFAULT_CONFIG: Config = {
	-- Suspension — tuned to match template wheel offset (Y = -1 from chassis center)
	-- restLength = 1.0 so equilibrium wheel center = chassisCenter - 1.0
	suspensionRestLength = 1.0,
	springStiffness = 4000,
	dampingCompression = 3500,
	dampingRebound = 4000,
	antiRollStiffness = 300,
	suspensionMaxTravel = 1.5,

	-- Steering — keep more angle at high speed so the car can still turn when moving fast
	maxSteerAngle = 40,
	steerSpeed = 5,
	steerReturnSpeed = 6,
	counterSteerFactor = 0.4,

	-- Engine & Drivetrain — moderate power, 4 active gears for simplicity
	maxTorque = 10000,
	reverseTorque = 3000,
	idleRPM = 800,
	redlineRPM = 7500,
	shiftUpRPM = 6800,
	shiftDownRPM = 3200,
	gearRatios = { 3.636, 2.375, 1.761, 1.346, 1.062, 0.848, 0.667, 0.553 },
	reverseGearRatio = 3.25,
	finalDriveRatio = 3.42,
	activeGearCount = 4,
	transmissionEfficiency = 0.85,

	-- Differential — all open for simple, predictable AWD
	frontDiff = { diffType = "open" :: any, preload = 0, powerRamp = 0, coastRamp = 0 },
	rearDiff  = { diffType = "open" :: any, preload = 0, powerRamp = 0, coastRamp = 0 },
	centerDiff = { diffType = "open" :: any, preload = 0, powerRamp = 0, coastRamp = 0 },

	-- Tire / Friction — super grip: car sticks, turns on a dime
	tireFrictionCoefficient = 1.25,
	tireSlipAnglepeak = 14,
	lateralGripMultiplier = 1.25,
	frontLateralGripMultiplier = 1.4, -- front still leads in cornering
	longitudinalGripMultiplier = 1.2,
	lateralFalloffSpeed = 50,
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
		Grass = 0.5,
		LeafyGrass = 0.45,
		Ground = 0.45,
		Mud = 0.2,
		Sand = 0.3,
		Snow = 0.2,
		Ice = 0.08,
		Glacier = 0.08,
		SmoothPlastic = 0.85,
		Neon = 0.9,
		Fabric = 0.55,
		Marble = 0.7,
		Pebble = 0.5,
		CrackedLava = 0.4,
		Salt = 0.5,
	},

	-- Stability — very high lateral cap for super grip
	maxSuspensionForceMultiplier = 3.0,
	maxLateralForceClamp = 1.5,
	angularDampingCoefficient = 0.3,

	-- Wheel Visuals
	wheelRadius = 2.0,

	-- Body Physics — light downforce only (high value caused chassis to sink at speed)
	downforceCoefficient = 0.18,
	dragCoefficient = 0.02,
	centerOfMassOffset = Vector3.new(0, 1.5, 0),

	-- ABS — disabled for chaotic braking
	absEnabled = false,
	absSlipThreshold = 0.15,
	absCycleRate = 15,

	-- TCS — disabled so wheels spin freely
	tcsEnabled = false,
	tcsSlipThreshold = 0.20,
	tcsMinTorqueFraction = 0.1,
	tcsFadeRate = 8,

	-- Brake System — weak brakes: long stopping distance, easy to overshoot
	brakeBiasFront = 0.6,
	brakeTorque = 1400,
	handbrakeForce = 1100,
	engineBrakingCoefficient = 0.12,

	-- Limits
	maxSpeedStudsPerSec = 400,

	-- Hydraulics — zeroed out, not used in DM
	hydraulicMaxLift = 0,
	hydraulicPumpSpeed = 0,
	hydraulicLowerSpeed = 0,
	hydraulicBounceFrequency = 0,
	hydraulicBounceAmplitude = 0,

	-- Below Roblox default (196.2) for floaty jumps
	gravity = 120,

	-- AWD layout: all 4 wheels driven
	-- axleId groups left/right wheels for differential: 1 = front axle, 2 = rear axle
	wheels = {
		{ partName = "WheelFL", isSteered = true,  isDriven = true, axleId = 1, suspensionOffset = Vector3.new(-4.5, 0, -6.75) },
		{ partName = "WheelFR", isSteered = true,  isDriven = true, axleId = 1, suspensionOffset = Vector3.new(4.5, 0, -6.75)  },
		{ partName = "WheelRL", isSteered = false, isDriven = true, axleId = 2, suspensionOffset = Vector3.new(-4.5, 0, 6.75)  },
		{ partName = "WheelRR", isSteered = false, isDriven = true, axleId = 2, suspensionOffset = Vector3.new(4.5, 0, 6.75)   },
	},
}

function ChassisConfig.new(overrides: Config?): Config
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
	if overrides then
		for key, value in overrides do
			if config[key] ~= nil then
				config[key] = value
			end
		end
	end
	config.activeGearCount = math.clamp(config.activeGearCount, 1, #config.gearRatios)
	return config
end

function ChassisConfig.getDefault(): Config
	return ChassisConfig.new()
end

function ChassisConfig.getSurfaceFriction(config: Config, material: Enum.Material): number
	local name = material.Name
	return config.surfaceFrictionMap[name] or 1.0
end

return ChassisConfig
