--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local DailyRewardConfig = require(DAC:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local DailyRewardPanel = {}

local STREAK_REWARDS = DailyRewardConfig.STREAK_REWARDS

local player = Players.LocalPlayer

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

	local multLabel = Instance.new("TextLabel")
	multLabel.Name = "MultLabel"
	multLabel.Size = UDim2.new(1, -8, 0, 28)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 16
	multLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	multLabel.TextXAlignment = Enum.TextXAlignment.Left
	multLabel.LayoutOrder = 0
	multLabel.Parent = scroll

	local calendarRow = Instance.new("Frame")
	calendarRow.Name = "CalendarRow"
	calendarRow.Size = UDim2.new(1, -8, 0, 128)
	calendarRow.BackgroundTransparency = 1
	calendarRow.LayoutOrder = 1
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
	premiumFrame.LayoutOrder = 2
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

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if root.Visible then
			refresh()
		end
	end)

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refresh()
		end
	end)

	UIHelpers.textButton(root, "Claim daily reward", Color3.fromRGB(255, 193, 7), 99, function()
		Remotes.getEvent("ClaimDailyReward"):FireServer()
	end)

	task.defer(refresh)
end

return DailyRewardPanel
