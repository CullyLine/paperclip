--[[
	ChassisClient — Client-side raycast chassis for Downhill Madness.

	Sits in StarterPlayerScripts. Detects when the local player sits
	in a vehicle, takes over physics via Heartbeat, and stops when
	they stand up.

	Uses DownhillConfig + DownhillPhysics (no Drivetrain, no LiveValues).
	All 4 wheels are driven (AWD). Simple flat drive force model.

	Visual wheels are separate Anchored parts living outside the vehicle
	assembly. Positioned on RenderStepped (not Heartbeat) so they always
	read the latest chassis CFrame right before the frame renders.
	No welds, no constraints, no physics — zero jitter.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local InputManager = require(script.Parent:WaitForChild("InputManager"))

local DMRep = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local DownhillConfig = require(DMRep:WaitForChild("DownhillConfig"))
local DownhillPhysics = require(DMRep:WaitForChild("DownhillPhysics"))

local input: any = nil
local vehicleModel: Model = nil
local cfg: any = nil
local root: BasePart = nil
local wheelsFolder: Model = nil

type WheelData = {
	part: BasePart,
	visual: BasePart,
	def: any,
	lastSpringLen: number,
	spinAngle: number,
	groundHit: boolean,
	suspForce: number,
	surfaceMaterial: Enum.Material?,
}

local wheels: { WheelData } = {}
local visualWheelFolder: Folder = nil
local rayParams: RaycastParams = nil
local currentSteerAngle = 0
local physicsConn: RBXScriptConnection? = nil
local vehicleDestroyConn: RBXScriptConnection? = nil
local isActive = false
local savedGravity: number = 196.2

local DEBUG_ENABLED = true
local debugTimer = 0
local DEBUG_INTERVAL = 0.5

----------------------------------------------------------------
-- Visual wheel creation / destruction
----------------------------------------------------------------

local function createVisualWheel(templatePart: BasePart): BasePart
	local vis = templatePart:Clone()
	vis.Name = templatePart.Name .. "_Visual"
	vis.Transparency = 0
	vis.Anchored = true
	vis.CanCollide = false
	vis.CanQuery = false
	vis.Massless = true

	for _, child in vis:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			child:Destroy()
		end
	end

	vis.Parent = visualWheelFolder
	return vis
end

local function destroyVisualWheels()
	if visualWheelFolder then
		visualWheelFolder:Destroy()
		visualWheelFolder = nil
	end
end

----------------------------------------------------------------
-- Wheel building
----------------------------------------------------------------

local function buildWheels()
	wheels = {}

	destroyVisualWheels()
	visualWheelFolder = Instance.new("Folder")
	visualWheelFolder.Name = "VisualWheels_" .. player.Name
	visualWheelFolder.Parent = workspace

	for _, def in cfg.wheels do
		local part = wheelsFolder:FindFirstChild(def.name)
			or wheelsFolder:WaitForChild(def.name, 5)
		if not part then
			warn("[ChassisClient] Wheel missing: " .. def.name)
			continue
		end

		local visual = createVisualWheel(part)

		table.insert(wheels, {
			part = part,
			visual = visual,
			def = def,
			lastSpringLen = cfg.suspRestLength,
			spinAngle = 0,
			groundHit = false,
			suspForce = 0,
			surfaceMaterial = nil,
		})
	end
end

local function resolveRoot(vModel: Model): BasePart?
	local body = vModel:FindFirstChild("Body")
	if body then
		local ch = body:FindFirstChild("Chassis") or body.PrimaryPart
		if ch then return ch end
		for _, c in body:GetChildren() do
			if c:IsA("BasePart") then return c end
		end
	end
	return vModel.PrimaryPart
end

----------------------------------------------------------------
-- Debug helper
----------------------------------------------------------------

local function vec3str(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

----------------------------------------------------------------
-- Visual wheel positioning — called at the end of physicsStep
-- with a FRESH root.CFrame read (not the stale one from the top
-- of the function). Runs on Heartbeat in the same frame as
-- the physics so there's zero lag.
----------------------------------------------------------------

local function updateVisualWheels()
	if not root or not root.Parent then return end

	local freshCF = root.CFrame
	local bodyRot = freshCF - freshCF.Position

	for _, wheel in wheels do
		if not wheel.visual or not wheel.visual.Parent then continue end

		local mountWorld = freshCF:PointToWorldSpace(wheel.def.offset)
		local visualPos = mountWorld + Vector3.new(0, -wheel.lastSpringLen, 0)

		local cf = CFrame.new(visualPos) * bodyRot

		if wheel.def.isSteered then
			cf = cf * CFrame.Angles(0, math.rad(currentSteerAngle), 0)
		end

		cf = cf * CFrame.Angles(math.rad(wheel.spinAngle), 0, 0)

		wheel.visual.CFrame = cf
	end
end

----------------------------------------------------------------
-- Physics step (Heartbeat — after physics sim)
----------------------------------------------------------------

local function physicsStep(dt: number)
	if not isActive or not root or dt <= 0 or dt > 0.5 then return end
	if root.Anchored then return end

	local state = input:getState()
	local throttle = state.throttle
	local steer = -state.steer
	local handbrake = state.handbrake

	local rootCF = root.CFrame
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local forwardSpeed = velocity:Dot(rootCF.LookVector)
	local mass = root.AssemblyMass
	if mass <= 0 then return end

	-- Counter-steer assist
	local lateralVel = velocity:Dot(rootCF.RightVector)
	if math.abs(forwardSpeed) > 5 and math.abs(lateralVel) > 2 then
		local slide = lateralVel / math.max(math.abs(forwardSpeed), 1)
		steer = math.clamp(steer + slide * cfg.counterSteerFactor, -1, 1)
	end

	currentSteerAngle = DownhillPhysics.steerAngle(currentSteerAngle, steer, speed, cfg, dt)

	-- Per-wheel suspension + lateral grip
	local groundedCount = 0

	-- Debug throttle
	local shouldDebug = false
	if DEBUG_ENABLED then
		debugTimer += dt
		if debugTimer >= DEBUG_INTERVAL then
			debugTimer = 0
			shouldDebug = true
		end
	end

	if shouldDebug then
		print("===== [ChassisDebug] =====")
		print(string.format("  Root pos: %s  vel: %s  speed: %.1f  fwdSpd: %.1f",
			vec3str(rootCF.Position), vec3str(velocity), speed, forwardSpeed))
		print(string.format("  Mass: %.1f  Gravity: %.1f  SteerAngle: %.1f",
			mass, workspace.Gravity, currentSteerAngle))
	end

	for i, wheel in wheels do
		local worldOffset = rootCF:PointToWorldSpace(wheel.def.offset)
		local rayLen = cfg.suspRestLength + cfg.wheelRadius + cfg.suspMaxTravel

		local hit = workspace:Raycast(worldOffset, -Vector3.yAxis * rayLen, rayParams)
		local hitDist: number? = if hit then (worldOffset - hit.Position).Magnitude else nil

		local susp = DownhillPhysics.suspension(
			hitDist, worldOffset, rayLen,
			wheel.lastSpringLen, cfg, #wheels, mass, workspace.Gravity, dt
		)

		wheel.lastSpringLen = susp.springLength
		wheel.groundHit = susp.onGround
		wheel.suspForce = susp.force

		if shouldDebug then
			local mountWorld = rootCF:PointToWorldSpace(wheel.def.offset)
			local logicalPos = mountWorld + Vector3.new(0, -susp.springLength, 0)
			local visualPos = if wheel.visual and wheel.visual.Parent
				then wheel.visual.Position
				else Vector3.zero

			print(string.format("  [%s] grounded=%s  hitDist=%s  springLen=%.3f  suspForce=%.0f",
				wheel.def.name,
				tostring(susp.onGround),
				if hitDist then string.format("%.3f", hitDist) else "nil",
				susp.springLength,
				susp.force
			))
			print(string.format("       mount=%s  logical=%s  visual=%s  delta=%.4f",
				vec3str(mountWorld),
				vec3str(logicalPos),
				vec3str(visualPos),
				(logicalPos - visualPos).Magnitude
			))
		end

		wheel.surfaceMaterial = if hit then hit.Material else nil

		if susp.onGround then
			groundedCount += 1
			local attachPt = rootCF:PointToWorldSpace(wheel.def.offset)

			root:ApplyImpulseAtPosition(Vector3.yAxis * susp.force * dt, attachPt)

			local wheelCF = rootCF * CFrame.new(wheel.def.offset)
			if wheel.def.isSteered then
				wheelCF = wheelCF * CFrame.Angles(0, math.rad(currentSteerAngle), 0)
			end
			local wheelRight = wheelCF.RightVector
			local wheelFwd = wheelCF.LookVector

			local ptVel = root:GetVelocityAtPosition(attachPt)
			local latSpeed = ptVel:Dot(wheelRight)
			local lonSpeed = ptVel:Dot(wheelFwd)

			local surfFric = 1.0
			if hit then
				surfFric = DownhillConfig.getSurfaceFriction(cfg, hit.Material)
			end

			local gripMul = if wheel.def.isSteered then cfg.lateralGripFront else cfg.lateralGrip
			local latForce = DownhillPhysics.lateralForce(
				latSpeed, lonSpeed, susp.force, gripMul, cfg, surfFric
			)
			if handbrake > 0.5 and not wheel.def.isSteered then
				latForce = latForce * cfg.handbrakeGripFactor
			end
			root:ApplyImpulseAtPosition(wheelRight * latForce * dt, attachPt)

			local atLimit = math.abs(forwardSpeed) > cfg.maxSpeed
			if not atLimit then
				if math.abs(throttle) > 0.05 then
					local force = if throttle > 0 then cfg.driveForce else cfg.reverseForce
					local perWheel = force * math.abs(throttle) * surfFric / #wheels
					local dir = if throttle > 0 then wheelFwd else -wheelFwd
					root:ApplyImpulseAtPosition(dir * perWheel * dt, attachPt)
				end
			end

			if (throttle > 0.1 and forwardSpeed < -2) or (throttle < -0.1 and forwardSpeed > 2) then
				local brakeMag = cfg.brakeForce * math.abs(throttle) * 0.7 / #wheels
				local brakeDir = if ptVel.Magnitude > 1 then -ptVel.Unit else Vector3.zero
				root:ApplyImpulseAtPosition(brakeDir * brakeMag * dt, attachPt)
			end

			if math.abs(throttle) < 0.05 and math.abs(lonSpeed) > 1 then
				local ebForce = cfg.engineBraking * susp.force
				local ebDir = -wheelFwd * (if lonSpeed > 0 then 1 else -1)
				root:ApplyImpulseAtPosition(ebDir * ebForce * dt, attachPt)
			end

			if handbrake > 0.5 and not wheel.def.isSteered then
				local hbMag = cfg.brakeForce * 0.6 / 2
				local hbDir = if ptVel.Magnitude > 1 then -ptVel.Unit else Vector3.zero
				root:ApplyImpulseAtPosition(hbDir * hbMag * dt, attachPt)
			end

			local spinRate = lonSpeed / math.max(cfg.wheelRadius, 0.1)
			wheel.spinAngle += math.deg(spinRate * dt)
		else
			wheel.spinAngle = wheel.spinAngle * (1 - dt * 2)
		end
	end

	if #wheels >= 4 then
		local flAR, frAR = DownhillPhysics.antiRoll(
			wheels[1].groundHit, wheels[2].groundHit,
			wheels[1].lastSpringLen, wheels[2].lastSpringLen,
			cfg.antiRollStiffness
		)
		if flAR ~= 0 then
			root:ApplyImpulseAtPosition(Vector3.yAxis * flAR * dt, rootCF:PointToWorldSpace(wheels[1].def.offset))
			root:ApplyImpulseAtPosition(Vector3.yAxis * frAR * dt, rootCF:PointToWorldSpace(wheels[2].def.offset))
		end

		local rlAR, rrAR = DownhillPhysics.antiRoll(
			wheels[3].groundHit, wheels[4].groundHit,
			wheels[3].lastSpringLen, wheels[4].lastSpringLen,
			cfg.antiRollStiffness
		)
		if rlAR ~= 0 then
			root:ApplyImpulseAtPosition(Vector3.yAxis * rlAR * dt, rootCF:PointToWorldSpace(wheels[3].def.offset))
			root:ApplyImpulseAtPosition(Vector3.yAxis * rrAR * dt, rootCF:PointToWorldSpace(wheels[4].def.offset))
		end
	end

	if groundedCount == 0 then
		local airImpulse = DownhillPhysics.airControl(
			steer, throttle, root.AssemblyAngularVelocity, rootCF, cfg, dt
		)
		root:ApplyImpulseAtPosition(airImpulse, rootCF.Position)
	end

	local df = DownhillPhysics.downforce(speed, cfg.downforceCoeff, dt)
	if df.Magnitude > 0 then
		local maxDF = mass * workspace.Gravity * dt * 0.12
		if df.Magnitude > maxDF then
			df = df.Unit * maxDF
		end
		root:ApplyImpulseAtPosition(df, rootCF.Position)
	end

	local dragImp = DownhillPhysics.drag(velocity, speed, cfg.dragCoeff, dt)
	if dragImp.Magnitude > 0 then
		root:ApplyImpulseAtPosition(dragImp, rootCF.Position)
	end

	root.AssemblyAngularVelocity = DownhillPhysics.angularDamp(
		root.AssemblyAngularVelocity, cfg.angularDamping, dt
	)

	if shouldDebug then
		print(string.format("  Grounded: %d/%d", groundedCount, #wheels))
		print("=========================")
	end

	-- Position visual wheels using a FRESH CFrame read (after all impulses)
	updateVisualWheels()
end

----------------------------------------------------------------
-- Start / Stop driving
----------------------------------------------------------------

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

local stopDriving -- forward declaration, assigned below startDriving

local function startDriving(vModel: Model)
	if isActive then
		stopDriving()
	end

	vehicleModel = vModel
	root = resolveRoot(vModel)
	if not root then
		warn("[ChassisClient] No root part found")
		return
	end

	wheelsFolder = vModel:FindFirstChild("Wheels")
	if not wheelsFolder then
		warn("[ChassisClient] No Wheels model found")
		return
	end

	local vehicleId = vModel:GetAttribute("VehicleId") or "all_rounder"
	cfg = DownhillConfig.forVehicle(vehicleId)

	savedGravity = workspace.Gravity
	workspace.Gravity = cfg.gravity

	if player.Character then
		for _, desc in player.Character:GetDescendants() do
			if desc:IsA("BasePart") then desc.CanQuery = false end
		end
	end

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicleModel }
	if player.Character then
		table.insert(rayParams.FilterDescendantsInstances, player.Character)
	end

	buildWheels()

	if visualWheelFolder then
		table.insert(rayParams.FilterDescendantsInstances, visualWheelFolder)
	end

	input = InputManager.new()
	currentSteerAngle = 0
	debugTimer = 0
	isActive = true

	physicsConn = RunService.Heartbeat:Connect(physicsStep)

	-- Auto-cleanup if the vehicle is destroyed (e.g. round ends, server calls cleanup)
	vehicleDestroyConn = root.AncestryChanged:Connect(function(_, newParent)
		if isActive and (not newParent or not root:IsDescendantOf(workspace)) then
			stopDriving()
		end
	end)
end

stopDriving = function()
	isActive = false
	if physicsConn then
		physicsConn:Disconnect()
		physicsConn = nil
	end
	if vehicleDestroyConn then
		vehicleDestroyConn:Disconnect()
		vehicleDestroyConn = nil
	end
	if input then
		input:destroy()
		input = nil
	end

	destroyVisualWheels()
	wheels = {}

	if player.Character then
		for _, desc in player.Character:GetDescendants() do
			if desc:IsA("BasePart") then desc.CanQuery = true end
		end
	end

	workspace.Gravity = savedGravity

	vehicleModel = nil
	cfg = nil
	root = nil
	wheelsFolder = nil
	currentSteerAngle = 0
end

----------------------------------------------------------------
-- Seat detection
----------------------------------------------------------------

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
