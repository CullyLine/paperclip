--!strict
--[[
	ReplicatedFirst loading overlay: title, rotating tips, progress, fade-out.
	Requires ReplicatedFirst entry in default.project.json.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local LoadingTipsConfig = require(DAC:WaitForChild("Config"):WaitForChild("LoadingTipsConfig"))
local EasterEggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EasterEggConfig"))

local rawTips = LoadingTipsConfig.Tips
local tips: { string } = if #rawTips > 0 then rawTips else { "Loading..." }

local gui = Instance.new("ScreenGui")
gui.Name = "DACLoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100_000
gui.ResetOnSpawn = false
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = Color3.fromRGB(14, 14, 32)
root.BorderSizePixel = 0
root.Parent = gui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 28, 64)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 24)),
})
gradient.Rotation = 90
gradient.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0.92, 0, 0, 56)
title.Position = UDim2.new(0.5, 0, 0.28, 0)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.Text = 'Drive a Car Simulator'
title.Parent = root

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MaxTextSize = 44
titleConstraint.MinTextSize = 18
titleConstraint.Parent = title

local splashIds: { string } = {}
for _, id in EasterEggConfig.LoadingScreenImages do
	if type(id) == "string" and string.find(id, "rbxassetid://%d+") and id ~= "rbxassetid://0" then
		table.insert(splashIds, id)
	end
end
if #splashIds > 0 then
	local splash = Instance.new("ImageLabel")
	splash.Name = "Splash"
	splash.BackgroundTransparency = 1
	splash.Size = UDim2.new(0.42, 0, 0, 140)
	splash.Position = UDim2.new(0.5, 0, 0.14, 0)
	splash.AnchorPoint = Vector2.new(0.5, 0)
	splash.Image = splashIds[math.random(1, #splashIds)]
	splash.ScaleType = Enum.ScaleType.Fit
	splash.ImageTransparency = 0.08
	splash.Parent = root
	local splashRound = Instance.new("UICorner")
	splashRound.CornerRadius = UDim.new(0, 12)
	splashRound.Parent = splash
end

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.Size = UDim2.new(0.88, 0, 0, 80)
tip.Position = UDim2.new(0.5, 0, 0.52, 0)
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.Gotham
tip.TextSize = 18
tip.TextColor3 = Color3.fromRGB(200, 210, 255)
tip.TextWrapped = true
tip.Text = tips[1]
tip.Parent = root

local barBack = Instance.new("Frame")
barBack.Name = "ProgressBack"
barBack.Size = UDim2.new(0.72, 0, 0, 14)
barBack.Position = UDim2.new(0.5, 0, 0.68, 0)
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.BackgroundColor3 = Color3.fromRGB(40, 44, 80)
barBack.BorderSizePixel = 0
barBack.Parent = root

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0.08, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 8)
fillCorner.Parent = barFill

local pctLabel = Instance.new("TextLabel")
pctLabel.Name = "Pct"
pctLabel.Size = UDim2.new(0.3, 0, 0, 22)
pctLabel.Position = UDim2.new(0.5, 0, 0.72, 20)
pctLabel.AnchorPoint = Vector2.new(0.5, 0)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.GothamBold
pctLabel.TextSize = 16
pctLabel.TextColor3 = Color3.fromRGB(180, 190, 220)
pctLabel.Text = "0%"
pctLabel.Parent = root

local tipIndex = 1
task.spawn(function()
	while gui.Parent do
		task.wait(4)
		tipIndex = (tipIndex % #tips) + 1
		tip.Text = tips[tipIndex]
	end
end)

local targetProgress = 0.12
local function setBar(alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	barFill.Size = UDim2.new(alpha, 0, 1, 0)
	pctLabel.Text = `{math.floor(alpha * 100)}%`
end

setBar(0.08)

task.spawn(function()
	for _ = 1, 40 do
		task.wait(0.12)
		targetProgress = math.min(0.92, targetProgress + math.random() * 0.04)
		setBar(targetProgress)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
targetProgress = math.max(targetProgress, 0.55)
setBar(targetProgress)

local preloadList: { Instance } = {}
for _, d in DAC:GetDescendants() do
	if d:IsA("Decal") or d:IsA("Texture") then
		table.insert(preloadList, d)
	end
end
if #preloadList > 0 then
	pcall(function()
		ContentProvider:PreloadAsync(preloadList)
	end)
end

targetProgress = 1
setBar(1)
task.wait(0.35)

local fade = TweenService:Create(
	root,
	TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{ BackgroundTransparency = 1 }
)
fade:Play()
for _, d in root:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") and d ~= root then
		TweenService:Create(d, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	end
end
gradient:Destroy()
task.wait(0.58)
gui:Destroy()
