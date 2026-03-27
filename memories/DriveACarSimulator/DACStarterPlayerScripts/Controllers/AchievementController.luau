--!strict
--[[
	Achievement unlock toast queue (max 3 pending, 1 visible). Suppressed during driving runs.

	Phase4NotificationLaneJuiceSpec §2–5: FIFO + one visible enforces one hero stinger at a time;
	stacked unlocks use STACK_GAP_AFTER_DISMISS between dismiss and next entrance. [E] payout and
	[G] ceremony queue defer new [C] entrances (see laneBlocked); duckBus already trims [C] SFX
	while payout is open (SoundController).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local NotificationLaneBridge = require(DAC:WaitForChild("NotificationLaneBridge"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local AchievementPopupConfig = require(DAC:WaitForChild("Config"):WaitForChild("AchievementPopupConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local Z = UILayerStack.z

local DrivingController = require(script.Parent:WaitForChild("DrivingController"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local VFXController = require(script.Parent:WaitForChild("VFXController"))
local NewPlayerCalmWindow = require(DAC:WaitForChild("NewPlayerCalmWindow"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local AchievementController = {}

-- Idempotent init: hot reload must not stack achievement RemoteEvent listeners or duplicate layers.
local achievementClientInitDone = false

local player = Players.LocalPlayer
local achievementHostScreen: ScreenGui? = nil

local MAX_QUEUE = 3
-- Phase4NotificationLaneJuiceSpec §2 "Stacked unlock": minimum gap after dismiss before next entrance.
local STACK_GAP_AFTER_DISMISS = 0.4
local queue: { any } = {}
local showing = false
local pendingProgressWhileBlocked: { id: string, current: number, target: number }? = nil
local root: Frame? = nil
local progressRoot: Frame? = nil
local lastProgressKey = ""
local lastProgressAt = 0.0

local RARITY_ACCENT: { [string]: Color3 } = {
	bronze = Color3.fromRGB(180, 120, 60),
	silver = Color3.fromRGB(180, 195, 210),
	gold = Color3.fromRGB(255, 213, 79),
	diamond = Color3.fromRGB(160, 220, 255),
}

-- DAC panel language (AGENTS.md): pastel body + charcoal border; ephemeral toast matches inventory/store.
local PANEL_GRAD_TOP = Color3.fromRGB(255, 214, 238)
local PANEL_GRAD_BOT = Color3.fromRGB(224, 214, 255)
local BORDER_CHARCOAL = Color3.fromRGB(42, 42, 64)
local BODY_TEXT_DARK = Color3.fromRGB(30, 30, 30)
local TITLE_WHITE = Color3.new(1, 1, 1)
local PROGRESS_FILL_GREEN = Color3.fromRGB(46, 204, 113)
local COUNT_GOLD = Color3.fromRGB(255, 201, 74)

local function soundForRarity(r: string): string
	if r == "diamond" then
		return "trophy_diamond"
	elseif r == "gold" then
		return "trophy_gold"
	elseif r == "silver" then
		return "trophy_silver"
	end
	return "trophy_bronze"
end

local function flashScreen(peak: number)
	if not root then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = Z.achievementFlash
	flash.Parent = root
	TweenService:Create(
		flash,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 - peak }
	):Play()
	task.delay(0.12, function()
		if flash.Parent then
			TweenService:Create(
				flash,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
			task.delay(0.35, function()
				flash:Destroy()
			end)
		end
	end)
end

local function confettiDots(parent: GuiObject, count: number, rarity: string)
	local acc = RARITY_ACCENT[rarity] or RARITY_ACCENT.gold
	for i = 1, count do
		local d = Instance.new("Frame")
		d.Size = UDim2.fromOffset(6, 6)
		d.Position = UDim2.new(0.5, math.random(-180, 180), 0.5, math.random(-40, 40))
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.BackgroundColor3 = acc:Lerp(Color3.new(1, 1, 1), math.random() * 0.4)
		d.BorderSizePixel = 0
		d.ZIndex = Z.achievementConfetti
		d.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		local dest = UDim2.new(d.Position.X.Scale, d.Position.X.Offset + math.random(-80, 80), 1.2, math.random(0, 40))
		TweenService:Create(d, TweenInfo.new(1.8 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = dest,
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(d, 2.2)
	end
end

local function notificationLaneBlockedByStack(): boolean
	return SoundController.isPayoutModalOpen() or VFXController.isCeremonyHeroBlocking()
end

local function showToast(payload: any, done: () -> ())
	if not root then
		done()
		return
	end

	local kind = type(payload.kind) == "string" and payload.kind or "unlock"
	local headline = ""
	local subline = ""
	local rarity = "gold"
	local dur = 2.6

	if kind == "unlock" then
		local id = payload.id
		if type(id) == "string" then
			local def = AchievementPopupConfig.getAchievementById(id)
			if def then
				-- Match AchievementTrophySpec §B: headline = UnlockToastLines + title; body = description (not title twice).
				headline = AchievementPopupConfig.pickVariant(AchievementPopupConfig.UnlockToastLines):gsub("{TITLE}", def.title)
				subline = def.description
			else
				headline = MicrocopyConfig.AchievementToastHeadlineGeneric
				subline = tostring(id)
			end
		end
		rarity = if type(payload.rarity) == "string" then string.lower(payload.rarity) else "bronze"
		if rarity == "diamond" then
			dur = 4.0
		elseif rarity == "gold" then
			dur = 3.2
		end
	elseif kind == "category_complete" then
		headline = MicrocopyConfig.AchievementToastCategoryCompleteHeadline
		subline = type(payload.line) == "string" and payload.line or ""
		rarity = "gold"
		dur = 3.5
	elseif kind == "total_completion" then
		headline = MicrocopyConfig.AchievementToastTotalCompletionHeadline
		subline = type(payload.line) == "string" and payload.line or ""
		rarity = "diamond"
		dur = 5.0
	else
		done()
		return
	end

	local accent = RARITY_ACCENT[rarity] or RARITY_ACCENT.bronze

	local manualTop = select(2, HudSafeArea.getManualInsetForScreenGui(achievementHostScreen))
	local narrow = HudSafeArea.isCompactWidth(HudLayoutConfig.compactViewportWidth)
	local toastW = if rarity == "diamond" then (if narrow then HudLayoutConfig.achievementToastWidthNarrowDiamond else HudLayoutConfig.achievementToastWidthDiamond) else (if narrow then HudLayoutConfig.achievementToastWidthNarrow else HudLayoutConfig.achievementToastWidthDefault)
	local toastH = if rarity == "diamond" then 84 else 74
	local topRest = HudLayoutConfig.achievementToastTopRestPx + manualTop

	local card = Instance.new("Frame")
	card.Name = "AchievementToast"
	card.Size = UDim2.fromOffset(toastW, toastH)
	card.Position = UDim2.new(0.5, 0, 0, -120 - manualTop)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.02
	card.ZIndex = Z.achievementUnlockCard
	card.Parent = root

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(PANEL_GRAD_TOP, PANEL_GRAD_BOT)
	grad.Rotation = 90
	grad.Parent = card

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 14)
	cr.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if rarity == "diamond" then 3 else 2.5
	stroke.Color = BORDER_CHARCOAL
	stroke.Transparency = 0.08
	stroke.Parent = card

	local accentBar = Instance.new("Frame")
	accentBar.Name = "RarityAccent"
	accentBar.Size = UDim2.new(1, -24, 0, 3)
	accentBar.Position = UDim2.new(0, 12, 0, 36)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = Z.achievementUnlockInner
	local abCr = Instance.new("UICorner")
	abCr.CornerRadius = UDim.new(0, 2)
	abCr.Parent = accentBar
	accentBar.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Position = UDim2.new(0, 12, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = TITLE_WHITE
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0.48
	title.Text = headline
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = Z.achievementUnlockInner
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -24, 0, 34)
	body.Position = UDim2.new(0, 12, 0, 44)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 14
	body.TextColor3 = BODY_TEXT_DARK
	body.Text = subline
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.ZIndex = Z.achievementUnlockInner
	body.Parent = card

	if kind == "unlock" then
		title.TextSize = 16
		title.TextWrapped = true
		title.TextYAlignment = Enum.TextYAlignment.Top
		title.Size = UDim2.new(1, -24, 0, 34)
		accentBar.Position = UDim2.new(0, 12, 0, 44)
		body.Position = UDim2.new(0, 12, 0, 50)
		body.Size = UDim2.new(1, -24, 0, 22)
		body.TextSize = 13
	end

	if kind == "total_completion" then
		SoundFacade.playOneShot("trophy_total_completion")
	elseif kind == "category_complete" then
		SoundFacade.playOneShot("trophy_gold")
	else
		SoundFacade.playOneShot(soundForRarity(rarity))
	end

	if kind == "total_completion" then
		VFXFacade.cameraShake(0.18, 0.35)
		flashScreen(0.18)
		confettiDots(card, 24, "diamond")
	elseif kind == "category_complete" then
		VFXFacade.cameraShake(0.14, 0.3)
		flashScreen(0.12)
		confettiDots(card, 12, "gold")
	elseif rarity == "bronze" then
		VFXFacade.cameraShake(0.06, 0.2)
	elseif rarity == "silver" then
		VFXFacade.cameraShake(0.1, 0.25)
		flashScreen(0.08)
	elseif rarity == "gold" then
		VFXFacade.cameraShake(0.14, 0.3)
		flashScreen(0.12)
		confettiDots(card, 8, "gold")
	else
		VFXFacade.cameraShake(0.18, 0.35)
		flashScreen(0.18)
		confettiDots(card, 16, "diamond")
	end

	TweenService:Create(
		card,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, topRest) }
	):Play()

	task.delay(dur, function()
		if not card.Parent then
			done()
			return
		end
		TweenService:Create(
			card,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -100 - manualTop), BackgroundTransparency = 1 }
		):Play()
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			elseif d:IsA("Frame") and d.Name == "RarityAccent" then
				TweenService:Create(d, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				}):Play()
			end
		end
		task.delay(0.4, function()
			card:Destroy()
			done()
		end)
	end)
end

local function showAchievementProgressToast(payload: { id: string, current: number, target: number })
	if not progressRoot then
		return
	end
	if NewPlayerCalmWindow.shouldDeferAchievementProgress() then
		NewPlayerCalmWindow.enqueueAchievementProgress(payload)
		return
	end
	if notificationLaneBlockedByStack() then
		pendingProgressWhileBlocked = payload
		return
	end
	local id = payload.id
	local cur = math.max(0, math.floor(tonumber(payload.current) or 0))
	local tgt = math.max(1, math.floor(tonumber(payload.target) or 1))
	local pct = math.clamp(math.floor((cur / tgt) * 100 + 0.5), 0, 100)
	local now = os.clock()
	local dedupeKey = `{id}:{cur}:{tgt}`
	if dedupeKey == lastProgressKey and now - lastProgressAt < 0.35 then
		return
	end
	lastProgressKey = dedupeKey
	lastProgressAt = now

	local def = AchievementPopupConfig.getAchievementById(id)
	local titleText = if def then def.title else string.upper(id)
	local line = AchievementPopupConfig.pickVariant(AchievementPopupConfig.ProgressNudge)
		:gsub("{TITLE}", titleText)
		:gsub("{PERCENT}", tostring(pct))

	for _, child in progressRoot:GetChildren() do
		if child:IsA("Frame") and child.Name == "AchievementProgressToast" then
			child:Destroy()
		end
	end

	local _, _, _, pManualBottom = HudSafeArea.getManualInsetsForScreenGui(achievementHostScreen)
	local bottomPad = HudLayoutConfig.edgeMarginPx + pManualBottom
	local pNarrow = HudSafeArea.isCompactWidth(HudLayoutConfig.compactViewportWidth)
	local pW = if pNarrow then HudLayoutConfig.progressToastWidthNarrow else HudLayoutConfig.progressToastWidthDefault

	local card = Instance.new("Frame")
	card.Name = "AchievementProgressToast"
	card.Size = UDim2.fromOffset(pW, 78)
	card.Position = UDim2.new(0.5, 0, 1, -120 - bottomPad)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.02
	card.ZIndex = Z.achievementProgressCard
	card.Parent = progressRoot

	local pGrad = Instance.new("UIGradient")
	pGrad.Color = ColorSequence.new(PANEL_GRAD_TOP, PANEL_GRAD_BOT)
	pGrad.Rotation = 90
	pGrad.Parent = card

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 12)
	cr.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = BORDER_CHARCOAL
	stroke.Transparency = 0.1
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -130, 0, 22)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = TITLE_WHITE
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0.5
	title.Text = titleText
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = Z.achievementProgressInner
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 0, 32)
	body.Position = UDim2.new(0, 10, 0, 28)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextSize = 13
	body.TextColor3 = BODY_TEXT_DARK
	body.Text = line
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.ZIndex = Z.achievementProgressInner
	body.Parent = card

	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(0, 120, 0, 18)
	count.Position = UDim2.new(1, -10, 0, 8)
	count.AnchorPoint = Vector2.new(1, 0)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextSize = 14
	count.TextColor3 = COUNT_GOLD
	count.TextStrokeColor3 = Color3.new(0, 0, 0)
	count.TextStrokeTransparency = 0.55
	count.Text = `{cur} / {tgt}`
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.ZIndex = Z.achievementProgressInner
	count.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBarBg"
	barBg.Size = UDim2.new(1, -20, 0, 8)
	barBg.Position = UDim2.new(0, 10, 1, -14)
	barBg.AnchorPoint = Vector2.new(0, 1)
	barBg.BackgroundColor3 = Color3.fromRGB(55, 50, 72)
	barBg.BackgroundTransparency = 0.15
	barBg.BorderSizePixel = 0
	barBg.ZIndex = Z.achievementProgressInner
	barBg.Parent = card
	local barCr = Instance.new("UICorner")
	barCr.CornerRadius = UDim.new(1, 0)
	barCr.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Name = "ProgressBarFill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = PROGRESS_FILL_GREEN
	fill.BorderSizePixel = 0
	fill.ZIndex = Z.achievementProgressFill
	fill.Parent = barBg
	local fillCr = Instance.new("UICorner")
	fillCr.CornerRadius = UDim.new(1, 0)
	fillCr.Parent = fill

	local ratio = math.clamp(cur / tgt, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()

	SoundFacade.playOneShot("notification")

	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -132 - bottomPad),
	}):Play()

	task.delay(2.4, function()
		if not card.Parent then
			return
		end
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 40),
			BackgroundTransparency = 1,
		}):Play()
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			elseif d:IsA("Frame") and d ~= card then
				TweenService:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				}):Play()
			end
		end
		task.delay(0.35, function()
			if card.Parent then
				card:Destroy()
			end
		end)
	end)
end

local function tryFlushDeferredProgress()
	local p = pendingProgressWhileBlocked
	if not p then
		return
	end
	if notificationLaneBlockedByStack() then
		return
	end
	pendingProgressWhileBlocked = nil
	showAchievementProgressToast(p)
end

local function pump()
	if showing then
		return
	end
	if DrivingController.isInRun() then
		return
	end
	if notificationLaneBlockedByStack() then
		return
	end
	local nextPayload = table.remove(queue, 1)
	if not nextPayload then
		return
	end
	showing = true
	showToast(nextPayload, function()
		showing = false
		task.delay(STACK_GAP_AFTER_DISMISS, function()
			pump()
			tryFlushDeferredProgress()
		end)
	end)
end

local function enqueue(payload: any)
	if #queue >= MAX_QUEUE then
		return
	end
	table.insert(queue, payload)
	pump()
end

function AchievementController.init(screenGui: ScreenGui)
	if achievementClientInitDone then
		return
	end
	achievementClientInitDone = true

	achievementHostScreen = screenGui
	local holder = Instance.new("Frame")
	holder.Name = "AchievementToastLayer"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = Z.achievementUnlockLayer
	holder.Parent = screenGui
	root = holder

	local progressHolder = Instance.new("Frame")
	progressHolder.Name = "AchievementProgressLayer"
	progressHolder.Size = UDim2.fromScale(1, 1)
	progressHolder.BackgroundTransparency = 1
	progressHolder.ZIndex = Z.achievementProgressLayer
	progressHolder.Parent = screenGui
	progressRoot = progressHolder

	local progressConn = Remotes.getEvent("AchievementProgress").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.id) ~= "string" then
			return
		end
		showAchievementProgressToast(payload :: any)
	end)

	local unlockConn = Remotes.getEvent("AchievementUnlocked").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		enqueue(payload)
	end)

	local endRunConn = Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
		task.defer(function()
			pump()
		end)
	end)

	screenGui.Destroying:Connect(function()
		progressConn:Disconnect()
		unlockConn:Disconnect()
		endRunConn:Disconnect()
	end)

	NotificationLaneBridge.register(function()
		tryFlushDeferredProgress()
		pump()
	end)
end

function AchievementController.showQueuedAchievementProgress(payload: { id: string, current: number, target: number })
	showAchievementProgressToast(payload)
end

return AchievementController
