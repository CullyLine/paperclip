--[[
	DriverHUD — In-vehicle dashboard UI with speedometer, RPM gauge,
	gear display, and speed readout. Appears when the player sits
	in the driver seat, disappears when they exit.
	
	All UI is created programmatically — no RBXM dependencies.
	Gauges use circular arc rendering via UIStroke on frames.
]]

local TweenService = game:GetService("TweenService")

local DriverHUD = {}
DriverHUD.__index = DriverHUD

local GAUGE_TWEEN_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function createRoundFrame(parent, name, size, pos, bgColor, transparency)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = bgColor or Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	return frame
end

local function createLabel(parent, name, text, size, pos, textColor, textSize, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 24
	label.Font = font or Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function createNeedleFrame(parent, name, pivotPos, length, color)
	local container = Instance.new("Frame")
	container.Name = name
	container.Size = UDim2.new(0, 4, 0, length)
	container.Position = pivotPos
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.BackgroundColor3 = color or Color3.fromRGB(255, 60, 60)
	container.BackgroundTransparency = 0
	container.BorderSizePixel = 0
	container.Rotation = 0
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = container

	return container
end

local function createGaugeArc(parent, centerX, centerY, radius, startAngle, endAngle, segments, color, thickness)
	-- Render gauge tick marks around an arc
	local totalAngle = endAngle - startAngle
	for i = 0, segments do
		local angle = startAngle + (totalAngle * i / segments)
		local rad = math.rad(angle)
		local tickLen = (i % 2 == 0) and 12 or 6
		local tickWidth = (i % 2 == 0) and 2 or 1

		local x = centerX + math.sin(rad) * radius
		local y = centerY - math.cos(rad) * radius

		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, tickWidth, 0, tickLen)
		tick.Position = UDim2.new(0, x, 0, y)
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.BackgroundColor3 = color or Color3.fromRGB(180, 180, 180)
		tick.BackgroundTransparency = 0
		tick.BorderSizePixel = 0
		tick.Rotation = angle
		tick.Parent = parent
	end
end

function DriverHUD.new(playerGui: PlayerGui)
	local self = setmetatable({}, DriverHUD)

	-- Main ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "DriverHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	self.gui = gui

	-- Container at bottom-right
	local container = Instance.new("Frame")
	container.Name = "DashContainer"
	container.Size = UDim2.new(0, 420, 0, 220)
	container.Position = UDim2.new(1, -440, 1, -240)
	container.BackgroundTransparency = 1
	container.Parent = gui

	-- RPM Gauge (left circular gauge)
	local rpmGauge = createRoundFrame(container, "RPMGauge",
		UDim2.new(0, 190, 0, 190),
		UDim2.new(0, 0, 0, 15),
		Color3.fromRGB(15, 15, 20), 0)

	local rpmStroke = Instance.new("UIStroke")
	rpmStroke.Thickness = 3
	rpmStroke.Color = Color3.fromRGB(60, 60, 70)
	rpmStroke.Parent = rpmGauge

	createGaugeArc(rpmGauge, 95, 95, 75, -135, 135, 18, Color3.fromRGB(120, 120, 130), 2)

	-- RPM redline zone ticks
	for i = 15, 18 do
		local angle = -135 + (270 * i / 18)
		local rad = math.rad(angle)
		local x = 95 + math.sin(rad) * 75
		local y = 95 - math.cos(rad) * 75
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 3, 0, 14)
		tick.Position = UDim2.new(0, x, 0, y)
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		tick.BorderSizePixel = 0
		tick.Rotation = angle
		tick.Parent = rpmGauge
	end

	self.rpmNeedle = createNeedleFrame(rpmGauge, "RPMNeedle",
		UDim2.new(0, 95, 0, 95), 65, Color3.fromRGB(255, 70, 70))
	self.rpmNeedle.Rotation = -135

	createLabel(rpmGauge, "RPMLabel", "RPM", UDim2.new(1, 0, 0, 20),
		UDim2.new(0, 0, 0.7, 0), Color3.fromRGB(140, 140, 150), 14, Enum.Font.Gotham)

	self.rpmValueLabel = createLabel(rpmGauge, "RPMValue", "0", UDim2.new(1, 0, 0, 22),
		UDim2.new(0, 0, 0.52, 0), Color3.fromRGB(255, 255, 255), 18, Enum.Font.GothamBold)

	-- Speedometer (right circular gauge)
	local speedGauge = createRoundFrame(container, "SpeedGauge",
		UDim2.new(0, 190, 0, 190),
		UDim2.new(0, 225, 0, 15),
		Color3.fromRGB(15, 15, 20), 0)

	local speedStroke = Instance.new("UIStroke")
	speedStroke.Thickness = 3
	speedStroke.Color = Color3.fromRGB(60, 60, 70)
	speedStroke.Parent = speedGauge

	createGaugeArc(speedGauge, 95, 95, 75, -135, 135, 14, Color3.fromRGB(120, 120, 130), 2)

	self.speedNeedle = createNeedleFrame(speedGauge, "SpeedNeedle",
		UDim2.new(0, 95, 0, 95), 65, Color3.fromRGB(80, 180, 255))
	self.speedNeedle.Rotation = -135

	self.speedValueLabel = createLabel(speedGauge, "SpeedValue", "0", UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0.42, 0), Color3.fromRGB(255, 255, 255), 28, Enum.Font.GothamBold)

	createLabel(speedGauge, "SpeedUnit", "MPH", UDim2.new(1, 0, 0, 16),
		UDim2.new(0, 0, 0.6, 0), Color3.fromRGB(140, 140, 150), 14, Enum.Font.Gotham)

	-- Gear display (center between gauges)
	local gearFrame = createRoundFrame(container, "GearDisplay",
		UDim2.new(0, 56, 0, 56),
		UDim2.new(0, 182, 0, 85),
		Color3.fromRGB(25, 25, 35), 0)

	local gearStroke = Instance.new("UIStroke")
	gearStroke.Thickness = 2
	gearStroke.Color = Color3.fromRGB(80, 180, 255)
	gearStroke.Parent = gearFrame

	self.gearLabel = createLabel(gearFrame, "GearText", "1", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 180, 255), 32, Enum.Font.GothamBold)

	-- ABS indicator
	local absFrame = createRoundFrame(container, "ABSIndicator",
		UDim2.new(0, 42, 0, 22),
		UDim2.new(0, 168, 0, 150),
		Color3.fromRGB(40, 40, 50), 0)

	self.absLabel = createLabel(absFrame, "ABSText", "ABS", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 80, 90), 12, Enum.Font.GothamBold)

	self.absFrame = absFrame

	-- TCS indicator
	local tcsFrame = createRoundFrame(container, "TCSIndicator",
		UDim2.new(0, 42, 0, 22),
		UDim2.new(0, 214, 0, 150),
		Color3.fromRGB(40, 40, 50), 0)

	self.tcsLabel = createLabel(tcsFrame, "TCSText", "TCS", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 80, 90), 12, Enum.Font.GothamBold)

	self.tcsFrame = tcsFrame

	-- Hydraulics indicator (shows mode + bounce status)
	local hydFrame = createRoundFrame(container, "HydraulicIndicator",
		UDim2.new(0, 60, 0, 22),
		UDim2.new(0, 130, 0, 150),
		Color3.fromRGB(40, 40, 50), 0)

	self.hydLabel = createLabel(hydFrame, "HydText", "HYD", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 80, 90), 10, Enum.Font.GothamBold)

	self.hydFrame = hydFrame

	-- Bounce mode indicator
	local bounceFrame = createRoundFrame(container, "BounceIndicator",
		UDim2.new(0, 50, 0, 22),
		UDim2.new(0, 260, 0, 150),
		Color3.fromRGB(40, 40, 50), 0)

	self.bounceLabel = createLabel(bounceFrame, "BounceText", "BNC", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 80, 90), 10, Enum.Font.GothamBold)

	self.bounceFrame = bounceFrame

	-- Surface type indicator (between indicators and bottom of gauges)
	local surfaceFrame = createRoundFrame(container, "SurfaceIndicator",
		UDim2.new(0, 100, 0, 22),
		UDim2.new(0, 160, 0, 180),
		Color3.fromRGB(40, 40, 50), 0)

	self.surfaceLabel = createLabel(surfaceFrame, "SurfaceText", "---", UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0), Color3.fromRGB(140, 140, 150), 11, Enum.Font.Gotham)

	self.surfaceFrame = surfaceFrame

	-- Telemetry overlay (hidden by default, toggled with T)
	local telemetryPanel = Instance.new("Frame")
	telemetryPanel.Name = "TelemetryPanel"
	telemetryPanel.Size = UDim2.new(0, 340, 0, 280)
	telemetryPanel.Position = UDim2.new(0, 20, 0.5, -140)
	telemetryPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	telemetryPanel.BackgroundTransparency = 0.25
	telemetryPanel.BorderSizePixel = 0
	telemetryPanel.Visible = false
	telemetryPanel.Parent = gui

	local telCorner = Instance.new("UICorner")
	telCorner.CornerRadius = UDim.new(0, 8)
	telCorner.Parent = telemetryPanel

	local telStroke = Instance.new("UIStroke")
	telStroke.Thickness = 1
	telStroke.Color = Color3.fromRGB(50, 50, 60)
	telStroke.Parent = telemetryPanel

	createLabel(telemetryPanel, "TelTitle", "TELEMETRY", UDim2.new(1, 0, 0, 18),
		UDim2.new(0, 0, 0, 4), Color3.fromRGB(80, 180, 255), 11, Enum.Font.GothamBold)

	-- Per-wheel data: FL(top-left), FR(top-right), RL(bottom-left), RR(bottom-right)
	local wheelPositions = {
		UDim2.new(0, 10, 0, 28),   -- FL
		UDim2.new(0, 175, 0, 28),  -- FR
		UDim2.new(0, 10, 0, 140),  -- RL
		UDim2.new(0, 175, 0, 140), -- RR
	}
	local wheelNames = { "FL", "FR", "RL", "RR" }

	self.wheelLabels = {}
	for i = 1, 4 do
		local wFrame = Instance.new("Frame")
		wFrame.Name = "Wheel" .. wheelNames[i]
		wFrame.Size = UDim2.new(0, 155, 0, 105)
		wFrame.Position = wheelPositions[i]
		wFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		wFrame.BackgroundTransparency = 0.3
		wFrame.BorderSizePixel = 0
		wFrame.Parent = telemetryPanel

		local wCorner = Instance.new("UICorner")
		wCorner.CornerRadius = UDim.new(0, 4)
		wCorner.Parent = wFrame

		createLabel(wFrame, "Name", wheelNames[i], UDim2.new(0, 30, 0, 14),
			UDim2.new(0, 4, 0, 2), Color3.fromRGB(80, 180, 255), 10, Enum.Font.GothamBold)

		local labels = {}
		local lineY = 18
		local lineH = 13
		for _, field in { "Susp", "Force", "Slip\u{b0}", "SlipR", "Surf", "Wt%" } do
			local fieldLabel = createLabel(wFrame, field .. "Label", field,
				UDim2.new(0, 40, 0, lineH), UDim2.new(0, 4, 0, lineY),
				Color3.fromRGB(100, 100, 110), 9, Enum.Font.Gotham)
			fieldLabel.TextXAlignment = Enum.TextXAlignment.Left

			local valLabel = createLabel(wFrame, field .. "Val", "---",
				UDim2.new(0, 100, 0, lineH), UDim2.new(0, 48, 0, lineY),
				Color3.fromRGB(200, 200, 210), 9, Enum.Font.GothamBold)
			valLabel.TextXAlignment = Enum.TextXAlignment.Left

			labels[field] = valLabel
			lineY += lineH + 1
		end

		self.wheelLabels[i] = labels
	end

	-- G-force crosshair (center between wheel quadrants)
	local gForceFrame = Instance.new("Frame")
	gForceFrame.Name = "GForcePanel"
	gForceFrame.Size = UDim2.new(0, 80, 0, 80)
	gForceFrame.Position = UDim2.new(0.5, -40, 0.5, -16)
	gForceFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	gForceFrame.BackgroundTransparency = 0.2
	gForceFrame.BorderSizePixel = 0
	gForceFrame.Parent = telemetryPanel

	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0.5, 0)
	gCorner.Parent = gForceFrame

	local gStroke = Instance.new("UIStroke")
	gStroke.Thickness = 1
	gStroke.Color = Color3.fromRGB(50, 50, 60)
	gStroke.Parent = gForceFrame

	-- Crosshair lines
	local hLine = Instance.new("Frame")
	hLine.Size = UDim2.new(1, -10, 0, 1)
	hLine.Position = UDim2.new(0, 5, 0.5, 0)
	hLine.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	hLine.BorderSizePixel = 0
	hLine.Parent = gForceFrame

	local vLine = Instance.new("Frame")
	vLine.Size = UDim2.new(0, 1, 1, -10)
	vLine.Position = UDim2.new(0.5, 0, 0, 5)
	vLine.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	vLine.BorderSizePixel = 0
	vLine.Parent = gForceFrame

	-- G-force dot
	local gDot = Instance.new("Frame")
	gDot.Name = "GDot"
	gDot.Size = UDim2.new(0, 8, 0, 8)
	gDot.Position = UDim2.new(0.5, -4, 0.5, -4)
	gDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	gDot.BorderSizePixel = 0
	gDot.Parent = gForceFrame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = gDot

	self.gDot = gDot
	self.gForceFrame = gForceFrame

	createLabel(gForceFrame, "GLabel", "G", UDim2.new(0, 16, 0, 12),
		UDim2.new(1, -18, 0, 2), Color3.fromRGB(100, 100, 110), 9, Enum.Font.GothamBold)

	-- Vehicle data bar at bottom of telemetry
	local dataBar = Instance.new("Frame")
	dataBar.Name = "DataBar"
	dataBar.Size = UDim2.new(1, -20, 0, 22)
	dataBar.Position = UDim2.new(0, 10, 1, -28)
	dataBar.BackgroundTransparency = 1
	dataBar.Parent = telemetryPanel

	self.telSteerLabel = createLabel(dataBar, "Steer", "STR: 0°",
		UDim2.new(0.33, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(180, 180, 190), 10, Enum.Font.Gotham)

	self.telGLatLabel = createLabel(dataBar, "GLat", "G-Lat: 0.00",
		UDim2.new(0.33, 0, 1, 0), UDim2.new(0.33, 0, 0, 0),
		Color3.fromRGB(180, 180, 190), 10, Enum.Font.Gotham)

	self.telGLonLabel = createLabel(dataBar, "GLon", "G-Lon: 0.00",
		UDim2.new(0.33, 0, 1, 0), UDim2.new(0.66, 0, 0, 0),
		Color3.fromRGB(180, 180, 190), 10, Enum.Font.Gotham)

	self.telemetryPanel = telemetryPanel

	return self
end

local SURFACE_COLORS: { [string]: Color3 } = {
	Asphalt = Color3.fromRGB(140, 140, 150),
	Concrete = Color3.fromRGB(140, 140, 150),
	Grass = Color3.fromRGB(80, 180, 80),
	LeafyGrass = Color3.fromRGB(60, 160, 60),
	Sand = Color3.fromRGB(210, 180, 100),
	Snow = Color3.fromRGB(200, 220, 255),
	Ice = Color3.fromRGB(120, 200, 255),
	Glacier = Color3.fromRGB(120, 200, 255),
	Mud = Color3.fromRGB(140, 100, 60),
	Ground = Color3.fromRGB(160, 130, 80),
	Wood = Color3.fromRGB(180, 140, 80),
	WoodPlanks = Color3.fromRGB(180, 140, 80),
	Metal = Color3.fromRGB(160, 160, 170),
	Cobblestone = Color3.fromRGB(150, 150, 140),
	Brick = Color3.fromRGB(180, 120, 100),
}

function DriverHUD:update(speedMPH: number, gear: number, rpm: number, redlineRPM: number, isReversing: boolean, absActive: boolean?, tcsActive: boolean?, surfaceName: string?, hydraulicsActive: boolean?, bounceMode: boolean?, bounceIntensity: number?)
	-- Speed needle: 0-200 MPH mapped to -135° to 135° (270° sweep)
	local speedNorm = math.clamp(speedMPH / 200, 0, 1)
	local speedAngle = -135 + speedNorm * 270
	self.speedNeedle.Rotation = speedAngle

	self.speedValueLabel.Text = tostring(math.floor(speedMPH))

	-- Smooth RPM display to avoid jittery readout
	local safeRedline = math.max(redlineRPM, 1)
	if not self._smoothRPM then self._smoothRPM = rpm end
	self._smoothRPM = self._smoothRPM + (rpm - self._smoothRPM) * 0.3

	local rpmNorm = math.clamp(self._smoothRPM / safeRedline, 0, 1)
	local rpmAngle = -135 + rpmNorm * 270
	self.rpmNeedle.Rotation = rpmAngle

	self.rpmValueLabel.Text = tostring(math.floor(self._smoothRPM / 100) * 100)

	-- RPM needle color: intensify near redline with pulsing
	if rpmNorm > 0.92 then
		local pulse = 0.5 + 0.5 * math.sin(tick() * 12)
		local r = math.floor(255 * (0.7 + 0.3 * pulse))
		self.rpmNeedle.BackgroundColor3 = Color3.fromRGB(r, 20, 20)
	elseif rpmNorm > 0.85 then
		self.rpmNeedle.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	else
		self.rpmNeedle.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	end

	-- Gear display
	if isReversing then
		self.gearLabel.Text = "R"
		self.gearLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
	else
		self.gearLabel.Text = tostring(gear)
		self.gearLabel.TextColor3 = Color3.fromRGB(80, 180, 255)
	end

	-- ABS indicator: amber when active
	if absActive then
		self.absFrame.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
		self.absLabel.TextColor3 = Color3.fromRGB(255, 190, 40)
	else
		self.absFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		self.absLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
	end

	-- TCS indicator: amber when active
	if tcsActive then
		self.tcsFrame.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
		self.tcsLabel.TextColor3 = Color3.fromRGB(255, 190, 40)
	else
		self.tcsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		self.tcsLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
	end

	-- Hydraulics indicator: cyan when active
	if hydraulicsActive then
		self.hydFrame.BackgroundColor3 = Color3.fromRGB(10, 45, 60)
		self.hydLabel.TextColor3 = Color3.fromRGB(40, 200, 255)
		self.hydLabel.Text = "HYD"
	else
		self.hydFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		self.hydLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
		self.hydLabel.Text = "HYD"
	end

	-- Bounce indicator: shows intensity level
	local BOUNCE_NAMES = { [0] = "OFF", [1] = "LOW", [2] = "MED", [3] = "HIGH" }
	local bLevel = bounceIntensity or 0
	if bounceMode and bLevel > 0 then
		self.bounceFrame.BackgroundColor3 = Color3.fromRGB(50, 20, 60)
		self.bounceLabel.TextColor3 = Color3.fromRGB(220, 100, 255)
		self.bounceLabel.Text = BOUNCE_NAMES[bLevel] or "BNC"
	else
		self.bounceFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		self.bounceLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
		self.bounceLabel.Text = "OFF"
	end

	-- Surface indicator
	if surfaceName then
		self.surfaceLabel.Text = surfaceName
		local color = SURFACE_COLORS[surfaceName] or Color3.fromRGB(140, 140, 150)
		self.surfaceLabel.TextColor3 = color
	else
		self.surfaceLabel.Text = "---"
		self.surfaceLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
	end
end

function DriverHUD:setTelemetryVisible(visible: boolean)
	if self.telemetryPanel then
		self.telemetryPanel.Visible = visible
	end
end

local function colorForValue(value: number, greenThreshold: number, yellowThreshold: number, invert: boolean?): Color3
	local absVal = math.abs(value)
	if invert then
		if absVal <= greenThreshold then return Color3.fromRGB(80, 200, 80) end
		if absVal <= yellowThreshold then return Color3.fromRGB(255, 200, 40) end
		return Color3.fromRGB(255, 70, 70)
	else
		if absVal >= greenThreshold then return Color3.fromRGB(80, 200, 80) end
		if absVal >= yellowThreshold then return Color3.fromRGB(255, 200, 40) end
		return Color3.fromRGB(255, 70, 70)
	end
end

function DriverHUD:updateTelemetry(data: any)
	if not self.telemetryPanel or not self.telemetryPanel.Visible then return end

	for i = 1, math.min(#data.wheels, 4) do
		local wd = data.wheels[i]
		local labels = self.wheelLabels[i]
		if not labels then continue end

		labels["Susp"].Text = string.format("%.2f", wd.suspCompression)
		labels["Susp"].TextColor3 = colorForValue(wd.suspCompression, 0, 0.5, true)

		labels["Force"].Text = string.format("%.0f", wd.contactForce)
		labels["Force"].TextColor3 = if wd.onGround then Color3.fromRGB(200, 200, 210) else Color3.fromRGB(255, 70, 70)

		labels["Slip\u{b0}"].Text = string.format("%.1f°", wd.slipAngle)
		labels["Slip\u{b0}"].TextColor3 = colorForValue(wd.slipAngle, 0, 6, true)

		labels["SlipR"].Text = string.format("%.2f", wd.slipRatio)
		labels["SlipR"].TextColor3 = colorForValue(wd.slipRatio, 0, 0.15, true)

		labels["Surf"].Text = wd.surfaceMaterial
		local surfColor = SURFACE_COLORS[wd.surfaceMaterial]
		labels["Surf"].TextColor3 = surfColor or Color3.fromRGB(140, 140, 150)

		local wtPct = wd.weightFraction * 100
		labels["Wt%"].Text = string.format("%.0f%%", wtPct)
		labels["Wt%"].TextColor3 = colorForValue(wtPct - 25, 0, 10, true)
	end

	-- G-force dot position (map ±2G to the circle area)
	local gRadius = 32
	local dotX = math.clamp(data.gLateral / 2, -1, 1) * gRadius
	local dotY = math.clamp(-data.gLongitudinal / 2, -1, 1) * gRadius
	self.gDot.Position = UDim2.new(0.5, dotX - 4, 0.5, dotY - 4)

	local gMag = math.sqrt(data.gLateral * data.gLateral + data.gLongitudinal * data.gLongitudinal)
	if gMag > 1.5 then
		self.gDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	elseif gMag > 0.8 then
		self.gDot.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	else
		self.gDot.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	end

	self.telSteerLabel.Text = string.format("STR: %.1f°", data.steerAngle)
	self.telGLatLabel.Text = string.format("G-Lat: %.2f", data.gLateral)
	self.telGLonLabel.Text = string.format("G-Lon: %.2f", data.gLongitudinal)
end

function DriverHUD:destroy()
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return DriverHUD
