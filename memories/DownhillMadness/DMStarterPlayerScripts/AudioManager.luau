--[[
	AudioManager — Client-side vehicle audio for Downhill Madness.

	Engine (pitch + volume vs speed), crash pool, tire screech vs lateral slip,
	wind layers vs speed, optional UI one-shots. Parent sounds to the vehicle
	PrimaryPart; call destroy() when leaving the seat.

	Expected wiring (see issue POL-158): ChassisClient calls
	new → update each frame → playImpact / playGlassShatter on damage → destroy.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMRep = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local AudioConfig = require(DMRep:WaitForChild("AudioConfig"))

export type AudioManagerImpl = {
	destroy: (self: AudioManagerImpl) -> (),
	update: (self: AudioManagerImpl, speed: number, maxSpeed: number, lateralFraction: number) -> (),
	playImpact: (self: AudioManagerImpl, severity: number) -> (),
	playGlassShatter: (self: AudioManagerImpl) -> (),
	playUiClick: (self: AudioManagerImpl) -> (),
	playUiHover: (self: AudioManagerImpl) -> (),
}

local AudioManager = {}
AudioManager.__index = AudioManager

local sfxRoot: SoundGroup? = nil
local groups: { [string]: SoundGroup } = {}

local function ensureGroup(name: string, volume: number): SoundGroup
	if not sfxRoot then
		local root = SoundService:FindFirstChild("DM_SFX")
		if not root then
			root = Instance.new("SoundGroup")
			root.Name = "DM_SFX"
			root.Volume = 0.85
			root.Parent = SoundService
		end
		sfxRoot = root :: SoundGroup
	end
	local g = groups[name]
	if not g then
		local sg = SoundService:FindFirstChild("DM_" .. name)
		if not sg or not sg:IsA("SoundGroup") then
			sg = Instance.new("SoundGroup")
			sg.Name = "DM_" .. name
			sg.Volume = volume
			sg.Parent = SoundService
		end
		g = sg :: SoundGroup
		groups[name] = g
	end
	return g
end

local function applySpatial(s: Sound)
	local sp = AudioConfig.Spatial
	s.RollOffMode = sp.rolloffMode
	s.RollOffMinDistance = sp.minDistance
	s.RollOffMaxDistance = sp.maxDistance
	s.EmitterSize = sp.minDistance
end

local function safeSoundId(id: string): string
	if id == "" or id == "rbxassetid://0" then
		return "rbxassetid://0"
	end
	return id
end

function AudioManager.new(vehicle: Model, vehicleId: string): AudioManagerImpl
	local root = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
	if not root or not root:IsA("BasePart") then
		error("[AudioManager] Vehicle needs a PrimaryPart or a BasePart")
	end

	local self = setmetatable({
		_vehicle = vehicle,
		_root = root :: BasePart,
		_profile = AudioConfig.getProfile(vehicleId),
		_engine = nil :: Sound?,
		_engineBed = nil :: Sound?,
		_crashPool = {} :: { Sound },
		_crashIdx = 1,
		_screech = nil :: Sound?,
		_windA = nil :: Sound?,
		_windB = nil :: Sound?,
		_glass = nil :: Sound?,
		_lastCrash = 0,
		_smPitch = 0.9,
		_smEngVol = 0,
		_smScreech = 0,
		_smWindA = 0,
		_smWindB = 0,
		_lastTick = tick(),
	}, AudioManager)

	local gEngine = ensureGroup("Engine", 1)
	local gTires = ensureGroup("Tires", 0.9)
	local gColl = ensureGroup("Collision", 1)
	local gWind = ensureGroup("Wind", 0.65)

	local ids = AudioConfig.AssetIds

	local function mk(parent: Instance, soundGroup: SoundGroup, id: string, looped: boolean): Sound
		local s = Instance.new("Sound")
		s.Name = "DM_Audio"
		s.SoundId = safeSoundId(id)
		s.Looped = looped
		s.SoundGroup = soundGroup
		s.Parent = parent
		applySpatial(s)
		return s
	end

	self._engine = mk(root, gEngine, ids.engine.primary, true)
	self._engineBed = mk(root, gEngine, ids.engine.bed, true)
	self._engineBed.Volume = 0.25

	local tireId = if self._profile.screechVariant == "low" then ids.tires.low else ids.tires.medium
	self._screech = mk(root, gTires, tireId, true)
	self._screech.Volume = 0

	self._windA = mk(root, gWind, ids.wind.bed, true)
	self._windB = mk(root, gWind, ids.wind.turbulent, true)
	self._windA.Volume = 0
	self._windB.Volume = 0

	for _, cid in ids.crash do
		local c = mk(root, gColl, cid, false)
		c.Volume = 0.85
		table.insert(self._crashPool, c)
	end

	self._glass = mk(root, gColl, ids.glass, false)

	for _, s in { self._engine, self._engineBed, self._screech, self._windA, self._windB } do
		if s and s.SoundId ~= "rbxassetid://0" then
			s:Play()
		end
	end

	return self
end

local function expSmooth(current: number, target: number, rate: number, dt: number): number
	local a = 1 - math.exp(-rate * dt)
	return current + (target - current) * a
end

function AudioManager:update(speed: number, maxSpeed: number, lateralFraction: number)
	local now = tick()
	local dt = math.clamp(now - self._lastTick, 0, 0.1)
	self._lastTick = now

	local prof = self._profile
	local maxS = math.max(maxSpeed, 1)
	local spdFrac = math.clamp(speed / maxS, 0, 1)

	local pitchTarget = prof.enginePitchIdle
		+ (prof.enginePitchMax - prof.enginePitchIdle) * spdFrac
		+ prof.enginePitchBias
	pitchTarget = math.clamp(pitchTarget, 0.35, 2.5)

	local volTarget = prof.engineVolumeIdle
		+ (prof.engineVolumeMax - prof.engineVolumeIdle) * (spdFrac ^ 0.85)

	self._smPitch = expSmooth(self._smPitch, pitchTarget, 18, dt)
	self._smEngVol = expSmooth(self._smEngVol, volTarget, 14, dt)

	if self._engine then
		self._engine.PlaybackSpeed = self._smPitch
		self._engine.Volume = self._smEngVol
	end
	if self._engineBed then
		self._engineBed.PlaybackSpeed = self._smPitch * 0.97
		self._engineBed.Volume = self._smEngVol * 0.35
	end

	local slip = math.clamp(math.abs(lateralFraction), 0, 3)
	local screechTarget = 0
	if slip > AudioConfig.ScreechLateralThreshold then
		local t = math.clamp((slip - AudioConfig.ScreechLateralThreshold) / 1.25, 0, 1)
		screechTarget = t * math.clamp(spdFrac * 1.2, 0, 1)
	end
	local screechRate = if screechTarget > self._smScreech
		then AudioConfig.ScreechFadeIn
		else AudioConfig.ScreechFadeOut
	self._smScreech = expSmooth(self._smScreech, screechTarget, screechRate, dt)
	if self._screech then
		self._screech.Volume = self._smScreech * 0.7
		self._screech.PlaybackSpeed = 0.92 + self._smScreech * 0.35
	end

	local windOn = math.clamp((spdFrac - AudioConfig.WindSpeedStartFraction) / (1 - AudioConfig.WindSpeedStartFraction + 1e-4), 0, 1)
	local wPitch = AudioConfig.WindPitchMin + (AudioConfig.WindPitchMax - AudioConfig.WindPitchMin) * spdFrac
	self._smWindA = expSmooth(self._smWindA, windOn * 0.45, 6, dt)
	self._smWindB = expSmooth(self._smWindB, windOn * windOn * 0.55, 8, dt)
	if self._windA then
		self._windA.Volume = self._smWindA * 0.5
		self._windA.PlaybackSpeed = wPitch * 0.95
	end
	if self._windB then
		self._windB.Volume = self._smWindB * 0.55
		self._windB.PlaybackSpeed = wPitch * 1.08
	end
end

function AudioManager:playImpact(severity: number)
	local t = tick()
	if (t - self._lastCrash) < AudioConfig.CrashCooldown then
		return
	end
	self._lastCrash = t

	local pool = self._crashPool
	if #pool == 0 then
		return
	end

	local c = AudioConfig.CrashSeverityClamp
	local sev = math.clamp(severity, c.min, c.max)
	local s = pool[self._crashIdx]
	self._crashIdx = (self._crashIdx % #pool) + 1

	if not s or s.SoundId == "rbxassetid://0" then
		return
	end

	s.PlaybackSpeed = 0.92 + math.random() * 0.18
	s.Volume = 0.35 + 0.55 * ((sev - c.min) / (c.max - c.min))
	s:Play()
end

function AudioManager:playGlassShatter()
	local s = self._glass
	if not s or s.SoundId == "rbxassetid://0" then
		return
	end
	s.PlaybackSpeed = 0.98 + math.random() * 0.06
	s.Volume = 0.75
	s:Play()
end

local function playUi(self: AudioManagerImpl, key: "click" | "hover")
	local id = AudioConfig.AssetIds.ui[key]
	if not id or id == "rbxassetid://0" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.35
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
end

function AudioManager:playUiClick()
	playUi(self, "click")
end

function AudioManager:playUiHover()
	playUi(self, "hover")
end

function AudioManager:destroy()
	local list = {
		self._engine,
		self._engineBed,
		self._screech,
		self._windA,
		self._windB,
		self._glass,
	}
	for _, s in list do
		if s then
			s:Stop()
			s:Destroy()
		end
	end
	for _, s in self._crashPool do
		s:Stop()
		s:Destroy()
	end
	self._crashPool = {}
	self._engine = nil
	self._engineBed = nil
	self._screech = nil
	self._windA = nil
	self._windB = nil
	self._glass = nil
	setmetatable(self, nil)
end

return AudioManager
