--[[
	DownhillPhysics — Pure computation functions for the Downhill Madness chassis.

	No Roblox service references. Takes data in, returns results out.
	The caller (ChassisClient) handles raycasting, input, and force application.
]]

local DownhillPhysics = {}

----------------------------------------------------------------
-- Suspension
----------------------------------------------------------------

export type SuspensionResult = {
	force: number,
	onGround: boolean,
	springLength: number,
	contactPosition: Vector3,
}

function DownhillPhysics.suspension(
	hitDistance: number?,
	rayOrigin: Vector3,
	rayLength: number,
	lastSpringLen: number,
	cfg: any,
	wheelCount: number,
	assemblyMass: number,
	gravity: number,
	dt: number
): SuspensionResult
	local safeDt = math.clamp(dt, 0.0005, 0.1)

	if hitDistance then
		local springLen = hitDistance - cfg.wheelRadius
		springLen = math.clamp(springLen, 0, cfg.suspRestLength + cfg.suspMaxTravel)

		local compression = cfg.suspRestLength - springLen
		local velocity = (lastSpringLen - springLen) / safeDt
		velocity = math.clamp(velocity, -500, 500)

		local damp = if velocity > 0 then cfg.suspDampCompress else cfg.suspDampRebound

		local weightPerWheel = math.max(assemblyMass, 1) * gravity / math.max(wheelCount, 1)
		local force = weightPerWheel + cfg.suspStiffness * compression + damp * velocity
		force = math.clamp(force, 0, weightPerWheel * cfg.maxSuspForceMul)

		return {
			force = force,
			onGround = true,
			springLength = springLen,
			contactPosition = rayOrigin - Vector3.yAxis * hitDistance,
		}
	end

	return {
		force = 0,
		onGround = false,
		springLength = cfg.suspRestLength + cfg.suspMaxTravel,
		contactPosition = rayOrigin - Vector3.yAxis * rayLength,
	}
end

----------------------------------------------------------------
-- Anti-roll bar
----------------------------------------------------------------

function DownhillPhysics.antiRoll(
	leftOnGround: boolean,
	rightOnGround: boolean,
	leftLen: number,
	rightLen: number,
	stiffness: number
): (number, number)
	if not leftOnGround or not rightOnGround then
		return 0, 0
	end
	local diff = leftLen - rightLen
	return -diff * stiffness, diff * stiffness
end

----------------------------------------------------------------
-- Lateral grip (tire model)
----------------------------------------------------------------

function DownhillPhysics.lateralForce(
	lateralSpeed: number,
	longSpeed: number,
	suspForce: number,
	gripMul: number,
	cfg: any,
	surfaceFriction: number
): number
	local slipAngle = 0
	if math.abs(longSpeed) > 0.5 then
		slipAngle = math.deg(math.atan2(lateralSpeed, math.abs(longSpeed)))
	end
	local normSlip = math.clamp(slipAngle / cfg.slipAnglePeak, -1, 1)
	local forceNorm = math.sin(normSlip * math.pi * 0.5)

	local absLat = math.abs(lateralSpeed)
	local falloff = 1
	if absLat > cfg.slideFalloffSpeed then
		local excess = absLat - cfg.slideFalloffSpeed
		falloff = math.clamp(1 - excess / (cfg.slideFalloffSpeed * 2), 0.7, 1)
	end

	local lat = -forceNorm * suspForce * gripMul * falloff * surfaceFriction
	local maxLat = suspForce * cfg.maxLateralClamp * surfaceFriction
	return math.clamp(lat, -maxLat, maxLat)
end

----------------------------------------------------------------
-- Steering
----------------------------------------------------------------

function DownhillPhysics.steerAngle(
	current: number,
	input: number,
	speed: number,
	cfg: any,
	dt: number
): number
	local speedNorm = math.clamp(speed / cfg.maxSpeed, 0, 1)
	local speedFactor = 1 - speedNorm * speedNorm * 0.2
	local target = input * cfg.maxSteerAngle * speedFactor

	if math.abs(input) > 0.05 then
		local rate = cfg.steerSpeed + speedNorm * 4
		return current + (target - current) * math.min(dt * rate, 1)
	else
		return current + (0 - current) * math.min(dt * cfg.steerReturnSpeed, 1)
	end
end

----------------------------------------------------------------
-- Airborne control
----------------------------------------------------------------

function DownhillPhysics.airControl(
	steerInput: number,
	throttleInput: number,
	angularVel: Vector3,
	rootCF: CFrame,
	cfg: any,
	dt: number
): Vector3
	local yaw   = rootCF.UpVector * (-steerInput * cfg.airYawTorque * dt)
	local pitch  = rootCF.RightVector * (throttleInput * cfg.airPitchTorque * dt)
	local torque = yaw + pitch

	local airDamp = angularVel * (-cfg.airDragCoeff * dt)

	return torque + airDamp
end

----------------------------------------------------------------
-- Downforce & drag
----------------------------------------------------------------

function DownhillPhysics.downforce(speed: number, coeff: number, dt: number): Vector3
	if speed <= 10 then return Vector3.zero end
	local safeDt = math.min(dt, 0.1)
	return -Vector3.yAxis * coeff * speed * speed * safeDt
end

function DownhillPhysics.drag(velocity: Vector3, speed: number, coeff: number, dt: number): Vector3
	if speed <= 1 then return Vector3.zero end
	local safeDt = math.min(dt, 0.1)
	return -velocity.Unit * coeff * speed * speed * safeDt
end

----------------------------------------------------------------
-- Angular damping
----------------------------------------------------------------

function DownhillPhysics.angularDamp(angVel: Vector3, coeff: number, dt: number): Vector3
	local mag = angVel.Magnitude
	if mag <= 0.5 then return angVel end
	local safeDt = math.min(dt, 0.1)
	local damp = math.max(1 - coeff * safeDt, 0)
	if mag > 8 then
		damp = damp * math.max(1 - (mag - 8) * 0.05, 0.1)
	end
	if mag > 12 then
		angVel = angVel.Unit * 12
	end
	return angVel * damp
end

return DownhillPhysics
