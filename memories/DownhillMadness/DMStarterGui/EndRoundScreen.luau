--[[
	EndRoundScreen — Builds the end-of-round results ScreenGui.

	Full-screen overlay showing:
	  - Final standings (Position, Player Name, Finish Time or DNF)
	  - 30s ready-up timer
	  - "Ready Up" and "Return to Hub" buttons

	Same dark panel / frosted glass style as HubScreen.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local EndRoundScreen = {}

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.15
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local READY_COLOR = Color3.fromRGB(0, 200, 100)
local HUB_COLOR = Color3.fromRGB(200, 60, 60)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(160, 160, 170)
local HIGHLIGHT_COLOR = Color3.fromRGB(0, 220, 120)
local DNF_COLOR = Color3.fromRGB(200, 80, 80)
local CORNER_RADIUS = UDim.new(0, 16)
local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer

export type EndRoundScreenInstance = {
	screenGui: ScreenGui,
	readyUpButton: TextButton,
	returnToHubButton: TextButton,
	destroy: (self: EndRoundScreenInstance) -> (),
	setVisible: (self: EndRoundScreenInstance, visible: boolean) -> (),
	setResults: (self: EndRoundScreenInstance, results: { any }) -> (),
	setTimer: (self: EndRoundScreenInstance, remaining: number) -> (),
	setReadyState: (self: EndRoundScreenInstance, isReady: boolean) -> (),
	showXPAward: (self: EndRoundScreenInstance, data: {
		xpGained: number,
		xpBreakdown: any?,
		scrapGained: number?,
		placement: number,
		leveledUp: boolean,
		newLevel: number,
		scrapBonuses: number?,
	}) -> (),
}

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	local ms = math.floor((seconds % 1) * 100)
	return string.format("%d:%02d.%02d", mins, secs, ms)
end

local function ordinal(n: number): string
	local mod100 = n % 100
	if mod100 >= 11 and mod100 <= 13 then
		return n .. "th"
	end
	local mod10 = n % 10
	if mod10 == 1 then return n .. "st"
	elseif mod10 == 2 then return n .. "nd"
	elseif mod10 == 3 then return n .. "rd"
	end
	return n .. "th"
end

function EndRoundScreen.new(playerGui: PlayerGui): EndRoundScreenInstance
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EndRoundScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 15
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	-- Main panel
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainPanel"
	mainPanel.Size = UDim2.new(0, 500, 0, 520)
	mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	mainPanel.BackgroundColor3 = PANEL_COLOR
	mainPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	mainPanel.BorderSizePixel = 0
	mainPanel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = CORNER_RADIUS
	panelCorner.Parent = mainPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = ACCENT_COLOR
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.3
	panelStroke.Parent = mainPanel

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 44)
	titleLabel.Position = UDim2.new(0, 0, 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = TEXT_COLOR
	titleLabel.TextSize = 28
	titleLabel.Text = "RACE RESULTS"
	titleLabel.Parent = mainPanel

	-- Timer
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(1, 0, 0, 24)
	timerLabel.Position = UDim2.new(0, 0, 0, 52)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.TextColor3 = SUBTEXT_COLOR
	timerLabel.TextSize = 16
	timerLabel.Text = "Next round in 30s"
	timerLabel.Parent = mainPanel

	-- Results container
	local resultsContainer = Instance.new("ScrollingFrame")
	resultsContainer.Name = "Results"
	resultsContainer.Size = UDim2.new(1, -32, 0, 330)
	resultsContainer.Position = UDim2.new(0, 16, 0, 82)
	resultsContainer.BackgroundTransparency = 1
	resultsContainer.BorderSizePixel = 0
	resultsContainer.ScrollBarThickness = 4
	resultsContainer.ScrollBarImageColor3 = ACCENT_COLOR
	resultsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultsContainer.Parent = mainPanel

	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Padding = UDim.new(0, 4)
	resultsLayout.Parent = resultsContainer

	-- Header row
	local headerRow = Instance.new("Frame")
	headerRow.Name = "Header"
	headerRow.Size = UDim2.new(1, 0, 0, 24)
	headerRow.BackgroundTransparency = 1
	headerRow.LayoutOrder = 0
	headerRow.Parent = resultsContainer

	local headerFields = { { "POS", 0.05 }, { "PLAYER", 0.2 }, { "TIME", 0.75 } }
	for _, field in headerFields do
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 80, 1, 0)
		lbl.Position = UDim2.new(field[2] :: number, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = ACCENT_COLOR
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = field[1] :: string
		lbl.Parent = headerRow
	end

	-- Buttons container
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, -32, 0, 56)
	buttonsFrame.Position = UDim2.new(0, 16, 1, -72)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = mainPanel

	local readyUpBtn = Instance.new("TextButton")
	readyUpBtn.Name = "ReadyUp"
	readyUpBtn.Size = UDim2.new(0.48, 0, 1, 0)
	readyUpBtn.Position = UDim2.new(0, 0, 0, 0)
	readyUpBtn.BackgroundColor3 = READY_COLOR
	readyUpBtn.BackgroundTransparency = 0.2
	readyUpBtn.BorderSizePixel = 0
	readyUpBtn.AutoButtonColor = false
	readyUpBtn.Font = Enum.Font.GothamBold
	readyUpBtn.TextColor3 = TEXT_COLOR
	readyUpBtn.TextSize = 20
	readyUpBtn.Text = "READY UP"
	readyUpBtn.Parent = buttonsFrame

	local readyCorner = Instance.new("UICorner")
	readyCorner.CornerRadius = CORNER_RADIUS
	readyCorner.Parent = readyUpBtn

	local readyStroke = Instance.new("UIStroke")
	readyStroke.Color = READY_COLOR
	readyStroke.Thickness = 2
	readyStroke.Parent = readyUpBtn

	readyUpBtn.MouseEnter:Connect(function()
		TweenService:Create(readyUpBtn, HOVER_TWEEN, { BackgroundTransparency = 0.05 }):Play()
	end)
	readyUpBtn.MouseLeave:Connect(function()
		TweenService:Create(readyUpBtn, HOVER_TWEEN, { BackgroundTransparency = 0.2 }):Play()
	end)

	local returnBtn = Instance.new("TextButton")
	returnBtn.Name = "ReturnToHub"
	returnBtn.Size = UDim2.new(0.48, 0, 1, 0)
	returnBtn.Position = UDim2.new(0.52, 0, 0, 0)
	returnBtn.BackgroundColor3 = HUB_COLOR
	returnBtn.BackgroundTransparency = 0.3
	returnBtn.BorderSizePixel = 0
	returnBtn.AutoButtonColor = false
	returnBtn.Font = Enum.Font.GothamBold
	returnBtn.TextColor3 = TEXT_COLOR
	returnBtn.TextSize = 20
	returnBtn.Text = "RETURN TO HUB"
	returnBtn.Parent = buttonsFrame

	local returnCorner = Instance.new("UICorner")
	returnCorner.CornerRadius = CORNER_RADIUS
	returnCorner.Parent = returnBtn

	local returnStroke = Instance.new("UIStroke")
	returnStroke.Color = HUB_COLOR
	returnStroke.Thickness = 2
	returnStroke.Parent = returnBtn

	returnBtn.MouseEnter:Connect(function()
		TweenService:Create(returnBtn, HOVER_TWEEN, { BackgroundTransparency = 0.15 }):Play()
	end)
	returnBtn.MouseLeave:Connect(function()
		TweenService:Create(returnBtn, HOVER_TWEEN, { BackgroundTransparency = 0.3 }):Play()
	end)

	-- ═══════════════════════════════════════════════════════════
	-- INSTANCE METHODS
	-- ═══════════════════════════════════════════════════════════

	local self: EndRoundScreenInstance = {} :: any

	self.screenGui = screenGui
	self.readyUpButton = readyUpBtn
	self.returnToHubButton = returnBtn

	function self:destroy()
		screenGui:Destroy()
	end

	function self:setVisible(visible: boolean)
		screenGui.Enabled = visible
	end

	function self:setResults(results)
		for _, child in resultsContainer:GetChildren() do
			if child:IsA("Frame") and child.Name ~= "Header" then
				child:Destroy()
			end
		end

		for i, result in results do
			local row = Instance.new("Frame")
			row.Name = "Result_" .. i
			row.Size = UDim2.new(1, 0, 0, 32)
			row.BackgroundTransparency = 1
			row.LayoutOrder = i
			row.Parent = resultsContainer

			local isLocal = result.userId == localPlayer.UserId
			local isDNF = result.finishTime == nil

			if isLocal then
				row.BackgroundColor3 = ACCENT_COLOR
				row.BackgroundTransparency = 0.85
				local rowCorner = Instance.new("UICorner")
				rowCorner.CornerRadius = UDim.new(0, 6)
				rowCorner.Parent = row
			end

			local posLabel = Instance.new("TextLabel")
			posLabel.Size = UDim2.new(0, 50, 1, 0)
			posLabel.Position = UDim2.new(0.05, 0, 0, 0)
			posLabel.BackgroundTransparency = 1
			posLabel.Font = Enum.Font.GothamBold
			posLabel.TextColor3 = if isLocal then HIGHLIGHT_COLOR else TEXT_COLOR
			posLabel.TextSize = 16
			posLabel.TextXAlignment = Enum.TextXAlignment.Left
			posLabel.Text = ordinal(result.placement or i)
			posLabel.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 200, 1, 0)
			nameLabel.Position = UDim2.new(0.2, 0, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = if isLocal then Enum.Font.GothamBold else Enum.Font.Gotham
			nameLabel.TextColor3 = if isLocal then TEXT_COLOR else SUBTEXT_COLOR
			nameLabel.TextSize = 15
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Text = result.playerName or "Player"
			nameLabel.Parent = row

			local timeLabel = Instance.new("TextLabel")
			timeLabel.Size = UDim2.new(0, 100, 1, 0)
			timeLabel.Position = UDim2.new(0.75, 0, 0, 0)
			timeLabel.BackgroundTransparency = 1
			timeLabel.Font = Enum.Font.GothamBold
			timeLabel.TextSize = 14
			timeLabel.TextXAlignment = Enum.TextXAlignment.Left
			timeLabel.Parent = row

			if isDNF then
				timeLabel.Text = "DNF"
				timeLabel.TextColor3 = DNF_COLOR
			else
				timeLabel.Text = formatTime(result.finishTime)
				timeLabel.TextColor3 = HIGHLIGHT_COLOR
			end
		end
	end

	function self:setTimer(remaining: number)
		local secs = math.ceil(remaining)
		timerLabel.Text = "Next round in " .. secs .. "s"
	end

	function self:setReadyState(isReady: boolean)
		if isReady then
			readyUpBtn.Text = "READY!"
			readyUpBtn.BackgroundColor3 = HIGHLIGHT_COLOR
			readyStroke.Color = HIGHLIGHT_COLOR
		else
			readyUpBtn.Text = "READY UP"
			readyUpBtn.BackgroundColor3 = READY_COLOR
			readyStroke.Color = READY_COLOR
		end
	end

	-- Rewards panel (overlays on top of results panel)
	local SCRAP_COLOR = Color3.fromRGB(200, 180, 60)

	local rewardPanel = Instance.new("Frame")
	rewardPanel.Name = "RewardPanel"
	rewardPanel.Size = UDim2.new(0, 280, 0, 200)
	rewardPanel.Position = UDim2.new(0.5, 0, 0, 60)
	rewardPanel.AnchorPoint = Vector2.new(0.5, 0)
	rewardPanel.BackgroundColor3 = PANEL_COLOR
	rewardPanel.BackgroundTransparency = 0.1
	rewardPanel.BorderSizePixel = 0
	rewardPanel.Visible = false
	rewardPanel.ZIndex = 20
	rewardPanel.Parent = screenGui

	local rpCorner = Instance.new("UICorner")
	rpCorner.CornerRadius = CORNER_RADIUS
	rpCorner.Parent = rewardPanel

	local rpStroke = Instance.new("UIStroke")
	rpStroke.Color = HIGHLIGHT_COLOR
	rpStroke.Thickness = 2
	rpStroke.Parent = rewardPanel

	local rewardTitle = Instance.new("TextLabel")
	rewardTitle.Name = "RewardTitle"
	rewardTitle.Size = UDim2.new(1, 0, 0, 24)
	rewardTitle.Position = UDim2.new(0.5, 0, 0, 8)
	rewardTitle.AnchorPoint = Vector2.new(0.5, 0)
	rewardTitle.BackgroundTransparency = 1
	rewardTitle.Font = Enum.Font.GothamBold
	rewardTitle.TextColor3 = TEXT_COLOR
	rewardTitle.TextSize = 16
	rewardTitle.Text = "RACE REWARDS"
	rewardTitle.ZIndex = 21
	rewardTitle.Parent = rewardPanel

	local breakdownFrame = Instance.new("Frame")
	breakdownFrame.Name = "Breakdown"
	breakdownFrame.Size = UDim2.new(1, -24, 1, -40)
	breakdownFrame.Position = UDim2.new(0, 12, 0, 36)
	breakdownFrame.BackgroundTransparency = 1
	breakdownFrame.ZIndex = 21
	breakdownFrame.Parent = rewardPanel

	local breakdownLayout = Instance.new("UIListLayout")
	breakdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
	breakdownLayout.Padding = UDim.new(0, 2)
	breakdownLayout.Parent = breakdownFrame

	local function createRewardLine(text: string, value: string, color: Color3, order: number): Frame
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 16)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.ZIndex = 21
		row.Parent = breakdownFrame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.65, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Gotham
		label.TextColor3 = SUBTEXT_COLOR
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.ZIndex = 21
		label.Parent = row

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(0.35, 0, 1, 0)
		val.Position = UDim2.new(0.65, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.GothamBold
		val.TextColor3 = color
		val.TextSize = 12
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Text = value
		val.ZIndex = 21
		val.Parent = row

		return row
	end

	function self:showXPAward(data)
		-- Clear old breakdown
		for _, child in breakdownFrame:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local lineOrder = 0

		-- XP breakdown
		local breakdown = data.xpBreakdown
		if breakdown then
			if breakdown.raceFinish > 0 then
				lineOrder += 1
				createRewardLine("Race Finish", "+" .. breakdown.raceFinish .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
			if breakdown.placementBonus > 0 then
				lineOrder += 1
				createRewardLine(ordinal(data.placement) .. " Place", "+" .. breakdown.placementBonus .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
			if breakdown.distance > 0 then
				lineOrder += 1
				createRewardLine("Distance", "+" .. breakdown.distance .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
			if breakdown.destruction > 0 then
				lineOrder += 1
				createRewardLine("Destruction", "+" .. breakdown.destruction .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
			if breakdown.cleanDriving > 0 then
				lineOrder += 1
				createRewardLine("Clean Driving", "+" .. breakdown.cleanDriving .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
			if breakdown.stylePoints > 0 then
				lineOrder += 1
				createRewardLine("Style Points", "+" .. breakdown.stylePoints .. " XP", HIGHLIGHT_COLOR, lineOrder)
			end
		end

		-- XP total
		lineOrder += 1
		createRewardLine("Total XP", "+" .. data.xpGained .. " XP", ACCENT_COLOR, lineOrder)

		-- Separator
		lineOrder += 1
		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, 0, 0, 1)
		sep.BackgroundColor3 = ACCENT_COLOR
		sep.BackgroundTransparency = 0.6
		sep.BorderSizePixel = 0
		sep.LayoutOrder = lineOrder
		sep.ZIndex = 21
		sep.Parent = breakdownFrame

		-- Scrap
		local scrapGained = data.scrapGained or 0
		if scrapGained > 0 then
			lineOrder += 1
			createRewardLine("Race Reward", "+" .. scrapGained .. " Scrap", SCRAP_COLOR, lineOrder)
		end

		local scrapBonuses = data.scrapBonuses or 0
		if scrapBonuses > 0 then
			lineOrder += 1
			createRewardLine("Level-Up Bonus", "+" .. scrapBonuses .. " Scrap", SCRAP_COLOR, lineOrder)
		end

		-- Level up
		if data.leveledUp then
			lineOrder += 1
			local lvlRow = Instance.new("Frame")
			lvlRow.Size = UDim2.new(1, 0, 0, 20)
			lvlRow.BackgroundTransparency = 1
			lvlRow.LayoutOrder = lineOrder
			lvlRow.ZIndex = 21
			lvlRow.Parent = breakdownFrame

			local lvlLabel = Instance.new("TextLabel")
			lvlLabel.Size = UDim2.new(1, 0, 1, 0)
			lvlLabel.BackgroundTransparency = 1
			lvlLabel.Font = Enum.Font.GothamBold
			lvlLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			lvlLabel.TextSize = 14
			lvlLabel.Text = "LEVEL UP! Level " .. data.newLevel
			lvlLabel.ZIndex = 21
			lvlLabel.Parent = lvlRow

			rpStroke.Color = Color3.fromRGB(255, 215, 0)
		else
			rpStroke.Color = HIGHLIGHT_COLOR
		end

		-- Size panel based on content
		local totalHeight = 44 + (lineOrder * 18) + 12
		rewardPanel.Size = UDim2.new(0, 280, 0, totalHeight)

		rewardPanel.Visible = true
		rewardPanel.BackgroundTransparency = 0.1

		rewardPanel.Position = UDim2.new(0.5, 0, 0, 30)
		TweenService:Create(rewardPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 60),
		}):Play()

		task.delay(6, function()
			if rewardPanel and rewardPanel.Parent then
				TweenService:Create(rewardPanel, TweenInfo.new(0.4), {
					BackgroundTransparency = 1,
				}):Play()
				for _, child in rewardPanel:GetDescendants() do
					if child:IsA("TextLabel") then
						TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
					elseif child:IsA("Frame") and child.BackgroundTransparency < 1 then
						TweenService:Create(child, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
					end
				end
				task.delay(0.45, function()
					if rewardPanel and rewardPanel.Parent then
						rewardPanel.Visible = false
						for _, child in rewardPanel:GetDescendants() do
							if child:IsA("TextLabel") then
								child.TextTransparency = 0
							end
						end
					end
				end)
			end
		end)
	end

	return self
end

return EndRoundScreen
