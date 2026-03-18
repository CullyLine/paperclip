--[[
	InputManager — Input abstraction for Downhill Madness.
	
	Provides a unified interface for keyboard, gamepad, and mobile.
	M0: Keyboard fully implemented. Gamepad/mobile are stubbed placeholders.
	
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

local InputManager = {}
InputManager.__index = InputManager

export type InputState = {
	throttle: number,
	steer: number,
	brake: number,
	handbrake: number,
}

function InputManager.new()
	local self = setmetatable({}, InputManager)

	self._keysHeld = {} :: { [Enum.KeyCode]: boolean }
	self._connections = {} :: { RBXScriptConnection }

	self:_bindKeyboard()

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

function InputManager:getState(): InputState
	local keys = self._keysHeld

	-- Throttle: W or Up = forward, S or Down = reverse
	local fwd = if keys[Enum.KeyCode.W] or keys[Enum.KeyCode.Up] then 1 else 0
	local rev = if keys[Enum.KeyCode.S] or keys[Enum.KeyCode.Down] then 1 else 0
	local throttle = fwd - rev

	-- Steer: A or Left = left (-1), D or Right = right (+1)
	local left = if keys[Enum.KeyCode.A] or keys[Enum.KeyCode.Left] then 1 else 0
	local right = if keys[Enum.KeyCode.D] or keys[Enum.KeyCode.Right] then 1 else 0
	local steer = right - left

	-- Brake: auto-brake when throttle opposes current motion (handled in physics loop)
	local brake = 0

	-- Handbrake: Space
	local handbrake = if keys[Enum.KeyCode.Space] then 1 else 0

	-- Gamepad stub (M8)
	if UserInputService.GamepadEnabled then
		-- TODO: Read gamepad triggers/sticks
	end

	return {
		throttle = throttle,
		steer = steer,
		brake = brake,
		handbrake = handbrake,
	}
end

function InputManager:destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._keysHeld)
end

return InputManager
