--[[
	PreRoundScreen — Builds the Pre-Round vehicle selection ScreenGui.

	Dark panel / frosted glass style matching HubScreen.
	Full-screen overlay with countdown timer, 3D viewport (ViewportFrame),
	confirm button, and a 4-column scrollable vehicle grid.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local PreRoundScreen = {}

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.25
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local ACCENT_CONFIRM = Color3.fromRGB(30, 200, 80)
local SELECTED_COLOR = Color3.fromRGB(0, 180, 255)
local TAKEN_COLOR = Color3.fromRGB(60, 60, 65)
local AVAILABLE_COLOR = Color3.fromRGB(40, 40, 46)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(160, 160, 170)
local TAKEN_TEXT_COLOR = Color3.fromRGB(100, 100, 110)
local CORNER_RADIUS = UDim.new(0, 16)
local CORNER_RADIUS_SMALL = UDim.new(0, 10)
local HOVER_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local VEHICLE_NAMES = {
	"Roadster", "Cruiser", "Hauler", "Speedster", "Buggy",
	"Rally", "Muscle", "Compact", "Pickup", "SUV",
	"Racer", "Drifter", "Offroad", "Sedan", "Coupe",
	"Hatchback", "Minivan", "Jeep", "Wagon", "Hotrod",
}

local GRID_COLUMNS = 4
local CELL_PADDING = 8

export type VehicleCellState = "available" | "selected" | "taken"

export type PreRoundScreenInstance = {
	screenGui: ScreenGui,
	viewportFrame: ViewportFrame,
	viewportCamera: Camera,
	countdownLabel: TextLabel,
	confirmButton: TextButton,
	vehicleCells: { [string]: Frame },
	onVehicleSelected: BindableEvent,
	onConfirm: BindableEvent,
	destroy: (self: PreRoundScreenInstance) -> (),
	setVisible: (self: PreRoundScreenInstance, visible: boolean) -> (),
	setCountdown: (self: PreRoundScreenInstance, seconds: number) -> (),
	setVehicleState: (self: PreRoundScreenInstance, vehicleName: string, state: VehicleCellState) -> (),
	setConfirmEnabled: (self: PreRoundScreenInstance, enabled: boolean) -> (),
	setVehicleModel: (self: PreRoundScreenInstance, model: Model?) -> (),
}

local function createVehicleCell(vehicleName: string, index: number, parent: ScrollingFrame): Frame
	local cell = Instance.new("Frame")
	cell.Name = "Cell_" .. vehicleName
	cell.BackgroundColor3 = AVAILABLE_COLOR
	cell.BackgroundTransparency = 0.15
	cell.BorderSizePixel = 0
	cell.LayoutOrder = index
	cell.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS_SMALL
	corner.Parent = cell

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectionStroke"
	stroke.Color = ACCENT_COLOR
	stroke.Thickness = 0
	stroke.Transparency = 0
	stroke.Parent = cell

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "VehicleName"
	nameLabel.Size = UDim2.new(1, -12, 1, -8)
	nameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = TEXT_COLOR
	nameLabel.TextSize = 16
	nameLabel.TextScaled = false
	nameLabel.Text = vehicleName
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = cell

	local takenOverlay = Instance.new("Frame")
	takenOverlay.Name = "TakenOverlay"
	takenOverlay.Size = UDim2.new(1, 0, 1, 0)
	takenOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	takenOverlay.BackgroundTransparency = 0.5
	takenOverlay.BorderSizePixel = 0
	takenOverlay.Visible = false
	takenOverlay.ZIndex = 2
	takenOverlay.Parent = cell

	local takenCorner = Instance.new("UICorner")
	takenCorner.CornerRadius = CORNER_RADIUS_SMALL
	takenCorner.Parent = takenOverlay

	local takenLabel = Instance.new("TextLabel")
	takenLabel.Name = "TakenText"
	takenLabel.Size = UDim2.new(1, 0, 1, 0)
	takenLabel.BackgroundTransparency = 1
	takenLabel.Font = Enum.Font.GothamBold
	takenLabel.TextColor3 = TAKEN_TEXT_COLOR
	takenLabel.TextSize = 14
	takenLabel.Text = "TAKEN"
	takenLabel.ZIndex = 3
	takenLabel.Parent = takenOverlay

	local clickDetector = Instance.new("TextButton")
	clickDetector.Name = "ClickDetector"
	clickDetector.Size = UDim2.new(1, 0, 1, 0)
	clickDetector.BackgroundTransparency = 1
	clickDetector.Text = ""
	clickDetector.ZIndex = 4
	clickDetector.Parent = cell

	return cell
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

	-- Full-screen dark backdrop
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

	-- Main content area (left = viewport, right = grid)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -60, 1, -180)
	contentFrame.Position = UDim2.new(0.5, 0, 0, 145)
	contentFrame.AnchorPoint = Vector2.new(0.5, 0)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = backdrop

	-- Left side: 3D viewport + confirm button
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
	noSelectionLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	noSelectionLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	noSelectionLabel.BackgroundTransparency = 1
	noSelectionLabel.Font = Enum.Font.Gotham
	noSelectionLabel.TextColor3 = SUBTEXT_COLOR
	noSelectionLabel.TextSize = 18
	noSelectionLabel.Text = "Select a vehicle from the grid"
	noSelectionLabel.Parent = viewportPanel

	-- ViewportFrame for 3D preview
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "VehicleViewport"
	viewportFrame.Size = UDim2.new(1, -20, 1, -20)
	viewportFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	viewportFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.Ambient = Color3.fromRGB(140, 140, 150)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)
	viewportFrame.Parent = viewportPanel

	local viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 50
	viewportCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = viewportCamera

	-- Confirm button below viewport
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

	-- Hover effect on confirm button
	confirmButton.MouseEnter:Connect(function()
		TweenService:Create(confirmButton, HOVER_TWEEN, { BackgroundTransparency = 0 }):Play()
	end)
	confirmButton.MouseLeave:Connect(function()
		TweenService:Create(confirmButton, HOVER_TWEEN, { BackgroundTransparency = 0.15 }):Play()
	end)

	-- Right side: vehicle grid
	local gridPanel = Instance.new("Frame")
	gridPanel.Name = "GridPanel"
	gridPanel.Size = UDim2.new(0.55, -10, 1, 0)
	gridPanel.Position = UDim2.new(0.45, 10, 0, 0)
	gridPanel.BackgroundColor3 = PANEL_COLOR
	gridPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	gridPanel.BorderSizePixel = 0
	gridPanel.ClipsDescendants = true
	gridPanel.Parent = contentFrame

	local gridCorner = Instance.new("UICorner")
	gridCorner.CornerRadius = CORNER_RADIUS
	gridCorner.Parent = gridPanel

	local gridStroke = Instance.new("UIStroke")
	gridStroke.Color = ACCENT_COLOR
	gridStroke.Thickness = 1.5
	gridStroke.Transparency = 0.5
	gridStroke.Parent = gridPanel

	local gridTitle = Instance.new("TextLabel")
	gridTitle.Name = "GridTitle"
	gridTitle.Size = UDim2.new(1, -20, 0, 30)
	gridTitle.Position = UDim2.new(0, 10, 0, 8)
	gridTitle.BackgroundTransparency = 1
	gridTitle.Font = Enum.Font.GothamBold
	gridTitle.TextColor3 = TEXT_COLOR
	gridTitle.TextSize = 16
	gridTitle.TextXAlignment = Enum.TextXAlignment.Left
	gridTitle.Text = "VEHICLES"
	gridTitle.Parent = gridPanel

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "VehicleGrid"
	scrollFrame.Size = UDim2.new(1, -20, 1, -48)
	scrollFrame.Position = UDim2.new(0, 10, 0, 42)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = ACCENT_COLOR
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = gridPanel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, CELL_PADDING, 0, CELL_PADDING)
	gridLayout.CellSize = UDim2.new(1 / GRID_COLUMNS, -(CELL_PADDING * (GRID_COLUMNS - 1) / GRID_COLUMNS), 0, 60)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	-- Build vehicle cells
	local vehicleCells: { [string]: Frame } = {}
	for i, vehicleName in ipairs(VEHICLE_NAMES) do
		local cell = createVehicleCell(vehicleName, i, scrollFrame)
		vehicleCells[vehicleName] = cell
	end

	-- BindableEvents for callbacks
	local onVehicleSelected = Instance.new("BindableEvent")
	onVehicleSelected.Name = "OnVehicleSelected"
	onVehicleSelected.Parent = screenGui

	local onConfirm = Instance.new("BindableEvent")
	onConfirm.Name = "OnConfirm"
	onConfirm.Parent = screenGui

	-- Wire up cell click handlers
	for vehicleName, cell in pairs(vehicleCells) do
		local clickDetector = cell:FindFirstChild("ClickDetector") :: TextButton
		if clickDetector then
			clickDetector.Activated:Connect(function()
				onVehicleSelected:Fire(vehicleName)
			end)
		end
	end

	confirmButton.Activated:Connect(function()
		onConfirm:Fire()
	end)

	-- Turntable rotation for viewport model
	local currentModel: Model? = nil
	local turntableAngle = 0
	local turntableConnection: RBXScriptConnection? = nil

	local self: PreRoundScreenInstance = {
		screenGui = screenGui,
		viewportFrame = viewportFrame,
		viewportCamera = viewportCamera,
		countdownLabel = countdownLabel,
		confirmButton = confirmButton,
		vehicleCells = vehicleCells,
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
			local countdownStrokeRef = countdownLabel:FindFirstChildOfClass("UIStroke")
			if countdownStrokeRef then
				countdownStrokeRef.Color = Color3.fromRGB(255, 80, 80)
			end
		else
			countdownLabel.TextColor3 = ACCENT_COLOR
			local countdownStrokeRef = countdownLabel:FindFirstChildOfClass("UIStroke")
			if countdownStrokeRef then
				countdownStrokeRef.Color = ACCENT_COLOR
			end
		end
	end

	function self:setVehicleState(vehicleName: string, state: VehicleCellState)
		local cell = vehicleCells[vehicleName]
		if not cell then return end

		local strokeRef = cell:FindFirstChild("SelectionStroke") :: UIStroke
		local overlay = cell:FindFirstChild("TakenOverlay") :: Frame
		local nameLabel = cell:FindFirstChild("VehicleName") :: TextLabel
		local clickDetector = cell:FindFirstChild("ClickDetector") :: TextButton

		if state == "selected" then
			cell.BackgroundColor3 = Color3.fromRGB(0, 50, 80)
			cell.BackgroundTransparency = 0.1
			if strokeRef then
				strokeRef.Thickness = 2.5
				strokeRef.Color = SELECTED_COLOR
			end
			if overlay then overlay.Visible = false end
			if nameLabel then nameLabel.TextColor3 = TEXT_COLOR end
			if clickDetector then clickDetector.Active = true end
		elseif state == "taken" then
			cell.BackgroundColor3 = TAKEN_COLOR
			cell.BackgroundTransparency = 0.2
			if strokeRef then
				strokeRef.Thickness = 0
			end
			if overlay then overlay.Visible = true end
			if nameLabel then nameLabel.TextColor3 = TAKEN_TEXT_COLOR end
			if clickDetector then clickDetector.Active = false end
		else
			cell.BackgroundColor3 = AVAILABLE_COLOR
			cell.BackgroundTransparency = 0.15
			if strokeRef then
				strokeRef.Thickness = 0
				strokeRef.Color = ACCENT_COLOR
			end
			if overlay then overlay.Visible = false end
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
			confirmButton.BackgroundColor3 = TAKEN_COLOR
			confirmButton.TextColor3 = SUBTEXT_COLOR
			local cStroke = confirmButton:FindFirstChild("ConfirmStroke") :: UIStroke
			if cStroke then cStroke.Color = TAKEN_COLOR end
		end
	end

	function self:setVehicleModel(model: Model?)
		-- Clear existing viewport children (except camera)
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

			-- Position camera to frame the model
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

	-- Start with confirm disabled
	self:setConfirmEnabled(false)

	return self
end

PreRoundScreen.VEHICLE_NAMES = VEHICLE_NAMES

return PreRoundScreen
