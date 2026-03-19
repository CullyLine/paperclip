--[[
	ChassisController — Main server script for raycast vehicle physics.
	
	Place this script inside the vehicle Model. The model structure:
	  VehicleModel
	    ├── Body (Model — the car body parts, contains PrimaryPart)
	    ├── Wheels (Model — WheelFL, WheelFR, WheelRL, WheelRR)
	    ├── DriverSeat (VehicleSeat)
	    ├── LiveValues (Configuration — created by LiveValuesSync)
	    └── ChassisController (this script)
	    └── ChassisConfig (ModuleScript)
	
	Server runs suspension at all times (keeps car up + wheels positioned).
	When a player sits, network ownership transfers to them and
	the client takes over full physics for responsiveness.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local vehicleModel = script.Parent
local ChassisConfig = require(vehicleModel:WaitForChild("ChassisConfig", 10))
local LiveValuesSync = require(vehicleModel:WaitForChild("LiveValuesSync", 10))
local Drivetrain = require(vehicleModel:WaitForChild("Drivetrain", 10))
local ChassisPhysics = require(vehicleModel:WaitForChild("ChassisPhysics", 10))

local config = ChassisConfig.new()
local driveState = Drivetrain.new()

local body: Model = vehicleModel:WaitForChild("Body", 10)
local wheelsFolder: Model = vehicleModel:WaitForChild("Wheels", 10)
local driverSeat: Seat = vehicleModel:WaitForChild("DriverSeat", 10)

assert(body, "Vehicle must have a Body model")
assert(wheelsFolder, "Vehicle must have a Wheels model")
assert(driverSeat, "Vehicle must have a DriverSeat")

local root: BasePart = body.PrimaryPart or body:FindFirstChildWhichIsA("BasePart")
assert(root, "Body must have a PrimaryPart or at least one BasePart")

-- LiveValues setup
local liveContainer = vehicleModel:FindFirstChild("LiveValues")
if not liveContainer then
	liveContainer = LiveValuesSync.createContainer(vehicleModel, config)
end
local liveSync = LiveValuesSync.bind(liveContainer, config)

type WheelData = {
	part: BasePart,
	def: any,
	lastSuspensionLength: number,
	visualAngle: number,
	groundHit: boolean,
	contactNormal: Vector3,
	suspensionForce: number,
	localVelocity: Vector3,
	hydraulicOffset: number,
}

local wheels: { WheelData } = {}

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
		})
	else
		warn("[Chassis] Wheel part not found: " .. def.partName)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { vehicleModel }

local currentSteerAngle = 0
local isDriverSeated = false
local currentDriver: Player? = nil
local serverPhysicsConnection: RBXScriptConnection? = nil

local function weldModel(model: Model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then return end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.CanCollide = false
		end
	end
end

local function applyCenterOfMass()
	local offset = config.centerOfMassOffset
	if offset.Magnitude < 0.01 then return end

	local comPart = Instance.new("Part")
	comPart.Name = "CenterOfMass"
	comPart.Size = Vector3.new(0.1, 0.1, 0.1)
	comPart.Transparency = 1
	comPart.CanCollide = false
	comPart.Massless = false
	comPart.CustomPhysicalProperties = PhysicalProperties.new(50, 0, 0, 0, 0)
	comPart.CFrame = root.CFrame * CFrame.new(offset)
	comPart.Parent = body

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = comPart
	weld.Parent = comPart
end

local function castAndComputeSuspension(wheel: WheelData, dt: number): (number, boolean, Vector3, number)
	local worldOffset = root.CFrame:PointToWorldSpace(wheel.def.suspensionOffset)
	local effectiveRestLength = config.suspensionRestLength + wheel.hydraulicOffset
	local rayLength = effectiveRestLength + config.wheelRadius + config.suspensionMaxTravel

	local result = workspace:Raycast(worldOffset, -Vector3.yAxis * rayLength, rayParams)

	local suspInput: ChassisPhysics.SuspensionInput = {
		hitDistance = if result then (worldOffset - result.Position).Magnitude else nil,
		hitNormal = if result then result.Normal else nil,
		rayOrigin = worldOffset,
		rayLength = rayLength,
		lastSuspensionLength = wheel.lastSuspensionLength,
		hydraulicOffset = wheel.hydraulicOffset,
	}

	local suspResult = ChassisPhysics.computeSuspension(
		suspInput, config, #wheels, root.AssemblyMass, workspace.Gravity, dt
	)

	wheel.lastSuspensionLength = suspResult.springLength
	wheel.groundHit = suspResult.onGround
	wheel.contactNormal = if result then result.Normal else Vector3.yAxis
	wheel.suspensionForce = suspResult.force

	return suspResult.force, suspResult.onGround, if result then result.Position else suspResult.contactPosition, suspResult.springLength
end

local function setWheelCFrame(wheel: WheelData, cf: CFrame)
	wheel.part.CFrame = cf
	for _, child in wheel.part:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame = cf
		end
	end
end

local function positionWheel(wheel: WheelData, rootCF: CFrame, upDir: Vector3, contactPos: Vector3?, onGround: boolean)
	local cf = ChassisPhysics.computeWheelCFrame({
		onGround = onGround and contactPos ~= nil,
		contactPosition = contactPos or Vector3.zero,
		suspensionOffset = wheel.def.suspensionOffset,
		isSteered = wheel.def.isSteered,
		steerAngle = currentSteerAngle,
		visualAngle = wheel.visualAngle,
	}, rootCF, upDir, config)
	setWheelCFrame(wheel, cf)
end

local function serverIdleStep(dt: number)
	if isDriverSeated or dt <= 0 or dt > 0.5 then return end
	if root.AssemblyMass <= 0 then return end

	local rootCF = root.CFrame
	local upDir = rootCF.UpVector

	for _, wheel in wheels do
		local suspForce, onGround, contactPos, springLen = castAndComputeSuspension(wheel, dt)

		if onGround then
			local attachPoint = rootCF:PointToWorldSpace(wheel.def.suspensionOffset)
			root:ApplyImpulseAtPosition(Vector3.yAxis * suspForce * dt, attachPoint)
		end

		positionWheel(wheel, rootCF, upDir, contactPos, onGround)
	end

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
end

local function startServerPhysics()
	if serverPhysicsConnection then return end
	serverPhysicsConnection = RunService.Heartbeat:Connect(serverIdleStep)
end

local function stopServerPhysics()
	if serverPhysicsConnection then
		serverPhysicsConnection:Disconnect()
		serverPhysicsConnection = nil
	end
end

local function onOccupantChanged()
	local humanoid = driverSeat.Occupant
	if humanoid then
		local character = humanoid.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			isDriverSeated = true
			currentDriver = player

			stopServerPhysics()

			root:SetNetworkOwner(player)

			for _, wheel in wheels do
				wheel.part.Anchored = false
				wheel.part.Massless = true
				pcall(function() wheel.part:SetNetworkOwner(player) end)
			end

			local startEvent = vehicleModel:FindFirstChild("StartChassis")
			if startEvent and startEvent:IsA("RemoteEvent") then
				startEvent:FireClient(player, config, driveState.currentGear, driveState.currentRPM)
			end
		end
	else
		local prevDriver = currentDriver
		isDriverSeated = false
		currentDriver = nil

		for _, wheel in wheels do
			wheel.part.Anchored = true
			wheel.part.Massless = false
		end

		pcall(function() root:SetNetworkOwner(nil) end)

		if prevDriver then
			local stopEvent = vehicleModel:FindFirstChild("StopChassis")
			if stopEvent and stopEvent:IsA("RemoteEvent") then
				stopEvent:FireClient(prevDriver)
			end
		end

		startServerPhysics()
	end
end

local function setupRemotes()
	local startEvent = Instance.new("RemoteEvent")
	startEvent.Name = "StartChassis"
	startEvent.Parent = vehicleModel

	local stopEvent = Instance.new("RemoteEvent")
	stopEvent.Name = "StopChassis"
	stopEvent.Parent = vehicleModel

	local stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "ChassisState"
	stateEvent.Parent = vehicleModel

	local hydSyncEvent = Instance.new("RemoteEvent")
	hydSyncEvent.Name = "HydraulicSync"
	hydSyncEvent.Parent = vehicleModel
	hydSyncEvent.OnServerEvent:Connect(function(player, offsets)
		if player ~= currentDriver then return end
		if typeof(offsets) ~= "table" then return end
		for i, wheel in wheels do
			local val = offsets[i]
			if typeof(val) == "number" then
				wheel.hydraulicOffset = math.clamp(val, -config.hydraulicMaxLift, config.hydraulicMaxLift)
			end
		end
	end)
end

-- Initialize: keep root anchored until first physics frame
weldModel(body)
applyCenterOfMass()
setupRemotes()

for _, wheel in wheels do
	wheel.part.Anchored = true
	wheel.part.CanCollide = false
	for _, child in wheel.part:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
		end
	end
end

driverSeat.CanCollide = false
root.CanCollide = false

driverSeat:GetPropertyChangedSignal("Occupant"):Connect(onOccupantChanged)

local prompt = driverSeat:FindFirstChildOfClass("ProximityPrompt")
if prompt then
	prompt.Triggered:Connect(function(player)
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and not driverSeat.Occupant then
				driverSeat:Sit(hum)
			end
		end
	end)
end

local firstFrame = true
local originalIdleStep = serverIdleStep
serverIdleStep = function(dt: number)
	if firstFrame then
		firstFrame = false
		root.Anchored = false
		driverSeat.Anchored = false
	end
	originalIdleStep(dt)
end

startServerPhysics()
print("[Chassis] Server initialized, idle suspension running")
