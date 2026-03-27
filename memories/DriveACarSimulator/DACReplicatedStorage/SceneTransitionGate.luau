--!strict
--[[
	POLA-465: Single flag for loading / teleport / world-travel transitions.
	While active: block duplicate travel UI, treat as gameplay-input block (see UIController),
	and keep driving steer/horn suppressed (via UIController.isBlockingGameplayInput).
]]

local SceneTransitionGate = {}

local active = false

function SceneTransitionGate.setActive(v: boolean)
	active = v
end

function SceneTransitionGate.isActive(): boolean
	return active
end

--[[
	Atomically start a transition if none is running. Call from VFXController.worldTransition
	after any yielding Remote work so double-clicks cannot both pass.
]]
function SceneTransitionGate.tryBegin(): boolean
	if active then
		return false
	end
	active = true
	return true
end

return SceneTransitionGate
