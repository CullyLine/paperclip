--!strict
--[[
	HUD right-rail toast stack — priority tiers and tuning (POLA-332).
	Used by UIController.showNotification / showToast.

	Primary entry points (server → client Remotes.Notification or direct UI):
	- Server must use `DACServerScriptService/Services/NotificationDispatchService.luau` (POLA-492) for all HUD toasts.
	- `DACStarterPlayerScripts/Bootstrap.local.luau` (Notification remote, EasterEgg)
	- `DACReplicatedStorage/RemoteFailSafe.luau`
	- `DACStarterGui/EggShopPanel.luau` (first-session success)
	- `DACStarterPlayerScripts/Controllers/RetentionController.luau` (streak kinds)

	Achievement unlock/progress uses `AchievementController` + NotificationLaneBridge (separate lane).
]]

local HudToastConfig = {}

-- Higher number = more important when competing for visible slots.
HudToastConfig.PRIORITY_CRITICAL = 100
HudToastConfig.PRIORITY_URGENT = 85
HudToastConfig.PRIORITY_ACHIEVEMENT = 60
HudToastConfig.PRIORITY_INFO = 40

-- Visible stack cap (Phase 4: 1–2 simultaneous; we use 2).
HudToastConfig.MAX_VISIBLE_TOASTS = 2

-- Drop duplicate identical messages within this window (seconds).
HudToastConfig.COALESCE_WINDOW_SEC = 2.5

-- During an active drive, only priorities >= this may show immediately (critical + urgent).
HudToastConfig.MIN_PRIORITY_DURING_RUN = HudToastConfig.PRIORITY_URGENT

local function priorityFromString(s: string): number?
	local lower = string.lower(s)
	if lower == "critical" then
		return HudToastConfig.PRIORITY_CRITICAL
	elseif lower == "urgent" or lower == "high" then
		return HudToastConfig.PRIORITY_URGENT
	elseif lower == "achievement" or lower == "success" then
		return HudToastConfig.PRIORITY_ACHIEVEMENT
	elseif lower == "info" or lower == "low" then
		return HudToastConfig.PRIORITY_INFO
	end
	return nil
end

function HudToastConfig.resolvePriority(kind: string, notification: any): number
	if type(notification) == "table" then
		local n = notification :: any
		if n.critical == true then
			return HudToastConfig.PRIORITY_CRITICAL
		end
		if type(n.priority) == "number" then
			return math.clamp(n.priority, 0, 200)
		end
		if type(n.priority) == "string" then
			local p = priorityFromString(n.priority)
			if p then
				return p
			end
		end
	end
	if kind == "streak_critical" or kind == "error" then
		return HudToastConfig.PRIORITY_CRITICAL
	end
	if kind == "streak_urgent" then
		return HudToastConfig.PRIORITY_URGENT
	end
	if kind == "streak_celebrate" or kind == "success" then
		return HudToastConfig.PRIORITY_ACHIEVEMENT
	end
	return HudToastConfig.PRIORITY_INFO
end

function HudToastConfig.coalesceKey(kind: string, msg: string): string
	return kind .. "\0" .. msg
end

return HudToastConfig
