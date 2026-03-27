--!strict
--[[
	POLA-432: Optional `DrivingUI.MobileSteerPedals` (Left/Right + Fill) shows lateral steer
	intensity on touch. There are no discrete throttle/brake controls — speed is auto-driven;
	see DrivingController (touch drag → steer only). Studio template: STUDIO_TEMPLATES.md.

	POLA-438: There is no RPM/tach/gear readout — only speed (studs/s), power, fuel. Redline
	polish uses `DrivingController.getRedlineNorm()` (speed / run cap) with Speed frame stroke,
	speed dial shake, shift-up flash, optional `rev_limiter` loop in SoundController.

	POLA-468: Optional `DrivingUI.VehicleReset` (large `Btn` + optional `CooldownFill` / `TimerLabel`)
	wires to `DrivingController.vehicleResetIntent()` — same two-step flow as R / gamepad Y.

	POLA-443: Fuel meter `Gas` frame — `FuelPanicStroke` amber border pulse under 20% (5–20% band),
	`fuel_low_warn` chirp (8s cap), one-shot red flash when entering <5% or hitting empty then
	steady stroke (no looping red pulse).

	POLA-457: Cosmetic handbrake/drift — **no** vehicle physics (`DrivingController` header). Optional
	pre-built `DrivingUI.HandbrakeHud` (Icon + optional Btn); Shift / gamepad R1 / UI hold → tint +
	pulse + SFX via `DrivingController.isHandbrakeEngaged()`.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local SpeedMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedMilestoneConfig"))
local SpeedTierCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedTierCopyConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))

local DrivingHUD = {}

-- Idempotent init: GuiBootstrap guard + defense against duplicate driving HUD listeners.
local drivingHudInitDone = false
local drivingHudLayoutDisconnect: (() -> ())? = nil

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local TweenService = game:GetService("TweenService")

local drivingUI: Frame
local gasBar: ImageLabel
local gasBackground: ImageLabel
local gasText: TextLabel
local gasPanicStroke: UIStroke? = nil
local gasGoldenStroke: UIStroke? = nil
local speedText: TextLabel
local powerText: TextLabel
local travelFrame: ImageLabel
local travelLabel: TextLabel
local lapsLabel: TextLabel
local recordFrame: Instance?
local steerHintLabel: TextLabel? = nil
local lastSteerHintMode: string? = nil

local isVisible = false
local maxGas = 0
local currentGas = 0
local currentDistance = 0
local currentLaps = 0
local currentSpeed = 0
local currentPower = 0
local bestDistance = 0

local DrivingController: any = nil
-- POLA-420: optional `DrivingUI.LightsToggle` (pre-built in Studio); cycles off → low → high
-- POLA-425: optional `DrivingUI.Horn` + `Btn` — mobile honk; keyboard H, gamepad L1
local headlightHudMode = 0
local headlightApplyUi: (() -> ())? = nil

local function resetHeadlightHudToOff()
	headlightHudMode = 0
	if headlightApplyUi then
		headlightApplyUi()
	end
end

local hudMilestoneFlashBusy = false
local hudNearMissFlashBusy = false
local hudComboCelebrationBusy = false
local hudComboBreakBusy = false
local hudTierNameFlashBusy = false
local hudAccelCalloutBusy = false
local engineIgnitionFlashBusy = false
local lastSpeedTierKey: string? = nil
local tierNameFlashQueue: { string } = {}
local accelCalloutQueue: { string } = {}

local speedUIScale: UIScale? = nil
local speedHudFrame: Frame? = nil
local speedRedlineStroke: UIStroke? = nil
local prevRedlineNormStored = 0.0
local revLimiterActive = false

-- POLA-438: speed/run-cap ratio (no tach in data model)
local REDLINE_VISUAL = 0.86
local REDLINE_SOUND_ON = 0.88
local REDLINE_SOUND_OFF = 0.76

local lastAlmostSpeedToastClock = 0.0
local lastAlmostSpeedToastThreshold: number? = nil
local ALMOST_SPEED_TOAST_COOLDOWN_SEC = 28.0
local lastGasPercentForHudSfx = 1.0
local prevGasPercentForFuelJuice = 1.0
local fuelShimmerBusy = false
local lastBoostReadySfxClock = -999.0
local LOW_FUEL_SLOW_PULSE_SEC = 2.8
-- POLA-443: scarcity bands on `Gas` frame border stroke (pre-built `FuelPanicStroke`)
local CRITICAL_FUEL_MAX = 0.05
local LOW_FUEL_AMBER_MAX = 0.20
local FUEL_LOW_WARN_CHIRP_COOLDOWN_SEC = 8.0
local FUEL_HUD_CRITICAL_FLASH_SEC = 0.42
local prevGasPctForBand = 1.0
local prevGasIntForEmpty = 0
local fuelHudCriticalFlashUntil = 0.0
local lastFuelLowWarnChirpClock = -999.0

-- POLA-432 optional MobileSteerPedals (pre-built under DrivingUI)
local mobilePedalsRoot: Frame? = nil
local mobilePedalLeftFill: GuiObject? = nil
local mobilePedalRightFill: GuiObject? = nil
local mobilePedalLeftStroke: UIStroke? = nil
local mobilePedalRightStroke: UIStroke? = nil
local mobilePedalLeftScale: UIScale? = nil
local mobilePedalRightScale: UIScale? = nil
local mobilePedalLeftGrad: UIGradient? = nil
local mobilePedalRightGrad: UIGradient? = nil
local lastTouchSteerActive = false
local lastLeftPedalShown = 0.0
local lastRightPedalShown = 0.0
local lastHapticSteerTier = -1

-- POLA-457 optional `DrivingUI.HandbrakeHud` (see STUDIO_TEMPLATES.md)
local handbrakeHudRoot: Frame? = nil
local handbrakeHudIcon: ImageLabel? = nil
local handbrakeHudScale: UIScale? = nil
local handbrakeHudRim: UIStroke? = nil
local prevHandbrakeHudEngaged = false
local handbrakeIconTween: Tween? = nil

-- POLA-468: optional `DrivingUI.VehicleReset` (pre-built; mobile-first tap target)
local vehicleResetRoot: Frame? = nil
local vehicleResetBtn: GuiButton? = nil
local vehicleResetCooldownFill: Frame? = nil
local vehicleResetTimerLabel: TextLabel? = nil
local vehicleResetStatusLabel: TextLabel? = nil
local C_HB_NEUTRAL = Color3.fromRGB(255, 255, 255)
local C_HB_ENGAGED = Color3.fromRGB(255, 88, 168)

--[[
	POLA-676: `DrivingUI` is often a short bottom band; scale-Y positions stack near-miss
	(~0.78) and combo celebration (~0.35) into the same vertical pocket on small phones.
	When the viewport or frame is compact, move combo higher and near-miss lower.
	Returns: comboCelebrationY, comboBreakY, nearMissY (scale 0–1 within `drivingUI`).
]]
local function getHudFlashYPositions(): (number, number, number)
	local h = drivingUI.AbsoluteSize.Y
	if h < 1 then
		h = 400
	end
	local vw = HudSafeArea.getViewportWidth()
	local cam = Workspace.CurrentCamera
	local vh = if cam then cam.ViewportSize.Y else 700
	local compact = vw <= HudLayoutConfig.compactViewportWidth or vh < 640
	local shortFrame = h < 220
	if compact or shortFrame then
		return 0.26, 0.34, 0.86
	end
	return 0.35, 0.42, 0.78
end

local C_SPEED_WHITE = Color3.fromRGB(255, 255, 255)
local C_SPEED_YELLOW = Color3.fromRGB(255, 230, 80)
local C_SPEED_ORANGE = Color3.fromRGB(255, 160, 40)
local C_SPEED_RED = Color3.fromRGB(255, 60, 40)
local C_SPEED_MAGENTA = Color3.fromRGB(255, 40, 200)

local function milestoneCelebrationColor(th: number): Color3
	local hex = SpeedMilestoneConfig.MilestoneColor[th]
	if type(hex) == "string" and hex ~= "" then
		local ok, c = pcall(function()
			return Color3.fromHex(hex)
		end)
		if ok and typeof(c) == "Color3" then
			return c
		end
	end
	return SpeedMilestoneConfig.CelebrationColor[th] or Color3.fromRGB(255, 230, 100)
end

local function speedToColor(s: number): Color3
	if s <= 50 then
		return C_SPEED_WHITE
	elseif s <= 100 then
		local t = (s - 50) / 50
		return C_SPEED_WHITE:Lerp(C_SPEED_YELLOW, t)
	elseif s <= 200 then
		local t = (s - 100) / 100
		return C_SPEED_YELLOW:Lerp(C_SPEED_ORANGE, t)
	elseif s <= 300 then
		local t = (s - 200) / 100
		return C_SPEED_ORANGE:Lerp(C_SPEED_RED, t)
	else
		return C_SPEED_MAGENTA
	end
end

local TIER_ORDER: { [string]: number } = {
	Cruising = 1,
	Fast = 2,
	Blazing = 3,
	Insane = 4,
	Legendary = 5,
}

local function speedTierKeyForSpeed(speed: number): string
	local k = "Cruising"
	for _, row in SpeedTierCopyConfig.TierThresholds do
		if speed >= row.min then
			k = row.key
		end
	end
	return k
end

local function tryPlayBoostReadyDebounced()
	local now = os.clock()
	if now - lastBoostReadySfxClock < 3.0 then
		return
	end
	lastBoostReadySfxClock = now
	SoundFacade.playOneShot("boost_ready")
end

local function triggerFuelRechargeShimmer()
	if not gasBar or gasBar.Parent == nil or fuelShimmerBusy then
		return
	end
	if ClientPerformanceProfile.uiJuiceStrength() < 0.35 then
		return
	end
	if maxGas <= 0 then
		return
	end
	local gp = math.clamp(currentGas / maxGas, 0, 1)
	if gp < 0.06 then
		return
	end
	fuelShimmerBusy = true
	tryPlayBoostReadyDebounced()

	local sweep = Instance.new("Frame")
	sweep.Name = "FuelRechargeShimmer"
	sweep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sweep.BackgroundTransparency = 0.62
	sweep.BorderSizePixel = 0
	sweep.ZIndex = (gasBar.ZIndex or 1) + 2
	sweep.Size = UDim2.new(0, 22, 0.88, 0)
	sweep.AnchorPoint = Vector2.new(0.5, 0.5)
	sweep.Position = UDim2.new(0, -14, 0.5, 0)
	sweep.Parent = gasBar

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = sweep

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = sweep

	TweenService:Create(sweep, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 14, 0.5, 0),
		BackgroundTransparency = 0.94,
	}):Play()
	task.delay(0.5, function()
		if sweep.Parent then
			sweep:Destroy()
		end
		fuelShimmerBusy = false
	end)
end

local function tryGetDrivingController()
	if DrivingController then return end
	local ok, mod = pcall(function()
		local sps = player:WaitForChild("PlayerScripts", 2)
		if not sps then return nil end
		local dac = sps:FindFirstChild("DAC")
		if not dac then return nil end
		local ctrls = dac:FindFirstChild("Controllers")
		if not ctrls then return nil end
		local dc = ctrls:FindFirstChild("DrivingController")
		if not dc then return nil end
		return require(dc)
	end)
	if ok and mod then
		DrivingController = mod
	end
end

--[[
	POLA-436: ephemeral "ENGINE ON" line (~300–600ms fade) + optional speed dial twitch.
	Runs after `DrivingController.startRun` ignition SFX (deferred callback).
]]
function DrivingHUD.flashEngineIgnition()
	if not drivingUI or not isVisible or engineIgnitionFlashBusy then
		return
	end
	engineIgnitionFlashBusy = true

	if speedUIScale then
		local sc = speedUIScale
		TweenService:Create(sc, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
		task.delay(0.09, function()
			if sc.Parent then
				TweenService:Create(sc, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 0.98 }):Play()
			end
		end)
		task.delay(0.2, function()
			if sc.Parent then
				TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
	end

	local lbl = Instance.new("TextLabel")
	lbl.Name = "EngineIgnitionFlash"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 280, 0, 32)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, 0, 0.58, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 22
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.35
	lbl.TextStrokeColor3 = Color3.fromRGB(25, 25, 45)
	lbl.Text = MicrocopyConfig.DrivingHudEngineIgnitionFlash
	lbl.TextTransparency = 1
	lbl.ZIndex = 18
	lbl.Parent = drivingUI

	TweenService:Create(lbl, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	task.delay(0.28, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
	task.delay(0.82, function()
		engineIgnitionFlashBusy = false
		if lbl.Parent then
			lbl:Destroy()
		end
	end)
end

local hudShiftUpFlashBusy = false

local function flashShiftUpRedline()
	if not drivingUI or not isVisible or hudShiftUpFlashBusy then
		return
	end
	hudShiftUpFlashBusy = true
	local lbl = Instance.new("TextLabel")
	lbl.Name = "RedlineShiftFlash"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 260, 0, 36)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, 0, 0.44, 0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 24
	lbl.TextColor3 = Color3.fromRGB(255, 90, 70)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextStrokeColor3 = Color3.fromRGB(40, 10, 10)
	lbl.Text = MicrocopyConfig.DrivingHudShiftUpFlash
	lbl.TextTransparency = 1
	lbl.ZIndex = 19
	lbl.Parent = drivingUI
	local sc = Instance.new("UIScale")
	sc.Scale = 0.82
	sc.Parent = lbl
	TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	task.delay(0.35, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
	task.delay(0.82, function()
		hudShiftUpFlashBusy = false
		if lbl.Parent then
			lbl:Destroy()
		end
	end)
end

function DrivingHUD.show(stats: { gas: number, speed: number, power: number })
	maxGas = stats.gas
	currentGas = stats.gas
	currentDistance = 0
	currentLaps = 0
	currentSpeed = stats.speed
	currentPower = stats.power
	lastSpeedTierKey = nil
	table.clear(tierNameFlashQueue)
	table.clear(accelCalloutQueue)
	lastAlmostSpeedToastClock = 0.0
	lastAlmostSpeedToastThreshold = nil
	lastGasPercentForHudSfx = 1.0
	prevGasPercentForFuelJuice = 1.0
	prevGasPctForBand = 1.0
	prevGasIntForEmpty = 0
	fuelHudCriticalFlashUntil = 0.0
	lastFuelLowWarnChirpClock = -999.0
	lastSteerHintMode = nil
	lastTouchSteerActive = false
	lastLeftPedalShown = 0
	lastRightPedalShown = 0
	lastHapticSteerTier = -1
	prevRedlineNormStored = 0
	revLimiterActive = false
	isVisible = true
	resetHeadlightHudToOff()
	if drivingUI then
		drivingUI.Visible = true
	end
	if travelFrame then
		travelFrame.Visible = true
	end
	task.defer(function()
		if isVisible and gasBar then
			triggerFuelRechargeShimmer()
		end
	end)
end

function DrivingHUD.hide()
	isVisible = false
	if revLimiterActive then
		SoundFacade.stopLoop("rev_limiter", 0.12)
		revLimiterActive = false
	end
	prevRedlineNormStored = 0
	if speedRedlineStroke then
		speedRedlineStroke.Transparency = 1
	end
	lastSpeedTierKey = nil
	lastSteerHintMode = nil
	lastTouchSteerActive = false
	lastHapticSteerTier = -1
	if steerHintLabel then
		steerHintLabel.Visible = false
	end
	prevGasPctForBand = 1.0
	prevGasIntForEmpty = 0
	fuelHudCriticalFlashUntil = 0.0
	if drivingUI then
		drivingUI.Visible = false
	end
	if travelFrame then
		travelFrame.Visible = false
	end
	prevHandbrakeHudEngaged = false
	if handbrakeIconTween then
		handbrakeIconTween:Cancel()
		handbrakeIconTween = nil
	end
	if handbrakeHudIcon then
		handbrakeHudIcon.ImageColor3 = C_HB_NEUTRAL
	end
	if handbrakeHudScale then
		handbrakeHudScale.Scale = 1
	end
	if handbrakeHudRim then
		handbrakeHudRim.Transparency = 1
	end
	if vehicleResetCooldownFill then
		vehicleResetCooldownFill.Size = UDim2.new(0, 0, 1, 0)
	end
	if vehicleResetTimerLabel then
		vehicleResetTimerLabel.Visible = false
	end
	if vehicleResetStatusLabel then
		vehicleResetStatusLabel.Visible = false
	end
	if vehicleResetBtn then
		vehicleResetBtn.Active = true
		vehicleResetBtn.AutoButtonColor = true
	end
end

local function render()
	if not isVisible then return end
	tryGetDrivingController()

	if DrivingController then
		local state = DrivingController.getRunState()
		if state then
			currentDistance = state.distance
			currentGas = state.gas
			currentSpeed = state.speed
			currentLaps = state.laps
		end
	end

	local redlineNorm = if DrivingController and DrivingController.getRedlineNorm then DrivingController.getRedlineNorm() else 0

	local gasPercent = if maxGas > 0 then math.clamp(currentGas / maxGas, 0, 1) else 0

	local enterCriticalBand = prevGasPctForBand >= CRITICAL_FUEL_MAX and gasPercent < CRITICAL_FUEL_MAX and gasPercent > 0
	local crossEmpty = prevGasIntForEmpty > 0 and currentGas == 0
	if isVisible and (enterCriticalBand or crossEmpty) then
		fuelHudCriticalFlashUntil = os.clock() + FUEL_HUD_CRITICAL_FLASH_SEC
	end

	VFXFacade.fuelPanic(gasPercent)
	if lastGasPercentForHudSfx >= 0.05 and gasPercent < 0.05 then
		SoundFacade.playOneShot("fuel_warning")
	end
	lastGasPercentForHudSfx = gasPercent

	if isVisible and gasPercent >= CRITICAL_FUEL_MAX and gasPercent < LOW_FUEL_AMBER_MAX then
		local now = os.clock()
		if now - lastFuelLowWarnChirpClock >= FUEL_LOW_WARN_CHIRP_COOLDOWN_SEC then
			lastFuelLowWarnChirpClock = now
			SoundFacade.playOneShot("fuel_low_warn")
		end
	end

	if prevGasPercentForFuelJuice < 0.88 and gasPercent >= 0.96 and gasPercent - prevGasPercentForFuelJuice > 0.04 then
		task.defer(triggerFuelRechargeShimmer)
	end
	prevGasPercentForFuelJuice = gasPercent

	if gasBar then
		gasBar.Size = UDim2.new(gasPercent * 0.5, 0, gasBar.Size.Y.Scale, 0)
	end

	local contMotion = ClientPerformanceProfile.allowsContinuousScreenMotion()
	if gasText then
		gasText.Text = tostring(math.floor(currentGas))
		if gasPercent < 0.05 then
			if contMotion then
				gasText.TextTransparency = 0.25 + 0.55 * math.abs(math.sin(os.clock() * 10))
			else
				gasText.TextTransparency = 0.35
			end
		else
			gasText.TextTransparency = 0
		end
	end

	if gasPanicStroke then
		if gasPercent >= CRITICAL_FUEL_MAX and gasPercent < LOW_FUEL_AMBER_MAX then
			local pulse = 0.5
			if contMotion then
				pulse += 0.5 * math.sin((os.clock() * (2 * math.pi)) / LOW_FUEL_SLOW_PULSE_SEC)
			end
			local amber = Color3.fromRGB(255, 165, 0)
			local amberLight = Color3.fromRGB(255, 215, 130)
			gasPanicStroke.Color = amber:Lerp(amberLight, pulse)
			gasPanicStroke.Thickness = 2.0 + 1.35 * pulse
			gasPanicStroke.Transparency = 0.06 + 0.24 * (1 - pulse)
		elseif gasPercent < CRITICAL_FUEL_MAX then
			if os.clock() < fuelHudCriticalFlashUntil then
				local t = (fuelHudCriticalFlashUntil - os.clock()) / FUEL_HUD_CRITICAL_FLASH_SEC
				t = math.clamp(t, 0, 1)
				gasPanicStroke.Color = Color3.fromRGB(255, 28, 28)
				gasPanicStroke.Thickness = 3.0 + 4.2 * t
				gasPanicStroke.Transparency = 0.02 + 0.14 * (1 - t)
			else
				gasPanicStroke.Color = Color3.fromRGB(255, 45, 45)
				gasPanicStroke.Thickness = 3.2
				gasPanicStroke.Transparency = 0.08
			end
		else
			gasPanicStroke.Transparency = 1
		end
	end

	prevGasPctForBand = gasPercent
	prevGasIntForEmpty = currentGas

	if gasGoldenStroke then
		if VFXFacade.isFirstRunOfDay() then
			if contMotion then
				local pulse = 0.85 + 0.15 * math.sin(os.clock() * 3.5)
				gasGoldenStroke.Color = Color3.fromRGB(255, 215, 60):Lerp(Color3.fromRGB(255, 240, 160), 0.5 + 0.5 * math.sin(os.clock() * 2))
				gasGoldenStroke.Thickness = 2.5 + 1.0 * pulse
				gasGoldenStroke.Transparency = 0.05 + 0.1 * (1 - pulse)
			else
				gasGoldenStroke.Color = Color3.fromRGB(255, 225, 100)
				gasGoldenStroke.Thickness = 2.9
				gasGoldenStroke.Transparency = 0.08
			end
		else
			gasGoldenStroke.Transparency = 1
		end
	end

	if speedText then
		speedText.Text = tostring(math.floor(currentSpeed))
		speedText.TextColor3 = speedToColor(currentSpeed)
	end

	if speedRedlineStroke and speedHudFrame and speedHudFrame.Parent then
		if redlineNorm >= REDLINE_VISUAL then
			if contMotion then
				local pulse = 0.5 + 0.5 * math.sin(os.clock() * 11)
				speedRedlineStroke.Transparency = 0.12 + 0.38 * (1 - pulse)
				speedRedlineStroke.Thickness = 2.0 + 2.8 * pulse
			else
				speedRedlineStroke.Transparency = 0.22
				speedRedlineStroke.Thickness = 3.2
			end
		else
			speedRedlineStroke.Transparency = 1
		end
	end

	if
		redlineNorm >= REDLINE_VISUAL
		and prevRedlineNormStored < REDLINE_VISUAL
		and drivingUI
		and drivingUI.Visible
	then
		flashShiftUpRedline()
	end

	if redlineNorm >= REDLINE_SOUND_ON then
		if not revLimiterActive then
			SoundFacade.playLoop("rev_limiter", 1.05, 0.28)
			revLimiterActive = true
		end
	elseif redlineNorm < REDLINE_SOUND_OFF then
		if revLimiterActive then
			SoundFacade.stopLoop("rev_limiter", 0.12)
			revLimiterActive = false
		end
	end

	if isVisible and DrivingController and DrivingController.popAccelCallout then
		local line = DrivingController.popAccelCallout()
		if type(line) == "string" and line ~= "" then
			table.insert(accelCalloutQueue, line)
		end
	end

	if isVisible and DrivingController then
		local tk = speedTierKeyForSpeed(currentSpeed)
		if lastSpeedTierKey ~= nil and tk ~= lastSpeedTierKey then
			local newO = TIER_ORDER[tk] or 0
			local oldO = TIER_ORDER[lastSpeedTierKey] or 0
			if newO > oldO then
				local pool = SpeedTierCopyConfig.TierNames[tk]
				if pool and #pool > 0 then
					table.insert(tierNameFlashQueue, pool[math.random(1, #pool)])
				end
			end
		end
		lastSpeedTierKey = tk
	end

	if speedUIScale then
		local baseScale = 1.0
		if currentSpeed >= 300 then
			baseScale = 1.0 + 0.08 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		end
		if redlineNorm >= REDLINE_VISUAL then
			baseScale *= 1.0 + 0.038 * math.abs(math.sin(os.clock() * 13.5))
		end
		speedUIScale.Scale = baseScale
	end

	if isVisible and mobilePedalsRoot and mobilePedalsRoot.Parent and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.getSteerInput and DrivingController.getSteerHintMode then
			local mode = DrivingController.getSteerHintMode()
			local touchMode = mode == "touch"
			mobilePedalsRoot.Visible = touchMode
			if touchMode then
				local steer = math.clamp(DrivingController.getSteerInput(), -1, 1)
				local leftAmt = math.clamp(-steer, 0, 1)
				local rightAmt = math.clamp(steer, 0, 1)
				local touchActive = false
				if DrivingController.isTouchSteerActive then
					touchActive = DrivingController.isTouchSteerActive()
				end

				local mag = math.max(leftAmt, rightAmt)
				local tier = math.floor(mag * 3)
				if touchActive then
					if tier > lastHapticSteerTier and tier >= 1 and UserInputService.TouchEnabled then
						pcall(function()
							if HapticService:IsMotorSupported(Enum.UserInputType.Touch, Enum.VibrationMotor.Small) then
								HapticService:SetMotor(Enum.UserInputType.Touch, Enum.VibrationMotor.Small, 0.25)
							end
						end)
					end
					lastHapticSteerTier = tier
				else
					lastHapticSteerTier = -1
				end

				if mobilePedalLeftFill then
					mobilePedalLeftFill.Size = UDim2.new(1, 0, leftAmt * 0.92, 0)
				end
				if mobilePedalRightFill then
					mobilePedalRightFill.Size = UDim2.new(1, 0, rightAmt * 0.92, 0)
				end
				if mobilePedalLeftStroke then
					mobilePedalLeftStroke.Transparency = 1 - 0.55 * leftAmt
				end
				if mobilePedalRightStroke then
					mobilePedalRightStroke.Transparency = 1 - 0.55 * rightAmt
				end
				if mobilePedalLeftGrad then
					local a = 0.35 + 0.65 * leftAmt
					mobilePedalLeftGrad.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5 - 0.35 * a),
						NumberSequenceKeypoint.new(1, 0.85 - 0.25 * a),
					})
				end
				if mobilePedalRightGrad then
					local a = 0.35 + 0.65 * rightAmt
					mobilePedalRightGrad.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5 - 0.35 * a),
						NumberSequenceKeypoint.new(1, 0.85 - 0.25 * a),
					})
				end

				if lastTouchSteerActive and not touchActive and (lastLeftPedalShown > 0.08 or lastRightPedalShown > 0.08) then
					local function punch(scale: UIScale?)
						if not scale or not scale.Parent then
							return
						end
						TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
						task.delay(0.09, function()
							if scale.Parent then
								TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
							end
						end)
					end
					if lastLeftPedalShown > 0.08 then
						punch(mobilePedalLeftScale)
					end
					if lastRightPedalShown > 0.08 then
						punch(mobilePedalRightScale)
					end
				end
				lastTouchSteerActive = touchActive
				lastLeftPedalShown = leftAmt
				lastRightPedalShown = rightAmt
			else
				lastTouchSteerActive = false
				lastHapticSteerTier = -1
				lastLeftPedalShown = 0
				lastRightPedalShown = 0
			end
		end
	end

	if isVisible and handbrakeHudRoot and handbrakeHudRoot.Parent and drivingUI and drivingUI.Visible and handbrakeHudIcon then
		tryGetDrivingController()
		local hbEng = false
		if DrivingController and DrivingController.isHandbrakeEngaged then
			hbEng = DrivingController.isHandbrakeEngaged()
		end
		if hbEng ~= prevHandbrakeHudEngaged then
			prevHandbrakeHudEngaged = hbEng
			if handbrakeIconTween then
				handbrakeIconTween:Cancel()
				handbrakeIconTween = nil
			end
			if hbEng then
				handbrakeIconTween = TweenService:Create(
					handbrakeHudIcon,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ ImageColor3 = C_HB_ENGAGED }
				)
				handbrakeIconTween:Play()
				if handbrakeHudScale then
					TweenService:Create(
						handbrakeHudScale,
						TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1.18 }
					):Play()
					task.delay(0.1, function()
						if handbrakeHudScale and handbrakeHudScale.Parent then
							TweenService:Create(
								handbrakeHudScale,
								TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
								{ Scale = 1.06 }
							):Play()
						end
					end)
					task.delay(0.26, function()
						if handbrakeHudScale and handbrakeHudScale.Parent then
							TweenService:Create(
								handbrakeHudScale,
								TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
								{ Scale = 1 }
							):Play()
						end
					end)
				end
				if handbrakeHudRim then
					handbrakeHudRim.Transparency = 0.22
				end
			else
				handbrakeIconTween = TweenService:Create(
					handbrakeHudIcon,
					TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ ImageColor3 = C_HB_NEUTRAL }
				)
				handbrakeIconTween:Play()
				if handbrakeHudRim then
					TweenService:Create(
						handbrakeHudRim,
						TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Transparency = 1 }
					):Play()
				end
			end
		end
	end

	if isVisible and vehicleResetRoot and vehicleResetRoot.Parent and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if
			DrivingController
			and DrivingController.getVehicleResetCooldownUntil
			and DrivingController.getVehicleResetArmExpires
		then
			local now = os.clock()
			local cdUntil = DrivingController.getVehicleResetCooldownUntil()
			local armUntil = DrivingController.getVehicleResetArmExpires()
			local remCd = math.max(0, cdUntil - now)
			local armed = armUntil > now and remCd <= 0.05
			if vehicleResetTimerLabel then
				if remCd > 0.05 then
					vehicleResetTimerLabel.Visible = true
					vehicleResetTimerLabel.Text = string.format("%ds", math.max(1, math.ceil(remCd)))
				else
					vehicleResetTimerLabel.Visible = false
				end
			end
			if vehicleResetCooldownFill then
				local p = if remCd > 0.05 then 1 - (remCd / Constants.VEHICLE_RESET_COOLDOWN_SEC) else 0
				p = math.clamp(p, 0, 1)
				vehicleResetCooldownFill.Size = UDim2.new(p, 0, 1, 0)
			end
			if vehicleResetBtn then
				vehicleResetBtn.Active = remCd <= 0.05
				vehicleResetBtn.AutoButtonColor = remCd <= 0.05
			end
			if vehicleResetStatusLabel then
				if armed then
					vehicleResetStatusLabel.Text = MicrocopyConfig.VehicleResetMicroStatusAgain
					vehicleResetStatusLabel.Visible = true
				elseif remCd > 0.05 then
					vehicleResetStatusLabel.Text = MicrocopyConfig.VehicleResetMicroStatusWait
					vehicleResetStatusLabel.Visible = true
				else
					vehicleResetStatusLabel.Visible = false
				end
			end
		end
	end

	if isVisible and drivingUI and drivingUI.Visible then
		local nextTh: number? = nil
		for _, th in SpeedMilestoneConfig.Thresholds do
			if currentSpeed < th then
				nextTh = th
				break
			end
		end
		if nextTh and currentSpeed >= nextTh * 0.9 then
			local now = os.clock()
			local th = nextTh :: number
			if now - lastAlmostSpeedToastClock >= ALMOST_SPEED_TOAST_COOLDOWN_SEC or lastAlmostSpeedToastThreshold ~= th then
				lastAlmostSpeedToastClock = now
				lastAlmostSpeedToastThreshold = th
				local pct = math.floor(math.clamp((currentSpeed / th) * 100, 0, 100))
				local tpl = SocialFeedConfig.pickLine("AlmostNextTier")
				local line = tpl:gsub("{PERCENT}", tostring(pct)):gsub("{TARGET}", `{th} studs/s`)
				VFXFacade.milestonePopup(line, "almost_there")
			end
		end
	end

	if powerText then
		powerText.Text = tostring(math.floor(currentPower))
	end

	if travelLabel then
		local miles = currentDistance / 5280
		travelLabel.Text = MicrocopyConfig.DrivingHudTravelMilesLine:gsub("{MILES}", string.format("%.1f", miles))
	end
	if lapsLabel then
		lapsLabel.Text = MicrocopyConfig.DrivingHudLapsDrivenLine:gsub("{LAPS}", tostring(currentLaps))
	end

	if steerHintLabel and isVisible then
		tryGetDrivingController()
		local mode = "keyboard"
		if DrivingController and DrivingController.getSteerHintMode then
			mode = DrivingController.getSteerHintMode()
		end
		if mode ~= lastSteerHintMode then
			lastSteerHintMode = mode
			if mode == "touch" then
				steerHintLabel.Text = MicrocopyConfig.DrivingHudSteerHintTouch
			elseif mode == "gamepad" then
				steerHintLabel.Text = MicrocopyConfig.DrivingHudSteerHintGamepad
			else
				steerHintLabel.Text = MicrocopyConfig.DrivingHudSteerHintKeyboard
			end
		end
		steerHintLabel.Visible = true
	elseif steerHintLabel then
		steerHintLabel.Visible = false
		lastSteerHintMode = nil
	end

	if recordFrame and currentDistance > bestDistance then
		recordFrame.Visible = true
	end

	if not hudMilestoneFlashBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudMilestoneFlash then
			local th = DrivingController.popHudMilestoneFlash()
			if type(th) == "number" then
				hudMilestoneFlashBusy = true
				SoundFacade.playOneShot("milestone")
				local heads = SpeedMilestoneConfig.CelebrationText[th]
				local flavors = SpeedMilestoneConfig.FlavorText[th]
				local headline = if heads and #heads > 0 then heads[math.random(1, #heads)] else `SPEED {th}!`
				local flavor = if flavors and #flavors > 0 then flavors[math.random(1, #flavors)] else ""
				local col = milestoneCelebrationColor(th)
				local lbl = Instance.new("TextLabel")
				lbl.Name = "SpeedMilestoneFlash"
				lbl.BackgroundTransparency = 1
				lbl.Size = UDim2.new(0.9, 0, 0, 72)
				lbl.AnchorPoint = Vector2.new(0.5, 0.5)
				lbl.Position = UDim2.new(0.5, 0, 0.22, 0)
				lbl.Font = Enum.Font.GothamBlack
				lbl.TextSize = 32
				lbl.TextColor3 = col
				lbl.TextStrokeTransparency = 0.45
				lbl.TextStrokeColor3 = col:Lerp(Color3.new(0, 0, 0), 0.65)
				lbl.TextWrapped = true
				lbl.Text = if flavor ~= "" then headline .. "\n" .. flavor else headline
				lbl.ZIndex = 20
				lbl.Parent = drivingUI
				local sc = Instance.new("UIScale")
				sc.Scale = 0.35
				sc.Parent = lbl
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
				local flexLine = SpeedMilestoneConfig.FlexText[th]
				if type(flexLine) == "string" and flexLine ~= "" then
					task.delay(1.0, function()
						if not drivingUI or not drivingUI.Parent then
							return
						end
						local fl = Instance.new("TextLabel")
						fl.Name = "SpeedMilestoneFlex"
						fl.BackgroundTransparency = 1
						fl.Size = UDim2.new(0.88, 0, 0, 36)
						fl.AnchorPoint = Vector2.new(0.5, 0.5)
						fl.Position = UDim2.new(0.5, 0, 0.31, 10)
						fl.Font = Enum.Font.GothamBold
						fl.TextSize = 17
						fl.TextColor3 = Color3.fromRGB(235, 225, 255)
						fl.TextStrokeTransparency = 0.55
						fl.TextStrokeColor3 = Color3.fromRGB(30, 15, 40)
						fl.TextWrapped = true
						fl.RichText = true
						fl.Text = "<i>" .. flexLine .. "</i>"
						fl.TextTransparency = 1
						fl.ZIndex = 19
						fl.Parent = drivingUI
						TweenService:Create(fl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 0,
							Position = UDim2.new(0.5, 0, 0.31, 0),
						}):Play()
						task.delay(1.6, function()
							if fl.Parent then
								TweenService:Create(fl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									TextTransparency = 1,
									TextStrokeTransparency = 1,
								}):Play()
							end
						end)
						task.delay(1.95, function()
							if fl.Parent then
								fl:Destroy()
							end
						end)
					end)
				end
				task.delay(0.22, function()
					if lbl.Parent then
						TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 1,
							TextStrokeTransparency = 1,
						}):Play()
					end
				end)
				task.delay(0.52, function()
					hudMilestoneFlashBusy = false
					if lbl.Parent then
						lbl:Destroy()
					end
				end)
			end
		end
	end

	if not hudNearMissFlashBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudNearMissFlash then
			local nm = DrivingController.popHudNearMissFlash()
			if type(nm) == "string" and nm ~= "" then
				hudNearMissFlashBusy = true
				SoundFacade.playOneShot("near_miss")
				local _, _, nearMissY = getHudFlashYPositions()
				local lbl = Instance.new("TextLabel")
				lbl.Name = "NearMissHudFlash"
				lbl.BackgroundTransparency = 1
				lbl.Size = UDim2.new(0.88, 0, 0, 40)
				lbl.AnchorPoint = Vector2.new(0.5, 0.5)
				lbl.Position = UDim2.new(0.5, 0, nearMissY, 0)
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 22
				lbl.TextColor3 = Color3.fromRGB(255, 245, 200)
				lbl.TextStrokeTransparency = 0.35
				lbl.TextStrokeColor3 = Color3.fromRGB(40, 20, 80)
				lbl.Text = nm
				lbl.ZIndex = 19
				lbl.Parent = drivingUI
				local sc = Instance.new("UIScale")
				sc.Scale = 0.3
				sc.Parent = lbl
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				task.delay(0.6, function()
					if lbl.Parent then
						TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 1,
							TextStrokeTransparency = 1,
						}):Play()
					end
				end)
				task.delay(0.95, function()
					hudNearMissFlashBusy = false
					if lbl.Parent then
						lbl:Destroy()
					end
				end)
			end
		end
	end

	if not hudComboCelebrationBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudComboCelebration then
			local pack = DrivingController.popHudComboCelebration()
			if type(pack) == "table" and type((pack :: any).headline) == "string" then
				local headline = (pack :: any).headline
				local body = if type((pack :: any).body) == "string" then (pack :: any).body else ""
				local comboCount = if type((pack :: any).comboCount) == "number" then (pack :: any).comboCount else 2
				if headline ~= "" then
					hudComboCelebrationBusy = true
					local comboY, _, _ = getHudFlashYPositions()
					local pitch = math.clamp(1 + 0.04 * math.max(0, comboCount - 2), 0.88, 1.38)
					SoundFacade.playOneShot("combo", pitch)
					local holder = Instance.new("Frame")
					holder.Name = "ComboCelebrationFlash"
					holder.BackgroundTransparency = 1
					holder.Size = UDim2.new(0.88, 0, 0, 72)
					holder.AnchorPoint = Vector2.new(0.5, 0.5)
					holder.Position = UDim2.new(0.5, 0, comboY, 0)
					holder.ZIndex = 21
					holder.Parent = drivingUI
					local hl = Instance.new("TextLabel")
					hl.BackgroundTransparency = 1
					hl.Size = UDim2.new(1, 0, 0, body ~= "" and 36 or 44)
					hl.Position = UDim2.new(0, 0, 0, 0)
					hl.Font = Enum.Font.GothamBlack
					hl.TextSize = 26
					hl.TextColor3 = Color3.fromRGB(255, 220, 100)
					hl.TextStrokeTransparency = 0.4
					hl.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
					hl.TextWrapped = true
					hl.Text = headline
					hl.Parent = holder
					if body ~= "" then
						local bl = Instance.new("TextLabel")
						bl.BackgroundTransparency = 1
						bl.Size = UDim2.new(1, 0, 0, 32)
						bl.Position = UDim2.new(0, 0, 0, 38)
						bl.Font = Enum.Font.Gotham
						bl.TextSize = 15
						bl.TextColor3 = Color3.fromRGB(255, 245, 220)
						bl.TextStrokeTransparency = 0.5
						bl.TextWrapped = true
						bl.Text = body
						bl.Parent = holder
					end
					local sc = Instance.new("UIScale")
					sc.Scale = 0.4
					sc.Parent = holder
					TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					task.delay(0.65, function()
						if holder.Parent then
							TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								BackgroundTransparency = 1,
							}):Play()
							for _, d in holder:GetDescendants() do
								if d:IsA("TextLabel") then
									TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
										TextTransparency = 1,
										TextStrokeTransparency = 1,
									}):Play()
								end
							end
						end
					end)
					task.delay(1.05, function()
						hudComboCelebrationBusy = false
						if holder.Parent then
							holder:Destroy()
						end
					end)
				end
			end
		end
	end

	if not hudComboBreakBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudComboBreak then
			local pack = DrivingController.popHudComboBreak()
			if type(pack) == "table" and type((pack :: any).headline) == "string" then
				local headline = (pack :: any).headline
				local body = if type((pack :: any).body) == "string" then (pack :: any).body else ""
				if headline ~= "" then
					hudComboBreakBusy = true
					local _, breakY = getHudFlashYPositions()
					local holder = Instance.new("Frame")
					holder.Name = "ComboBreakFlash"
					holder.BackgroundTransparency = 1
					holder.Size = UDim2.new(0.88, 0, 0, 72)
					holder.AnchorPoint = Vector2.new(0.5, 0.5)
					holder.Position = UDim2.new(0.5, 0, breakY, 0)
					holder.ZIndex = 21
					holder.Parent = drivingUI
					local hl = Instance.new("TextLabel")
					hl.BackgroundTransparency = 1
					hl.Size = UDim2.new(1, 0, 0, body ~= "" and 36 or 44)
					hl.Position = UDim2.new(0, 0, 0, 0)
					hl.Font = Enum.Font.GothamBlack
					hl.TextSize = 24
					hl.TextColor3 = Color3.fromRGB(255, 140, 120)
					hl.TextStrokeTransparency = 0.35
					hl.TextStrokeColor3 = Color3.fromRGB(60, 20, 10)
					hl.TextWrapped = true
					hl.Text = headline
					hl.Parent = holder
					if body ~= "" then
						local bl = Instance.new("TextLabel")
						bl.BackgroundTransparency = 1
						bl.Size = UDim2.new(1, 0, 0, 32)
						bl.Position = UDim2.new(0, 0, 0, 38)
						bl.Font = Enum.Font.Gotham
						bl.TextSize = 15
						bl.TextColor3 = Color3.fromRGB(255, 220, 200)
						bl.TextStrokeTransparency = 0.5
						bl.TextWrapped = true
						bl.Text = body
						bl.Parent = holder
					end
					local sc = Instance.new("UIScale")
					sc.Scale = 0.4
					sc.Parent = holder
					TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					task.delay(0.65, function()
						if holder.Parent then
							for _, d in holder:GetDescendants() do
								if d:IsA("TextLabel") then
									TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
										TextTransparency = 1,
										TextStrokeTransparency = 1,
									}):Play()
								end
							end
						end
					end)
					task.delay(1.05, function()
						hudComboBreakBusy = false
						if holder.Parent then
							holder:Destroy()
						end
					end)
				end
			end
		end
	end

	if not hudTierNameFlashBusy and drivingUI and drivingUI.Visible and #tierNameFlashQueue > 0 then
		local tierLine = table.remove(tierNameFlashQueue, 1)
		if tierLine ~= "" then
			hudTierNameFlashBusy = true
			SoundFacade.playOneShot("speed_tier")
			local lbl = Instance.new("TextLabel")
			lbl.Name = "SpeedTierNameFlash"
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(0.95, 0, 0, 36)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.new(0.5, 0, 0.12, 0)
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 28
			lbl.TextColor3 = Color3.fromRGB(120, 220, 255)
			lbl.TextStrokeTransparency = 0.35
			lbl.TextStrokeColor3 = Color3.fromRGB(20, 40, 80)
			lbl.Text = tierLine
			lbl.ZIndex = 18
			lbl.Parent = drivingUI
			local sc = Instance.new("UIScale")
			sc.Scale = 0.5
			sc.Parent = lbl
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
			task.delay(0.55, function()
				if lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				end
			end)
			task.delay(0.95, function()
				hudTierNameFlashBusy = false
				if lbl.Parent then
					lbl:Destroy()
				end
			end)
		end
	end

	if not hudAccelCalloutBusy and drivingUI and drivingUI.Visible and #accelCalloutQueue > 0 then
		local aline = table.remove(accelCalloutQueue, 1)
		if aline ~= "" then
			hudAccelCalloutBusy = true
			local lbl = Instance.new("TextLabel")
			lbl.Name = "AccelCalloutFlash"
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(0, 200, 0, 28)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.new(0.5, 0, 0.62, 0)
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 20
			lbl.TextColor3 = Color3.fromRGB(255, 180, 90)
			lbl.TextStrokeTransparency = 0.4
			lbl.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
			lbl.Text = aline
			lbl.ZIndex = 17
			lbl.Parent = drivingUI
			local sc = Instance.new("UIScale")
			sc.Scale = 1
			sc.Parent = lbl
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.3 }):Play()
			task.delay(0.2, function()
				if sc.Parent then
					TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end)
			task.delay(0.5, function()
				if lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				end
			end)
			task.delay(0.92, function()
				hudAccelCalloutBusy = false
				if lbl.Parent then
					lbl:Destroy()
				end
			end)
		end
	end

	prevRedlineNormStored = redlineNorm
end

function DrivingHUD.init()
	if drivingHudInitDone then
		return
	end
	drivingHudInitDone = true

	local screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	local pInfo = screenGui:WaitForChild("PlayerInfo") :: Frame
	drivingUI = pInfo:WaitForChild("DrivingUI") :: Frame
	drivingUI.Visible = false

	local function applyDrivingUiBottomSafe()
		local sg = playerGui:FindFirstChild("DACMain") :: ScreenGui?
		if not sg then
			return
		end
		local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(sg)
		local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
		local pad = drivingUI:FindFirstChild("DACDrivingUiSafePad") :: UIPadding?
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "DACDrivingUiSafePad"
			pad.Parent = drivingUI
		end
		-- Top/sides come from PlayerInfo safe pad; bottom is needed when ActionBar is hidden during a run (home indicator).
		pad.PaddingBottom = UDim.new(0, math.floor(b + em + 0.5))
	end
	applyDrivingUiBottomSafe()
	if drivingHudLayoutDisconnect then
		drivingHudLayoutDisconnect()
		drivingHudLayoutDisconnect = nil
	end
	drivingHudLayoutDisconnect = HudSafeArea.onLayoutChanged(applyDrivingUiBottomSafe)

	local gasFrame = drivingUI:FindFirstChild("Gas")
	if gasFrame then
		gasBar = gasFrame:FindFirstChild("Bar") :: ImageLabel
		gasBackground = gasFrame:FindFirstChild("Background") :: ImageLabel
		local textFrame = gasFrame:FindFirstChild("Text")
		if textFrame then
			gasText = textFrame:FindFirstChild("TextLabel") :: TextLabel
		end
		local stroke = gasFrame:FindFirstChild("FuelPanicStroke") :: UIStroke?
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "FuelPanicStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Thickness = 2
			stroke.Transparency = 1
			stroke.Parent = gasFrame
		end
		gasPanicStroke = stroke

		local goldenStroke = gasFrame:FindFirstChild("GoldenGlowStroke") :: UIStroke?
		if not goldenStroke then
			goldenStroke = Instance.new("UIStroke")
			goldenStroke.Name = "GoldenGlowStroke"
			goldenStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			goldenStroke.LineJoinMode = Enum.LineJoinMode.Round
			goldenStroke.Color = Color3.fromRGB(255, 215, 60)
			goldenStroke.Thickness = 3
			goldenStroke.Transparency = 1
			goldenStroke.Parent = gasFrame
		end
		gasGoldenStroke = goldenStroke
	end

	local speedFrame = drivingUI:FindFirstChild("Speed")
	if speedFrame and speedFrame:IsA("Frame") then
		speedHudFrame = speedFrame
		speedText = speedFrame:FindFirstChild("TextLabel") :: TextLabel
		local sc = speedFrame:FindFirstChildOfClass("UIScale")
		if not sc then
			sc = Instance.new("UIScale")
			sc.Scale = 1
			sc.Parent = speedFrame
		end
		speedUIScale = sc
		local rStroke = speedFrame:FindFirstChild("SpeedRedlineStroke") :: UIStroke?
		if not rStroke then
			rStroke = Instance.new("UIStroke")
			rStroke.Name = "SpeedRedlineStroke"
			rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rStroke.LineJoinMode = Enum.LineJoinMode.Round
			rStroke.Color = Color3.fromRGB(255, 52, 48)
			rStroke.Thickness = 2.4
			rStroke.Transparency = 1
			rStroke.Parent = speedFrame
		end
		speedRedlineStroke = rStroke
	end

	local powerFrame = drivingUI:FindFirstChild("Power")
	if powerFrame then
		local pt = powerFrame:FindFirstChild("Text")
		if pt then
			powerText = pt:FindFirstChild("TextLabel") :: TextLabel
		end
	end

	travelFrame = drivingUI:FindFirstChild("Travel") :: ImageLabel
	if travelFrame then
		travelFrame.Visible = false
		travelLabel = travelFrame:FindFirstChild("Travel") :: TextLabel
		lapsLabel = travelFrame:FindFirstChild("Laps") :: TextLabel
		local rec = travelFrame:FindFirstChild("Record")
		if rec then
			recordFrame = rec
			rec.Visible = false
		end
	end

	local sh = drivingUI:FindFirstChild("SteerHint")
	if sh and sh:IsA("TextLabel") then
		steerHintLabel = sh
	else
		local lbl = Instance.new("TextLabel")
		lbl.Name = "SteerHint"
		lbl.BackgroundTransparency = 1
		lbl.AnchorPoint = Vector2.new(0.5, 1)
		lbl.Position = UDim2.new(0.5, 0, 1, -10)
		lbl.Size = UDim2.new(0.92, 0, 0, 24)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0.45
		lbl.TextStrokeColor3 = Color3.fromRGB(20, 20, 40)
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.ZIndex = 12
		lbl.Visible = false
		lbl.Parent = drivingUI
		steerHintLabel = lbl
	end

	tryGetDrivingController()

	-- POLA-432: optional pre-built MobileSteerPedals → lateral intensity (no throttle/brake gameplay)
	local function wireMobileSteerPedals()
		local root = drivingUI:FindFirstChild("MobileSteerPedals")
		if not root or not root:IsA("Frame") then
			return
		end
		mobilePedalsRoot = root
		root.Visible = false

		local function prepSide(side: Instance, green: boolean): (GuiObject?, UIScale?, UIGradient?)
			if not side:IsA("GuiObject") then
				return nil, nil, nil
			end
			local fill = side:FindFirstChild("Fill")
			if not fill or not fill:IsA("GuiObject") then
				return nil, nil, nil
			end
			fill.AnchorPoint = Vector2.new(0.5, 1)
			fill.Position = UDim2.new(0.5, 0, 1, 0)
			fill.Size = UDim2.new(1, 0, 0, 0)
			fill.BorderSizePixel = 0
			local grad = fill:FindFirstChildOfClass("UIGradient")
			if not grad then
				grad = Instance.new("UIGradient")
				grad.Rotation = 90
				if green then
					grad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 95, 55)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 165)),
					})
				else
					grad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 28, 36)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 115, 95)),
					})
				end
				grad.Parent = fill
			end
			local sc = side:FindFirstChildOfClass("UIScale")
			if not sc then
				sc = Instance.new("UIScale")
				sc.Scale = 1
				sc.Parent = side
			end
			return fill, sc, grad
		end

		local left = root:FindFirstChild("Left")
		if left then
			local f, s, g = prepSide(left, true)
			mobilePedalLeftFill = f
			mobilePedalLeftScale = s
			mobilePedalLeftGrad = g
			if left:IsA("GuiObject") then
				mobilePedalLeftStroke = left:FindFirstChildOfClass("UIStroke")
			end
		end
		local right = root:FindFirstChild("Right")
		if right then
			local f, s, g = prepSide(right, false)
			mobilePedalRightFill = f
			mobilePedalRightScale = s
			mobilePedalRightGrad = g
			if right:IsA("GuiObject") then
				mobilePedalRightStroke = right:FindFirstChildOfClass("UIStroke")
			end
		end
	end

	local function wireHeadlightsToggle()
		local lt = drivingUI:FindFirstChild("LightsToggle")
		if not lt or not lt:IsA("Frame") then
			return
		end
		local btn = lt:FindFirstChild("Btn") :: GuiButton?
		if not btn then
			return
		end
		local offIcon = lt:FindFirstChild("Off") :: ImageLabel?
		local lowIcon = lt:FindFirstChild("Low") :: ImageLabel?
		local highIcon = lt:FindFirstChild("High") :: ImageLabel?
		local glow = lt:FindFirstChild("ActiveGlow") :: UIStroke?
		local scale = lt:FindFirstChildOfClass("UIScale") :: UIScale?
		if not scale then
			local ns = Instance.new("UIScale")
			ns.Scale = 1
			ns.Parent = lt
			scale = ns
		end

		local function applyUi()
			local mode = headlightHudMode
			if offIcon then
				offIcon.Visible = mode == 0
			end
			if lowIcon then
				lowIcon.Visible = mode == 1
			end
			if highIcon then
				highIcon.Visible = mode == 2
			end
			if glow then
				glow.Transparency = if mode == 0 then 1 else 0.35
			end
		end

		headlightApplyUi = applyUi

		local function bumpJuice()
			TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
			task.delay(0.1, function()
				if scale.Parent then
					TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end)
		end

		btn.MouseButton1Click:Connect(function()
			tryGetDrivingController()
			local prev = headlightHudMode
			headlightHudMode = (headlightHudMode + 1) % 3
			bumpJuice()
			if prev == 0 and headlightHudMode > 0 then
				SoundFacade.playOneShot("lights_toggle_on")
			elseif headlightHudMode == 0 then
				SoundFacade.playOneShot("lights_toggle_off")
			elseif headlightHudMode == 2 then
				SoundFacade.playOneShot("lights_toggle_on")
			else
				SoundFacade.playOneShot("lights_toggle_off")
			end
			applyUi()
			if DrivingController and DrivingController.setHeadlightMode then
				DrivingController.setHeadlightMode(headlightHudMode)
			end
		end)

		applyUi()
	end

	local function wireHornHud()
		local hornFrame = drivingUI:FindFirstChild("Horn") :: Frame?
		if not hornFrame then
			return
		end
		local btn = hornFrame:FindFirstChild("Btn") :: GuiButton?
		if not btn then
			return
		end
		local scale = hornFrame:FindFirstChildOfClass("UIScale") :: UIScale?
		if not scale then
			local ns = Instance.new("UIScale")
			ns.Scale = 1
			ns.Parent = hornFrame
			scale = ns
		end

		local function punchHornIcon()
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.14 }):Play()
			task.delay(0.08, function()
				if scale.Parent then
					TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end)
		end

		task.defer(function()
			tryGetDrivingController()
			if DrivingController and DrivingController.registerHornHudPunch then
				DrivingController.registerHornHudPunch(punchHornIcon)
			end
		end)

		btn.MouseButton1Down:Connect(function()
			tryGetDrivingController()
			if DrivingController and DrivingController.honkUiButtonDown then
				DrivingController.honkUiButtonDown()
			end
		end)
		btn.MouseButton1Up:Connect(function()
			tryGetDrivingController()
			if DrivingController and DrivingController.honkUiButtonUp then
				DrivingController.honkUiButtonUp()
			end
		end)
	end

	wireMobileSteerPedals()
	wireHeadlightsToggle()
	wireHornHud()

	local function wireHandbrakeHud()
		local root = drivingUI:FindFirstChild("HandbrakeHud")
		if not root or not root:IsA("Frame") then
			return
		end
		local icon = root:FindFirstChild("Icon") :: ImageLabel?
		if not icon then
			return
		end
		handbrakeHudRoot = root
		handbrakeHudIcon = icon
		icon.ImageColor3 = C_HB_NEUTRAL
		local sc = root:FindFirstChildOfClass("UIScale") :: UIScale?
		if not sc then
			sc = Instance.new("UIScale")
			sc.Scale = 1
			sc.Parent = root
		end
		handbrakeHudScale = sc
		handbrakeHudRim = root:FindFirstChild("Rim") :: UIStroke?
		if handbrakeHudRim then
			handbrakeHudRim.Transparency = 1
		end
		local btn = root:FindFirstChild("Btn") :: GuiButton?
		if btn then
			btn.MouseButton1Down:Connect(function()
				tryGetDrivingController()
				if DrivingController and DrivingController.handbrakeUiButtonDown then
					DrivingController.handbrakeUiButtonDown()
				end
			end)
			btn.MouseButton1Up:Connect(function()
				tryGetDrivingController()
				if DrivingController and DrivingController.handbrakeUiButtonUp then
					DrivingController.handbrakeUiButtonUp()
				end
			end)
		end
	end

	wireHandbrakeHud()

	local function wireVehicleReset()
		local root = drivingUI:FindFirstChild("VehicleReset")
		if not root or not root:IsA("Frame") then
			return
		end
		vehicleResetRoot = root
		local btn = root:FindFirstChild("Btn") :: GuiButton?
		if btn then
			vehicleResetBtn = btn
			btn.MouseButton1Click:Connect(function()
				tryGetDrivingController()
				if DrivingController and DrivingController.vehicleResetIntent then
					DrivingController.vehicleResetIntent()
				end
			end)
		end
		local fill = root:FindFirstChild("CooldownFill")
		if fill and fill:IsA("Frame") then
			vehicleResetCooldownFill = fill
			fill.Size = UDim2.new(0, 0, 1, 0)
		end
		local tl = root:FindFirstChild("TimerLabel") :: TextLabel?
		if not tl then
			tl = root:FindFirstChild("Timer") :: TextLabel?
		end
		if tl then
			vehicleResetTimerLabel = tl
			tl.Visible = false
		end
		local st = root:FindFirstChild("Status") :: TextLabel?
		if st then
			vehicleResetStatusLabel = st
			st.Visible = false
		end
	end

	wireVehicleReset()

	local function wireStopButton()
		local stopRoot = drivingUI:FindFirstChild("StopRun") :: Frame?
		if not stopRoot then
			stopRoot = Instance.new("Frame")
			stopRoot.Name = "StopRun"
			stopRoot.BackgroundTransparency = 1
			stopRoot.AnchorPoint = Vector2.new(1, 0)
			stopRoot.Position = UDim2.new(1, -8, 0, 8)
			stopRoot.Size = UDim2.new(0, 80, 0, 32)
			stopRoot.ZIndex = 15
			stopRoot.Parent = drivingUI
		end
		local stopBtn = stopRoot:FindFirstChild("Btn") :: TextButton?
		if not stopBtn then
			stopBtn = Instance.new("TextButton")
			stopBtn.Name = "Btn"
			stopBtn.Size = UDim2.new(1, 0, 1, 0)
			stopBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
			stopBtn.BackgroundTransparency = 0.25
			stopBtn.Font = Enum.Font.GothamBold
			stopBtn.TextSize = 14
			stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			stopBtn.Text = "STOP"
			stopBtn.ZIndex = 16
			stopBtn.AutoButtonColor = true
			stopBtn.Parent = stopRoot
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = stopBtn
		end
		stopBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			Remotes.getEvent("EndRun"):FireServer()
		end)
	end

	wireStopButton()

	tryGetDrivingController()
	if DrivingController and DrivingController.registerEngineIgnitionFx then
		DrivingController.registerEngineIgnitionFx(function()
			DrivingHUD.flashEngineIgnition()
		end)
	end

	RunService.RenderStepped:Connect(render)

	Remotes.getEvent("StartRun").OnClientEvent:Connect(function(runInfo)
		tryGetDrivingController()
		DrivingHUD.show(runInfo.stats)
	end)

	Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
		if currentDistance > bestDistance then
			bestDistance = currentDistance
		end
		DrivingHUD.hide()
	end)

	Players.PlayerRemoving:Connect(function(p)
		if p == player then
			if drivingHudLayoutDisconnect then
				drivingHudLayoutDisconnect()
				drivingHudLayoutDisconnect = nil
			end
		end
	end)

	Constants.bootLog("[DAC] DrivingHUD initialized (using DACMain.DrivingUI)")
end

return DrivingHUD
