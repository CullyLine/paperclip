--[[
	PearlCounterUI.lua — StarterPlayerScripts (LocalScript)
	HUD element showing current pearl count and production rate.
	Listens to AquariumPearlUpdate from the server.
	Uses PearlVFX for collection burst effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game.Workspace

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local pearlUpdateEvent = ReplicatedStorage:WaitForChild("AquariumPearlUpdate")
local collectPearlsEvent = ReplicatedStorage:WaitForChild("AquariumCollectPearls")

----------------------------------------------------------------------
-- HUD SETUP
----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PearlCounterGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Background frame (top-right, rounded pill shape)
local frame = Instance.new("Frame")
frame.Name = "PearlFrame"
frame.Size = UDim2.new(0, 200, 0, 60)
frame.Position = UDim2.new(1, -220, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30, 50, 70)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 240, 200)
stroke.Thickness = 2
stroke.Transparency = 0.4
stroke.Parent = frame

-- Pearl icon (circle with glow)
local icon = Instance.new("Frame")
icon.Name = "PearlIcon"
icon.Size = UDim2.new(0, 36, 0, 36)
icon.Position = UDim2.new(0, 12, 0.5, -18)
icon.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
icon.BorderSizePixel = 0
icon.Parent = frame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = icon

local iconGlow = Instance.new("UIStroke")
iconGlow.Color = Color3.fromRGB(255, 220, 150)
iconGlow.Thickness = 2
iconGlow.Parent = icon

local iconLabel = Instance.new("TextLabel")
iconLabel.Size = UDim2.new(1, 0, 1, 0)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "P"
iconLabel.TextColor3 = Color3.fromRGB(180, 140, 60)
iconLabel.TextScaled = true
iconLabel.Font = Enum.Font.GothamBold
iconLabel.Parent = icon

-- Pearl count text
local countLabel = Instance.new("TextLabel")
countLabel.Name = "PearlCount"
countLabel.Size = UDim2.new(0, 120, 0, 30)
countLabel.Position = UDim2.new(0, 56, 0, 6)
countLabel.BackgroundTransparency = 1
countLabel.Text = "0"
countLabel.TextColor3 = Color3.fromRGB(255, 245, 220)
countLabel.TextStrokeTransparency = 0.5
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.TextScaled = true
countLabel.Font = Enum.Font.GothamBold
countLabel.Parent = frame

-- Production rate text
local rateLabel = Instance.new("TextLabel")
rateLabel.Name = "PearlRate"
rateLabel.Size = UDim2.new(0, 120, 0, 18)
rateLabel.Position = UDim2.new(0, 56, 0, 36)
rateLabel.BackgroundTransparency = 1
rateLabel.Text = "+0/min"
rateLabel.TextColor3 = Color3.fromRGB(180, 220, 200)
rateLabel.TextStrokeTransparency = 0.6
rateLabel.TextXAlignment = Enum.TextXAlignment.Left
rateLabel.TextScaled = true
rateLabel.Font = Enum.Font.Gotham
rateLabel.Parent = frame

----------------------------------------------------------------------
-- PEARL COLLECTION FEEDBACK
----------------------------------------------------------------------
local PearlVFX = require(ReplicatedStorage:WaitForChild("PearlVFX", 5))

local function animateCollect(collected)
	-- Pulse the counter frame
	local pulse = TweenService:Create(frame,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 220, 0, 66) }
	)
	pulse:Play()
	pulse.Completed:Connect(function()
		local restore = TweenService:Create(frame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 200, 0, 60) }
		)
		restore:Play()
	end)

	-- Flash count text gold
	countLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	task.delay(0.5, function()
		local restore = TweenService:Create(countLabel,
			TweenInfo.new(0.5),
			{ TextColor3 = Color3.fromRGB(255, 245, 220) }
		)
		restore:Play()
	end)

	-- VFX burst at pearl collection point
	if PearlVFX then
		local aquarium = Workspace:FindFirstChild("AquariumTemplate_Preview")
			or Workspace:FindFirstChild("AquariumTemplate")
		if aquarium then
			local pearlPoint = aquarium:FindFirstChild("PearlCollectionPoint")
			if pearlPoint then
				PearlVFX.burst(pearlPoint.Position, collected)
				PearlVFX.floatingText(pearlPoint.Position, "+" .. collected .. " Pearls")
			end
		end
	end
end

----------------------------------------------------------------------
-- COLLECT PEARLS (via ProximityPrompt on PearlCollectionPoint)
----------------------------------------------------------------------
local function bindCollectionPoint()
	local aquarium = Workspace:FindFirstChild("AquariumTemplate_Preview")
		or Workspace:FindFirstChild("AquariumTemplate")
	if not aquarium then return end

	local pearlPoint = aquarium:FindFirstChild("PearlCollectionPoint")
	if not pearlPoint then return end

	local prompt = pearlPoint:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function()
		collectPearlsEvent:FireServer()
	end)
end

task.spawn(function()
	task.wait(2)
	bindCollectionPoint()
end)

----------------------------------------------------------------------
-- HANDLE SERVER UPDATES
----------------------------------------------------------------------
pearlUpdateEvent.OnClientEvent:Connect(function(data)
	if data.collected and data.collected > 0 then
		animateCollect(data.collected)
	end

	countLabel.Text = tostring(data.pearls or 0)

	if data.rate then
		if data.rate > 0 then
			rateLabel.Text = string.format("+%.1f/min", data.rate)
		else
			rateLabel.Text = "+0/min"
		end
	end
end)

print("[PearlCounterUI] Initialized — pearl HUD active")
