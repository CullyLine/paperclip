--[[
	VFXController — P0 client VFX: tire smoke, panel sparks, windshield shatter burst, speed lines.

	Lifecycle matches ChassisClient: attach() when driving starts, update() each Heartbeat, destroy() on exit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local DMRep = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local VFXConfig = require(DMRep:WaitForChild("VFXConfig"))

export type DriveContext = {
	root: BasePart,
	rootCF: CFrame,
	velocity: Vector3,
	speed: number,
	forwardSpeed: number,
	lateralSlipFraction: number,
	effectiveMaxSpeed: number,
}

local function randRange(a: number, b: number): number
	return a + (b - a) * math.random()
end

local function makeSmokeEmitter(parent: BasePart, tint: Color3): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "TireSmoke"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = 0
	pe.Enabled = true
	pe.Lifetime = NumberRange.new(VFXConfig.tireSmoke.lifetimeMin, VFXConfig.tireSmoke.lifetimeMax)
	pe.Speed = NumberRange.new(2, 8)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, VFXConfig.tireSmoke.sizeMin),
		NumberSequenceKeypoint.new(1, VFXConfig.tireSmoke.sizeMax),
	})
	pe.Transparency = NumberSequence.new(VFXConfig.tireSmoke.transparency)
	pe.Color = ColorSequence.new(tint)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-40, 40)
	pe.Drag = 2
	pe.Acceleration = Vector3.new(0, 2, 0)
	pe.Parent = parent
	return pe
end

local function makeBurstEmitter(name: string, colorSeq: ColorSequence): ParticleEmitter
	local holder = Instance.new("Part")
	holder.Name = "VFXBurst_" .. name
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace

	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Enabled = true
	pe.EmissionDirection = Enum.NormalId.Top
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Color = colorSeq
	pe.Parent = holder
	return pe
end

local function burstConfigEmit(pe: ParticleEmitter, cfg: { countMin: number, countMax: number, speedMin: number, speedMax: number, sizeMin: number, sizeMax: number, lifetimeMin: number, lifetimeMax: number, spreadDeg: number }, worldCF: CFrame)
	local holder = pe.Parent :: BasePart
	holder.CFrame = worldCF
	pe.Speed = NumberRange.new(cfg.speedMin, cfg.speedMax)
	pe.Lifetime = NumberRange.new(cfg.lifetimeMin, cfg.lifetimeMax)
	pe.Size = NumberSequence.new(cfg.sizeMin, cfg.sizeMax)
	pe.SpreadAngle = Vector2.new(cfg.spreadDeg * 0.5, cfg.spreadDeg * 0.5)
	pe.Acceleration = Vector3.new(0, -workspace.Gravity * 0.35, 0)
	local n = math.random(cfg.countMin, cfg.countMax)
	pe:Emit(n)
end

local VFXController = {}
VFXController.__index = VFXController

function VFXController.new(): any
	local self = setmetatable({
		_vehicleId = "all_rounder",
		_cfg = nil :: any,
		_profile = VFXConfig.getProfile("all_rounder"),
		_smokeL = nil :: ParticleEmitter?,
		_smokeR = nil :: ParticleEmitter?,
		_sparks = nil :: ParticleEmitter?,
		_glass = nil :: ParticleEmitter?,
		_speedGui = nil :: ScreenGui?,
		_streaks = {} :: { Frame },
		_panelConn = nil :: RBXScriptConnection?,
		_damageConn = nil :: RBXScriptConnection?,
		_active = false,
	}, VFXController)
	return self
end

function VFXController:_buildSpeedLines(profile: any)
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "VFXSpeedLines"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ResetOnSpawn = false
	gui.Parent = pg

	local count = VFXConfig.speedLines.streakCount
	local streaks: { Frame } = {}
	local inset = 0.02
	for i = 1, count do
		local f = Instance.new("Frame")
		f.Name = "Streak" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = profile.speedLineTint
		f.BorderSizePixel = 0
		f.Rotation = (i / count) * 360
		local t = (i % 4) / 4
		local edge = i % 4
		if edge == 0 then
			f.Position = UDim2.new(inset + t * (1 - 2 * inset), 0, inset, 0)
			f.Size = UDim2.new(0, 3, 0.12, 0)
		elseif edge == 1 then
			f.Position = UDim2.new(1 - inset, 0, inset + t * (1 - 2 * inset), 0)
			f.Size = UDim2.new(0.08, 0, 0, 3)
		elseif edge == 2 then
			f.Position = UDim2.new(inset + t * (1 - 2 * inset), 0, 1 - inset, 0)
			f.Size = UDim2.new(0, 3, 0.1, 0)
		else
			f.Position = UDim2.new(inset, 0, inset + t * (1 - 2 * inset), 0)
			f.Size = UDim2.new(0.06, 0, 0, 3)
		end
		f.BackgroundTransparency = 1
		f.Parent = gui
		table.insert(streaks, f)
	end

	self._speedGui = gui
	self._streaks = streaks
end

function VFXController:_tearDownSpeedLines()
	if self._speedGui then
		self._speedGui:Destroy()
		self._speedGui = nil
	end
	self._streaks = {}
end

function VFXController:_shouldCull(worldPos: Vector3): boolean
	local cam = workspace.CurrentCamera
	if not cam then return false end
	return (worldPos - cam.CFrame.Position).Magnitude > VFXConfig.cullDistanceStuds
end

function VFXController:attach(vehicleModel: Model, chassisCfg: any, wheels: { any })
	self:destroy()

	self._cfg = chassisCfg
	self._vehicleId = (vehicleModel:GetAttribute("VehicleId") :: string?) or "all_rounder"
	self._profile = VFXConfig.getProfile(self._vehicleId)
	self._active = true

	local smokeTint = self._profile.smokeTint
	local rl, rr: BasePart? = nil, nil
	for _, w in wheels do
		if w.def.name == "WheelRL" then rl = w.visual end
		if w.def.name == "WheelRR" then rr = w.visual end
	end
	if rl then self._smokeL = makeSmokeEmitter(rl, smokeTint) end
	if rr then self._smokeR = makeSmokeEmitter(rr, smokeTint) end

	self._sparks = makeBurstEmitter("Sparks", ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 40)),
	}))
	self._glass = makeBurstEmitter("Glass", ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
	}))

	self:_buildSpeedLines(self._profile)

	local panelEv = ReplicatedStorage:FindFirstChild("PanelDetached") :: RemoteEvent?
	if panelEv then
		self._panelConn = panelEv.OnClientEvent:Connect(function(data: any)
			if typeof(data) ~= "table" then return end
			if type(data.vehicleName) ~= "string" or type(data.panelName) ~= "string" then return end
			if data.panelName == "Windshield" then return end

			local veh = workspace:FindFirstChild(data.vehicleName)
			if not veh then return end
			local panels = veh:FindFirstChild("BodyPanels")
			if not panels then return end
			local panel = panels:FindFirstChild(data.panelName)
			if not panel or not panel:IsA("BasePart") then return end
			if self:_shouldCull(panel.Position) then return end

			local dir = Vector3.new(0, 1, 0)
			if type(data.impulseDir) == "table" and data.impulseDir[1] then
				dir = Vector3.new(data.impulseDir[1], data.impulseDir[2], data.impulseDir[3]).Unit
			end
			local cf = CFrame.lookAt(panel.Position, panel.Position + dir)
			burstConfigEmit(self._sparks :: ParticleEmitter, VFXConfig.panelSparks, cf)
		end)
	end

	local dmgEv = ReplicatedStorage:FindFirstChild("DamageBroadcast") :: RemoteEvent?
	if dmgEv then
		self._damageConn = dmgEv.OnClientEvent:Connect(function(data: any)
			if typeof(data) ~= "table" then return end
			if data.panelName ~= "Windshield" then return end
			if not data.destroyed then return end

			local veh = workspace:FindFirstChild(data.vehicleName)
			if not veh then return end
			local panels = veh:FindFirstChild("BodyPanels")
			if not panels then return end
			local ws = panels:FindFirstChild("Windshield")
			if not ws or not ws:IsA("BasePart") then return end
			if self:_shouldCull(ws.Position) then return end

			local look = veh.PrimaryPart and veh.PrimaryPart.CFrame.LookVector or Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(ws.Position + look * 0.5, ws.Position + look * 2)
			burstConfigEmit(self._glass :: ParticleEmitter, VFXConfig.windshieldShatter, cf)
		end)
	end
end

function VFXController:update(_dt: number, ctx: DriveContext)
	if not self._active or not self._cfg then return end

	local slip = ctx.lateralSlipFraction
	local smokeCfg = VFXConfig.tireSmoke
	local t = if slip > smokeCfg.slipThreshold
		then math.clamp((slip - smokeCfg.slipThreshold) / (1 - smokeCfg.slipThreshold), 0, 1)
		else 0

	local rate = smokeCfg.rateMin + (smokeCfg.rateMax - smokeCfg.rateMin) * t
	for _, pe in { self._smokeL, self._smokeR } do
		if pe and pe.Parent then
			pe.Rate = rate * (ctx.speed > 3 and 1 or 0)
		end
	end

	local maxSpd = math.max(ctx.effectiveMaxSpeed, 1)
	local spdFrac = ctx.speed / maxSpd
	local startFrac = self._profile.speedLineStartFrac
	local lineIntensity = 0
	if spdFrac >= startFrac then
		local u = (spdFrac - startFrac) / (1 - startFrac)
		lineIntensity = u * u
	end
	local opacity = lineIntensity * VFXConfig.speedLines.maxOpacity
	for _, f in self._streaks do
		f.BackgroundTransparency = 1 - opacity
	end
end

function VFXController:destroy()
	self._active = false

	if self._panelConn then
		self._panelConn:Disconnect()
		self._panelConn = nil
	end
	if self._damageConn then
		self._damageConn:Disconnect()
		self._damageConn = nil
	end

	if self._smokeL then self._smokeL:Destroy(); self._smokeL = nil end
	if self._smokeR then self._smokeR:Destroy(); self._smokeR = nil end
	if self._sparks then
		local h = self._sparks.Parent
		self._sparks:Destroy()
		if h then h:Destroy() end
		self._sparks = nil
	end
	if self._glass then
		local h = self._glass.Parent
		self._glass:Destroy()
		if h then h:Destroy() end
		self._glass = nil
	end

	self:_tearDownSpeedLines()
	self._cfg = nil
end

return VFXController
