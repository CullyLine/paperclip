--!strict
--[[
	Pending state for manual rebirth RemoteEvent (POLA-521).
	- Disables the primary rebirth button while a request is in flight.
	- Clears when rebirth count advances (DataUpdate) or after timeout (server error / no DataUpdate).
	Idempotency uses client snapshot (expected rebirth index) on the server; this module is UX-only.
]]

local Constants = require(script.Parent:WaitForChild("Constants"))

local RebirthClientState = {}

local pending = false
local snapshotAtSend = 0
local timeoutTask: thread? = nil
local registeredBtn: GuiButton? = nil

local function syncButton()
	local b = registeredBtn
	if b and b.Parent then
		b.Active = not pending
	end
end

function RebirthClientState.registerPrimaryButton(btn: GuiButton?)
	registeredBtn = btn
	syncButton()
end

function RebirthClientState.begin(expectedRebirths: number): boolean
	if pending then
		return false
	end
	pending = true
	snapshotAtSend = math.max(0, math.floor(expectedRebirths))
	if timeoutTask then
		task.cancel(timeoutTask)
		timeoutTask = nil
	end
	local delaySec = Constants.REBIRTH_CLIENT_PENDING_TIMEOUT_SEC
	if type(delaySec) ~= "number" or delaySec <= 0 then
		delaySec = 8
	end
	timeoutTask = task.delay(delaySec, function()
		timeoutTask = nil
		if pending then
			pending = false
			syncButton()
		end
	end)
	syncButton()
	return true
end

function RebirthClientState.clearIfRebirthAdvanced(newRebirths: number): boolean
	if not pending then
		return false
	end
	local n = math.max(0, math.floor(newRebirths))
	if n > snapshotAtSend then
		pending = false
		if timeoutTask then
			task.cancel(timeoutTask)
			timeoutTask = nil
		end
		syncButton()
		return true
	end
	return false
end

function RebirthClientState.isPending(): boolean
	return pending
end

function RebirthClientState.forceRelease()
	if not pending then
		return
	end
	pending = false
	if timeoutTask then
		task.cancel(timeoutTask)
		timeoutTask = nil
	end
	syncButton()
end

return RebirthClientState
