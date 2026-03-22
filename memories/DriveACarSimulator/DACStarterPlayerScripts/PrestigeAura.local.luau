--!strict
--[[
	Persistent prestige glow from DAC_PrestigeTier (server-synced rebirth band).
	Visible on all players; complements VIP / title nametags.
]]

local Players = game:GetService("Players")

local TIER_COLORS: { Color3 } = {
	Color3.fromRGB(180, 110, 60),
	Color3.fromRGB(200, 210, 225),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(190, 245, 255),
	Color3.fromRGB(255, 120, 220),
}

local function tierFromAttribute(v: any): number
	if type(v) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(v), 0, 5)
end

local function clearAura(root: BasePart)
	local l = root:FindFirstChild("DAC_PrestigeLight")
	if l then
		l:Destroy()
	end
	local a = root:FindFirstChild("DAC_PrestigeAttach")
	if a then
		a:Destroy()
	end
end

local function attachAura(character: Model, tier: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	clearAura(root)
	if tier <= 0 then
		return
	end

	local col = TIER_COLORS[math.clamp(tier, 1, #TIER_COLORS)]

	local light = Instance.new("PointLight")
	light.Name = "DAC_PrestigeLight"
	light.Color = col
	light.Range = 9 + tier * 2.2
	light.Brightness = 0.45 + tier * 0.38
	light.Shadows = false
	light.Parent = root

	local att = Instance.new("Attachment")
	att.Name = "DAC_PrestigeAttach"
	att.Position = Vector3.new(0, 1.2, 0)
	att.Parent = root

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "PrestigeMotes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(col)
	motes.Lifetime = NumberRange.new(0.4, 1.0)
	motes.Speed = NumberRange.new(0.2, 2.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Size = NumberSequence.new(0.08, 0.35)
	motes.Transparency = NumberSequence.new(0.3, 1)
	motes.LightEmission = 0.7
	motes.Rate = if tier >= 5 then 5 elseif tier >= 3 then 3 else 2
	motes.Parent = att
end

local function hookPlayer(target: Player)
	local function refresh()
		local char = target.Character
		if not char then
			return
		end
		local t = tierFromAttribute(target:GetAttribute("DAC_PrestigeTier"))
		attachAura(char, t)
	end

	target.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)
	target:GetAttributeChangedSignal("DAC_PrestigeTier"):Connect(refresh)
	if target.Character then
		refresh()
	end
end

for _, p in Players:GetPlayers() do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)
