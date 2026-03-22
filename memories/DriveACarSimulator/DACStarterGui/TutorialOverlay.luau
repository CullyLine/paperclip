--!strict
--[[
	Semi-transparent tutorial overlay: prompt text, optional UI highlight, skip.
	Each step pops in with elastic bubble + sound. Highlight arrows bob.
	Completion triggers confetti + celebration sound.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local TutorialOverlay = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local root: Frame
local dimmer: Frame
local bubble: Frame
local bubbleScale: UIScale
local titleLabel: TextLabel
local bodyLabel: TextLabel
local skipBtn: TextButton
local highlightStroke: UIStroke?
local highlighted: GuiObject?
local arrowLabel: TextLabel?
local arrowTween: Tween?

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 213, 79),
	Color3.fromRGB(120, 160, 255),
	Color3.fromRGB(255, 100, 120),
	Color3.fromRGB(100, 255, 160),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(200, 120, 255),
}

local function clearHighlight()
	if highlightStroke then
		highlightStroke:Destroy()
		highlightStroke = nil
	end
	if arrowLabel then
		if arrowTween then
			arrowTween:Cancel()
			arrowTween = nil
		end
		arrowLabel:Destroy()
		arrowLabel = nil
	end
	highlighted = nil
end

local function findTarget(name: string?): GuiObject?
	if type(name) ~= "string" or name == "" then
		return nil
	end
	for _, inst in playerGui:GetDescendants() do
		if inst:IsA("GuiObject") and inst.Name == name then
			return inst :: GuiObject
		end
	end
	return nil
end

local function applyHighlight(target: GuiObject)
	clearHighlight()
	highlighted = target

	local s = Instance.new("UIStroke")
	s.Name = "TutorialHighlightStroke"
	s.Color = Color3.fromRGB(255, 213, 79)
	s.Thickness = 4
	s.Parent = target
	highlightStroke = s

	-- Pulse stroke thickness
	TweenService:Create(
		s,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 6 }
	):Play()

	-- Bobbing arrow above the target
	local arrow = Instance.new("TextLabel")
	arrow.Name = "TutorialArrow"
	arrow.Size = UDim2.new(0, 30, 0, 30)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 28
	arrow.TextColor3 = Color3.fromRGB(255, 213, 79)
	arrow.Text = "\xE2\x96\xBC" -- ▼
	arrow.ZIndex = 10
	arrow.Parent = root
	arrowLabel = arrow

	task.defer(function()
		if not arrow.Parent or not target.Parent then
			return
		end
		local pos = target.AbsolutePosition
		local sz = target.AbsoluteSize
		local cx = pos.X + sz.X / 2 - 15
		local baseY = pos.Y - 34
		arrow.Position = UDim2.new(0, cx, 0, baseY)

		local bob = TweenService:Create(
			arrow,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0, cx, 0, baseY - 8) }
		)
		bob:Play()
		arrowTween = bob
	end)
end

local function layoutBubble(target: GuiObject?)
	task.defer(function()
		local pad = 12
		if target then
			local pos = target.AbsolutePosition
			local sz = target.AbsoluteSize
			bubble.AnchorPoint = Vector2.new(0.5, 1)
			bubble.Position = UDim2.new(0, pos.X + sz.X / 2, 0, pos.Y - pad)
		else
			bubble.AnchorPoint = Vector2.new(0.5, 0.5)
			bubble.Position = UDim2.new(0.5, 0, 0.42, 0)
		end
	end)
end

local function animateBubbleIn()
	bubbleScale.Scale = 0
	local over = TweenService:Create(
		bubbleScale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.05 }
	)
	over:Play()
	over.Completed:Wait()
	TweenService:Create(
		bubbleScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	):Play()
end

local function spawnConfetti()
	local container = Instance.new("Frame")
	container.Name = "Confetti"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 5
	container.Parent = root

	for _ = 1, 40 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.new(0, math.random(6, 12), 0, math.random(4, 10))
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		piece.Rotation = math.random(0, 360)
		piece.BorderSizePixel = 0
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local startX = math.random(5, 95) / 100
		piece.Position = UDim2.new(startX, 0, -0.05, 0)
		piece.ZIndex = 5
		piece.Parent = container

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 3)
		pc.Parent = piece

		local endY = math.random(105, 130) / 100
		local drift = (math.random() - 0.5) * 0.15
		local duration = 1.2 + math.random() * 1.0
		local delay = math.random() * 0.4

		task.delay(delay, function()
			TweenService:Create(
				piece,
				TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.new(startX + drift, 0, endY, 0),
					Rotation = math.random(180, 720),
					BackgroundTransparency = 0.6,
				}
			):Play()
		end)
	end

	task.delay(3, function()
		if container.Parent then
			container:Destroy()
		end
	end)
end

local function show(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local done = payload.done == true
	if done and (payload.step == 0 or payload.step == nil) then
		screenGui.Enabled = false
		clearHighlight()
		return
	end

	screenGui.Enabled = true
	clearHighlight()

	local targetName = payload.targetName
	local target = findTarget(targetName)
	if target then
		applyHighlight(target)
		layoutBubble(target)
	else
		layoutBubble(nil)
	end

	if done then
		titleLabel.Text = if type(payload.title) == "string" and payload.title ~= ""
			then payload.title
			else "Tutorial Complete!"
		bodyLabel.Text = if type(payload.body) == "string" and payload.body ~= ""
			then payload.body
			else "You're ready to hit the road!"

		SoundFacade.playOneShot("tutorial_complete")
		skipBtn.Visible = false
		spawnConfetti()
		task.spawn(animateBubbleIn)

		task.delay(4, function()
			if screenGui and screenGui.Parent then
				screenGui.Enabled = false
			end
			clearHighlight()
		end)
	else
		titleLabel.Text = type(payload.title) == "string" and payload.title or ""
		bodyLabel.Text = type(payload.body) == "string" and payload.body or ""

		SoundFacade.playOneShot("tutorial_step")
		skipBtn.Visible = true
		task.spawn(animateBubbleIn)
	end
end

function TutorialOverlay.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DACTutorialOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 90
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Parent = screenGui

	dimmer = Instance.new("Frame")
	dimmer.Name = "Dimmer"
	dimmer.Size = UDim2.new(1, 0, 1, 0)
	dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
	dimmer.BackgroundTransparency = 0.45
	dimmer.BorderSizePixel = 0
	dimmer.Active = false
	dimmer.Parent = root

	bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(0, 380, 0, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.BackgroundColor3 = Color3.fromRGB(28, 28, 52)
	bubble.BorderSizePixel = 0
	bubble.Active = false
	bubble.Parent = root

	bubbleScale = Instance.new("UIScale")
	bubbleScale.Scale = 1
	bubbleScale.Parent = bubble

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 14)
	bc.Parent = bubble

	local bstroke = Instance.new("UIStroke")
	bstroke.Color = Color3.fromRGB(120, 160, 255)
	bstroke.Thickness = 2
	bstroke.Parent = bubble

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = bubble

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = bubble

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.fromRGB(255, 213, 79)
	titleLabel.TextWrapped = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = bubble

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, 0, 0, 0)
	bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 16
	bodyLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.Parent = bubble

	skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipTutorial"
	skipBtn.Size = UDim2.new(0, 120, 0, 36)
	skipBtn.Position = UDim2.new(1, -132, 1, -48)
	skipBtn.AnchorPoint = Vector2.new(0, 0)
	skipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	skipBtn.Text = "Skip Tutorial"
	skipBtn.TextColor3 = Color3.new(1, 1, 1)
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 14
	skipBtn.Parent = root
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = skipBtn
	skipBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		Remotes.getEvent("TutorialSkip"):FireServer()
	end)

	bubble.ZIndex = 2
	skipBtn.ZIndex = 2
	dimmer.ZIndex = 1

	screenGui.Parent = playerGui

	Remotes.getEvent("TutorialStep").OnClientEvent:Connect(function(payload: any)
		show(payload)
	end)
end

return TutorialOverlay
