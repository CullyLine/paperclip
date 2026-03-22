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
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local DailyRewardPanel = {}

local STREAK_REWARDS = DailyRewardConfig.STREAK_REWARDS
local player = Players.LocalPlayer
local preClaimStreak: number? = nil
local claimPending = false

local function flameColorForDay(day: number): Color3
	local t = math.clamp((day - 1) / 6, 0, 1)
	return Color3.fromRGB(255, math.floor(180 - 140 * t), math.floor(40 - 30 * t))
end

local function playCelebration(dayIndex: number, dayDef: any, mult: number, isPremium: boolean, lostStreak: number?)
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local isJackpot = dayIndex == Constants.MAX_DAILY_STREAK

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DailyRewardCelebration"
	overlay.DisplayOrder = 100; overlay.IgnoreGuiInset = true; overlay.ResetOnSpawn = false
	overlay.Parent = pg

	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.fromScale(1, 1); dismissBtn.BackgroundColor3 = Color3.new(0, 0, 0)
	dismissBtn.BackgroundTransparency = 0.5; dismissBtn.Text = ""; dismissBtn.ZIndex = 1
	dismissBtn.Parent = overlay

	local dayFlameColor = flameColorForDay(dayIndex)
	VFXFacade.purchaseCelebration("daily", nil)
	task.delay(0.05, function()
		local flashCol = if isJackpot then Color3.fromRGB(255, 200, 50) else dayFlameColor
		local flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.fromScale(1, 1); flashFrame.BackgroundColor3 = flashCol
		flashFrame.BackgroundTransparency = 0.6; flashFrame.ZIndex = 50; flashFrame.Parent = overlay
		TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function() flashFrame:Destroy() end)
	end)

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.8, 0, 0, 80); banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, -0.15, 0)
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
	TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.22, 0) }):Play()
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
	elseif dayIndex == 7 or dayIndex == 14 or dayIndex == 30 then
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOMilestone)
	else
		local nextD = DailyRewardConfig.nextDayIndex(dayIndex)
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOTomorrow):gsub("{STREAK}", tostring(nextD))
	end
	streakFlavor.Parent = overlay

	if isJackpot then VFXFacade.rebirthFlash(7) end

	local streakLbl = Instance.new("TextLabel")
	streakLbl.Size = UDim2.new(0, 200, 0, 30); streakLbl.AnchorPoint = Vector2.new(0.5, 0)
	streakLbl.Position = UDim2.new(0.5, 0, 0.30, 0); streakLbl.BackgroundTransparency = 1
	streakLbl.Font = Enum.Font.GothamBold; streakLbl.TextSize = 18
	streakLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
	streakLbl.Text = "Day " .. dayIndex .. "/" .. Constants.MAX_DAILY_STREAK; streakLbl.ZIndex = 10
	streakLbl.Parent = overlay
	local streakScale = Instance.new("UIScale"); streakScale.Scale = 1; streakScale.Parent = streakLbl
	TweenService:Create(streakScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
	task.delay(0.15, function() if streakScale.Parent then TweenService:Create(streakScale, TweenInfo.new(0.15), { Scale = 1 }):Play() end end)

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
			task.delay(0.3 + (i - 1) * 0.12, function()
				if not dot.Parent then return end
				local col = flameColorForDay(i)
				dot.BackgroundColor3 = col
				local dg = Instance.new("UIStroke"); dg.Color = col; dg.Thickness = 2; dg.Transparency = 0.3; dg.Parent = dot
				local ds = Instance.new("UIScale"); ds.Scale = 0.5; ds.Parent = dot
				TweenService:Create(ds, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
				task.delay(0.2, function() if ds.Parent then TweenService:Create(ds, TweenInfo.new(0.1), { Scale = 1 }):Play() end end)
			end)
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
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 50) }):Play()
			SoundFacade.playOneShot("currency")
			VFXFacade.currencyPopup(reward.currency, amt)
		end)
	end

	local totalDuration = 1.5 + #rewards * 0.45 + (if isPremium then 2.0 else 0.5) + 2.5
	local function closeOverlay()
		TweenService:Create(dismissBtn, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, -0.2, 0) }):Play()
		task.delay(0.5, function() if overlay.Parent then overlay:Destroy() end end)
	end
	task.delay(totalDuration, closeOverlay)
	dismissBtn.MouseButton1Click:Connect(closeOverlay)
end

local function fetchData(): any?
	local ok, data = pcall(function() return Remotes.getFunction("GetPlayerData"):InvokeServer() end)
	if ok then return data end
	return nil
end

function DailyRewardPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Daily") :: Frame
	MenuHub.registerPanel("daily", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	local closeBtn = titleBar:WaitForChild("Close") :: TextButton
	closeBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		root.Visible = false
	end)

	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame
	local streakWarning = scroll:WaitForChild("StreakFOMO") :: TextLabel
	local multLabel = scroll:WaitForChild("MultLabel") :: TextLabel
	local calendarRow = scroll:WaitForChild("CalendarRow") :: Frame
	local premiumFrame = scroll:WaitForChild("PremiumGift") :: Frame
	local claimBtn = root:WaitForChild("ClaimBtn") :: TextButton

	local dayCells: { Frame } = {}
	for i = 1, Constants.MAX_DAILY_STREAK do
		local cell = calendarRow:FindFirstChild("Day" .. i)
		if cell and cell:IsA("Frame") then dayCells[i] = cell end
	end

	local claimBtnOriginalText = "Claim daily reward"
	local claimBtnScale = Instance.new("UIScale"); claimBtnScale.Scale = 1; claimBtnScale.Parent = claimBtn
	local claimShimmerGrad: UIGradient? = nil

	local function restoreClaimButton()
		claimBtnScale.Scale = 1
		claimBtn.Text = claimBtnOriginalText
		if claimShimmerGrad then claimShimmerGrad:Destroy(); claimShimmerGrad = nil end
	end

	local function refresh()
		local data = fetchData()
		local streak = 0; local cycle = 1
		if data and data.dailyReward then
			streak = data.dailyReward.streak or 0
			cycle = data.dailyReward.dailyCycle or 1
		end
		local mult = DailyRewardConfig.getCycleMultiplier(cycle)
		multLabel.Text = `Cycle #{cycle} \u{2022} {mult}x reward multiplier (resets if you miss 2+ days)`
		if streak > 3 then
			streakWarning.Visible = true
			streakWarning.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOWarning):gsub("{STREAK}", tostring(streak))
		else
			streakWarning.Visible = false
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
		end
		premiumFrame.Visible = player.MembershipType == Enum.MembershipType.Premium
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then refresh() end
	end)

	claimBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		local data = fetchData()
		if data and data.dailyReward then preClaimStreak = data.dailyReward.streak or 0
		else preClaimStreak = 0 end
		claimPending = true
		Remotes.getEvent("ClaimDailyReward"):FireServer()
		task.delay(3, function() if claimPending then restoreClaimButton() end end)
	end)

	claimBtn.MouseButton1Down:Connect(function()
		TweenService:Create(claimBtnScale, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
		claimBtn.Text = "Claiming..."
		if not claimShimmerGrad then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,240,180)), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))})
			g.Rotation = 25; g.Parent = claimBtn; claimShimmerGrad = g
			TweenService:Create(g, TweenInfo.new(0.55, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 385 }):Play()
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		if root.Visible then refresh() end
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
