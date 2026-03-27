--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = {}

-- Hub / ActionBar icon buttons: UIScale hover + press + SoundFacade (POLA-402, shared with UIController).
local HUB_ICON_HOVER_SCALE = 1.06
local HUB_ICON_PRESS_SCALE = 0.94
local HUB_ICON_TWEEN_IN = 0.07
local HUB_ICON_TWEEN_OUT = 0.09

local hubJuiceTweens: { [Instance]: { Tween } } = {}

local function cancelHubJuiceTweens(inst: Instance)
	local bucket = hubJuiceTweens[inst]
	if not bucket then
		return
	end
	for _, tw in bucket do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(bucket)
end

local function playHubJuiceTween(inst: Instance, tw: Tween)
	local bucket = hubJuiceTweens[inst]
	if not bucket then
		bucket = {}
		hubJuiceTweens[inst] = bucket
	end
	table.insert(bucket, tw)
	tw:Play()
end

local function ensureButtonUIScale(gui: GuiObject): UIScale
	local u = gui:FindFirstChildOfClass("UIScale")
	if not u then
		u = Instance.new("UIScale")
		u.Scale = 1
		u.Parent = gui
	end
	return u
end

local function hubIconJuiceReduced(): boolean
	if ClientPerformanceProfile.isReducedMotion() then
		return true
	end
	if ClientPerformanceProfile.isLowGraphicsTier() then
		return true
	end
	-- POLA-501: MenuHub / ActionBar hover scale — skip tweens when FPS is throttling cosmetic idle motion.
	if ClientPerformanceProfile.isCosmeticUiMotionThrottled() then
		return true
	end
	return false
end

export type HubIconJuiceOptions = {
	hoverScale: number?,
	pressScale: number?,
	tweenInSec: number?,
	tweenOutSec: number?,
	-- Registered in SoundController; defaults match ActionBar quickbar (POLA-395).
	soundHover: string?,
	soundPress: string?,
}

--[[
	Wires UIScale press/hover feedback + SoundFacade for a primary hub / menu icon button.
	Idempotent per button (attribute DACHubIconJuice). Matches ActionBar polish constants.
]]
function UIHelpers.wireHubIconButtonJuice(btn: GuiButton, opts: HubIconJuiceOptions?)
	if btn:GetAttribute("DACHubIconJuice") == true then
		return
	end
	btn:SetAttribute("DACHubIconJuice", true)

	local o = opts or {}
	local hoverS = o.hoverScale or HUB_ICON_HOVER_SCALE
	local pressS = o.pressScale or HUB_ICON_PRESS_SCALE
	local tIn = o.tweenInSec or HUB_ICON_TWEEN_IN
	local tOut = o.tweenOutSec or HUB_ICON_TWEEN_OUT
	local sndHover = o.soundHover or "ui_quickbar_hover"
	local sndPress = o.soundPress or "ui_quickbar_press"

	if btn:IsA("ImageButton") then
		btn.AutoButtonColor = false
	end

	local scale = ensureButtonUIScale(btn)
	scale.Scale = 1

	local origImg: Color3? = if btn:IsA("ImageButton") then (btn :: ImageButton).ImageColor3 else nil
	local origBg = btn.BackgroundColor3

	local hoverActive = false
	local pressed = false
	local lastHoverSound = 0.0
	local lastPressSound = 0.0

	local function tweenScale(target: number, dur: number)
		if hubIconJuiceReduced() then
			scale.Scale = target
			return
		end
		cancelHubJuiceTweens(scale)
		playHubJuiceTween(
			scale,
			TweenService:Create(scale, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = target })
		)
	end

	local function resetColors()
		if origImg then
			(btn :: ImageButton).ImageColor3 = origImg
		end
		btn.BackgroundColor3 = origBg
	end

	local function applyHoverLook()
		if pressed then
			return
		end
		if origImg then
			(btn :: ImageButton).ImageColor3 = origImg:Lerp(Color3.new(1, 1, 1), 0.18)
		end
		if btn.BackgroundTransparency < 0.99 then
			btn.BackgroundColor3 = origBg:Lerp(Color3.new(1, 1, 1), 0.12)
		end
		tweenScale(hoverS, tIn)
	end

	local function releasePressVisual()
		pressed = false
		if hoverActive then
			applyHoverLook()
		else
			resetColors()
			tweenScale(1, tOut)
		end
	end

	btn.MouseEnter:Connect(function()
		hoverActive = true
		local now = os.clock()
		if now - lastHoverSound > 0.04 then
			lastHoverSound = now
			SoundFacade.playOneShot(sndHover)
		end
		applyHoverLook()
	end)

	btn.MouseLeave:Connect(function()
		hoverActive = false
		pressed = false
		resetColors()
		tweenScale(1, tOut)
	end)

	btn.MouseButton1Down:Connect(function()
		pressed = true
		local now = os.clock()
		if now - lastPressSound > 0.08 then
			lastPressSound = now
			SoundFacade.playOneShot(sndPress)
		end
		tweenScale(pressS, tIn)
	end)

	btn.MouseButton1Up:Connect(function()
		releasePressVisual()
	end)
end

--[[
	Applies wireHubIconButtonJuice to every GuiButton under a frame (e.g. DACMain.ActionBar).
]]
function UIHelpers.wireHubIconButtonsUnder(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") then
			UIHelpers.wireHubIconButtonJuice(d)
		end
	end
end

function UIHelpers.panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(24, 24, 48)
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	f.Size = UDim2.new(0.9, 0, 0.85, 0)
	f.Position = UDim2.new(0.5, 0, 0.5, 0)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Visible = false
	f.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = f

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 160, 255)
	s.Thickness = 2
	s.Transparency = 0.4
	s.Parent = f

	return f
end

function UIHelpers.titleBar(parent: Frame, title: string, onClose: () -> ())
	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 44)
	bar.BackgroundTransparency = 1
	bar.Parent = parent

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -56, 1, 0)
	t.Position = UDim2.new(0, 16, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 22
	t.TextColor3 = Color3.fromRGB(245, 245, 245)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	t.Parent = bar

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -48, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.Parent = bar
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		onClose()
	end)

	return bar
end

function UIHelpers.textButton(
	parent: Instance,
	text: string,
	color: Color3,
	layoutOrder: number,
	callback: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = layoutOrder
	b.Size = UDim2.new(1, -16, 0, 40)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	b.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		callback()
	end)
	return b
end

function UIHelpers.scrolling(parent: Frame): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = "Scroll"
	s.Size = UDim2.new(1, -24, 1, -60)
	s.Position = UDim2.new(0, 12, 0, 52)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent

	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 8)
	lay.Parent = s

	return s
end

function UIHelpers.scrollingGrid(parent: Frame): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = "ScrollGrid"
	s.Size = UDim2.new(1, -24, 1, -60)
	s.Position = UDim2.new(0, 12, 0, 52)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent

	local lay = Instance.new("UIGridLayout")
	lay.CellSize = UDim2.new(0, 140, 0, 160)
	lay.CellPadding = UDim2.new(0, 8, 0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = s

	return s
end

function UIHelpers.rarityStroke(rarity: string): Color3
	return Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
end

function UIHelpers.currencyColor(currencyType: string): Color3
	local row = Constants.CURRENCY_DISPLAY[currencyType]
	return if row then row.color else Color3.fromRGB(255, 255, 255)
end

--[[
	POLA-497: prevent long Microcopy / localized strings from spilling past fixed-width UI.
	Idempotent per label (DACSingleLineTruncate / DACFittedWrapped).
]]
function UIHelpers.ensureSingleLineTruncate(lbl: TextLabel | TextButton)
	if lbl:GetAttribute("DACSingleLineTruncate") == true then
		return
	end
	lbl:SetAttribute("DACSingleLineTruncate", true)
	lbl.TextWrapped = false
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
end

--[[
	Fixed-height cells with multi-line body copy: scale font down to fit (TextScaled + UITextSizeConstraint).
	Does not touch ClientPerformanceProfile / ReduceMotion (layout-only).
]]
function UIHelpers.ensureFittedWrappedText(lbl: TextLabel, maxTextSize: number, minTextSize: number?)
	if lbl:GetAttribute("DACFittedWrapped") == true then
		return
	end
	lbl:SetAttribute("DACFittedWrapped", true)
	lbl.TextWrapped = true
	lbl.TextScaled = true
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	local c = lbl:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
	end
	c.MaxTextSize = maxTextSize
	c.MinTextSize = minTextSize or math.max(7, math.floor(maxTextSize * 0.55))
	c.Parent = lbl
end

return UIHelpers
