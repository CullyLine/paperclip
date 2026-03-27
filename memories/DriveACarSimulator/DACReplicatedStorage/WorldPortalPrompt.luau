--!strict
--[[
	Shared world portal / travel affordances: debounced confirm SFX + row focus ring pulse
	(WorldPanel and any future portal UIs should use this module.)
]]

local TweenService = game:GetService("TweenService")

local SoundFacade = require(script.Parent:WaitForChild("SoundFacade"))

local WorldPortalPrompt = {}

local CONFIRM_DEBOUNCE_SEC = 0.42
local lastPortalConfirmClock = -1e9

--- Plays `world_portal_confirm` at most once per debounce window (overlap / double-click safe).
function WorldPortalPrompt.tryPlayPortalConfirm(): boolean
	local now = os.clock()
	if now - lastPortalConfirmClock < CONFIRM_DEBOUNCE_SEC then
		return false
	end
	lastPortalConfirmClock = now
	SoundFacade.playOneShot("world_portal_confirm")
	return true
end

--- Ring pulse on the row stroke while pointer is over the row and travel/unlock is available.
function WorldPortalPrompt.bindRowFocusPulse(row: Frame, stroke: UIStroke, getCanFocus: () -> boolean): () -> ()
	local focusTween: Tween? = nil
	local baseThickness = stroke.Thickness

	local function stopFocus()
		if focusTween then
			focusTween:Cancel()
			focusTween = nil
		end
		stroke.Thickness = baseThickness
	end

	local function startFocus()
		if not getCanFocus() then
			return
		end
		stopFocus()
		baseThickness = stroke.Thickness
		focusTween = TweenService:Create(
			stroke,
			TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = math.min(baseThickness + 3.5, 12) }
		)
		focusTween:Play()
	end

	local enter = row.MouseEnter:Connect(function()
		if getCanFocus() then
			startFocus()
		end
	end)
	local leave = row.MouseLeave:Connect(stopFocus)

	return function()
		stopFocus()
		enter:Disconnect()
		leave:Disconnect()
	end
end

return WorldPortalPrompt
