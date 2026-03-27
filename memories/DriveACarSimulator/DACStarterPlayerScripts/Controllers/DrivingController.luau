--!strict
--[[
	Client-side driving controller.
	
	The car drives forward AUTOMATICALLY along -Z (the highway direction).
	The player can only steer left/right. When gas runs out, the server ends
	the run. When the car reaches the highway end, it laps.

	POLA-468: Lane snap / “unstick” — two-step confirm (R or optional `DrivingUI.VehicleReset`),
	server cooldown via `RequestVehicleReset`, `vehicle_reset` SFX. Car stays upright
	from per-frame `PivotTo`; reset snaps lateral offset to lane center only.

	POLA-457 (handbrake / drift HUD): No handbrake physics or drift torque — car is
	lane-steer arcade only (`rg -i handbrake` / `drift` in `DrivingController` had
	no gameplay hook before this). **Cosmetic** “drift” engage: Left/Right Shift,
	gamepad **R1** (`ButtonR1`), optional pre-built `DrivingUI.HandbrakeHud` — HUD
	tint + pulse + `handbrake_on`/`handbrake_off` SFX only.

	POLA-631: Mid-run character or `Car` respawn — re-bind `carModel`, collision hooks,
	headlights, and lane origin (`centerX` / `startZ`) so HUD/camera stay aligned with
	the server run (server keeps `activeRuns`; client arcade lane must match new HRP).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local DrivingRunGate = require(DAC:WaitForChild("DrivingRunGate"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local NearMissCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("NearMissCopyConfig"))
local SpeedTierCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedTierCopyConfig"))
local ComboCelebrationConfig = require(DAC:WaitForChild("Config"):WaitForChild("ComboCelebrationConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local VFXController = require(script.Parent:WaitForChild("VFXController"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local DrivingController = {}

-- Idempotent init: Studio hot reload must not stack RenderStepped / input connections.
local drivingClientInitDone = false

local player = Players.LocalPlayer

-- POLA-561: Pause local run simulation when the window loses focus (tab background /
-- alt-tab) so HUD distance/gas prediction does not race ahead of server tick.
local windowFocused = true

local isRunning = false
local runInfo: any = nil
local carModel: Model? = nil

-- Client-only headlight beams (POLA-420); 0 = off, 1 = low, 2 = high
local headlightMode = 0
local headlightSpots: { SpotLight } = {}

local function clearClientHeadlights()
	for _, s in headlightSpots do
		s:Destroy()
	end
	table.clear(headlightSpots)
end

local function applyClientHeadlights()
	clearClientHeadlights()
	if headlightMode == 0 or not carModel then
		return
	end
	local root = carModel.PrimaryPart
	if not root then
		return
	end
	local s = Instance.new("SpotLight")
	s.Name = "DAC_ClientHeadlight"
	s.Enabled = true
	s.Face = Enum.NormalId.Front
	if headlightMode == 1 then
		s.Brightness = 2.8
		s.Range = 58
		s.Angle = 68
	else
		s.Brightness = 5.2
		s.Range = 105
		s.Angle = 78
	end
	s.Parent = root
	table.insert(headlightSpots, s)
end

local startZ = 0
local centerX = 0
local lateralX = 0
local currentSpeed = 0
local maxSpeed = 0
local runPower = 0
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

-- Horn (POLA-425): H / gamepad L1 / optional DrivingUI.Horn; hold repeats at HORN_REPEAT_HZ max
local hornKeyDown = false
local hornGamepadDown = false
local hornUiDown = false
local hornAnyPrev = false
local lastHornRepeatClock = 0.0
local HORN_REPEAT_INTERVAL = 0.5 -- 2 per second
local hornHudPunch: (() -> ())? = nil
-- POLA-436: HUD ignition line + optional tach twitch after engine SFX (registered from DrivingHUD.init)
local engineIgnitionFxCallbacks: { () -> () } = {}
local gameplaySuppressPrev = false

-- POLA-457: cosmetic handbrake / drift engage (no physics); see file header
local handbrakeUiDown = false
local handbrakeAnyPrev = false

-- POLA-468: lane-center snap UX (confirm window + server cooldown clock)
local vehicleResetArmedUntil = 0.0
local vehicleResetCooldownUntil = 0.0

local function hornAnyHeld(): boolean
	return hornKeyDown or hornGamepadDown or hornUiDown
end

local function handbrakeRawHeld(): boolean
	if handbrakeUiDown then
		return true
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		return true
	end
	if UserInputService.GamepadEnabled and UserInputService:IsKeyDown(Enum.KeyCode.ButtonR1) then
		return true
	end
	return false
end

local function fireHornShort()
	SoundFacade.playOneShot("horn_short")
	if hornHudPunch then
		hornHudPunch()
	end
end

local function onHornChannelsChanged()
	local nowHeld = hornAnyHeld()
	if nowHeld and not hornAnyPrev then
		fireHornShort()
		lastHornRepeatClock = os.clock()
	end
	hornAnyPrev = nowHeld
end

local function isHornInputBegin(input: InputObject): boolean
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.H then
		return true
	end
	if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonL1 then
		return true
	end
	return false
end

local function isHornInputEnd(input: InputObject): boolean
	return isHornInputBegin(input)
end

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
-- High-speed barrier hits: stronger juice (POLA-414). Car is kinematic; speed proxies impact severity.
local HEAVY_COLLISION_SPEED = 58
local HEAVY_COLLISION_SFX_DEBOUNCE = 1.0

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
local lastHeavyCollisionSfxClock = 0.0
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
		local heavy = currentSpeed >= HEAVY_COLLISION_SPEED
		if heavy and (t - lastHeavyCollisionSfxClock) >= HEAVY_COLLISION_SFX_DEBOUNCE then
			lastHeavyCollisionSfxClock = t
			lastCollisionSfxClock = t
			SoundFacade.playOneShot("impact_heavy")
			VFXFacade.heavyCollisionImpact()
			VFXFacade.cameraShake(0.58, 0.3)
			return
		end
		if t - lastCollisionSfxClock < COLLISION_SFX_COOLDOWN then
			return
		end
		lastCollisionSfxClock = t
		SoundFacade.playOneShot("collision")
		VFXFacade.cameraShake(0.38, 0.22)
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

local function shouldSuppressGameplayInput(): boolean
	if UIController.isBlockingGameplayInput() then
		return true
	end
	if SoundController.isPayoutModalOpen() then
		return true
	end
	if SoundController.isTutorialGameplayBlocked() then
		return true
	end
	if VFXController.isCeremonyHeroBlocking() then
		return true
	end
	return false
end

local function handleInput(_dt: number)
	steerInput = 0
	if shouldSuppressGameplayInput() then
		return
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		steerInput -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		steerInput += 1
	end
	if steerInput ~= 0 then
		return
	end
	local gp = 0
	if UserInputService.GamepadEnabled then
		local ok, state = pcall(function()
			return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		end)
		if ok and state then
			gp = math.clamp(state.Thumbstick1.X, -1, 1)
		end
	end
	if math.abs(gp) > 0.15 then
		steerInput = gp
	end
end

local function onTouchBegan(input: InputObject, _gameProcessed: boolean)
	if not isRunning then return end
	if shouldSuppressGameplayInput() then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		touchStartX = input.Position.X
	end
end

local function onTouchChanged(input: InputObject, _gameProcessed: boolean)
	if not isRunning or not touchStartX then return end
	if shouldSuppressGameplayInput() then
		steerInput = 0
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position.X - touchStartX
		local screenWidth = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1920
		-- POLA-610: keep full-steer drag distance sane on the narrowest phones (avoid ultra-twitchy steer).
		local steerDenom = math.max(screenWidth * 0.15, 48)
		steerInput = math.clamp(delta / steerDenom, -1, 1)
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

--[[
	After CharacterAdded or server re-cloning `Car`, `carModel` may be nil or stale.
	Re-derive lane origin from HRP so posZ = startZ - currentLapDistance matches world.
]]
local function resyncCarAndLaneOriginFromCharacter()
	if not isRunning or not runInfo then
		return
	end
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local newCar = character:FindFirstChild("Car") :: Model?
	if not hrp or not newCar or not newCar.PrimaryPart then
		return
	end
	carModel = newCar
	centerX = hrp.Position.X - lateralX
	startZ = hrp.Position.Z + currentLapDistance
	disconnectCollisionSfx()
	hookCollisionSfx(newCar)
	applyClientHeadlights()
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

	if not windowFocused then
		steerInput = 0
		touchStartX = nil
		return
	end

	if carModel and not carModel.Parent then
		carModel = nil
	end
	if isRunning and carModel == nil then
		resyncCarAndLaneOriginFromCharacter()
	end

	handleInput(dt)
	local suppressGameplay = shouldSuppressGameplayInput()
	if suppressGameplay and not gameplaySuppressPrev then
		hornKeyDown = false
		hornGamepadDown = false
		hornUiDown = false
		hornAnyPrev = false
		handbrakeUiDown = false
		handbrakeAnyPrev = false
	end
	gameplaySuppressPrev = suppressGameplay
	if suppressGameplay then
		steerInput = 0
	end

	local handbrakeNow = isRunning and not suppressGameplay and handbrakeRawHeld()
	if handbrakeNow and not handbrakeAnyPrev then
		SoundFacade.playOneShot("handbrake_on")
	elseif not handbrakeNow and handbrakeAnyPrev then
		SoundFacade.playOneShot("handbrake_off")
	end
	handbrakeAnyPrev = handbrakeNow

	if isRunning and hornAnyHeld() and not suppressGameplay then
		local now = os.clock()
		if now - lastHornRepeatClock >= HORN_REPEAT_INTERVAL then
			lastHornRepeatClock = now
			SoundFacade.playOneShot("horn_repeat")
		end
	end

	if autoDriveAssist then
		local s = if lateralX > 0.01 then 1 elseif lateralX < -0.01 then -1 else 0
		steerInput = math.clamp(steerInput - s * 1.2 * dt, -1, 1)
	end

	local accelRate = 8 + runPower * 0.5
	currentSpeed = math.min(maxSpeed, currentSpeed + accelRate * dt)

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
		if now - lastNearMissEnterClock > Constants.NEAR_MISS_CLIENT_LATERAL_DEBOUNCE_SEC then
			lastNearMissEnterClock = now
			local prevStreak = nearMissStreak
			local streakReset = now - lastNearMissStreakAt > Constants.NEAR_MISS_CHAIN_RESET_SEC
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
			VFXFacade.nearMissSpark(fromRight, nearMissStreak)
			-- Gameplay-timed remote (~6.7/s max); server claimNearMiss + RemoteCooldown enforce Constants.NEAR_MISS_CLAIM_MIN_INTERVAL
			Remotes.getEvent("NearMissClaim"):FireServer()
		end
	elseif not nearLaneEdge and wasNearLaneEdge then
		VFXController.nearMissRecover(nearMissStreak)
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
	local speedNorm = if runMaxSpeedForRush > 0 then currentSpeed / runMaxSpeedForRush else 0
	VFXController.applyRunSpeedFov(speedNorm, dt, shouldSuppressGameplayInput())
	if currentSpeed >= runMaxSpeedForRush * 0.7 then
		VFXFacade.speedRushOverlay(currentSpeed / runMaxSpeedForRush)
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
	DrivingRunGate.setInRun(true)
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
	hornKeyDown = false
	hornGamepadDown = false
	hornUiDown = false
	hornAnyPrev = false
	handbrakeUiDown = false
	handbrakeAnyPrev = false
	lastHornRepeatClock = 0
	gameplaySuppressPrev = false
	vehicleResetArmedUntil = 0
	vehicleResetCooldownUntil = 0
	headlightMode = 0
	clearClientHeadlights()
	maxSpeed = if type(info.stats) == "table" and type(info.stats.speed) == "number" then info.stats.speed else 0
	runPower = if type(info.stats) == "table" and type(info.stats.power) == "number" then info.stats.power else 0
	currentSpeed = 0
	runMaxSpeedForRush = math.max(maxSpeed, 1)
	currentGas = info.stats.gas
	totalDistance = 0
	currentLapDistance = 0
	laps = 0
	steerInput = 0
	lateralX = 0

	local character = player.Character
	if character and character.Parent then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			startZ = root.Position.Z
			centerX = root.Position.X
		end
		carModel = character:FindFirstChild("Car") :: Model?
		if not carModel then
			local ok, added = pcall(function()
				return character:WaitForChild("Car", 5)
			end)
			if ok and added and added:IsA("Model") then
				carModel = added
			end
		end
	end

	lastCollisionSfxClock = 0
	lastHeavyCollisionSfxClock = 0
	activeEngineLoopName = nil
	if type(info.carId) == "string" then
		activeEngineLoopName = engineSoundForCarId(info.carId)
		SoundFacade.playLoop(activeEngineLoopName :: string, 0.72, 0.52)
	end
	SoundFacade.playLoop("engine_wind", 1, 0)
	-- POLA-436: key-turn + starter one-shots (idle loop above); HUD flash registered via registerEngineIgnitionFx
	SoundFacade.playOneShot("ignition")
	SoundFacade.playOneShot("engine_start")
	-- POLA-447: enter-run confirmation (no VehicleSeat prompt in this game — see Audio/MANIFEST.md)
	SoundFacade.playOneShot("vehicle_enter_success")
	VFXController.vehicleEnterCheckmarkPop()
	for _, fn in engineIgnitionFxCallbacks do
		task.defer(fn)
	end
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

	headlightMode = 0
	clearClientHeadlights()
	hornKeyDown = false
	hornGamepadDown = false
	hornUiDown = false
	hornAnyPrev = false
	if handbrakeAnyPrev then
		SoundFacade.playOneShot("handbrake_off")
	end
	handbrakeUiDown = false
	handbrakeAnyPrev = false
	lastHornRepeatClock = 0
	gameplaySuppressPrev = false
	vehicleResetArmedUntil = 0
	vehicleResetCooldownUntil = 0
	isRunning = false
	DrivingRunGate.setInRun(false)
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
		local lapDelta = if type(update.lapDeltaSecondsFromBest) == "number" then update.lapDeltaSecondsFromBest else nil
		local lapDeltaLast = if type(update.lapDeltaSecondsFromLast) == "number" then update.lapDeltaSecondsFromLast else nil
		VFXFacade.lapFlash(isPb, lapSec, lapDelta, lapDeltaLast)
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

--[[
	POLA-438: No RPM/tach in sim — HUD uses speed vs run cap (`runMaxSpeedForRush`) as redline proxy.
]]
function DrivingController.getRedlineNorm(): number
	if not isRunning or runMaxSpeedForRush <= 0 then
		return 0
	end
	return currentSpeed / runMaxSpeedForRush
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

--[[
	Hint line on DrivingHUD: which control set to describe (keyboard / touch / gamepad).
	Priority: held keys → active touch drag → thumbstick → GetLastInputType fallback.
]]
function DrivingController.setHeadlightMode(mode: number)
	headlightMode = math.clamp(math.floor(mode + 0.5), 0, 2)
	applyClientHeadlights()
end

function DrivingController.registerHornHudPunch(callback: () -> ())
	hornHudPunch = callback
end

function DrivingController.registerEngineIgnitionFx(callback: () -> ())
	table.insert(engineIgnitionFxCallbacks, callback)
end

function DrivingController.honkUiButtonDown()
	if not isRunning or shouldSuppressGameplayInput() then
		return
	end
	hornUiDown = true
	onHornChannelsChanged()
end

function DrivingController.honkUiButtonUp()
	hornUiDown = false
	onHornChannelsChanged()
end

function DrivingController.handbrakeUiButtonDown()
	if not isRunning or shouldSuppressGameplayInput() then
		return
	end
	handbrakeUiDown = true
end

function DrivingController.handbrakeUiButtonUp()
	handbrakeUiDown = false
end

--[[
	True while cosmetic handbrake/drift input is held (POLA-457). No effect on speed or steer.
]]
function DrivingController.isHandbrakeEngaged(): boolean
	if not isRunning or shouldSuppressGameplayInput() then
		return false
	end
	return handbrakeRawHeld()
end

function DrivingController.getHeadlightMode(): number
	return headlightMode
end

--[[
	Analog steer -1..1 for HUD (keyboard / gamepad / touch drag). POLA-432: mobile
	has no separate throttle-brake — car is always forward-driven; touch intensity is lateral.
]]
function DrivingController.getSteerInput(): number
	return steerInput
end

function DrivingController.isTouchSteerActive(): boolean
	return touchStartX ~= nil
end

function DrivingController.getVehicleResetArmExpires(): number
	return vehicleResetArmedUntil
end

function DrivingController.getVehicleResetCooldownUntil(): number
	return vehicleResetCooldownUntil
end

--[[
	POLA-468: First call arms (shows confirm line); second call within window invokes server snap.
]]
function DrivingController.vehicleResetIntent()
	if not isRunning or shouldSuppressGameplayInput() then
		return
	end
	local now = os.clock()
	if vehicleResetCooldownUntil > now then
		local rem = math.max(1, math.ceil(vehicleResetCooldownUntil - now))
		local msg = MicrocopyConfig.VehicleResetCooldown:gsub("{SEC}", tostring(rem))
		VFXFacade.milestonePopup(msg, "vehicle_reset_err")
		return
	end

	if vehicleResetArmedUntil > now then
		vehicleResetArmedUntil = 0
		local ok, res = pcall(function()
			return Remotes.getFunction("RequestVehicleReset"):InvokeServer()
		end)
		if not ok or type(res) ~= "table" then
			VFXFacade.milestonePopup(MicrocopyConfig.VehicleResetGenericFail, "vehicle_reset_err")
			return
		end
		if (res :: any).ok == true then
			lateralX = 0
			vehicleResetCooldownUntil = now + Constants.VEHICLE_RESET_COOLDOWN_SEC
			SoundFacade.playOneShot("vehicle_reset")
			VFXFacade.milestonePopup(MicrocopyConfig.VehicleResetSuccess, "vehicle_reset_ok")
			VFXFacade.cameraShake(0.2, 0.12)
			return
		end
		local reason = (res :: any).reason
		if reason == "cooldown" and type((res :: any).remainingSec) == "number" then
			local r = math.max(0, (res :: any).remainingSec)
			vehicleResetCooldownUntil = now + r
			local rem = math.max(1, math.ceil(r))
			local msg = MicrocopyConfig.VehicleResetCooldown:gsub("{SEC}", tostring(rem))
			VFXFacade.milestonePopup(msg, "vehicle_reset_err")
			return
		end
		if reason == "no_run" then
			VFXFacade.milestonePopup(MicrocopyConfig.VehicleResetNotInRun, "vehicle_reset_err")
			return
		end
		VFXFacade.milestonePopup(MicrocopyConfig.VehicleResetGenericFail, "vehicle_reset_err")
		return
	end

	vehicleResetArmedUntil = now + Constants.VEHICLE_RESET_CONFIRM_WINDOW_SEC
	VFXFacade.milestonePopup(MicrocopyConfig.VehicleResetConfirmLine, "vehicle_reset_hint")
end

function DrivingController.getSteerHintMode(): string
	-- POLA-554: Living-room / console — show stick hint immediately (no keyboard/mouse).
	if UserInputService.GamepadEnabled and UserInputService.KeyboardEnabled == false and UserInputService.MouseEnabled == false then
		return "gamepad"
	end
	if
		UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right)
	then
		return "keyboard"
	end
	if touchStartX ~= nil then
		return "touch"
	end
	if UserInputService.GamepadEnabled then
		local ok, state = pcall(function()
			return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		end)
		if ok and state and math.abs(state.Thumbstick1.X) > 0.15 then
			return "gamepad"
		end
	end
	local lit = UserInputService:GetLastInputType()
	if lit == Enum.UserInputType.Touch then
		return "touch"
	end
	if lit == Enum.UserInputType.Gamepad1
		or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3
		or lit == Enum.UserInputType.Gamepad4
		or lit == Enum.UserInputType.Gamepad5
		or lit == Enum.UserInputType.Gamepad6
		or lit == Enum.UserInputType.Gamepad7
		or lit == Enum.UserInputType.Gamepad8
	then
		return "gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	return "keyboard"
end

function DrivingController.init()
	if drivingClientInitDone then
		return
	end
	drivingClientInitDone = true

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

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if not isRunning or not isHornInputBegin(input) then
			return
		end
		if shouldSuppressGameplayInput() then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			hornKeyDown = true
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			hornGamepadDown = true
		end
		onHornChannelsChanged()
	end)

	UserInputService.InputEnded:Connect(function(input, _processed)
		if not isHornInputEnd(input) then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			hornKeyDown = false
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			hornGamepadDown = false
		end
		onHornChannelsChanged()
	end)

	UserInputService.WindowFocused:Connect(function()
		windowFocused = true
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		windowFocused = false
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if not isRunning or shouldSuppressGameplayInput() then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			DrivingController.vehicleResetIntent()
			return
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonY then
			DrivingController.vehicleResetIntent()
		end
	end)
end

return DrivingController
