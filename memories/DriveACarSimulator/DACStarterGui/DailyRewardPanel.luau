--!strict

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
	return Color3.fromRGB(
		255,
		math.floor(180 - 140 * t),
		math.floor(40 - 30 * t)
	)
end

local function playCelebration(dayIndex: number, dayDef: any, mult: number, isPremium: boolean, lostStreak: number?)
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local isJackpot = dayIndex == Constants.MAX_DAILY_STREAK

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DailyRewardCelebration"
	overlay.DisplayOrder = 100
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.Parent = pg

	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.fromScale(1, 1)
	dismissBtn.BackgroundColor3 = Color3.new(0, 0, 0)
	dismissBtn.BackgroundTransparency = 0.5
	dismissBtn.Text = ""
	dismissBtn.ZIndex = 1
	dismissBtn.Parent = overlay

	local dayFlameColor = flameColorForDay(dayIndex)
	VFXFacade.purchaseCelebration("daily", nil)
	task.delay(0.05, function()
		local flashCol = if isJackpot then Color3.fromRGB(255, 200, 50) else dayFlameColor
		local flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BackgroundColor3 = flashCol
		flashFrame.BackgroundTransparency = 0.6
		flashFrame.ZIndex = 50
		flashFrame.Parent = overlay
		TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.45, function()
			flashFrame:Destroy()
		end)
	end)

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.8, 0, 0, 80)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, -0.15, 0)
	banner.BackgroundColor3 = if isJackpot then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(30, 30, 65)
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = if isJackpot then 40 else 32
	banner.TextColor3 = if isJackpot then Color3.fromRGB(50, 25, 0) else Color3.fromRGB(255, 230, 120)
	banner.TextStrokeTransparency = if isJackpot then 0.3 else 0.6
	banner.Text = if isJackpot then "JACKPOT DAY!" else ("Day " .. dayIndex .. " Reward!")
	banner.ZIndex = 10
	banner.Parent = overlay

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 16)
	bc.Parent = banner

	local bs = Instance.new("UIStroke")
	bs.Color = if isJackpot then Color3.fromRGB(255, 170, 0) else Color3.fromRGB(120, 160, 255)
	bs.Thickness = if isJackpot then 3 else 2
	bs.Parent = banner

	TweenService:Create(
		banner,
		TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.22, 0) }
	):Play()
	SoundFacade.playOneShot("level_up")

	local streakFlavor = Instance.new("TextLabel")
	streakFlavor.Size = UDim2.new(0.88, 0, 0, 44)
	streakFlavor.AnchorPoint = Vector2.new(0.5, 0)
	streakFlavor.Position = UDim2.new(0.5, 0, 0.26, 0)
	streakFlavor.BackgroundTransparency = 1
	streakFlavor.Font = Enum.Font.Gotham
	streakFlavor.TextSize = 16
	streakFlavor.TextColor3 = Color3.fromRGB(255, 205, 130)
	streakFlavor.TextWrapped = true
	streakFlavor.TextXAlignment = Enum.TextXAlignment.Center
	if lostStreak ~= nil and lostStreak > 0 then
		streakFlavor.TextColor3 = Color3.fromRGB(255, 120, 120)
		streakFlavor.Font = Enum.Font.GothamBold
		streakFlavor.TextSize = 17
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOLost):gsub("{STREAK}", tostring(lostStreak))
	elseif dayIndex == 7 or dayIndex == 14 or dayIndex == 30 then
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOMilestone)
	else
		local nextD = DailyRewardConfig.nextDayIndex(dayIndex)
		streakFlavor.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOTomorrow):gsub("{STREAK}", tostring(nextD))
	end
	streakFlavor.ZIndex = 10
	streakFlavor.Parent = overlay

	if isJackpot then
		VFXFacade.rebirthFlash(7)
	end

	local streakLbl = Instance.new("TextLabel")
	streakLbl.Size = UDim2.new(0, 200, 0, 30)
	streakLbl.AnchorPoint = Vector2.new(0.5, 0)
	streakLbl.Position = UDim2.new(0.5, 0, 0.30, 0)
	streakLbl.BackgroundTransparency = 1
	streakLbl.Font = Enum.Font.GothamBold
	streakLbl.TextSize = 18
	streakLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
	streakLbl.Text = "Day " .. dayIndex .. "/" .. Constants.MAX_DAILY_STREAK
	streakLbl.ZIndex = 10
	streakLbl.Parent = overlay

	local streakScale = Instance.new("UIScale")
	streakScale.Scale = 1
	streakScale.Parent = streakLbl
	TweenService:Create(streakScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
	task.delay(0.15, function()
		if streakScale.Parent then
			TweenService:Create(streakScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	local streakDotsFrame = Instance.new("Frame")
	streakDotsFrame.Name = "StreakDots"
	streakDotsFrame.Size = UDim2.new(0.7, 0, 0, 24)
	streakDotsFrame.AnchorPoint = Vector2.new(0.5, 0)
	streakDotsFrame.Position = UDim2.new(0.5, 0, 0.345, 0)
	streakDotsFrame.BackgroundTransparency = 1
	streakDotsFrame.ZIndex = 10
	streakDotsFrame.Parent = overlay
	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding = UDim.new(0, 6)
	dotsLayout.Parent = streakDotsFrame

	for i = 1, Constants.MAX_DAILY_STREAK do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i
		dot.Size = UDim2.fromOffset(20, 20)
		dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		dot.BorderSizePixel = 0
		dot.LayoutOrder = i
		dot.ZIndex = 10
		dot.Parent = streakDotsFrame
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot

		if i <= dayIndex then
			task.delay(0.3 + (i - 1) * 0.12, function()
				if not dot.Parent then return end
				local col = flameColorForDay(i)
				dot.BackgroundColor3 = col
				local dotGlow = Instance.new("UIStroke")
				dotGlow.Color = col
				dotGlow.Thickness = 2
				dotGlow.Transparency = 0.3
				dotGlow.Parent = dot
				local dotScale = Instance.new("UIScale")
				dotScale.Scale = 0.5
				dotScale.Parent = dot
				TweenService:Create(dotScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
				task.delay(0.2, function()
					if dotScale.Parent then
						TweenService:Create(dotScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
					end
				end)
			end)
		end
	end

	if isJackpot then
		task.delay(0.3 + Constants.MAX_DAILY_STREAK * 0.12 + 0.15, function()
			if not overlay.Parent then return end
			local maxLbl = Instance.new("TextLabel")
			maxLbl.Size = UDim2.new(0.8, 0, 0, 48)
			maxLbl.AnchorPoint = Vector2.new(0.5, 0.5)
			maxLbl.Position = UDim2.new(0.5, 0, 0.39, 0)
			maxLbl.BackgroundTransparency = 1
			maxLbl.Font = Enum.Font.GothamBlack
			maxLbl.TextSize = 38
			maxLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
			maxLbl.TextStrokeColor3 = Color3.fromRGB(80, 10, 10)
			maxLbl.TextStrokeTransparency = 0.25
			maxLbl.Text = "MAX STREAK!"
			maxLbl.ZIndex = 12
			maxLbl.Parent = overlay

			local maxScale = Instance.new("UIScale")
			maxScale.Scale = 0.3
			maxScale.Parent = maxLbl
			TweenService:Create(maxScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
			task.delay(0.35, function()
				if maxScale.Parent then
					TweenService:Create(maxScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
				end
			end)

			local rainbowGrad = Instance.new("UIGradient")
			rainbowGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 200, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 255, 120)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(160, 100, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 100, 200)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)),
			})
			rainbowGrad.Parent = maxLbl

			local rainbowStart = os.clock()
			local rainbowConn: RBXScriptConnection? = nil
			local RunService = game:GetService("RunService")
			rainbowConn = RunService.RenderStepped:Connect(function()
				if not maxLbl.Parent then
					if rainbowConn then rainbowConn:Disconnect() end
					return
				end
				rainbowGrad.Offset = Vector2.new(math.sin((os.clock() - rainbowStart) * 2) * 0.3, 0)
			end)

			SoundFacade.playOneShot("level_up")

			TweenService:Create(maxLbl, TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			task.delay(2.1, function()
				if rainbowConn then rainbowConn:Disconnect() end
				maxLbl:Destroy()
			end)
		end)
	end

	local rewards = dayDef.rewards
	local rewardContainer = Instance.new("Frame")
	rewardContainer.Size = UDim2.new(0.7, 0, 0, 0)
	rewardContainer.AutomaticSize = Enum.AutomaticSize.Y
	rewardContainer.AnchorPoint = Vector2.new(0.5, 0)
	rewardContainer.Position = UDim2.new(0.5, 0, 0.38, 0)
	rewardContainer.BackgroundTransparency = 1
	rewardContainer.ZIndex = 10
	rewardContainer.Parent = overlay

	local rLayout = Instance.new("UIListLayout")
	rLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rLayout.Padding = UDim.new(0, 8)
	rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rLayout.Parent = rewardContainer

	for idx, reward in rewards do
		task.delay(0.5 + (idx - 1) * 0.45, function()
			local amt = math.floor(reward.amount * mult + 0.5)

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.6, 0, 0, 30)
			card.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
			card.BackgroundTransparency = 0.12
			card.BorderSizePixel = 0
			card.LayoutOrder = idx
			card.ClipsDescendants = true
			card.ZIndex = 10
			card.Parent = rewardContainer

			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 10)
			cc.Parent = card

			local currColor = UIHelpers.currencyColor(reward.currency)

			local cs = Instance.new("UIStroke")
			cs.Color = currColor
			cs.Thickness = 2
			cs.Transparency = 0.35
			cs.Parent = card

			local rewardLbl = Instance.new("TextLabel")
			rewardLbl.Size = UDim2.new(1, -20, 1, 0)
			rewardLbl.Position = UDim2.new(0, 10, 0, 0)
			rewardLbl.BackgroundTransparency = 1
			rewardLbl.Font = Enum.Font.GothamBold
			rewardLbl.TextSize = 22
			rewardLbl.TextColor3 = currColor
			rewardLbl.TextStrokeTransparency = 0.4
			rewardLbl.Text = "+" .. tostring(amt) .. " " .. reward.currency
			rewardLbl.ZIndex = 12
			rewardLbl.Parent = card

			local shimmer = Instance.new("Frame")
			shimmer.Size = UDim2.fromScale(1, 1)
			shimmer.BackgroundColor3 = currColor
			shimmer.BackgroundTransparency = 0.88
			shimmer.ZIndex = 11
			shimmer.Parent = card

			local shimCorner = Instance.new("UICorner")
			shimCorner.CornerRadius = UDim.new(0, 10)
			shimCorner.Parent = shimmer

			local grad = Instance.new("UIGradient")
			grad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 1),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			grad.Rotation = 25
			grad.Offset = Vector2.new(-1, 0)
			grad.Parent = shimmer

			TweenService:Create(
				grad,
				TweenInfo.new(1.0, Enum.EasingStyle.Linear),
				{ Offset = Vector2.new(1, 0) }
			):Play()

			TweenService:Create(
				card,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(1, 0, 0, 50) }
			):Play()

			SoundFacade.playOneShot("currency")
			VFXFacade.currencyPopup(reward.currency, amt)
		end)
	end

	if isPremium then
		task.delay(0.5 + #rewards * 0.45 + 0.3, function()
			local premCard = Instance.new("Frame")
			premCard.Size = UDim2.new(0.5, 0, 0, 30)
			premCard.BackgroundColor3 = Color3.fromRGB(80, 40, 120)
			premCard.BackgroundTransparency = 0.1
			premCard.BorderSizePixel = 0
			premCard.LayoutOrder = #rewards + 1
			premCard.ClipsDescendants = true
			premCard.ZIndex = 10
			premCard.Parent = rewardContainer

			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(0, 10)
			pc.Parent = premCard

			local ps = Instance.new("UIStroke")
			ps.Color = Color3.fromRGB(200, 140, 255)
			ps.Thickness = 2
			ps.Parent = premCard

			local pGrad = Instance.new("UIGradient")
			pGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 200)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 200)),
			})
			pGrad.Parent = premCard

			TweenService:Create(
				pGrad,
				TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			):Play()

			local premLbl = Instance.new("TextLabel")
			premLbl.Size = UDim2.new(1, -10, 1, 0)
			premLbl.BackgroundTransparency = 1
			premLbl.Font = Enum.Font.GothamBold
			premLbl.TextSize = 18
			premLbl.TextColor3 = Color3.fromRGB(255, 220, 255)
			premLbl.TextStrokeTransparency = 0.3
			premLbl.Text = "PREMIUM BONUS"
			premLbl.ZIndex = 12
			premLbl.Parent = premCard

			TweenService:Create(
				premCard,
				TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(1, 0, 0, 50) }
			):Play()

			SoundFacade.playOneShot("purchase")
		end)
	end

	local totalDuration = 1.5 + #rewards * 0.45 + (if isPremium then 2.0 else 0.5) + 2.5

	local function closeOverlay()
		TweenService:Create(
			dismissBtn,
			TweenInfo.new(0.3),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			banner,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, -0.2, 0) }
		):Play()
		task.delay(0.5, function()
			if overlay.Parent then
				overlay:Destroy()
			end
		end)
	end

	task.delay(totalDuration, closeOverlay)
	dismissBtn.MouseButton1Click:Connect(closeOverlay)
end

local function fetchData(): any?
	local ok, data = pcall(function()
		return Remotes.getFunction("GetPlayerData"):InvokeServer()
	end)
	if ok then
		return data
	end
	return nil
end

function DailyRewardPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "DailyRoot")
	MenuHub.registerPanel("daily", root)
	UIHelpers.titleBar(root, "Daily Rewards", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)
	scroll.Size = UDim2.new(1, -24, 1, -108)

	local streakWarning = Instance.new("TextLabel")
	streakWarning.Name = "StreakFOMO"
	streakWarning.Size = UDim2.new(1, -8, 0, 0)
	streakWarning.AutomaticSize = Enum.AutomaticSize.Y
	streakWarning.BackgroundTransparency = 1
	streakWarning.Font = Enum.Font.GothamBold
	streakWarning.TextSize = 14
	streakWarning.TextColor3 = Color3.fromRGB(255, 160, 90)
	streakWarning.TextWrapped = true
	streakWarning.TextXAlignment = Enum.TextXAlignment.Left
	streakWarning.Visible = false
	streakWarning.LayoutOrder = 0
	streakWarning.Parent = scroll

	local multLabel = Instance.new("TextLabel")
	multLabel.Name = "MultLabel"
	multLabel.Size = UDim2.new(1, -8, 0, 28)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 16
	multLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	multLabel.TextXAlignment = Enum.TextXAlignment.Left
	multLabel.LayoutOrder = 1
	multLabel.Parent = scroll

	local calendarRow = Instance.new("Frame")
	calendarRow.Name = "CalendarRow"
	calendarRow.Size = UDim2.new(1, -8, 0, 128)
	calendarRow.BackgroundTransparency = 1
	calendarRow.LayoutOrder = 2
	calendarRow.Parent = scroll

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 4)
	rowLayout.Parent = calendarRow

	local dayCells: { Frame } = {}
	for i = 1, Constants.MAX_DAILY_STREAK do
		local cell = Instance.new("Frame")
		cell.Name = "Day" .. i
		cell.Size = UDim2.new(0, 76, 0, 120)
		cell.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
		cell.BorderSizePixel = 0
		cell.LayoutOrder = i
		cell.Parent = calendarRow

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = cell

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(100, 120, 200)
		stroke.Transparency = 0.5
		stroke.Parent = cell

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -6, 0, 22)
		title.Position = UDim2.new(0, 3, 0, 4)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextColor3 = Color3.fromRGB(230, 230, 255)
		title.Text = `Day {i}`
		title.Parent = cell

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.Size = UDim2.new(1, -8, 1, -30)
		body.Position = UDim2.new(0, 4, 0, 28)
		body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham
		body.TextSize = 11
		body.TextWrapped = true
		body.TextColor3 = Color3.fromRGB(200, 200, 220)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Parent = cell

		dayCells[i] = cell
	end

	local premiumFrame = Instance.new("Frame")
	premiumFrame.Name = "PremiumGift"
	premiumFrame.Size = UDim2.new(1, -8, 0, 96)
	premiumFrame.BackgroundColor3 = Color3.fromRGB(55, 45, 20)
	premiumFrame.BorderSizePixel = 0
	premiumFrame.LayoutOrder = 3
	premiumFrame.Parent = scroll

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 12)
	pCorner.Parent = premiumFrame

	local pStroke = Instance.new("UIStroke")
	pStroke.Name = "GoldStroke"
	pStroke.Thickness = 3
	pStroke.Color = Color3.fromRGB(255, 200, 60)
	pStroke.Parent = premiumFrame

	local pGrad = Instance.new("UIGradient")
	pGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
	})
	pGrad.Rotation = 35
	pGrad.Parent = premiumFrame

	TweenService:Create(
		pGrad,
		TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	):Play()

	local premiumTitle = Instance.new("TextLabel")
	premiumTitle.Size = UDim2.new(1, -12, 0, 22)
	premiumTitle.Position = UDim2.new(0, 8, 0, 8)
	premiumTitle.BackgroundTransparency = 1
	premiumTitle.Font = Enum.Font.GothamBold
	premiumTitle.TextSize = 15
	premiumTitle.TextColor3 = Color3.fromRGB(40, 30, 10)
	premiumTitle.TextXAlignment = Enum.TextXAlignment.Left
	premiumTitle.Text = "Premium Daily Gift Box"
	premiumTitle.Parent = premiumFrame

	local premiumBody = Instance.new("TextLabel")
	premiumBody.Name = "PremiumBody"
	premiumBody.Size = UDim2.new(1, -16, 0, 52)
	premiumBody.Position = UDim2.new(0, 8, 0, 34)
	premiumBody.BackgroundTransparency = 1
	premiumBody.Font = Enum.Font.Gotham
	premiumBody.TextSize = 12
	premiumBody.TextWrapped = true
	premiumBody.TextColor3 = Color3.fromRGB(35, 28, 8)
	premiumBody.TextXAlignment = Enum.TextXAlignment.Left
	premiumBody.TextYAlignment = Enum.TextYAlignment.Top
	premiumBody.Text =
		"Roblox Premium members roll a bonus gift each time they claim: coins, gems, crystals, a random egg from your current world, Speed Boost, or skulls."
	premiumBody.Parent = premiumFrame

	local function refresh()
		local data = fetchData()
		local streak = 0
		local cycle = 1
		if data and data.dailyReward then
			streak = data.dailyReward.streak or 0
			cycle = data.dailyReward.dailyCycle or 1
		end

		local mult = DailyRewardConfig.getCycleMultiplier(cycle)
		multLabel.Text = `Cycle #{cycle} • {mult}x reward multiplier (resets if you miss 2+ days)`

		if streak > 3 then
			streakWarning.Visible = true
			streakWarning.Text = MicrocopyConfig.pickVariant(MicrocopyConfig.StreakFOMOWarning):gsub("{STREAK}", tostring(streak))
		else
			streakWarning.Visible = false
		end

		local nextIdx = DailyRewardConfig.nextDayIndex(streak)
		for i = 1, Constants.MAX_DAILY_STREAK do
			local cell = dayCells[i]
			local dayDef = STREAK_REWARDS[i]
			local body = cell:FindFirstChild("Body") :: TextLabel
			if body and dayDef then
				body.Text = DailyRewardConfig.formatRewardLine(dayDef, mult)
			end
			local isNext = i == nextIdx
			cell.BackgroundColor3 = isNext and Color3.fromRGB(70, 55, 25) or Color3.fromRGB(40, 40, 70)
			local s = cell:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = isNext and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(100, 120, 200)
				s.Thickness = isNext and 2 or 1
			end
		end

		local isPremium = player.MembershipType == Enum.MembershipType.Premium
		premiumFrame.Visible = isPremium
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refresh()
		end
	end)

	local claimBtnOriginalText = "Claim daily reward"
	local claimBtnScale = Instance.new("UIScale")
	claimBtnScale.Scale = 1
	local claimShimmerGrad: UIGradient? = nil

	local function restoreClaimButton()
		claimBtnScale.Scale = 1
		claimBtn.Text = claimBtnOriginalText
		if claimShimmerGrad then
			claimShimmerGrad:Destroy()
			claimShimmerGrad = nil
		end
	end

	local claimBtn = UIHelpers.textButton(root, claimBtnOriginalText, Color3.fromRGB(255, 193, 7), 99, function()
		local data = fetchData()
		if data and data.dailyReward then
			preClaimStreak = data.dailyReward.streak or 0
		else
			preClaimStreak = 0
		end
		claimPending = true
		Remotes.getEvent("ClaimDailyReward"):FireServer()
		task.delay(3, function()
			if claimPending then
				restoreClaimButton()
			end
		end)
	end)
	claimBtnScale.Parent = claimBtn

	claimBtn.MouseButton1Down:Connect(function()
		TweenService:Create(claimBtnScale, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
		claimBtn.Text = "Claiming..."
		if not claimShimmerGrad then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 180)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			})
			g.Rotation = 25
			g.Parent = claimBtn
			claimShimmerGrad = g
			TweenService:Create(g, TweenInfo.new(0.55, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
				Rotation = 385,
			}):Play()
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		if root.Visible then
			refresh()
		end
		if claimPending and type(data) == "table" and data.dailyReward then
			local newStreak = data.dailyReward.streak or 0
			if preClaimStreak ~= nil and newStreak ~= preClaimStreak then
				claimPending = false
				restoreClaimButton()
				local dayIndex = DailyRewardConfig.nextDayIndex(preClaimStreak)
				local cycle = data.dailyReward.dailyCycle or 1
				local dayDef = STREAK_REWARDS[dayIndex]
				local lost = math.floor(tonumber(data.dailyReward.lastClaimLostStreak) or 0)
				local lostOpt: number? = if lost > 0 then lost else nil
				if dayDef then
					playCelebration(
						dayIndex,
						dayDef,
						DailyRewardConfig.getCycleMultiplier(cycle),
						player.MembershipType == Enum.MembershipType.Premium,
						lostOpt
					)
				end
				preClaimStreak = nil
			end
		end
	end)

	task.defer(refresh)
end

return DailyRewardPanel
