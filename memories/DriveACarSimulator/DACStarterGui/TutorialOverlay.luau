--!strict
--[[
	Semi-transparent tutorial overlay: prompt text, optional UI highlight, skip.
	UI is pre-built in StarterGui.DACTutorialOverlay; this script only wires behavior.
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
	if highlightStroke then highlightStroke:Destroy(); highlightStroke = nil end
	if arrowLabel then
		if arrowTween then arrowTween:Cancel(); arrowTween = nil end
		arrowLabel:Destroy(); arrowLabel = nil
	end
	highlighted = nil
end

local function findTarget(name: string?): GuiObject?
	if type(name) ~= "string" or name == "" then return nil end
	for _, inst in playerGui:GetDescendants() do
		if inst:IsA("GuiObject") and inst.Name == name then return inst :: GuiObject end
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
	TweenService:Create(s, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6 }):Play()

	local arrow = Instance.new("TextLabel")
	arrow.Name = "TutorialArrow"
	arrow.Size = UDim2.new(0, 30, 0, 30)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 28
	arrow.TextColor3 = Color3.fromRGB(255, 213, 79)
	arrow.Text = "\u{25BC}"
	arrow.ZIndex = 10
	arrow.Parent = root
	arrowLabel = arrow

	task.defer(function()
		if not arrow.Parent or not target.Parent then return end
		local pos = target.AbsolutePosition
		local sz = target.AbsoluteSize
		local cx = pos.X + sz.X / 2 - 15
		local baseY = pos.Y - 34
		arrow.Position = UDim2.new(0, cx, 0, baseY)
		local bob = TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, cx, 0, baseY - 8) })
		bob:Play()
		arrowTween = bob
	end)
end

local function layoutBubble(target: GuiObject?)
	task.defer(function()
		if target then
			local pos = target.AbsolutePosition
			local sz = target.AbsoluteSize
			bubble.AnchorPoint = Vector2.new(0.5, 1)
			bubble.Position = UDim2.new(0, pos.X + sz.X / 2, 0, pos.Y - 12)
		else
			bubble.AnchorPoint = Vector2.new(0.5, 0.5)
			bubble.Position = UDim2.new(0.5, 0, 0.42, 0)
		end
	end)
end

local function animateBubbleIn()
	bubbleScale.Scale = 0
	local over = TweenService:Create(bubbleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 })
	over:Play()
	over.Completed:Wait()
	TweenService:Create(bubbleScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
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
		local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 3); pc.Parent = piece
		local endY = math.random(105, 130) / 100
		local drift = (math.random() - 0.5) * 0.15
		local duration = 1.2 + math.random() * 1.0
		local d = math.random() * 0.4
		task.delay(d, function()
			TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(startX + drift, 0, endY, 0),
				Rotation = math.random(180, 720),
				BackgroundTransparency = 0.6,
			}):Play()
		end)
	end
	task.delay(3, function() if container.Parent then container:Destroy() end end)
end

local function show(payload: any)
	if type(payload) ~= "table" then return end
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
	if target then applyHighlight(target); layoutBubble(target) else layoutBubble(nil) end
	if done then
		titleLabel.Text = if type(payload.title) == "string" and payload.title ~= "" then payload.title else "Tutorial Complete!"
		bodyLabel.Text = if type(payload.body) == "string" and payload.body ~= "" then payload.body else "You're ready to hit the road!"
		SoundFacade.playOneShot("tutorial_complete")
		skipBtn.Visible = false
		spawnConfetti()
		task.spawn(animateBubbleIn)
		task.delay(4, function()
			if screenGui and screenGui.Parent then screenGui.Enabled = false end
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
	screenGui = playerGui:WaitForChild("DACTutorialOverlay") :: ScreenGui
	root = screenGui:WaitForChild("Root") :: Frame
	dimmer = root:WaitForChild("Dimmer") :: Frame
	bubble = root:WaitForChild("Bubble") :: Frame
	bubbleScale = bubble:WaitForChild("UIScale") :: UIScale
	titleLabel = bubble:WaitForChild("Title") :: TextLabel
	bodyLabel = bubble:WaitForChild("Body") :: TextLabel
	skipBtn = root:WaitForChild("SkipTutorial") :: TextButton

	skipBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		Remotes.getEvent("TutorialSkip"):FireServer()
	end)

	Remotes.getEvent("TutorialStep").OnClientEvent:Connect(function(payload: any)
		show(payload)
	end)
end

return TutorialOverlay
