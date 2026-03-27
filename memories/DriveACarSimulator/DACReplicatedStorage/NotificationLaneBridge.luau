--!strict
--[[
	Thin callback bridge for Phase4NotificationLaneJuiceSpec §3–4: [C] achievement lane
	must resume after blocking [E] payout or [G] ceremony queue without circular
	requires between VFXController and AchievementController.
]]

local Players = game:GetService("Players")

local NotificationLaneBridge = {}

local resume: (() -> ())? = nil

function NotificationLaneBridge.register(callback: () -> ())
	resume = callback
end

function NotificationLaneBridge.resume()
	local fn = resume
	if fn then
		task.defer(function()
			local lp = Players.LocalPlayer
			if lp and lp.Parent then
				fn()
			end
		end)
	end
end

return NotificationLaneBridge
