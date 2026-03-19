--[[
	⚠️ DEPRECATED — This module is NOT currently used by Downhill Madness.
	The active chassis system uses DownhillPhysics.luau instead.
	Kept as reference for the original Polaris-based approach.

	ChassisPhysics — Pure physics computation functions shared between
	server (ChassisController) and client (ChassisClient).

	These functions take data in and return results out. They never
	reference Roblox services, perform raycasts, or apply forces.
	The caller is responsible for raycasting, reading input, and
	applying the returned forces/positions to the assembly.
]]

local ChassisPhysics = {}

export type SuspensionInput = {
	hitDistance: number?,
	hitNormal: Vector3?,
	rayOrigin: Vector3,
	rayLength: number,
	lastSuspensionLength: number,
	hydraulicOffset: number?,
}

export type SuspensionResult = {
	force: number,
	onGround: boolean,
	springLength: number,
	contactPosition: Vector3,
}

function ChassisPhysics.computeSuspension(
	input: SuspensionInput,
	config: any,
	wheelCount: number,
	assemblyMass: number,
	gravity: number,
	dt: number
): SuspensionResult
	local safeDt = math.clamp(dt, 0.0005, 0.1)
	local safeMass = math.max(assemblyMass, 1)
	local effectiveRestLength = config.suspensionRestLength + (input.hydraulicOffset or 0)

	if input.hitDistance then
		local springLength = input.hitDistance - config.wheelRadius
		springLength = math.clamp(springLength, 0, effectiveRestLength + config.suspensionMaxTravel)

		local compression = effectiveRestLength - springLength
		local springVelocity = (input.lastSuspensionLength - springLength) / safeDt
		springVelocity = math.clamp(springVelocity, -500, 500)

		local dampingCoeff
		if springVelocity > 0 then
			dampingCoeff = config.dampingCompression
		else
			dampingCoeff = config.dampingRebound
		end

		local weightPerWheel = safeMass * gravity / math.max(wheelCount, 1)
		local force = weightPerWheel + (config.springStiffness * compression) + (dampingCoeff * springVelocity)
		force = math.clamp(force, 0, weightPerWheel * config.maxSuspensionForceMultiplier)

		return {
			force = force,
			onGround = true,
			springLength = springLength,
			contactPosition = input.rayOrigin + (-Vector3.yAxis) * input.hitDistance,
		}
	else
		return {
			force = 0,
			onGround = false,
			springLength = effectiveRestLength + config.suspensionMaxTravel,
			contactPosition = input.rayOrigin + (-Vector3.yAxis) * input.rayLength,
		}
	end
end

function ChassisPhysics.computeAntiRoll(
	leftOnGround: boolean,
	rightOnGround: boolean,
	leftSpringLength: number,
	rightSpringLength: number,
	antiRollStiffness: number
): (number, number)
	if not leftOnGround or not rightOnGround then
		return 0, 0
	end
	local diff = leftSpringLength - rightSpringLength
	local antiRollForce = diff * antiRollStiffness
	return -antiRollForce, antiRollForce
end

export type LateralForceInput = {
	lateralSpeed: number,
	longitudinalSpeed: number,
	suspensionForce: number,
}

function ChassisPhysics.computeLateralForce(input: LateralForceInput, config: any, surfaceFriction: number?): number
	local surfMul = surfaceFriction or 1.0
	local slipAngle = 0
	if math.abs(input.longitudinalSpeed) > 0.5 then
		slipAngle = math.deg(math.atan2(input.lateralSpeed, math.abs(input.longitudinalSpeed)))
	end
	local normalizedSlip = math.clamp(slipAngle / config.tireSlipAnglepeak, -1, 1)
	local lateralForceNorm = math.sin(normalizedSlip * math.pi * 0.5)

	-- Mild slide falloff: keep most grip even when sliding (super grip feel)
	local absLateralSpeed = math.abs(input.lateralSpeed)
	local slideFalloff = 1
	if absLateralSpeed > config.lateralFalloffSpeed then
		local excess = absLateralSpeed - config.lateralFalloffSpeed
		local range = math.max(config.lateralFalloffSpeed * 2, 1)
		slideFalloff = math.clamp(1 - excess / range, 0.75, 1)
	end

	local lateralForce = -lateralForceNorm * input.suspensionForce * config.tireFrictionCoefficient * config.lateralGripMultiplier * slideFalloff * surfMul
	local maxLateral = input.suspensionForce * config.tireFrictionCoefficient * config.maxLateralForceClamp * surfMul
	lateralForce = math.clamp(lateralForce, -maxLateral, maxLateral)

	return lateralForce
end

function ChassisPhysics.computeDriveForce(
	wheelTorque: number,
	wheelRadius: number,
	gripMultiplier: number,
	surfaceFriction: number?
): number
	local surfMul = surfaceFriction or 1.0
	return (wheelTorque / wheelRadius) * gripMultiplier * surfMul
end

function ChassisPhysics.computeBrakeForce(
	brakeInput: number,
	isFrontAxle: boolean,
	config: any
): number
	local biasMultiplier = if isFrontAxle then config.brakeBiasFront * 2 else (1 - config.brakeBiasFront) * 2
	return config.brakeTorque * brakeInput * biasMultiplier / config.wheelRadius
end

function ChassisPhysics.computeEngineBrakeForce(
	longitudinalSpeed: number,
	suspensionForce: number,
	currentRPM: number,
	config: any
): number
	if math.abs(longitudinalSpeed) <= 1 then
		return 0
	end
	local engineBrakeForce = config.engineBrakingCoefficient * currentRPM / config.redlineRPM
	return engineBrakeForce * suspensionForce * config.tireFrictionCoefficient
end

function ChassisPhysics.computeTcsMultiplier(
	wheelLongitudinalSpeed: number,
	chassisForwardSpeed: number,
	config: any
): (number, boolean)
	local wheelRotSpeed = math.abs(wheelLongitudinalSpeed)
	local chassisSpeed = math.abs(chassisForwardSpeed)
	local slipRatio = 0
	if chassisSpeed > 1 then
		slipRatio = (wheelRotSpeed - chassisSpeed) / chassisSpeed
	elseif wheelRotSpeed > 2 then
		slipRatio = 1
	end
	if slipRatio > config.tcsSlipThreshold then
		local excessSlip = slipRatio - config.tcsSlipThreshold
		local multiplier = math.clamp(1 - excessSlip * config.tcsFadeRate, config.tcsMinTorqueFraction, 1)
		return multiplier, true
	end
	return 1, false
end

function ChassisPhysics.shouldAbsPulse(
	wheelLongitudinalSpeed: number,
	chassisForwardSpeed: number,
	config: any
): boolean
	if not config.absEnabled then
		return false
	end
	if math.abs(wheelLongitudinalSpeed) <= 2 then
		return false
	end
	local wheelRotSpeed = math.abs(wheelLongitudinalSpeed)
	local chassisSpeed = math.abs(chassisForwardSpeed)
	local slipRatio = 0
	if chassisSpeed > 1 then
		slipRatio = 1 - (wheelRotSpeed / math.max(chassisSpeed, 0.1))
	end
	return math.abs(slipRatio) > config.absSlipThreshold
end

export type WheelVisualInput = {
	onGround: boolean,
	contactPosition: Vector3,
	suspensionOffset: Vector3,
	isSteered: boolean,
	steerAngle: number,
	visualAngle: number,
}

function ChassisPhysics.computeWheelCFrame(
	input: WheelVisualInput,
	rootCF: CFrame,
	upDir: Vector3,
	config: any
): CFrame
	local bodyRot = rootCF - rootCF.Position
	if input.onGround then
		local visualPos = input.contactPosition + upDir * config.wheelRadius
		local cf = CFrame.new(visualPos) * bodyRot
		if input.isSteered then
			cf = cf * CFrame.Angles(0, math.rad(input.steerAngle), 0)
		end
		cf = cf * CFrame.Angles(math.rad(input.visualAngle), 0, 0)
		return cf
	else
		local worldOffset = rootCF:PointToWorldSpace(input.suspensionOffset)
		local dropPos = worldOffset - upDir * config.suspensionRestLength
		return CFrame.new(dropPos) * bodyRot
	end
end

function ChassisPhysics.computeWheelCFrameSmoothed(
	input: WheelVisualInput,
	rootCF: CFrame,
	upDir: Vector3,
	config: any
): CFrame
	local bodyRot = rootCF - rootCF.Position
	if input.onGround then
		local rollDot = upDir:Dot(Vector3.yAxis)
		local blendedUp = if rollDot > 0.7 then upDir else upDir:Lerp(Vector3.yAxis, 1 - rollDot).Unit
		local visualPos = input.contactPosition + blendedUp * config.wheelRadius
		local cf = CFrame.new(visualPos) * bodyRot
		if input.isSteered then
			cf = cf * CFrame.Angles(0, math.rad(input.steerAngle), 0)
		end
		cf = cf * CFrame.Angles(math.rad(input.visualAngle), 0, 0)
		return cf
	else
		local worldOffset = rootCF:PointToWorldSpace(input.suspensionOffset)
		local dropPos = worldOffset - upDir * config.suspensionRestLength
		return CFrame.new(dropPos) * bodyRot
	end
end

function ChassisPhysics.computeDownforce(speed: number, coefficient: number, dt: number): Vector3
	if speed <= 10 then
		return Vector3.zero
	end
	local safeDt = math.min(dt, 0.1)
	return -Vector3.yAxis * coefficient * speed * speed * safeDt
end

function ChassisPhysics.computeDrag(velocity: Vector3, speed: number, coefficient: number, dt: number): Vector3
	if speed <= 1 then
		return Vector3.zero
	end
	local safeDt = math.min(dt, 0.1)
	return -velocity.Unit * coefficient * speed * speed * safeDt
end

function ChassisPhysics.computeSteerAngle(
	currentAngle: number,
	steerInput: number,
	speed: number,
	config: any,
	dt: number
): number
	-- Speed-sensitive steering: keep most of the angle at high speed so car can turn
	local speedNorm = math.clamp(speed / config.maxSpeedStudsPerSec, 0, 1)
	local speedFactor = 1 - speedNorm * speedNorm * 0.18
	local targetAngle = steerInput * config.maxSteerAngle * speedFactor

	if math.abs(steerInput) > 0.05 then
		local rate = config.steerSpeed + speedNorm * 4
		return currentAngle + (targetAngle - currentAngle) * math.min(dt * rate, 1)
	else
		return currentAngle + (0 - currentAngle) * math.min(dt * config.steerReturnSpeed, 1)
	end
end

function ChassisPhysics.computeAngularDamping(
	angularVelocity: Vector3,
	coefficient: number,
	dt: number
): Vector3
	local mag = angularVelocity.Magnitude
	if mag <= 0.5 then
		return angularVelocity
	end
	local safeDt = math.min(dt, 0.1)
	local damping = math.max(1 - coefficient * safeDt, 0)
	if mag > 8 then
		damping = damping * math.max(1 - (mag - 8) * 0.05, 0.1)
	end
	local MAX_ANGULAR_SPEED = 12
	if mag > MAX_ANGULAR_SPEED then
		angularVelocity = angularVelocity.Unit * MAX_ANGULAR_SPEED
	end
	return angularVelocity * damping
end

-- Helper: apply anti-roll forces for a left/right wheel pair.
-- Returns (leftForce, rightForce) impulse magnitudes along Y axis.
function ChassisPhysics.computeAntiRollPair(
	leftOnGround: boolean,
	rightOnGround: boolean,
	leftSpringLength: number,
	rightSpringLength: number,
	antiRollStiffness: number
): (number, number)
	return ChassisPhysics.computeAntiRoll(
		leftOnGround, rightOnGround,
		leftSpringLength, rightSpringLength,
		antiRollStiffness
	)
end

return ChassisPhysics
