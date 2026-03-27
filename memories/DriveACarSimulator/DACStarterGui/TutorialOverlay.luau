--!strict
--[[
	Semi-transparent tutorial overlay: prompt text, optional UI highlight, skip.
	UI is pre-built in StarterGui.DACTutorialOverlay; this script only wires behavior.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))

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
local skipConfirmRoot: Frame?
local savedSkipBtnVisible = false
local highlightStroke: UIStroke?
local highlighted: GuiObject?
local arrowLabel: TextLabel?
local arrowTween: Tween?
local highlightStrokeTween: Tween?

-- POLA-407: soft "waypoint" ping when onboarding advances (no compass HUD in this game).
local lastTutorialStepForObjectivePing: number? = nil
local lastObjectivePingClock = 0.0
local OBJECTIVE_PING_DEBOUNCE_SEC = 2.5

local DAC_TUTORIAL_SKIP_BACK_ACTION = "DAC_TutorialSkipConfirmBack"
local DAC_TUTORIAL_SKIP_BACK_PRIORITY = 5000

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 213, 79),
	Color3.fromRGB(120, 160, 255),
	Color3.fromRGB(255, 100, 120),
	Color3.fromRGB(100, 255, 160),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(200, 120, 255),
}

local bubbleInTweens: { Tween } = {}

local function cancelBubbleScaleTweens()
	for _, tw in bubbleInTweens do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(bubbleInTweens)
end

local function clearHighlight()
	if highlightStrokeTween then
		highlightStrokeTween:Cancel()
		highlightStrokeTween = nil
	end
	cancelBubbleScaleTweens()
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
	if ClientPerformanceProfile.allowsContinuousScreenMotion() then
		highlightStrokeTween = TweenService:Create(
			s,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 6 }
		)
		highlightStrokeTween:Play()
	else
		s.Thickness = 5
	end

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
		if ClientPerformanceProfile.allowsContinuousScreenMotion() then
			local bob = TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, cx, 0, baseY - 8) })
			bob:Play()
			arrowTween = bob
		end
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
	cancelBubbleScaleTweens()
	bubbleScale.Scale = 0
	local over = TweenService:Create(bubbleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 })
	table.insert(bubbleInTweens, over)
	over:Play()
	over.Completed:Wait()
	local settle = TweenService:Create(bubbleScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
	table.insert(bubbleInTweens, settle)
	settle:Play()
end

local function spawnConfetti()
	local n = math.max(0, math.floor(40 * ClientPerformanceProfile.uiJuiceStrength() + 0.5))
	if n <= 0 then
		return
	end
	local container = Instance.new("Frame")
	container.Name = "Confetti"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 5
	container.Parent = root
	for _ = 1, n do
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

local function closeSkipConfirm()
	local sc = skipConfirmRoot
	if sc and sc.Visible then
		sc.Visible = false
		skipBtn.Visible = savedSkipBtnVisible
	end
end

local function show(payload: any)
	if type(payload) ~= "table" then return end
	local done = payload.done == true
	if done and (payload.step == 0 or payload.step == nil) then
		closeSkipConfirm()
		screenGui.Enabled = false
		clearHighlight()
		return
	end
	screenGui.Enabled = true
	closeSkipConfirm()
	clearHighlight()
	local targetName = payload.targetName
	local target = findTarget(targetName)
	if target then applyHighlight(target); layoutBubble(target) else layoutBubble(nil) end
	if done then
		closeSkipConfirm()
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
		local stepNum = payload.step
		if type(stepNum) == "number" and stepNum >= 1 then
			local prev = lastTutorialStepForObjectivePing
			if
				prev ~= nil
				and stepNum ~= prev
				and (os.clock() - lastObjectivePingClock) >= OBJECTIVE_PING_DEBOUNCE_SEC
			then
				SoundFacade.playOneShot("objective_ping")
				lastObjectivePingClock = os.clock()
			end
			lastTutorialStepForObjectivePing = stepNum
		end
		skipBtn.Visible = true
		task.spawn(animateBubbleIn)
	end
end

function TutorialOverlay.init()
	screenGui = playerGui:WaitForChild("DACTutorialOverlay") :: ScreenGui
	screenGui.DisplayOrder = UILayerStack.screenGui.tutorialOverlay
	root = screenGui:WaitForChild("Root") :: Frame
	dimmer = root:WaitForChild("Dimmer") :: Frame
	bubble = root:WaitForChild("Bubble") :: Frame
	bubbleScale = bubble:WaitForChild("UIScale") :: UIScale
	titleLabel = bubble:WaitForChild("Title") :: TextLabel
	bodyLabel = bubble:WaitForChild("Body") :: TextLabel
	skipBtn = root:WaitForChild("SkipTutorial") :: TextButton
	skipConfirmRoot = root:FindFirstChild("SkipConfirm") :: Frame?

	if skipConfirmRoot then
		local panel = skipConfirmRoot:WaitForChild("Panel") :: Frame
		local confirmTitle = panel:WaitForChild("ConfirmTitle") :: TextLabel
		local confirmBody = panel:WaitForChild("ConfirmBody") :: TextLabel
		confirmTitle.Text = MicrocopyConfig.TutorialSkipConfirmTitle
		confirmBody.Text = MicrocopyConfig.TutorialSkipConfirmBody
		local keepBtn = panel:WaitForChild("KeepLearning") :: TextButton
		local skipAnywayBtn = panel:WaitForChild("SkipAnyway") :: TextButton

		local confirmRoot = skipConfirmRoot :: Frame
		skipBtn.MouseButton1Click:Connect(function()
			if confirmRoot.Visible then
				return
			end
			SoundFacade.playOneShot("tutorial_skip_open")
			savedSkipBtnVisible = skipBtn.Visible
			confirmRoot.Visible = true
			skipBtn.Visible = false
		end)

		keepBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			closeSkipConfirm()
		end)

		skipAnywayBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("tutorial_skip_confirm")
			closeSkipConfirm()
			Remotes.getEvent("TutorialSkip"):FireServer()
		end)
	else
		skipBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			Remotes.getEvent("TutorialSkip"):FireServer()
		end)
	end

	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		local on = screenGui.Enabled
		SoundFacade.setModalOverlayOpen(on)
		SoundFacade.setTutorialGameplayBlocked(on)
	end)
	if screenGui.Enabled then
		SoundFacade.setModalOverlayOpen(true)
		SoundFacade.setTutorialGameplayBlocked(true)
	end

	Remotes.getEvent("TutorialStep").OnClientEvent:Connect(function(payload: any)
		show(payload)
	end)

	local function onTutorialSkipBackAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject?)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local sc = skipConfirmRoot
		if not sc or not sc.Visible or not screenGui.Enabled then
			return Enum.ContextActionResult.Pass
		end
		if
			inputObject
			and (
				inputObject.KeyCode == Enum.KeyCode.ButtonB
				or inputObject.KeyCode == Enum.KeyCode.Escape
			)
		then
			SoundFacade.playOneShot("click")
			closeSkipConfirm()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority(
		DAC_TUTORIAL_SKIP_BACK_ACTION,
		onTutorialSkipBackAction,
		false,
		DAC_TUTORIAL_SKIP_BACK_PRIORITY,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)

	Players.PlayerRemoving:Connect(function(p)
		if p == player then
			ContextActionService:UnbindAction(DAC_TUTORIAL_SKIP_BACK_ACTION)
			closeSkipConfirm()
			clearHighlight()
		end
	end)
end

return TutorialOverlay
