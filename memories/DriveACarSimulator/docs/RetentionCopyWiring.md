# Retention copy wiring audit (POLA-284 / Phase 4 follow-up)

Audit date: 2026-03-22. Verifies that **POLA-284** retention microcopy packs are **referenced** by the intended systems: session hooks, return / streak welcome, idle (AFK) nudge, and streak timers.

Sources: `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `DACReplicatedStorage/Config/SocialFeedConfig.luau`, `DACStarterPlayerScripts/Bootstrap.local.luau`, `DACStarterPlayerScripts/Controllers/RetentionController.luau`, `DACStarterGui/DailyRewardPanel.luau`.

## Wiring table

| Copy key / pool | Intended consumer | Status | Notes |
|-----------------|-------------------|--------|-------|
| `MicrocopyConfig.SessionWelcome` | Session-start toast (`Bootstrap.local.luau`) | **Wired** | Default branch (`streak < 2` or first-session path). |
| `MicrocopyConfig.SessionWelcomeStreak` | Session-start toast (`Bootstrap.local.luau`) | **Wired** | When `streak >= 2` and not win-back / return-streak branch. `{STREAK}` substituted. |
| `MicrocopyConfig.ReturnStreakWelcome` | Session-start toast (`Bootstrap.local.luau`) | **Wired** | When `streak >= 2` and `daysAway >= 1` (server `retention.daysSinceLastSession`). Phase 4 pack. |
| `MicrocopyConfig.SessionWinback7d` | Session-start toast (`Bootstrap.local.luau`) | **Wired** | When `daysAway >= 7` (takes priority over streak branches). Phase 4 pack. |
| `MicrocopyConfig.SessionWinback14d` | Session-start toast (`Bootstrap.local.luau`) | **Wired** | When `daysAway >= 14`. Phase 4 pack. |
| `MicrocopyConfig.RetentionIdleHeader` | AFK idle modal header (`RetentionController.luau`) | **Wired** | `pickVariant(RetentionIdleHeader)` on card header. Phase 4 pack. |
| `SocialFeedConfig.SessionEndRetention` | AFK idle modal **body** (`RetentionController.luau` → `pickLine("SessionEndRetention")`) | **Wired** | Body text is a random line from this pool (includes Phase 4 “softer hooks” lines at end of table in config). |
| `MicrocopyConfig.StreakWarning6h` | Streak loss-aversion toasts (`RetentionController.streakTick`) | **Wired** | Fires when time-left crosses 6h threshold inside 48h claim window. |
| `MicrocopyConfig.StreakWarning2h` | Same | **Wired** | 2h threshold. |
| `MicrocopyConfig.StreakWarning30m` | Same | **Wired** | 30m threshold. |
| `MicrocopyConfig.StreakLost` | Same (commiseration / edge cases) | **Wired** | After streak loss detection in same tick loop. |
| `MicrocopyConfig.PlayStreak` | Periodic streak celebration toast (`RetentionController`) | **Wired** | **Not** session welcome; interval-based while in claim window (`PLAY_STREAK_INTERVAL_SEC`). |
| `MicrocopyConfig.StreakFOMOWarning` | Daily reward panel (`DailyRewardPanel.luau`) | **Wired** | Streak warning label in daily UI. |
| `MicrocopyConfig.StreakFOMOTomorrow` | Same | **Wired** | Tomorrow teaser. |
| `MicrocopyConfig.StreakFOMOLost` | Same | **Wired** | Lost-streak flavor. |
| `MicrocopyConfig.StreakFOMOMilestone` | Same | **Wired** | Milestone line. |

## Gaps / follow-ups

| Item | Severity | Owner | Detail |
|------|----------|-------|--------|
| `PlayStreak` comment block in `MicrocopyConfig.luau` | Low | Content | Previously implied HUD/session welcome; actual consumer is `RetentionController` periodic toast. **Corrected in config comment** in same change as this doc. |
| Push notification copy (`StreakWarning*` etc.) | N/A | — | Pools exist for future or external surfaces; in-client wiring is `RetentionController` only unless another system is added later. |

## Summary

- **Wiring table row count:** **16** (one row is `SocialFeedConfig.SessionEndRetention`; the rest are `MicrocopyConfig` pools).
- **Wired:** All Phase 4 retention strings checked above are **referenced** by live client code on the paths described.
- **Engineer ticket:** None required for wiring; optional future work is only if product wants **push** delivery to use the same pools (not in this audit scope).
