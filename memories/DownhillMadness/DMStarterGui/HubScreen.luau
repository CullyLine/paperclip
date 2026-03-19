--[[
	HubScreen — Builds the Hub ScreenGui programmatically.

	Dark semi-transparent panels, rounded corners, frosted-glass effect.
	Bold white typography, mobile-first with large tap targets.

	Layout: Play (top-left), Party Mode (bottom-left),
	        Garage (center, largest), Shop (top-right), Settings (bottom-right).
	Player list panel on the right edge showing server population.
]]

local TweenService = game:GetService("TweenService")

local HubScreen = {}

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.25
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local ACCENT_GREEN = Color3.fromRGB(0, 200, 100)
local DISABLED_COLOR = Color3.fromRGB(80, 80, 90)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(160, 160, 170)
local CORNER_RADIUS = UDim.new(0, 16)
local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type HubScreenInstance = {
	screenGui: ScreenGui,
	buttons: { [string]: TextButton },
	notification: TextLabel,
	playerListFrame: Frame,
	queueCountLabel: TextLabel,
	destroy: (self: HubScreenInstance) -> (),
	setVisible: (self: HubScreenInstance, visible: boolean) -> (),
	showNotification: (self: HubScreenInstance, text: string) -> (),
	updatePlayerList: (self: HubScreenInstance, players: { any }, queuedCount: number, totalCount: number) -> (),
	setPlayButtonQueued: (self: HubScreenInstance, isQueued: boolean) -> (),
	setProgression: (self: HubScreenInstance, level: number, xp: number, xpNeeded: number, scrap: number?) -> (),
}

local function createButton(
	name: string,
	label: string,
	subtitle: string?,
	position: UDim2,
	size: UDim2,
	enabled: boolean,
	parent: Frame
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Position = position
	btn.Size = size
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = PANEL_COLOR
	btn.BackgroundTransparency = PANEL_TRANSPARENCY
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = if enabled then ACCENT_COLOR else DISABLED_COLOR
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = btn

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 36)
	titleLabel.Position = if subtitle then UDim2.new(0.5, 0, 0.5, -14) else UDim2.new(0.5, 0, 0.5, 0)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = if enabled then TEXT_COLOR else SUBTEXT_COLOR
	titleLabel.TextSize = if name == "Garage" then 32 else 24
	titleLabel.TextScaled = false
	titleLabel.Text = label
	titleLabel.Parent = btn

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.Size = UDim2.new(1, -20, 0, 20)
		subLabel.Position = UDim2.new(0.5, 0, 0.5, 16)
		subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextColor3 = SUBTEXT_COLOR
		subLabel.TextSize = 14
		subLabel.Text = subtitle
		subLabel.Parent = btn
	end

	if enabled then
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, HOVER_TWEEN, { BackgroundTransparency = 0.1 }):Play()
			TweenService:Create(stroke, HOVER_TWEEN, { Transparency = 0 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, HOVER_TWEEN, { BackgroundTransparency = PANEL_TRANSPARENCY }):Play()
			TweenService:Create(stroke, HOVER_TWEEN, { Transparency = 0.4 }):Play()
		end)
	end

	return btn
end

function HubScreen.new(playerGui: PlayerGui): HubScreenInstance
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "GameTitle"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0.5, 0, 0, 40)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = TEXT_COLOR
	title.TextSize = 48
	title.Text = "DOWNHILL MADNESS"
	title.Parent = container

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = ACCENT_COLOR
	titleStroke.Thickness = 1.5
	titleStroke.Transparency = 0.3
	titleStroke.Parent = title

	local buttons: { [string]: TextButton } = {}

	-- Play: top-left (was Quick Play)
	buttons.Play = createButton(
		"Play", "PLAY", "Queue for next round",
		UDim2.new(0.28, 0, 0.35, 0),
		UDim2.new(0, 240, 0, 120),
		true, container
	)

	-- Party Mode: bottom-left
	buttons.PartyMode = createButton(
		"PartyMode", "PARTY MODE", "Coming Soon",
		UDim2.new(0.28, 0, 0.65, 0),
		UDim2.new(0, 240, 0, 120),
		false, container
	)

	-- Garage: center, largest
	buttons.Garage = createButton(
		"Garage", "GARAGE", "Coming Soon",
		UDim2.new(0.48, 0, 0.5, 0),
		UDim2.new(0, 300, 0, 180),
		false, container
	)

	-- Shop: top-right (shifted left to make room for player list)
	buttons.Shop = createButton(
		"Shop", "SHOP", "Coming Soon",
		UDim2.new(0.65, 0, 0.35, 0),
		UDim2.new(0, 200, 0, 120),
		false, container
	)

	-- Settings: bottom-right
	buttons.Settings = createButton(
		"Settings", "SETTINGS", "Coming Soon",
		UDim2.new(0.65, 0, 0.65, 0),
		UDim2.new(0, 200, 0, 120),
		false, container
	)

	-- ═══════════════════════════════════════════════════════════════
	-- PLAYER LIST PANEL (right side)
	-- ═══════════════════════════════════════════════════════════════
	local playerListPanel = Instance.new("Frame")
	playerListPanel.Name = "PlayerListPanel"
	playerListPanel.Size = UDim2.new(0, 220, 0.6, 0)
	playerListPanel.Position = UDim2.new(1, -20, 0.5, 0)
	playerListPanel.AnchorPoint = Vector2.new(1, 0.5)
	playerListPanel.BackgroundColor3 = PANEL_COLOR
	playerListPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	playerListPanel.BorderSizePixel = 0
	playerListPanel.Parent = container

	local plCorner = Instance.new("UICorner")
	plCorner.CornerRadius = CORNER_RADIUS
	plCorner.Parent = playerListPanel

	local plStroke = Instance.new("UIStroke")
	plStroke.Color = ACCENT_COLOR
	plStroke.Thickness = 1
	plStroke.Transparency = 0.5
	plStroke.Parent = playerListPanel

	-- Panel header
	local plHeader = Instance.new("TextLabel")
	plHeader.Name = "Header"
	plHeader.Size = UDim2.new(1, -16, 0, 30)
	plHeader.Position = UDim2.new(0.5, 0, 0, 8)
	plHeader.AnchorPoint = Vector2.new(0.5, 0)
	plHeader.BackgroundTransparency = 1
	plHeader.Font = Enum.Font.GothamBold
	plHeader.TextColor3 = TEXT_COLOR
	plHeader.TextSize = 16
	plHeader.Text = "PLAYERS"
	plHeader.Parent = playerListPanel

	-- Queue count label
	local queueCountLabel = Instance.new("TextLabel")
	queueCountLabel.Name = "QueueCount"
	queueCountLabel.Size = UDim2.new(1, -16, 0, 22)
	queueCountLabel.Position = UDim2.new(0.5, 0, 0, 38)
	queueCountLabel.AnchorPoint = Vector2.new(0.5, 0)
	queueCountLabel.BackgroundTransparency = 1
	queueCountLabel.Font = Enum.Font.Gotham
	queueCountLabel.TextColor3 = ACCENT_COLOR
	queueCountLabel.TextSize = 13
	queueCountLabel.Text = "0/0 queued"
	queueCountLabel.Parent = playerListPanel

	-- Scrolling frame for player entries
	local playerListScroll = Instance.new("ScrollingFrame")
	playerListScroll.Name = "PlayerList"
	playerListScroll.Size = UDim2.new(1, -16, 1, -72)
	playerListScroll.Position = UDim2.new(0.5, 0, 0, 64)
	playerListScroll.AnchorPoint = Vector2.new(0.5, 0)
	playerListScroll.BackgroundTransparency = 1
	playerListScroll.BorderSizePixel = 0
	playerListScroll.ScrollBarThickness = 4
	playerListScroll.ScrollBarImageColor3 = ACCENT_COLOR
	playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerListScroll.Parent = playerListPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = playerListScroll

	-- Notification toast
	local notification = Instance.new("TextLabel")
	notification.Name = "Notification"
	notification.Size = UDim2.new(0, 400, 0, 50)
	notification.Position = UDim2.new(0.5, 0, 0.88, 0)
	notification.AnchorPoint = Vector2.new(0.5, 0.5)
	notification.BackgroundColor3 = PANEL_COLOR
	notification.BackgroundTransparency = 0.15
	notification.BorderSizePixel = 0
	notification.Font = Enum.Font.GothamBold
	notification.TextColor3 = ACCENT_COLOR
	notification.TextSize = 18
	notification.Text = ""
	notification.Visible = false
	notification.Parent = container

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 12)
	notifCorner.Parent = notification

	local notifStroke = Instance.new("UIStroke")
	notifStroke.Color = ACCENT_COLOR
	notifStroke.Thickness = 1
	notifStroke.Transparency = 0.5
	notifStroke.Parent = notification

	-- ═══════════════════════════════════════════════════════════════
	-- PROGRESSION PANEL (bottom center)
	-- ═══════════════════════════════════════════════════════════════
	local progressPanel = Instance.new("Frame")
	progressPanel.Name = "ProgressPanel"
	progressPanel.Size = UDim2.new(0, 300, 0, 60)
	progressPanel.Position = UDim2.new(0.5, 0, 1, -30)
	progressPanel.AnchorPoint = Vector2.new(0.5, 1)
	progressPanel.BackgroundColor3 = PANEL_COLOR
	progressPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	progressPanel.BorderSizePixel = 0
	progressPanel.Parent = container

	local ppCorner = Instance.new("UICorner")
	ppCorner.CornerRadius = UDim.new(0, 12)
	ppCorner.Parent = progressPanel

	local ppStroke = Instance.new("UIStroke")
	ppStroke.Color = ACCENT_COLOR
	ppStroke.Thickness = 1
	ppStroke.Transparency = 0.5
	ppStroke.Parent = progressPanel

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(0, 80, 0, 24)
	levelLabel.Position = UDim2.new(0, 12, 0, 6)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextColor3 = ACCENT_COLOR
	levelLabel.TextSize = 18
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Text = "LVL 1"
	levelLabel.Parent = progressPanel

	local xpTextLabel = Instance.new("TextLabel")
	xpTextLabel.Name = "XPText"
	xpTextLabel.Size = UDim2.new(1, -100, 0, 16)
	xpTextLabel.Position = UDim2.new(0, 96, 0, 10)
	xpTextLabel.BackgroundTransparency = 1
	xpTextLabel.Font = Enum.Font.Gotham
	xpTextLabel.TextColor3 = SUBTEXT_COLOR
	xpTextLabel.TextSize = 12
	xpTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpTextLabel.Text = "0 / 100 XP"
	xpTextLabel.Parent = progressPanel

	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XPBarBg"
	xpBarBg.Size = UDim2.new(1, -24, 0, 10)
	xpBarBg.Position = UDim2.new(0, 12, 0, 36)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = progressPanel

	local xpBarBgCorner = Instance.new("UICorner")
	xpBarBgCorner.CornerRadius = UDim.new(0, 5)
	xpBarBgCorner.Parent = xpBarBg

	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "Fill"
	xpBarFill.Size = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = ACCENT_COLOR
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBg

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 5)
	xpFillCorner.Parent = xpBarFill

	local scrapLabel = Instance.new("TextLabel")
	scrapLabel.Name = "Scrap"
	scrapLabel.Size = UDim2.new(0, 120, 0, 24)
	scrapLabel.Position = UDim2.new(1, -12, 0, 6)
	scrapLabel.AnchorPoint = Vector2.new(1, 0)
	scrapLabel.BackgroundTransparency = 1
	scrapLabel.Font = Enum.Font.GothamBold
	scrapLabel.TextColor3 = Color3.fromRGB(200, 180, 60)
	scrapLabel.TextSize = 16
	scrapLabel.TextXAlignment = Enum.TextXAlignment.Right
	scrapLabel.Text = "0 Scrap"
	scrapLabel.Parent = progressPanel

	-- ═══════════════════════════════════════════════════════════════
	-- INSTANCE METHODS
	-- ═══════════════════════════════════════════════════════════════
	local self: HubScreenInstance = {
		screenGui = screenGui,
		buttons = buttons,
		notification = notification,
		playerListFrame = playerListScroll,
		queueCountLabel = queueCountLabel,
	} :: any

	function self:destroy()
		screenGui:Destroy()
	end

	function self:setVisible(visible: boolean)
		screenGui.Enabled = visible
	end

	function self:showNotification(text: string)
		notification.Text = text
		notification.Visible = true
		notification.TextTransparency = 0
		notification.BackgroundTransparency = 0.15

		task.delay(2, function()
			if notification and notification.Parent then
				TweenService:Create(notification, TweenInfo.new(0.5), {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
				task.delay(0.5, function()
					if notification and notification.Parent then
						notification.Visible = false
					end
				end)
			end
		end)
	end

	function self:updatePlayerList(players: { any }, queuedCount: number, totalCount: number)
		queueCountLabel.Text = queuedCount .. "/" .. totalCount .. " queued"

		-- Clear existing entries
		for _, child in playerListScroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for i, info in players do
			local entry = Instance.new("Frame")
			entry.Name = "Player_" .. i
			entry.Size = UDim2.new(1, 0, 0, 28)
			entry.BackgroundTransparency = 1
			entry.LayoutOrder = i
			entry.Parent = playerListScroll

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 0, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextColor3 = TEXT_COLOR
			nameLabel.TextSize = 13
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Text = info.name or "Player"
			nameLabel.Parent = entry

			local statusLabel = Instance.new("TextLabel")
			statusLabel.Size = UDim2.new(0.35, 0, 1, 0)
			statusLabel.Position = UDim2.new(0.65, 0, 0, 0)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Font = Enum.Font.Gotham
			statusLabel.TextSize = 11
			statusLabel.TextXAlignment = Enum.TextXAlignment.Right

			local status = info.status or "hub"
			if status == "queued" then
				statusLabel.TextColor3 = ACCENT_GREEN
				statusLabel.Text = "Queued"
			elseif status == "racing" then
				statusLabel.TextColor3 = ACCENT_COLOR
				statusLabel.Text = "Racing"
			elseif status == "spectating" then
				statusLabel.TextColor3 = SUBTEXT_COLOR
				statusLabel.Text = "Spectating"
			else
				statusLabel.TextColor3 = SUBTEXT_COLOR
				statusLabel.Text = "In Hub"
			end
			statusLabel.Parent = entry
		end
	end

	function self:setPlayButtonQueued(isQueued: boolean)
		local playBtn = buttons.Play
		local titleLabel = playBtn:FindFirstChild("Title") :: TextLabel?
		local subtitleLabel = playBtn:FindFirstChild("Subtitle") :: TextLabel?
		local stroke = playBtn:FindFirstChildOfClass("UIStroke")

		if isQueued then
			if titleLabel then
				titleLabel.Text = "CANCEL"
				titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			end
			if subtitleLabel then subtitleLabel.Text = "Leave queue" end
			if stroke then stroke.Color = Color3.fromRGB(255, 100, 100) end
			playBtn.BackgroundTransparency = 0.15
		else
			if titleLabel then
				titleLabel.Text = "PLAY"
				titleLabel.TextColor3 = TEXT_COLOR
			end
			if subtitleLabel then subtitleLabel.Text = "Queue for next round" end
			if stroke then stroke.Color = ACCENT_COLOR end
			playBtn.BackgroundTransparency = PANEL_TRANSPARENCY
		end
	end

	function self:setProgression(level: number, xp: number, xpNeeded: number, scrap: number?)
		levelLabel.Text = "LVL " .. level
		xpTextLabel.Text = xp .. " / " .. xpNeeded .. " XP"
		local fraction = if xpNeeded > 0 then math.clamp(xp / xpNeeded, 0, 1) else 0
		TweenService:Create(xpBarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(fraction, 0, 1, 0),
		}):Play()
		if scrap ~= nil then
			scrapLabel.Text = tostring(scrap) .. " Scrap"
		end
	end

	return self
end

return HubScreen
