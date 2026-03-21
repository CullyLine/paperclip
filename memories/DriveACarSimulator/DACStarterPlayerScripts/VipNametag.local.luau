--!strict
--[[
	VIP overhead glow: BillboardGui above head for players with DAC_VipPass attribute.
]]

local Players = game:GetService("Players")

local function attachVipGlow(character: Model, show: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local existing = root:FindFirstChild("DAC_VipNametag")
	if existing then
		existing:Destroy()
	end
	if not show then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "DAC_VipNametag"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(140, 48)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "VIP"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 180, 40)
	stroke.Parent = label

	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Thickness = 6
	glow.Color = Color3.fromRGB(255, 200, 80)
	glow.Transparency = 0.65
	glow.Parent = label
end

local function hookPlayer(player: Player)
	local function refresh()
		local char = player.Character
		if not char then
			return
		end
		local vip = player:GetAttribute("DAC_VipPass") == true
		attachVipGlow(char, vip)
	end

	player.CharacterAdded:Connect(refresh)
	player:GetAttributeChangedSignal("DAC_VipPass"):Connect(refresh)
	if player.Character then
		refresh()
	end
end

for _, p in Players:GetPlayers() do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)
