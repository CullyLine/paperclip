--!strict
--[[
	Shows DAC_PlayerTitle attribute above characters (e.g. Early Driver).
	Prestige animations: pop-in UIScale, spark particles, tiered rarity styling,
	smooth transition on title change.

	Rarity is read from DAC_TitleRarity attribute (common | rare | epic | legendary).
	Falls back to "common" if unset.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RARITY_STYLES: { [string]: {
	textColor: Color3,
	strokeColor: Color3,
	strokeThickness: number,
	glowColor: Color3?,
	glowThickness: number?,
	glowTransparency: number?,
	animateStroke: boolean,
	sparkColor: Color3,
	sparkCount: number,
} } = {
	common = {
		textColor = Color3.fromRGB(255, 200, 80),
		strokeColor = Color3.fromRGB(120, 80, 20),
		strokeThickness = 1.5,
		animateStroke = false,
		sparkColor = Color3.fromRGB(255, 220, 150),
		sparkCount = 6,
	},
	rare = {
		textColor = Color3.fromRGB(100, 200, 255),
		strokeColor = Color3.fromRGB(40, 100, 170),
		strokeThickness = 1.8,
		glowColor = Color3.fromRGB(100, 180, 255),
		glowThickness = 4,
		glowTransparency = 0.6,
		animateStroke = false,
		sparkColor = Color3.fromRGB(120, 200, 255),
		sparkCount = 10,
	},
	epic = {
		textColor = Color3.fromRGB(200, 120, 255),
		strokeColor = Color3.fromRGB(100, 40, 160),
		strokeThickness = 2,
		glowColor = Color3.fromRGB(180, 100, 255),
		glowThickness = 5,
		glowTransparency = 0.45,
		animateStroke = true,
		sparkColor = Color3.fromRGB(200, 130, 255),
		sparkCount = 16,
	},
	legendary = {
		textColor = Color3.fromRGB(255, 215, 60),
		strokeColor = Color3.fromRGB(200, 130, 0),
		strokeThickness = 2.2,
		glowColor = Color3.fromRGB(255, 200, 50),
		glowThickness = 6,
		glowTransparency = 0.35,
		animateStroke = true,
		sparkColor = Color3.fromRGB(255, 230, 100),
		sparkCount = 22,
	},
}

local TitleNametag = {}

local activeStrokePulses: { [BillboardGui]: RBXScriptConnection } = {}

local function emitSparks(bb: BillboardGui, style: typeof(RARITY_STYLES.common))
	local adornee = bb.Adornee :: BasePart?
	if not adornee then
		return
	end

	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 2.35, 0)
	att.Parent = adornee

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(style.sparkColor, Color3.fromRGB(255, 255, 255))
	emitter.Lifetime = NumberRange.new(0.3, 0.55)
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(180, 80)
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.5, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0.9
	emitter.Parent = att
	emitter:Emit(style.sparkCount)

	task.delay(1.2, function()
		att:Destroy()
	end)
end

local function startStrokePulse(bb: BillboardGui, glow: UIStroke)
	if activeStrokePulses[bb] then
		activeStrokePulses[bb]:Disconnect()
	end

	local baseTransparency = glow.Transparency
	local minTransparency = math.max(baseTransparency - 0.2, 0)
	local maxTransparency = math.min(baseTransparency + 0.15, 1)
	local t0 = os.clock()

	local conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not bb.Parent then
			return
		end
		local elapsed = os.clock() - t0
		local alpha = (math.sin(elapsed * 3.2) + 1) * 0.5
		glow.Transparency = minTransparency + (maxTransparency - minTransparency) * alpha
	end)

	activeStrokePulses[bb] = conn
end

local function cleanupPulse(bb: BillboardGui)
	local conn = activeStrokePulses[bb]
	if conn then
		conn:Disconnect()
		activeStrokePulses[bb] = nil
	end
end

local function attachTitle(character: Model, titleText: string?, rarity: string?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local existing = root:FindFirstChild("DAC_TitleNametag") :: BillboardGui?
	if existing then
		cleanupPulse(existing)
		existing:Destroy()
	end

	if not titleText or titleText == "" then
		return
	end

	local rarityKey = if type(rarity) == "string" and RARITY_STYLES[string.lower(rarity)]
		then string.lower(rarity) else "common"
	local style = RARITY_STYLES[rarityKey]

	local bb = Instance.new("BillboardGui")
	bb.Name = "DAC_TitleNametag"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(200, 28)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.35, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = style.textColor
	label.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = style.strokeThickness
	stroke.Color = style.strokeColor
	stroke.Parent = label

	if rarityKey == "rare" or rarityKey == "epic" or rarityKey == "legendary" then
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.textColor),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, style.textColor),
		})
		grad.Rotation = 0
		grad.Parent = label
	end

	if style.glowColor then
		local glow = Instance.new("UIStroke")
		glow.Name = "Glow"
		glow.Thickness = style.glowThickness :: number
		glow.Color = style.glowColor :: Color3
		glow.Transparency = style.glowTransparency :: number
		glow.Parent = label

		if style.animateStroke then
			startStrokePulse(bb, glow)
		end
	end

	-- Pop-in scale animation: 0 -> 1.1 -> 1.0
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = bb

	local popOut = TweenService:Create(scale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.1 }
	)
	popOut:Play()
	popOut.Completed:Connect(function()
		TweenService:Create(scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)

	emitSparks(bb, style)
end

local function hookPlayer(target: Player)
	local function refresh()
		local char = target.Character
		if not char then
			return
		end
		local t = target:GetAttribute("DAC_PlayerTitle")
		local r = target:GetAttribute("DAC_TitleRarity")
		attachTitle(
			char,
			if type(t) == "string" then t else nil,
			if type(r) == "string" then r else nil
		)
	end

	target.CharacterAdded:Connect(refresh)
	target:GetAttributeChangedSignal("DAC_PlayerTitle"):Connect(refresh)
	target:GetAttributeChangedSignal("DAC_TitleRarity"):Connect(refresh)
	if target.Character then
		refresh()
	end
end

function TitleNametag.init()
	for _, p in Players:GetPlayers() do
		hookPlayer(p)
	end
	Players.PlayerAdded:Connect(hookPlayer)
end

return TitleNametag
