--[[
	DriverHUDScreen — Builds the in-race HUD ScreenGui programmatically.

	M0 subset:
	  - Top center: placement (large bold) + elapsed time
	  - Top right: mini leaderboard (Name + Position)
	  - Top left: race timer countdown (from 2:00)
	  - Full-screen 3-2-1-GO overlay

	Same dark panel / frosted glass style as HubScreen.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local DriverHUDScreen = {}

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.35
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(160, 160, 170)
local HIGHLIGHT_COLOR = Color3.fromRGB(0, 220, 120)
local CORNER_RADIUS = UDim.new(0, 12)

local localPlayer = Players.LocalPlayer

export type DriverHUDInstance = {
	screenGui: ScreenGui,
	destroy: (self: DriverHUDInstance) -> (),
	setVisible: (self: DriverHUDInstance, visible: boolean) -> (),
	setPlacement: (self: DriverHUDInstance, placement: number) -> (),
	setElapsedTime: (self: DriverHUDInstance, seconds: number) -> (),
	setRaceTimer: (self: DriverHUDInstance, remaining: number) -> (),
	updateLeaderboard: (self: DriverHUDInstance, entries: { { userId: number, name: string, progress: number, finishTime: number? } }) -> (),
	showCountdown: (self: DriverHUDInstance, value: number) -> (),
}

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function ordinal(n: number): string
	local suffix = "th"
	if n == 1 then suffix = "st"
	elseif n == 2 then suffix = "nd"
	elseif n == 3 then suffix = "rd"
	end
	return n .. suffix
end

function DriverHUDScreen.new(playerGui: PlayerGui): DriverHUDInstance
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DriverHUDScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- ═══════════════════════════════════════════════════════════
	-- TOP CENTER: Placement + Elapsed Time
	-- ═══════════════════════════════════════════════════════════
	local placementPanel = Instance.new("Frame")
	placementPanel.Name = "PlacementPanel"
	placementPanel.Size = UDim2.new(0, 200, 0, 80)
	placementPanel.Position = UDim2.new(0.5, 0, 0, 16)
	placementPanel.AnchorPoint = Vector2.new(0.5, 0)
	placementPanel.BackgroundColor3 = PANEL_COLOR
	placementPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	placementPanel.BorderSizePixel = 0
	placementPanel.Parent = screenGui

	local placementCorner = Instance.new("UICorner")
	placementCorner.CornerRadius = CORNER_RADIUS
	placementCorner.Parent = placementPanel

	local placementStroke = Instance.new("UIStroke")
	placementStroke.Color = ACCENT_COLOR
	placementStroke.Thickness = 1.5
	placementStroke.Transparency = 0.5
	placementStroke.Parent = placementPanel

	local placementLabel = Instance.new("TextLabel")
	placementLabel.Name = "Placement"
	placementLabel.Size = UDim2.new(1, 0, 0, 48)
	placementLabel.Position = UDim2.new(0.5, 0, 0, 4)
	placementLabel.AnchorPoint = Vector2.new(0.5, 0)
	placementLabel.BackgroundTransparency = 1
	placementLabel.Font = Enum.Font.GothamBold
	placementLabel.TextColor3 = TEXT_COLOR
	placementLabel.TextSize = 40
	placementLabel.Text = "1st"
	placementLabel.Parent = placementPanel

	local elapsedLabel = Instance.new("TextLabel")
	elapsedLabel.Name = "Elapsed"
	elapsedLabel.Size = UDim2.new(1, 0, 0, 22)
	elapsedLabel.Position = UDim2.new(0.5, 0, 1, -26)
	elapsedLabel.AnchorPoint = Vector2.new(0.5, 0)
	elapsedLabel.BackgroundTransparency = 1
	elapsedLabel.Font = Enum.Font.Gotham
	elapsedLabel.TextColor3 = SUBTEXT_COLOR
	elapsedLabel.TextSize = 16
	elapsedLabel.Text = "0:00"
	elapsedLabel.Parent = placementPanel

	-- ═══════════════════════════════════════════════════════════
	-- TOP LEFT: Race Timer (countdown from 2:00)
	-- ═══════════════════════════════════════════════════════════
	local timerPanel = Instance.new("Frame")
	timerPanel.Name = "TimerPanel"
	timerPanel.Size = UDim2.new(0, 140, 0, 56)
	timerPanel.Position = UDim2.new(0, 16, 0, 16)
	timerPanel.BackgroundColor3 = PANEL_COLOR
	timerPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	timerPanel.BorderSizePixel = 0
	timerPanel.Parent = screenGui

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = CORNER_RADIUS
	timerCorner.Parent = timerPanel

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = ACCENT_COLOR
	timerStroke.Thickness = 1.5
	timerStroke.Transparency = 0.5
	timerStroke.Parent = timerPanel

	local timerTitleLabel = Instance.new("TextLabel")
	timerTitleLabel.Name = "Title"
	timerTitleLabel.Size = UDim2.new(1, 0, 0, 18)
	timerTitleLabel.Position = UDim2.new(0.5, 0, 0, 6)
	timerTitleLabel.AnchorPoint = Vector2.new(0.5, 0)
	timerTitleLabel.BackgroundTransparency = 1
	timerTitleLabel.Font = Enum.Font.Gotham
	timerTitleLabel.TextColor3 = SUBTEXT_COLOR
	timerTitleLabel.TextSize = 12
	timerTitleLabel.Text = "TIME LEFT"
	timerTitleLabel.Parent = timerPanel

	local timerValueLabel = Instance.new("TextLabel")
	timerValueLabel.Name = "Value"
	timerValueLabel.Size = UDim2.new(1, 0, 0, 28)
	timerValueLabel.Position = UDim2.new(0.5, 0, 0, 24)
	timerValueLabel.AnchorPoint = Vector2.new(0.5, 0)
	timerValueLabel.BackgroundTransparency = 1
	timerValueLabel.Font = Enum.Font.GothamBold
	timerValueLabel.TextColor3 = TEXT_COLOR
	timerValueLabel.TextSize = 24
	timerValueLabel.Text = "2:00"
	timerValueLabel.Parent = timerPanel

	-- ═══════════════════════════════════════════════════════════
	-- TOP RIGHT: Mini Leaderboard
	-- ═══════════════════════════════════════════════════════════
	local leaderboardPanel = Instance.new("Frame")
	leaderboardPanel.Name = "LeaderboardPanel"
	leaderboardPanel.Size = UDim2.new(0, 220, 0, 300)
	leaderboardPanel.Position = UDim2.new(1, -16, 0, 16)
	leaderboardPanel.AnchorPoint = Vector2.new(1, 0)
	leaderboardPanel.BackgroundColor3 = PANEL_COLOR
	leaderboardPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	leaderboardPanel.BorderSizePixel = 0
	leaderboardPanel.ClipsDescendants = true
	leaderboardPanel.Parent = screenGui

	local lbCorner = Instance.new("UICorner")
	lbCorner.CornerRadius = CORNER_RADIUS
	lbCorner.Parent = leaderboardPanel

	local lbStroke = Instance.new("UIStroke")
	lbStroke.Color = ACCENT_COLOR
	lbStroke.Thickness = 1.5
	lbStroke.Transparency = 0.5
	lbStroke.Parent = leaderboardPanel

	local lbTitle = Instance.new("TextLabel")
	lbTitle.Name = "Title"
	lbTitle.Size = UDim2.new(1, 0, 0, 28)
	lbTitle.Position = UDim2.new(0, 0, 0, 4)
	lbTitle.BackgroundTransparency = 1
	lbTitle.Font = Enum.Font.GothamBold
	lbTitle.TextColor3 = ACCENT_COLOR
	lbTitle.TextSize = 13
	lbTitle.Text = "STANDINGS"
	lbTitle.Parent = leaderboardPanel

	local lbContainer = Instance.new("Frame")
	lbContainer.Name = "Entries"
	lbContainer.Size = UDim2.new(1, -12, 1, -36)
	lbContainer.Position = UDim2.new(0, 6, 0, 32)
	lbContainer.BackgroundTransparency = 1
	lbContainer.Parent = leaderboardPanel

	local lbLayout = Instance.new("UIListLayout")
	lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lbLayout.Padding = UDim.new(0, 2)
	lbLayout.Parent = lbContainer

	-- ═══════════════════════════════════════════════════════════
	-- COUNTDOWN OVERLAY (3-2-1-GO)
	-- ═══════════════════════════════════════════════════════════
	local countdownOverlay = Instance.new("Frame")
	countdownOverlay.Name = "CountdownOverlay"
	countdownOverlay.Size = UDim2.new(1, 0, 1, 0)
	countdownOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	countdownOverlay.BackgroundTransparency = 0.7
	countdownOverlay.BorderSizePixel = 0
	countdownOverlay.Visible = false
	countdownOverlay.ZIndex = 100
	countdownOverlay.Parent = screenGui

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownText"
	countdownLabel.Size = UDim2.new(1, 0, 1, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextColor3 = TEXT_COLOR
	countdownLabel.TextSize = 120
	countdownLabel.Text = "3"
	countdownLabel.ZIndex = 101
	countdownLabel.Parent = countdownOverlay

	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Color = ACCENT_COLOR
	countdownStroke.Thickness = 3
	countdownStroke.Transparency = 0.2
	countdownStroke.Parent = countdownLabel

	-- ═══════════════════════════════════════════════════════════
	-- INSTANCE METHODS
	-- ═══════════════════════════════════════════════════════════

	local self: DriverHUDInstance = {} :: any

	self.screenGui = screenGui

	function self:destroy()
		screenGui:Destroy()
	end

	function self:setVisible(visible: boolean)
		screenGui.Enabled = visible
	end

	function self:setPlacement(placement: number)
		placementLabel.Text = ordinal(placement)
	end

	function self:setElapsedTime(seconds: number)
		elapsedLabel.Text = formatTime(seconds)
	end

	function self:setRaceTimer(remaining: number)
		timerValueLabel.Text = formatTime(math.max(0, remaining))

		if remaining <= 30 then
			timerValueLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		else
			timerValueLabel.TextColor3 = TEXT_COLOR
		end
	end

	function self:updateLeaderboard(entries)
		for _, child in lbContainer:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for i, entry in entries do
			local row = Instance.new("Frame")
			row.Name = "Row_" .. i
			row.Size = UDim2.new(1, 0, 0, 22)
			row.BackgroundTransparency = 1
			row.LayoutOrder = i
			row.Parent = lbContainer

			local isLocal = entry.userId == localPlayer.UserId

			if isLocal then
				row.BackgroundColor3 = ACCENT_COLOR
				row.BackgroundTransparency = 0.85
				local rowCorner = Instance.new("UICorner")
				rowCorner.CornerRadius = UDim.new(0, 4)
				rowCorner.Parent = row
			end

			local posLabel = Instance.new("TextLabel")
			posLabel.Name = "Pos"
			posLabel.Size = UDim2.new(0, 30, 1, 0)
			posLabel.Position = UDim2.new(0, 4, 0, 0)
			posLabel.BackgroundTransparency = 1
			posLabel.Font = Enum.Font.GothamBold
			posLabel.TextColor3 = if isLocal then HIGHLIGHT_COLOR else SUBTEXT_COLOR
			posLabel.TextSize = 13
			posLabel.TextXAlignment = Enum.TextXAlignment.Left
			posLabel.Text = ordinal(i)
			posLabel.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.Size = UDim2.new(1, -80, 1, 0)
			nameLabel.Position = UDim2.new(0, 36, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = if isLocal then Enum.Font.GothamBold else Enum.Font.Gotham
			nameLabel.TextColor3 = if isLocal then TEXT_COLOR else SUBTEXT_COLOR
			nameLabel.TextSize = 13
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Text = entry.name
			nameLabel.Parent = row

			local progressLabel = Instance.new("TextLabel")
			progressLabel.Name = "Progress"
			progressLabel.Size = UDim2.new(0, 40, 1, 0)
			progressLabel.Position = UDim2.new(1, -4, 0, 0)
			progressLabel.AnchorPoint = Vector2.new(1, 0)
			progressLabel.BackgroundTransparency = 1
			progressLabel.Font = Enum.Font.Gotham
			progressLabel.TextColor3 = SUBTEXT_COLOR
			progressLabel.TextSize = 11
			progressLabel.TextXAlignment = Enum.TextXAlignment.Right
			progressLabel.Parent = row

			if entry.finishTime then
				progressLabel.Text = formatTime(entry.finishTime)
				progressLabel.TextColor3 = HIGHLIGHT_COLOR
			else
				progressLabel.Text = math.floor(entry.progress) .. "%"
			end
		end
	end

	function self:showCountdown(value: number)
		if value > 0 then
			countdownOverlay.Visible = true
			countdownLabel.Text = tostring(value)
			countdownLabel.TextSize = 120
			countdownLabel.TextTransparency = 0

			TweenService:Create(countdownLabel, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				TextSize = 160,
			}):Play()
		elseif value == 0 then
			countdownLabel.Text = "GO!"
			countdownLabel.TextColor3 = HIGHLIGHT_COLOR
			countdownLabel.TextSize = 100
			countdownLabel.TextTransparency = 0

			TweenService:Create(countdownLabel, TweenInfo.new(0.4), {
				TextSize = 180,
			}):Play()

			task.delay(0.6, function()
				TweenService:Create(countdownLabel, TweenInfo.new(0.3), {
					TextTransparency = 1,
				}):Play()
				TweenService:Create(countdownOverlay, TweenInfo.new(0.3), {
					BackgroundTransparency = 1,
				}):Play()
				task.delay(0.35, function()
					countdownOverlay.Visible = false
					countdownOverlay.BackgroundTransparency = 0.7
					countdownLabel.TextColor3 = TEXT_COLOR
				end)
			end)
		end
	end

	return self
end

return DriverHUDScreen
