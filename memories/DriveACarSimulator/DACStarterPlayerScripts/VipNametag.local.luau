--!strict
--[[
	VIP overhead glow: BillboardGui above head for players with DAC_VipPass attribute.
	Enhanced with continuous gold shimmer pulse, gradient background, and crown icon
	entrance animation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local GOLD_A = Color3.fromRGB(255, 200, 50)
local GOLD_B = Color3.fromRGB(255, 235, 140)
local PULSE_SPEED = 2.4

local activeConnections: { [BillboardGui]: RBXScriptConnection } = {}

local function cleanup(bb: BillboardGui)
	local conn = activeConnections[bb]
	if conn then
		conn:Disconnect()
		activeConnections[bb] = nil
	end
end

local function attachVipGlow(character: Model, show: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local existing = root:FindFirstChild("DAC_VipNametag") :: BillboardGui?
	if existing then
		cleanup(existing)
		existing:Destroy()
	end

	if not show then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "DAC_VipNametag"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(160, 66)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = root

	-- Background panel with gradient
	local bg = Instance.new("Frame")
	bg.Name = "VipBg"
	bg.Size = UDim2.new(0.85, 0, 0.82, 0)
	bg.Position = UDim2.new(0.075, 0, 0.09, 0)
	bg.BackgroundColor3 = Color3.fromRGB(40, 25, 5)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bg

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 55, 10)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 35, 5)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 55, 10)),
	})
	bgGrad.Rotation = 0
	bgGrad.Parent = bg

	-- Crown icon (text emoji, scales in on appear)
	local crown = Instance.new("TextLabel")
	crown.Name = "Crown"
	crown.Size = UDim2.fromOffset(22, 22)
	crown.Position = UDim2.new(0, 8, 0.5, -11)
	crown.BackgroundTransparency = 1
	crown.Text = "👑"
	crown.TextSize = 16
	crown.Font = Enum.Font.GothamBold
	crown.Parent = bg

	local crownScale = Instance.new("UIScale")
	crownScale.Scale = 0
	crownScale.Parent = crown

	-- VIP label
	local label = Instance.new("TextLabel")
	label.Name = "VipTitle"
	label.Size = UDim2.new(1, -36, 0, 22)
	label.Position = UDim2.new(0, 32, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = "VIP"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Parent = bg

	local flavor = Instance.new("TextLabel")
	flavor.Name = "Flavor"
	flavor.Size = UDim2.new(1, -10, 0, 14)
	flavor.Position = UDim2.new(0.5, 0, 1, -4)
	flavor.AnchorPoint = Vector2.new(0.5, 1)
	flavor.BackgroundTransparency = 1
	flavor.Font = Enum.Font.Gotham
	flavor.TextSize = 10
	flavor.TextColor3 = Color3.fromRGB(255, 235, 170)
	flavor.TextWrapped = true
	flavor.TextTransparency = 0
	flavor.Parent = bg
	if #MicrocopyConfig.VIPNametagFlavor > 0 then
		local fIdx = math.random(1, #MicrocopyConfig.VIPNametagFlavor)
		flavor.Text = MicrocopyConfig.VIPNametagFlavor[fIdx]
		task.spawn(function()
			while bb.Parent and #MicrocopyConfig.VIPNametagFlavor > 0 do
				task.wait(8)
				if not bb.Parent then
					break
				end
				local nextIdx = (fIdx % #MicrocopyConfig.VIPNametagFlavor) + 1
				local out = TweenService:Create(flavor, TweenInfo.new(0.4), { TextTransparency = 1 })
				out:Play()
				out.Completed:Wait()
				if not bb.Parent then
					break
				end
				fIdx = nextIdx
				flavor.Text = MicrocopyConfig.VIPNametagFlavor[fIdx]
				local inn = TweenService:Create(flavor, TweenInfo.new(0.4), { TextTransparency = 0 })
				inn:Play()
			end
		end)
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "MainStroke"
	stroke.Thickness = 2
	stroke.Color = GOLD_A
	stroke.Parent = label

	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Thickness = 6
	glow.Color = Color3.fromRGB(255, 200, 80)
	glow.Transparency = 0.65
	glow.Parent = label

	-- Pop-in entrance animation for the whole billboard
	local bbScale = Instance.new("UIScale")
	bbScale.Scale = 0
	bbScale.Parent = bb

	local popOut = TweenService:Create(bbScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.08 }
	)
	popOut:Play()
	popOut.Completed:Connect(function()
		TweenService:Create(bbScale,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)

	-- Crown entrance: delayed scale-in with bounce
	task.delay(0.2, function()
		if not crownScale.Parent then return end
		local crownPop = TweenService:Create(crownScale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.15 }
		)
		crownPop:Play()
		crownPop.Completed:Connect(function()
			if crownScale.Parent then
				TweenService:Create(crownScale,
					TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end)
	end)

	-- Continuous gold shimmer pulse + gradient rotation
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		if not bb.Parent then
			cleanup(bb)
			return
		end
		local elapsed = os.clock() - t0
		local alpha = (math.sin(elapsed * PULSE_SPEED) + 1) * 0.5
		stroke.Color = GOLD_A:Lerp(GOLD_B, alpha)
		glow.Transparency = 0.55 + 0.2 * alpha

		bgGrad.Rotation = (elapsed * 25) % 360
	end)
	activeConnections[bb] = conn
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
