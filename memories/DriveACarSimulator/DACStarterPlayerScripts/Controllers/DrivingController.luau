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
local NearMissCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("NearMissCopyConfig"))
local SpeedTierCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedTierCopyConfig"))
local ComboCelebrationConfig = require(DAC:WaitForChild("Config"):WaitForChild("ComboCelebrationConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local VFXController = require(script.Parent:WaitForChild("VFXController"))

local DrivingController = {}

local player = Players.LocalPlayer

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
local NEAR_EDGE_STUDS = 2 -- lateral distance from lane boundary to trigger near-miss VFX
local STEER_SPEED = 40
local steeringSensitivity = 1
local autoDriveAssist = false
local doubleSpeedPass = false
local runMaxSpeedForRush = 100
local lastBoostSfxClock = 0.0
local BOOST_SFX_INTERVAL = 2.8
local previousSpeed = 0
local lastAccelCalloutClock = 0.0
local ACCEL_CALLOUT_COOLDOWN = 3.0
local accelSpeedSamples: { { t: number, s: number } } = {}
local accelCalloutQueue: { string } = {}
local CAMERA_OFFSET = Vector3.new(0, 8, 18)
local CAMERA_LOOK_AHEAD = 30

local touchStartX: number? = nil
local wasNearLaneEdge = false
local lastNearMissEnterClock = 0.0
local nearMissStreak = 0
local lastNearMissStreakAt = 0.0
local nearMissHudQueue: { string } = {}
local comboCelebrationHudQueue: { { headline: string, body: string, comboCount: number? } } = {}
local comboBreakHudQueue: { { headline: string, body: string } } = {}
local nearMissGrantChainTotal = 0
local maxNearMissStreakThisRun = 0

local NEAR_MISS_STREAK_RESET_SEC = 3.0

local function pickNearMissPopupText(streak: number): string
	if streak >= 2 and #NearMissCopyConfig.StreakHeadlines > 0 then
		local idx = math.clamp(streak - 1, 1, #NearMissCopyConfig.StreakHeadlines)
		if streak >= 3 and math.random() < 0.4 then
			local nm = NearMissCopyConfig.NearMiss
			for _ = 1, 10 do
				local line = nm[math.random(1, #nm)]
				if string.find(line, "MISS", 1, true) and (string.find(line, "x2", 1, true) or string.find(line, "x3", 1, true) or string.find(line, "x5", 1, true)) then
					return line
				end
			end
		end
		return NearMissCopyConfig.StreakHeadlines[idx]
	end
	local nm = NearMissCopyConfig.NearMiss
	return nm[math.random(1, #nm)]
end

local SPEED_MILESTONES = { 100, 150, 200, 250, 300 }
local crossedSpeedMilestones: { [number]: boolean } = {}
local milestoneHudQueue: { number } = {}

local WHEEL_NAMES = {"FL", "FR", "RL", "RR"}

local COLLISION_SFX_COOLDOWN = 0.5

local CAR_TO_ENGINE: { [string]: string } = {
	starter = "engine_sedan",
	sedan = "engine_sedan",
	muscle = "engine_racer",
	sports = "engine_racer",
	suv = "engine_sedan",
	dune_buggy = "engine_buggy",
	hot_rod = "engine_racer",
	snowmobile = "engine_buggy",
	ice_racer = "engine_racer",
	cyber_car = "engine_supercar",
	hyper_car = "engine_supercar",
	midnight_drifter = "engine_racer",
}

local function engineSoundForCarId(carId: string): string
	return CAR_TO_ENGINE[carId] or "engine_sedan"
end

local lastCollisionSfxClock = 0.0
local collisionConn: RBXScriptConnection? = nil
local activeEngineLoopName: string? = nil

local function disconnectCollisionSfx()
	if collisionConn then
		collisionConn:Disconnect()
		collisionConn = nil
	end
end

local function isBarrierTouch(other: BasePart): boolean
	if other:IsA("Terrain") then
		return false
	end
	if not other.CanCollide then
		return false
	end
	if carModel and other:IsDescendantOf(carModel) then
		return false
	end
	if other:GetAttribute("DAC_Barrier") == true then
		return true
	end
	local n = string.lower(other.Name)
	if string.find(n, "barrier") or string.find(n, "wall") or string.find(n, "guardrail") or string.find(n, "column") then
		return true
	end
	return false
end

local function hookCollisionSfx(car: Model)
	disconnectCollisionSfx()
	local root = car.PrimaryPart
	if not root then
		return
	end
	collisionConn = root.Touched:Connect(function(hit: BasePart)
		if not isRunning or not isBarrierTouch(hit) then
			return
		end
		local t = os.clock()
		if t - lastCollisionSfxClock < COLLISION_SFX_COOLDOWN then
			return
		end
		lastCollisionSfxClock = t
		SoundFacade.playOneShot("collision")
		VFXFacade.cameraShake(0.4, 0.25)
	end)
end

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
	doubleSpeedPass = flags.double_speed == true
end

local function trimAccelSamples(now: number)
	while #accelSpeedSamples > 0 and now - accelSpeedSamples[1].t > 0.5 do
		table.remove(accelSpeedSamples, 1)
	end
end

local function considerAccelerationCallout()
	local now = os.clock()
	local delta = currentSpeed - previousSpeed
	table.insert(accelSpeedSamples, { t = now, s = currentSpeed })
	trimAccelSamples(now)
	local rangeOver50 = false
	if #accelSpeedSamples >= 2 then
		local smin = accelSpeedSamples[1].s
		local smax = accelSpeedSamples[1].s
		for _, sample in accelSpeedSamples do
			smin = math.min(smin, sample.s)
			smax = math.max(smax, sample.s)
		end
		rangeOver50 = (smax - smin) > 50
	end
	local spike = delta > 30
	if (spike or rangeOver50) and (now - lastAccelCalloutClock >= ACCEL_CALLOUT_COOLDOWN) then
		lastAccelCalloutClock = now
		local pool = SpeedTierCopyConfig.AccelerationCallouts
		if #pool > 0 then
			table.insert(accelCalloutQueue, pool[math.random(1, #pool)])
		end
		SoundFacade.playOneShot("boost")
	end
	previousSpeed = currentSpeed
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

	local distFromLaneEdge = LANE_WIDTH - math.abs(lateralX)
	local nearLaneEdge = distFromLaneEdge <= NEAR_EDGE_STUDS
	if nearLaneEdge and not wasNearLaneEdge then
		local fromRight = lateralX > 0
		local now = os.clock()
		if now - lastNearMissEnterClock > 0.15 then
			lastNearMissEnterClock = now
			local prevStreak = nearMissStreak
			local streakReset = now - lastNearMissStreakAt > NEAR_MISS_STREAK_RESET_SEC
			if streakReset and prevStreak >= 3 then
				local coins = math.max(0, math.floor(nearMissGrantChainTotal))
				local headline = ComboCelebrationConfig.pickVariant(ComboCelebrationConfig.ComboBreak)
				headline = (headline:gsub("{COMBO}", tostring(prevStreak))):gsub("{COINS}", tostring(coins))
				local body = ComboCelebrationConfig.pickVariant(ComboCelebrationConfig.ComboBreakMotivation)
				table.insert(comboBreakHudQueue, { headline = headline, body = body })
				SoundFacade.playOneShot("combo_break")
				nearMissGrantChainTotal = 0
			end
			if streakReset then
				nearMissStreak = 1
			else
				nearMissStreak += 1
			end
			lastNearMissStreakAt = now

			if not streakReset then
				local prevTierKey = ComboCelebrationConfig.getTierKey(math.max(2, prevStreak))
				local newTierKey = ComboCelebrationConfig.getTierKey(nearMissStreak)
				if nearMissStreak >= 2 and newTierKey ~= prevTierKey then
					local heads = ComboCelebrationConfig.Headlines[newTierKey]
					local bodies = ComboCelebrationConfig.Bodies[newTierKey]
					if heads and bodies and #heads > 0 and #bodies > 0 then
						local h = ComboCelebrationConfig.pickVariant(heads)
						local b = ComboCelebrationConfig.pickVariant(bodies)
						h = (h:gsub("{COMBO}", tostring(nearMissStreak)))
						b = (b:gsub("{COMBO}", tostring(nearMissStreak)))
						table.insert(comboCelebrationHudQueue, { headline = h, body = b, comboCount = nearMissStreak })
					end
				end

				local prevBest = maxNearMissStreakThisRun
				if nearMissStreak > prevBest then
					maxNearMissStreakThisRun = nearMissStreak
					if prevBest >= 1 then
						local pb = ComboCelebrationConfig.pickVariant(ComboCelebrationConfig.NewPersonalBest)
						pb = (pb:gsub("{COMBO}", tostring(nearMissStreak))):gsub("{OLD}", tostring(prevBest))
						table.insert(comboCelebrationHudQueue, { headline = pb, body = "", comboCount = nearMissStreak })
					end
				end
			end

			table.insert(nearMissHudQueue, pickNearMissPopupText(nearMissStreak))
			VFXController.nearMissEdgeEnterFx(fromRight)
			VFXFacade.nearMissSpark(fromRight)
			Remotes.getEvent("NearMissClaim"):FireServer()
		end
	elseif not nearLaneEdge and wasNearLaneEdge then
		VFXController.nearMissRecover()
	end
	wasNearLaneEdge = nearLaneEdge

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
		camera.CFrame = CFrame.lookAt(cameraPos, lookAt) * CFrame.new(VFXController.getRunCameraShakeOffset())
	end

	if activeEngineLoopName then
		local pitch = math.clamp(0.55 + (currentSpeed / 300) * 0.85, 0.45, 1.55)
		SoundFacade.setLoopPitch(activeEngineLoopName, pitch)
	end
	local windVol = math.clamp(currentSpeed / 240, 0, 1) * 0.55
	SoundFacade.setLoopVolume("engine_wind", windVol)

	if VFXController.speedTrail then
		VFXController.speedTrail(currentSpeed)
	end
	VFXFacade.boostOverlay(doubleSpeedPass == true)
	if currentSpeed >= runMaxSpeedForRush * 0.7 then
		VFXFacade.speedRushOverlay(currentSpeed)
	else
		VFXFacade.speedRushOverlay(0)
	end
	if doubleSpeedPass and isRunning then
		local now = os.clock()
		if now - lastBoostSfxClock >= BOOST_SFX_INTERVAL then
			lastBoostSfxClock = now
			SoundFacade.playOneShot("boost")
		end
	end
	if VFXController.onRunDistanceTick then
		VFXController.onRunDistanceTick(totalDistance)
	end

	considerAccelerationCallout()

	for _, threshold in SPEED_MILESTONES do
		if currentSpeed >= threshold and not crossedSpeedMilestones[threshold] then
			crossedSpeedMilestones[threshold] = true
			VFXFacade.speedMilestone(threshold)
			SoundFacade.playOneShot("level_up")
			table.insert(milestoneHudQueue, threshold)
		end
	end
end

function DrivingController.startRun(info: any)
	runInfo = info
	isRunning = true
	lastBoostSfxClock = os.clock()
	previousSpeed = 0
	table.clear(accelSpeedSamples)
	table.clear(accelCalloutQueue)
	lastAccelCalloutClock = 0
	wasNearLaneEdge = false
	lastNearMissEnterClock = 0
	nearMissStreak = 0
	lastNearMissStreakAt = 0
	nearMissGrantChainTotal = 0
	table.clear(nearMissHudQueue)
	table.clear(comboCelebrationHudQueue)
	table.clear(comboBreakHudQueue)
	maxNearMissStreakThisRun = 0
	table.clear(crossedSpeedMilestones)
	table.clear(milestoneHudQueue)
	currentSpeed = info.stats.speed
	runMaxSpeedForRush = if type(info.stats) == "table" and type(info.stats.speed) == "number" then math.max(info.stats.speed, 1) else 100
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

	lastCollisionSfxClock = 0
	activeEngineLoopName = nil
	if type(info.carId) == "string" then
		activeEngineLoopName = engineSoundForCarId(info.carId)
		SoundFacade.playLoop(activeEngineLoopName :: string, 0.72, 0.52)
	end
	SoundFacade.playLoop("engine_wind", 1, 0)
	if carModel then
		hookCollisionSfx(carModel)
	end
end

function DrivingController.endRun(_results: any)
	VFXFacade.boostOverlay(false)
	VFXFacade.speedRushOverlay(0)
	disconnectCollisionSfx()
	if activeEngineLoopName then
		SoundFacade.stopLoop(activeEngineLoopName :: string, 0.5)
		activeEngineLoopName = nil
	end
	SoundFacade.stopLoop("engine_wind", 0.5)

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
		local lapSec = if type(update.lapTimeSeconds) == "number" then update.lapTimeSeconds else nil
		VFXFacade.lapFlash(isPb, lapSec)
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

function DrivingController.popHudMilestoneFlash(): number?
	if #milestoneHudQueue == 0 then
		return nil
	end
	return table.remove(milestoneHudQueue, 1)
end

function DrivingController.popHudNearMissFlash(): string?
	if #nearMissHudQueue == 0 then
		return nil
	end
	return table.remove(nearMissHudQueue, 1)
end

function DrivingController.popHudComboCelebration(): { headline: string, body: string, comboCount: number? }?
	if #comboCelebrationHudQueue == 0 then
		return nil
	end
	return table.remove(comboCelebrationHudQueue, 1)
end

function DrivingController.recordNearMissGrant(amount: number)
	if not isRunning or amount <= 0 then
		return
	end
	nearMissGrantChainTotal += amount
end

function DrivingController.popHudComboBreak(): { headline: string, body: string }?
	if #comboBreakHudQueue == 0 then
		return nil
	end
	return table.remove(comboBreakHudQueue, 1)
end

function DrivingController.popAccelCallout(): string?
	if #accelCalloutQueue == 0 then
		return nil
	end
	return table.remove(accelCalloutQueue, 1)
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
