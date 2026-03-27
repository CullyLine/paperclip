--!strict
--[[
	Single source of truth for "player is in an active highway run" on the client.
	DrivingController sets this; HUD toast stack reads it to defer non-critical
	notifications during driving (POLA-332).
]]

local DrivingRunGate = {}

local inRun = false

function DrivingRunGate.setInRun(v: boolean)
	inRun = v
end

function DrivingRunGate.isInRun(): boolean
	return inRun
end

return DrivingRunGate
