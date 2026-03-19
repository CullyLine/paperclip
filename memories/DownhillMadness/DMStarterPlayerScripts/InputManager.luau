--[[
	InputManager — Input abstraction for Downhill Madness.

	Provides a unified interface for keyboard, gamepad, and mobile.
	Automatically detects touch devices and creates on-screen driving
	controls (steering arrows, gas, brake, handbrake).

	Touch controls are created when InputManager.new() is called and
	destroyed when input:destroy() is called — so they only appear
	while the player is actively driving.

	Usage:
	  local InputManager = require(script.Parent.InputManager)
	  local input = InputManager.new()
	  -- each frame:
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

local IS_TOUCH = UserInputService.TouchEnabled

----------------------------------------------------------------
-- Style constants (matches HubScreen)
----------------------------------------------------------------

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local PANEL_TRANSPARENCY = 0.3
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
	fontSize: number?
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Position = position
	btn.Size = size
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = PANEL_COLOR
	btn.BackgroundTransparency = PANEL_TRANSPARENCY
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

	-- Multi-touch tracking: count active touches so overlapping
	-- fingers don't cause premature release
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
				btn.BackgroundTransparency = PANEL_TRANSPARENCY
				stroke.Color = STROKE_COLOR
				stroke.Transparency = 0.5
			end
		end
	end))

	return btn
end

----------------------------------------------------------------
-- InputManager
----------------------------------------------------------------

function InputManager.new()
	local self = setmetatable({}, InputManager)

	self._keysHeld = {} :: { [Enum.KeyCode]: boolean }
	self._connections = {} :: { RBXScriptConnection }
	self._touchState = {
		steerLeft = false,
		steerRight = false,
		gas = false,
		brake = false,
		handbrake = false,
	}
	self._mobileGui = nil :: ScreenGui?

	self:_bindKeyboard()

	if IS_TOUCH then
		self:_createMobileControls()
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

	--[[
		Layout (bottom of screen, thumb-reach zones):

		Left thumb:                          Right thumb:
		┌──────┐ ┌──────┐           ┌──────┐ ┌──────┐
		│  ◄   │ │  ►   │           │  HB  │ │ GAS  │
		│      │ │      │           │      │ │      │
		└──────┘ └──────┘           └──────┘ └──────┘
		                            ┌──────┐
		                            │ BRK  │
		                            └──────┘

		Gas is top-right (primary thumb resting spot).
		Brake is below gas (quick thumb slide down).
		Handbrake is left of gas (drift access).
		Steering arrows are bottom-left, large targets.
	]]

	local BTN_W = 110
	local BTN_H = 120
	local GAP = 10
	local MARGIN = 20

	-- Left side: steering
	createTouchButton(
		"steerLeft", "◄",
		UDim2.new(0, MARGIN, 1, -MARGIN),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns, 36
	)

	createTouchButton(
		"steerRight", "►",
		UDim2.new(0, MARGIN + BTN_W + GAP, 1, -MARGIN),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns, 36
	)

	-- Right side: gas (top), brake (bottom), handbrake (left of gas)
	createTouchButton(
		"gas", "GAS",
		UDim2.new(1, -MARGIN, 1, -MARGIN - BTN_H - GAP),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns
	)

	createTouchButton(
		"brake", "BRK",
		UDim2.new(1, -MARGIN, 1, -MARGIN),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns
	)

	createTouchButton(
		"handbrake", "HB",
		UDim2.new(1, -MARGIN - BTN_W - GAP, 1, -MARGIN - BTN_H - GAP),
		UDim2.new(0, BTN_W, 0, BTN_H),
		gui, ts, conns, 22
	)
end

function InputManager:getState(): InputState
	local keys = self._keysHeld
	local touch = self._touchState

	-- Keyboard
	local fwd = if keys[Enum.KeyCode.W] or keys[Enum.KeyCode.Up] then 1 else 0
	local rev = if keys[Enum.KeyCode.S] or keys[Enum.KeyCode.Down] then 1 else 0
	local left = if keys[Enum.KeyCode.A] or keys[Enum.KeyCode.Left] then 1 else 0
	local right = if keys[Enum.KeyCode.D] or keys[Enum.KeyCode.Right] then 1 else 0
	local hb = if keys[Enum.KeyCode.Space] then 1 else 0

	-- Touch (additive — both inputs work simultaneously)
	if touch.gas then fwd = 1 end
	if touch.brake then rev = 1 end
	if touch.steerLeft then left = 1 end
	if touch.steerRight then right = 1 end
	if touch.handbrake then hb = 1 end

	-- Gamepad (reads left stick + triggers when a gamepad is connected)
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

	return {
		throttle = fwd - rev,
		steer = right - left,
		brake = 0,
		handbrake = hb,
	}
end

function InputManager:destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._keysHeld)

	-- Reset touch state
	for k in self._touchState do
		self._touchState[k] = false
	end

	-- Destroy mobile GUI
	if self._mobileGui then
		self._mobileGui:Destroy()
		self._mobileGui = nil
	end
end

return InputManager
