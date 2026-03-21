--!strict
--[[
	Client-side driving controller.
	
	The car drives forward AUTOMATICALLY along -Z (the highway direction).
	The player can only steer left/right. When gas runs out, the server ends
	the run. When the car reaches the highway end, it laps.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))

local VFXController: any = nil

local DrivingController = {}

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")

local isRunning = false
local runInfo: any = nil
local carModel: Model? = nil

local startZ = 0
local centerX = 0
local lateralX = 0
local currentSpeed = 0
local currentGas = 0
local totalDistance = 0
local currentLapDistance = 0
local laps = 0
local steerInput = 0

local LANE_WIDTH = 20
local STEER_SPEED = 40
local steeringSensitivity = 1
local autoDriveAssist = false
local CAMERA_OFFSET = Vector3.new(0, 8, 18)
local CAMERA_LOOK_AHEAD = 30

local touchStartX: number? = nil

local WHEEL_NAMES = {"FL", "FR", "RL", "RR"}

local function getWheelSpinAxis(wheel: BasePart): string
	local s = wheel.Size
	if s.X <= s.Y and s.X <= s.Z then return "X"
	elseif s.Y <= s.X and s.Y <= s.Z then return "Y"
	else return "Z" end
end

local function getWheelRadius(wheel: BasePart): number
	local s = wheel.Size
	if s.X <= s.Y and s.X <= s.Z then return math.max(s.Y, s.Z) / 2
	elseif s.Y <= s.X and s.Y <= s.Z then return math.max(s.X, s.Z) / 2
	else return math.max(s.X, s.Y) / 2 end
end

local function spinWheels(dt: number)
	if not carModel then return end
	local firstWheel: BasePart? = nil
	for _, name in WHEEL_NAMES do
		local w = carModel:FindFirstChild(name)
		if w and w:IsA("BasePart") then
			firstWheel = w
			break
		end
	end
	if not firstWheel then return end

	local radius = math.max(getWheelRadius(firstWheel), 0.1)
	local angularDelta = (currentSpeed * dt) / radius
	local axis = getWheelSpinAxis(firstWheel)

	for _, name in WHEEL_NAMES do
		local wheel = carModel:FindFirstChild(name)
		if wheel and wheel:IsA("BasePart") then
			if axis == "X" then
				wheel.CFrame *= CFrame.Angles(-angularDelta, 0, 0)
			elseif axis == "Y" then
				wheel.CFrame *= CFrame.Angles(0, -angularDelta, 0)
			else
				wheel.CFrame *= CFrame.Angles(0, 0, -angularDelta)
			end
		end
	end
end

local function handleInput(_dt: number)
	steerInput = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		steerInput -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		steerInput += 1
	end
end

local function onTouchBegan(input: InputObject, _gameProcessed: boolean)
	if not isRunning then return end
	if input.UserInputType == Enum.UserInputType.Touch then
		touchStartX = input.Position.X
	end
end

local function onTouchChanged(input: InputObject, _gameProcessed: boolean)
	if not isRunning or not touchStartX then return end
	if input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position.X - touchStartX
		local screenWidth = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1920
		steerInput = math.clamp(delta / (screenWidth * 0.15), -1, 1)
	end
end

local function onTouchEnded(input: InputObject, _gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchStartX = nil
		steerInput = 0
	end
end

function DrivingController.setFromSettings(settings: any)
	if type(settings) == "table" and type(settings.steeringSensitivity) == "number" then
		steeringSensitivity = math.clamp(settings.steeringSensitivity, 0.5, 2)
	end
end

function DrivingController.setPassFlags(flags: { [string]: boolean }?)
	if not flags then
		return
	end
	autoDriveAssist = flags.auto_drive == true
end

local function updateDriving(dt: number)
	if not isRunning or not runInfo then return end

	handleInput(dt)

	if autoDriveAssist then
		local s = if lateralX > 0.01 then 1 elseif lateralX < -0.01 then -1 else 0
		steerInput = math.clamp(steerInput - s * 1.2 * dt, -1, 1)
	end

	local forwardDelta = currentSpeed * dt
	totalDistance += forwardDelta
	currentLapDistance += forwardDelta

	currentGas -= Constants.GAS_DRAIN_RATE * dt

	local highwayLength = runInfo.highwayLength or 5000
	if currentLapDistance >= highwayLength then
		laps += 1
		currentLapDistance -= highwayLength
	end

	lateralX += steerInput * STEER_SPEED * steeringSensitivity * dt
	lateralX = math.clamp(lateralX, -LANE_WIDTH, LANE_WIDTH)

	local posX = centerX + lateralX
	local posZ = startZ - currentLapDistance

	if carModel and carModel.PrimaryPart then
		local targetCF = CFrame.new(posX, carModel.PrimaryPart.Position.Y, posZ)
		carModel:PivotTo(targetCF)
		spinWheels(dt)
	end

	local camera = workspace.CurrentCamera
	if camera and carModel and carModel.PrimaryPart then
		local carPos = carModel.PrimaryPart.Position
		local cameraPos = carPos + CAMERA_OFFSET
		local lookAt = carPos + Vector3.new(0, 2, -CAMERA_LOOK_AHEAD)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(cameraPos, lookAt)
	end

	if VFXController and VFXController.speedTrail then
		VFXController.speedTrail(currentSpeed)
	end
end

function DrivingController.startRun(info: any)
	if not VFXController then
		pcall(function()
			VFXController = require(playerScripts:WaitForChild("DAC"):WaitForChild("Controllers"):WaitForChild("VFXController"))
		end)
	end

	runInfo = info
	isRunning = true
	currentSpeed = info.stats.speed
	currentGas = info.stats.gas
	totalDistance = 0
	currentLapDistance = 0
	laps = 0
	steerInput = 0
	lateralX = 0

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			startZ = root.Position.Z
			centerX = root.Position.X
		end
		carModel = character:FindFirstChild("Car") :: Model?
		if not carModel then
			local added = character:WaitForChild("Car", 5)
			if added and added:IsA("Model") then
				carModel = added
			end
		end
	end
end

function DrivingController.endRun(_results: any)
	isRunning = false
	runInfo = nil
	carModel = nil

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

function DrivingController.onRunUpdate(update: any)
	if update.type == "lap" then
		laps = update.laps
		totalDistance = update.totalDistance
		currentGas = update.gasRemaining
		local isPb = if type(update.isPersonalBest) == "boolean" then update.isPersonalBest else false
		if VFXController and VFXController.lapFlash then
			VFXController.lapFlash(isPb)
		end
	end
end

function DrivingController.isInRun(): boolean
	return isRunning
end

function DrivingController.getRunState(): { distance: number, gas: number, speed: number, laps: number }
	return {
		distance = totalDistance,
		gas = currentGas,
		speed = currentSpeed,
		laps = laps,
	}
end

function DrivingController.init()
	task.defer(function()
		local ok, flags = pcall(function()
			return Remotes.getFunction("GetPassFlags"):InvokeServer()
		end)
		if ok and type(flags) == "table" then
			DrivingController.setPassFlags(flags :: any)
		end
	end)

	RunService.RenderStepped:Connect(updateDriving)

	UserInputService.TouchStarted:Connect(onTouchBegan)
	UserInputService.TouchMoved:Connect(onTouchChanged)
	UserInputService.TouchEnded:Connect(onTouchEnded)
end

return DrivingController
