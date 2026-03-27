--!strict
--[[
	Daily reward panel.
	Shell UI is pre-built in DACMain.Panels.Daily; this script wires behavior.
	Celebration overlay is still created at runtime (ephemeral).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MenuInputAccessibility = require(DAC:WaitForChild("MenuInputAccessibility"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local ClientRemoteDebounce = require(DAC:WaitForChild("ClientRemoteDebounce"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local FirstTimeConfig = require(DAC:WaitForChild("Config"):WaitForChild("FirstTimeConfig"))

local DailyRewardPanel = {}

local lastClaimDailyFire = { 0 }

local STREAK_REWARDS = DailyRewardConfig.STREAK_REWARDS
local player = Players.LocalPlayer
local preClaimStreak: number? = nil
local claimPending = false

local function motionJuice(): boolean
	return not ClientPerformanceProfile.isReducedMotion() and not ClientPerformanceProfile.isLowGraphicsTier()
end

local function ceremonyMilestoneLine(dayIndex: number): string?
	local pool = (FirstTimeConfig :: any).StreakMilestones :: { [number]: { string } }?
	if type(pool) ~= "table" then
		return nil
	end
	local at = pool[dayIndex]
	if type(at) == "table" and #at > 0 then
		return at[math.random(1, #at)]
	end
	return nil
end

local function claimsToNextMilestone(streak: number): (number, number)
	local s = math.max(0, streak)
	local pos = s % 7
	if pos == 0 then
		return 3, 3
	end
	if pos < 3 then
		return 3, 3 - pos
	end
	if pos < 7 then
		return 7, 7 - pos
	end
	return 3, 3
end
local function flameColorForDay(day: number): Color3
	local t = math.clamp((day - 1) / 6, 0, 1)
	return Color3.fromRGB(255, math.floor(180 - 140 * t), math.floor(40 - 30 * t))
end

local function playCelebration(dayIndex: number, dayDef: any, mult: number, isPremium: boolean, lostStreak: number?)
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local isJackpot = dayIndex == Constants.MAX_DAILY_STREAK
	local juice = motionJuice()
	local isMilestoneDay = dayIndex == 3 or dayIndex == 7
	local confettiTier: string? = if isJackpot then "mega" elseif dayIndex == 3 then "medium" else nil

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DailyRewardCelebration"
	overlay.DisplayOrder = UILayerStack.screenGui.dailyCelebration
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.Parent = pg

	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.fromScale(1, 1); dismissBtn.BackgroundColor3 = Color3.new(0, 0, 0)
	dismissBtn.BackgroundTransparency = 0.5; dismissBtn.Text = ""; dismissBtn.ZIndex = 1
	dismissBtn.Parent = overlay

	local dayFlameColor = flameColorForDay(dayIndex)
	VFXFacade.purchaseCelebration("daily", confettiTier)
	if juice then
		task.delay(0.05, function()
			local flashCol = if isJackpot then Color3.fromRGB(255, 200, 50) else dayFlameColor
			local flashFrame = Instance.new("Frame")
			flashFrame.Size = UDim2.fromScale(1, 1); flashFrame.BackgroundColor3 = flashCol
			flashFrame.BackgroundTransparency = 0.6; flashFrame.ZIndex = 50; flashFrame.Parent = overlay
			TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			task.delay(0.45, function() flashFrame:Destroy() end)
		end)
	end

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.8, 0, 0, 80); banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = if juice then UDim2.new(0.5, 0, -0.15, 0) else UDim2.new(0.5, 0, 0.22, 0)
	banner.BackgroundColor3 = if isJackpot then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(30, 30, 65)
	banner.BackgroundTransparency = 0.08; banner.BorderSizePixel = 0
	banner.Font = Enum.Font.GothamBold; banner.TextSize = if isJackpot then 40 else 32
	banner.TextColor3 = if isJackpot then Color3.fromRGB(50, 25, 0) else Color3.fromRGB(255, 230, 120)
	banner.TextStrokeTransparency = if isJackpot then 0.3 else 0.6
	banner.Text = if isJackpot then "JACKPOT DAY!" else ("Day " .. dayIndex .. " Reward!")
	banner.ZIndex = 10; banner.Parent = overlay
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 16); bc.Parent = banner
	local bs = Instance.new("UIStroke")
	bs.Color = if isJackpot then Color3.fromRGB(255, 170, 0) else Color3.fromRGB(120, 160, 255)
	bs.Thickness = if isJackpot then 3 else 2; bs.Parent = banner
	if juice then
		TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.22, 0) }):Play()
	end
	SoundFacade.playOneShot("level_up")

	local streakFlavor = Instance.new("TextLabel")
	streakFlavor.Size = UDim2.new(0.88, 0, 0, 44); streakFlavor.AnchorPoint = Vector2.new(0.5, 0)
	streakFlavor.Position = UDim2.new(0.5, 0, 0.26, 0); streakFlavor.BackgroundTransparency = 1
	streakFlavor.Font = Enum.Font.Gotham; streakFlavor.TextSize = 16
	streakFlavor.TextColor3 = Color3.fromRGB(255, 205, 130); streakFlavor.TextWrapped = true
	streakFlavor.TextXAlignment = Enum.TextXAlignment.Center; streakFlavor.ZIndex = 10
	if lostStreak ~= nil and lostStreak > 0 then
		streakFlavor.TextColor3 = Color3.fromRGB(255, 120, 120)
		streakFlavor.Font = Enum.Font.GothamBold; streakFlavor.TextSize = 17
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOLost):gsub("{STREAK}", tostring(lostStreak))
	elseif isMilestoneDay then
		local line = ceremonyMilestoneLine(dayIndex)
		streakFlavor.Text = if line and line ~= "" then line else MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOMilestone)
		streakFlavor.Font = Enum.Font.GothamBold
		streakFlavor.TextSize = 17
	else
		local nextD = DailyRewardConfig.nextDayIndex(dayIndex)
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOTomorrow):gsub("{STREAK}", tostring(nextD))
	end
	streakFlavor.Parent = overlay

	-- Jackpot juice: `purchaseCelebration("daily", "mega")` already runs mega confetti above.
	-- Do NOT call `rebirthFlash(7)` — that argument is *rebirth count* and updates
	-- `lastRebirthCelebrated`, which would suppress real rebirth VFX for rebirths 1–7 and
	-- flash a bogus "REBIRTH +7" label. Extra punch: camera shake only.
	if isJackpot and juice then
		VFXFacade.cameraShake(0.42, 0.4)
	end

	local streakLbl = Instance.new("TextLabel")
	streakLbl.Size = UDim2.new(0, 200, 0, 30); streakLbl.AnchorPoint = Vector2.new(0.5, 0)
	streakLbl.Position = UDim2.new(0.5, 0, 0.30, 0); streakLbl.BackgroundTransparency = 1
	streakLbl.Font = Enum.Font.GothamBold; streakLbl.TextSize = 18
	streakLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
	streakLbl.Text = "Day " .. dayIndex .. "/" .. Constants.MAX_DAILY_STREAK; streakLbl.ZIndex = 10
	streakLbl.Parent = overlay
	local streakScale = Instance.new("UIScale"); streakScale.Scale = 1; streakScale.Parent = streakLbl
	if juice then
		TweenService:Create(streakScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
		task.delay(0.15, function() if streakScale.Parent then TweenService:Create(streakScale, TweenInfo.new(0.15), { Scale = 1 }):Play() end end)
	end

	local streakDotsFrame = Instance.new("Frame")
	streakDotsFrame.Name = "StreakDots"; streakDotsFrame.Size = UDim2.new(0.7, 0, 0, 24)
	streakDotsFrame.AnchorPoint = Vector2.new(0.5, 0); streakDotsFrame.Position = UDim2.new(0.5, 0, 0.345, 0)
	streakDotsFrame.BackgroundTransparency = 1; streakDotsFrame.ZIndex = 10; streakDotsFrame.Parent = overlay
	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding = UDim.new(0, 6); dotsLayout.Parent = streakDotsFrame
	for i = 1, Constants.MAX_DAILY_STREAK do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i; dot.Size = UDim2.fromOffset(20, 20)
		dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80); dot.BorderSizePixel = 0
		dot.LayoutOrder = i; dot.ZIndex = 10; dot.Parent = streakDotsFrame
		local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0.5, 0); dc.Parent = dot
		if i <= dayIndex then
			local col = flameColorForDay(i)
			dot.BackgroundColor3 = col
			local dg = Instance.new("UIStroke"); dg.Color = col; dg.Thickness = 2; dg.Transparency = 0.3; dg.Parent = dot
			if juice then
				task.delay(0.3 + (i - 1) * 0.12, function()
					if not dot.Parent then return end
					local ds = Instance.new("UIScale"); ds.Scale = 0.5; ds.Parent = dot
					TweenService:Create(ds, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
					task.delay(0.2, function() if ds.Parent then TweenService:Create(ds, TweenInfo.new(0.1), { Scale = 1 }):Play() end end)
				end)
			end
		end
	end

	local rewards = dayDef.rewards
	local rewardContainer = Instance.new("Frame")
	rewardContainer.Size = UDim2.new(0.7, 0, 0, 0); rewardContainer.AutomaticSize = Enum.AutomaticSize.Y
	rewardContainer.AnchorPoint = Vector2.new(0.5, 0); rewardContainer.Position = UDim2.new(0.5, 0, 0.38, 0)
	rewardContainer.BackgroundTransparency = 1; rewardContainer.ZIndex = 10; rewardContainer.Parent = overlay
	local rLayout = Instance.new("UIListLayout")
	rLayout.SortOrder = Enum.SortOrder.LayoutOrder; rLayout.Padding = UDim.new(0, 8)
	rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rLayout.Parent = rewardContainer
	for idx, reward in rewards do
		task.delay(0.5 + (idx - 1) * 0.45, function()
			local amt = math.floor(reward.amount * mult + 0.5)
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.6, 0, 0, 30); card.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
			card.BackgroundTransparency = 0.12; card.BorderSizePixel = 0; card.LayoutOrder = idx
			card.ClipsDescendants = true; card.ZIndex = 10; card.Parent = rewardContainer
			local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 10); cc.Parent = card
			local currColor = UIHelpers.currencyColor(reward.currency)
			local cs = Instance.new("UIStroke"); cs.Color = currColor; cs.Thickness = 2; cs.Transparency = 0.35; cs.Parent = card
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 22
			lbl.TextColor3 = currColor; lbl.TextStrokeTransparency = 0.4
			lbl.Text = "+" .. tostring(amt) .. " " .. reward.currency; lbl.ZIndex = 12; lbl.Parent = card
			local cardScale = Instance.new("UIScale")
			cardScale.Scale = 1
			cardScale.Parent = card
			if idx == 1 and isMilestoneDay and juice then
				cardScale.Scale = 0.88
				local punch = if isJackpot then 1.14 else 1.08
				TweenService:Create(cardScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = punch }):Play()
				task.delay(0.28, function()
					if cardScale.Parent then
						TweenService:Create(cardScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					end
				end)
			end
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 50) }):Play()
			SoundFacade.playOneShot("currency")
			VFXFacade.currencyPopup(reward.currency, amt)
		end)
	end

	local totalDuration = 1.5 + #rewards * 0.45 + (if isPremium then 2.0 else 0.5) + 2.5
	local function closeOverlay()
		if juice then
			TweenService:Create(dismissBtn, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, -0.2, 0) }):Play()
		else
			dismissBtn.BackgroundTransparency = 1
		end
		task.delay(0.5, function() if overlay.Parent then overlay:Destroy() end end)
	end
	task.delay(totalDuration, closeOverlay)
	dismissBtn.MouseButton1Click:Connect(closeOverlay)
end

local function fetchData(): any?
	local ok, data = RemoteFailSafe.invokeGetPlayerData()
	if not ok then
		return nil
	end
	return data
end

function DailyRewardPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Daily") :: Frame
	MenuHub.registerPanel("daily", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	local closeBtn = titleBar:WaitForChild("Close") :: TextButton
	closeBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("panel_close")
		MenuHub.closeAll()
	end)

	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame
	local streakWarning = scroll:WaitForChild("StreakFOMO") :: TextLabel
	streakWarning.TextWrapped = true
	local multLabel = scroll:WaitForChild("MultLabel") :: TextLabel
	multLabel.TextWrapped = true
	multLabel.TextYAlignment = Enum.TextYAlignment.Top
	multLabel.AutomaticSize = Enum.AutomaticSize.Y
	local calendarRow = scroll:WaitForChild("CalendarRow") :: Frame
	local premiumFrame = scroll:WaitForChild("PremiumGift") :: Frame
	local claimBtn = root:WaitForChild("ClaimBtn") :: TextButton
	MenuInputAccessibility.applyPrimaryNavDefaults(closeBtn)
	MenuInputAccessibility.applyPrimaryNavDefaults(claimBtn)

	local dayCells: { Frame } = {}
	for i = 1, Constants.MAX_DAILY_STREAK do
		local cell = calendarRow:FindFirstChild("Day" .. i)
		if cell and cell:IsA("Frame") then dayCells[i] = cell end
	end

	local streakMeterRow = scroll:FindFirstChild("StreakMeter") :: Frame?
	if not streakMeterRow then
		streakMeterRow = Instance.new("Frame")
		streakMeterRow.Name = "StreakMeter"
		streakMeterRow.BackgroundTransparency = 1
		streakMeterRow.Size = UDim2.new(1, -16, 0, 0)
		streakMeterRow.AutomaticSize = Enum.AutomaticSize.Y
		local mo = (multLabel :: any).LayoutOrder
		streakMeterRow.LayoutOrder = if type(mo) == "number" then mo - 1 else 1
		streakMeterRow.Parent = scroll
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = streakMeterRow
		local vl = Instance.new("UIListLayout")
		vl.SortOrder = Enum.SortOrder.LayoutOrder
		vl.Padding = UDim.new(0, 6)
		vl.Parent = streakMeterRow
		local title = Instance.new("TextLabel")
		title.Name = "StreakMeterTitle"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextColor3 = Color3.fromRGB(45, 40, 62)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Size = UDim2.new(1, 0, 0, 18)
		title.Text = MicrocopyConfig.DailyRewardStreakMeterTitle
		title.LayoutOrder = 1
		title.Parent = streakMeterRow
		local track = Instance.new("Frame")
		track.Name = "StreakTrack"
		track.Size = UDim2.new(1, 0, 0, 14)
		track.BackgroundColor3 = Color3.fromRGB(38, 38, 58)
		track.BorderSizePixel = 0
		track.LayoutOrder = 2
		track.Parent = streakMeterRow
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 7)
		tc.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "StreakFill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(255, 188, 72)
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 7)
		fc.Parent = fill
		for _, frac in { 3 / 7, 1 } do
			local mark = Instance.new("Frame")
			mark.Size = UDim2.new(0, 3, 1, 8)
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.new(frac, 0, 0.5, 0)
			mark.BackgroundColor3 = Color3.fromRGB(230, 230, 255)
			mark.BackgroundTransparency = 0.25
			mark.BorderSizePixel = 0
			mark.ZIndex = 2
			mark.Parent = track
			local mc = Instance.new("UICorner")
			mc.CornerRadius = UDim.new(0, 2)
			mc.Parent = mark
		end
		local sub = Instance.new("TextLabel")
		sub.Name = "StreakMeterSub"
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 13
		sub.TextColor3 = Color3.fromRGB(55, 50, 70)
		sub.TextWrapped = true
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Size = UDim2.new(1, 0, 0, 0)
		sub.AutomaticSize = Enum.AutomaticSize.Y
		sub.Text = ""
		sub.LayoutOrder = 3
		sub.Parent = streakMeterRow
		local lost = Instance.new("TextLabel")
		lost.Name = "StreakMeterLost"
		lost.BackgroundTransparency = 1
		lost.Font = Enum.Font.GothamBold
		lost.TextSize = 13
		lost.TextColor3 = Color3.fromRGB(200, 85, 95)
		lost.TextWrapped = true
		lost.TextXAlignment = Enum.TextXAlignment.Left
		lost.Visible = false
		lost.Size = UDim2.new(1, 0, 0, 0)
		lost.AutomaticSize = Enum.AutomaticSize.Y
		lost.LayoutOrder = 4
		lost.Parent = streakMeterRow
	end

	local streakTrack = streakMeterRow:WaitForChild("StreakTrack") :: Frame
	local streakFill = streakTrack:WaitForChild("StreakFill") :: Frame
	local streakSub = streakMeterRow:WaitForChild("StreakMeterSub") :: TextLabel
	local streakLost = streakMeterRow:WaitForChild("StreakMeterLost") :: TextLabel
	local streakMeterTitle = streakMeterRow:WaitForChild("StreakMeterTitle") :: TextLabel

	local claimBtnOriginalText = MicrocopyConfig.DailyRewardClaimButtonDefault
	local claimBtnScale = Instance.new("UIScale"); claimBtnScale.Scale = 1; claimBtnScale.Parent = claimBtn
	local claimShimmerGrad: UIGradient? = nil
	local claimReadyPulseTween: Tween? = nil
	local streakFillGrad: UIGradient? = streakFill:FindFirstChildOfClass("UIGradient")
	local streakFillStroke: UIStroke? = streakFill:FindFirstChildOfClass("UIStroke")
	local streakTrackStroke: UIStroke? = streakTrack:FindFirstChildOfClass("UIStroke")

	local STREAK_TITLE_BASE = MicrocopyConfig.DailyRewardStreakMeterTitle

	local function stopClaimReadyPulse()
		if claimReadyPulseTween then
			claimReadyPulseTween:Cancel()
			claimReadyPulseTween = nil
		end
		claimBtnScale.Scale = 1
	end

	local function startClaimReadyPulse()
		stopClaimReadyPulse()
		if not motionJuice() or claimPending then
			return
		end
		claimReadyPulseTween = TweenService:Create(
			claimBtnScale,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.06 }
		)
		claimReadyPulseTween:Play()
	end

	local function restoreClaimButton()
		stopClaimReadyPulse()
		claimBtnScale.Scale = 1
		claimBtn.Text = claimBtnOriginalText
		if claimShimmerGrad then claimShimmerGrad:Destroy(); claimShimmerGrad = nil end
	end

	local function applyStreakFlameChrome(streak: number)
		local style = DailyRewardConfig.streakFlameStyleForStreak(streak)
		streakMeterTitle.Text = style.titlePrefix .. STREAK_TITLE_BASE
		if not streakFillGrad then
			streakFillGrad = Instance.new("UIGradient")
			streakFillGrad.Rotation = 90
			streakFillGrad.Parent = streakFill
		end
		streakFillGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.fillColor),
			ColorSequenceKeypoint.new(1, style.fillColorEnd),
		})
		if style.strokeThickness <= 0 then
			if streakFillStroke then
				streakFillStroke.Enabled = false
			end
		else
			if not streakFillStroke then
				streakFillStroke = Instance.new("UIStroke")
				streakFillStroke.Parent = streakFill
			end
			streakFillStroke.Enabled = true
			streakFillStroke.Color = style.strokeColor
			streakFillStroke.Thickness = style.strokeThickness
			streakFillStroke.Transparency = 0.25
		end
		if streak >= 3 and motionJuice() then
			if not streakTrackStroke then
				streakTrackStroke = Instance.new("UIStroke")
				streakTrackStroke.Parent = streakTrack
			end
			streakTrackStroke.Enabled = true
			streakTrackStroke.Color = style.strokeColor
			streakTrackStroke.Thickness = math.clamp(style.strokeThickness, 1, 3)
			streakTrackStroke.Transparency = 0.55
		elseif streakTrackStroke then
			streakTrackStroke.Enabled = false
		end
	end

	local function refresh()
		local data = fetchData()
		local streak = 0; local cycle = 1
		if data and data.dailyReward then
			streak = data.dailyReward.streak or 0
			cycle = data.dailyReward.dailyCycle or 1
		end
		local mult = DailyRewardConfig.getCycleMultiplier(cycle)
		local multStr = string.format("%.2g", mult)
		local cycleFmt = if HudSafeArea.isCompactWidth(HudLayoutConfig.compactViewportWidth) then MicrocopyConfig.DailyRewardCycleMultFormatCompact else MicrocopyConfig.DailyRewardCycleMultFormat
		multLabel.Text = cycleFmt:gsub("{CYCLE}", tostring(cycle)):gsub("{MULT}", multStr)
		local appliedDailyFraming = false
		local okFs, rFs = pcall(function()
			return Remotes.getFunction("FirstSessionOnboarding"):InvokeServer({ kind = "prepareDailyStreak" })
		end)
		if okFs and type(rFs) == "table" and rFs.applied == true then
			streakWarning.Visible = true
			local txt = rFs.mainLine
			if type(rFs.hookLine) == "string" and rFs.hookLine ~= "" then
				txt = txt .. "\n" .. rFs.hookLine
			end
			streakWarning.Text = txt
			appliedDailyFraming = true
		end
		if not appliedDailyFraming then
			if streak > 3 then
				streakWarning.Visible = true
				streakWarning.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOWarning):gsub("{STREAK}", tostring(streak))
			else
				streakWarning.Visible = false
			end
		end

		local lostN = 0
		if data and data.dailyReward then
			lostN = math.floor(tonumber((data.dailyReward :: any).lastClaimLostStreak) or 0)
		end
		streakFill.Size = UDim2.new(math.clamp(streak / Constants.MAX_DAILY_STREAK, 0, 1), 0, 1, 0)
		local mDay, left = claimsToNextMilestone(streak)
		local claimWord = if left == 1 then "claim" else "claims"
		streakSub.Text = MicrocopyConfig.DailyRewardNextMilestoneFormat:gsub("{MDAY}", tostring(mDay)):gsub(
			"{LEFT}",
			tostring(left)
		):gsub("{CLAIM_WORD}", claimWord)
		if lostN > 0 and streak == 0 then
			streakLost.Visible = true
			streakLost.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOLost):gsub("{STREAK}", tostring(lostN))
		else
			streakLost.Visible = false
		end

		applyStreakFlameChrome(streak)

		local lastClaimUnix = 0
		if data and data.dailyReward then
			lastClaimUnix = math.floor(tonumber((data.dailyReward :: any).lastClaim) or 0)
		end
		local canClaim = DailyRewardConfig.canClaimNow(lastClaimUnix)
		if canClaim and not claimPending and motionJuice() then
			startClaimReadyPulse()
		else
			stopClaimReadyPulse()
		end

		for i = 1, Constants.MAX_DAILY_STREAK do
			local cell = dayCells[i]
			if not cell then
				continue
			end
			local sc = cell:FindFirstChildOfClass("UIScale")
			if sc then
				sc:Destroy()
			end
		end

		local nextIdx = DailyRewardConfig.nextDayIndex(streak)
		for i = 1, Constants.MAX_DAILY_STREAK do
			local cell = dayCells[i]
			if not cell then continue end
			local dayDef = STREAK_REWARDS[i]
			local body = cell:FindFirstChild("Body") :: TextLabel
			if body and dayDef then body.Text = DailyRewardConfig.formatRewardLine(dayDef, mult) end
			local isNext = i == nextIdx
			cell.BackgroundColor3 = isNext and Color3.fromRGB(70, 55, 25) or Color3.fromRGB(40, 40, 70)
			local s = cell:FindFirstChildOfClass("UIStroke")
			if s then s.Color = isNext and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(100, 120, 200); s.Thickness = isNext and 2 or 1 end
			if isNext and motionJuice() and (nextIdx == 3 or nextIdx == 7) then
				local pulse = Instance.new("UIScale")
				pulse.Scale = 1
				pulse.Parent = cell
				TweenService:Create(pulse, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 }):Play()
			end
		end
		premiumFrame.Visible = player.MembershipType == Enum.MembershipType.Premium
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refresh()
			local dataOpen = fetchData()
			local lastClaimOpen = 0
			if dataOpen and dataOpen.dailyReward then
				lastClaimOpen = math.floor(tonumber((dataOpen.dailyReward :: any).lastClaim) or 0)
			end
			local settings = dataOpen and dataOpen.settings
			local soundOn = settings == nil or type(settings.sound) ~= "boolean" or (settings :: any).sound == true
			if DailyRewardConfig.canClaimNow(lastClaimOpen) and soundOn and motionJuice() then
				SoundFacade.playOneShot("notification")
			end
		else
			stopClaimReadyPulse()
		end
	end)

	claimBtn.MouseButton1Click:Connect(function()
		if not ClientRemoteDebounce.allow(lastClaimDailyFire) then
			return
		end
		SoundFacade.playOneShot("click")
		local data = fetchData()
		if data and data.dailyReward then preClaimStreak = data.dailyReward.streak or 0
		else 		preClaimStreak = 0 end
		claimPending = true
		if not RemoteFailSafe.fireEvent("DAILY", "ClaimDailyReward") then
			claimPending = false
			restoreClaimButton()
			return
		end
		task.delay(3, function() if claimPending then restoreClaimButton() end end)
	end)

	claimBtn.MouseButton1Down:Connect(function()
		TweenService:Create(claimBtnScale, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
		claimBtn.Text = MicrocopyConfig.DailyRewardClaimButtonProgress
		if not claimShimmerGrad then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,240,180)), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))})
			g.Rotation = 25; g.Parent = claimBtn; claimShimmerGrad = g
			TweenService:Create(g, TweenInfo.new(0.55, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 385 }):Play()
		end
	end)

	local autoOpenFired = false

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		if root.Visible then refresh() end

		if not autoOpenFired and not root.Visible and type(data) == "table" and data.dailyReward then
			local lc = math.floor(tonumber((data.dailyReward :: any).lastClaim) or 0)
			if DailyRewardConfig.canClaimNow(lc) then
				autoOpenFired = true
				task.delay(1.5, function()
					if not root.Visible then
						MenuHub.open("daily")
					end
				end)
			end
		end

		if claimPending and type(data) == "table" and data.dailyReward then
			local newStreak = data.dailyReward.streak or 0
			if preClaimStreak ~= nil and newStreak ~= preClaimStreak then
				claimPending = false; restoreClaimButton()
				local dayIndex = DailyRewardConfig.nextDayIndex(preClaimStreak)
				local cycle = data.dailyReward.dailyCycle or 1
				local dayDef = STREAK_REWARDS[dayIndex]
				local lost = math.floor(tonumber(data.dailyReward.lastClaimLostStreak) or 0)
				local lostOpt: number? = if lost > 0 then lost else nil
				if dayDef then
					playCelebration(dayIndex, dayDef, DailyRewardConfig.getCycleMultiplier(cycle), player.MembershipType == Enum.MembershipType.Premium, lostOpt)
				end
				preClaimStreak = nil
			end
		end
	end)

	task.defer(refresh)
end

return DailyRewardPanel
