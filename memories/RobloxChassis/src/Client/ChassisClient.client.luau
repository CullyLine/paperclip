--[[
	ChassisClient — Client-side physics loop for responsive driving.
	
	Runs on the player who is sitting in the driver seat.
	Network ownership is transferred to them by the server script.
	All raycast suspension, drivetrain, steering, and force
	application happen here for zero-latency feel.
	
	Place this as a LocalScript in StarterPlayerScripts.
	DriverHUD should be a ModuleScript child of this script.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local vehicleModel: Model = nil
local config: any = nil
local driverSeat: Seat = nil
local root: BasePart = nil
local wheelsFolder: Model = nil

local ChassisConfig = nil
local LiveValuesSync = nil
local Drivetrain = nil
local ChassisPhysics = nil

local driveState = nil

type WheelData = {
	part: BasePart,
	def: any,
	lastSuspensionLength: number,
	visualAngle: number,
	groundHit: boolean,
	contactNormal: Vector3,
	suspensionForce: number,
	localVelocity: Vector3,
	surfaceMaterial: Enum.Material?,
	hydraulicOffset: number,
	hydraulicTarget: number,
}

local wheels: { WheelData } = {}
local rayParams: RaycastParams = nil
local currentSteerAngle = 0
local physicsConnection: RBXScriptConnection? = nil
local isActive = false
local handbrakeInput = 0
local absActive = false
local tcsActive = false
local absPulseTimer = 0

local hud = nil
local telemetryVisible = false
local lastGForce = Vector3.zero
local gForceSmoothFactor = 0.15

-- Hydraulics state
local hydraulicInputs = { 0, 0, 0, 0 } -- per-corner target direction: +1 raise, -1 lower, 0 idle
local bounceMode = false
local bounceIntensityLevel = 0 -- 0=off, 1=low, 2=med, 3=high
local BOUNCE_AMPLITUDES = { 0, 0.5, 1.5, 3.0 }
local bounceTimer = 0
local hydraulicKeysHeld: { [Enum.KeyCode]: boolean } = {}
local hydSyncTimer = 0
local HYD_SYNC_INTERVAL = 0.2
local savedJumpHeight: number? = nil
local savedJumpPower: number? = nil

local keysHeld: { [Enum.KeyCode]: boolean } = {}
local function getThrottleInput(): number
	local fwd = if keysHeld[Enum.KeyCode.W] then 1 else 0
	local rev = if keysHeld[Enum.KeyCode.S] then 1 else 0
	return fwd - rev
end
local function getSteerInput(): number
	local left = if keysHeld[Enum.KeyCode.A] then 1 else 0
	local right = if keysHeld[Enum.KeyCode.D] then 1 else 0
	return left - right
end

local function updateHydraulicInputsFromKeys()
	-- Pair keys: I/K = front/back, J/L = left/right
	-- Corner keys: U/O = FL/FR, N/M = RL/RR
	-- Wheel order: 1=FL, 2=FR, 3=RL, 4=RR
	local targets = { 0, 0, 0, 0 }

	-- Front pair (I = raise front, K = lower front)
	if hydraulicKeysHeld[Enum.KeyCode.I] then targets[1] += 1; targets[2] += 1 end
	if hydraulicKeysHeld[Enum.KeyCode.K] then targets[1] -= 1; targets[2] -= 1 end
	-- Left/Right pair (J = raise left, L = raise right)
	if hydraulicKeysHeld[Enum.KeyCode.J] then targets[1] += 1; targets[3] += 1 end
	if hydraulicKeysHeld[Enum.KeyCode.L] then targets[2] += 1; targets[4] += 1 end
	-- Individual corners
	if hydraulicKeysHeld[Enum.KeyCode.U] then targets[1] += 1 end -- FL
	if hydraulicKeysHeld[Enum.KeyCode.O] then targets[2] += 1 end -- FR
	if hydraulicKeysHeld[Enum.KeyCode.N] then targets[3] += 1 end -- RL
	if hydraulicKeysHeld[Enum.KeyCode.M] then targets[4] += 1 end -- RR

	for i = 1, 4 do
		hydraulicInputs[i] = math.clamp(targets[i], -1, 1)
	end
end

local HYDRAULIC_KEYS = {
	[Enum.KeyCode.I] = true, [Enum.KeyCode.K] = true,
	[Enum.KeyCode.J] = true, [Enum.KeyCode.L] = true,
	[Enum.KeyCode.U] = true, [Enum.KeyCode.O] = true,
	[Enum.KeyCode.N] = true, [Enum.KeyCode.M] = true,
}

local function exitVehicle()
	if not isActive or not driverSeat or not root then return end

	local exitPos = root.CFrame * CFrame.new(6, 0, 0)
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil

	if hum then
		hum.Sit = false
		task.delay(0.1, function()
			if char and char.PrimaryPart then
				char:PivotTo(CFrame.new(exitPos.Position + Vector3.new(0, 3, 0)))
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A
		or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
		keysHeld[input.KeyCode] = true
	end

	if not isActive then
		return
	end

	if input.KeyCode == Enum.KeyCode.Space then
		handbrakeInput = 1
	elseif input.KeyCode == Enum.KeyCode.F then
		exitVehicle()
	elseif processed then
		return
	elseif input.KeyCode == Enum.KeyCode.T then
		telemetryVisible = not telemetryVisible
		if hud then
			hud:setTelemetryVisible(telemetryVisible)
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		bounceMode = not bounceMode
		if bounceMode and bounceIntensityLevel == 0 then
			bounceIntensityLevel = 2
		end
		if not bounceMode then
			bounceIntensityLevel = 0
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		if bounceMode then
			bounceIntensityLevel = (bounceIntensityLevel % 3) + 1
		end
	elseif HYDRAULIC_KEYS[input.KeyCode] then
		hydraulicKeysHeld[input.KeyCode] = true
		updateHydraulicInputsFromKeys()
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A
		or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
		keysHeld[input.KeyCode] = nil
	end

	if input.KeyCode == Enum.KeyCode.Space then
		handbrakeInput = 0
	end

	if HYDRAULIC_KEYS[input.KeyCode] then
		hydraulicKeysHeld[input.KeyCode] = nil
		updateHydraulicInputsFromKeys()
	end
end)

local function buildWheels()
	wheels = {}
	for _, def in config.wheels do
		local wheelPart = wheelsFolder:FindFirstChild(def.partName)
		if wheelPart then
			table.insert(wheels, {
				part = wheelPart,
				def = def,
				lastSuspensionLength = config.suspensionRestLength,
				visualAngle = 0,
				groundHit = false,
				contactNormal = Vector3.yAxis,
				suspensionForce = 0,
				localVelocity = Vector3.zero,
				hydraulicOffset = 0,
				hydraulicTarget = 0,
			})
		else
			warn("[ChassisClient] Wheel not found: " .. def.partName)
		end
	end
end

local function castAndComputeSuspension(wheel: WheelData, dt: number): (number, boolean, Vector3, number, Enum.Material?)
	local worldOffset = root.CFrame:PointToWorldSpace(wheel.def.suspensionOffset)
	local effectiveRestLength = config.suspensionRestLength + wheel.hydraulicOffset
	local rayLength = effectiveRestLength + config.wheelRadius + config.suspensionMaxTravel

	local result = workspace:Raycast(worldOffset, -Vector3.yAxis * rayLength, rayParams)

	local suspResult = ChassisPhysics.computeSuspension({
		hitDistance = if result then (worldOffset - result.Position).Magnitude else nil,
		hitNormal = if result then result.Normal else nil,
		rayOrigin = worldOffset,
		rayLength = rayLength,
		lastSuspensionLength = wheel.lastSuspensionLength,
		hydraulicOffset = wheel.hydraulicOffset,
	}, config, #wheels, root.AssemblyMass, workspace.Gravity, dt)

	wheel.lastSuspensionLength = suspResult.springLength
	wheel.groundHit = suspResult.onGround
	wheel.contactNormal = if result then result.Normal else Vector3.yAxis
	wheel.suspensionForce = suspResult.force
	wheel.surfaceMaterial = if result then result.Material else nil

	return suspResult.force, suspResult.onGround, if result then result.Position else suspResult.contactPosition, suspResult.springLength, if result then result.Material else nil
end

local function setWheelCFrame(wheel: WheelData, cf: CFrame)
	wheel.part.CFrame = cf
	for _, child in wheel.part:GetChildren() do
		if child:IsA("BasePart") then child.CFrame = cf end
	end
end

local function physicsStep(dt: number)
	if not isActive or not root or dt <= 0 or dt > 0.5 then return end

	local throttleInput = getThrottleInput()
	local steerInput = getSteerInput()
	local brakeInput = 0

	local forwardSpeed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	if (throttleInput > 0.1 and forwardSpeed < -2) or (throttleInput < -0.1 and forwardSpeed > 2) then
		brakeInput = math.abs(throttleInput) * 0.7
	end

	-- Counter-steer assist: detect oversteer and blend corrective input
	local lateralVel = root.AssemblyLinearVelocity:Dot(root.CFrame.RightVector)
	local counterSteerBlend = 0
	if math.abs(forwardSpeed) > 5 and math.abs(lateralVel) > 2 then
		local slideRatio = lateralVel / math.max(math.abs(forwardSpeed), 1)
		counterSteerBlend = math.clamp(slideRatio * config.counterSteerFactor, -1, 1)
	end
	steerInput = math.clamp(steerInput + counterSteerBlend, -1, 1)

	if root.AssemblyMass <= 0 then return end

	local rootCF = root.CFrame
	local rootVelocity = root.AssemblyLinearVelocity
	local upDir = rootCF.UpVector
	local speed = rootVelocity.Magnitude

	currentSteerAngle = ChassisPhysics.computeSteerAngle(currentSteerAngle, steerInput, speed, config, dt)

	Drivetrain.update(driveState, config, forwardSpeed, throttleInput, dt)

	-- Hydraulics: update per-wheel targets and animate offsets
	bounceTimer += dt
	for i, wheel in wheels do
		local input = hydraulicInputs[i] or 0

		if bounceMode and bounceIntensityLevel > 0 then
			local amp = BOUNCE_AMPLITUDES[bounceIntensityLevel + 1] or 0
			local phase = (i - 1) * math.pi * 0.5 -- stagger corners for visual flair
			local bounceVal = math.sin(bounceTimer * config.hydraulicBounceFrequency * math.pi * 2 + phase) * amp
			wheel.hydraulicTarget = bounceVal
		else
			wheel.hydraulicTarget += input * config.hydraulicPumpSpeed * dt
			if input == 0 then
				-- Gravity-assisted lower when no input held
				wheel.hydraulicTarget = wheel.hydraulicTarget - wheel.hydraulicTarget * config.hydraulicLowerSpeed * dt * 0.3
			end
		end
		wheel.hydraulicTarget = math.clamp(wheel.hydraulicTarget, -config.hydraulicMaxLift, config.hydraulicMaxLift)

		-- Asymmetric animation: fast pump up, controlled descent
		local diff = wheel.hydraulicTarget - wheel.hydraulicOffset
		local speed
		if diff > 0 then
			speed = config.hydraulicPumpSpeed
		else
			speed = config.hydraulicLowerSpeed
		end
		wheel.hydraulicOffset += math.clamp(diff, -speed * dt, speed * dt)
	end

	type WheelFrame = {
		wheel: WheelData,
		onGround: boolean,
		contactPos: Vector3,
		wheelForward: Vector3,
		wheelRight: Vector3,
		longitudinalSpeed: number,
		pointVelocity: Vector3,
		suspForce: number,
		surfaceFriction: number,
	}
	local wheelFrames: { WheelFrame } = {}

	for i, wheel in wheels do
		local suspForce, onGround, contactPos, springLen, hitMaterial = castAndComputeSuspension(wheel, dt)
		local surfFriction = 1.0
		if hitMaterial then
			surfFriction = ChassisConfig.getSurfaceFriction(config, hitMaterial)
		end
		local wf: WheelFrame = {
			wheel = wheel,
			onGround = onGround,
			contactPos = contactPos,
			wheelForward = Vector3.zero,
			wheelRight = Vector3.zero,
			longitudinalSpeed = 0,
			pointVelocity = Vector3.zero,
			suspForce = suspForce,
			surfaceFriction = surfFriction,
		}

		if onGround then
			local attachPoint = rootCF:PointToWorldSpace(wheel.def.suspensionOffset)
			root:ApplyImpulseAtPosition(Vector3.yAxis * suspForce * dt, attachPoint)

			local wheelWorldCF = rootCF * CFrame.new(wheel.def.suspensionOffset)
			if wheel.def.isSteered then
				wheelWorldCF = wheelWorldCF * CFrame.Angles(0, math.rad(currentSteerAngle), 0)
			end
			wf.wheelRight = wheelWorldCF.RightVector
			wf.wheelForward = wheelWorldCF.LookVector

			local pointVelocity = root:GetVelocityAtPosition(attachPoint)
			wf.pointVelocity = pointVelocity
			local lateralSpeed = pointVelocity:Dot(wf.wheelRight)
			local longitudinalSpeed = pointVelocity:Dot(wf.wheelForward)
			wf.longitudinalSpeed = longitudinalSpeed
			wheel.localVelocity = Vector3.new(lateralSpeed, 0, longitudinalSpeed)

			local lateralForce = ChassisPhysics.computeLateralForce({
				lateralSpeed = lateralSpeed,
				longitudinalSpeed = longitudinalSpeed,
				suspensionForce = suspForce,
			}, config, wf.surfaceFriction)

			if handbrakeInput > 0.5 and not wheel.def.isSteered then
				lateralForce = lateralForce * 0.15
			end

			root:ApplyImpulseAtPosition(wf.wheelRight * lateralForce * dt, attachPoint)
		end

		wheelFrames[i] = wf
	end

	local axles: { [number]: { WheelFrame } } = {}
	for _, wf in wheelFrames do
		if wf.wheel.def.isDriven then
			local aid = wf.wheel.def.axleId
			if not axles[aid] then axles[aid] = {} end
			table.insert(axles[aid], wf)
		end
	end

	local driveTorque = Drivetrain.getOutputTorque(driveState, config, throttleInput)
	local atSpeedLimit = math.abs(forwardSpeed) > config.maxSpeedStudsPerSec

	local axleIds = {}
	for aid in axles do
		table.insert(axleIds, aid)
	end
	table.sort(axleIds)

	local axleTorque: { [number]: number } = {}
	if #axleIds == 1 then
		axleTorque[axleIds[1]] = driveTorque
	elseif #axleIds == 2 then
		local frontAxle, rearAxle = axleIds[1], axleIds[2]
		local frontAvgSpeed, rearAvgSpeed = 0, 0
		for _, wf in axles[frontAxle] do frontAvgSpeed += wf.longitudinalSpeed end
		frontAvgSpeed /= #axles[frontAxle]
		for _, wf in axles[rearAxle] do rearAvgSpeed += wf.longitudinalSpeed end
		rearAvgSpeed /= #axles[rearAxle]

		local fFrac, rFrac = Drivetrain.centerSplit(config, frontAvgSpeed, rearAvgSpeed, throttleInput)
		axleTorque[frontAxle] = driveTorque * fFrac
		axleTorque[rearAxle] = driveTorque * rFrac
	else
		for _, aid in axleIds do
			axleTorque[aid] = driveTorque / #axleIds
		end
	end

	local wheelTorque: { [WheelData]: number } = {}
	for aid, axleWheels in axles do
		local diff = Drivetrain.getDiffForAxle(config, aid)
		local tq = axleTorque[aid] or 0

		if #axleWheels == 2 then
			local lFrac, rFrac = Drivetrain.diffSplit(
				diff,
				axleWheels[1].longitudinalSpeed,
				axleWheels[2].longitudinalSpeed,
				throttleInput
			)
			wheelTorque[axleWheels[1].wheel] = tq * lFrac
			wheelTorque[axleWheels[2].wheel] = tq * rFrac
		else
			for _, wf in axleWheels do
				wheelTorque[wf.wheel] = tq / #axleWheels
			end
		end
	end

	absPulseTimer += dt * config.absCycleRate
	local absPulseOn = (math.sin(absPulseTimer * math.pi * 2) > 0)

	local anyAbsTriggered = false
	local anyTcsTriggered = false

	for i, wf in wheelFrames do
		local wheel = wf.wheel
		if wf.onGround then
			local attachPoint = rootCF:PointToWorldSpace(wheel.def.suspensionOffset)

			local tcsMultiplier = 1
			if wheel.def.isDriven and config.tcsEnabled and math.abs(throttleInput) > 0.05 then
				local mult, triggered = ChassisPhysics.computeTcsMultiplier(
					wf.longitudinalSpeed, forwardSpeed, config
				)
				tcsMultiplier = mult
				if triggered then anyTcsTriggered = true end
			end

			if wheel.def.isDriven and not atSpeedLimit then
				local wTorque = (wheelTorque[wheel] or 0) * tcsMultiplier
				local driveForce = ChassisPhysics.computeDriveForce(wTorque, config.wheelRadius, 1, wf.surfaceFriction)

				local driveDir = wf.wheelForward
				if throttleInput < 0 then
					driveDir = -driveDir
				end
				root:ApplyImpulseAtPosition(driveDir * driveForce * dt * config.longitudinalGripMultiplier, attachPoint)
			end

			if wheel.def.isDriven and math.abs(throttleInput) < 0.05 and math.abs(wf.longitudinalSpeed) > 1 then
				local engineBrakeForce = ChassisPhysics.computeEngineBrakeForce(
					wf.longitudinalSpeed, wf.suspForce, driveState.currentRPM, config
				)
				local brakeDir = -wf.wheelForward * (if wf.longitudinalSpeed > 0 then 1 else -1)
				root:ApplyImpulseAtPosition(brakeDir * engineBrakeForce * dt, attachPoint)
			end

			if brakeInput > 0.05 then
				local isFrontAxle = (wheel.def.axleId == 1)
				local brakeForce = ChassisPhysics.computeBrakeForce(brakeInput, isFrontAxle, config)

				local applyBrake = true
				if ChassisPhysics.shouldAbsPulse(wf.longitudinalSpeed, forwardSpeed, config) then
					applyBrake = absPulseOn
					anyAbsTriggered = true
				end

				if applyBrake then
					local brakeDir = -wf.pointVelocity.Unit
					if wf.pointVelocity.Magnitude < 1 then
						brakeDir = Vector3.zero
					end
					root:ApplyImpulseAtPosition(brakeDir * brakeForce * dt, attachPoint)
				end
			end

			if handbrakeInput > 0.5 and wheel.def.axleId == 2 then
				local hbForce = config.handbrakeForce / config.wheelRadius
				local brakeDir = -wf.pointVelocity.Unit
				if wf.pointVelocity.Magnitude < 1 then
					brakeDir = Vector3.zero
				end
				root:ApplyImpulseAtPosition(brakeDir * hbForce * dt, attachPoint)
			end

			local wheelSpinSpeed = wf.longitudinalSpeed / config.wheelRadius
			wheel.visualAngle += math.deg(wheelSpinSpeed * dt)

			local cf = ChassisPhysics.computeWheelCFrameSmoothed({
				onGround = true,
				contactPosition = wf.contactPos,
				suspensionOffset = wheel.def.suspensionOffset,
				isSteered = wheel.def.isSteered,
				steerAngle = currentSteerAngle,
				visualAngle = wheel.visualAngle,
			}, rootCF, upDir, config)
			setWheelCFrame(wheel, cf)
		else
			-- Decay wheel spin smoothly while airborne instead of snapping to 0
			wheel.visualAngle = wheel.visualAngle * (1 - dt * 2)

			local cf = ChassisPhysics.computeWheelCFrameSmoothed({
				onGround = false,
				contactPosition = Vector3.zero,
				suspensionOffset = wheel.def.suspensionOffset,
				isSteered = wheel.def.isSteered,
				steerAngle = currentSteerAngle,
				visualAngle = wheel.visualAngle,
			}, rootCF, upDir, config)
			setWheelCFrame(wheel, cf)
		end
	end

	absActive = anyAbsTriggered
	tcsActive = anyTcsTriggered

	if #wheels >= 4 then
		local flAR, frAR = ChassisPhysics.computeAntiRoll(
			wheels[1].groundHit, wheels[2].groundHit,
			wheels[1].lastSuspensionLength, wheels[2].lastSuspensionLength,
			config.antiRollStiffness
		)
		if flAR ~= 0 then
			local fl_pos = rootCF:PointToWorldSpace(wheels[1].def.suspensionOffset)
			local fr_pos = rootCF:PointToWorldSpace(wheels[2].def.suspensionOffset)
			root:ApplyImpulseAtPosition(Vector3.yAxis * flAR * dt, fl_pos)
			root:ApplyImpulseAtPosition(Vector3.yAxis * frAR * dt, fr_pos)
		end
		local rlAR, rrAR = ChassisPhysics.computeAntiRoll(
			wheels[3].groundHit, wheels[4].groundHit,
			wheels[3].lastSuspensionLength, wheels[4].lastSuspensionLength,
			config.antiRollStiffness
		)
		if rlAR ~= 0 then
			local rl_pos = rootCF:PointToWorldSpace(wheels[3].def.suspensionOffset)
			local rr_pos = rootCF:PointToWorldSpace(wheels[4].def.suspensionOffset)
			root:ApplyImpulseAtPosition(Vector3.yAxis * rlAR * dt, rl_pos)
			root:ApplyImpulseAtPosition(Vector3.yAxis * rrAR * dt, rr_pos)
		end
	end

	local downforceImpulse = ChassisPhysics.computeDownforce(speed, config.downforceCoefficient, dt)
	if downforceImpulse.Magnitude > 0 then
		root:ApplyImpulseAtPosition(downforceImpulse, rootCF.Position)
	end

	local dragImpulse = ChassisPhysics.computeDrag(rootVelocity, speed, config.dragCoefficient, dt)
	if dragImpulse.Magnitude > 0 then
		root:ApplyImpulseAtPosition(dragImpulse, rootCF.Position)
	end

	root.AssemblyAngularVelocity = ChassisPhysics.computeAngularDamping(
		root.AssemblyAngularVelocity, config.angularDampingCoefficient, dt
	)

	if hud then
		local speedMPH = math.abs(forwardSpeed) * 0.6818
		local dominantSurface: string? = nil
		local lowestFriction = 2.0
		for _, wf in wheelFrames do
			if wf.onGround and wf.wheel.surfaceMaterial then
				if wf.surfaceFriction < lowestFriction then
					lowestFriction = wf.surfaceFriction
					dominantSurface = wf.wheel.surfaceMaterial.Name
				end
			end
		end
		local hydraulicsActive = false
		for _, w in wheels do
			if math.abs(w.hydraulicOffset) > 0.05 then
				hydraulicsActive = true
				break
			end
		end
		hud:update(speedMPH, driveState.currentGear, driveState.currentRPM, config.redlineRPM, driveState.isReversing, absActive, tcsActive, dominantSurface, hydraulicsActive, bounceMode, bounceIntensityLevel)

		if telemetryVisible then
			local lateralAccel = rootVelocity:Dot(rootCF.RightVector)
			local longAccel = forwardSpeed
			local gravity = workspace.Gravity
			local instantGForce = Vector3.new(
				root.AssemblyLinearVelocity:Dot(rootCF.RightVector),
				0,
				forwardSpeed
			)
			local accel = (instantGForce - lastGForce) / math.max(dt, 0.001)
			local gLateral = accel.X / gravity
			local gLongitudinal = accel.Z / gravity
			lastGForce = instantGForce

			gLateral = math.clamp(gLateral * gForceSmoothFactor, -2, 2)
			gLongitudinal = math.clamp(gLongitudinal * gForceSmoothFactor, -2, 2)

			local totalSuspForce = 0
			for _, wf in wheelFrames do
				if wf.onGround then totalSuspForce += wf.suspForce end
			end

			local wheelTelemetry = {}
			for i, wf in wheelFrames do
				local wheel = wf.wheel
				local latSpeed = if wf.onGround then wheel.localVelocity.X else 0
				local lonSpeed = wf.longitudinalSpeed
				local slipAngle = 0
				if math.abs(lonSpeed) > 0.5 then
					slipAngle = math.deg(math.atan2(latSpeed, math.abs(lonSpeed)))
				end
				local slipRatio = 0
				if math.abs(forwardSpeed) > 1 then
					slipRatio = (math.abs(lonSpeed) - math.abs(forwardSpeed)) / math.abs(forwardSpeed)
				end
				local compression = config.suspensionRestLength - wheel.lastSuspensionLength
				local weightFrac = if totalSuspForce > 0 then wf.suspForce / totalSuspForce else 0.25

				wheelTelemetry[i] = {
					suspCompression = compression,
					contactForce = wf.suspForce,
					slipAngle = slipAngle,
					slipRatio = slipRatio,
					surfaceMaterial = if wheel.surfaceMaterial then wheel.surfaceMaterial.Name else "---",
					onGround = wf.onGround,
					weightFraction = weightFrac,
				}
			end

			hud:updateTelemetry({
				gLateral = gLateral,
				gLongitudinal = gLongitudinal,
				speed = speedMPH,
				rpm = driveState.currentRPM,
				gear = driveState.currentGear,
				steerAngle = currentSteerAngle,
				wheels = wheelTelemetry,
			})
		end
	end

	-- Sync hydraulic offsets to server periodically
	hydSyncTimer += dt
	if hydSyncTimer >= HYD_SYNC_INTERVAL then
		hydSyncTimer = 0
		local hydSyncEvent = vehicleModel and vehicleModel:FindFirstChild("HydraulicSync")
		if hydSyncEvent and hydSyncEvent:IsA("RemoteEvent") then
			local offsets = {}
			for i, w in wheels do
				offsets[i] = w.hydraulicOffset
			end
			hydSyncEvent:FireServer(offsets)
		end
	end

end

local function findVehicleModel(seat: Instance): Model?
	local model = seat.Parent
	while model do
		if model:FindFirstChild("ChassisConfig") and model:FindFirstChild("Body") and model:FindFirstChild("Wheels") then
			return model
		end
		if model == workspace then break end
		model = model.Parent
	end
	return nil
end

local function startDriving(vModel: Model, initialConfig: any, gear: number?, rpm: number?)
	if isActive then return end

	vehicleModel = vModel
	driverSeat = vModel:FindFirstChild("DriverSeat")
	if not driverSeat then
		for _, desc in vModel:GetDescendants() do
			if desc:IsA("Seat") then
				driverSeat = desc
				break
			end
		end
	end

	local bodyModel = vModel:FindFirstChild("Body")
	if not bodyModel then
		warn("[ChassisClient] No Body model found in vehicle")
		return
	end
	root = bodyModel.PrimaryPart or bodyModel:FindFirstChildWhichIsA("BasePart")
	if not root then
		warn("[ChassisClient] No root part found in Body")
		return
	end
	wheelsFolder = vModel:FindFirstChild("Wheels")
	if not wheelsFolder then
		warn("[ChassisClient] No Wheels model found in vehicle")
		return
	end

	local configModule = vModel:FindFirstChild("ChassisConfig")
	if not configModule then
		warn("[ChassisClient] ChassisConfig not found in vehicle model")
		return
	end
	local lvsModule = vModel:FindFirstChild("LiveValuesSync")
	if not lvsModule then
		warn("[ChassisClient] LiveValuesSync not found in vehicle model")
		return
	end
	local dtModule = vModel:FindFirstChild("Drivetrain")
	if not dtModule then
		warn("[ChassisClient] Drivetrain not found in vehicle model")
		return
	end
	local cpModule = vModel:FindFirstChild("ChassisPhysics")
	if not cpModule then
		warn("[ChassisClient] ChassisPhysics not found in vehicle model")
		return
	end

	ChassisConfig = require(configModule)
	LiveValuesSync = require(lvsModule)
	Drivetrain = require(dtModule)
	ChassisPhysics = require(cpModule)

	config = ChassisConfig.new(initialConfig)
	driveState = Drivetrain.new()
	if gear then driveState.currentGear = gear end
	if rpm then driveState.currentRPM = rpm end

	local liveContainer = vModel:FindFirstChild("LiveValues")
	if liveContainer then
		LiveValuesSync.bind(liveContainer, config)
	end

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicleModel }

	buildWheels()

	local hudModule = script:FindFirstChild("DriverHUD")
	if hudModule then
		local DriverHUD = require(hudModule)
		hud = DriverHUD.new(playerGui)
	else
		warn("[ChassisClient] DriverHUD module not found as child of this script")
	end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			savedJumpHeight = hum.JumpHeight
			savedJumpPower = hum.JumpPower
			hum.JumpHeight = 0
			hum.JumpPower = 0
		end
	end

	handbrakeInput = 0
	isActive = true
	physicsConnection = RunService.Heartbeat:Connect(physicsStep)
	print("[ChassisClient] Driving started")
end

local function stopDriving()
	isActive = false
	if physicsConnection then
		physicsConnection:Disconnect()
		physicsConnection = nil
	end
	if hud then
		hud:destroy()
		hud = nil
	end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			if savedJumpHeight then hum.JumpHeight = savedJumpHeight end
			if savedJumpPower then hum.JumpPower = savedJumpPower end
		end
	end
	savedJumpHeight = nil
	savedJumpPower = nil

	vehicleModel = nil
	config = nil
	driveState = nil
	handbrakeInput = 0
	bounceMode = false
	bounceIntensityLevel = 0
	bounceTimer = 0
	hydraulicInputs = { 0, 0, 0, 0 }
	table.clear(hydraulicKeysHeld)
	print("[ChassisClient] Driving stopped")
end

local function setupSeatListener()
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		humanoid.Seated:Connect(function(seated, seat)
			if seated and seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
				local vModel = findVehicleModel(seat)
				if vModel then
					task.defer(function()
						startDriving(vModel, nil, nil, nil)
					end)
				else
					warn("[ChassisClient] Sat in seat but could not find vehicle model with ChassisConfig/Body/Wheels")
				end
			elseif not seated and isActive then
				stopDriving()
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

setupSeatListener()
print("[ChassisClient] Seat listener ready")
