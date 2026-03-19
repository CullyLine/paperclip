--[[
	CameraController — Custom chase camera for Downhill Madness.

	Features:
	  - Smooth chase cam behind the vehicle with velocity look-ahead
	  - Speed-dependent FOV (70 → 85)
	  - Impact shake on sudden deceleration
	  - Rear-view (hold C or mobile button)
	  - Free-look (hold right mouse button to orbit, release snaps back)

	Activates when ChassisClient reports driving, deactivates on stop.
	Respects Hub camera state (doesn't fight HubController).
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ChassisClient = require(script.Parent:WaitForChild("ChassisClient"))

----------------------------------------------------------------
-- Config
----------------------------------------------------------------

local CHASE_DISTANCE = 22
local CHASE_HEIGHT = 10
local LOOK_AHEAD_FACTOR = 0.12
local FOLLOW_SPEED = 6.0
local ROTATION_SPEED = 4.0

local BASE_FOV = 70
local MAX_FOV = 85
local FOV_SPEED_THRESHOLD = 30
local FOV_LERP_SPEED = 3.0

local SHAKE_DECEL_THRESHOLD = 40
local SHAKE_MAX_INTENSITY = 1.5
local SHAKE_DECAY = 8.0

local REAR_VIEW_YAW = math.pi

local FREE_LOOK_SENSITIVITY = 0.005

----------------------------------------------------------------
-- State
----------------------------------------------------------------

local camera = workspace.CurrentCamera
local isActive = false
local renderConn: RBXScriptConnection? = nil

local currentOffset = Vector3.new(0, CHASE_HEIGHT, CHASE_DISTANCE)
local currentFOV = BASE_FOV
local shakeIntensity = 0
local lastSpeed = 0

local isRearView = false
local isFreeLook = false
local freeLookYaw = 0
local freeLookPitch = 0

local keysHeld: { [Enum.KeyCode]: boolean } = {}
local mouseDown = false

local connections: { RBXScriptConnection } = {}

local IS_TOUCH = UserInputService.TouchEnabled

local mobileGui: ScreenGui? = nil
local rearViewTouchHeld = false

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

local function bindInput()
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode then
			keysHeld[input.KeyCode] = true
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			mouseDown = true
			isFreeLook = true
			freeLookYaw = 0
			freeLookPitch = 0
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input, _processed)
		if input.KeyCode then
			keysHeld[input.KeyCode] = nil
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			mouseDown = false
			isFreeLook = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input, processed)
		if processed then return end
		if isFreeLook and input.UserInputType == Enum.UserInputType.MouseMovement then
			freeLookYaw -= input.Delta.X * FREE_LOOK_SENSITIVITY
			freeLookPitch = math.clamp(
				freeLookPitch - input.Delta.Y * FREE_LOOK_SENSITIVITY,
				-math.pi / 3, math.pi / 4
			)
		end
	end))
end

local function createMobileRearViewButton()
	if not IS_TOUCH then return end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraControls"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 101
	gui.Parent = playerGui
	mobileGui = gui

	local btn = Instance.new("TextButton")
	btn.Name = "RearView"
	btn.Text = "👁"
	btn.Position = UDim2.new(0, 250, 1, -20)
	btn.Size = UDim2.new(0, 70, 0, 70)
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	btn.BackgroundTransparency = 0.3
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 28
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 70)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.5
	stroke.Parent = btn

	local activeTouches = 0

	table.insert(connections, btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeTouches += 1
			rearViewTouchHeld = true
			btn.BackgroundTransparency = 0.1
			stroke.Color = Color3.fromRGB(0, 180, 255)
		end
	end))

	table.insert(connections, btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeTouches = math.max(activeTouches - 1, 0)
			if activeTouches == 0 then
				rearViewTouchHeld = false
				btn.BackgroundTransparency = 0.3
				stroke.Color = Color3.fromRGB(60, 60, 70)
			end
		end
	end))
end

local function destroyMobileControls()
	if mobileGui then
		mobileGui:Destroy()
		mobileGui = nil
	end
	rearViewTouchHeld = false
end

local function unbindInput()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(keysHeld)
	mouseDown = false
	isFreeLook = false
	isRearView = false
	pcall(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
	destroyMobileControls()
end

----------------------------------------------------------------
-- Camera update
----------------------------------------------------------------

local function updateCamera(dt: number)
	if not isActive then return end

	local rootPart = ChassisClient.getRootPart()
	if not rootPart or not rootPart.Parent then return end

	camera.CameraType = Enum.CameraType.Scriptable

	local rootCF = rootPart.CFrame
	local velocity = ChassisClient.getVelocity()
	local speed = velocity.Magnitude

	-- Impact shake detection
	local decel = lastSpeed - speed
	if decel > SHAKE_DECEL_THRESHOLD then
		local newShake = math.clamp(decel / 80, 0, 1) * SHAKE_MAX_INTENSITY
		shakeIntensity = math.max(shakeIntensity, newShake)
	end
	lastSpeed = speed

	-- Decay shake
	shakeIntensity = math.max(shakeIntensity - SHAKE_DECAY * dt, 0)

	-- Rear-view state
	isRearView = keysHeld[Enum.KeyCode.C] == true or rearViewTouchHeld

	-- Compute desired camera position
	local lookDir = rootCF.LookVector
	if speed > 5 then
		local velDir = velocity.Unit
		lookDir = (lookDir + velDir * LOOK_AHEAD_FACTOR).Unit
	end

	local yawAngle = 0
	local pitchAngle = 0

	if isFreeLook then
		yawAngle = freeLookYaw
		pitchAngle = freeLookPitch
	elseif isRearView then
		yawAngle = REAR_VIEW_YAW
	end

	local behindDir = -lookDir
	local rotatedDir = CFrame.Angles(0, yawAngle, 0) * CFrame.new(behindDir * CHASE_DISTANCE)
	local desiredPos = rootCF.Position
		+ rotatedDir.Position
		+ Vector3.new(0, CHASE_HEIGHT, 0)

	if isFreeLook then
		desiredPos = desiredPos + Vector3.new(0, math.sin(pitchAngle) * CHASE_DISTANCE * 0.5, 0)
	end

	-- Smooth follow
	local camPos = camera.CFrame.Position
	local followAlpha = math.clamp(FOLLOW_SPEED * dt, 0, 1)
	local newPos = camPos:Lerp(desiredPos, followAlpha)

	-- Look target (slightly ahead of vehicle)
	local lookTarget = rootCF.Position + lookDir * 10
	if isRearView then
		lookTarget = rootCF.Position + rootCF.LookVector * -10
	elseif isFreeLook then
		lookTarget = rootCF.Position
	end

	local rotAlpha = math.clamp(ROTATION_SPEED * dt, 0, 1)
	local currentLook = camera.CFrame.LookVector
	local desiredLook = (lookTarget - newPos).Unit
	local blendedLook = currentLook:Lerp(desiredLook, rotAlpha)

	local newCF = CFrame.lookAt(newPos, newPos + blendedLook)

	-- Apply shake
	if shakeIntensity > 0.01 then
		local shakeX = (math.random() - 0.5) * 2 * shakeIntensity
		local shakeY = (math.random() - 0.5) * 2 * shakeIntensity
		newCF = newCF * CFrame.Angles(math.rad(shakeX), math.rad(shakeY), 0)
	end

	camera.CFrame = newCF

	-- Speed FOV
	local speedFraction = math.clamp((speed - FOV_SPEED_THRESHOLD) / (300 - FOV_SPEED_THRESHOLD), 0, 1)
	local targetFOV = BASE_FOV + (MAX_FOV - BASE_FOV) * speedFraction
	currentFOV = currentFOV + (targetFOV - currentFOV) * math.clamp(FOV_LERP_SPEED * dt, 0, 1)
	camera.FieldOfView = currentFOV
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------

local function activate()
	if isActive then return end
	isActive = true
	lastSpeed = 0
	shakeIntensity = 0
	currentFOV = BASE_FOV
	freeLookYaw = 0
	freeLookPitch = 0

	bindInput()
	createMobileRearViewButton()

	renderConn = RunService.RenderStepped:Connect(updateCamera)
end

local function deactivate()
	if not isActive then return end
	isActive = false

	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end

	unbindInput()

	camera.FieldOfView = BASE_FOV
	camera.CameraType = Enum.CameraType.Custom
end

----------------------------------------------------------------
-- Watch ChassisClient state changes via polling
-- (lightweight: checks once per Heartbeat)
----------------------------------------------------------------

local wasDriving = false

RunService.Heartbeat:Connect(function()
	local driving = ChassisClient.isDriving()
	if driving and not wasDriving then
		activate()
	elseif not driving and wasDriving then
		deactivate()
	end
	wasDriving = driving
end)

return true
