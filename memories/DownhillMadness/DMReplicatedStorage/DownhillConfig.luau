--[[
	DownhillConfig — Tuning parameters for the Downhill Madness chassis.

	Flat table, no classes, no complexity. Change a value and it takes
	effect next physics frame.
]]

local DownhillConfig = {}

export type WheelDef = {
	name: string,
	offset: Vector3,
	isSteered: boolean,
}

export type Config = {
	-- Suspension (raycast spring-damper)
	suspRestLength: number,
	suspStiffness: number,
	suspDampCompress: number,
	suspDampRebound: number,
	suspMaxTravel: number,
	antiRollStiffness: number,

	-- Wheels
	wheelRadius: number,
	wheels: { WheelDef },

	-- Steering
	maxSteerAngle: number,
	steerSpeed: number,
	steerReturnSpeed: number,

	-- Drive (flat force model — no gears, no RPM)
	driveForce: number,
	brakeForce: number,
	reverseForce: number,
	maxSpeed: number,
	engineBraking: number,

	-- Traction
	lateralGrip: number,
	lateralGripFront: number,
	maxLateralClamp: number,
	slipAnglePeak: number,
	slideFalloffSpeed: number,
	handbrakeGripFactor: number,

	-- Surface friction overrides
	surfaceFriction: { [string]: number },

	-- Body physics
	downforceCoeff: number,
	dragCoeff: number,
	angularDamping: number,
	centerOfMassOffset: Vector3,

	-- Airborne control
	airYawTorque: number,
	airPitchTorque: number,
	airRollTorque: number,
	airDragCoeff: number,

	-- Counter-steer assist
	counterSteerFactor: number,

	-- Gravity override (applied to workspace.Gravity)
	gravity: number,

	-- Max suspension force as multiple of weight-per-wheel
	maxSuspForceMul: number,
}

local DEFAULT: Config = {
	suspRestLength = 1.0,
	suspStiffness = 4500,
	suspDampCompress = 3000,
	suspDampRebound = 3500,
	suspMaxTravel = 1.5,
	antiRollStiffness = 400,

	wheelRadius = 2.0,
	wheels = {
		{ name = "WheelFL", offset = Vector3.new(-4.5, 0, -6.75), isSteered = true },
		{ name = "WheelFR", offset = Vector3.new(4.5, 0, -6.75),  isSteered = true },
		{ name = "WheelRL", offset = Vector3.new(-4.5, 0, 6.75),  isSteered = false },
		{ name = "WheelRR", offset = Vector3.new(4.5, 0, 6.75),   isSteered = false },
	},

	maxSteerAngle = 40,
	steerSpeed = 6,
	steerReturnSpeed = 8,

	driveForce = 28000,
	brakeForce = 18000,
	reverseForce = 12000,
	maxSpeed = 400,
	engineBraking = 0.15,

	lateralGrip = 2.5,
	lateralGripFront = 3.0,
	maxLateralClamp = 2.0,
	slipAnglePeak = 14,
	slideFalloffSpeed = 50,
	handbrakeGripFactor = 0.12,

	surfaceFriction = {
		Asphalt = 1.0, Concrete = 0.95, Brick = 0.9, Cobblestone = 0.85,
		Wood = 0.8, WoodPlanks = 0.8, Metal = 0.75, DiamondPlate = 0.75,
		Pavement = 0.95, Grass = 0.5, LeafyGrass = 0.45, Ground = 0.45,
		Mud = 0.2, Sand = 0.3, Snow = 0.2, Ice = 0.08, Glacier = 0.08,
		SmoothPlastic = 0.85, Neon = 0.9, Fabric = 0.55,
	},

	downforceCoeff = 0.15,
	dragCoeff = 0.02,
	angularDamping = 0.3,
	centerOfMassOffset = Vector3.new(0, 1.5, 0),

	airYawTorque = 6000,
	airPitchTorque = 4000,
	airRollTorque = 2000,
	airDragCoeff = 0.8,

	counterSteerFactor = 0.35,
	gravity = 120,
	maxSuspForceMul = 3.0,
}

function DownhillConfig.new(overrides: { [string]: any }?): Config
	local cfg = table.clone(DEFAULT)
	cfg.surfaceFriction = table.clone(DEFAULT.surfaceFriction)
	local clonedWheels = {}
	for i, w in DEFAULT.wheels do
		clonedWheels[i] = table.clone(w)
	end
	cfg.wheels = clonedWheels

	if overrides then
		for k, v in overrides do
			if cfg[k] ~= nil then
				cfg[k] = v
			end
		end
	end
	return cfg
end

function DownhillConfig.forVehicle(vehicleId: string): Config
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DMReplicatedStorage = ReplicatedStorage:FindFirstChild("DMReplicatedStorage")
	if not DMReplicatedStorage then return DownhillConfig.new() end

	local ok, VehicleRegistry = pcall(require, DMReplicatedStorage:FindFirstChild("VehicleRegistry"))
	if not ok or not VehicleRegistry then return DownhillConfig.new() end

	local def = VehicleRegistry.getById(vehicleId)
	if not def then return DownhillConfig.new() end

	local spec = def.buildSpec
	local overrides = {}
	for k, v in def.physicsOverrides do
		overrides[k] = v
	end

	overrides.wheelRadius = spec.wheelRadius
	overrides.wheels = {
		{ name = "WheelFL", offset = spec.wheelOffsets[1], isSteered = true },
		{ name = "WheelFR", offset = spec.wheelOffsets[2], isSteered = true },
		{ name = "WheelRL", offset = spec.wheelOffsets[3], isSteered = false },
		{ name = "WheelRR", offset = spec.wheelOffsets[4], isSteered = false },
	}
	overrides.centerOfMassOffset = spec.comOffset

	return DownhillConfig.new(overrides)
end

function DownhillConfig.getSurfaceFriction(cfg: Config, material: Enum.Material): number
	return cfg.surfaceFriction[material.Name] or 1.0
end

return DownhillConfig
