--[[
	⚠️ DEPRECATED — This module is NOT currently used by Downhill Madness.
	The active chassis uses a flat drive force model (no gears/RPM).
	See DownhillConfig.luau driveForce / reverseForce / maxSpeed instead.
	Kept as reference for the original Polaris-based approach.

	Drivetrain — Gear shifting, RPM simulation, and torque output.
	
	RPM is derived from wheel speed within the current gear ratio,
	clamped to idle-redline range. Automatic shifting happens at
	configurable RPM thresholds. Gear ratios are multiplied by the
	final drive ratio for total reduction.
]]

local Drivetrain = {}
Drivetrain.__index = Drivetrain

export type DrivetrainState = {
	currentGear: number,
	currentRPM: number,
	shiftCooldown: number,
	isReversing: boolean,
}

local SHIFT_COOLDOWN_SEC = 0.25

function Drivetrain.new(): DrivetrainState
	return setmetatable({
		currentGear = 1,
		currentRPM = 800,
		shiftCooldown = 0,
		isReversing = false,
	}, Drivetrain)
end

function Drivetrain.getTotalRatio(config: any, gear: number): number
	if gear < 1 or gear > config.activeGearCount then
		return config.gearRatios[1] * config.finalDriveRatio
	end
	return config.gearRatios[gear] * config.finalDriveRatio
end

function Drivetrain.update(state: DrivetrainState, config: any, wheelSpeed: number, throttle: number, dt: number)
	state.shiftCooldown = math.max(0, state.shiftCooldown - dt)

	-- Determine if reversing
	state.isReversing = throttle < -0.1

	local effectiveSpeed = math.abs(wheelSpeed)

	-- Calculate RPM from wheel speed and current gear ratio
	local totalRatio
	if state.isReversing then
		totalRatio = config.reverseGearRatio * config.finalDriveRatio
	else
		totalRatio = Drivetrain.getTotalRatio(config, state.currentGear)
	end

	-- RPM = wheelAngularVelocity * gearRatio
	-- wheelAngularVelocity ≈ speed / wheelRadius
	local wheelAngularSpeed = effectiveSpeed / math.max(config.wheelRadius, 0.1)
	local rawRPM = wheelAngularSpeed * totalRatio * 60 / (2 * math.pi)

	-- Blend with throttle-driven rev climb for responsiveness
	local throttleBoost = math.abs(throttle) * config.redlineRPM * 0.15
	local targetRPM = rawRPM + throttleBoost

	targetRPM = math.clamp(targetRPM, config.idleRPM, config.redlineRPM)

	-- Smooth RPM transitions
	local rpmLerp = dt * 12
	state.currentRPM = state.currentRPM + (targetRPM - state.currentRPM) * math.min(rpmLerp, 1)

	-- Automatic gear shifting (forward only)
	if not state.isReversing and state.shiftCooldown <= 0 then
		if state.currentRPM >= config.shiftUpRPM and state.currentGear < config.activeGearCount then
			state.currentGear += 1
			state.shiftCooldown = SHIFT_COOLDOWN_SEC
			-- RPM drop on upshift
			local newRatio = Drivetrain.getTotalRatio(config, state.currentGear)
			local oldRatio = Drivetrain.getTotalRatio(config, state.currentGear - 1)
			state.currentRPM = state.currentRPM * (newRatio / oldRatio)
		elseif state.currentRPM <= config.shiftDownRPM and state.currentGear > 1 then
			state.currentGear -= 1
			state.shiftCooldown = SHIFT_COOLDOWN_SEC
			local newRatio = Drivetrain.getTotalRatio(config, state.currentGear)
			local oldRatio = Drivetrain.getTotalRatio(config, state.currentGear + 1)
			state.currentRPM = state.currentRPM * (newRatio / oldRatio)
		end
	end

	state.currentRPM = math.clamp(state.currentRPM, config.idleRPM, config.redlineRPM)
end

function Drivetrain.getOutputTorque(state: DrivetrainState, config: any, throttle: number): number
	local absThrottle = math.abs(throttle)

	if absThrottle < 0.05 then
		return 0
	end

	local totalRatio
	if state.isReversing then
		totalRatio = config.reverseGearRatio * config.finalDriveRatio
	else
		totalRatio = Drivetrain.getTotalRatio(config, state.currentGear)
	end

	-- Torque curve: peaks at ~60% of redline, falls off near redline
	local rpmRange = config.redlineRPM - config.idleRPM
	if rpmRange <= 0 then rpmRange = 1 end
	local rpmNorm = (state.currentRPM - config.idleRPM) / rpmRange
	local torqueCurve = 1 - (rpmNorm - 0.6)^2 * 1.5
	torqueCurve = math.clamp(torqueCurve, 0.3, 1.0)

	local baseTorque = state.isReversing and config.reverseTorque or config.maxTorque
	local engineTorque = baseTorque * absThrottle * torqueCurve

	return engineTorque * totalRatio * config.transmissionEfficiency
end

function Drivetrain.getRPMNormalized(state: DrivetrainState, config: any): number
	local range = config.redlineRPM - config.idleRPM
	if range <= 0 then return 0 end
	return (state.currentRPM - config.idleRPM) / range
end

--[[
	Differential torque split.
	
	Returns (leftFraction, rightFraction) that sum to 1.0.
	`leftSpeed` / `rightSpeed` are longitudinal wheel speeds (signed).
	`throttle` determines whether to use powerRamp or coastRamp.
]]
function Drivetrain.diffSplit(diff: any, leftSpeed: number, rightSpeed: number, throttle: number): (number, number)
	local diffType = diff.diffType

	if diffType == "locked" then
		return 0.5, 0.5
	end

	if diffType == "open" then
		local absL = math.abs(leftSpeed)
		local absR = math.abs(rightSpeed)
		local sum = absL + absR
		if sum < 0.5 then
			return 0.5, 0.5
		end
		return absR / sum, absL / sum
	end

	-- LSD: blend between open and locked based on speed difference and tuning params
	local preload = diff.preload or 0
	local ramp = if math.abs(throttle) > 0.05 then (diff.powerRamp or 1) else (diff.coastRamp or 0.5)

	local absL = math.abs(leftSpeed)
	local absR = math.abs(rightSpeed)
	local sum = absL + absR

	local openL, openR
	if sum < 0.5 then
		openL, openR = 0.5, 0.5
	else
		openL = absR / sum
		openR = absL / sum
	end

	local speedDiff = math.abs(leftSpeed - rightSpeed)
	local lockFactor = math.clamp(preload + speedDiff * ramp * 0.01, 0, 1)

	local leftFrac = openL + (0.5 - openL) * lockFactor
	local rightFrac = openR + (0.5 - openR) * lockFactor

	return leftFrac, rightFrac
end

--[[
	Determines the DifferentialDef for a given axleId.
	axleId 1 = front, axleId 2 = rear. For AWD, center diff governs
	front/rear torque split before per-axle diffs apply.
]]
function Drivetrain.getDiffForAxle(config: any, axleId: number): any
	if axleId == 1 then
		return config.frontDiff
	end
	return config.rearDiff
end

--[[
	For AWD vehicles, compute (frontFraction, rearFraction) based on the
	center differential. `frontSpeed` and `rearSpeed` are average axle speeds.
]]
function Drivetrain.centerSplit(config: any, frontSpeed: number, rearSpeed: number, throttle: number): (number, number)
	return Drivetrain.diffSplit(config.centerDiff, frontSpeed, rearSpeed, throttle)
end

return Drivetrain
