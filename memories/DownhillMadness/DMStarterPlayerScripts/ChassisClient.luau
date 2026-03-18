--[[
	ChassisClient — Client-side physics loop for Downhill Madness.
	
	Based on the Polaris chassis system. Runs on the player who is
	sitting in the driver seat. Network ownership is transferred to
	them by VehicleSpawner. All raycast suspension, drivetrain,
	steering, and force application happen here for zero-latency feel.
	
	Differences from stock Polaris:
	  - Modules required from DMReplicatedStorage (not vehicle model)
	  - Uses InputManager for input abstraction
	  - Humanoid.Seated detection (not RemoteEvent start/stop)
	  - Cylinder wheel parts use native X-axis orientation (no extra rotation needed)
	  - No built-in DriverHUD (DM has its own UI)
	  - No hydraulics input/sync
	  - Sets workspace.Gravity from config on start, restores on stop
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local InputManager = require(script.Parent:WaitForChild("InputManager"))

local DMReplicatedStorage = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local ChassisConfig = require(DMReplicatedStorage:WaitForChild("ChassisConfig"))
local ChassisPhysics = require(DMReplicatedStorage:WaitForChild("ChassisPhysics"))
local Drivetrain = require(DMReplicatedStorage:WaitForChild("Drivetrain"))
local LiveValuesSync = require(DMReplicatedStorage:WaitForChild("LiveValuesSync"))

local input: any = nil
local vehicleModel: Model = nil
local config: any = nil
local driveState: any = nil
local root: BasePart = nil
local wheelsFolder: Model = nil

type WheelData = {
	part: BasePart,   -- physical (welded), never touched
	visual: BasePart, -- anchored proxy, CFrame updated each frame (reparented off assembly)
	def: any,
	pendingCFrame: CFrame?, -- applied in RenderStepped to avoid rubber-banding
	lastSuspensionLength: number,
	visualAngle: number,
	groundHit: boolean,
	contactNormal: Vector3,
	suspensionForce: number,
	localVelocity: Vector3,
	surfaceMaterial: Enum.Material?,
}

local wheels: { WheelData } = {}
local rayParams: RaycastParams = nil
local currentSteerAngle = 0
local physicsConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local isActive = false
local absPulseTimer = 0

local function buildWheels()
	wheels = {}
	local wheelVisualsFolder = vehicleModel and vehicleModel:FindFirstChild("WheelVisuals")
	for _, def in config.wheels do
		local wheelPart = wheelsFolder:FindFirstChild(def.partName)
			or wheelsFolder:WaitForChild(def.partName, 5)
		-- Visual may be under wheel (first sit) or already in WheelVisuals (re-entry)
		local visualPart = wheelPart and (wheelPart:FindFirstChild("Visual")
			or (wheelVisualsFolder and wheelVisualsFolder:FindFirstChild(def.partName .. "_Visual")))
		if wheelPart and visualPart and visualPart:IsA("BasePart") then
			table.insert(wheels, {
				part = wheelPart,
				visual = visualPart,
				def = def,
				pendingCFrame = nil,
				lastSuspensionLength = config.suspensionRestLength,
				visualAngle = 0,
				groundHit = false,
				contactNormal = Vector3.yAxis,
				suspensionForce = 0,
				localVelocity = Vector3.zero,
			})
		elseif wheelPart then
			warn("[ChassisClient] Wheel " .. def.partName .. " missing Visual child")
		else
			warn("[ChassisClient] Wheel not found after 5s: " .. def.partName)
		end
	end
end

local function castAndComputeSuspension(wheel: WheelData, dt: number): (number, boolean, Vector3, number, Enum.Material?)
	local worldOffset = root.CFrame:PointToWorldSpace(wheel.def.suspensionOffset)
	local rayLength = config.suspensionRestLength + config.wheelRadius + config.suspensionMaxTravel

	local result = workspace:Raycast(worldOffset, -Vector3.yAxis * rayLength, rayParams)

	local suspResult = ChassisPhysics.computeSuspension({
		hitDistance = if result then (worldOffset - result.Position).Magnitude else nil,
		hitNormal = if result then result.Normal else nil,
		rayOrigin = worldOffset,
		rayLength = rayLength,
		lastSuspensionLength = wheel.lastSuspensionLength,
		hydraulicOffset = 0,
	}, config, #wheels, root.AssemblyMass, workspace.Gravity, dt)

	wheel.lastSuspensionLength = suspResult.springLength
	wheel.groundHit = suspResult.onGround
	wheel.contactNormal = if result then result.Normal else Vector3.yAxis
	wheel.suspensionForce = suspResult.force
	wheel.surfaceMaterial = if result then result.Material else nil

	return suspResult.force, suspResult.onGround, if result then result.Position else suspResult.contactPosition, suspResult.springLength, if result then result.Material else nil
end

-- Store CFrame for RenderStepped (avoids rubber-band from parent/assembly updates)
local function setWheelCFrame(wheel: WheelData, cf: CFrame)
	wheel.pendingCFrame = cf
end

local function applyWheelCFrames()
	for _, wheel in wheels do
		if wheel.pendingCFrame then
			wheel.visual.CFrame = wheel.pendingCFrame
			for _, child in wheel.visual:GetChildren() do
				if child:IsA("BasePart") then child.CFrame = wheel.pendingCFrame end
			end
		end
	end
end

local function physicsStep(dt: number)
	if not isActive or not root or dt <= 0 or dt > 0.5 then return end
	if root.Anchored then return end

	local inputState = input:getState()
	local throttleInput = inputState.throttle
	local steerInput = -inputState.steer
	local handbrakeInput = inputState.handbrake
	local brakeInput = 0

	local forwardSpeed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	if (throttleInput > 0.1 and forwardSpeed < -2) or (throttleInput < -0.1 and forwardSpeed > 2) then
		brakeInput = math.abs(throttleInput) * 0.7
	end

	-- Counter-steer assist
	local lateralVel = root.AssemblyLinearVelocity:Dot(root.CFrame.RightVector)
	if math.abs(forwardSpeed) > 5 and math.abs(lateralVel) > 2 then
		local slideRatio = lateralVel / math.max(math.abs(forwardSpeed), 1)
		local counterSteerBlend = math.clamp(slideRatio * config.counterSteerFactor, -1, 1)
		steerInput = math.clamp(steerInput + counterSteerBlend, -1, 1)
	end

	if root.AssemblyMass <= 0 then return end

	local rootCF = root.CFrame
	local rootVelocity = root.AssemblyLinearVelocity
	local upDir = rootCF.UpVector
	local speed = rootVelocity.Magnitude

	currentSteerAngle = ChassisPhysics.computeSteerAngle(currentSteerAngle, steerInput, speed, config, dt)

	Drivetrain.update(driveState, config, forwardSpeed, throttleInput, dt)

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

			if wheel.def.isSteered and (config.frontLateralGripMultiplier or 1) ~= 1 then
				lateralForce = lateralForce * (config.frontLateralGripMultiplier or 1)
			end
			if handbrakeInput > 0.5 and not wheel.def.isSteered then
				lateralForce = lateralForce * 0.15
			end

			root:ApplyImpulseAtPosition(wf.wheelRight * lateralForce * dt, attachPoint)
		end

		wheelFrames[i] = wf
	end

	-- Drivetrain torque distribution via differentials
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

	for i, wf in wheelFrames do
		local wheel = wf.wheel
		if wf.onGround then
			local attachPoint = rootCF:PointToWorldSpace(wheel.def.suspensionOffset)

			-- TCS
			local tcsMultiplier = 1
			if wheel.def.isDriven and config.tcsEnabled and math.abs(throttleInput) > 0.05 then
				local mult, _ = ChassisPhysics.computeTcsMultiplier(
					wf.longitudinalSpeed, forwardSpeed, config
				)
				tcsMultiplier = mult
			end

			-- Drive force
			if wheel.def.isDriven and not atSpeedLimit then
				local wTorque = (wheelTorque[wheel] or 0) * tcsMultiplier
				local driveForce = ChassisPhysics.computeDriveForce(wTorque, config.wheelRadius, 1, wf.surfaceFriction)

				local driveDir = wf.wheelForward
				if throttleInput < 0 then
					driveDir = -driveDir
				end
				root:ApplyImpulseAtPosition(driveDir * driveForce * dt * config.longitudinalGripMultiplier, attachPoint)
			end

			-- Engine braking
			if wheel.def.isDriven and math.abs(throttleInput) < 0.05 and math.abs(wf.longitudinalSpeed) > 1 then
				local engineBrakeForce = ChassisPhysics.computeEngineBrakeForce(
					wf.longitudinalSpeed, wf.suspForce, driveState.currentRPM, config
				)
				local brakeDir = -wf.wheelForward * (if wf.longitudinalSpeed > 0 then 1 else -1)
				root:ApplyImpulseAtPosition(brakeDir * engineBrakeForce * dt, attachPoint)
			end

			-- Brake force
			if brakeInput > 0.05 then
				local isFrontAxle = (wheel.def.axleId == 1)
				local brakeForce = ChassisPhysics.computeBrakeForce(brakeInput, isFrontAxle, config)

				local applyBrake = true
				if ChassisPhysics.shouldAbsPulse(wf.longitudinalSpeed, forwardSpeed, config) then
					applyBrake = absPulseOn
				end

				if applyBrake then
					local brakeDir = -wf.pointVelocity.Unit
					if wf.pointVelocity.Magnitude < 1 then
						brakeDir = Vector3.zero
					end
					root:ApplyImpulseAtPosition(brakeDir * brakeForce * dt, attachPoint)
				end
			end

			-- Handbrake on rear wheels
			if handbrakeInput > 0.5 and wheel.def.axleId == 2 then
				local hbForce = config.handbrakeForce / config.wheelRadius
				local brakeDir = -wf.pointVelocity.Unit
				if wf.pointVelocity.Magnitude < 1 then
					brakeDir = Vector3.zero
				end
				root:ApplyImpulseAtPosition(brakeDir * hbForce * dt, attachPoint)
			end

			-- Wheel spin visual
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

	-- Anti-roll bars
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

	-- Downforce — very low cap so suspension is never overwhelmed (prevents chassis sinking)
	local downforceImpulse = ChassisPhysics.computeDownforce(speed, config.downforceCoefficient, dt)
	if downforceImpulse.Magnitude > 0 then
		local maxDownforceMagnitude = root.AssemblyMass * workspace.Gravity * dt * 0.12
		if downforceImpulse.Magnitude > maxDownforceMagnitude then
			downforceImpulse = downforceImpulse.Unit * maxDownforceMagnitude
		end
		root:ApplyImpulseAtPosition(downforceImpulse, rootCF.Position)
	end

	-- Aerodynamic drag
	local dragImpulse = ChassisPhysics.computeDrag(rootVelocity, speed, config.dragCoefficient, dt)
	if dragImpulse.Magnitude > 0 then
		root:ApplyImpulseAtPosition(dragImpulse, rootCF.Position)
	end

	-- Angular damping
	root.AssemblyAngularVelocity = ChassisPhysics.computeAngularDamping(
		root.AssemblyAngularVelocity, config.angularDampingCoefficient, dt
	)
end

local function findVehicleModel(seat: Instance): Model?
	local model = seat.Parent
	while model do
		if model:FindFirstChild("Body") and model:FindFirstChild("Wheels") then
			return model
		end
		if model == workspace then break end
		model = model.Parent
	end
	return nil
end

local function startDriving(vModel: Model)
	if isActive then return end

	vehicleModel = vModel

	local bodyModel = vModel:FindFirstChild("Body")
	if not bodyModel then
		warn("[ChassisClient] No Body model found")
		return
	end
	-- Robust root: by name, then PrimaryPart, then any BasePart in Body, then vehicle-level PrimaryPart
	root = bodyModel:FindFirstChild("Chassis") or bodyModel:FindFirstChild("CarBody")
		or bodyModel.PrimaryPart
	if not root then
		for _, child in bodyModel:GetChildren() do
			if child:IsA("BasePart") then root = child break end
		end
	end
	if not root then
		for _, desc in bodyModel:GetDescendants() do
			if desc:IsA("BasePart") then root = desc break end
		end
	end
	if not root and vModel.PrimaryPart then
		root = vModel.PrimaryPart
	end
	if not root then
		warn("[ChassisClient] No root part in Body")
		return
	end
	wheelsFolder = vModel:FindFirstChild("Wheels")
	if not wheelsFolder then
		warn("[ChassisClient] No Wheels model found")
		return
	end

	config = ChassisConfig.new()
	driveState = Drivetrain.new()

	workspace.Gravity = config.gravity

	-- LiveValues hot-tuning support
	local liveContainer = vModel:FindFirstChild("LiveValues")
	if liveContainer then
		LiveValuesSync.bind(liveContainer, config)
	end

	-- Hide character from all spatial queries while driving
	if player.Character then
		for _, desc in player.Character:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CanQuery = false
			end
		end
	end

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicleModel }

	buildWheels()

	-- Reparent visuals off the physical wheels so the weld/assembly doesn't pull them back (only if still under wheel)
	local wheelVisualsFolder = vehicleModel:FindFirstChild("WheelVisuals")
	if not wheelVisualsFolder then
		wheelVisualsFolder = Instance.new("Folder")
		wheelVisualsFolder.Name = "WheelVisuals"
		wheelVisualsFolder.Parent = vehicleModel
	end
	for _, wheel in wheels do
		if wheel.visual.Parent ~= wheelVisualsFolder then
			wheel.visual.Name = wheel.def.partName .. "_Visual"
			wheel.visual.Parent = wheelVisualsFolder
		end
	end

	input = InputManager.new()
	absPulseTimer = 0
	isActive = true
	physicsConnection = RunService.Heartbeat:Connect(physicsStep)
	-- Apply wheel positions right before render so they don't get overwritten by assembly
	renderConnection = RunService.RenderStepped:Connect(applyWheelCFrames)
end

local function stopDriving()
	isActive = false
	if physicsConnection then
		physicsConnection:Disconnect()
		physicsConnection = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if input then
		input:destroy()
		input = nil
	end

	-- Restore character to be queryable
	if player.Character then
		for _, desc in player.Character:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CanQuery = true
			end
		end
	end

	workspace.Gravity = 196.2

	vehicleModel = nil
	config = nil
	driveState = nil
	root = nil
	wheelsFolder = nil
	currentSteerAngle = 0
	absPulseTimer = 0
end

local function setupSeatListener()
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		humanoid.Seated:Connect(function(seated, seat)
			if seated and seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
				local vModel = findVehicleModel(seat)
				if vModel then
					task.defer(startDriving, vModel)
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

return true
