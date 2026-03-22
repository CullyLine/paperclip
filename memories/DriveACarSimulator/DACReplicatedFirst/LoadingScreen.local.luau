--!strict
--[[
	ReplicatedFirst loading overlay: title with golden glow, rotating tips,
	shimmer progress bar with sparkles, FOMO headlines, fade-out.
	Requires ReplicatedFirst entry in default.project.json.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local LoadingTipsConfig = require(DAC:WaitForChild("Config"):WaitForChild("LoadingTipsConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local EasterEggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EasterEggConfig"))

local function soundIdFromAudioFolder(name: string): string?
	local audio = ReplicatedStorage:FindFirstChild("Audio")
	if not audio then
		return nil
	end
	local inst = audio:FindFirstChild(name)
	if inst and inst:IsA("Sound") then
		local id = inst.SoundId
		if id ~= "" and id ~= "rbxassetid://0" then
			return id
		end
	elseif inst and inst:IsA("StringValue") then
		local v = inst.Value
		if string.sub(v, 1, 11) == "rbxassetid:" or string.sub(v, 1, 7) == "http://" or string.sub(v, 1, 8) == "https://" then
			return v
		end
	end
	return nil
end

-- Fallbacks when `ReplicatedStorage.Audio` is not wired yet (replace via Audio folder in Studio).
local FALLBACK_AMBIENT = "rbxassetid://9040519073"
local FALLBACK_CHIME = "rbxassetid://4612375803"
local FALLBACK_READY = "rbxassetid://9125402735"

local function resolveSoundId(name: string, fallback: string): string
	return soundIdFromAudioFolder(name) or fallback
end

local rawTips = LoadingTipsConfig.Tips
local baseTips: { string } = if #rawTips > 0 then rawTips else { "Loading..." }

local tipsPool: { string } = {}
for _, t in baseTips do
	table.insert(tipsPool, t)
end
local tipIsPremium: { boolean } = {}
for _ = 1, #tipsPool do
	table.insert(tipIsPremium, false)
end
local okFlags, flags = pcall(function()
	return Remotes.getFunction("GetPassFlags"):InvokeServer()
end)
if okFlags and type(flags) == "table" then
	local anyPass = false
	for _, v in flags do
		if v == true then
			anyPass = true
			break
		end
	end
	if anyPass and #MicrocopyConfig.PremiumLoadingTips > 0 then
		for _, line in MicrocopyConfig.PremiumLoadingTips do
			table.insert(tipsPool, `[VIP] {line}`)
			table.insert(tipIsPremium, true)
		end
	end
end
local tips = tipsPool

local headlines: { string } = LoadingTipsConfig.Headlines or {}
local headlineText = if #headlines > 0 then headlines[math.random(1, #headlines)] else nil

local gui = Instance.new("ScreenGui")
gui.Name = "DACLoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100_000
gui.ResetOnSpawn = false
gui.Parent = playerGui

local audioRoot = Instance.new("Folder")
audioRoot.Name = "LoadingAudio"
audioRoot.Parent = gui

local function fadeAllLoadingAudio(duration: number)
	for _, s in audioRoot:GetChildren() do
		if s:IsA("Sound") then
			TweenService:Create(s, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 }):Play()
		end
	end
end

local function playOneShotLoading(name: string, fallbackId: string, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = resolveSoundId(name, fallbackId)
	s.Volume = volume
	s.Parent = audioRoot
	if s.SoundId == "rbxassetid://0" or s.SoundId == "" then
		s:Destroy()
		return
	end
	s:Play()
	s.Ended:Connect(function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local ambientBed = Instance.new("Sound")
ambientBed.Name = "AmbientBed"
ambientBed.SoundId = resolveSoundId("loading_ambient", FALLBACK_AMBIENT)
ambientBed.Looped = true
ambientBed.Volume = 0.12
ambientBed.RollOffMode = Enum.RollOffMode.InverseTapered
ambientBed.Parent = audioRoot
if ambientBed.SoundId ~= "rbxassetid://0" and ambientBed.SoundId ~= "" then
	ambientBed:Play()
end

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

-- Golden glow behind the title
local titleGlow = Instance.new("ImageLabel")
titleGlow.Name = "TitleGlow"
titleGlow.Size = UDim2.new(0.7, 0, 0, 120)
titleGlow.Position = UDim2.new(0.5, 0, 0.28, 0)
titleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
titleGlow.BackgroundTransparency = 1
titleGlow.Image = "rbxassetid://7669684740"
titleGlow.ImageColor3 = Color3.fromRGB(255, 200, 50)
titleGlow.ImageTransparency = 0.55
titleGlow.ScaleType = Enum.ScaleType.Stretch
titleGlow.ZIndex = 1
titleGlow.Parent = root

task.spawn(function()
	while gui.Parent do
		local pulseOut = TweenService:Create(titleGlow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			ImageTransparency = 0.3,
			Size = UDim2.new(0.78, 0, 0, 140),
		})
		pulseOut:Play()
		pulseOut.Completed:Wait()

		local pulseIn = TweenService:Create(titleGlow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			ImageTransparency = 0.6,
			Size = UDim2.new(0.7, 0, 0, 120),
		})
		pulseIn:Play()
		pulseIn.Completed:Wait()
	end
end)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0.92, 0, 0, 56)
title.Position = UDim2.new(0.5, 0, 0.28, 0)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.Text = "Drive a Car Simulator"
title.ZIndex = 2
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

-- "Today in DAC..." FOMO headline
if headlineText then
	local headlineLbl = Instance.new("TextLabel")
	headlineLbl.Name = "Headline"
	headlineLbl.Size = UDim2.new(0.88, 0, 0, 28)
	headlineLbl.Position = UDim2.new(0.5, 0, 0.42, 0)
	headlineLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	headlineLbl.BackgroundTransparency = 1
	headlineLbl.Font = Enum.Font.GothamBold
	headlineLbl.TextSize = 16
	headlineLbl.TextColor3 = Color3.fromRGB(255, 220, 80)
	headlineLbl.TextWrapped = true
	headlineLbl.Text = "Today in DAC: " .. headlineText
	headlineLbl.ZIndex = 3
	headlineLbl.Parent = root

	task.spawn(function()
		while gui.Parent do
			local blink = TweenService:Create(headlineLbl, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextTransparency = 0.35,
			})
			blink:Play()
			blink.Completed:Wait()
			local restore = TweenService:Create(headlineLbl, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextTransparency = 0,
			})
			restore:Play()
			restore.Completed:Wait()
			task.wait(2)
		end
	end)
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

local function applyTipStyle(idx: number)
	local isPrem = tipIsPremium[idx] == true
	tip.TextColor3 = if isPrem then Color3.fromRGB(255, 215, 100) else Color3.fromRGB(200, 210, 255)
end
applyTipStyle(1)

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
barFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 8)
fillCorner.Parent = barFill

-- Shimmer gradient on the loading bar fill
local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 40)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 255, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 255, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 40)),
})
barGradient.Parent = barFill

task.spawn(function()
	local offset = 0
	while gui.Parent do
		offset = (offset + RunService.RenderStepped:Wait() * 0.4) % 1
		barGradient.Offset = Vector2.new(offset, 0)
	end
end)

-- Sparkle particles around the loading bar
local sparkleContainer = Instance.new("Frame")
sparkleContainer.Name = "SparkleContainer"
sparkleContainer.Size = UDim2.new(0.76, 0, 0, 40)
sparkleContainer.Position = UDim2.new(0.5, 0, 0.68, 0)
sparkleContainer.AnchorPoint = Vector2.new(0.5, 0.5)
sparkleContainer.BackgroundTransparency = 1
sparkleContainer.ClipsDescendants = false
sparkleContainer.ZIndex = 5
sparkleContainer.Parent = root

task.spawn(function()
	while gui.Parent do
		local sparkle = Instance.new("Frame")
		sparkle.Size = UDim2.new(0, math.random(3, 6), 0, math.random(3, 6))
		sparkle.Position = UDim2.new(math.random() * 0.96 + 0.02, 0, math.random() < 0.5 and 0.1 or 0.9, 0)
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.BackgroundColor3 = Color3.fromRGB(255, 255, math.random(180, 255))
		sparkle.BorderSizePixel = 0
		sparkle.Rotation = math.random(0, 45)
		sparkle.ZIndex = 5
		sparkle.Parent = sparkleContainer

		local sparkleCorner = Instance.new("UICorner")
		sparkleCorner.CornerRadius = UDim.new(1, 0)
		sparkleCorner.Parent = sparkle

		local fadeDir = math.random() < 0.5 and -20 or 20
		local tw = TweenService:Create(sparkle, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			Position = sparkle.Position + UDim2.new(0, 0, 0, fadeDir),
			Size = UDim2.new(0, 1, 0, 1),
		})
		tw:Play()
		tw.Completed:Connect(function()
			sparkle:Destroy()
		end)

		task.wait(math.random() * 0.15 + 0.05)
	end
end)

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
		applyTipStyle(tipIndex)
	end
end)

local targetProgress = 0.12
local progressMilestonesHit: { [number]: boolean } = {}
local progressMarks = { 0.25, 0.5, 0.75 }

local function setBar(alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	barFill.Size = UDim2.new(alpha, 0, 1, 0)
	pctLabel.Text = `{math.floor(alpha * 100)}%`
	for _, mark in progressMarks do
		if alpha + 1e-4 >= mark and not progressMilestonesHit[mark] then
			progressMilestonesHit[mark] = true
			playOneShotLoading("loading_chime", FALLBACK_CHIME, 0.26)
		end
	end
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

playOneShotLoading("loading_ready", FALLBACK_READY, 0.42)

local fade = TweenService:Create(
	root,
	TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{ BackgroundTransparency = 1 }
)
fade:Play()
fadeAllLoadingAudio(0.55)
for _, d in root:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
	elseif d:IsA("ImageLabel") then
		TweenService:Create(d, TweenInfo.new(0.55), { ImageTransparency = 1 }):Play()
	elseif d:IsA("Frame") and d ~= root then
		TweenService:Create(d, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	end
end
gradient:Destroy()
task.wait(0.58)
gui:Destroy()
