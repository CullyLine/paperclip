--[[
	InputManager — Input abstraction for Downhill Madness.

	Provides a unified interface for keyboard, gamepad, and mobile.
	Automatically detects touch devices and creates on-screen driving
	controls with configurable input modes.

	Touch controls are created when InputManager.new() is called and
	destroyed when input:destroy() is called — so they only appear
	while the player is actively driving.

	Mobile input modes:
	  "buttons"  — classic left/right arrow buttons (default)
	  "joystick" — virtual analog joystick on left side
	  "tilt"     — device accelerometer for steering

	Settings (all optional, passed to InputManager.new(settings)):
	  steerMode      — "buttons" | "joystick" | "tilt"
	  steerSensitivity — 0.5..2.0 (multiplier on steer speed)
	  buttonOpacity  — 0.0..1.0 (touch button base opacity)
	  buttonScale    — 0.5..2.0 (touch button size multiplier)
	  autoGas        — boolean (always-on throttle for casual play)
	  tiltDeadzone   — 0.0..0.5 (ignore small tilts)

	Usage:
	  local InputManager = require(script.Parent.InputManager)
	  local input = InputManager.new({ steerMode = "joystick", autoGas = true })
	  local state = input:getState()
	  state.throttle  -- -1..1 (negative = reverse)
	  state.steer     -- -1..1 (negative = left)
	  state.brake     -- 0..1
	  state.handbrake -- 0..1
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local InputManager = {}
InputManager.__index = InputManager

export type InputState = {
	throttle: number,
	steer: number,
	brake: number,
	handbrake: number,
}

export type InputSettings = {
	steerMode: string?,
	steerSensitivity: number?,
	buttonOpacity: number?,
	buttonScale: number?,
	autoGas: boolean?,
	tiltDeadzone: number?,
}

local IS_TOUCH = UserInputService.TouchEnabled

local DEFAULT_SETTINGS: InputSettings = {
	steerMode = "buttons",
	steerSensitivity = 1.0,
	buttonOpacity = 0.7,
	buttonScale = 1.0,
	autoGas = false,
	tiltDeadzone = 0.08,
}

----------------------------------------------------------------
-- Style constants (matches HubScreen)
----------------------------------------------------------------

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_PRESSED_TRANSPARENCY = 0.1
local ACCENT_COLOR = Color3.fromRGB(0, 180, 255)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local CORNER_RADIUS = UDim.new(0, 14)
local STROKE_COLOR = Color3.fromRGB(60, 60, 70)
local STROKE_PRESSED_COLOR = ACCENT_COLOR

----------------------------------------------------------------
-- Mobile touch control builder
----------------------------------------------------------------

local function createTouchButton(
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	parent: Instance,
	touchState: { [string]: boolean },
	connections: { RBXScriptConnection },
	baseTransparency: number,
	fontSize: number?
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Position = position
	btn.Size = size
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = PANEL_COLOR
	btn.BackgroundTransparency = baseTransparency
	btn.TextColor3 = TEXT_COLOR
	btn.TextSize = fontSize or 28
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1.5
	stroke.Transparency = 0.5
	stroke.Parent = btn

	local activeTouches = 0

	table.insert(connections, btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeTouches += 1
			touchState[name] = true
			btn.BackgroundTransparency = PANEL_PRESSED_TRANSPARENCY
			stroke.Color = STROKE_PRESSED_COLOR
			stroke.Transparency = 0
		end
	end))

	table.insert(connections, btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeTouches = math.max(activeTouches - 1, 0)
			if activeTouches == 0 then
				touchState[name] = false
				btn.BackgroundTransparency = baseTransparency
				stroke.Color = STROKE_COLOR
				stroke.Transparency = 0.5
			end
		end
	end))

	return btn
end

----------------------------------------------------------------
-- Virtual Joystick
----------------------------------------------------------------

local function createVirtualJoystick(
	parent: Instance,
	joystickState: { x: number },
	connections: { RBXScriptConnection },
	baseTransparency: number,
	scale: number
)
	local OUTER_SIZE = math.floor(180 * scale)
	local INNER_SIZE = math.floor(70 * scale)
	local MAX_RADIUS = (OUTER_SIZE - INNER_SIZE) / 2

	local outer = Instance.new("Frame")
	outer.Name = "JoystickOuter"
	outer.Size = UDim2.new(0, OUTER_SIZE, 0, OUTER_SIZE)
	outer.Position = UDim2.new(0, 20, 1, -20)
	outer.AnchorPoint = Vector2.new(0, 1)
	outer.BackgroundColor3 = PANEL_COLOR
	outer.BackgroundTransparency = baseTransparency
	outer.Parent = parent

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0.5, 0)
	outerCorner.Parent = outer

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = STROKE_COLOR
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.4
	outerStroke.Parent = outer

	local inner = Instance.new("Frame")
	inner.Name = "JoystickInner"
	inner.Size = UDim2.new(0, INNER_SIZE, 0, INNER_SIZE)
	inner.Position = UDim2.new(0.5, 0, 0.5, 0)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = ACCENT_COLOR
	inner.BackgroundTransparency = 0.3
	inner.Parent = outer

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.5, 0)
	innerCorner.Parent = inner

	local activeInputId = nil

	local function updateFromPosition(touchPos: Vector3)
		local outerAbsPos = outer.AbsolutePosition
		local outerAbsSize = outer.AbsoluteSize
		local centerX = outerAbsPos.X + outerAbsSize.X / 2
		local centerY = outerAbsPos.Y + outerAbsSize.Y / 2

		local dx = touchPos.X - centerX
		local dy = touchPos.Y - centerY
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist > MAX_RADIUS then
			dx = dx / dist * MAX_RADIUS
			dy = dy / dist * MAX_RADIUS
			dist = MAX_RADIUS
		end

		inner.Position = UDim2.new(0.5, dx, 0.5, dy)
		joystickState.x = math.clamp(dx / MAX_RADIUS, -1, 1)
	end

	local function resetJoystick()
		inner.Position = UDim2.new(0.5, 0, 0.5, 0)
		joystickState.x = 0
		activeInputId = nil
		outerStroke.Color = STROKE_COLOR
	end

	table.insert(connections, outer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInputId = input
			outerStroke.Color = ACCENT_COLOR
			updateFromPosition(input.Position)
		end
	end))

	table.insert(connections, outer.InputChanged:Connect(function(input)
		if activeInputId and (input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateFromPosition(input.Position)
		end
	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if activeInputId and input == activeInputId then
			updateFromPosition(input.Position)
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if activeInputId and input == activeInputId then
			resetJoystick()
		end
	end))

	return outer
end

----------------------------------------------------------------
-- InputManager
----------------------------------------------------------------

function InputManager.new(settings: InputSettings?)
	local self = setmetatable({}, InputManager)

	local s = {}
	for k, v in DEFAULT_SETTINGS do
		s[k] = v
	end
	if settings then
		for k, v in settings do
			if DEFAULT_SETTINGS[k] ~= nil then
				s[k] = v
			end
		end
	end
	self._settings = s

	self._keysHeld = {} :: { [Enum.KeyCode]: boolean }
	self._connections = {} :: { RBXScriptConnection }
	self._touchState = {
		steerLeft = false,
		steerRight = false,
		gas = false,
		brake = false,
		handbrake = false,
	}
	self._joystickState = { x = 0 }
	self._tiltSteer = 0
	self._mobileGui = nil :: ScreenGui?

	self:_bindKeyboard()

	if IS_TOUCH then
		self:_createMobileControls()
		if s.steerMode == "tilt" then
			self:_bindTiltSteering()
		end
	end

	return self
end

function InputManager:_bindKeyboard()
	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode then
			self._keysHeld[input.KeyCode] = true
		end
	end))

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input, _processed)
		if input.KeyCode then
			self._keysHeld[input.KeyCode] = nil
		end
	end))
end

function InputManager:_bindTiltSteering()
	local deadzone = self._settings.tiltDeadzone or 0.08
	local sensitivity = self._settings.steerSensitivity or 1.0

	table.insert(self._connections, UserInputService.DeviceGravityChanged:Connect(function(gravity: InputObject)
		local x = gravity.Position.X
		if math.abs(x) < deadzone then
			self._tiltSteer = 0
		else
			local adjusted = (math.abs(x) - deadzone) / (1 - deadzone)
			self._tiltSteer = math.clamp(adjusted * (if x > 0 then 1 else -1) * sensitivity * 3, -1, 1)
		end
	end))
end

function InputManager:_createMobileControls()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileDrivingControls"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	self._mobileGui = gui

	local ts = self._touchState
	local conns = self._connections
	local s = self._settings

	local baseTransparency = 1.0 - math.clamp(s.buttonOpacity, 0, 1)
	local scale = math.clamp(s.buttonScale, 0.5, 2.0)

	local BTN_W = math.floor(110 * scale)
	local BTN_H = math.floor(120 * scale)
	local GAP = 10
	local MARGIN = 20

	-- Left side: steering (mode-dependent)
	if s.steerMode == "joystick" then
		createVirtualJoystick(gui, self._joystickState, conns, baseTransparency, scale)
	elseif s.steerMode ~= "tilt" then
		createTouchButton(
			"steerLeft", "\226\151\132",
			UDim2.new(0, MARGIN, 1, -MARGIN),
			UDim2.new(0, BTN_W, 0, BTN_H),
			gui, ts, conns, baseTransparency, math.floor(36 * scale)
		)

		createTouchButton(
			"steerRight", "\226\150\186",
			UDim2.new(0, MARGIN + BTN_W + GAP, 1, -MARGIN),
			UDim2.new(0, BTN_W, 0, BTN_H),
			gui, ts, conns, baseTransparency, math.floor(36 * scale)
		)
	end

	-- Right side: gas (top), brake (bottom), handbrake (left of gas)
	if not s.autoGas then
		createTouchButton(
			"gas", "GAS",
			UDim2.new(1, -MARGIN, 1, -MARGIN - BTN_H - GAP),
			UDim2.new(0, BTN_W, 0, BTN_H),
			gui, ts, conns, baseTransparency
		)
	end

	createTouchButton(
		"brake", "BRK",
		UDim2.new(1, -MARGIN, 1, -MARGIN),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns, baseTransparency
	)

	createTouchButton(
		"handbrake", "HB",
		UDim2.new(1, -MARGIN - BTN_W - GAP, 1, -MARGIN - BTN_H - GAP),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns, baseTransparency, math.floor(22 * scale)
	)

	-- Auto-gas indicator
	if s.autoGas then
		local label = Instance.new("TextLabel")
		label.Name = "AutoGasIndicator"
		label.Text = "AUTO"
		label.Size = UDim2.new(0, BTN_W, 0, 30)
		label.Position = UDim2.new(1, -MARGIN, 1, -MARGIN - BTN_H - GAP - 35)
		label.AnchorPoint = Vector2.new(0, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = ACCENT_COLOR
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end
end

function InputManager:getState(): InputState
	local keys = self._keysHeld
	local touch = self._touchState
	local s = self._settings

	-- Keyboard
	local fwd = if keys[Enum.KeyCode.W] or keys[Enum.KeyCode.Up] then 1 else 0
	local rev = if keys[Enum.KeyCode.S] or keys[Enum.KeyCode.Down] then 1 else 0
	local left: number = if keys[Enum.KeyCode.A] or keys[Enum.KeyCode.Left] then 1 else 0
	local right: number = if keys[Enum.KeyCode.D] or keys[Enum.KeyCode.Right] then 1 else 0
	local hb = if keys[Enum.KeyCode.Space] then 1 else 0

	-- Touch button input
	if touch.gas then fwd = 1 end
	if touch.brake then rev = 1 end
	if touch.steerLeft then left = 1 end
	if touch.steerRight then right = 1 end
	if touch.handbrake then hb = 1 end

	-- Auto-gas
	if s.autoGas and IS_TOUCH then
		fwd = math.max(fwd, 1)
	end

	-- Virtual joystick steering
	local joystickSteer = 0
	if s.steerMode == "joystick" then
		joystickSteer = self._joystickState.x * (s.steerSensitivity or 1.0)
	end

	-- Tilt steering
	local tiltSteer = 0
	if s.steerMode == "tilt" then
		tiltSteer = self._tiltSteer
	end

	-- Gamepad
	if UserInputService.GamepadEnabled then
		local ok, state = pcall(function()
			return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		end)
		if ok and state then
			for _, input in state do
				if input.KeyCode == Enum.KeyCode.Thumbstick1 then
					local x = input.Position.X
					if x < -0.15 then left = math.max(left, -x) end
					if x > 0.15 then right = math.max(right, x) end
				elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
					local val = input.Position.Z
					if val > 0.1 then fwd = math.max(fwd, val) end
				elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
					local val = input.Position.Z
					if val > 0.1 then rev = math.max(rev, val) end
				elseif input.KeyCode == Enum.KeyCode.ButtonA then
					if input.Position.Z > 0.5 then hb = 1 end
				end
			end
		end
	end

	local steer = (right - left) + joystickSteer + tiltSteer

	-- Apply sensitivity multiplier to button steering
	if s.steerMode == "buttons" and IS_TOUCH then
		steer = steer * (s.steerSensitivity or 1.0)
	end

	return {
		throttle = math.clamp(fwd - rev, -1, 1),
		steer = math.clamp(steer, -1, 1),
		brake = 0,
		handbrake = hb,
	}
end

function InputManager:getSettings(): InputSettings
	local copy = {}
	for k, v in self._settings do
		copy[k] = v
	end
	return copy
end

function InputManager:destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._keysHeld)

	for k in self._touchState do
		self._touchState[k] = false
	end
	self._joystickState.x = 0
	self._tiltSteer = 0

	if self._mobileGui then
		self._mobileGui:Destroy()
		self._mobileGui = nil
	end
end

return InputManager
