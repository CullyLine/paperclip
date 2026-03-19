--[[
	PreRoundScreen — M1 vehicle selection ScreenGui.

	Shows 3 vehicle type cards (from VehicleRegistry) with stat bars,
	lock/unlock indicators, 3D viewport preview, and confirm button.
	Dark panel / frosted glass style matching HubScreen.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local PreRoundScreen = {}

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.25
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local ACCENT_CONFIRM = Color3.fromRGB(30, 200, 80)
local SELECTED_COLOR = Color3.fromRGB(0, 180, 255)
local LOCKED_COLOR = Color3.fromRGB(55, 55, 60)
local AVAILABLE_COLOR = Color3.fromRGB(40, 40, 46)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(160, 160, 170)
local LOCKED_TEXT_COLOR = Color3.fromRGB(90, 90, 100)
local STAT_BAR_BG = Color3.fromRGB(35, 35, 40)
local STAT_BAR_FILL = Color3.fromRGB(0, 180, 255)
local CORNER_RADIUS = UDim.new(0, 16)
local CORNER_RADIUS_SMALL = UDim.new(0, 10)
local CORNER_RADIUS_TINY = UDim.new(0, 4)
local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local STAT_LABELS = { "SPD", "HND", "WGT", "DUR" }
local STAT_KEYS = { "speed", "handling", "weight", "durability" }
local STAT_MAX = 10

export type VehicleCellState = "available" | "selected" | "locked"

export type PreRoundScreenInstance = {
	screenGui: ScreenGui,
	viewportFrame: ViewportFrame,
	viewportCamera: Camera,
	countdownLabel: TextLabel,
	confirmButton: TextButton,
	vehicleCards: { [string]: Frame },
	vehicleNameLabel: TextLabel,
	vehicleTaglineLabel: TextLabel,
	vehicleDescLabel: TextLabel,
	onVehicleSelected: BindableEvent,
	onConfirm: BindableEvent,
	destroy: (self: PreRoundScreenInstance) -> (),
	setVisible: (self: PreRoundScreenInstance, visible: boolean) -> (),
	setCountdown: (self: PreRoundScreenInstance, seconds: number) -> (),
	setVehicleState: (self: PreRoundScreenInstance, vehicleId: string, state: VehicleCellState) -> (),
	setConfirmEnabled: (self: PreRoundScreenInstance, enabled: boolean) -> (),
	setVehicleModel: (self: PreRoundScreenInstance, model: Model?) -> (),
	setVehicleInfo: (self: PreRoundScreenInstance, displayName: string, tagline: string, description: string) -> (),
	buildCards: (self: PreRoundScreenInstance, vehicles: { any }, playerLevel: number, playerScrap: number?, unlockedVehicles: { string }?) -> (),
}

local function createStatBar(statName: string, value: number, parent: Frame, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. statName
	row.Size = UDim2.new(1, 0, 0, 14)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 30, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = SUBTEXT_COLOR
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = statName
	label.Parent = row

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -36, 0, 6)
	barBg.Position = UDim2.new(0, 34, 0.5, 0)
	barBg.AnchorPoint = Vector2.new(0, 0.5)
	barBg.BackgroundColor3 = STAT_BAR_BG
	barBg.BorderSizePixel = 0
	barBg.Parent = row

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = CORNER_RADIUS_TINY
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(math.clamp(value / STAT_MAX, 0, 1), 0, 1, 0)
	barFill.BackgroundColor3 = STAT_BAR_FILL
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = CORNER_RADIUS_TINY
	fillCorner.Parent = barFill

	return row
end

local function createVehicleCard(vehicleData: any, isUnlocked: boolean, parent: Frame, canPurchase: boolean?): Frame
	local card = Instance.new("Frame")
	card.Name = "Card_" .. vehicleData.id
	card.BackgroundColor3 = if isUnlocked then AVAILABLE_COLOR else LOCKED_COLOR
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS_SMALL
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectionStroke"
	stroke.Color = ACCENT_COLOR
	stroke.Thickness = 0
	stroke.Transparency = 0
	stroke.Parent = card

	-- Vehicle name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "VehicleName"
	nameLabel.Size = UDim2.new(1, -16, 0, 24)
	nameLabel.Position = UDim2.new(0, 8, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = if isUnlocked then TEXT_COLOR else LOCKED_TEXT_COLOR
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = vehicleData.displayName
	nameLabel.Parent = card

	-- Tagline
	local taglineLabel = Instance.new("TextLabel")
	taglineLabel.Name = "Tagline"
	taglineLabel.Size = UDim2.new(1, -16, 0, 14)
	taglineLabel.Position = UDim2.new(0, 8, 0, 32)
	taglineLabel.BackgroundTransparency = 1
	taglineLabel.Font = Enum.Font.Gotham
	taglineLabel.TextColor3 = if isUnlocked then SUBTEXT_COLOR else LOCKED_TEXT_COLOR
	taglineLabel.TextSize = 11
	taglineLabel.TextXAlignment = Enum.TextXAlignment.Left
	taglineLabel.Text = vehicleData.tagline
	taglineLabel.Parent = card

	-- Stats container
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.Size = UDim2.new(1, -16, 0, 70)
	statsFrame.Position = UDim2.new(0, 8, 0, 52)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Parent = card

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 4)
	statsLayout.Parent = statsFrame

	for i, key in STAT_KEYS do
		createStatBar(STAT_LABELS[i], vehicleData.stats[key], statsFrame, i)
	end

	-- Lock overlay / Purchase info
	if not isUnlocked then
		local lockOverlay = Instance.new("Frame")
		lockOverlay.Name = "LockOverlay"
		lockOverlay.Size = UDim2.new(1, 0, 0, 34)
		lockOverlay.Position = UDim2.new(0, 0, 1, -42)
		lockOverlay.BackgroundTransparency = 1
		lockOverlay.Parent = card

		local lockText = "LVL " .. vehicleData.unlockLevel
		if vehicleData.scrapCost and vehicleData.scrapCost > 0 then
			lockText = lockText .. " + " .. vehicleData.scrapCost .. " Scrap"
		end

		local lockIcon = Instance.new("TextLabel")
		lockIcon.Name = "LockText"
		lockIcon.Size = UDim2.new(1, -16, 0, 14)
		lockIcon.Position = UDim2.new(0, 8, 0, 0)
		lockIcon.BackgroundTransparency = 1
		lockIcon.Font = Enum.Font.GothamBold
		lockIcon.TextColor3 = Color3.fromRGB(200, 160, 60)
		lockIcon.TextSize = 12
		lockIcon.TextXAlignment = Enum.TextXAlignment.Left
		lockIcon.Text = lockText
		lockIcon.Parent = lockOverlay

		if canPurchase then
			local buyBtn = Instance.new("TextButton")
			buyBtn.Name = "BuyButton"
			buyBtn.Size = UDim2.new(0, 70, 0, 18)
			buyBtn.Position = UDim2.new(1, -8, 0, 0)
			buyBtn.AnchorPoint = Vector2.new(1, 0)
			buyBtn.BackgroundColor3 = Color3.fromRGB(200, 180, 60)
			buyBtn.BackgroundTransparency = 0.2
			buyBtn.BorderSizePixel = 0
			buyBtn.Font = Enum.Font.GothamBold
			buyBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
			buyBtn.TextSize = 11
			buyBtn.Text = "BUY"
			buyBtn.ZIndex = 5
			buyBtn.Parent = lockOverlay

			local buyCorner = Instance.new("UICorner")
			buyCorner.CornerRadius = UDim.new(0, 4)
			buyCorner.Parent = buyBtn
		end
	end

	-- Click detector
	local clickDetector = Instance.new("TextButton")
	clickDetector.Name = "ClickDetector"
	clickDetector.Size = UDim2.new(1, 0, 1, 0)
	clickDetector.BackgroundTransparency = 1
	clickDetector.Text = ""
	clickDetector.ZIndex = 4
	clickDetector.Active = isUnlocked
	clickDetector.Parent = card

	return card
end

function PreRoundScreen.new(playerGui: PlayerGui): PreRoundScreenInstance
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PreRoundScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	backdrop.BackgroundTransparency = 0.15
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0.5, 0, 0, 30)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = TEXT_COLOR
	titleLabel.TextSize = 32
	titleLabel.Text = "SELECT YOUR VEHICLE"
	titleLabel.Parent = backdrop

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = ACCENT_COLOR
	titleStroke.Thickness = 1
	titleStroke.Transparency = 0.4
	titleStroke.Parent = titleLabel

	-- Countdown timer
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.Size = UDim2.new(0, 120, 0, 50)
	countdownLabel.Position = UDim2.new(0.5, 0, 0, 80)
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0)
	countdownLabel.BackgroundColor3 = PANEL_COLOR
	countdownLabel.BackgroundTransparency = PANEL_TRANSPARENCY
	countdownLabel.BorderSizePixel = 0
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextColor3 = ACCENT_COLOR
	countdownLabel.TextSize = 28
	countdownLabel.Text = "10"
	countdownLabel.Parent = backdrop

	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = CORNER_RADIUS
	countdownCorner.Parent = countdownLabel

	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Color = ACCENT_COLOR
	countdownStroke.Thickness = 2
	countdownStroke.Transparency = 0.3
	countdownStroke.Parent = countdownLabel

	-- Main content area
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -60, 1, -180)
	contentFrame.Position = UDim2.new(0.5, 0, 0, 145)
	contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = backdrop

	-- Left side: 3D viewport + vehicle info + confirm button
	local viewportPanel = Instance.new("Frame")
	viewportPanel.Name = "ViewportPanel"
	viewportPanel.Size = UDim2.new(0.45, -10, 1, -70)
	viewportPanel.Position = UDim2.new(0, 0, 0, 0)
	viewportPanel.BackgroundColor3 = PANEL_COLOR
	viewportPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	viewportPanel.BorderSizePixel = 0
	viewportPanel.Parent = contentFrame

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = CORNER_RADIUS
	vpCorner.Parent = viewportPanel

	local vpStroke = Instance.new("UIStroke")
	vpStroke.Color = ACCENT_COLOR
	vpStroke.Thickness = 1.5
	vpStroke.Transparency = 0.5
	vpStroke.Parent = viewportPanel

	-- No-selection placeholder
	local noSelectionLabel = Instance.new("TextLabel")
	noSelectionLabel.Name = "NoSelection"
	noSelectionLabel.Size = UDim2.new(1, -20, 0, 30)
	noSelectionLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
	noSelectionLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	noSelectionLabel.BackgroundTransparency = 1
	noSelectionLabel.Font = Enum.Font.Gotham
	noSelectionLabel.TextColor3 = SUBTEXT_COLOR
	noSelectionLabel.TextSize = 18
	noSelectionLabel.Text = "Select a vehicle from the right"
	noSelectionLabel.Parent = viewportPanel

	-- ViewportFrame
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "VehicleViewport"
	viewportFrame.Size = UDim2.new(1, -20, 0.6, 0)
	viewportFrame.Position = UDim2.new(0.5, 0, 0, 10)
	viewportFrame.AnchorPoint = Vector2.new(0.5, 0)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.Ambient = Color3.fromRGB(140, 140, 150)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)
	viewportFrame.Parent = viewportPanel

	local viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 50
	viewportCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = viewportCamera

	-- Vehicle info area below viewport
	local vehicleNameLabel = Instance.new("TextLabel")
	vehicleNameLabel.Name = "SelectedName"
	vehicleNameLabel.Size = UDim2.new(1, -20, 0, 24)
	vehicleNameLabel.Position = UDim2.new(0.5, 0, 0.62, 4)
	vehicleNameLabel.AnchorPoint = Vector2.new(0.5, 0)
	vehicleNameLabel.BackgroundTransparency = 1
	vehicleNameLabel.Font = Enum.Font.GothamBold
	vehicleNameLabel.TextColor3 = ACCENT_COLOR
	vehicleNameLabel.TextSize = 20
	vehicleNameLabel.Text = ""
	vehicleNameLabel.Visible = false
	vehicleNameLabel.Parent = viewportPanel

	local vehicleTaglineLabel = Instance.new("TextLabel")
	vehicleTaglineLabel.Name = "SelectedTagline"
	vehicleTaglineLabel.Size = UDim2.new(1, -20, 0, 16)
	vehicleTaglineLabel.Position = UDim2.new(0.5, 0, 0.62, 30)
	vehicleTaglineLabel.AnchorPoint = Vector2.new(0.5, 0)
	vehicleTaglineLabel.BackgroundTransparency = 1
	vehicleTaglineLabel.Font = Enum.Font.Gotham
	vehicleTaglineLabel.TextColor3 = SUBTEXT_COLOR
	vehicleTaglineLabel.TextSize = 13
	vehicleTaglineLabel.Text = ""
	vehicleTaglineLabel.Visible = false
	vehicleTaglineLabel.Parent = viewportPanel

	local vehicleDescLabel = Instance.new("TextLabel")
	vehicleDescLabel.Name = "SelectedDesc"
	vehicleDescLabel.Size = UDim2.new(1, -20, 0, 60)
	vehicleDescLabel.Position = UDim2.new(0.5, 0, 0.62, 50)
	vehicleDescLabel.AnchorPoint = Vector2.new(0.5, 0)
	vehicleDescLabel.BackgroundTransparency = 1
	vehicleDescLabel.Font = Enum.Font.Gotham
	vehicleDescLabel.TextColor3 = SUBTEXT_COLOR
	vehicleDescLabel.TextSize = 11
	vehicleDescLabel.TextWrapped = true
	vehicleDescLabel.TextYAlignment = Enum.TextYAlignment.Top
	vehicleDescLabel.Text = ""
	vehicleDescLabel.Visible = false
	vehicleDescLabel.Parent = viewportPanel

	-- Confirm button
	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "ConfirmButton"
	confirmButton.Size = UDim2.new(0.45, -10, 0, 55)
	confirmButton.Position = UDim2.new(0, 0, 1, -55)
	confirmButton.BackgroundColor3 = ACCENT_CONFIRM
	confirmButton.BackgroundTransparency = 0.15
	confirmButton.BorderSizePixel = 0
	confirmButton.AutoButtonColor = false
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.TextColor3 = TEXT_COLOR
	confirmButton.TextSize = 22
	confirmButton.Text = "CONFIRM"
	confirmButton.Parent = contentFrame

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = CORNER_RADIUS
	confirmCorner.Parent = confirmButton

	local confirmStroke = Instance.new("UIStroke")
	confirmStroke.Name = "ConfirmStroke"
	confirmStroke.Color = ACCENT_CONFIRM
	confirmStroke.Thickness = 2
	confirmStroke.Transparency = 0.3
	confirmStroke.Parent = confirmButton

	confirmButton.MouseEnter:Connect(function()
		if confirmButton.Active then
			TweenService:Create(confirmButton, HOVER_TWEEN, { BackgroundTransparency = 0 }):Play()
		end
	end)
	confirmButton.MouseLeave:Connect(function()
		TweenService:Create(confirmButton, HOVER_TWEEN, { BackgroundTransparency = 0.15 }):Play()
	end)

	-- Right side: vehicle cards
	local cardsPanel = Instance.new("Frame")
	cardsPanel.Name = "CardsPanel"
	cardsPanel.Size = UDim2.new(0.55, -10, 1, 0)
	cardsPanel.Position = UDim2.new(0.45, 10, 0, 0)
	cardsPanel.BackgroundColor3 = PANEL_COLOR
	cardsPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	cardsPanel.BorderSizePixel = 0
	cardsPanel.ClipsDescendants = true
	cardsPanel.Parent = contentFrame

	local cardsCorner = Instance.new("UICorner")
	cardsCorner.CornerRadius = CORNER_RADIUS
	cardsCorner.Parent = cardsPanel

	local cardsStroke = Instance.new("UIStroke")
	cardsStroke.Color = ACCENT_COLOR
	cardsStroke.Thickness = 1.5
	cardsStroke.Transparency = 0.5
	cardsStroke.Parent = cardsPanel

	local cardsTitle = Instance.new("TextLabel")
	cardsTitle.Name = "CardsTitle"
	cardsTitle.Size = UDim2.new(1, -20, 0, 30)
	cardsTitle.Position = UDim2.new(0, 10, 0, 8)
	cardsTitle.BackgroundTransparency = 1
	cardsTitle.Font = Enum.Font.GothamBold
	cardsTitle.TextColor3 = TEXT_COLOR
	cardsTitle.TextSize = 16
	cardsTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardsTitle.Text = "VEHICLES"
	cardsTitle.Parent = cardsPanel

	local cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -20, 1, -48)
	cardContainer.Position = UDim2.new(0, 10, 0, 42)
	cardContainer.BackgroundTransparency = 1
	cardContainer.Parent = cardsPanel

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.Parent = cardContainer

	-- BindableEvents
	local onVehicleSelected = Instance.new("BindableEvent")
	onVehicleSelected.Name = "OnVehicleSelected"
	onVehicleSelected.Parent = screenGui

	local onConfirm = Instance.new("BindableEvent")
	onConfirm.Name = "OnConfirm"
	onConfirm.Parent = screenGui

	confirmButton.Activated:Connect(function()
		onConfirm:Fire()
	end)

	-- Turntable rotation
	local currentModel: Model? = nil
	local turntableAngle = 0
	local turntableConnection: RBXScriptConnection? = nil

	local vehicleCards: { [string]: Frame } = {}

	local self: PreRoundScreenInstance = {
		screenGui = screenGui,
		viewportFrame = viewportFrame,
		viewportCamera = viewportCamera,
		countdownLabel = countdownLabel,
		confirmButton = confirmButton,
		vehicleCards = vehicleCards,
		vehicleNameLabel = vehicleNameLabel,
		vehicleTaglineLabel = vehicleTaglineLabel,
		vehicleDescLabel = vehicleDescLabel,
		onVehicleSelected = onVehicleSelected,
		onConfirm = onConfirm,
	} :: any

	function self:destroy()
		if turntableConnection then
			turntableConnection:Disconnect()
			turntableConnection = nil
		end
		onVehicleSelected:Destroy()
		onConfirm:Destroy()
		screenGui:Destroy()
	end

	function self:setVisible(visible: boolean)
		screenGui.Enabled = visible
	end

	function self:setCountdown(seconds: number)
		countdownLabel.Text = tostring(math.ceil(seconds))
		if seconds <= 3 then
			countdownLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			local ref = countdownLabel:FindFirstChildOfClass("UIStroke")
			if ref then ref.Color = Color3.fromRGB(255, 80, 80) end
		else
			countdownLabel.TextColor3 = ACCENT_COLOR
			local ref = countdownLabel:FindFirstChildOfClass("UIStroke")
			if ref then ref.Color = ACCENT_COLOR end
		end
	end

	function self:setVehicleState(vehicleId: string, state: VehicleCellState)
		local card = vehicleCards[vehicleId]
		if not card then return end

		local strokeRef = card:FindFirstChild("SelectionStroke") :: UIStroke
		local nameLabel = card:FindFirstChild("VehicleName") :: TextLabel
		local clickDetector = card:FindFirstChild("ClickDetector") :: TextButton

		if state == "selected" then
			card.BackgroundColor3 = Color3.fromRGB(0, 50, 80)
			card.BackgroundTransparency = 0.1
			if strokeRef then
				strokeRef.Thickness = 2.5
				strokeRef.Color = SELECTED_COLOR
			end
			if nameLabel then nameLabel.TextColor3 = TEXT_COLOR end
			if clickDetector then clickDetector.Active = true end
		elseif state == "locked" then
			card.BackgroundColor3 = LOCKED_COLOR
			card.BackgroundTransparency = 0.2
			if strokeRef then strokeRef.Thickness = 0 end
			if nameLabel then nameLabel.TextColor3 = LOCKED_TEXT_COLOR end
			if clickDetector then clickDetector.Active = false end
		else
			card.BackgroundColor3 = AVAILABLE_COLOR
			card.BackgroundTransparency = 0.15
			if strokeRef then
				strokeRef.Thickness = 0
				strokeRef.Color = ACCENT_COLOR
			end
			if nameLabel then nameLabel.TextColor3 = TEXT_COLOR end
			if clickDetector then clickDetector.Active = true end
		end
	end

	function self:setConfirmEnabled(enabled: boolean)
		confirmButton.Active = enabled
		if enabled then
			confirmButton.BackgroundColor3 = ACCENT_CONFIRM
			confirmButton.TextColor3 = TEXT_COLOR
			local cStroke = confirmButton:FindFirstChild("ConfirmStroke") :: UIStroke
			if cStroke then cStroke.Color = ACCENT_CONFIRM end
		else
			confirmButton.BackgroundColor3 = LOCKED_COLOR
			confirmButton.TextColor3 = SUBTEXT_COLOR
			local cStroke = confirmButton:FindFirstChild("ConfirmStroke") :: UIStroke
			if cStroke then cStroke.Color = LOCKED_COLOR end
		end
	end

	function self:setVehicleModel(model: Model?)
		for _, child in ipairs(viewportFrame:GetChildren()) do
			if child ~= viewportCamera then
				child:Destroy()
			end
		end
		currentModel = nil

		noSelectionLabel.Visible = (model == nil)

		if model then
			local clone = model:Clone()
			clone.Parent = viewportFrame
			currentModel = clone

			local cf, size = clone:GetBoundingBox()
			local maxDim = math.max(size.X, size.Y, size.Z)
			local distance = maxDim * 2.2

			turntableAngle = 0

			if turntableConnection then
				turntableConnection:Disconnect()
			end
			turntableConnection = RunService.RenderStepped:Connect(function(dt)
				if not currentModel or not currentModel.Parent then return end
				turntableAngle = turntableAngle + dt * 30
				local rad = math.rad(turntableAngle)
				local center = currentModel:GetBoundingBox().Position
				local offset = Vector3.new(
					math.sin(rad) * distance,
					distance * 0.4,
					math.cos(rad) * distance
				)
				viewportCamera.CFrame = CFrame.lookAt(center + offset, center)
			end)
		else
			if turntableConnection then
				turntableConnection:Disconnect()
				turntableConnection = nil
			end
		end
	end

	function self:setVehicleInfo(displayName: string, tagline: string, description: string)
		vehicleNameLabel.Text = displayName
		vehicleTaglineLabel.Text = tagline
		vehicleDescLabel.Text = description
		vehicleNameLabel.Visible = true
		vehicleTaglineLabel.Visible = true
		vehicleDescLabel.Visible = true
	end

	function self:buildCards(vehicles: { any }, playerLevel: number, playerScrap: number?, unlockedVehicles: { string }?)
		-- Clear existing cards
		for _, child in cardContainer:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		vehicleCards = {}
		self.vehicleCards = vehicleCards

		local scrap = playerScrap or 0
		local unlockedSet: { [string]: boolean } = {}
		if unlockedVehicles then
			for _, id in unlockedVehicles do
				unlockedSet[id] = true
			end
		end

		for i, vData in vehicles do
			local isUnlocked = unlockedSet[vData.id] or (not unlockedVehicles and vData.unlockLevel <= playerLevel)
			local meetsLevel = vData.unlockLevel <= playerLevel
			local meetsScrap = scrap >= (vData.scrapCost or 0)
			local canPurchase = (not isUnlocked) and meetsLevel and meetsScrap and (vData.scrapCost or 0) > 0
			local card = createVehicleCard(vData, isUnlocked, cardContainer, canPurchase)
			card.LayoutOrder = i

			card.Size = UDim2.new(1, 0, 1 / #vehicles, -(10 * (#vehicles - 1) / #vehicles))

			vehicleCards[vData.id] = card

			local clickDetector = card:FindFirstChild("ClickDetector") :: TextButton
			if clickDetector then
				clickDetector.Activated:Connect(function()
					if isUnlocked then
						onVehicleSelected:Fire(vData.id)
					end
				end)
			end

			-- Purchase button
			local lockOverlay = card:FindFirstChild("LockOverlay")
			if lockOverlay then
				local buyBtn = lockOverlay:FindFirstChild("BuyButton") :: TextButton?
				if buyBtn and canPurchase then
					buyBtn.Activated:Connect(function()
						onVehicleSelected:Fire("purchase:" .. vData.id)
					end)
				end
			end

			-- Hover effect for unlocked cards
			if isUnlocked and clickDetector then
				clickDetector.MouseEnter:Connect(function()
					if card.BackgroundColor3 ~= Color3.fromRGB(0, 50, 80) then
						TweenService:Create(card, HOVER_TWEEN, { BackgroundTransparency = 0.05 }):Play()
					end
				end)
				clickDetector.MouseLeave:Connect(function()
					if card.BackgroundColor3 ~= Color3.fromRGB(0, 50, 80) then
						TweenService:Create(card, HOVER_TWEEN, { BackgroundTransparency = 0.15 }):Play()
					end
				end)
			end
		end
	end

	self:setConfirmEnabled(false)

	return self
end

return PreRoundScreen
