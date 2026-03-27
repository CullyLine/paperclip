--!strict
--[[
	UTC Unix window for Founder's Bonus (2× coins), Early Driver title, and HUD countdown.
	Single source of truth: server applies this in EventService; client receives
	LaunchEventState (founderEndsAtUnix, serverTimeUnix). All times are UTC epoch seconds.

	See docs/Launch_EventWindowConfig_Checklist.md before changing values.
]]

local EventWindowConfig = {}

-- Edit before go-live; keep Microcopy founder strings aligned (2× coins only).
EventWindowConfig.FOUNDER_WINDOW_START_UTC = 1773878400 -- 2026-03-19T00:00:00Z
EventWindowConfig.FOUNDER_WINDOW_END_UTC = 1774051200 -- 2026-03-21T00:00:00Z (48h)

-- Human-readable UTC string for audits (copy/marketing); not shown in HUD by default.
EventWindowConfig.SCHEDULE_DISPLAY_UTC = "2026-03-19 00:00 UTC to 2026-03-21 00:00 UTC (48h)"

return EventWindowConfig
