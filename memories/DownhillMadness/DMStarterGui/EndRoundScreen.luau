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

	return self
end

return EndRoundScreen
