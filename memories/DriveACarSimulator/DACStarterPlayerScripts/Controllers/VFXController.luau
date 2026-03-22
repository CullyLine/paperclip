--!strict
--[[
	Client VFX: dual speed trails, boost overlay, speed rush edge/chroma overlay,
	fuel panic vignette + HUD-adjacent sounds, hatch timeline, pet orbit glow,
	ambient world particles, lap flash, world transitions, mobile LOD,
	run distance milestones, career milestone popups, near-miss lane feedback,
	purchase / car unlock celebrations, stat level-up cascade,
	quest completion fireworks, battle pass tier-up fanfare.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local RebirthMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthMilestoneConfig"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local WorldUnlockConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldUnlockConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SpeedMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedMilestoneConfig"))
local NearMissCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("NearMissCopyConfig"))
local FailureFeedback = require(DAC:WaitForChild("FailureFeedback"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local HatchCrackVisualSpec = require(DAC:WaitForChild("Config"):WaitForChild("HatchCrackVisualSpec"))

local VFXController = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local TRAIL_BUDGET = 100 -- both wheels + boost star streak

local WORLD_TRAIL_NEON = {
	grasslands = Color3.fromRGB(130, 255, 150),
	desert = Color3.fromRGB(255, 170, 70),
	frozen = Color3.fromRGB(130, 220, 255),
	neon = Color3.fromRGB(255, 55, 200),
}

local runActive = false
local activeWorldId = "grasslands"
local trailPart: BasePart? = nil
local trailEmitterL: ParticleEmitter? = nil
local trailEmitterR: ParticleEmitter? = nil
local boostEmitter: ParticleEmitter? = nil
local trailAttachmentL: Attachment? = nil
local trailAttachmentR: Attachment? = nil
local boostAttachment: Attachment? = nil

local screenGui: ScreenGui? = nil
local flashLayer: Frame? = nil
local lapFlashLayer: Frame? = nil
local vignetteLayer: Frame? = nil
local popupPool: { TextLabel } = {}
local popupIndex = 0
local shakeToken = 0

-- During runs, DrivingController applies this offset after computing the chase camera (see getRunCameraShakeOffset).
local runShakeSeq = 0
local runShakeState: { seq: number, t0: number, dur: number, int: number }? = nil
local fuelPanicDeepShake = false

-- Per-car stat snapshots (avoid duplicate level-up VFX on first snapshot)
local lastCarStatLevels: { [string]: { gas: number, power: number, speed: number } } = {}
local lastOwnedCarIds: { [string]: boolean } = {}
local carsOwnershipSeeded = false

local baseCameraFov = 70
local boostFovTween: Tween? = nil
local boostActive = false
local dofEffect: DepthOfField? = nil

-- LOD: 1 low, 2 mid, 3 high
local lodTier = 3
local fpsFrameAccum = 0
local fpsSecondClock = 0
local lowFpsStreakSeconds = 0
local lastWorldForTransition: string? = nil

-- Distance milestones (per run; reset in onRunStarted)
local lastDistK1 = 0
local lastDistK5 = 0
local lastDistK10 = 0

-- Career milestones (non-persisted; baseline from first DataUpdate)
type CareerSnap = {
	petCount: number,
	rebirths: number,
	coins: number,
	worlds: { [string]: boolean },
	discoveredPets: { [string]: boolean },
}
local careerSnap: CareerSnap? = nil

local lastCloseCallClock = 0.0
local nearMissPendingRecover = false
local isFirstRunOfDayActive = false

-- Egg hatch: consecutive rare+ pulls (client-only; resets on common/uncommon)
local eggRareStreak = 0

-- Celebration dedup (RebirthPanel + onPlayerDataUpdate; Store car purchase + DataUpdate)
local lastRebirthCelebrated = -1
local celebratedCarIds: { [string]: boolean } = {}

-- Almost-there nudges (60s cooldown per kind: rebirth | world | collection)
local lastAlmostNudgeAt: { [string]: number } = {}
local ALMOST_NUDGE_COOLDOWN_SEC = 60

-- Server-wide rare+ hatch banner (queue + throttle)
type ServerDropQueued = { playerName: string, petName: string, rarity: string, userId: number }
local serverDropQueue: { ServerDropQueued } = {}
local serverDropShowing = false
local serverDropLastStartClock = 0.0
local serverDropPendingDrain: thread? = nil
local SERVER_DROP_THROTTLE_SEC = 5
local SERVER_DROP_MAX_QUEUE = 3
local SERVER_DROP_TOP_PX = 56

-- Speed rush screen overlay (chromatic-style edge tint)
local speedRushEdgeFrame: Frame? = nil
local speedRushChromaFrame: Frame? = nil
local speedRushSmoothed = 0
local speedRushChromaSmoothed = 0
local speedMilestoneRushBoostUntil = 0.0

-- Fuel panic: vignette + sounds + micro-shake
local fuelPanicVignette: Frame? = nil
local fuelPanicPrevGas = 1

local ambientFolder: Folder? = nil
local ambientEmitters: { ParticleEmitter } = {}
local ambientRunning = false

-- Run coin combo (visual only; driven by client distance vs payout formula)
local runPowerForCombo = 0
local cachedPetModifier = 1
local lastVirtualCoinFloor = 0
local coinComboStreak = 0
local lastCoinPickupClock = 0.0
local lastCoinPickupSfxClock = 0.0
local comboResetToken = 0
local comboLabel: TextLabel? = nil
local comboUIScale: UIScale? = nil

local petGlowByUid: {
	[ string ]: {
		light: PointLight?,
		motes: ParticleEmitter?,
		orbitStars: ParticleEmitter?,
		attach: Attachment,
	},
} = {}

local function currencyColor(currencyType: string): Color3
	local row = Constants.CURRENCY_DISPLAY[currencyType]
	return if row then row.color else Color3.fromRGB(255, 255, 255)
end

local function qualityLodSeed(): number
	local ok, q = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	if ok and type(q) == "number" then
		if q <= 5 then
			return 1
		elseif q <= 10 then
			return 2
		end
	end
	return 3
end

local function lodTrailRateMul(): number
	if lodTier <= 1 then
		return 0.5
	elseif lodTier == 2 then
		return 0.75
	end
	return 1
end

local function lodBurstMul(): number
	if lodTier <= 1 then
		return 0.5
	elseif lodTier == 2 then
		return 0.75
	end
	return 1
end

local function lodPetMotesMax(base: number): number
	if lodTier <= 1 then
		return math.min(8, base)
	elseif lodTier == 2 then
		return math.min(12, base)
	end
	return base
end

local function trailColorFromSpeed(speed: number): Color3
	if speed < 40 then
		return Color3.fromHex("FFFFFF")
	end
	if speed < 60 then
		return Color3.fromHex("FACC15"):Lerp(Color3.fromHex("FFFFFF"), (60 - speed) / 20)
	end
	if speed < 80 then
		return Color3.fromHex("FB923C"):Lerp(Color3.fromHex("FACC15"), (80 - speed) / 20)
	end
	return Color3.fromHex("EF4444"):Lerp(Color3.fromHex("FB923C"), math.clamp((speed - 80) / 20, 0, 1))
end

local function mythicRainbowSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FF6B6B")),
		ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFD93D")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("6BCB77")),
		ColorSequenceKeypoint.new(0.6, Color3.fromHex("4D96FF")),
		ColorSequenceKeypoint.new(0.8, Color3.fromHex("C084FC")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("FF6B6B")),
	})
end

local function getFlashLayer(): Frame
	if flashLayer and flashLayer.Parent then
		return flashLayer
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "FlashLayer"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Position = UDim2.fromScale(0, 0)
	f.ZIndex = 1000
	f.Active = false
	f.Parent = sg
	flashLayer = f
	return f
end

local function getLapFlashFrame(): Frame
	if lapFlashLayer and lapFlashLayer.Parent then
		return lapFlashLayer
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "LapFlashLayer"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 999
	f.Parent = sg
	lapFlashLayer = f
	return f
end

local function getVignetteFrame(): Frame
	if vignetteLayer and vignetteLayer.Parent then
		return vignetteLayer
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "VignetteLayer"
	f.BackgroundColor3 = Color3.fromHex("0B0F14")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 998
	f.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.75),
	})
	grad.Rotation = 90
	grad.Parent = f
	vignetteLayer = f
	return f
end

local function getSpeedRushEdgeFrame(): Frame
	if speedRushEdgeFrame and speedRushEdgeFrame.Parent then
		return speedRushEdgeFrame
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "SpeedRushEdge"
	f.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 994
	f.Active = false
	f.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 0
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 50)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 160, 70)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 160, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 50)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	grad.Parent = f
	speedRushEdgeFrame = f
	return f
end

local function getSpeedRushChromaFrame(): Frame
	if speedRushChromaFrame and speedRushChromaFrame.Parent then
		return speedRushChromaFrame
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "SpeedRushChroma"
	f.BackgroundColor3 = Color3.fromRGB(255, 60, 120)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 995
	f.Active = false
	f.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 200, 255)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 160)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	grad.Parent = f
	speedRushChromaFrame = f
	return f
end

local function getFuelPanicVignette(): Frame
	if fuelPanicVignette and fuelPanicVignette.Parent then
		return fuelPanicVignette
	end
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local f = Instance.new("Frame")
	f.Name = "FuelPanicVignette"
	f.BackgroundColor3 = Color3.fromRGB(120, 10, 10)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 996
	f.Active = false
	f.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	grad.Parent = f
	fuelPanicVignette = f
	return f
end

local function stopFuelPanicShake()
	fuelPanicDeepShake = false
end

function VFXController.speedRushOverlay(speed: number)
	if not runActive then
		speedRushSmoothed = 0
		speedRushChromaSmoothed = 0
		local e = speedRushEdgeFrame
		if e then
			e.BackgroundTransparency = 1
		end
		local c = speedRushChromaFrame
		if c then
			c.BackgroundTransparency = 1
		end
		return
	end

	local targetEdge = 0
	local targetChroma = 0
	if speed > 80 then
		targetEdge = math.clamp(0.35 + (speed - 80) / 120, 0, 0.95)
		targetChroma = math.clamp((speed - 80) / 60, 0, 1)
	elseif speed > 60 then
		targetEdge = math.clamp((speed - 60) / 20, 0, 1) * 0.55
	end

	local nowClock = os.clock()
	if nowClock < speedMilestoneRushBoostUntil then
		local boost = (speedMilestoneRushBoostUntil - nowClock) / 0.35
		targetEdge = math.min(1, targetEdge + 0.42 * boost)
		targetChroma = math.min(1, targetChroma + 0.25 * boost)
	end

	speedRushSmoothed += (targetEdge - speedRushSmoothed) * 0.15
	speedRushChromaSmoothed += (targetChroma - speedRushChromaSmoothed) * 0.12

	local pulse = 0.88 + 0.12 * math.sin(os.clock() * (2.8 + speed * 0.035))
	local edgeVis = speedRushSmoothed * pulse
	local chromaPulse = 0.82 + 0.18 * math.sin(os.clock() * (5.5 + speed * 0.05))
	local chromaVis = speedRushChromaSmoothed * chromaPulse

	local edge = getSpeedRushEdgeFrame()
	edge.BackgroundTransparency = 1 - edgeVis * 0.55

	local chroma = getSpeedRushChromaFrame()
	if chromaVis > 0.02 then
		chroma.BackgroundTransparency = 1 - chromaVis * 0.42
	else
		chroma.BackgroundTransparency = 1
	end
end

function VFXController.fuelPanic(gasPercent: number)
	if not runActive then
		stopFuelPanicShake()
		local fv = fuelPanicVignette
		if fv then
			fv.BackgroundTransparency = 1
		end
		fuelPanicPrevGas = 1
		return
	end

	local g = math.clamp(gasPercent, 0, 1)
	local prev = fuelPanicPrevGas
	if prev > 0.25 and g <= 0.25 then
		SoundFacade.playOneShot("fuel_warning_25")
	end
	if prev > 0.10 and g <= 0.10 then
		SoundFacade.playOneShot("fuel_warning_10")
	end
	if prev > 0 and g <= 0 then
		SoundFacade.playOneShot("fuel_empty")
		FailureFeedback.fire("fuel_empty", { skipSound = true })
	end
	fuelPanicPrevGas = g

	local fv = getFuelPanicVignette()
	if g >= 0.25 then
		fv.BackgroundTransparency = 1
		stopFuelPanicShake()
	elseif g < 0.05 then
		fv.BackgroundColor3 = Color3.fromRGB(180, 5, 5)
		local deep = 0.55 + 0.12 * math.sin(os.clock() * 10)
		fv.BackgroundTransparency = 1 - deep
		fuelPanicDeepShake = true
	elseif g < 0.10 then
		stopFuelPanicShake()
		fv.BackgroundColor3 = Color3.fromRGB(200, 25, 25)
		local t = 0.35 + 0.08 * math.sin(os.clock() * 7)
		fv.BackgroundTransparency = 1 - t
	else
		stopFuelPanicShake()
		fv.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
		local t = 0.12 + 0.06 * math.sin(os.clock() * 4)
		fv.BackgroundTransparency = 1 - t
	end
end

local function formatStudsComma(n: number): string
	local s = tostring(math.floor(n))
	local result = ""
	local count = 0
	for i = #s, 1, -1 do
		if count > 0 and count % 3 == 0 then
			result = "," .. result
		end
		result = string.sub(s, i, i) .. result
		count += 1
	end
	return result
end

local function countPets(pets: any): number
	if type(pets) ~= "table" then
		return 0
	end
	local n = 0
	for _ in pairs(pets) do
		n += 1
	end
	return n
end

local function cloneWorldMap(w: any): { [string]: boolean }
	local r: { [string]: boolean } = {}
	if type(w) == "table" then
		for k, v in pairs(w) do
			if v == true then
				r[k :: string] = true
			end
		end
	end
	return r
end

local function cloneDiscoveredMap(w: any): { [string]: boolean }
	local r: { [string]: boolean } = {}
	if type(w) == "table" then
		for k, v in pairs(w) do
			if v == true then
				r[k :: string] = true
			end
		end
	end
	return r
end

local function countDiscoveredSpecies(map: { [string]: boolean }): number
	local n = 0
	for _, v in pairs(map) do
		if v then
			n += 1
		end
	end
	return n
end

local function indexPercent(filled: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.floor((100 * filled) / total)
end

local function screenFlash(color: Color3, duration: number, peakTransparency: number)
	local f = getFlashLayer()
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1
	local tw = TweenService:Create(
		f,
		TweenInfo.new(duration * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = peakTransparency }
	)
	local tw2 = TweenService:Create(
		f,
		TweenInfo.new(duration * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	tw:Play()
	tw.Completed:Connect(function()
		tw2:Play()
	end)
end

local function cameraShake(intensity: number, duration: number)
	if runActive then
		runShakeSeq += 1
		runShakeState = { seq = runShakeSeq, t0 = os.clock(), dur = duration, int = intensity }
		return
	end

	shakeToken += 1
	local token = shakeToken
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local start = cam.CFrame
	local t0 = os.clock()
	while os.clock() - t0 < duration and token == shakeToken do
		local w = (1 - (os.clock() - t0) / duration) * intensity
		cam.CFrame = start * CFrame.new((math.random() - 0.5) * w * 0.4, (math.random() - 0.5) * w * 0.4, 0)
		task.wait()
	end
	if token == shakeToken and cam then
		cam.CFrame = start
	end
end

function VFXController.cameraShake(intensity: number, duration: number)
	cameraShake(intensity, duration)
end

function VFXController.getRunCameraShakeOffset(): Vector3
	local off = Vector3.zero
	if runActive and runShakeState and runShakeState.seq == runShakeSeq then
		local elapsed = os.clock() - runShakeState.t0
		if elapsed < runShakeState.dur then
			local w = (1 - elapsed / runShakeState.dur) * runShakeState.int
			off += Vector3.new((math.random() - 0.5) * w * 0.4, (math.random() - 0.5) * w * 0.4, 0)
		end
	end
	if runActive and fuelPanicDeepShake then
		local w = 0.05
		off += Vector3.new((math.random() - 0.5) * w, (math.random() - 0.5) * w, 0)
	end
	return off
end

local CELEBRATION_Z = 1200

local function getCelebrationLayer(): Frame
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	local existing = sg:FindFirstChild("CelebrationLayer")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local f = Instance.new("Frame")
	f.Name = "CelebrationLayer"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = CELEBRATION_Z
	f.Active = false
	f.Parent = sg
	return f
end

local function spawnPurchaseConfetti()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = cam
	att.Position = Vector3.new(0, 3, -10)
	local mul = lodBurstMul()
	local conf = Instance.new("ParticleEmitter")
	conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	conf.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 180)),
	})
	conf.Lifetime = NumberRange.new(0.9, 1.6)
	conf.Speed = NumberRange.new(10, 32)
	conf.SpreadAngle = Vector2.new(180, 180)
	conf.Acceleration = Vector3.new(0, -38, 0)
	conf.Drag = 0.5
	conf.Rate = 0
	conf.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.4, 0.45),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	conf.LightEmission = 0.75
	conf.Parent = att
	conf:Emit(math.floor(36 * mul))
	task.delay(2.8, function()
		att:Destroy()
	end)
end

function VFXController.purchaseCelebration(productType: string, tier: string?, carIdForCar: string?)
	if string.lower(productType) == "car" then
		if type(carIdForCar) == "string" and carIdForCar ~= "" then
			local def = CarConfig.Cars[carIdForCar]
			local nm = if def and type(def.name) == "string" then def.name else carIdForCar
			VFXFacade.carUnlockCelebration(carIdForCar, nm)
		end
		return
	end

	local sg = screenGui
	if not sg then
		return
	end
	local isRobux = string.lower(productType) == "robux"
	local isVip = tier == "vip" or string.lower(productType) == "vip"
	local headline = if isVip then "VIP UNLOCKED!" else "PURCHASED!"
	if isRobux and type(tier) == "string" and tier ~= "" then
		headline = tier
	end

	screenFlash(Color3.fromRGB(255, 220, 100), 0.3, 0.42)
	task.spawn(function()
		cameraShake(0.15, 0.2)
	end)
	SoundFacade.playOneShot("purchase")
	spawnPurchaseConfetti()

	local layer = getCelebrationLayer()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.9, 0, 0, 96)
	title.Position = UDim2.new(0.05, 0, 0.38, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 56
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.TextStrokeColor3 = Color3.fromRGB(120, 70, 10)
	title.TextStrokeTransparency = 0.35
	title.Text = headline
	title.ZIndex = CELEBRATION_Z + 2
	title.Parent = layer
	local sc = Instance.new("UIScale")
	sc.Scale = 0.35
	sc.Parent = title
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
	task.delay(0.35, function()
		if sc.Parent then
			TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	TweenService:Create(title, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		title:Destroy()
	end)

	if isRobux and type(carIdForCar) == "string" and carIdForCar ~= "" then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.9, 0, 0, 40)
		sub.Position = UDim2.new(0.05, 0, 0.46, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 28
		sub.TextColor3 = Color3.fromRGB(255, 235, 180)
		sub.TextStrokeColor3 = Color3.fromRGB(80, 50, 10)
		sub.TextStrokeTransparency = 0.4
		sub.Text = carIdForCar
		sub.ZIndex = CELEBRATION_Z + 2
		sub.Parent = layer
		TweenService:Create(sub, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.2, function()
			sub:Destroy()
		end)
	end

	if isVip then
		local border = Instance.new("Frame")
		border.Name = "RainbowPulse"
		border.Size = UDim2.fromScale(1, 1)
		border.BackgroundTransparency = 1
		border.ZIndex = CELEBRATION_Z + 1
		border.Parent = layer
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 10
		stroke.Transparency = 0.15
		stroke.Parent = border
		local grad = Instance.new("UIGradient")
		grad.Color = mythicRainbowSequence()
		grad.Rotation = 0
		grad.Parent = stroke
		local t0 = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			if not border.Parent then
				if conn then
					conn:Disconnect()
				end
				return
			end
			local elapsed = os.clock() - t0
			if elapsed >= 3 then
				if conn then
					conn:Disconnect()
				end
				TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				task.delay(0.4, function()
					border:Destroy()
				end)
				return
			end
			grad.Rotation = (elapsed * 120) % 360
			local pulse = 0.65 + 0.35 * math.sin(elapsed * 7)
			stroke.Transparency = 0.1 + 0.15 * (1 - pulse)
		end)
	end
end

local function questRewardLine(rewardType: string, rewardAmount: number): (string, Color3)
	local t = string.lower(rewardType)
	if t == "season_xp" or t == "xp" then
		return `+{Utils.formatNumber(rewardAmount)} Season XP`, Color3.fromRGB(52, 211, 153)
	end
	local row = Constants.CURRENCY_DISPLAY[t]
	local label = t
	if t == "coins" then
		label = "Coins"
	elseif t == "gems" then
		label = "Gems"
	elseif t == "crystals" then
		label = "Crystals"
	elseif t == "skulls" then
		label = "Skulls"
	end
	local col = if row then row.color else Color3.fromRGB(52, 211, 153)
	return `+{Utils.formatNumber(rewardAmount)} {label}`, col
end

function VFXController.questComplete(questTitle: string, rewardType: string, rewardAmount: number)
	local sg = screenGui
	if not sg then
		return
	end
	local emerald = Color3.fromRGB(16, 185, 129)
	screenFlash(Color3.fromRGB(74, 222, 128), 0.2, 0.38)
	SoundFacade.playOneShot("notification")
	task.delay(0.3, function()
		SoundFacade.playOneShot("currency")
	end)

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 0, 0)
		att.Parent = root
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(52, 211, 153)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 255, 200)),
		})
		burst.Lifetime = NumberRange.new(0.35, 0.85)
		burst.Speed = NumberRange.new(8, 26)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Acceleration = Vector3.new(0, -8, 0)
		burst.Drag = 0.4
		burst.Rate = 0
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		burst.LightEmission = 0.85
		burst.Parent = att
		burst:Emit(math.floor(55 * lodBurstMul()))
		task.delay(1.4, function()
			att:Destroy()
		end)
	end

	local layer = getCelebrationLayer()
	local check = Instance.new("TextLabel")
	check.Name = "QuestCheck"
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Size = UDim2.fromOffset(120, 120)
	check.Position = UDim2.new(0.5, 0, 0.4, 0)
	check.BackgroundTransparency = 1
	check.Font = Enum.Font.GothamBlack
	check.TextSize = 96
	check.TextColor3 = Color3.fromRGB(52, 211, 129)
	check.TextStrokeColor3 = Color3.fromRGB(6, 95, 70)
	check.TextStrokeTransparency = 0.35
	check.Text = "✓"
	check.TextTransparency = 0
	check.ZIndex = CELEBRATION_Z + 3
	check.Parent = layer
	local checkScale = Instance.new("UIScale")
	checkScale.Scale = 0.01
	checkScale.Parent = check

	local headline = Instance.new("TextLabel")
	headline.Size = UDim2.new(0.92, 0, 0, 52)
	headline.AnchorPoint = Vector2.new(0.5, 0.5)
	headline.Position = UDim2.new(0.5, 0, 1.08, 0)
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBlack
	headline.TextSize = 38
	headline.TextColor3 = emerald
	headline.TextStrokeTransparency = 0.4
	headline.Text = "QUEST COMPLETE!"
	headline.ZIndex = CELEBRATION_Z + 3
	headline.Parent = layer

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(0.88, 0, 0, 36)
	subTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subTitle.Position = UDim2.new(0.5, 0, 1.14, 0)
	subTitle.BackgroundTransparency = 1
	subTitle.Font = Enum.Font.GothamBold
	subTitle.TextSize = 22
	subTitle.TextColor3 = Color3.fromRGB(230, 245, 240)
	subTitle.TextStrokeTransparency = 0.5
	subTitle.Text = questTitle
	subTitle.TextTransparency = 0
	subTitle.ZIndex = CELEBRATION_Z + 3
	subTitle.Parent = layer

	local rewardLine, rewardCol = questRewardLine(rewardType, rewardAmount)
	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.Size = UDim2.new(0.88, 0, 0, 40)
	rewardLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	rewardLbl.Position = UDim2.new(0.5, 0, 1.2, 0)
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Font = Enum.Font.GothamBlack
	rewardLbl.TextSize = 32
	rewardLbl.TextColor3 = rewardCol
	rewardLbl.TextStrokeTransparency = 0.45
	rewardLbl.Text = rewardLine
	rewardLbl.TextTransparency = 0
	rewardLbl.ZIndex = CELEBRATION_Z + 3
	rewardLbl.Parent = layer
	local rewardScale = Instance.new("UIScale")
	rewardScale.Scale = 0.2
	rewardScale.Parent = rewardLbl

	TweenService:Create(checkScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
	task.delay(0.28, function()
		if checkScale.Parent then
			TweenService:Create(checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	TweenService:Create(headline, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.52, 0),
	}):Play()
	TweenService:Create(subTitle, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.58, 0),
	}):Play()
	TweenService:Create(rewardLbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.64, 0),
	}):Play()
	task.delay(0.05, function()
		if rewardScale.Parent then
			TweenService:Create(rewardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	task.delay(0.5, function()
		TweenService:Create(check, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)

	task.delay(1.15, function()
		TweenService:Create(headline, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(subTitle, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(rewardLbl, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
	end)

	task.delay(1.75, function()
		check:Destroy()
		headline:Destroy()
		subTitle:Destroy()
		rewardLbl:Destroy()
	end)
end

local function spawnTierConfetti(isPremium: boolean)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = cam
	att.Position = Vector3.new(0, 2, -8)
	local conf = Instance.new("ParticleEmitter")
	conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	if isPremium then
		conf.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 100)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
		})
	else
		conf.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 248, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 210, 230)),
		})
	end
	conf.Lifetime = NumberRange.new(0.7, 1.3)
	conf.Speed = NumberRange.new(12, 34)
	conf.SpreadAngle = Vector2.new(180, 180)
	conf.Acceleration = Vector3.new(0, -32, 0)
	conf.Drag = 0.45
	conf.Rate = 0
	conf.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.45, 0.5),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	conf.LightEmission = 0.8
	conf.Parent = att
	conf:Emit(math.floor((if isPremium then 70 else 28) * lodBurstMul()))
	task.delay(2.6, function()
		att:Destroy()
	end)
end

function VFXController.battlePassTierUp(newTier: number, isPremium: boolean, rewardName: string?)
	local sg = screenGui
	if not sg then
		return
	end
	local layer = getCelebrationLayer()
	local banner = Instance.new("Frame")
	banner.Name = "BattlePassTierBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UDim2.new(1, -32, 0, 96)
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	banner.BackgroundColor3 = if isPremium then Color3.fromRGB(40, 32, 18) else Color3.fromRGB(28, 32, 44)
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.ZIndex = CELEBRATION_Z + 8
	banner.Parent = layer
	local bnr = Instance.new("UICorner")
	bnr.CornerRadius = UDim.new(0, 12)
	bnr.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if isPremium then 4 else 2
	stroke.Color = if isPremium then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(220, 230, 245)
	stroke.Transparency = 0.15
	stroke.Parent = banner

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 44)
	title.Position = UDim2.new(0, 8, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 32
	title.TextColor3 = if isPremium then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(240, 245, 255)
	title.TextStrokeTransparency = 0.35
	title.Text = `TIER {newTier} UNLOCKED!`
	title.ZIndex = CELEBRATION_Z + 9
	title.Parent = banner

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -16, 0, 28)
	sub.Position = UDim2.new(0, 8, 0, 54)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 16
	sub.TextColor3 = Color3.fromRGB(220, 220, 235)
	sub.TextStrokeTransparency = 0.5
	sub.Text = if rewardName and rewardName ~= "" then rewardName else "Reward ready to claim"
	sub.ZIndex = CELEBRATION_Z + 9
	sub.Parent = banner

	if isPremium then
		task.spawn(function()
			cameraShake(0.42, 0.38)
		end)
	end
	spawnTierConfetti(isPremium)
	SoundFacade.playOneShot("level_up")

	TweenService:Create(banner, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18),
	}):Play()

	task.delay(2.0, function()
		if not banner.Parent then
			return
		end
		TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -140),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
	end)

	task.delay(2.55, function()
		banner:Destroy()
	end)
end

function VFXController.carUnlockCelebration(carId: string, carDisplayName: string)
	if celebratedCarIds[carId] then
		return
	end
	celebratedCarIds[carId] = true

	local sg = screenGui
	if not sg then
		return
	end
	local theme = WORLD_TRAIL_NEON[activeWorldId] or WORLD_TRAIL_NEON.grasslands
	screenFlash(Color3.new(1, 1, 1), 0.12, 0.35)
	task.delay(0.1, function()
		screenFlash(theme, 0.45, 0.38)
	end)
	SoundFacade.playOneShot("level_up")

	local cam = workspace.CurrentCamera
	if cam then
		local att = Instance.new("Attachment")
		att.Parent = cam
		att.Position = Vector3.new(0, 0, -12)
		local spark = Instance.new("ParticleEmitter")
		spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spark.Color = ColorSequence.new(theme:Lerp(Color3.new(1, 1, 1), 0.35))
		spark.Lifetime = NumberRange.new(0.5, 1.1)
		spark.Speed = NumberRange.new(12, 36)
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.Acceleration = Vector3.new(0, -12, 0)
		spark.Rate = 0
		spark.LightEmission = 0.9
		spark.Parent = att
		spark:Emit(math.floor(60 * lodBurstMul()))
		task.delay(2.2, function()
			att:Destroy()
		end)
	end

	local layer = getCelebrationLayer()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.92, 0, 0, 88)
	title.Position = UDim2.new(0.04, 0, 0.4, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 44
	title.TextColor3 = theme
	title.TextStrokeTransparency = 0.4
	title.Text = carDisplayName
	title.ZIndex = CELEBRATION_Z + 2
	title.Parent = layer
	TweenService:Create(title, TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.04, 0, 0.28, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, function()
		title:Destroy()
	end)
end

local function statDisplayName(stat: string): string
	if stat == "gas" then
		return "GAS"
	elseif stat == "power" then
		return "POWER"
	elseif stat == "speed" then
		return "SPEED"
	end
	return string.upper(stat)
end

local function statMaxFor(stat: string): number
	local row = UpgradeConfig.Stats[stat]
	return if row and type(row.maxLevel) == "number" then row.maxLevel else 100
end

function VFXController.statLevelUp(statName: string, oldLevel: number, newLevel: number)
	if newLevel <= oldLevel then
		return
	end
	local sg = screenGui
	if not sg then
		return
	end
	local statKey = string.lower(statName)
	local maxLv = statMaxFor(statKey)

	local car = player.Character and player.Character:FindFirstChild("Car")
	local primary = car and car:IsA("Model") and (car :: Model).PrimaryPart
	if primary then
		local att = Instance.new("Attachment")
		att.Parent = primary
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(120, 255, 200))
		p.Lifetime = NumberRange.new(0.25, 0.55)
		p.Speed = NumberRange.new(2, 10)
		p.SpreadAngle = Vector2.new(90, 90)
		p.Size = NumberSequence.new(0.2, 0.7)
		p.Rate = 0
		p.Parent = att
		p:Emit(22)
		task.delay(0.8, function()
			att:Destroy()
		end)
	end

	local layer = getCelebrationLayer()
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.9, 0, 0, 72)
	lbl.Position = UDim2.new(0.05, 0, 0.62, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 38
	lbl.TextColor3 = Color3.fromRGB(180, 255, 220)
	lbl.TextStrokeTransparency = 0.45
	lbl.ZIndex = CELEBRATION_Z + 2
	lbl.Parent = layer

	local startClock = os.clock()
	local duration = 0.4
	local lastFloored = oldLevel
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if not lbl.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local t = math.clamp((os.clock() - startClock) / duration, 0, 1)
		local v = math.floor(oldLevel + (newLevel - oldLevel) * t + 0.0001)
		lbl.Text = `{statDisplayName(statKey)}  {v}`
		if v > lastFloored then
			lastFloored = v
			screenFlash(Color3.fromRGB(200, 255, 230), 0.06, 0.12)
		end
		if t >= 1 then
			if conn then
				conn:Disconnect()
			end
		end
	end)

	task.delay(duration, function()
		if lbl.Parent then
			lbl.Text = `{statDisplayName(statKey)}  {newLevel}`
		end
		if newLevel >= maxLv then
			screenFlash(Color3.fromRGB(255, 255, 200), 0.22, 0.35)
			local maxLbl = Instance.new("TextLabel")
			maxLbl.Size = UDim2.new(0.8, 0, 0, 56)
			maxLbl.Position = UDim2.new(0.1, 0, 0.56, 0)
			maxLbl.BackgroundTransparency = 1
			maxLbl.Font = Enum.Font.GothamBlack
			maxLbl.TextSize = 48
			maxLbl.TextColor3 = Color3.fromRGB(255, 240, 120)
			maxLbl.TextStrokeTransparency = 0.25
			maxLbl.Text = "MAX"
			maxLbl.TextTransparency = 0
			maxLbl.ZIndex = CELEBRATION_Z + 3
			maxLbl.Parent = layer
			local mg = Instance.new("UIGradient")
			mg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 200)),
			})
			mg.Parent = maxLbl
			task.spawn(function()
				local t0 = os.clock()
				while maxLbl.Parent and os.clock() - t0 < 0.6 do
					mg.Offset = Vector2.new(math.sin(os.clock() * 6) * 0.15, 0)
					task.wait()
				end
			end)
			TweenService:Create(maxLbl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			task.delay(0.9, function()
				maxLbl:Destroy()
			end)
		end
		TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.55, function()
			lbl:Destroy()
		end)
	end)
end

local function ensureDepthOfField(): DepthOfField
	if dofEffect and dofEffect.Parent then
		return dofEffect
	end
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "DACVFX_BoostDOF"
	d.Enabled = false
	d.FarIntensity = 0
	d.NearIntensity = 0
	d.FocusDistance = 20
	d.InFocusRadius = 12
	d.Parent = Lighting
	dofEffect = d
	return d
end

local function configureTrailEmitter(em: ParticleEmitter, speed: number, color: Color3, worldAccent: Color3)
	local t = math.clamp(speed / 100, 0, 1)
	local mul = lodTrailRateMul()
	local rateLo = (15 + t * 10) * mul
	local rateHi = (25 + t * 35) * mul
	em.Color = ColorSequence.new(color:Lerp(worldAccent, 0.15))
	em.Lifetime = NumberRange.new(0.45 + t * 0.5, 0.55 + t * 1.1)
	em.Rate = math.clamp((rateLo + rateHi) * 0.5, 0, 60)
	em.Speed = NumberRange.new(2 + t * 6, 5 + t * 9)
	em.SpreadAngle = Vector2.new(8 + t * 7, 8 + t * 4)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 + t * 0.2),
		NumberSequenceKeypoint.new(0.2, 0.55 + t * 0.15),
		NumberSequenceKeypoint.new(1, 0.1 + t * 0.05),
	})
	local midA = 0.55 - t * 0.25
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.45, midA),
		NumberSequenceKeypoint.new(1, 1),
	})
	em.LightEmission = 0.35 + t * 0.3
	em.Drag = 2 - t * 0.8
	em.Acceleration = Vector3.new(0, 0.5 + t * 0.5, 0)
	em.RotSpeed = NumberRange.new(-30 - t * 30, 30 + t * 30)
end

local function ensureTrailOnCar()
	if trailEmitterL and trailEmitterL.Parent then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local car = char:FindFirstChild("Car")
	local model = if car and car:IsA("Model") then car :: Model else nil
	local primary = model and model.PrimaryPart
	if not primary then
		return
	end
	trailPart = primary

	local function att(name: string, pos: Vector3): Attachment
		local a = primary:FindFirstChild(name) :: Attachment?
		if not a then
			a = Instance.new("Attachment")
			a.Name = name
			a.Position = pos
			a.Parent = primary
		end
		return a
	end

	trailAttachmentL = att("DACVFX_TrailL", Vector3.new(-1.6, 0, 2.8))
	trailAttachmentR = att("DACVFX_TrailR", Vector3.new(1.6, 0, 2.8))
	boostAttachment = att("DACVFX_BoostCenter", Vector3.new(0, 0.2, 3.2))

	local function ensureEmitter(parent: Attachment, nm: string): ParticleEmitter
		local em = parent:FindFirstChild(nm) :: ParticleEmitter?
		if not em then
			em = Instance.new("ParticleEmitter")
			em.Name = nm
			em.Parent = parent
		end
		em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		em.Enabled = true
		return em
	end

	trailEmitterL = ensureEmitter(trailAttachmentL, "DACVFX_TrailL")
	trailEmitterR = ensureEmitter(trailAttachmentR, "DACVFX_TrailR")
	boostEmitter = ensureEmitter(boostAttachment, "DACVFX_BoostStars")
	boostEmitter.Rate = 0
	boostEmitter.Lifetime = NumberRange.new(0.3, 0.55)
	boostEmitter.Speed = NumberRange.new(6, 18)
	boostEmitter.SpreadAngle = Vector2.new(25, 25)
	boostEmitter.Size = NumberSequence.new(0.2, 0.9)
	boostEmitter.Transparency = NumberSequence.new(0.2, 1)
	boostEmitter.Color = mythicRainbowSequence()
	boostEmitter.LightEmission = 0.85
end

local function destroyTrail()
	if trailEmitterL then
		trailEmitterL.Enabled = false
	end
	if trailEmitterR then
		trailEmitterR.Enabled = false
	end
	if boostEmitter then
		boostEmitter.Enabled = false
	end
	trailEmitterL = nil
	trailEmitterR = nil
	boostEmitter = nil
	trailAttachmentL = nil
	trailAttachmentR = nil
	boostAttachment = nil
	trailPart = nil
	if boostFovTween then
		boostFovTween:Cancel()
		boostFovTween = nil
	end
	boostActive = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = baseCameraFov
	end
	local dof = dofEffect
	if dof then
		dof.Enabled = false
	end
end

local function setBoostFov(active: boolean)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if boostFovTween then
		boostFovTween:Cancel()
		boostFovTween = nil
	end
	local target = if active then math.min(cam.FieldOfView + 10, 75) else baseCameraFov
	boostFovTween = TweenService:Create(
		cam,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = target }
	)
	boostFovTween:Play()

	local dof = ensureDepthOfField()
	if lodTier >= 3 and not UserInputService.TouchEnabled and active then
		dof.Enabled = true
		dof.FarIntensity = 0.2
	else
		dof.Enabled = false
		dof.FarIntensity = 0
	end
end

function VFXController.boostOverlay(isActive: boolean)
	if boostActive == isActive then
		return
	end
	boostActive = isActive
	setBoostFov(isActive)
	if not runActive then
		return
	end
	ensureTrailOnCar()
	if boostEmitter then
		local mul = lodTrailRateMul()
		boostEmitter.Rate = if isActive then (28 * mul) else 0
	end
end

function VFXController.init()
	lodTier = qualityLodSeed()

	local sg = Instance.new("ScreenGui")
	sg.Name = "DACVFX"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 80
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = playerGui
	screenGui = sg

	for i = 1, 18 do
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Popup_" .. i
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Size = UDim2.fromOffset(280, 48)
		lbl.BackgroundTransparency = 1
		lbl.TextSize = 26
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.5
		lbl.Visible = false
		lbl.Parent = sg
		table.insert(popupPool, lbl)
	end

	task.defer(function()
		local cam = workspace.CurrentCamera
		if cam then
			baseCameraFov = cam.FieldOfView
		end
	end)

	fpsSecondClock = os.clock()
	RunService.Heartbeat:Connect(function()
		fpsFrameAccum += 1
		local now = os.clock()
		if now - fpsSecondClock >= 1 then
			local fps = fpsFrameAccum
			fpsFrameAccum = 0
			fpsSecondClock = now
			if fps < 30 then
				lowFpsStreakSeconds += 1
			else
				lowFpsStreakSeconds = 0
			end
			if lowFpsStreakSeconds >= 2 then
				lodTier = math.min(lodTier, 1)
			elseif fps >= 45 then
				lodTier = math.max(lodTier, qualityLodSeed())
			end
		end
	end)
end

local function virtualCoinFloorFromDistance(dist: number): number
	local world = WorldConfig.Worlds[activeWorldId]
	local wm = if world then world.coinMultiplier else 1
	local petMod = math.max(cachedPetModifier, 0.01)
	local power = runPowerForCombo
	return math.floor(dist * Constants.DISTANCE_TO_COINS_RATE * wm * petMod * (1 + power * 0.01))
end

local function hideComboLabel()
	if comboLabel and comboLabel.Parent then
		comboLabel.Visible = false
	end
end

local function ensureComboLabel(): TextLabel
	local sg = screenGui
	assert(sg, "VFXController.init not called")
	if comboLabel and comboLabel.Parent then
		return comboLabel :: TextLabel
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = "CoinCombo"
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Size = UDim2.fromOffset(220, 56)
	lbl.Position = UDim2.new(0.5, 0, 0.58, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = ""
	lbl.Visible = false
	lbl.ZIndex = 1001
	lbl.Parent = sg
	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = lbl
	comboLabel = lbl
	comboUIScale = sc
	return lbl
end

local function comboColorForStreak(streak: number): Color3
	if streak <= 2 then
		return Color3.new(1, 1, 1)
	elseif streak == 3 then
		return Color3.fromRGB(255, 230, 80)
	elseif streak == 4 then
		return Color3.fromRGB(255, 160, 60)
	end
	return Color3.fromRGB(255, 80, 80)
end

local function comboTextSizeForStreak(streak: number): number
	return if streak <= 2 then 22 elseif streak == 3 then 28 else 34
end

local function scheduleComboReset()
	comboResetToken += 1
	local t = comboResetToken
	task.delay(2.05, function()
		if t ~= comboResetToken then
			return
		end
		if os.clock() - lastCoinPickupClock >= 2 then
			coinComboStreak = 0
			hideComboLabel()
		end
	end)
end

local function comboCoinPickup()
	local now = os.clock()
	if now - lastCoinPickupSfxClock >= 0.06 then
		lastCoinPickupSfxClock = now
		SoundFacade.playOneShot("coin_pickup")
	end
	local gap = now - lastCoinPickupClock
	lastCoinPickupClock = now
	if gap > 2 or coinComboStreak < 1 then
		coinComboStreak = 1
	else
		coinComboStreak += 1
	end

	scheduleComboReset()

	if coinComboStreak < 2 then
		return
	end

	local lbl = ensureComboLabel()
	lbl.Text = "x" .. tostring(coinComboStreak)
	lbl.TextColor3 = comboColorForStreak(coinComboStreak)
	lbl.TextSize = comboTextSizeForStreak(coinComboStreak)
	lbl.TextTransparency = 0
	lbl.Visible = true

	local sc = comboUIScale
	if sc then
		sc.Scale = 1
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.22 }):Play()
		task.delay(0.12, function()
			if sc.Parent then
				TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
	end

	if coinComboStreak == 10 then
		screenFlash(Color3.new(1, 1, 1), 0.2, 0.25)
		SoundFacade.playOneShot("level_up")
	end
end

local function milestoneDistanceCelebration(totalDistance: number)
	local k10 = math.floor(totalDistance / 10000)
	local k5 = math.floor(totalDistance / 5000)
	local k1 = math.floor(totalDistance / 1000)
	if k10 > lastDistK10 then
		lastDistK10 = k10
		local n = k10 * 10000
		VFXController.milestonePopup(formatStudsComma(n) .. " studs!", "distance_big")
		return
	end
	if k5 > lastDistK5 then
		lastDistK5 = k5
		local n = k5 * 5000
		VFXController.milestonePopup(formatStudsComma(n) .. " studs!", "distance_medium")
		return
	end
	if k1 > lastDistK1 then
		lastDistK1 = k1
		local n = k1 * 1000
		VFXController.milestonePopup(formatStudsComma(n) .. " studs!", "distance_small")
	end
end

function VFXController.onRunDistanceTick(totalDistance: number)
	if not runActive then
		return
	end
	milestoneDistanceCelebration(totalDistance)
	local newFloor = virtualCoinFloorFromDistance(totalDistance)
	if newFloor <= lastVirtualCoinFloor then
		return
	end
	local n = newFloor - lastVirtualCoinFloor
	local maxBurst = 24
	for _ = 1, math.min(n, maxBurst) do
		comboCoinPickup()
	end
	lastVirtualCoinFloor = newFloor
end

function VFXController.isFirstRunOfDay(): boolean
	return isFirstRunOfDayActive
end

function VFXController.firstRunEntrance()
	local sg = screenGui
	if not sg then
		return
	end

	SoundFacade.playOneShot("level_up")

	local ENTRANCE_Z = 1300

	local wipe = Instance.new("Frame")
	wipe.Name = "FirstRunWipe"
	wipe.Size = UDim2.fromScale(1, 1)
	wipe.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	wipe.BackgroundTransparency = 0
	wipe.ZIndex = ENTRANCE_Z
	wipe.Parent = sg
	local wipeGrad = Instance.new("UIGradient")
	wipeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 30)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 240, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 60)),
	})
	wipeGrad.Rotation = 90
	wipeGrad.Parent = wipe

	TweenService:Create(wipe, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.85, function()
		wipe:Destroy()
	end)

	local title = Instance.new("TextLabel")
	title.Name = "FirstRunTitle"
	title.Size = UDim2.new(0.9, 0, 0, 70)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.38, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 48
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.TextStrokeColor3 = Color3.fromRGB(120, 70, 10)
	title.TextStrokeTransparency = 0.2
	title.Text = "FIRST RUN OF THE DAY!"
	title.TextTransparency = 0
	title.ZIndex = ENTRANCE_Z + 2
	title.Parent = sg

	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 0.3
	titleScale.Parent = title
	TweenService:Create(titleScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
	task.delay(0.4, function()
		if titleScale.Parent then
			TweenService:Create(titleScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	local bonus = Instance.new("TextLabel")
	bonus.Name = "FirstRunBonus"
	bonus.Size = UDim2.new(0.8, 0, 0, 50)
	bonus.AnchorPoint = Vector2.new(0.5, 0.5)
	bonus.Position = UDim2.new(0.5, 0, 0.46, 0)
	bonus.BackgroundTransparency = 1
	bonus.Font = Enum.Font.GothamBold
	bonus.TextSize = 36
	bonus.TextColor3 = Color3.fromRGB(255, 240, 140)
	bonus.TextStrokeColor3 = Color3.fromRGB(100, 60, 5)
	bonus.TextStrokeTransparency = 0.3
	bonus.Text = "x3 BONUS"
	bonus.TextTransparency = 1
	bonus.ZIndex = ENTRANCE_Z + 2
	bonus.Parent = sg

	local bonusScale = Instance.new("UIScale")
	bonusScale.Scale = 0.5
	bonusScale.Parent = bonus
	task.delay(0.25, function()
		if bonus.Parent then
			bonus.TextTransparency = 0
			TweenService:Create(bonusScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	local cam = workspace.CurrentCamera
	if cam then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 5, -6)
		att.Parent = cam
		local coinShower = Instance.new("ParticleEmitter")
		coinShower.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		coinShower.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
		})
		coinShower.Lifetime = NumberRange.new(0.8, 1.6)
		coinShower.Speed = NumberRange.new(10, 28)
		coinShower.SpreadAngle = Vector2.new(140, 30)
		coinShower.EmissionDirection = Enum.NormalId.Bottom
		coinShower.Acceleration = Vector3.new(0, -40, 0)
		coinShower.Drag = 0.3
		coinShower.Rate = 0
		coinShower.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.4, 0.55),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		coinShower.LightEmission = 0.85
		coinShower.Parent = att
		coinShower:Emit(math.floor(30 * lodBurstMul()))
		task.delay(2.5, function()
			att:Destroy()
		end)
	end

	task.delay(1.4, function()
		TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(bonus, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)
	task.delay(2.1, function()
		title:Destroy()
		bonus:Destroy()
	end)
end

function VFXController.onRunStarted(runInfo: any)
	runActive = true
	fuelPanicDeepShake = false
	runShakeState = nil
	activeWorldId = if type(runInfo) == "table" and type(runInfo.worldId) == "string" then runInfo.worldId else "grasslands"
	lastDistK1 = 0
	lastDistK5 = 0
	lastDistK10 = 0
	nearMissPendingRecover = false
	local cam = workspace.CurrentCamera
	if cam then
		baseCameraFov = cam.FieldOfView
	end
	lastVirtualCoinFloor = 0
	coinComboStreak = 0
	lastCoinPickupClock = 0
	comboResetToken += 1
	hideComboLabel()
	local st = if type(runInfo) == "table" then runInfo.stats else nil
	runPowerForCombo = if type(st) == "table" and type((st :: any).power) == "number" then (st :: any).power else 0
	ensureTrailOnCar()
	fuelPanicPrevGas = 1
	speedRushSmoothed = 0
	speedRushChromaSmoothed = 0

	isFirstRunOfDayActive = type(runInfo) == "table" and runInfo.isFirstRunOfDay == true
end

function VFXController.onRunEnded()
	runActive = false
	isFirstRunOfDayActive = false
	runShakeState = nil
	stopFuelPanicShake()
	if fuelPanicVignette then
		fuelPanicVignette.BackgroundTransparency = 1
	end
	fuelPanicPrevGas = 1
	speedRushSmoothed = 0
	speedRushChromaSmoothed = 0
	if speedRushEdgeFrame then
		speedRushEdgeFrame.BackgroundTransparency = 1
	end
	if speedRushChromaFrame then
		speedRushChromaFrame.BackgroundTransparency = 1
	end
	destroyTrail()
	lastVirtualCoinFloor = 0
	coinComboStreak = 0
	comboResetToken += 1
	hideComboLabel()
end

function VFXController.runEndFanfare(isRecord: boolean)
	local cam = workspace.CurrentCamera
	if cam then
		local startFov = cam.FieldOfView
		TweenService:Create(cam, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = math.min(startFov + 11, 88),
		}):Play()
		task.delay(0.14, function()
			if cam.Parent then
				TweenService:Create(cam, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					FieldOfView = startFov,
				}):Play()
			end
		end)
	end

	if isRecord then
		SoundFacade.playOneShot("level_up")
	else
		SoundFacade.playOneShot("purchase")
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 6, 0)
		att.Parent = root
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60))
		burst.Lifetime = NumberRange.new(0.5, 1.2)
		burst.Speed = NumberRange.new(4, 22)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rate = 0
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.9),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		burst.LightEmission = 0.85
		burst.Parent = att
		local mul = lodBurstMul()
		burst:Emit(math.floor((isRecord and 140 or 95) * mul))

		local shower = Instance.new("ParticleEmitter")
		shower.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		shower.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
		shower.Lifetime = NumberRange.new(0.8, 1.4)
		shower.Speed = NumberRange.new(8, 28)
		shower.SpreadAngle = Vector2.new(25, 25)
		shower.EmissionDirection = Enum.NormalId.Top
		shower.Acceleration = Vector3.new(0, -35, 0)
		shower.Rate = 0
		shower.Parent = att
		shower:Emit(math.floor((isRecord and 70 or 45) * mul))

		task.delay(2, function()
			att:Destroy()
		end)
	end
end

function VFXController.speedTrail(speed: number)
	ensureTrailOnCar()
	if not trailEmitterL or not trailEmitterR then
		return
	end

	local theme = WORLD_TRAIL_NEON[activeWorldId] or WORLD_TRAIL_NEON.grasslands
	local tc = trailColorFromSpeed(speed)
	local mul = lodTrailRateMul()
	local perWheel = math.clamp((TRAIL_BUDGET * 0.5) * mul * 0.02, 4, 50)
	configureTrailEmitter(trailEmitterL, speed, tc, theme)
	configureTrailEmitter(trailEmitterR, speed, tc, theme)
	trailEmitterL.Rate = perWheel
	trailEmitterR.Rate = perWheel
	if boostEmitter and boostActive then
		local starBudget = math.clamp(20 * mul, 5, 40)
		boostEmitter.Rate = starBudget
	end
end

local function rarityTier(r: string): number
	local order = Constants.RARITY_ORDER
	return order[r] or 1
end

local function isRarePlusRarity(rarity: string): boolean
	return rarityTier(rarity) >= (Constants.RARITY_ORDER.rare or 3)
end

local function eggStreakParticleMul(streak: number): number
	if streak < 2 then
		return 1
	end
	return math.clamp(1 + (streak - 2) * 0.18, 1, 2.2)
end

local function playLuckyStreakSounds(streak: number)
	if streak < 2 then
		return
	end
	SoundFacade.playOneShot("notification")
	if streak >= 3 then
		task.defer(function()
			SoundFacade.playOneShot("level_up")
		end)
	end
	if streak >= 4 then
		task.delay(0.08, function()
			SoundFacade.playOneShot("hatch_legendary")
		end)
	end
	if streak >= 5 then
		task.delay(0.16, function()
			SoundFacade.playOneShot("hatch_mythic")
		end)
	end
end

local function luckyStreakMegaCelebration()
	local cam = workspace.CurrentCamera
	if cam then
		local startFov = cam.FieldOfView
		TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = math.min(startFov + 18, 95),
		}):Play()
		task.delay(0.14, function()
			if cam.Parent then
				TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					FieldOfView = startFov,
				}):Play()
			end
		end)
	end
	screenFlash(Color3.new(1, 1, 1), 0.12, 0.55)
	task.delay(0.06, function()
		local f = getFlashLayer()
		f.BackgroundTransparency = 1
		local seq = mythicRainbowSequence()
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		local tw = TweenService:Create(
			f,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.35 }
		)
		tw:Play()
		tw.Completed:Connect(function()
			TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end)
	end)
	local mul = lodBurstMul() * 2.4
	local cam2 = workspace.CurrentCamera
	if cam2 then
		local att = Instance.new("Attachment")
		att.Parent = cam2
		att.Position = Vector3.new(0, 2, -10)
		local conf = Instance.new("ParticleEmitter")
		conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		conf.Color = mythicRainbowSequence()
		conf.Lifetime = NumberRange.new(0.8, 1.6)
		conf.Speed = NumberRange.new(14, 42)
		conf.SpreadAngle = Vector2.new(180, 180)
		conf.Acceleration = Vector3.new(0, -40, 0)
		conf.Drag = 0.45
		conf.Rate = 0
		conf.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.45, 0.65),
			NumberSequenceKeypoint.new(1, 0.12),
		})
		conf.LightEmission = 0.9
		conf.Parent = att
		conf:Emit(math.floor(120 * mul))
		task.delay(3, function()
			att:Destroy()
		end)
	end
end

type BurstSpec = {
	core: number,
	stars: number,
	wisps: number,
	bolts: number,
	confetti: number,
	beams: number,
	duration: number,
	shake: number,
	hitstop: number,
}

local BURST_TABLE: { [string]: BurstSpec } = {
	common = { core = 20, stars = 0, wisps = 0, bolts = 0, confetti = 0, beams = 0, duration = 0.5, shake = 0, hitstop = 0 },
	uncommon = { core = 30, stars = 10, wisps = 0, bolts = 0, confetti = 0, beams = 0, duration = 0.7, shake = 0, hitstop = 0 },
	rare = { core = 50, stars = 20, wisps = 0, bolts = 0, confetti = 0, beams = 4, duration = 1.0, shake = 0, hitstop = 0 },
	epic = { core = 80, stars = 30, wisps = 20, bolts = 0, confetti = 0, beams = 6, duration = 1.5, shake = 0.35, hitstop = 0 },
	legendary = {
		core = 120,
		stars = 50,
		wisps = 0,
		bolts = 16,
		confetti = 24,
		beams = 8,
		duration = 2.0,
		shake = 0.35,
		hitstop = 0.25,
	},
	mythic = {
		core = 200,
		stars = 80,
		wisps = 40,
		bolts = 24,
		confetti = 40,
		beams = 0,
		duration = 3.5,
		shake = 0.5,
		hitstop = 0.5,
	},
}

-- Legacy hatch timeline reference (pre–HatchCrackVisualSpec) — used only to scale procedural crack spawns.
local REF_HATCH_BREAK_FOR_SCALE: { [string]: number } = {
	common = 1.5,
	uncommon = 1.5,
	rare = 3,
	epic = 4,
	legendary = 5,
	mythic = 6.5,
}

local function hatchCrackTimeScale(rarity: string, breakT: number): number
	local ref = REF_HATCH_BREAK_FOR_SCALE[rarity] or REF_HATCH_BREAK_FOR_SCALE.common
	return if ref > 0.001 then breakT / ref else 1
end

local function hatchSpawnCrackLine(
	parent: Frame,
	z: number,
	pos: UDim2,
	size: UDim2,
	rotDeg: number,
	color: Color3,
	startTrans: number,
	endTrans: number,
	tweenDur: number
)
	local ln = Instance.new("Frame")
	ln.BorderSizePixel = 0
	ln.AnchorPoint = Vector2.new(0.5, 0)
	ln.BackgroundColor3 = color
	ln.BackgroundTransparency = startTrans
	ln.Rotation = rotDeg
	ln.Size = size
	ln.Position = pos
	ln.ZIndex = z
	ln.Parent = parent
	TweenService:Create(ln, TweenInfo.new(tweenDur, Enum.EasingStyle.Quad), { BackgroundTransparency = endTrans }):Play()
	return ln
end

local function hatchSpawnGlitchStrip(parent: Frame, yScale: number, delay: number)
	task.delay(delay, function()
		if not parent.Parent then
			return
		end
		local strip = Instance.new("Frame")
		strip.Size = UDim2.new(1, 0, 0, math.random(2, 6))
		strip.Position = UDim2.new(-0.5, 0, yScale, 0)
		strip.BackgroundColor3 = Color3.new(1, 1, 1)
		strip.BackgroundTransparency = 0.4
		strip.BorderSizePixel = 0
		strip.ZIndex = 39
		strip.Parent = parent
		TweenService:Create(strip, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { Position = UDim2.new(1.5, 0, yScale, 0) }):Play()
		task.delay(0.35, function()
			strip:Destroy()
		end)
	end)
end

local function makeEmitter(att: Attachment, texture: string, col: ColorSequence)
	local p = Instance.new("ParticleEmitter")
	p.Texture = texture
	p.Color = col
	p.Parent = att
	return p
end

local function emitBurst(att: Attachment, spec: BurstSpec, rarity: string, col: Color3, streakMul: number?)
	local m = lodBurstMul() * (if streakMul and streakMul > 0 then streakMul else 1)
	local cs = ColorSequence.new(col)
	local starSeq = ColorSequence.new(col)

	local function burst(em: ParticleEmitter, n: number, life: NumberRange, spd: NumberRange, spread: Vector2)
		em.Lifetime = life
		em.Speed = spd
		em.SpreadAngle = spread
		em.Rate = 0
		em.Size = NumberSequence.new(0.25, 1.1)
		em:Emit(math.max(1, math.floor(n * m)))
	end

	local core = makeEmitter(att, "rbxasset://textures/particles/sparkles_main.dds", cs)
	burst(core, spec.core, NumberRange.new(0.4, 0.8), NumberRange.new(10, 28), Vector2.new(180, 180))

	if spec.stars > 0 then
		local stars = makeEmitter(att, "rbxasset://textures/particles/sparkles_main.dds", starSeq)
		burst(stars, spec.stars, NumberRange.new(0.35, 0.7), NumberRange.new(12, 32), Vector2.new(90, 90))
	end

	if spec.wisps > 0 then
		local w = makeEmitter(att, "rbxasset://textures/particles/smoke_main.dds", cs)
		burst(w, spec.wisps, NumberRange.new(0.8, 1.4), NumberRange.new(4, 12), Vector2.new(40, 40))
	end

	if spec.bolts > 0 then
		local b = makeEmitter(att, "rbxasset://textures/particles/sparkles_main.dds", cs)
		burst(b, spec.bolts, NumberRange.new(0.2, 0.45), NumberRange.new(20, 45), Vector2.new(30, 30))
	end

	if spec.confetti > 0 then
		local c = makeEmitter(att, "rbxasset://textures/particles/sparkles_main.dds", ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.3)))
		burst(c, spec.confetti, NumberRange.new(0.5, 1.0), NumberRange.new(8, 22), Vector2.new(180, 180))
	end

	task.delay(spec.duration + 0.5, function()
		for _, ch in att:GetChildren() do
			if ch:IsA("ParticleEmitter") then
				ch:Destroy()
			end
		end
	end)

	if spec.beams > 0 then
		local root = att.Parent
		if root and root:IsA("BasePart") then
			for i = 1, math.min(spec.beams, 8) do
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.5, 0)
				a0.Parent = root
				local a1 = Instance.new("Attachment")
				local ang = (i - 1) * (math.pi * 2 / spec.beams)
				a1.Position = Vector3.new(math.cos(ang) * 5, 2, math.sin(ang) * 5)
				a1.Parent = root
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Color = ColorSequence.new(col)
				beam.Width0 = 0.35
				beam.Width1 = 0.05
				beam.Transparency = NumberSequence.new(0.2, 1)
				beam.FaceCamera = true
				beam.Parent = root
				task.delay(0.85, function()
					beam:Destroy()
					a0:Destroy()
					a1:Destroy()
				end)
			end
		end
	end

	if rarity == "legendary" or rarity == "mythic" then
		local orbit = makeEmitter(att, "rbxasset://textures/particles/sparkles_main.dds", if rarity == "mythic" then mythicRainbowSequence() else ColorSequence.new(col))
		orbit.Rate = if rarity == "mythic" then 6 else 4
		orbit.Lifetime = NumberRange.new(0.4, 0.9)
		orbit.Speed = NumberRange.new(2, 8)
		orbit.SpreadAngle = Vector2.new(360, 360)
		orbit.Size = NumberSequence.new(0.15, 0.45)
		task.delay(6, function()
			if orbit.Parent then
				orbit.Rate = 0
				orbit:Destroy()
			end
		end)
	end
end

function VFXController.hatchReveal(petData: any)
	if type(petData) ~= "table" then
		return
	end
	local rarity = if type(petData.rarity) == "string" then string.lower(petData.rarity) else "common"
	local petName = if type(petData.petName) == "string" then petData.petName else "Pet"
	local hcEntry = HatchCrackVisualSpec.getForRarity(rarity) or HatchCrackVisualSpec.getForRarity("common") :: any
	local hatchCol = hcEntry.glowColor
	local col = Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
	local spec = BURST_TABLE[rarity] or BURST_TABLE.common
	local breakT = hcEntry.totalDurationSec
	local totalT = hcEntry.totalDurationSec
	local hitstopDur = hcEntry.hitstopSec or 0
	local hitstopStart = if hitstopDur > 0.001 then breakT - hitstopDur else math.huge
	local tScale = hatchCrackTimeScale(rarity, breakT)

	for _, st in hcEntry.sfxTiming do
		task.delay(st.atSec, function()
			SoundFacade.playOneShot(st.soundId)
		end)
	end

	if isRarePlusRarity(rarity) then
		eggRareStreak += 1
	else
		eggRareStreak = 0
	end
	local luckyStreak = eggRareStreak
	local streakParticleMul = eggStreakParticleMul(luckyStreak)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

	local sg = screenGui
	if not sg then
		return
	end

	local eggBase = Vector2.new(140, 180)
	local eggSwellMul = 1 + (hcEntry.eggSizeGrowth or 0)
	local eggW = eggBase.X * eggSwellMul
	local eggH = eggBase.Y * eggSwellMul

	local eggFrame = Instance.new("Frame")
	eggFrame.Size = UDim2.fromOffset(eggBase.X, eggBase.Y)
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.Position = UDim2.new(0.5, 0, 0.48, 0)
	eggFrame.BackgroundColor3 = Color3.fromRGB(240, 230, 210)
	eggFrame.BackgroundTransparency = 0.1
	eggFrame.ZIndex = 40
	eggFrame.Parent = sg
	local eggCorner = Instance.new("UICorner")
	eggCorner.CornerRadius = UDim.new(0, 24)
	eggCorner.Parent = eggFrame

	local darkOverlay: Frame? = nil
	if rarity == "mythic" then
		local ov = Instance.new("Frame")
		ov.Name = "MythicHatchDarken"
		ov.Size = UDim2.fromScale(1, 1)
		ov.BackgroundColor3 = Color3.new(0, 0, 0)
		ov.BackgroundTransparency = 1
		ov.BorderSizePixel = 0
		ov.ZIndex = 37
		ov.Parent = sg
		darkOverlay = ov
		task.delay(1, function()
			if ov.Parent then
				TweenService:Create(ov, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.55 }):Play()
			end
		end)
	end

	local epicGrad: UIGradient? = nil
	if rarity == "epic" then
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 230, 210)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 60, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 230, 210)),
		})
		g.Transparency = NumberSequence.new(0.85)
		g.Parent = eggFrame
		epicGrad = g
		task.delay(1.2, function()
			if g.Parent then
				TweenService:Create(g, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					Offset = Vector2.new(0, 0.6),
				}):Play()
			end
		end)
	end

	local mythicEggGrad: UIGradient? = nil
	if rarity == "mythic" then
		task.delay(1.5, function()
			if not eggFrame.Parent then
				return
			end
			local g = Instance.new("UIGradient")
			g.Rotation = 0
			g.Color = mythicRainbowSequence()
			g.Transparency = NumberSequence.new(0.7)
			g.Parent = eggFrame
			mythicEggGrad = g
			TweenService:Create(g, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Rotation = 120 }):Play()
			TweenService:Create(g, TweenInfo.new(2, Enum.EasingStyle.Quad), { Transparency = NumberSequence.new(0.35) }):Play()
		end)
	end

	if eggSwellMul > 1.001 then
		TweenService:Create(eggFrame, TweenInfo.new(breakT, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(eggW, eggH),
		}):Play()
	end

	local t0 = os.clock()
	local rotAtFreeze = 0
	local baseEggPos = eggFrame.Position
	local rockConn: RBXScriptConnection? = nil
	rockConn = RunService.RenderStepped:Connect(function()
		if not eggFrame.Parent then
			if rockConn then
				rockConn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - t0
		if elapsed >= breakT + 0.05 then
			if rockConn then
				rockConn:Disconnect()
			end
			return
		end
		if hitstopDur > 0.001 and elapsed >= hitstopStart and elapsed < hitstopStart + hitstopDur then
			eggFrame.Rotation = rotAtFreeze
		elseif elapsed < hitstopStart then
			rotAtFreeze = HatchCrackVisualSpec.wobbleAt(hcEntry, elapsed)
			eggFrame.Rotation = rotAtFreeze
		else
			eggFrame.Rotation = rotAtFreeze
		end
		local jitterAfter = hcEntry.wobblePhases.jitterAfterSec or 2.5
		local jitterPx = hcEntry.wobblePhases.jitterPx or 1
		if rarity == "mythic" and elapsed > jitterAfter and elapsed < hitstopStart then
			local jx = (math.noise(elapsed * 8, 1.7, 0) - 0.5) * 2 * jitterPx
			local jy = (math.noise(elapsed * 8, 3.1, 0) - 0.5) * 2 * jitterPx
			eggFrame.Position = UDim2.new(baseEggPos.X.Scale, baseEggPos.X.Offset + jx, baseEggPos.Y.Scale, baseEggPos.Y.Offset + jy)
		elseif rarity == "mythic" then
			eggFrame.Position = baseEggPos
		end
	end)

	local dustDur = breakT + 0.35
	local dustAtt: Attachment? = nil
	if root then
		dustAtt = Instance.new("Attachment")
		dustAtt.Position = Vector3.new(0, -2, 0)
		dustAtt.Parent = root
		local dustRate = if lodTier <= 1 then 4 else 12
		local sparkRate = if lodTier <= 1 then 5 else 14
		if rarity == "uncommon" then
			dustRate += 1
			sparkRate += 1
		elseif rarity == "rare" then
			dustRate += 2
			sparkRate += 2
		elseif rarity == "epic" then
			dustRate += 4
			sparkRate += 6
		elseif rarity == "legendary" then
			dustRate += 6
			sparkRate += 11
		elseif rarity == "mythic" then
			dustRate += 8
			sparkRate += 16
		end
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromHex("D4C4A8"))
		dust.Lifetime = NumberRange.new(0.4, 0.8)
		dust.Rate = dustRate
		dust.Speed = NumberRange.new(2, 6)
		dust.SpreadAngle = Vector2.new(25, 25)
		dust.Parent = dustAtt
		local spark = Instance.new("ParticleEmitter")
		spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spark.Color = ColorSequence.new(hatchCol)
		spark.Lifetime = NumberRange.new(1.2, math.min(2, dustDur))
		spark.Rate = sparkRate
		spark.Speed = NumberRange.new(1, 4)
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.Parent = dustAtt
		task.delay(dustDur, function()
			dust.Enabled = false
			spark.Enabled = false
		end)
	end

	local vig = getVignetteFrame()
	vig.BackgroundTransparency = 0.92
	local vigTarget = if hcEntry.screenEffect.vignetteDarkenTo then hcEntry.screenEffect.vignetteDarkenTo else 0.85
	TweenService:Create(vig, TweenInfo.new(1.5), { BackgroundTransparency = vigTarget }):Play()

	if rarity == "legendary" then
		task.delay(0, function()
			TweenService:Create(vig, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.75 }):Play()
		end)
		task.delay(math.max(0, breakT - 0.5), function()
			TweenService:Create(vig, TweenInfo.new(0.35), { BackgroundTransparency = 0.65 }):Play()
		end)
	end

	task.delay(math.min(1.1, breakT * 0.45), function()
		TweenService:Create(eggFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundColor3 = hatchCol }):Play()
	end)

	local crackStyle = hcEntry.crackStyle
	local crackColor = crackStyle.color
	if crackStyle.lines and #crackStyle.lines > 0 then
		for _, ln in crackStyle.lines do
			task.delay(ln.spawnTimeSec, function()
				if not eggFrame.Parent then
					return
				end
				hatchSpawnCrackLine(
					eggFrame,
					41,
					ln.position,
					ln.sizeScale,
					ln.rotationDeg,
					crackColor,
					ln.fadeFrom,
					ln.fadeTo,
					ln.fadeDurationSec
				)
			end)
		end
		if rarity == "uncommon" then
			task.delay(0.8, function()
				if not eggFrame.Parent then
					return
				end
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = crackColor
				stroke.Transparency = 0.5
				stroke.Parent = eggFrame
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.2 }):Play()
			end)
		elseif rarity == "rare" then
			task.delay(1.3, function()
				if not eggFrame.Parent then
					return
				end
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 3
				stroke.Color = crackColor
				stroke.Transparency = 0.3
				stroke.Parent = eggFrame
			end)
		end
	elseif rarity == "epic" then
		local purp = crackColor
		for i = 1, 6 do
			task.delay((0.6 + (i - 1) * 0.22) * tScale, function()
				if not eggFrame.Parent then
					return
				end
				local ang = -40 + (i - 1) * 16
				hatchSpawnCrackLine(
					eggFrame,
					41,
					UDim2.new(0.5, 0, 0.12, 0),
					UDim2.new(0, 2 + (i % 2), 0.35 + (i % 3) * 0.1, 0),
					ang,
					purp,
					0.55,
					0.12,
					0.45
				)
			end)
		end
	elseif rarity == "legendary" then
		local gold = crackColor
		for i = 1, 8 do
			task.delay((0.75 + (i - 1) * 0.22) * tScale, function()
				if not eggFrame.Parent then
					return
				end
				local ang = -35 + (i - 1) * 9
				hatchSpawnCrackLine(
					eggFrame,
					41,
					UDim2.new(0.48 + (i % 2) * 0.04, 0, 0.1 + (i % 4) * 0.05, 0),
					UDim2.new(0, 3, 0.4 + (i % 3) * 0.08, 0),
					ang,
					gold,
					0.5,
					0.1,
					0.5
				)
			end)
		end
	elseif rarity == "mythic" then
		for i = 1, 10 do
			task.delay((0.45 + (i - 1) * 0.24) * tScale, function()
				if not eggFrame.Parent then
					return
				end
				local ang = (i - 1) * 34
				local c = if crackStyle.isRainbow then Color3.fromHSV((i * 0.09 + os.clock() * 0.1) % 1, 0.85, 1) else crackColor
				hatchSpawnCrackLine(
					eggFrame,
					41,
					UDim2.new(0.5, 0, 0.1, 0),
					UDim2.new(0, 3 + (i % 3), 0.45 + (i % 4) * 0.06, 0),
					ang,
					c,
					0.55,
					0.08,
					0.55
				)
			end)
		end
		for g = 1, 5 do
			hatchSpawnGlitchStrip(sg, 0.15 + g * 0.12, (2 + g * 0.18) * tScale)
		end
	end

	local function runRevealBurst()
		if eggFrame.Parent then
			if rarity == "mythic" then
				eggFrame.Visible = false
			else
				TweenService:Create(eggFrame, TweenInfo.new(0.32, Enum.EasingStyle.Quad), {
					BackgroundTransparency = 1,
					Rotation = if rarity == "common" then 5 else 8,
				}):Play()
			end
		end
		if epicGrad and epicGrad.Parent then
			TweenService:Create(epicGrad, TweenInfo.new(0.2), { Transparency = NumberSequence.new(1) }):Play()
		end
		if mythicEggGrad and mythicEggGrad.Parent then
			TweenService:Create(mythicEggGrad, TweenInfo.new(0.15), { Transparency = NumberSequence.new(1) }):Play()
		end
		TweenService:Create(vig, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
		if darkOverlay and darkOverlay.Parent then
			TweenService:Create(darkOverlay, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
		end

		local shakeAmt = if (hcEntry.cameraShakeIntensity or 0) > 0 then hcEntry.cameraShakeIntensity :: number else spec.shake
		if shakeAmt > 0 then
			local shakeDur = if (hcEntry.cameraShakeDurationSec or 0) > 0 then hcEntry.cameraShakeDurationSec :: number else (if rarity == "mythic" then 0.35 else 0.2)
			task.spawn(function()
				cameraShake(shakeAmt, shakeDur)
			end)
		end
		if rarity == "legendary" or rarity == "mythic" then
			local cam = workspace.CurrentCamera
			if cam then
				local startFov = cam.FieldOfView
				local punch = if (hcEntry.fovPunch or 0) > 0 then hcEntry.fovPunch :: number else (if rarity == "mythic" then 8 else 4)
				local punchInT = 0.28
				local returnT = if (hcEntry.fovReturnSec or 0) > 0 then hcEntry.fovReturnSec :: number else 0.28
				TweenService:Create(cam, TweenInfo.new(punchInT, Enum.EasingStyle.Quad), { FieldOfView = startFov + punch }):Play()
				task.delay(0.32, function()
					if cam.Parent then
						TweenService:Create(cam, TweenInfo.new(returnT), { FieldOfView = startFov }):Play()
					end
				end)
			end
		end

		local attParent = root or trailPart
		if attParent and attParent:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 1, 0)
			att.Parent = attParent
			emitBurst(att, spec, rarity, hatchCol, streakParticleMul)
			task.delay(spec.duration + 1, function()
				att:Destroy()
			end)
		end

		if rarity == "mythic" then
			screenFlash(Color3.new(1, 1, 1), 0.22, 0.12)
			task.delay(0.06, function()
				screenFlash(hatchCol, 0.45, 0.28)
			end)
		else
			screenFlash(hatchCol, 0.18, 0.55)
		end

		if isRarePlusRarity(rarity) then
			playLuckyStreakSounds(luckyStreak)
			if luckyStreak >= 5 then
				luckyStreakMegaCelebration()
			end
		end

		if isRarePlusRarity(rarity) and luckyStreak >= 2 then
			local streakLbl = Instance.new("TextLabel")
			streakLbl.Size = UDim2.new(0.92, 0, 0, 56)
			streakLbl.Position = UDim2.new(0.04, 0, 0.2, 0)
			streakLbl.BackgroundTransparency = 1
			streakLbl.Font = Enum.Font.GothamBlack
			streakLbl.TextSize = if luckyStreak >= 5 then 48 else 40
			streakLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
			streakLbl.TextStrokeColor3 = Color3.fromRGB(120, 70, 10)
			streakLbl.TextStrokeTransparency = 0.25
			streakLbl.Text = `LUCKY STREAK x{luckyStreak}!`
			streakLbl.ZIndex = 62
			streakLbl.Parent = sg
			local sc = Instance.new("UIScale")
			sc.Scale = 0.35
			sc.Parent = streakLbl
			TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
			TweenService:Create(streakLbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.04, 0, 0.14, 0),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			task.delay(0.95, function()
				streakLbl:Destroy()
			end)
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.9, 0, 0, 44)
		nameLbl.Position = UDim2.new(0.05, 0, 0.52, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 30
		nameLbl.TextColor3 = col
		nameLbl.TextStrokeTransparency = 0.3
		nameLbl.Text = petName .. " • " .. string.upper(rarity)
		nameLbl.ZIndex = 60
		nameLbl.Parent = sg
		TweenService:Create(nameLbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.05, 0, 0.46, 0),
			TextTransparency = 1,
		}):Play()
		task.delay(0.85, function()
			nameLbl:Destroy()
		end)
	end

	if rarity == "mythic" and hitstopDur > 0.001 then
		task.delay(hitstopStart, function()
			SoundFacade.playOneShot("egg_mythic_hum")
		end)
	end
	task.delay(breakT, runRevealBurst)

	if rarity == "common" or rarity == "uncommon" then
		task.delay(breakT + 0.25, function()
			local tpl = SocialFeedConfig.pickLine("PityEncouragement")
			local line = tpl:gsub("{n}", tostring(math.random(3, 14)))
			VFXController.milestonePopup(line, "almost_there")
		end)
	end

	task.delay(breakT + 1.5, function()
		local confRoot = root or trailPart
		if confRoot and confRoot:IsA("BasePart") then
			local ca = Instance.new("Attachment")
			ca.Parent = confRoot
			local conf = Instance.new("ParticleEmitter")
			conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			conf.Color = ColorSequence.new(col)
			conf.Lifetime = NumberRange.new(0.6, 1.2)
			conf.Rate = if lodTier <= 1 then 12 else 32
			conf.Speed = NumberRange.new(6, 18)
			conf.SpreadAngle = Vector2.new(40, 40)
			conf.EmissionDirection = Enum.NormalId.Top
			conf.Acceleration = Vector3.new(0, -35, 0)
			conf.Parent = ca
			task.delay(1.2, function()
				conf.Rate = 0
			end)
			task.delay(2.5, function()
				ca:Destroy()
			end)
		end
	end)

	task.delay(totalT + 1.2, function()
		if eggFrame.Parent then
			eggFrame:Destroy()
		end
		if darkOverlay and darkOverlay.Parent then
			darkOverlay:Destroy()
		end
	end)

	task.delay(dustDur + 0.25, function()
		if dustAtt then
			dustAtt:Destroy()
		end
	end)
end

function VFXController.fusionReveal(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local rarity = if type(payload.rarity) == "string" then string.lower(payload.rarity) else "common"
	local petName = if type(payload.petName) == "string" then payload.petName else "Pet"
	local newPower = if type(payload.power) == "number" then payload.power else 0
	local prevPower = if type(payload.previousPowerTotal) == "number" then payload.previousPowerTotal else 0
	local sourceRarity = if type(payload.sourceRarity) == "string" then string.lower(payload.sourceRarity) else "common"
	local sacrificedNames: { string } = {}
	if type(payload.sacrificedNames) == "table" then
		for _, n in payload.sacrificedNames do
			if type(n) == "string" then
				table.insert(sacrificedNames, n)
			end
		end
	end

	local startPower = math.floor(prevPower)
	local endPower = math.floor(newPower)
	if endPower <= startPower then
		startPower = math.max(0, endPower - math.max(8, math.floor(endPower * 0.08)))
	end

	local col = Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
	local srcCol = Constants.RARITY_COLORS[sourceRarity] or Color3.fromRGB(160, 170, 200)
	local spec = BURST_TABLE[rarity] or BURST_TABLE.common

	local sg = screenGui
	if not sg then
		return
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attParent = root or trailPart

	local layer = getCelebrationLayer()
	local chamber = Instance.new("Frame")
	chamber.Name = "FusionChamber"
	chamber.Size = UDim2.fromOffset(420, 420)
	chamber.Position = UDim2.new(0.5, 0, 0.42, 0)
	chamber.AnchorPoint = Vector2.new(0.5, 0.5)
	chamber.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	chamber.BackgroundTransparency = 0.12
	chamber.ZIndex = CELEBRATION_Z + 1
	chamber.Parent = layer
	local chCorner = Instance.new("UICorner")
	chCorner.CornerRadius = UDim.new(0, 28)
	chCorner.Parent = chamber
	local chStroke = Instance.new("UIStroke")
	chStroke.Thickness = 3
	chStroke.Color = srcCol
	chStroke.Transparency = 0.35
	chStroke.Parent = chamber

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.new(0, 12, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(220, 225, 245)
	title.Text = "FUSION CHAMBER"
	title.ZIndex = CELEBRATION_Z + 2
	title.Parent = chamber

	local core = Instance.new("Frame")
	core.Name = "ChamberCore"
	core.Size = UDim2.fromOffset(280, 280)
	core.Position = UDim2.new(0.5, 0, 0.52, 0)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.BackgroundTransparency = 1
	core.ZIndex = CELEBRATION_Z + 2
	core.Parent = chamber

	local orbs: { Frame } = {}
	for i = 1, 3 do
		local orb = Instance.new("Frame")
		orb.Size = UDim2.fromOffset(72, 72)
		orb.AnchorPoint = Vector2.new(0.5, 0.5)
		orb.BackgroundColor3 = srcCol
		orb.ZIndex = CELEBRATION_Z + 3
		orb.Parent = core
		local oc = Instance.new("UICorner")
		oc.CornerRadius = UDim.new(1, 0)
		oc.Parent = orb
		local ol = Instance.new("TextLabel")
		ol.Size = UDim2.fromScale(1, 1)
		ol.BackgroundTransparency = 1
		ol.Font = Enum.Font.GothamBlack
		ol.TextSize = 28
		ol.TextColor3 = Color3.fromRGB(255, 255, 255)
		local sn = sacrificedNames[i]
		ol.Text = if sn and sn ~= "" then string.upper(string.sub(sn, 1, 1)) else tostring(i)
		ol.ZIndex = CELEBRATION_Z + 4
		ol.Parent = orb
		table.insert(orbs, orb)
	end

	local vig = getVignetteFrame()
	vig.BackgroundTransparency = 0.94
	TweenService:Create(vig, TweenInfo.new(1.2), { BackgroundTransparency = 0.82 }):Play()

	SoundFacade.playOneShot("notification")

	local tOrbit0 = os.clock()
	local orbitConn: RBXScriptConnection? = nil
	orbitConn = RunService.RenderStepped:Connect(function()
		if not core.Parent then
			if orbitConn then
				orbitConn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - tOrbit0
		local merge = math.clamp(elapsed / 2.05, 0, 1)
		local radiusPx = (1 - merge) * 118 + 4
		local spin = elapsed * 2.8
		for i, orb in orbs do
			local a = spin + (i - 1) * (math.pi * 2 / 3)
			orb.Position = UDim2.new(0.5, math.cos(a) * radiusPx, 0.5, math.sin(a) * radiusPx)
			orb.Rotation = math.deg(spin * 12 + i * 40)
		end
		if elapsed >= 2.15 then
			if orbitConn then
				orbitConn:Disconnect()
			end
		end
	end)

	task.delay(2.18, function()
		for _, orb in orbs do
			TweenService:Create(orb, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
			}):Play()
			for _, d in orb:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.12), { TextTransparency = 1 }):Play()
				end
			end
		end
		screenFlash(Color3.new(1, 1, 1), 0.32, 0.18)
		TweenService:Create(chStroke, TweenInfo.new(0.2), { Color = col, Thickness = 6 }):Play()
		SoundFacade.playOneShot("level_up")
	end)

	task.delay(2.35, function()
		if attParent and attParent:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 1.2, 0)
			att.Parent = attParent
			emitBurst(att, spec, rarity, col, 1)
			task.delay(spec.duration + 1.2, function()
				if att.Parent then
					att:Destroy()
				end
			end)
		end

		if rarity == "legendary" or rarity == "mythic" then
			task.spawn(function()
				cameraShake(if rarity == "mythic" then 0.42 else 0.28, if rarity == "mythic" then 0.45 else 0.32)
			end)
			screenFlash(col, 0.22, 0.42)
			if rarity == "mythic" then
				screenFlash(Color3.new(1, 1, 1), 0.18, 0.14)
				task.delay(0.06, function()
					local f = getFlashLayer()
					f.BackgroundColor3 = Color3.new(1, 1, 1)
					local tw = TweenService:Create(
						f,
						TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 0.38 }
					)
					tw:Play()
					tw.Completed:Connect(function()
						TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
					end)
				end)
				SoundFacade.playOneShot("hatch_mythic")
			else
				SoundFacade.playOneShot("hatch_legendary")
			end
		end
	end)

	local powerLbl = Instance.new("TextLabel")
	powerLbl.Size = UDim2.new(0.92, 0, 0, 48)
	powerLbl.Position = UDim2.new(0.04, 0, 0.78, 0)
	powerLbl.BackgroundTransparency = 1
	powerLbl.Font = Enum.Font.GothamBlack
	powerLbl.TextSize = 44
	powerLbl.TextColor3 = Color3.fromRGB(255, 230, 120)
	powerLbl.TextStrokeColor3 = Color3.fromRGB(80, 50, 10)
	powerLbl.TextStrokeTransparency = 0.35
	powerLbl.Text = "POWER " .. tostring(startPower)
	powerLbl.ZIndex = CELEBRATION_Z + 5
	powerLbl.Parent = chamber

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.94, 0, 0, 52)
	banner.Position = UDim2.new(0.03, 0, 0.02, 0)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 38
	banner.TextColor3 = Color3.fromRGB(255, 240, 140)
	banner.TextStrokeColor3 = Color3.fromRGB(90, 60, 20)
	banner.TextStrokeTransparency = 0.3
	banner.Text = ""
	banner.ZIndex = CELEBRATION_Z + 6
	banner.Parent = chamber

	local silhouette = Instance.new("Frame")
	silhouette.Size = UDim2.fromOffset(168, 168)
	silhouette.Position = UDim2.new(0.5, 0, 0.44, 0)
	silhouette.AnchorPoint = Vector2.new(0.5, 0.5)
	silhouette.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	silhouette.ZIndex = CELEBRATION_Z + 4
	silhouette.Parent = chamber
	local silCorner = Instance.new("UICorner")
	silCorner.CornerRadius = UDim.new(0, 20)
	silCorner.Parent = silhouette
	local silStroke = Instance.new("UIStroke")
	silStroke.Thickness = 2
	silStroke.Color = col
	silStroke.Transparency = 0.5
	silStroke.Parent = silhouette
	local silMark = Instance.new("TextLabel")
	silMark.Size = UDim2.fromScale(1, 1)
	silMark.BackgroundTransparency = 1
	silMark.Font = Enum.Font.GothamBlack
	silMark.TextSize = 96
	silMark.TextColor3 = Color3.fromRGB(40, 44, 58)
	silMark.Text = "?"
	silMark.ZIndex = CELEBRATION_Z + 5
	silMark.Parent = silhouette

	local nameReveal = Instance.new("TextLabel")
	nameReveal.Size = UDim2.new(0.92, 0, 0, 36)
	nameReveal.Position = UDim2.new(0.04, 0, 0.9, 0)
	nameReveal.BackgroundTransparency = 1
	nameReveal.Font = Enum.Font.GothamBold
	nameReveal.TextSize = 26
	nameReveal.TextColor3 = col
	nameReveal.TextTransparency = 1
	nameReveal.Text = petName .. "  •  " .. string.upper(rarity)
	nameReveal.ZIndex = CELEBRATION_Z + 6
	nameReveal.Parent = chamber

	silhouette.Visible = false
	nameReveal.Visible = false
	banner.Visible = false

	task.delay(2.32, function()
		banner.Visible = true
		banner.Text = "FUSION COMPLETE!"
		local bs = Instance.new("UIScale")
		bs.Scale = 0.2
		bs.Parent = banner
		TweenService:Create(bs, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	task.delay(2.42, function()
		silhouette.Visible = true
		silMark.TextTransparency = 0
		TweenService:Create(silhouette, TweenInfo.new(0.25), { BackgroundColor3 = Color3.fromRGB(28, 32, 48) }):Play()
	end)

	task.delay(2.68, function()
		TweenService:Create(silMark, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(silhouette, TweenInfo.new(0.45), { BackgroundTransparency = 0.55 }):Play()
		TweenService:Create(silStroke, TweenInfo.new(0.45), { Transparency = 0.85 }):Play()
		nameReveal.Visible = true
		TweenService:Create(nameReveal, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end)

	local countDur = 1.15
	local countConn: RBXScriptConnection? = nil
	task.delay(2.35, function()
		local countStart = os.clock()
		countConn = RunService.RenderStepped:Connect(function()
			if not powerLbl.Parent then
				if countConn then
					countConn:Disconnect()
				end
				return
			end
			local t = math.clamp((os.clock() - countStart) / countDur, 0, 1)
			local eased = 1 - (1 - t) * (1 - t)
			local v = math.floor(startPower + (endPower - startPower) * eased + 0.5)
			powerLbl.Text = "POWER " .. tostring(v)
			powerLbl.TextColor3 = Color3.fromRGB(255, 230, 120):Lerp(col, eased * 0.85)
			if t >= 1 then
				powerLbl.Text = "POWER " .. tostring(endPower)
				if countConn then
					countConn:Disconnect()
				end
			end
		end)
	end)

	task.delay(5.2, function()
		TweenService:Create(vig, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		if chamber.Parent then
			TweenService:Create(chamber, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
			for _, d in chamber:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
		end
	end)
	task.delay(5.85, function()
		chamber:Destroy()
	end)
end

local function rebirthMilestoneLabel(key: string): string
	for _, row in ipairs(RebirthMilestoneConfig.MILESTONES) do
		if row.key == key then
			return row.label
		end
	end
	return "REBIRTH!"
end

local function spawnScreenParticles(seq: ColorSequence, emitMul: number, spread: number, speedMin: number, speedMax: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = cam
	att.WorldCFrame = cam.CFrame * CFrame.new(0, 0, -12)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = seq
	p.Lifetime = NumberRange.new(0.5, 1.1)
	p.Speed = NumberRange.new(speedMin, speedMax)
	p.SpreadAngle = Vector2.new(spread, spread)
	p.Size = NumberSequence.new(0.4, 1.8)
	p.LightEmission = 0.55
	p.Rate = 0
	p.Parent = att
	p:Emit(math.floor(emitMul * lodBurstMul()))
	task.delay(1.5, function()
		att:Destroy()
	end)
end

local function rebirthMilestoneVfx(key: string, rebirthCount: number, suppressTextLabels: boolean?)
	local label = rebirthMilestoneLabel(key)
	local sg = screenGui
	local mul = lodBurstMul()

	if key == "veteran" then
		screenFlash(Color3.fromRGB(200, 120, 60), 0.55, 0.68)
		task.delay(0.1, function()
			screenFlash(Color3.fromRGB(255, 200, 120), 0.5, 0.52)
		end)
		SoundFacade.playOneShot("rebirth_boom")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Color = ColorSequence.new(Color3.fromRGB(180, 110, 55))
			p.Lifetime = NumberRange.new(0.35, 0.75)
			p.Speed = NumberRange.new(14, 32)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Size = NumberSequence.new(0.35, 1.2)
			p.Rate = 0
			p.Parent = att
			p:Emit(math.floor(140 * mul))
			task.delay(1.2, function()
				att:Destroy()
			end)
		end
	elseif key == "elite" then
		screenFlash(Color3.fromRGB(220, 230, 240), 0.55, 0.65)
		SoundFacade.playOneShot("rebirth_confetti")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			for i = 1, 3 do
				local att = Instance.new("Attachment")
				att.Position = Vector3.new((i - 2) * 1.2, 4 + i * 0.8, 0)
				att.Parent = root
				local p = Instance.new("ParticleEmitter")
				p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				p.Color = ColorSequence.new(Color3.fromRGB(210, 220, 235))
				p.Lifetime = NumberRange.new(0.6, 1.2)
				p.Speed = NumberRange.new(10, 22)
				p.EmissionDirection = Enum.NormalId.Bottom
				p.SpreadAngle = Vector2.new(40, 40)
				p.Size = NumberSequence.new(0.25, 0.9)
				p.Rate = 0
				p.Parent = att
				p:Emit(math.floor(90 * mul))
				task.delay(1.4, function()
					att:Destroy()
				end)
			end
		end
		spawnScreenParticles(ColorSequence.new(Color3.fromRGB(200, 215, 230)), 160, 180, 4, 18)
	elseif key == "master" then
		screenFlash(Color3.new(1, 1, 1), 0.45, 0.2)
		task.delay(0.08, function()
			screenFlash(Color3.fromRGB(255, 200, 60), 0.65, 0.55)
		end)
		task.delay(0.18, function()
			screenFlash(Color3.fromRGB(255, 170, 40), 0.55, 0.62)
		end)
		task.spawn(function()
			cameraShake(0.5, 0.45)
		end)
		SoundFacade.playOneShot("rebirth_boom")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
			p.Lifetime = NumberRange.new(0.4, 0.95)
			p.Speed = NumberRange.new(18, 42)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Size = NumberSequence.new(0.5, 2.0)
			p.Rate = 0
			p.Parent = att
			p:Emit(math.floor(220 * mul))
			task.delay(1.3, function()
				att:Destroy()
			end)
		end
		spawnScreenParticles(ColorSequence.new(Color3.fromRGB(255, 210, 70)), 200, 180, 8, 28)
	elseif key == "legend" then
		screenFlash(Color3.fromRGB(200, 250, 255), 0.5, 0.18)
		task.delay(0.1, function()
			screenFlash(Color3.fromRGB(120, 220, 255), 0.6, 0.58)
		end)
		task.spawn(function()
			cameraShake(0.65, 0.55)
		end)
		SoundFacade.playOneShot("rebirth_boom")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 230, 255)),
			})
			p.Lifetime = NumberRange.new(0.45, 1.0)
			p.Speed = NumberRange.new(14, 38)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Size = NumberSequence.new(0.45, 2.2)
			p.Rate = 0
			p.Parent = att
			p:Emit(math.floor(260 * mul))
			task.delay(1.4, function()
				att:Destroy()
			end)
		end
		spawnScreenParticles(ColorSequence.new(Color3.fromRGB(185, 245, 255)), 320, 180, 10, 32)
		spawnScreenParticles(ColorSequence.new(Color3.fromRGB(255, 255, 255)), 280, 200, 6, 24)
	else
		-- immortal
		screenFlash(Color3.new(1, 1, 1), 0.55, 0.12)
		task.delay(0.1, function()
			screenFlash(Color3.fromRGB(255, 100, 200), 0.5, 0.5)
		end)
		task.delay(0.2, function()
			screenFlash(Color3.fromRGB(100, 200, 255), 0.55, 0.52)
		end)
		task.spawn(function()
			cameraShake(0.85, 0.75)
		end)
		SoundFacade.playOneShot("rebirth_riser")
		task.delay(0.15, function()
			SoundFacade.playOneShot("rebirth_boom")
		end)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Color = mythicRainbowSequence()
			p.Lifetime = NumberRange.new(0.5, 1.2)
			p.Speed = NumberRange.new(14, 45)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Size = NumberSequence.new(0.5, 2.4)
			p.Rate = 0
			p.Parent = att
			p:Emit(math.floor(340 * mul))
			task.delay(1.5, function()
				att:Destroy()
			end)
		end
		spawnScreenParticles(mythicRainbowSequence(), 420, 200, 12, 36)
		if sg then
			local crack = Instance.new("Frame")
			crack.Name = "DAC_UniverseCrack"
			crack.BackgroundTransparency = 0.6
			crack.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
			crack.BorderSizePixel = 0
			crack.Size = UDim2.fromScale(1, 1)
			crack.ZIndex = CELEBRATION_Z + 2
			crack.Parent = getCelebrationLayer()
			local grad = Instance.new("UIGradient")
			grad.Color = mythicRainbowSequence()
			grad.Rotation = 35
			grad.Parent = crack
			TweenService:Create(grad, TweenInfo.new(0.6, Enum.EasingStyle.Linear), { Rotation = 125 }):Play()
			TweenService:Create(crack, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			task.delay(2.35, function()
				crack:Destroy()
			end)
		end
	end

	if sg and not suppressTextLabels then
		local n = Instance.new("TextLabel")
		n.Size = UDim2.new(1, 0, 0, 140)
		n.Position = UDim2.new(0, 0, 0.32, 0)
		n.BackgroundTransparency = 1
		n.Font = Enum.Font.GothamBlack
		n.TextSize = if key == "immortal" then 96 elseif key == "legend" then 88 else 80
		n.TextColor3 = if key == "veteran" then Color3.fromRGB(220, 150, 90)
			elseif key == "elite" then Color3.fromRGB(220, 230, 245)
			elseif key == "master" then Color3.fromRGB(255, 220, 100)
			elseif key == "legend" then Color3.fromRGB(200, 250, 255)
			else Color3.fromRGB(255, 245, 255)
		n.TextStrokeTransparency = 0.2
		n.Text = label
		n.ZIndex = CELEBRATION_Z + 2
		n.Parent = sg
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 48)
		sub.Position = UDim2.new(0, 0, 0.42, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 28
		sub.TextColor3 = Color3.fromRGB(255, 230, 200)
		sub.TextTransparency = 0.2
		sub.TextStrokeTransparency = 0.35
		sub.Text = "REBIRTH #" .. tostring(rebirthCount)
		sub.ZIndex = CELEBRATION_Z + 2
		sub.Parent = sg
		TweenService:Create(n, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0.18, 0),
			TextTransparency = 1,
		}):Play()
		TweenService:Create(sub, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0.28, 0),
			TextTransparency = 1,
		}):Play()
		task.delay(1.95, function()
			n:Destroy()
			sub:Destroy()
		end)
	end
end

local function rebirthFlashStandard(rebirthCount: number)
	screenFlash(Color3.new(1, 1, 1), 0.55, 0.72)
	task.delay(0.08, function()
		screenFlash(Color3.fromRGB(255, 210, 90), 0.6, 0.55)
	end)

	local sg = screenGui
	if not sg then
		return
	end
	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(1, 0, 0, 120)
	n.Position = UDim2.new(0, 0, 0.35, 0)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.GothamBold
	n.TextSize = 72
	n.TextColor3 = Color3.fromRGB(255, 230, 120)
	n.TextStrokeTransparency = 0.2
	n.Text = "REBIRTH +" .. tostring(rebirthCount)
	n.ZIndex = 70
	n.Parent = sg
	TweenService:Create(n, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.22, 0),
		TextTransparency = 1,
	}):Play()
	task.delay(1.5, function()
		n:Destroy()
	end)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Parent = root
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
		p.Lifetime = NumberRange.new(0.5, 1.1)
		p.Speed = NumberRange.new(10, 28)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Size = NumberSequence.new(0.4, 1.5)
		p.Parent = att
		local mul = lodBurstMul()
		p:Emit(math.floor(90 * mul))
		task.delay(1.4, function()
			att:Destroy()
		end)
	end
end

function VFXController.rebirthFlash(rebirthCount: number, milestoneKey: string?, suppressTextLabels: boolean?)
	if rebirthCount <= lastRebirthCelebrated then
		return
	end
	lastRebirthCelebrated = rebirthCount

	if milestoneKey and milestoneKey ~= "" then
		rebirthMilestoneVfx(milestoneKey, rebirthCount, suppressTextLabels)
	else
		rebirthFlashStandard(rebirthCount)
	end
end

local function acquirePopup(): TextLabel
	popupIndex += 1
	if popupIndex > #popupPool then
		popupIndex = 1
	end
	return popupPool[popupIndex]
end

function VFXController.milestonePopup(text: string, style: string?)
	local sg = screenGui
	if not sg then
		return
	end
	local st = style or "small"
	local lbl = acquirePopup()
	lbl.Text = text
	lbl.TextTransparency = 0
	lbl.TextStrokeTransparency = 0.35
	lbl.Visible = true
	lbl.AnchorPoint = Vector2.new(0.5, 0.45)

	if st == "distance_small" then
		lbl.TextSize = 26
		lbl.TextColor3 = Color3.fromRGB(255, 250, 220)
		SoundFacade.playOneShot("distance_marker")
		local spark = Instance.new("ParticleEmitter")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			spark.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
			spark.Lifetime = NumberRange.new(0.25, 0.5)
			spark.Speed = NumberRange.new(4, 14)
			spark.SpreadAngle = Vector2.new(180, 180)
			spark.Rate = 0
			spark.Parent = root
			spark:Emit(math.floor(12 * lodBurstMul()))
			task.delay(0.6, function()
				spark:Destroy()
			end)
		end
	elseif st == "distance_medium" then
		lbl.TextSize = 34
		lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
		screenFlash(Color3.new(1, 1, 1), 0.28, 0.2)
		SoundFacade.playOneShot("level_up")
	elseif st == "distance_big" then
		lbl.TextSize = 44
		lbl.TextColor3 = Color3.fromRGB(255, 215, 60)
		screenFlash(Color3.fromRGB(255, 220, 80), 0.45, 0.28)
		task.spawn(function()
			cameraShake(0.45, 0.35)
		end)
		SoundFacade.playOneShot("level_up")
	elseif st == "banner" then
		lbl.TextSize = 52
		lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
		lbl.Position = UDim2.new(0.5, 0, 0.28, 0)
		TweenService:Create(lbl, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.18, 0),
			TextTransparency = 1,
		}):Play()
		task.delay(2.3, function()
			lbl.Visible = false
		end)
		return
	elseif st == "ascended" then
		lbl.TextSize = 64
		lbl.TextColor3 = Color3.fromRGB(255, 230, 100)
		screenFlash(Color3.new(1, 1, 1), 0.5, 0.15)
		task.delay(0.1, function()
			screenFlash(Color3.fromRGB(255, 200, 60), 0.55, 0.5)
		end)
		task.spawn(function()
			cameraShake(0.55, 0.45)
		end)
		SoundFacade.playOneShot("rebirth_boom")
	elseif st == "world_unlock" then
		lbl.TextSize = 40
		lbl.TextColor3 = Color3.fromRGB(200, 255, 220)
		local worldId = "grasslands"
		local pipe = string.find(text, "|", 1, true)
		if pipe then
			lbl.Text = string.sub(text, 1, pipe - 1)
			worldId = string.sub(text, pipe + 1)
		else
			lbl.Text = "NEW WORLD UNLOCKED!"
			worldId = text
		end
		local flashCol = WORLD_TRAIL_NEON[worldId] or WORLD_TRAIL_NEON.grasslands
		screenFlash(flashCol, 0.4, 0.35)
		SoundFacade.playOneShot("world_unlock")
	elseif st == "close_call" then
		lbl.TextSize = 32
		lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
		SoundFacade.playOneShot("notification")
	elseif st == "first_pet" then
		lbl.TextSize = 48
		lbl.TextColor3 = Color3.fromRGB(255, 255, 200)
		SoundFacade.playOneShot("hatch_legendary")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local conf = Instance.new("ParticleEmitter")
			conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			conf.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
			conf.Lifetime = NumberRange.new(0.4, 0.9)
			conf.Speed = NumberRange.new(6, 18)
			conf.SpreadAngle = Vector2.new(180, 180)
			conf.Rate = 0
			conf.Parent = att
			conf:Emit(math.floor(40 * lodBurstMul()))
			task.delay(1.2, function()
				att:Destroy()
			end)
		end
	elseif st == "petdex_25" then
		lbl.TextSize = 30
		lbl.TextColor3 = Color3.fromRGB(120, 220, 140)
		screenFlash(Color3.fromRGB(100, 200, 130), 0.22, 0.45)
		SoundFacade.playOneShot("notification")
	elseif st == "petdex_50" then
		lbl.TextSize = 36
		lbl.TextColor3 = Color3.fromRGB(255, 210, 90)
		screenFlash(Color3.fromRGB(255, 200, 80), 0.32, 0.38)
		SoundFacade.playOneShot("level_up")
	elseif st == "petdex_75" then
		lbl.TextSize = 42
		lbl.TextColor3 = Color3.fromRGB(255, 160, 70)
		screenFlash(Color3.fromRGB(255, 140, 60), 0.4, 0.32)
		task.spawn(function()
			cameraShake(0.35, 0.28)
		end)
		SoundFacade.playOneShot("level_up")
	elseif st == "petdex_100" then
		lbl.TextSize = 54
		lbl.TextColor3 = Color3.fromRGB(255, 245, 160)
		screenFlash(Color3.new(1, 1, 1), 0.45, 0.14)
		task.delay(0.08, function()
			screenFlash(Color3.fromRGB(255, 200, 80), 0.55, 0.45)
		end)
		task.spawn(function()
			cameraShake(0.55, 0.42)
		end)
		SoundFacade.playOneShot("rebirth_boom")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local att = Instance.new("Attachment")
			att.Parent = root
			local conf = Instance.new("ParticleEmitter")
			conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			conf.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
			conf.Lifetime = NumberRange.new(0.5, 1.1)
			conf.Speed = NumberRange.new(10, 26)
			conf.SpreadAngle = Vector2.new(180, 180)
			conf.Rate = 0
			conf.Parent = att
			conf:Emit(math.floor(110 * lodBurstMul()))
			task.delay(1.4, function()
				att:Destroy()
			end)
		end
	elseif st == "failure_toast" then
		lbl.TextSize = 30
		lbl.TextColor3 = Color3.fromRGB(255, 140, 130)
		lbl.TextStrokeColor3 = Color3.fromRGB(60, 20, 20)
		lbl.Position = UDim2.new(0.5, 0, 0.78, 0)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		local dur = 1.05
		TweenService:Create(lbl, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.82, 0),
		}):Play()
		task.delay(dur + 0.05, function()
			lbl.Visible = false
		end)
		return
	elseif st == "world_arrival" then
		local headline = "Welcome!"
		local flavor = ""
		local worldId = "grasslands"
		local p1 = string.find(text, "|", 1, true)
		if p1 then
			headline = string.sub(text, 1, p1 - 1)
			local rest = string.sub(text, p1 + 1)
			local p2 = string.find(rest, "|", 1, true)
			if p2 then
				flavor = string.sub(rest, 1, p2 - 1)
				worldId = string.sub(rest, p2 + 1)
			else
				flavor = rest
			end
		end
		if flavor ~= "" then
			lbl.Text = headline .. "\n" .. flavor
		else
			lbl.Text = headline
		end
		lbl.TextSize = 28
		lbl.TextColor3 = Color3.fromRGB(255, 245, 215)
		lbl.Position = UDim2.new(0.5, 0, 0.38, 0)
		local flashCol = WORLD_TRAIL_NEON[worldId] or WORLD_TRAIL_NEON.grasslands
		screenFlash(flashCol, 0.2, 0.26)
	elseif st == "almost_there" then
		lbl.TextSize = 28
		lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
		lbl.Position = UDim2.new(0.5, 0, 0.86, 0)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		local sc = Instance.new("UIScale")
		sc.Scale = 1
		sc.Parent = lbl
		SoundFacade.playOneShot("notification")
		local t0 = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			if not lbl.Parent or not sc.Parent then
				if conn then
					conn:Disconnect()
				end
				return
			end
			local elapsed = os.clock() - t0
			if elapsed >= 2.4 then
				if conn then
					conn:Disconnect()
				end
				TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
				task.delay(0.45, function()
					if lbl.Parent then
						lbl.Visible = false
					end
				end)
				return
			end
			sc.Scale = 1 + 0.045 * math.sin(elapsed * 8)
		end)
		return
	elseif st == "first_time_ceremony" then
		lbl.TextSize = 40
		lbl.TextColor3 = Color3.fromRGB(255, 225, 120)
		lbl.Size = UDim2.fromOffset(560, 96)
		screenFlash(Color3.fromRGB(255, 200, 80), 0.32, 0.26)
		SoundFacade.playOneShot("level_up")
	elseif st == "streak_milestone" then
		lbl.TextSize = 36
		lbl.TextColor3 = Color3.fromRGB(255, 210, 255)
		screenFlash(Color3.fromRGB(255, 140, 200), 0.22, 0.32)
		SoundFacade.playOneShot("notification")
	elseif st == "lap_pb" then
		lbl.TextSize = 36
		lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
	elseif st == "lap_humor" then
		lbl.TextSize = 28
		lbl.TextColor3 = Color3.fromRGB(255, 200, 160)
	elseif st == "lap_complete" then
		lbl.TextSize = 32
		lbl.TextColor3 = Color3.fromRGB(255, 245, 210)
	else
		lbl.TextSize = 30
		lbl.TextColor3 = Color3.new(1, 1, 1)
	end

	if st ~= "banner" and st ~= "world_unlock" and st ~= "world_arrival" then
		lbl.Position = UDim2.new(0.5, (math.random() - 0.5) * 80, 0.42, (math.random() - 0.5) * 20)
		local dur = if st == "close_call" then 0.85
			elseif st == "first_time_ceremony" then 2.1
			elseif st == "streak_milestone" then 2.0
			elseif st == "petdex_100" then 2.35
			elseif st == "petdex_75" then 1.85
			elseif st == "petdex_50" then 1.75
			elseif st == "petdex_25" then 1.7
			else 1.6
		TweenService:Create(lbl, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, (math.random() - 0.5) * 40, 0.32, 0),
			TextTransparency = 1,
		}):Play()
		task.delay(dur + 0.05, function()
			lbl.Visible = false
		end)
	elseif st == "world_unlock" or st == "world_arrival" then
		lbl.Position = UDim2.new(0.5, 0, 0.4, 0)
		TweenService:Create(lbl, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.3, 0),
			TextTransparency = 1,
		}):Play()
		task.delay(1.85, function()
			lbl.Visible = false
		end)
	end
end

local function escapeRichtext(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function VFXController.ceremonyFirstTime(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local body = payload.body
	if type(body) ~= "string" or body == "" then
		return
	end
	VFXController.milestonePopup(body, "first_time_ceremony")
end

function VFXController.ceremonySpendMilestone(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local sg = screenGui
	if not sg then
		return
	end
	local tier = tostring(payload.tierName or "")
	local title = tostring(payload.title or "")
	local subtitle = tostring(payload.subtitle or "")
	local description = tostring(payload.description or "")
	local lbl = acquirePopup()
	lbl.RichText = true
	lbl.TextWrapped = true
	lbl.Size = UDim2.fromOffset(520, 220)
	lbl.Text = string.format(
		'<font size="18" color="#BBBBBB">%s</font>\n<font size="32" color="#FFD966">%s</font>\n<font size="22">%s</font>\n<font size="17" color="#CCCCCC">%s</font>',
		escapeRichtext(tier),
		escapeRichtext(title),
		escapeRichtext(subtitle),
		escapeRichtext(description)
	)
	lbl.TextTransparency = 0
	lbl.TextStrokeTransparency = 0.35
	lbl.Visible = true
	lbl.Position = UDim2.new(0.5, 0, 0.36, 0)
	screenFlash(Color3.fromRGB(255, 200, 80), 0.4, 0.32)
	task.spawn(function()
		cameraShake(0.35, 0.28)
	end)
	SoundFacade.playOneShot("rebirth_boom")
	TweenService:Create(lbl, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.26, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(2.45, function()
		lbl.Visible = false
		lbl.RichText = false
		lbl.TextWrapped = false
		lbl.Text = ""
		lbl.Size = UDim2.fromOffset(280, 48)
	end)
end

function VFXController.ceremonyStreakMilestone(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local body = payload.body
	if type(body) ~= "string" or body == "" then
		return
	end
	VFXController.milestonePopup(body, "streak_milestone")
end

local function subVfxTemplate(s: string, vars: { [string]: string }): string
	local out = s
	for k, v in pairs(vars) do
		out = string.gsub(out, "{" .. k .. "}", v)
	end
	return out
end

local function getCurrencyAmount(data: any, currency: string): number
	local c = string.lower(currency)
	if c == "coins" then
		return if type(data.coins) == "number" then data.coins else 0
	elseif c == "gems" then
		return if type(data.gems) == "number" then data.gems else 0
	elseif c == "crystals" then
		return if type(data.crystals) == "number" then data.crystals else 0
	end
	return 0
end

local function tryAlmostThereNudge(kind: string, text: string): boolean
	local now = os.clock()
	local last = lastAlmostNudgeAt[kind]
	if last and (now - last) < ALMOST_NUDGE_COOLDOWN_SEC then
		return false
	end
	lastAlmostNudgeAt[kind] = now
	VFXController.milestonePopup(text, "almost_there")
	return true
end

local function processAlmostThereNudges(data: any)
	if type(data) ~= "table" then
		return
	end
	local tpl = (SocialFeedConfig :: any).AlmostThereVFX
	if type(tpl) ~= "table" then
		return
	end

	local reb = if type(data.rebirths) == "number" then data.rebirths else 0
	local coins = if type(data.coins) == "number" then data.coins else 0
	local worlds = cloneWorldMap(data.unlockedWorlds)

	local cost = Utils.calculateRebirthCost(reb, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
	if cost > 0 and coins >= cost * 0.8 and coins < cost then
		local line = tpl.rebirth
		if type(line) == "string" and line ~= "" then
			tryAlmostThereNudge("rebirth", line)
		end
	end

	local sorted = WorldConfig.getWorldsSorted()
	local nextWorldRow: any = nil
	for _, w in sorted do
		if not worlds[w.id] then
			nextWorldRow = WorldConfig.Worlds[w.id]
			break
		end
	end

	if nextWorldRow then
		local wid = nextWorldRow.id :: string
		local thresholds = (WorldUnlockConfig :: any).RebirthThresholdsByWorldId
		local worldNudged = false
		local wantRebirthWorldNudge = false
		if type(thresholds) == "table" then
			local needReb = thresholds[wid]
			if type(needReb) == "number" and needReb > 0 then
				local remaining = needReb - reb
				if remaining >= 1 and remaining <= 2 then
					wantRebirthWorldNudge = true
					local wm = nextWorldRow.name
					local key = if remaining == 1 then "worldOneRebirth" else "worldTwoRebirth"
					local line = tpl[key]
					if type(line) == "string" and line ~= "" then
						worldNudged = tryAlmostThereNudge("world", subVfxTemplate(line, { WorldName = wm }))
					end
				end
			end
		end
		if not worldNudged and not wantRebirthWorldNudge then
			local need = nextWorldRow.unlockCost
			if type(need) == "number" and need > 0 then
				local cur = if type(nextWorldRow.unlockCurrency) == "string" then nextWorldRow.unlockCurrency else "coins"
				local have = getCurrencyAmount(data, cur)
				if have >= need * 0.8 and have < need then
					local line = tpl.worldCurrency
					if type(line) == "string" and line ~= "" then
						tryAlmostThereNudge("world", subVfxTemplate(line, { WorldName = nextWorldRow.name }))
					end
				end
			end
		end
	end

	local totalSpecies = PetConfig.getTotalSpeciesCount()
	if totalSpecies > 0 then
		local newDisc = cloneDiscoveredMap(data.discoveredPets)
		local newC = countDiscoveredSpecies(newDisc)
		local np = indexPercent(newC, totalSpecies)
		local milestones = { 25, 50, 75, 100 }
		for _, m in milestones do
			if np < m and (m - np) <= 5 then
				local raw = tpl.collection
				if type(raw) == "string" and raw ~= "" then
					local line = string.gsub(raw, "{n}", tostring(m))
					tryAlmostThereNudge("collection", line)
				end
				break
			end
		end
	end
end

function VFXController.petIndexDiscovery(petId: string)
	local sg = screenGui
	if not sg then
		return
	end
	local def = PetConfig.Pets[petId]
	local rarity = if def and type(def.rarity) == "string" then string.lower(def.rarity) else "common"
	local petName = if def and type(def.name) == "string" then def.name else "???"
	local col = Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

	SoundFacade.playOneShot("notification")
	task.delay(0.12, function()
		local snd = "hatch_" .. rarity
		SoundFacade.playOneShot(snd)
	end)

	screenFlash(col, 0.14, 0.42)

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Parent = root
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = if rarity == "mythic" then mythicRainbowSequence() else ColorSequence.new(col)
		burst.Lifetime = NumberRange.new(0.35, 0.75)
		burst.Speed = NumberRange.new(8, 22)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rate = 0
		burst.Parent = att
		burst:Emit(math.floor(55 * lodBurstMul()))
		task.delay(1.0, function()
			att:Destroy()
		end)
	end

	local card = Instance.new("Frame")
	card.Name = "DAC_PetIndexDiscovery"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.46, 0)
	card.Size = UDim2.fromOffset(400, 228)
	card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	card.BackgroundTransparency = 0.12
	card.ZIndex = 55
	card.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = col
	stroke.Thickness = 4
	stroke.Parent = card

	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, col),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, col),
	})
	glow.Transparency = NumberSequence.new(0.85)
	glow.Parent = stroke

	task.spawn(function()
		for _ = 1, 8 do
			if not stroke.Parent then
				break
			end
			TweenService:Create(stroke, TweenInfo.new(0.35), { Thickness = 7 }):Play()
			task.wait(0.35)
			TweenService:Create(stroke, TweenInfo.new(0.35), { Thickness = 4 }):Play()
			task.wait(0.35)
		end
	end)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.new(0, 12, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 245, 200)
	title.Text = "NEW DISCOVERY!"
	title.ZIndex = 56
	title.Parent = card

	local sil = Instance.new("TextLabel")
	sil.Size = UDim2.new(1, -24, 0, 56)
	sil.Position = UDim2.new(0, 12, 0, 96)
	sil.BackgroundTransparency = 1
	sil.Font = Enum.Font.GothamBlack
	sil.TextSize = 44
	sil.TextColor3 = Color3.fromRGB(38, 38, 44)
	sil.Text = "▓▓▓▓▓▓▓▓"
	sil.ZIndex = 56
	sil.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -24, 0, 56)
	nameLbl.Position = UDim2.new(0, 12, 0, 96)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 34
	nameLbl.TextColor3 = col
	nameLbl.Text = petName
	nameLbl.TextTransparency = 1
	nameLbl.ZIndex = 57
	nameLbl.Parent = card

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size = UDim2.new(1, -24, 0, 22)
	rarityLbl.Position = UDim2.new(0, 12, 0, 168)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Font = Enum.Font.Gotham
	rarityLbl.TextSize = 16
	rarityLbl.TextColor3 = col
	rarityLbl.TextTransparency = 1
	rarityLbl.Text = string.upper(rarity)
	rarityLbl.ZIndex = 56
	rarityLbl.Parent = card

	local nameScale = Instance.new("UIScale")
	nameScale.Scale = 0.82
	nameScale.Parent = nameLbl

	TweenService:Create(sil, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(nameLbl, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	TweenService:Create(rarityLbl, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0.15,
	}):Play()
	TweenService:Create(nameScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(0.45, function()
		local ok, data = pcall(function()
			return Remotes.getFunction("GetPlayerData"):InvokeServer()
		end)
		if not ok or type(data) ~= "table" then
			return
		end
		local totalSpecies = PetConfig.getTotalSpeciesCount()
		local found = 0
		if type(data.discoveredPets) == "table" then
			for _, v in pairs(data.discoveredPets) do
				if v == true then
					found += 1
				end
			end
		end
		local pct = if totalSpecies > 0 then math.floor((found * 100) / totalSpecies) else 0
		local remaining = math.max(0, totalSpecies - found)
		local tpl = MicrocopyConfig.pickVariant(MicrocopyConfig.CollectionNewDiscovery)
		tpl = tpl:gsub("{PET}", petName):gsub("{REMAINING}", tostring(remaining)):gsub("{PERCENT}", tostring(pct))
		VFXFacade.milestonePopup(tpl, "collection_toast")
	end)

	TweenService:Create(card, TweenInfo.new(2.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.4, 0),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(2.1), { Transparency = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(2.1), { TextTransparency = 1 }):Play()
	TweenService:Create(nameLbl, TweenInfo.new(2.1), { TextTransparency = 1 }):Play()
	TweenService:Create(rarityLbl, TweenInfo.new(2.1), { TextTransparency = 1 }):Play()

	task.delay(2.35, function()
		card:Destroy()
	end)
end

function VFXController.nearMissSpark(fromRight: boolean)
	local primary = trailPart
	if not primary or not primary.Parent then
		ensureTrailOnCar()
		primary = trailPart
	end
	if not primary then
		return
	end
	local sign = if fromRight then 1 else -1
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(sign * 1.8, 0.35, 2.4)
	att.Parent = primary
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 120, 80))
	sp.Lifetime = NumberRange.new(0.12, 0.28)
	sp.Speed = NumberRange.new(8, 22)
	sp.SpreadAngle = Vector2.new(40, 40)
	sp.EmissionDirection = if fromRight then Enum.NormalId.Right else Enum.NormalId.Left
	sp.Rate = 0
	sp.Size = NumberSequence.new(0.12, 0.45)
	sp.Parent = att
	sp:Emit(math.floor(math.random(3, 5) * lodBurstMul()))
	task.delay(0.45, function()
		att:Destroy()
	end)
end

function VFXController.nearMissEdgeEnterFx(fromRight: boolean)
	nearMissPendingRecover = true
	local vig = getVignetteFrame()
	vig.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	vig.BackgroundTransparency = 0.92
	TweenService:Create(vig, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.78 }):Play()
	task.delay(0.12, function()
		TweenService:Create(vig, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end)
	SoundFacade.playOneShot(if math.random(1, 2) == 1 then "screech" else "rebirth_whoosh")
end

function VFXController.nearMissRecover()
	if not nearMissPendingRecover then
		return
	end
	local now = os.clock()
	if now - lastCloseCallClock < 0.55 then
		return
	end
	lastCloseCallClock = now
	nearMissPendingRecover = false
	VFXController.milestonePopup("CLOSE CALL!", "close_call")
end

function VFXController.currencyPopup(currencyType: string, amount: number, flavorLine: string?)
	SoundFacade.playOneShot("currency")
	local sg = screenGui
	if not sg then
		return
	end
	local lbl = acquirePopup()
	local symbol = "+"
	local text = `{symbol}{Utils.formatNumber(amount)} {currencyType}`
	local baseSize = UDim2.fromOffset(280, 48)
	if flavorLine ~= nil and flavorLine ~= "" then
		lbl.Text = text .. "\n" .. flavorLine
		lbl.TextWrapped = true
		lbl.Size = UDim2.fromOffset(320, 72)
		lbl.TextSize = 22
	else
		lbl.Text = text
		lbl.TextWrapped = false
		lbl.Size = baseSize
		lbl.TextSize = 26
	end
	lbl.TextColor3 = currencyColor(currencyType)
	lbl.TextTransparency = 0
	lbl.Visible = true
	lbl.Position = UDim2.new(0.5, (math.random() - 0.5) * 140, 0.72, (math.random() - 0.5) * 20)

	TweenService:Create(lbl, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, (math.random() - 0.5) * 60, 0.38, 0),
		TextTransparency = 1,
	}):Play()
	task.delay(1.85, function()
		lbl.Visible = false
		lbl.Size = baseSize
		lbl.TextSize = 26
		lbl.TextWrapped = false
	end)
end

function VFXController.skullDrop(amount: number)
	local sg = screenGui
	if not sg then
		return
	end
	local lbl = acquirePopup()
	lbl.Text = "+" .. tostring(amount) .. " skulls"
	lbl.TextColor3 = currencyColor("skulls")
	lbl.TextTransparency = 0
	lbl.Visible = true
	lbl.Position = UDim2.new(0.5, 0, 0.68, 0)
	TweenService:Create(lbl, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.4, 0),
		TextTransparency = 1,
	}):Play()
	task.delay(1.65, function()
		lbl.Visible = false
	end)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Parent = root
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(160, 80, 255))
		p.Lifetime = NumberRange.new(0.4, 0.9)
		p.Speed = NumberRange.new(4, 16)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Size = NumberSequence.new(0.25, 0.9)
		p.Rate = 0
		p.Parent = att
		p:Emit(40 + math.min(amount * 3, 80))
		task.delay(1.2, function()
			att:Destroy()
		end)
	end
end

function VFXController.upgradeFlash()
	-- Lightweight fallback when stat deltas are unknown; prefer statLevelUp from data updates.
	local car = player.Character and player.Character:FindFirstChild("Car")
	local primary = car and car:IsA("Model") and (car :: Model).PrimaryPart
	if primary then
		local att = Instance.new("Attachment")
		att.Parent = primary
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(120, 255, 200))
		p.Lifetime = NumberRange.new(0.25, 0.55)
		p.Speed = NumberRange.new(2, 10)
		p.SpreadAngle = Vector2.new(90, 90)
		p.Size = NumberSequence.new(0.2, 0.7)
		p.Parent = att
		p:Emit(22)
		task.delay(0.8, function()
			att:Destroy()
		end)
	end
	screenFlash(Color3.fromRGB(180, 255, 220), 0.35, 0.82)
end

local function formatLapTimeDisplay(lapTimeSeconds: number?): string
	if type(lapTimeSeconds) ~= "number" or lapTimeSeconds < 0 then
		return "--"
	end
	if lapTimeSeconds >= 60 then
		local m = math.floor(lapTimeSeconds / 60)
		local s = lapTimeSeconds - m * 60
		return string.format("%d:%05.2f", m, s)
	end
	return string.format("%.2fs", lapTimeSeconds)
end

local function lapCenterToast(text: string)
	local sg = screenGui
	if not sg or text == "" then
		return
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = "LapToast"
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Size = UDim2.new(0.92, 0, 0, 72)
	lbl.Position = UDim2.new(0.5, 0, 0.45, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 40
	lbl.TextColor3 = Color3.fromRGB(255, 245, 220)
	lbl.TextStrokeTransparency = 0.35
	lbl.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
	lbl.Text = text
	lbl.TextTransparency = 1
	lbl.ZIndex = 900
	lbl.Parent = sg
	local sc = Instance.new("UIScale")
	sc.Scale = 0.8
	sc.Parent = lbl
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	task.delay(2.3, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.95 }):Play()
		end
	end)
	task.delay(2.75, function()
		if lbl.Parent then
			lbl:Destroy()
		end
	end)
end

function VFXController.lapFlash(isPersonalBest: boolean, lapTimeSeconds: number?)
	SoundFacade.playOneShot("lap_horn")
	local sg = screenGui
	local lapLine = ""
	if isPersonalBest and #NearMissCopyConfig.LapPersonalBest > 0 then
		lapLine = NearMissCopyConfig.LapPersonalBest[math.random(1, #NearMissCopyConfig.LapPersonalBest)]
	elseif not isPersonalBest then
		if math.random() < 0.7 and #NearMissCopyConfig.LapComplete > 0 then
			lapLine = NearMissCopyConfig.LapComplete[math.random(1, #NearMissCopyConfig.LapComplete)]
		elseif #NearMissCopyConfig.LapHumor > 0 then
			lapLine = NearMissCopyConfig.LapHumor[math.random(1, #NearMissCopyConfig.LapHumor)]
		elseif #NearMissCopyConfig.LapComplete > 0 then
			lapLine = NearMissCopyConfig.LapComplete[math.random(1, #NearMissCopyConfig.LapComplete)]
		end
	end
	if lapLine ~= "" then
		local timeStr = formatLapTimeDisplay(lapTimeSeconds)
		lapLine = (lapLine:gsub("{TIME}", timeStr))
		lapCenterToast(lapLine)
	end
	if not sg then
		return
	end
	local peak = if isPersonalBest then 0.45 else 0.35
	local f = getLapFlashFrame()
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	local edge = Color3.fromHex("FACC15")
	TweenService:Create(f, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 - peak }):Play()
	task.delay(0.08, function()
		f.BackgroundColor3 = edge
		TweenService:Create(f, TweenInfo.new(0.27, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end)

	local vig = getVignetteFrame()
	vig.BackgroundTransparency = 1
	TweenService:Create(vig, TweenInfo.new(0.15), { BackgroundTransparency = 0.88 }):Play()
	task.delay(0.15, function()
		TweenService:Create(vig, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end)

	if lodTier >= 2 then
		task.spawn(function()
			cameraShake(if isPersonalBest then 0.2 else 0.12, 0.12)
		end)
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, -4, 0)
		att.Parent = root
		local streaks = Instance.new("ParticleEmitter")
		streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		streaks.Lifetime = NumberRange.new(0.35, 0.45)
		streaks.Speed = NumberRange.new(18, 32)
		streaks.SpreadAngle = Vector2.new(15, 15)
		streaks.EmissionDirection = Enum.NormalId.Bottom
		streaks.Rate = 0
		streaks.Parent = att
		local n = if lodTier <= 1 then 12 else 16
		streaks:Emit(n)
		if isPersonalBest then
			local conf = Instance.new("ParticleEmitter")
			conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			conf.Color = ColorSequence.new(Color3.fromHex("FACC15"))
			conf.Lifetime = NumberRange.new(0.4, 0.8)
			conf.Speed = NumberRange.new(4, 14)
			conf.SpreadAngle = Vector2.new(180, 180)
			conf.Rate = 0
			conf.Parent = att
			conf:Emit(24)
		end
		task.delay(0.8, function()
			att:Destroy()
		end)
	end
end

function VFXController.failureFeedback(copyLine: string, _kind: string?)
	task.spawn(function()
		cameraShake(0.06, 0.1)
	end)
	VFXController.milestonePopup(copyLine, "failure_toast")
end

function VFXController.speedMilestone(speed: number)
	speedMilestoneRushBoostUntil = os.clock() + 0.35

	local thr = speed
	local tierIdx = 1
	for i, t in ipairs(SpeedMilestoneConfig.Thresholds) do
		if t == thr then
			tierIdx = i
			break
		end
	end
	local maxTier = #SpeedMilestoneConfig.Thresholds
	local scale = if maxTier > 1 then (tierIdx - 1) / (maxTier - 1) else 0
	local col: Color3 = SpeedMilestoneConfig.CelebrationColor[thr] or Color3.fromRGB(255, 200, 55)
	local hex = SpeedMilestoneConfig.MilestoneColor[thr]
	if type(hex) == "string" and hex ~= "" then
		local ok, c = pcall(function()
			return Color3.fromHex(hex)
		end)
		if ok and typeof(c) == "Color3" then
			col = c
		end
	end

	local sg = screenGui
	if sg then
		local f = getLapFlashFrame()
		local peak = 0.26 + 0.18 * scale
		f.BackgroundColor3 = col
		f.BackgroundTransparency = 1
		local openDur = 0.05 + 0.03 * scale
		TweenService:Create(f, TweenInfo.new(openDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1 - peak,
		}):Play()
		task.delay(openDur + 0.01, function()
			if not f.Parent then
				return
			end
			f.BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.35)
			local closeDur = 0.18 + 0.12 * scale
			TweenService:Create(f, TweenInfo.new(closeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end)
	end

	if tierIdx >= 3 then
		task.spawn(function()
			cameraShake(0.04 + 0.1 * scale, 0.08 + 0.06 * scale)
		end)
	end

	if tierIdx >= maxTier then
		screenFlash(col, 0.12 + 0.08 * scale, 0.18 + 0.12 * scale)
		local cam = workspace.CurrentCamera
		if cam then
			local startFov = cam.FieldOfView
			local bump = 6 + 4 * scale
			TweenService:Create(cam, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = math.min(startFov + bump, 95),
			}):Play()
			task.delay(0.12, function()
				if cam.Parent then
					TweenService:Create(cam, TweenInfo.new(0.35 + 0.1 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						FieldOfView = startFov,
					}):Play()
				end
			end)
		end
	end
end

function VFXController.worldTransition(fromWorldId: string, toWorldId: string)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local col = WORLD_TRAIL_NEON[toWorldId] or WORLD_TRAIL_NEON.grasslands

	if root then
		local att = Instance.new("Attachment")
		att.Parent = root
		local swirl = Instance.new("ParticleEmitter")
		swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		swirl.Color = ColorSequence.new(col)
		swirl.Lifetime = NumberRange.new(0.4, 1.0)
		swirl.Rate = if lodTier <= 1 then 20 else 40
		swirl.Speed = NumberRange.new(2, 12)
		swirl.SpreadAngle = Vector2.new(180, 180)
		swirl.Parent = att
		task.delay(2, function()
			swirl.Rate = 0
		end)
		task.delay(2.5, function()
			att:Destroy()
		end)
	end

	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(1, Enum.EasingStyle.Sine), { FieldOfView = cam.FieldOfView + 12 }):Play()
		task.delay(1, function()
			TweenService:Create(cam, TweenInfo.new(0.8), { FieldOfView = baseCameraFov }):Play()
		end)
	end

	-- Teleport fade 0.3 + 0.3 hold + 0.4 in
	local f = getFlashLayer()
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	task.delay(0.3, function()
		task.delay(0.3, function()
			TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end)
	end)

	local amb = Lighting
	TweenService:Create(amb, TweenInfo.new(1.2), {
		Ambient = col:Lerp(amb.Ambient, 0.35),
		OutdoorAmbient = col:Lerp(amb.OutdoorAmbient, 0.25),
	}):Play()
end

local function clearAmbient()
	for _, e in ambientEmitters do
		if e.Parent then
			e:Destroy()
		end
	end
	table.clear(ambientEmitters)
	if ambientFolder then
		ambientFolder:Destroy()
		ambientFolder = nil
	end
end

function VFXController.ambientStop()
	ambientRunning = false
	clearAmbient()
end

function VFXController.ambientStart()
	local allowedAmbient = {
		grasslands = true,
		desert = true,
		frozen = true,
		neon = true,
	}
	if not allowedAmbient[activeWorldId] then
		return
	end
	if runActive then
		return
	end
	if lodTier <= 1 then
		return
	end
	if ambientRunning then
		return
	end
	ambientRunning = true
	clearAmbient()
	local folder = Instance.new("Folder")
	folder.Name = "DACVFX_Ambient"
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		folder.Parent = root
	else
		folder.Parent = workspace.CurrentCamera or workspace
	end
	ambientFolder = folder

	local rateMul = if lodTier == 2 then 0.65 else 1
	local accent = WORLD_TRAIL_NEON[activeWorldId] or WORLD_TRAIL_NEON.grasslands

	if activeWorldId == "grasslands" then
		local pollen = Instance.new("ParticleEmitter")
		pollen.Name = "Pollen"
		pollen.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pollen.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200))
		pollen.Lifetime = NumberRange.new(4, 8)
		pollen.Rate = (if lodTier == 2 then 2 else 3) * rateMul
		pollen.Speed = NumberRange.new(0.2, 1.2)
		pollen.SpreadAngle = Vector2.new(180, 180)
		pollen.Size = NumberSequence.new(0.08, 0.2)
		pollen.Parent = folder
		table.insert(ambientEmitters, pollen)

		local seeds = Instance.new("ParticleEmitter")
		seeds.Name = "Seeds"
		seeds.Texture = "rbxasset://textures/particles/smoke_main.dds"
		seeds.Color = ColorSequence.new(Color3.fromRGB(200, 180, 120))
		seeds.Lifetime = NumberRange.new(5, 9)
		seeds.Rate = (if lodTier == 2 then 1.5 else 2.5) * rateMul
		seeds.Speed = NumberRange.new(0.5, 2)
		seeds.SpreadAngle = Vector2.new(180, 180)
		seeds.Parent = folder
		table.insert(ambientEmitters, seeds)
	elseif activeWorldId == "desert" then
		local heat = Instance.new("ParticleEmitter")
		heat.Name = "HeatShimmer"
		heat.Texture = "rbxasset://textures/particles/smoke_main.dds"
		heat.Color = ColorSequence.new(accent:Lerp(Color3.fromRGB(255, 240, 200), 0.35))
		heat.Lifetime = NumberRange.new(2.5, 4.5)
		heat.Rate = 2.2 * rateMul
		heat.Speed = NumberRange.new(0.4, 2.2)
		heat.SpreadAngle = Vector2.new(180, 180)
		heat.EmissionDirection = Enum.NormalId.Top
		heat.Acceleration = Vector3.new(0, 0.8, 0)
		heat.Drag = 1.2
		heat.LightEmission = 0.25
		heat.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.5, 1.1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		heat.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		heat.Parent = folder
		table.insert(ambientEmitters, heat)

		local sand = Instance.new("ParticleEmitter")
		sand.Name = "SandMotes"
		sand.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sand.Color = ColorSequence.new(Color3.fromRGB(230, 190, 120))
		sand.Lifetime = NumberRange.new(3, 6)
		sand.Rate = 2.5 * rateMul
		sand.Speed = NumberRange.new(1.5, 4)
		sand.SpreadAngle = Vector2.new(25, 25)
		sand.EmissionDirection = Enum.NormalId.Right
		sand.Acceleration = Vector3.new(0, -0.15, 0)
		sand.Drag = 0.8
		sand.RotSpeed = NumberRange.new(-20, 20)
		sand.Size = NumberSequence.new(0.06, 0.18)
		sand.Parent = folder
		table.insert(ambientEmitters, sand)
	elseif activeWorldId == "frozen" then
		local snow = Instance.new("ParticleEmitter")
		snow.Name = "Snowflakes"
		snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		snow.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
		snow.Lifetime = NumberRange.new(4, 7)
		snow.Rate = 2.8 * rateMul
		snow.Speed = NumberRange.new(0.8, 2.5)
		snow.SpreadAngle = Vector2.new(180, 180)
		snow.EmissionDirection = Enum.NormalId.Top
		snow.Acceleration = Vector3.new(0, -1.2, 0)
		snow.Drag = 0.5
		snow.Size = NumberSequence.new(0.1, 0.28)
		snow.Parent = folder
		table.insert(ambientEmitters, snow)

		local ice = Instance.new("ParticleEmitter")
		ice.Name = "IceSparkle"
		ice.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		ice.Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.4))
		ice.Lifetime = NumberRange.new(1.2, 2.8)
		ice.Rate = 2 * rateMul
		ice.Speed = NumberRange.new(0.2, 1.4)
		ice.SpreadAngle = Vector2.new(180, 180)
		ice.LightEmission = 0.75
		ice.Size = NumberSequence.new(0.05, 0.2)
		ice.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		ice.Parent = folder
		table.insert(ambientEmitters, ice)
	else -- neon
		local fleck = Instance.new("ParticleEmitter")
		fleck.Name = "NeonFleck"
		fleck.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fleck.Color = ColorSequence.new(accent)
		fleck.Lifetime = NumberRange.new(1.5, 3)
		fleck.Rate = 3 * rateMul
		fleck.Speed = NumberRange.new(1.5, 5)
		fleck.SpreadAngle = Vector2.new(40, 40)
		fleck.EmissionDirection = Enum.NormalId.Top
		fleck.Acceleration = Vector3.new(0, 1.2, 0)
		fleck.LightEmission = 0.9
		fleck.Size = NumberSequence.new(0.08, 0.22)
		fleck.Parent = folder
		table.insert(ambientEmitters, fleck)

		local spark = Instance.new("ParticleEmitter")
		spark.Name = "StaticCrackle"
		spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spark.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, accent),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 255)),
		})
		spark.Lifetime = NumberRange.new(0.08, 0.22)
		spark.Rate = 8 * rateMul
		spark.Speed = NumberRange.new(4, 14)
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.LightEmission = 1
		spark.Size = NumberSequence.new(0.04, 0.12)
		spark.Parent = folder
		table.insert(ambientEmitters, spark)
	end
end

-- Pet equip one-shot entrance (see PetEntranceDesignSpec.luau)
local function petEquipBeamRingCount(base: number): number
	if lodTier <= 1 then
		return 0
	elseif lodTier == 2 then
		return math.max(1, math.floor(base * 0.66 + 0.5))
	end
	return base
end

local function petEquipRadialBeams(
	primary: BasePart,
	color: Color3,
	count: number,
	length: number,
	w0: number,
	w1: number,
	hold: number
)
	if count <= 0 or not primary.Parent then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DACVFX_EquipBeams"
	folder.Parent = primary
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local att0 = Instance.new("Attachment")
		att0.Position = Vector3.new(0, 0.8, 0)
		att0.Parent = primary
		local att1 = Instance.new("Attachment")
		att1.Position = Vector3.new(0, 0.8, 0) + dir * length
		att1.Parent = primary
		local b = Instance.new("Beam")
		b.Attachment0 = att0
		b.Attachment1 = att1
		b.FaceCamera = true
		b.Color = ColorSequence.new(color)
		b.Width0 = w0
		b.Width1 = w1
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.LightInfluence = 0
		b.Parent = folder
	end
	task.delay(hold, function()
		if folder.Parent then
			folder:Destroy()
		end
	end)
end

local function petEquipFovPunch(delta: number, restoreDur: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local start = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = math.min(start + delta, 95),
	}):Play()
	task.delay(0.14, function()
		if cam.Parent then
			TweenService:Create(cam, TweenInfo.new(restoreDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = start,
			}):Play()
		end
	end)
end

local function petEquipAlive(model: Model?): boolean
	return model ~= nil and model.Parent ~= nil and model.PrimaryPart ~= nil
end

function VFXController.petEquipEntrance(_petUid: string, model: Model?, rarity: string?)
	if not petEquipAlive(model) then
		return
	end
	local r = string.lower(rarity or "common")

	task.spawn(function()
		local m = model :: Model
		local primary = m.PrimaryPart :: BasePart
		local col = Constants.RARITY_COLORS[r] or Color3.new(1, 1, 1)

		if r == "common" then
			local att = Instance.new("Attachment")
			att.Parent = primary
			local spark = Instance.new("ParticleEmitter")
			spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			spark.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
			spark.Lifetime = NumberRange.new(0.15, 0.35)
			spark.Speed = NumberRange.new(4, 10)
			spark.SpreadAngle = Vector2.new(180, 180)
			spark.Size = NumberSequence.new(0.08, 0.25)
			spark.LightEmission = 0.4
			spark.Drag = 1.5
			spark.Acceleration = Vector3.new(0, -2, 0)
			spark.Rate = 0
			spark.Parent = att
			spark:Emit(math.floor(8 * lodBurstMul()))
			SoundFacade.playOneShot("pet_equip_common")
			local canScale = pcall(function()
				return (m :: any):GetScale()
			end)
			if canScale then
				pcall(function()
					(m :: any):ScaleTo(0.01)
				end)
				local nv = Instance.new("NumberValue")
				nv.Value = 0
				nv.Parent = playerGui
				local tw = TweenService:Create(
					nv,
					TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Value = 1 }
				)
				nv:GetPropertyChangedSignal("Value"):Connect(function()
					local s = 0.01 + 0.99 * nv.Value
					pcall(function()
						(m :: any):ScaleTo(s)
					end)
				end)
				tw.Completed:Connect(function()
					nv:Destroy()
				end)
				tw:Play()
			end
			task.delay(0.45, function()
				if att.Parent then
					att:Destroy()
				end
			end)
			return
		end

		if r == "uncommon" then
			local targetCf = m:GetPivot()
			local side = if math.random() < 0.5 then -1 else 1
			local offset = Vector3.new(8 * side, 2, 0)
			local fromCf = targetCf + offset
			m:PivotTo(fromCf)
			local trail = Instance.new("ParticleEmitter")
			trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			trail.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 230, 100)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 60)),
			})
			trail.Lifetime = NumberRange.new(0.2, 0.5)
			trail.Speed = NumberRange.new(1, 4)
			trail.SpreadAngle = Vector2.new(15, 15)
			trail.Size = NumberSequence.new(0.1, 0.3)
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.LightEmission = 0.55
			trail.Drag = 2
			trail.Rate = 35 * lodTrailRateMul()
			trail.Parent = primary
			local dur = 0.35
			local t0 = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				if not petEquipAlive(m) then
					if conn then
						conn:Disconnect()
					end
					return
				end
				local t = math.clamp((os.clock() - t0) / dur, 0, 1)
				local eased = 1 - (1 - t) * (1 - t)
				m:PivotTo(fromCf:Lerp(targetCf, eased))
				if t >= 1 then
					if conn then
						conn:Disconnect()
					end
					trail.Rate = 0
					SoundFacade.playOneShot("pet_equip_uncommon")
					local burst = Instance.new("ParticleEmitter")
					burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					burst.Color = ColorSequence.new(col)
					burst.Lifetime = NumberRange.new(0.2, 0.45)
					burst.Speed = NumberRange.new(6, 14)
					burst.SpreadAngle = Vector2.new(180, 180)
					burst.Rate = 0
					burst.Parent = primary
					burst:Emit(math.floor(14 * lodBurstMul()))
					task.delay(0.6, function()
						trail:Destroy()
						if burst.Parent then
							burst:Destroy()
						end
					end)
				end
			end)
			return
		end

		if r == "rare" then
			local targetPos = primary.Position
			local rx, ry, rz = m:GetPivot():ToEulerAnglesXYZ()
			m:PivotTo(CFrame.new(targetPos + Vector3.new(0, 6, 0)) * CFrame.Angles(rx, ry, rz))
			local zap = Instance.new("ParticleEmitter")
			zap.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			zap.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 180, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 230, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 130, 255)),
			})
			zap.Lifetime = NumberRange.new(0.06, 0.18)
			zap.Speed = NumberRange.new(8, 22)
			zap.SpreadAngle = Vector2.new(60, 60)
			zap.Size = NumberSequence.new(0.04, 0.15)
			zap.LightEmission = 1
			zap.Drag = 0.5
			zap.Rate = 28 * lodTrailRateMul()
			zap.Parent = primary
			local dur = 0.6
			local t0 = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				if not petEquipAlive(m) then
					if conn then
						conn:Disconnect()
					end
					return
				end
				local t = math.clamp((os.clock() - t0) / dur, 0, 1)
				local tVert = 1 - (1 - t) ^ 1.5
				local angle = t * 1.5 * math.pi * 2
				local rad = 2 * (1 - t)
				local off = Vector3.new(math.cos(angle) * rad, 6 * (1 - tVert), math.sin(angle) * rad)
				m:PivotTo(CFrame.new(targetPos + off) * CFrame.Angles(rx, ry, rz))
				if t >= 1 then
					if conn then
						conn:Disconnect()
					end
					zap.Rate = 0
					SoundFacade.playOneShot("pet_equip_rare")
					task.spawn(function()
						cameraShake(0.08, 0.1)
					end)
					local land = Instance.new("ParticleEmitter")
					land.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					land.Color = zap.Color
					land.Lifetime = NumberRange.new(0.2, 0.5)
					land.Speed = NumberRange.new(8, 20)
					land.SpreadAngle = Vector2.new(180, 180)
					land.Rate = 0
					land.Parent = primary
					land:Emit(math.floor(24 * lodBurstMul()))
					petEquipRadialBeams(primary, col, petEquipBeamRingCount(4), 3, 0.25, 0.04, 0.45)
					task.delay(0.55, function()
						zap:Destroy()
						if land.Parent then
							land:Destroy()
						end
					end)
				end
			end)
			return
		end

		if r == "epic" then
			local sg = screenGui
			if sg then
				local pulse = Instance.new("Frame")
				pulse.Size = UDim2.fromScale(1, 1)
				pulse.BackgroundColor3 = Color3.fromRGB(60, 10, 80)
				pulse.BackgroundTransparency = 1
				pulse.ZIndex = 997
				pulse.Active = false
				pulse.Parent = sg
				TweenService:Create(pulse, TweenInfo.new(0.15), { BackgroundTransparency = 0.7 }):Play()
				task.delay(0.15, function()
					TweenService:Create(pulse, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
				end)
				task.delay(0.35, function()
					if pulse.Parent then
						pulse:Destroy()
					end
				end)
			end
			local targetPos = primary.Position
			local rx, ry, rz = m:GetPivot():ToEulerAnglesXYZ()
			local vortex = Instance.new("ParticleEmitter")
			vortex.Texture = "rbxasset://textures/particles/smoke_main.dds"
			vortex.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 60, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 30, 200)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
			})
			vortex.Lifetime = NumberRange.new(0.3, 0.7)
			vortex.Speed = NumberRange.new(2, 8)
			vortex.SpreadAngle = Vector2.new(30, 30)
			vortex.RotSpeed = NumberRange.new(-60, 60)
			vortex.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 0.1),
			})
			vortex.Transparency = NumberSequence.new(0.3, 1)
			vortex.LightEmission = 0.65
			vortex.Rate = 40 * lodTrailRateMul()
			vortex.Parent = primary
			local crackle = Instance.new("ParticleEmitter")
			crackle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			crackle.Color = ColorSequence.new(Color3.fromRGB(220, 180, 255))
			crackle.Lifetime = NumberRange.new(0.04, 0.12)
			crackle.Speed = NumberRange.new(12, 30)
			crackle.SpreadAngle = Vector2.new(90, 90)
			crackle.Size = NumberSequence.new(0.03, 0.1)
			crackle.LightEmission = 1
			crackle.Rate = 18 * lodTrailRateMul()
			crackle.Parent = primary
			local dur = 0.8
			m:PivotTo(CFrame.new(targetPos + Vector3.new(0, 8, 0)) * CFrame.Angles(rx, ry, rz))
			local t0 = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				if not petEquipAlive(m) then
					if conn then
						conn:Disconnect()
					end
					return
				end
				local t = math.clamp((os.clock() - t0) / dur, 0, 1)
				local te = 1 - 2 ^ (-8 * t)
				local angle = t * 2.5 * math.pi * 2
				local rad = 3 * (1 - t)
				local y = 8 * (1 - te)
				local off = Vector3.new(math.cos(angle) * rad, y, math.sin(angle) * rad)
				m:PivotTo(CFrame.new(targetPos + off) * CFrame.Angles(rx, ry, rz))
				if t >= 1 then
					if conn then
						conn:Disconnect()
					end
					vortex.Rate = 0
					crackle.Rate = 0
					SoundFacade.playOneShot("pet_equip_epic")
					screenFlash(Color3.fromRGB(180, 60, 255), 0.25, 0.55)
					task.spawn(function()
						cameraShake(0.18, 0.2)
					end)
					local core = Instance.new("ParticleEmitter")
					core.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					core.Color = ColorSequence.new(col)
					core.Lifetime = NumberRange.new(0.2, 0.55)
					core.Speed = NumberRange.new(8, 24)
					core.SpreadAngle = Vector2.new(180, 180)
					core.Rate = 0
					core.Parent = primary
					core:Emit(math.floor(35 * lodBurstMul()))
					local wisp = Instance.new("ParticleEmitter")
					wisp.Texture = "rbxasset://textures/particles/smoke_main.dds"
					wisp.Color = ColorSequence.new(col)
					wisp.Lifetime = NumberRange.new(0.25, 0.55)
					wisp.Speed = NumberRange.new(4, 12)
					wisp.SpreadAngle = Vector2.new(180, 180)
					wisp.Rate = 0
					wisp.Parent = primary
					wisp:Emit(math.floor(12 * lodBurstMul()))
					petEquipRadialBeams(primary, col, petEquipBeamRingCount(6), 4, 0.3, 0.05, 0.6)
					task.delay(0.65, function()
						vortex:Destroy()
						crackle:Destroy()
						core:Destroy()
						wisp:Destroy()
					end)
				end
			end)
			return
		end

		if r == "legendary" then
			SoundFacade.playOneShot("pet_equip_legendary_beam")
			local targetPos = primary.Position
			local rx, ry, rz = m:GetPivot():ToEulerAnglesXYZ()
			local startY = targetPos.Y + 20
			m:PivotTo(CFrame.new(Vector3.new(targetPos.X, startY, targetPos.Z)) * CFrame.Angles(rx, ry, rz))
			local attTop = Instance.new("Attachment")
			attTop.Position = Vector3.new(0, 20, 0)
			attTop.Parent = primary
			local attBot = Instance.new("Attachment")
			attBot.Position = Vector3.new(0, 0, 0)
			attBot.Parent = primary
			local skyBeam = Instance.new("Beam")
			skyBeam.Attachment0 = attTop
			skyBeam.Attachment1 = attBot
			skyBeam.FaceCamera = true
			skyBeam.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
			})
			skyBeam.Width0 = 1.2
			skyBeam.Width1 = 0.3
			skyBeam.Transparency = NumberSequence.new(0, 0.4)
			skyBeam.LightInfluence = 0
			skyBeam.Parent = primary
			local beamSpark = Instance.new("ParticleEmitter")
			beamSpark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			beamSpark.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
			beamSpark.Lifetime = NumberRange.new(0.5, 1.2)
			beamSpark.Speed = NumberRange.new(2, 8)
			beamSpark.SpreadAngle = Vector2.new(10, 10)
			beamSpark.EmissionDirection = Enum.NormalId.Bottom
			beamSpark.Size = NumberSequence.new(0.15, 0.45)
			beamSpark.LightEmission = 0.85
			beamSpark.Rate = 25 * lodTrailRateMul()
			beamSpark.Parent = attTop
			local dur = 0.9
			local t0 = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				if not petEquipAlive(m) then
					if conn then
						conn:Disconnect()
					end
					return
				end
				local t = math.clamp((os.clock() - t0) / dur, 0, 1)
				local te = t * t
				local y = startY + (targetPos.Y - startY) * te
				local p = Vector3.new(targetPos.X, y, targetPos.Z)
				m:PivotTo(CFrame.new(p) * CFrame.Angles(rx, ry, rz))
				if t >= 1 then
					if conn then
						conn:Disconnect()
					end
					beamSpark.Rate = 0
					SoundFacade.playOneShot("pet_equip_legendary_impact")
					screenFlash(Color3.fromRGB(255, 220, 100), 0.3, 0.42)
					task.spawn(function()
						cameraShake(0.35, 0.25)
					end)
					petEquipFovPunch(6, 0.3)
					petEquipRadialBeams(primary, col, petEquipBeamRingCount(8), 5, 0.4, 0.06, 0.7)
					local shock = Instance.new("ParticleEmitter")
					shock.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					shock.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
					})
					shock.Lifetime = NumberRange.new(0.3, 0.7)
					shock.Speed = NumberRange.new(14, 32)
					shock.SpreadAngle = Vector2.new(180, 180)
					shock.Acceleration = Vector3.new(0, -20, 0)
					shock.Rate = 0
					shock.Parent = primary
					shock:Emit(math.floor(50 * lodBurstMul()))
					local dust = Instance.new("ParticleEmitter")
					dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
					dust.Color = ColorSequence.new(Color3.fromRGB(200, 180, 140))
					dust.Lifetime = NumberRange.new(0.4, 0.8)
					dust.Speed = NumberRange.new(4, 10)
					dust.SpreadAngle = Vector2.new(60, 30)
					dust.Rate = 0
					dust.Parent = primary
					dust:Emit(math.floor(16 * lodBurstMul()))
					local cam = workspace.CurrentCamera
					if cam then
						local attC = Instance.new("Attachment")
						attC.Parent = cam
						attC.Position = Vector3.new(0, 3, -10)
						local conf = Instance.new("ParticleEmitter")
						conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
						conf.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
						conf.Lifetime = NumberRange.new(0.8, 1.4)
						conf.Speed = NumberRange.new(8, 24)
						conf.SpreadAngle = Vector2.new(180, 180)
						conf.Acceleration = Vector3.new(0, -35, 0)
						conf.Rate = 0
						conf.Parent = attC
						conf:Emit(math.floor(28 * lodBurstMul()))
						task.delay(2.2, function()
							attC:Destroy()
						end)
					end
					task.delay(0.5, function()
						skyBeam:Destroy()
						attTop:Destroy()
						attBot:Destroy()
						shock:Destroy()
						dust:Destroy()
					end)
				end
			end)
			return
		end

		-- mythic
		local prevTrailL: number? = nil
		local prevTrailR: number? = nil
		local prevBoost: number? = nil
		if runActive then
			if trailEmitterL then
				prevTrailL = trailEmitterL.Rate
				trailEmitterL.Rate = 0
			end
			if trailEmitterR then
				prevTrailR = trailEmitterR.Rate
				trailEmitterR.Rate = 0
			end
			if boostEmitter then
				prevBoost = boostEmitter.Rate
				boostEmitter.Rate = 0
			end
		end
		SoundFacade.playOneShot("pet_equip_mythic_tear")
		local sg = screenGui
		if sg then
			local tear = Instance.new("Frame")
			tear.Size = UDim2.fromScale(1, 1)
			tear.BackgroundColor3 = Color3.new(0, 0, 0)
			tear.BackgroundTransparency = 1
			tear.ZIndex = 1100
			tear.Active = false
			tear.Parent = sg
			TweenService:Create(tear, TweenInfo.new(0.12), { BackgroundTransparency = 0.6 }):Play()
			task.delay(0.12, function()
				TweenService:Create(tear, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
			end)
			for i = 1, 5 do
				local strip = Instance.new("Frame")
				strip.Size = UDim2.new(1.5, 0, 0, math.random(2, 6))
				strip.Position = UDim2.new(-0.5, 0, math.random(20, 80) / 100, 0)
				strip.BackgroundColor3 = Color3.new(1, 1, 1)
				strip.BackgroundTransparency = 0.3
				strip.ZIndex = 1101
				strip.Parent = tear
				TweenService:Create(strip, TweenInfo.new(0.15), { Position = UDim2.new(1.5, 0, strip.Position.Y.Scale, 0) })
					:Play()
			end
			task.delay(0.35, function()
				if tear.Parent then
					tear:Destroy()
				end
			end)
		end
		local cam = workspace.CurrentCamera
		local freezeCf = if cam then cam.CFrame else nil
		local freezeT0 = os.clock()
		if freezeCf and cam then
			local fconn: RBXScriptConnection? = nil
			fconn = RunService.RenderStepped:Connect(function()
				if os.clock() - freezeT0 < 0.35 and cam then
					cam.CFrame = freezeCf
				else
					if fconn then
						fconn:Disconnect()
					end
				end
			end)
		end
		task.delay(0.35, function()
			if runActive then
				if trailEmitterL and prevTrailL ~= nil then
					trailEmitterL.Rate = prevTrailL
				end
				if trailEmitterR and prevTrailR ~= nil then
					trailEmitterR.Rate = prevTrailR
				end
				if boostEmitter and prevBoost ~= nil then
					boostEmitter.Rate = prevBoost
				end
			end
			if not petEquipAlive(m) then
				return
			end
			local pr = m.PrimaryPart :: BasePart
			SoundFacade.playOneShot("pet_equip_mythic_explosion")
			task.delay(0.2, function()
				SoundFacade.playOneShot("hatch_mythic")
			end)
			local canScale = pcall(function()
				return (m :: any):GetScale()
			end)
			if canScale then
				pcall(function()
					(m :: any):ScaleTo(0.01)
				end)
				local nv = Instance.new("NumberValue")
				nv.Value = 0
				nv.Parent = playerGui
				local tw = TweenService:Create(
					nv,
					TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Value = 1 }
				)
				nv:GetPropertyChangedSignal("Value"):Connect(function()
					local s = 0.01 + 0.99 * nv.Value
					pcall(function()
						(m :: any):ScaleTo(s)
					end)
				end)
				tw.Completed:Connect(function()
					pcall(function()
						(m :: any):ScaleTo(1)
					end)
					nv:Destroy()
				end)
				tw:Play()
			end
			local core = Instance.new("ParticleEmitter")
			core.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			core.Color = mythicRainbowSequence()
			core.Lifetime = NumberRange.new(0.4, 1)
			core.Speed = NumberRange.new(14, 38)
			core.SpreadAngle = Vector2.new(180, 180)
			core.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.4, 0.65),
				NumberSequenceKeypoint.new(1, 0.08),
			})
			core.LightEmission = 0.9
			core.Acceleration = Vector3.new(0, -15, 0)
			core.Drag = 0.4
			core.Rate = 0
			core.Parent = pr
			core:Emit(math.floor(80 * lodBurstMul()))
			local tornado = Instance.new("ParticleEmitter")
			tornado.Texture = "rbxasset://textures/particles/smoke_main.dds"
			tornado.Color = mythicRainbowSequence()
			tornado.Lifetime = NumberRange.new(0.6, 1.4)
			tornado.Speed = NumberRange.new(4, 12)
			tornado.SpreadAngle = Vector2.new(360, 90)
			tornado.RotSpeed = NumberRange.new(-120, 120)
			tornado.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.5, 0.9),
				NumberSequenceKeypoint.new(1, 0.15),
			})
			tornado.Transparency = NumberSequence.new(0.25, 1)
			tornado.LightEmission = 0.5
			tornado.Rate = 0
			tornado.Parent = pr
			tornado:Emit(math.floor(30 * lodBurstMul()))
			local bolt = Instance.new("ParticleEmitter")
			bolt.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			bolt.Color = ColorSequence.new(Color3.new(1, 1, 1))
			bolt.Lifetime = NumberRange.new(0.04, 0.12)
			bolt.Speed = NumberRange.new(20, 48)
			bolt.SpreadAngle = Vector2.new(45, 45)
			bolt.LightEmission = 1
			bolt.Rate = 0
			bolt.Parent = pr
			bolt:Emit(math.floor(20 * lodBurstMul()))
			local cam2 = workspace.CurrentCamera
			if cam2 then
				local attC = Instance.new("Attachment")
				attC.Parent = cam2
				attC.Position = Vector3.new(0, 4, -12)
				local conf = Instance.new("ParticleEmitter")
				conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				conf.Color = mythicRainbowSequence()
				conf.Lifetime = NumberRange.new(0.8, 1.6)
				conf.Speed = NumberRange.new(10, 28)
				conf.SpreadAngle = Vector2.new(180, 180)
				conf.Acceleration = Vector3.new(0, -40, 0)
				conf.Rate = 0
				conf.Parent = attC
				conf:Emit(math.floor(45 * lodBurstMul()))
				task.delay(2.5, function()
					attC:Destroy()
				end)
			end
			screenFlash(Color3.new(1, 1, 1), 0.12, 0.35)
			task.delay(0.05, function()
				screenFlash(Color3.fromRGB(255, 120, 200), 0.4, 0.25)
			end)
			task.spawn(function()
				cameraShake(0.5, 0.35)
			end)
			petEquipFovPunch(12, 0.45)
			if sg then
				local border = Instance.new("Frame")
				border.Size = UDim2.fromScale(1, 1)
				border.BackgroundTransparency = 1
				border.ZIndex = 1005
				border.Active = false
				border.Parent = sg
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 8
				stroke.Transparency = 0.1
				stroke.Parent = border
				local grad = Instance.new("UIGradient")
				grad.Color = mythicRainbowSequence()
				grad.Parent = stroke
				local tRain = os.clock()
				local bconn: RBXScriptConnection? = nil
				bconn = RunService.RenderStepped:Connect(function()
					if not border.Parent then
						if bconn then
							bconn:Disconnect()
						end
						return
					end
					if os.clock() - tRain > 2.5 then
						if bconn then
							bconn:Disconnect()
						end
						TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
						task.delay(0.4, function()
							border:Destroy()
						end)
						return
					end
					grad.Rotation = ((os.clock() - tRain) * 120) % 360
				end)
			end
			task.delay(1.2, function()
				core:Destroy()
				tornado:Destroy()
				bolt:Destroy()
			end)
		end)
	end)
end

local function destroyPetGlow(uid: string)
	local g = petGlowByUid[uid]
	if g then
		if g.light then
			g.light:Destroy()
		end
		if g.motes then
			g.motes:Destroy()
		end
		if g.orbitStars then
			g.orbitStars:Destroy()
		end
		if g.attach.Parent then
			g.attach:Destroy()
		end
		petGlowByUid[uid] = nil
	end
end

local function rarityLightSettings(r: string): (number, Color3, number)
	if r == "common" then
		return 0.2, Color3.new(1, 1, 1), 4
	elseif r == "uncommon" then
		return 0.6, Color3.fromHex("22C55E"), 6
	elseif r == "rare" then
		return 0.9, Color3.fromHex("3B82F6"), 8
	elseif r == "epic" then
		return 1.1, Color3.fromHex("A855F7"), 10
	elseif r == "legendary" then
		return 1.3, Color3.fromHex("F59E0B"), 12
	end
	return 1.2, Color3.new(1, 1, 1), 12 -- mythic: hue cycle handled in heartbeat if needed
end

function VFXController.petOrbitGlow(petUid: string, model: Model?, rarity: string?, phase: string)
	if phase == "unequip" then
		destroyPetGlow(petUid)
		if not model then
			return
		end
		local primary = model.PrimaryPart
		if primary then
			local att = Instance.new("Attachment")
			att.Parent = primary
			local suck = Instance.new("ParticleEmitter")
			suck.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			suck.Lifetime = NumberRange.new(0.3, 0.6)
			suck.Speed = NumberRange.new(-12, -4)
			suck.SpreadAngle = Vector2.new(180, 180)
			suck.Rate = 0
			suck.Parent = att
			suck:Emit(20)
			task.delay(0.55, function()
				att:Destroy()
			end)
		end
		return
	end

	if not model then
		return
	end

	local r = string.lower(rarity or "common")

	local primary = model.PrimaryPart
	if not primary then
		return
	end

	destroyPetGlow(petUid)
	local attach = Instance.new("Attachment")
	attach.Name = "DACVFX_PetGlow"
	attach.Parent = primary

	local brightness, color, range = rarityLightSettings(r)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Color = color
	light.Range = range
	light.Parent = primary

	local motesMax = 4
	if r == "rare" then
		motesMax = 8
	elseif r == "epic" then
		motesMax = 12
	elseif r == "legendary" or r == "mythic" then
		motesMax = 16
	end
	motesMax = lodPetMotesMax(motesMax)

	local motes: ParticleEmitter? = nil
	if motesMax > 0 and r ~= "common" then
		local m = Instance.new("ParticleEmitter")
		m.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		m.Color = if r == "mythic" then mythicRainbowSequence() else ColorSequence.new(Constants.RARITY_COLORS[r] or color)
		m.Lifetime = NumberRange.new(0.5, 1.2)
		m.Rate = math.clamp(motesMax / 4, 1, 6)
		m.Speed = NumberRange.new(0.5, 3)
		m.SpreadAngle = Vector2.new(180, 180)
		m.Parent = attach
		motes = m
	end

	local orbitStars: ParticleEmitter? = nil
	if (r == "legendary" or r == "mythic") and lodTier > 1 then
		local os = Instance.new("ParticleEmitter")
		os.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		os.Color = if r == "mythic" then mythicRainbowSequence() else ColorSequence.new(Color3.fromHex("F59E0B"))
		os.Lifetime = NumberRange.new(0.4, 0.9)
		os.Rate = if r == "mythic" then 6 else 4
		os.Speed = NumberRange.new(2, 8)
		os.SpreadAngle = Vector2.new(360, 360)
		os.Parent = attach
		orbitStars = os
	end

	petGlowByUid[petUid] = {
		light = light,
		motes = motes,
		orbitStars = orbitStars,
		attach = attach,
	}

	if phase == "equip" then
		VFXController.petEquipEntrance(petUid, model, r)
	end
end

function VFXController.onPlayerDataUpdate(data: any)
	if type(data) == "table" and type(data.pets) == "table" then
		local equipped: { { power: number } } = {}
		for _, pet in pairs(data.pets) do
			if type(pet) == "table" and pet.equipped then
				table.insert(equipped, { power = pet.power or 0 })
			end
		end
		cachedPetModifier = Utils.calculatePetModifier(equipped)
	end

	if type(data) == "table" and type(data.cars) == "table" then
		if not carsOwnershipSeeded then
			for carId, c in pairs(data.cars) do
				if type(c) == "table" then
					lastOwnedCarIds[carId :: string] = true
				end
			end
			carsOwnershipSeeded = true
		else
			for carId, c in pairs(data.cars) do
				if type(c) == "table" and not lastOwnedCarIds[carId :: string] then
					lastOwnedCarIds[carId :: string] = true
					local def = CarConfig.Cars[carId :: string]
					local nm = if def and type(def.name) == "string" then def.name else carId :: string
					VFXFacade.carUnlockCelebration(carId :: string, nm)
				end
			end
		end

		local eq = if type(data.equippedCar) == "string" then data.equippedCar else nil
		if eq and type(data.cars[eq]) == "table" then
			local owned = data.cars[eq] :: any
			local g = math.floor(owned.gasLevel or 0)
			local p = math.floor(owned.powerLevel or 0)
			local s = math.floor(owned.speedLevel or 0)
			local prev = lastCarStatLevels[eq]
			if prev == nil then
				lastCarStatLevels[eq] = { gas = g, power = p, speed = s }
			else
				if g > prev.gas then
					VFXFacade.statLevelUp("gas", prev.gas, g)
				end
				if p > prev.power then
					VFXFacade.statLevelUp("power", prev.power, p)
				end
				if s > prev.speed then
					VFXFacade.statLevelUp("speed", prev.speed, s)
				end
				lastCarStatLevels[eq] = { gas = g, power = p, speed = s }
			end
		end
	end

	if type(data) == "table" and type(data.currentWorld) == "string" then
		local w = data.currentWorld
		if lastWorldForTransition ~= nil and lastWorldForTransition ~= w then
			local wf = WorldUnlockConfig.WorldFlavor[w]
			if wf and type(wf.headline) == "string" and type(wf.flavor) == "string" then
				VFXController.milestonePopup(wf.headline .. "|" .. wf.flavor .. "|" .. w, "world_arrival")
			end
		end
		lastWorldForTransition = w
		activeWorldId = w
		if not runActive then
			VFXFacade.ambientStop()
			VFXFacade.ambientStart()
		end
	end

	if type(data) == "table" then
		local petCount = countPets(data.pets)
		local reb = if type(data.rebirths) == "number" then data.rebirths else 0
		local coins = if type(data.coins) == "number" then data.coins else 0
		local worlds = cloneWorldMap(data.unlockedWorlds)

		if careerSnap == nil then
			careerSnap = {
				petCount = petCount,
				rebirths = reb,
				coins = coins,
				worlds = worlds,
				discoveredPets = cloneDiscoveredMap(data.discoveredPets),
			}
		else
			local prev = careerSnap
			local newDisc = cloneDiscoveredMap(data.discoveredPets)

			local newIndexIds: { string } = {}
			for pid, v in pairs(newDisc) do
				if v and not prev.discoveredPets[pid] then
					table.insert(newIndexIds, pid)
				end
			end
			table.sort(newIndexIds)
			local discStagger = 0
			for _, pid in newIndexIds do
				task.delay(discStagger, function()
					VFXFacade.petIndexDiscovery(pid)
				end)
				discStagger += 2.65
			end

			-- Pet index % ceremony copy is server-driven (MilestoneCeremonyCopyConfig via MilestoneCeremonyService).

			if prev.petCount == 0 and petCount >= 1 then
				VFXController.milestonePopup("FIRST PET!", "first_pet")
			end
			if prev.rebirths < reb then
				local mk = RebirthMilestoneConfig.getHighestMilestoneCrossed(prev.rebirths, reb)
				VFXController.rebirthFlash(reb, mk, mk ~= nil)
			end
			if prev.rebirths == 0 and reb >= 1 then
				VFXController.milestonePopup("ASCENDED!", "ascended")
			end
			if prev.petCount < 10 and petCount >= 10 then
				VFXController.milestonePopup("Pet Collector!", "banner")
			end
			if prev.coins < 100_000 and coins >= 100_000 then
				VFXController.milestonePopup("Money Maker!", "banner")
			end
			for wid, unlocked in pairs(worlds) do
				if unlocked and not prev.worlds[wid] then
					VFXController.milestonePopup("NEW WORLD UNLOCKED!" .. "|" .. wid, "world_unlock")
				end
			end
			careerSnap = {
				petCount = petCount,
				rebirths = reb,
				coins = coins,
				worlds = worlds,
				discoveredPets = newDisc,
			}
		end
	end

	processAlmostThereNudges(data)
end

function VFXController.rewardChestBurst()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "DAC_RewardChestBurst"
	att.Parent = cam
	att.WorldCFrame = cam.CFrame * CFrame.new(0, 0, -10)

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
	burst.Lifetime = NumberRange.new(0.35, 0.75)
	burst.Speed = NumberRange.new(6, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 0.6
	burst.Parent = att
	burst:Emit(32)

	local coins = Instance.new("ParticleEmitter")
	coins.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	coins.Color = ColorSequence.new(Color3.fromRGB(255, 190, 40))
	coins.Lifetime = NumberRange.new(0.45, 1.0)
	coins.Speed = NumberRange.new(4, 14)
	coins.SpreadAngle = Vector2.new(180, 180)
	coins.Rate = 0
	coins.Parent = att
	coins:Emit(28)

	task.delay(1.1, function()
		if att.Parent then
			att:Destroy()
		end
	end)
end

local function statLabelLb(stat: string): string
	if stat == "totalDistance" then
		return "Distance"
	elseif stat == "totalRebirths" then
		return "Rebirths"
	end
	return stat
end

local function spawnCrownBurst()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local mul = lodBurstMul()
	local att = Instance.new("Attachment")
	att.Parent = cam
	att.Position = Vector3.new(0, 2.5, -8)

	local crown = Instance.new("ParticleEmitter")
	crown.Name = "CrownBurst"
	crown.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	crown.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 200)),
	})
	crown.Lifetime = NumberRange.new(0.55, 1.15)
	crown.Speed = NumberRange.new(14, 38)
	crown.SpreadAngle = Vector2.new(180, 180)
	crown.Acceleration = Vector3.new(0, -28, 0)
	crown.Drag = 0.42
	crown.Rate = 0
	crown.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.35, 0.85),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	crown.LightEmission = 0.92
	crown.Parent = att
	crown:Emit(math.floor(85 * mul))

	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ring.Color = ColorSequence.new(Color3.fromRGB(255, 215, 64))
	ring.Lifetime = NumberRange.new(0.35, 0.65)
	ring.Speed = NumberRange.new(18, 42)
	ring.SpreadAngle = Vector2.new(25, 180)
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Acceleration = Vector3.new(0, 2, 0)
	ring.Rate = 0
	ring.Parent = att
	ring:Emit(math.floor(48 * mul))

	task.delay(2.4, function()
		if att.Parent then
			att:Destroy()
		end
	end)
end

function VFXController.leaderboardRankFanfare(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local stat = if type(payload.stat) == "string" then payload.stat else "totalDistance"
	local oldRank = tonumber(payload.oldRank)
	local newRank = tonumber(payload.newRank)
	local tier = if type(payload.tier) == "string" then payload.tier else "rankup"

	local sg = screenGui
	if not sg then
		return
	end

	local layer = getCelebrationLayer()
	local statName = statLabelLb(stat)

	-- First time the player appears on a board (no previous snapshot).
	if payload.isFirstPlacement == true then
		if newRank == nil then
			return
		end
		screenFlash(Color3.fromRGB(255, 220, 120), 0.18, 0.28)
		SoundFacade.playOneShot("notification")
		task.delay(0.1, function()
			SoundFacade.playOneShot("currency")
		end)
		local banner = Instance.new("TextLabel")
		banner.Size = UDim2.new(0.88, 0, 0, 72)
		banner.Position = UDim2.new(0.06, 0, 0.36, 0)
		banner.BackgroundTransparency = 1
		banner.Font = Enum.Font.GothamBlack
		banner.TextSize = 40
		banner.TextColor3 = Color3.fromRGB(255, 235, 120)
		banner.TextStrokeTransparency = 0.28
		banner.Text = `You're ranked! #{tostring(newRank)}`
		banner.ZIndex = CELEBRATION_Z + 3
		banner.Parent = layer
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.88, 0, 0, 28)
		sub.Position = UDim2.new(0.06, 0, 0.44, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 20
		sub.TextColor3 = Color3.fromRGB(210, 220, 245)
		sub.TextStrokeTransparency = 0.5
		sub.Text = statName
		sub.ZIndex = CELEBRATION_Z + 3
		sub.Parent = layer
		TweenService:Create(banner, TweenInfo.new(1.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(sub, TweenInfo.new(1.05), { TextTransparency = 1 }):Play()
		task.delay(1.15, function()
			if banner.Parent then
				banner:Destroy()
			end
			if sub.Parent then
				sub:Destroy()
			end
		end)
		return
	end

	if oldRank == nil or newRank == nil then
		return
	end

	if tier == "champion" then
		screenFlash(Color3.fromRGB(255, 230, 100), 0.35, 0.48)
		task.spawn(function()
			cameraShake(0.5, 0.45)
		end)
		spawnPurchaseConfetti()
		SoundFacade.playOneShot("level_up")
		task.delay(0.08, function()
			SoundFacade.playOneShot("purchase")
		end)

		local aura = Instance.new("Frame")
		aura.Name = "ChampionAura"
		aura.Size = UDim2.fromScale(1, 1)
		aura.BackgroundTransparency = 0.92
		aura.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		aura.BorderSizePixel = 0
		aura.ZIndex = CELEBRATION_Z + 1
		aura.Parent = layer
		local ag = Instance.new("UIGradient")
		ag.Rotation = 45
		ag.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 40)),
		})
		ag.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0.75),
		})
		ag.Parent = aura
		local tAura = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			if not aura.Parent then
				if conn then
					conn:Disconnect()
				end
				return
			end
			local e = os.clock() - tAura
			if e >= 2.8 then
				if conn then
					conn:Disconnect()
				end
				TweenService:Create(aura, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
				task.delay(0.5, function()
					aura:Destroy()
				end)
				return
			end
			ag.Rotation = (e * 55) % 360
		end)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.92, 0, 0, 110)
		title.Position = UDim2.new(0.04, 0, 0.34, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 72
		title.TextColor3 = Color3.fromRGB(255, 220, 80)
		title.TextStrokeColor3 = Color3.fromRGB(130, 80, 10)
		title.TextStrokeTransparency = 0.2
		title.Text = "CHAMPION!"
		title.ZIndex = CELEBRATION_Z + 4
		title.Parent = layer
		local ts = Instance.new("UIScale")
		ts.Scale = 0.2
		ts.Parent = title
		TweenService:Create(ts, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
		task.delay(0.42, function()
			if ts.Parent then
				TweenService:Create(ts, TweenInfo.new(0.15), { Scale = 1 }):Play()
			end
		end)

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.9, 0, 0, 44)
		sub.Position = UDim2.new(0.05, 0, 0.5, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 26
		sub.TextColor3 = Color3.fromRGB(255, 250, 220)
		sub.TextStrokeTransparency = 0.45
		sub.Text = `#1 on {statName} — defend your crown!`
		sub.ZIndex = CELEBRATION_Z + 4
		sub.Parent = layer

		TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(sub, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
		task.delay(1.35, function()
			title:Destroy()
			sub:Destroy()
		end)
		return
	end

	if tier == "top10" then
		screenFlash(Color3.fromRGB(255, 210, 90), 0.22, 0.35)
		spawnCrownBurst()
		SoundFacade.playOneShot("level_up")

		local banner = Instance.new("TextLabel")
		banner.Size = UDim2.new(0.92, 0, 0, 64)
		banner.Position = UDim2.new(0.04, 0, 0.12, 0)
		banner.BackgroundTransparency = 1
		banner.Font = Enum.Font.GothamBlack
		banner.TextSize = 44
		banner.TextColor3 = Color3.fromRGB(255, 215, 70)
		banner.TextStrokeTransparency = 0.3
		banner.Text = "TOP 10!"
		banner.ZIndex = CELEBRATION_Z + 3
		banner.Parent = layer

		local detail = Instance.new("TextLabel")
		detail.Size = UDim2.new(0.9, 0, 0, 36)
		detail.Position = UDim2.new(0.05, 0, 0.2, 0)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.GothamBold
		detail.TextSize = 22
		detail.TextColor3 = Color3.fromRGB(240, 240, 255)
		detail.TextStrokeTransparency = 0.5
		detail.Text = `{statName}  #{oldRank} → #{newRank}`
		detail.ZIndex = CELEBRATION_Z + 3
		detail.Parent = layer

		TweenService:Create(banner, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.04, 0, 0.06, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(detail, TweenInfo.new(1.0), { TextTransparency = 1 }):Play()
		task.delay(1.1, function()
			banner:Destroy()
			detail:Destroy()
		end)
		return
	end

	-- rankup: gold arrows + flying rank number
	screenFlash(Color3.fromRGB(255, 220, 120), 0.18, 0.28)
	SoundFacade.playOneShot("notification")
	task.delay(0.12, function()
		SoundFacade.playOneShot("currency")
	end)

	local holder = Instance.new("Frame")
	holder.Name = "RankUpHolder"
	holder.Size = UDim2.new(0.85, 0, 0, 140)
	holder.Position = UDim2.new(0.075, 0, 0.36, 0)
	holder.BackgroundTransparency = 1
	holder.ZIndex = CELEBRATION_Z + 3
	holder.Parent = layer

	local leftArrow = Instance.new("TextLabel")
	leftArrow.Size = UDim2.new(0.2, 0, 1, 0)
	leftArrow.Position = UDim2.new(0, 0, 0, 0)
	leftArrow.BackgroundTransparency = 1
	leftArrow.Font = Enum.Font.GothamBlack
	leftArrow.TextSize = 72
	leftArrow.TextColor3 = Color3.fromRGB(255, 200, 50)
	leftArrow.TextStrokeTransparency = 0.35
	leftArrow.Text = "⬆"
	leftArrow.Rotation = -8
	leftArrow.Parent = holder

	local rightArrow = Instance.new("TextLabel")
	rightArrow.Size = UDim2.new(0.2, 0, 1, 0)
	rightArrow.Position = UDim2.new(0.8, 0, 0, 0)
	rightArrow.BackgroundTransparency = 1
	rightArrow.Font = Enum.Font.GothamBlack
	rightArrow.TextSize = 72
	rightArrow.TextColor3 = Color3.fromRGB(255, 200, 50)
	rightArrow.TextStrokeTransparency = 0.35
	rightArrow.Text = "⬆"
	rightArrow.Rotation = 8
	rightArrow.Parent = holder

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Size = UDim2.new(0.56, 0, 1, 0)
	rankLbl.Position = UDim2.new(0.22, 0, 0, 0)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Font = Enum.Font.GothamBlack
	rankLbl.TextSize = 86
	rankLbl.TextColor3 = Color3.fromRGB(255, 235, 120)
	rankLbl.TextStrokeColor3 = Color3.fromRGB(120, 80, 20)
	rankLbl.TextStrokeTransparency = 0.25
	rankLbl.Text = "#" .. tostring(oldRank)
	rankLbl.Parent = holder

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(0.9, 0, 0, 28)
	sub.Position = UDim2.new(0.05, 0, 0.92, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 18
	sub.TextColor3 = Color3.fromRGB(200, 210, 240)
	sub.TextStrokeTransparency = 0.55
	sub.Text = `{statName} leaderboard`
	sub.ZIndex = CELEBRATION_Z + 3
	sub.Parent = layer

	local startClock = os.clock()
	local dur = 0.55
	local conn2: RBXScriptConnection? = nil
	conn2 = RunService.RenderStepped:Connect(function()
		if not rankLbl.Parent then
			if conn2 then
				conn2:Disconnect()
			end
			return
		end
		local t = math.clamp((os.clock() - startClock) / dur, 0, 1)
		local v = math.floor(oldRank + (newRank - oldRank) * t + 0.0001)
		rankLbl.Text = "#" .. tostring(v)
		rankLbl.TextColor3 = Color3.fromRGB(255, 235, 120):Lerp(Color3.fromRGB(120, 255, 180), t)
		if t >= 1 then
			if conn2 then
				conn2:Disconnect()
			end
		end
	end)

	TweenService:Create(holder, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.075, 0, 0.22, 0),
	}):Play()
	TweenService:Create(leftArrow, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Rotation = -14,
	}):Play()
	TweenService:Create(rightArrow, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Rotation = 14,
	}):Play()

	task.delay(dur, function()
		if rankLbl.Parent then
			rankLbl.Text = "#" .. tostring(newRank)
		end
	end)

	task.delay(0.9, function()
		TweenService:Create(holder, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.075, 0, 0.14, 0),
		}):Play()
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.55), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
		TweenService:Create(sub, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.5, function()
		holder:Destroy()
		sub:Destroy()
	end)
end

function VFXController.premiumWelcomeFanfare()
	local sg = screenGui
	if not sg then
		return
	end

	-- Golden full-screen flash
	screenFlash(Color3.fromRGB(255, 210, 60), 0.5, 0.25)
	task.spawn(function()
		cameraShake(0.18, 0.25)
	end)
	SoundFacade.playOneShot("premium_welcome")

	-- Confetti burst from camera
	local cam = workspace.CurrentCamera
	if cam then
		local att = Instance.new("Attachment")
		att.Parent = cam
		att.Position = Vector3.new(0, 3, -10)
		local mul = lodBurstMul()
		local conf = Instance.new("ParticleEmitter")
		conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		conf.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 60)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 180, 40)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 240, 150)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 80)),
		})
		conf.Lifetime = NumberRange.new(1.0, 1.8)
		conf.Speed = NumberRange.new(12, 36)
		conf.SpreadAngle = Vector2.new(180, 180)
		conf.Acceleration = Vector3.new(0, -32, 0)
		conf.Drag = 0.4
		conf.Rate = 0
		conf.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.4, 0.5),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		conf.LightEmission = 0.8
		conf.Parent = att
		conf:Emit(math.floor(48 * mul))
		task.delay(3.0, function()
			att:Destroy()
		end)
	end

	-- Premium badge popup with scale animation
	local layer = getCelebrationLayer()

	local badge = Instance.new("Frame")
	badge.Name = "PremiumBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0.5, 0, 0.42, 0)
	badge.Size = UDim2.fromOffset(320, 180)
	badge.BackgroundColor3 = Color3.fromRGB(30, 22, 5)
	badge.BackgroundTransparency = 0.15
	badge.ZIndex = CELEBRATION_Z + 1
	badge.Parent = layer

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 16)
	badgeCorner.Parent = badge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(255, 200, 50)
	badgeStroke.Thickness = 3
	badgeStroke.Parent = badge

	local star = Instance.new("TextLabel")
	star.Size = UDim2.fromOffset(60, 60)
	star.Position = UDim2.new(0.5, -30, 0, 16)
	star.BackgroundTransparency = 1
	star.Text = "⭐"
	star.TextSize = 44
	star.Font = Enum.Font.GothamBold
	star.ZIndex = CELEBRATION_Z + 3
	star.Parent = badge

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, -20, 0, 40)
	heading.Position = UDim2.new(0, 10, 0, 78)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 28
	heading.TextColor3 = Color3.fromRGB(255, 215, 60)
	heading.TextStrokeColor3 = Color3.fromRGB(120, 70, 10)
	heading.TextStrokeTransparency = 0.4
	heading.Text = "PREMIUM UNLOCKED!"
	heading.ZIndex = CELEBRATION_Z + 2
	heading.Parent = badge

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 0, 48)
	sub.Position = UDim2.new(0, 10, 0, 118)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 15
	sub.TextColor3 = Color3.fromRGB(255, 240, 180)
	sub.TextWrapped = true
	sub.Text = MicrocopyConfig.PremiumWelcome[math.random(1, #MicrocopyConfig.PremiumWelcome)]
	sub.ZIndex = CELEBRATION_Z + 2
	sub.Parent = badge

	-- Pop-in scale
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = badge
	local popIn = TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
	popIn:Play()
	popIn.Completed:Connect(function()
		if sc.Parent then
			TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	-- Border pulse
	task.spawn(function()
		for _ = 1, 4 do
			if not badgeStroke.Parent then break end
			TweenService:Create(badgeStroke, TweenInfo.new(0.3), { Thickness = 6 }):Play()
			task.wait(0.3)
			TweenService:Create(badgeStroke, TweenInfo.new(0.3), { Thickness = 3 }):Play()
			task.wait(0.3)
		end
	end)

	-- Fade out + drift up
	task.delay(2.0, function()
		if not badge.Parent then return end
		TweenService:Create(badge, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.36, 0),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(badgeStroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		TweenService:Create(heading, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(star, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	end)
	task.delay(3.0, function()
		badge:Destroy()
	end)
	task.delay(3.2, function()
		if layer and layer.Parent and #layer:GetChildren() == 0 then
			layer:Destroy()
		end
	end)
end

local function serverDropResolveLine(playerName: string, petName: string, rarity: string): string
	local ok, cfg = pcall(function()
		return require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
	end)
	local template: string
	if ok and cfg and type((cfg :: any).pickDropLine) == "function" then
		local picked = (cfg :: any).pickDropLine(rarity)
		if type(picked) == "string" and picked ~= "" then
			template = picked
		else
			template = "{PLAYER} hatched {PET} ({RARITY})!"
		end
	else
		template = "{PLAYER} hatched {PET} ({RARITY})!"
	end
	return template
		:gsub("{PLAYER}", playerName)
		:gsub("{PET}", petName)
		:gsub("{RARITY}", string.upper(rarity))
end

local function serverDropStyleForRarity(rarity: string): (Color3, Color3, boolean)
	local r = string.lower(rarity)
	if r == "rare" then
		return Color3.fromRGB(28, 40, 72), Color3.fromRGB(120, 190, 255), false
	elseif r == "epic" then
		return Color3.fromRGB(48, 22, 80), Color3.fromRGB(210, 120, 255), false
	elseif r == "legendary" then
		return Color3.fromRGB(56, 42, 8), Color3.fromRGB(255, 210, 80), false
	elseif r == "mythic" then
		return Color3.fromRGB(20, 14, 36), Color3.fromRGB(255, 255, 255), true
	end
	return Color3.fromRGB(32, 32, 40), Color3.fromRGB(220, 220, 235), false
end

local serverDropShowNext: () -> ()

local function serverDropScheduleDrain()
	if serverDropShowing then
		return
	end
	if #serverDropQueue == 0 then
		return
	end
	if serverDropPendingDrain then
		task.cancel(serverDropPendingDrain)
		serverDropPendingDrain = nil
	end
	local now = os.clock()
	local since = if serverDropLastStartClock > 0 then (now - serverDropLastStartClock) else SERVER_DROP_THROTTLE_SEC
	local gap = SERVER_DROP_THROTTLE_SEC - since
	if gap > 0.01 then
		serverDropPendingDrain = task.delay(gap, function()
			serverDropPendingDrain = nil
			serverDropShowNext()
		end)
		return
	end
	serverDropShowNext()
end

serverDropShowNext = function()
	if serverDropShowing then
		return
	end
	if #serverDropQueue == 0 then
		return
	end
	local sg = screenGui
	if not sg then
		while #serverDropQueue > 0 do
			table.remove(serverDropQueue, 1)
		end
		return
	end
	local item = table.remove(serverDropQueue, 1)
	serverDropShowing = true
	serverDropLastStartClock = os.clock()

	local bgCol, strokeCol, useMythicGradient = serverDropStyleForRarity(item.rarity)
	local line = serverDropResolveLine(item.playerName, item.petName, item.rarity)

	local root = Instance.new("Frame")
	root.Name = "ServerDropFeedBanner"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Size = UDim2.fromOffset(460, 48)
	root.Position = UDim2.new(1.35, 0, 0, SERVER_DROP_TOP_PX)
	root.BackgroundColor3 = bgCol
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.ZIndex = 8000
	root.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeCol
	stroke.Thickness = 2
	stroke.Parent = root

	if useMythicGradient then
		local bgGrad = Instance.new("UIGradient")
		bgGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(120, 220, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 230, 120)),
			ColorSequenceKeypoint.new(0.78, Color3.fromRGB(160, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
		})
		bgGrad.Rotation = 10
		bgGrad.Parent = root
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -10)
	label.Position = UDim2.new(0, 10, 0, 5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = line
	label.TextColor3 = Color3.fromRGB(245, 248, 255)
	label.TextStrokeTransparency = 0.5
	label.ZIndex = 8001
	label.Parent = root

	if useMythicGradient then
		local tg = Instance.new("UIGradient")
		tg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 120)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 140, 220)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(130, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 120)),
		})
		tg.Parent = label
	end

	SoundFacade.playOneShot("notification")

	local slideIn = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local holdT = 3.0
	local slideOut = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local inPos = UDim2.new(0.5, 0, 0, SERVER_DROP_TOP_PX)
	TweenService:Create(root, slideIn, { Position = inPos }):Play()
	task.delay(0.38 + holdT, function()
		if not root.Parent then
			serverDropShowing = false
			serverDropScheduleDrain()
			return
		end
		local outPos = UDim2.new(-0.35, 0, 0, SERVER_DROP_TOP_PX)
		local tw = TweenService:Create(root, slideOut, { Position = outPos })
		tw:Play()
		tw.Completed:Connect(function()
			if root.Parent then
				root:Destroy()
			end
			serverDropShowing = false
			serverDropScheduleDrain()
		end)
	end)
end

function VFXController.serverDropFeedBanner(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local uid = tonumber(payload.userId)
	if uid and uid == player.UserId then
		return
	end
	local playerName = if type(payload.playerName) == "string" then payload.playerName else "Someone"
	local petName = if type(payload.petName) == "string" then payload.petName else "Pet"
	local rarityRaw = if type(payload.rarity) == "string" then payload.rarity else "rare"
	local rarity = string.lower(rarityRaw)

	table.insert(serverDropQueue, {
		playerName = playerName,
		petName = petName,
		rarity = rarity,
		userId = uid or 0,
	})
	while #serverDropQueue > SERVER_DROP_MAX_QUEUE do
		table.remove(serverDropQueue, 1)
	end
	serverDropScheduleDrain()
end

return VFXController
