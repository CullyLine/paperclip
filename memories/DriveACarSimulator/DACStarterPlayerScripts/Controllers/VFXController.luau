--!strict
--[[
	Client VFX: dual speed trails, boost overlay, hatch timeline, pet orbit glow,
	ambient world particles, lap flash, world transitions, mobile LOD.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

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
local lastUpgradeSum: number? = nil
local shakeToken = 0

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

local ambientFolder: Folder? = nil
local ambientEmitters: { ParticleEmitter } = {}
local ambientRunning = false

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

function VFXController.onRunStarted(runInfo: any)
	runActive = true
	activeWorldId = if type(runInfo) == "table" and type(runInfo.worldId) == "string" then runInfo.worldId else "grasslands"
	local cam = workspace.CurrentCamera
	if cam then
		baseCameraFov = cam.FieldOfView
	end
	VFXController.ambientStop()
	ensureTrailOnCar()
end

function VFXController.onRunEnded()
	runActive = false
	destroyTrail()
	VFXController.ambientStart()
end

function VFXController.speedTrail(speed: number, boost: boolean?)
	ensureTrailOnCar()
	if not trailEmitterL or not trailEmitterR then
		return
	end
	if boost == true then
		VFXController.boostOverlay(true)
	elseif boost == false then
		VFXController.boostOverlay(false)
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
		hitstop = 0.25,
	},
}

local function makeEmitter(att: Attachment, texture: string, col: ColorSequence)
	local p = Instance.new("ParticleEmitter")
	p.Texture = texture
	p.Color = col
	p.Parent = att
	return p
end

local function emitBurst(att: Attachment, spec: BurstSpec, rarity: string, col: Color3)
	local m = lodBurstMul()
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
	local tier = rarityTier(rarity)
	local col = Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
	local spec = BURST_TABLE[rarity] or BURST_TABLE.common

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

	local sg = screenGui
	if not sg then
		return
	end

	-- Phase 1 (0-2s): anticipation UI + dust at feet
	local eggFrame = Instance.new("Frame")
	eggFrame.Size = UDim2.fromOffset(140, 180)
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.Position = UDim2.new(0.5, 0, 0.48, 0)
	eggFrame.BackgroundColor3 = Color3.fromRGB(240, 230, 210)
	eggFrame.BackgroundTransparency = 0.1
	eggFrame.ZIndex = 40
	eggFrame.Parent = sg
	local eggCorner = Instance.new("UICorner")
	eggCorner.CornerRadius = UDim.new(0, 24)
	eggCorner.Parent = eggFrame

	local t0 = os.clock()
	local rockConn: RBXScriptConnection? = nil
	rockConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - t0
		if elapsed > 2 then
			if rockConn then
				rockConn:Disconnect()
			end
			return
		end
		local env = math.clamp(elapsed / 2, 0, 1)
		local wobble = math.sin(elapsed * (math.pi * 2 / 0.5)) * math.rad(4) * env
		eggFrame.Rotation = math.deg(wobble)
	end)

	local dustAtt: Attachment? = nil
	if root then
		dustAtt = Instance.new("Attachment")
		dustAtt.Position = Vector3.new(0, -2, 0)
		dustAtt.Parent = root
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromHex("D4C4A8"))
		dust.Lifetime = NumberRange.new(0.4, 0.8)
		dust.Rate = if lodTier <= 1 then 4 else 12
		dust.Speed = NumberRange.new(2, 6)
		dust.SpreadAngle = Vector2.new(25, 25)
		dust.Parent = dustAtt
		local spark = Instance.new("ParticleEmitter")
		spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spark.Color = ColorSequence.new(col)
		spark.Lifetime = NumberRange.new(1.5, 2)
		spark.Rate = if lodTier <= 1 then 5 else 14
		spark.Speed = NumberRange.new(1, 4)
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.Parent = dustAtt
		task.delay(2, function()
			dust.Enabled = false
			spark.Enabled = false
		end)
	end

	local vig = getVignetteFrame()
	vig.BackgroundTransparency = 0.92
	TweenService:Create(vig, TweenInfo.new(1.5), { BackgroundTransparency = 0.85 }):Play()

	task.delay(2, function()
		eggFrame.BackgroundColor3 = col
		TweenService:Create(eggFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(160, 200),
		}):Play()
	end)

	-- Phase 2-3: crack + beams (handled inside emitBurst at t=3)
	task.delay(3, function()
		if eggFrame.Parent then
			TweenService:Create(eggFrame, TweenInfo.new(0.35), { BackgroundTransparency = 1, Rotation = 8 }):Play()
		end
		TweenService:Create(vig, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		if tier >= 4 then
			task.spawn(function()
				cameraShake(spec.shake > 0 and spec.shake or 0.25, 0.2)
			end)
		end

		local attParent = root or trailPart
		if attParent and attParent:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 1, 0)
			att.Parent = attParent
			emitBurst(att, spec, rarity, col)
			task.delay(spec.duration + 1, function()
				att:Destroy()
			end)
		end

		screenFlash(col, 0.18, 0.55)
		if rarity == "mythic" then
			screenFlash(Color3.new(1, 1, 1), 0.2, 0.12)
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
	end)

	-- Phase 4.5-6: confetti
	task.delay(4.5, function()
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

	task.delay(6, function()
		if eggFrame.Parent then
			eggFrame:Destroy()
		end
	end)

	task.delay(2.1, function()
		if dustAtt then
			dustAtt:Destroy()
		end
	end)
end

function VFXController.rebirthFlash(rebirthCount: number)
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

local function acquirePopup(): TextLabel
	popupIndex += 1
	if popupIndex > #popupPool then
		popupIndex = 1
	end
	return popupPool[popupIndex]
end

function VFXController.currencyPopup(currencyType: string, amount: number)
	SoundFacade.playOneShot("currency")
	local sg = screenGui
	if not sg then
		return
	end
	local lbl = acquirePopup()
	local symbol = "+"
	local text = `{symbol}{Utils.formatNumber(amount)} {currencyType}`
	lbl.Text = text
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

local function sumUpgradeLevels(data: any): number
	if type(data) ~= "table" or type(data.cars) ~= "table" then
		return 0
	end
	local n = 0
	for _, c in data.cars do
		if type(c) == "table" then
			n += (c.gasLevel or 0) + (c.powerLevel or 0) + (c.speedLevel or 0)
		end
	end
	return n
end

function VFXController.lapFlash(isPersonalBest: boolean)
	local sg = screenGui
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
	if activeWorldId ~= "grasslands" then
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

	local pollen = Instance.new("ParticleEmitter")
	pollen.Name = "Pollen"
	pollen.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pollen.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200))
	pollen.Lifetime = NumberRange.new(4, 8)
	pollen.Rate = if lodTier == 2 then 2 else 3
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
	seeds.Rate = if lodTier == 2 then 1.5 else 2.5
	seeds.Speed = NumberRange.new(0.5, 2)
	seeds.SpreadAngle = Vector2.new(180, 180)
	seeds.Parent = folder
	table.insert(ambientEmitters, seeds)
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
		local ring = Instance.new("ParticleEmitter")
		ring.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		ring.Color = ColorSequence.new(Constants.RARITY_COLORS[r] or color)
		ring.Lifetime = NumberRange.new(0.2, 0.45)
		ring.Rate = 0
		ring.Speed = NumberRange.new(8, 18)
		ring.SpreadAngle = Vector2.new(10, 180)
		ring.Parent = attach
		local burstCount = math.floor(math.clamp(12 + motesMax * 2, 12, 40) * lodBurstMul())
		ring:Emit(burstCount)
		task.delay(0.5, function()
			ring:Destroy()
		end)
	end
end

function VFXController.onPlayerDataUpdate(data: any)
	local s = sumUpgradeLevels(data)
	if lastUpgradeSum ~= nil and s > lastUpgradeSum then
		VFXController.upgradeFlash()
	end
	lastUpgradeSum = s

	if type(data) == "table" and type(data.currentWorld) == "string" then
		local w = data.currentWorld
		if lastWorldForTransition ~= nil and lastWorldForTransition ~= w then
			VFXController.worldTransition(lastWorldForTransition, w)
		end
		lastWorldForTransition = w
		activeWorldId = w
		if not runActive then
			VFXController.ambientStop()
			VFXController.ambientStart()
		end
	end
end

return VFXController
