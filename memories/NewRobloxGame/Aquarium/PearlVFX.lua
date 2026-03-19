--[[
	PearlVFX.lua — StarterPlayerScripts or ReplicatedStorage (ModuleScript)
	Pearl sparkle particle effects for aquarium creatures.
	Call PearlVFX.attach(creaturePart) to add sparkle particles.
	Call PearlVFX.burst(position) for pearl collection burst.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game.Workspace

local PearlVFX = {}

----------------------------------------------------------------------
-- SPARKLE PARTICLES (attached to creature parts producing pearls)
----------------------------------------------------------------------
local SPARKLE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 180)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 200)),
})

local SPARKLE_SIZE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.2, 0.3),
	NumberSequenceKeypoint.new(0.8, 0.2),
	NumberSequenceKeypoint.new(1, 0),
})

local SPARKLE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.2),
	NumberSequenceKeypoint.new(0.7, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})

function PearlVFX.attach(parentPart, pearlRate)
	if not parentPart then return nil end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PearlSparkle"
	emitter.Color = SPARKLE_COLOR
	emitter.Size = SPARKLE_SIZE
	emitter.Transparency = SPARKLE_TRANSPARENCY
	emitter.Texture = "rbxassetid://6490035152" -- default star particle
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0.3
	emitter.Lifetime = NumberRange.new(1.2, 2.0)
	emitter.Rate = math.clamp((pearlRate or 1) * 2, 1, 30)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Drag = 2
	emitter.Parent = parentPart

	return emitter
end

function PearlVFX.updateRate(emitter, pearlRate)
	if emitter and emitter.Parent then
		emitter.Rate = math.clamp((pearlRate or 1) * 2, 1, 30)
	end
end

function PearlVFX.detach(parentPart)
	if not parentPart then return end
	local emitter = parentPart:FindFirstChild("PearlSparkle")
	if emitter then emitter:Destroy() end
end

----------------------------------------------------------------------
-- PEARL BURST (played when collecting pearls at the collection point)
----------------------------------------------------------------------
function PearlVFX.burst(position, pearlCount)
	local count = math.clamp(pearlCount or 5, 3, 20)

	for i = 1, count do
		local pearl = Instance.new("Part")
		pearl.Name = "PearlBurst"
		pearl.Shape = Enum.PartType.Ball
		pearl.Size = Vector3.new(0.6, 0.6, 0.6)
		pearl.Position = position + Vector3.new(0, 1, 0)
		pearl.Color = Color3.fromRGB(255, 245, 220)
		pearl.Material = Enum.Material.Neon
		pearl.Anchored = true
		pearl.CanCollide = false
		pearl.CastShadow = false
		pearl.Parent = Workspace

		local angle = (i / count) * math.pi * 2
		local radius = 3 + math.random() * 2
		local height = 2 + math.random() * 3
		local target = position + Vector3.new(
			math.cos(angle) * radius,
			height,
			math.sin(angle) * radius
		)

		local tween = TweenService:Create(pearl,
			TweenInfo.new(0.8 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = target,
				Transparency = 1,
				Size = Vector3.new(0.15, 0.15, 0.15),
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			pearl:Destroy()
		end)
	end

	-- Central glow flash
	local glow = Instance.new("Part")
	glow.Name = "PearlGlow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(2, 2, 2)
	glow.Position = position + Vector3.new(0, 1.5, 0)
	glow.Color = Color3.fromRGB(255, 240, 200)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.3
	glow.Anchored = true
	glow.CanCollide = false
	glow.CastShadow = false
	glow.Parent = Workspace

	local glowTween = TweenService:Create(glow,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(5, 5, 5),
			Transparency = 1,
		}
	)
	glowTween:Play()
	glowTween.Completed:Connect(function()
		glow:Destroy()
	end)
end

----------------------------------------------------------------------
-- FLOATING PEARL INDICATOR (+N text that floats up)
----------------------------------------------------------------------
function PearlVFX.floatingText(position, text)
	local anchor = Instance.new("Part")
	anchor.Name = "PearlTextAnchor"
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 240, 180)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(180, 140, 40)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local floatTween = TweenService:Create(anchor,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = anchor.Position + Vector3.new(0, 5, 0) }
	)
	floatTween:Play()

	task.delay(1.2, function()
		local fadeTween = TweenService:Create(label,
			TweenInfo.new(0.4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			anchor:Destroy()
		end)
	end)
end

return PearlVFX
