# Launch — Founder's Bonus window (UTC)

**Canonical config:** `DACReplicatedStorage/Config/EventWindowConfig.luau` — `FOUNDER_WINDOW_START_UTC` and `FOUNDER_WINDOW_END_UTC` (Unix seconds, UTC). `EventService` reads these values. The same window drives:

- **2× coin multiplier** (`getFounderCoinMultiplier`)
- **Early Driver** title grant for first join in window (`joinedDuringLaunch` / `early_driver` in `Constants.TITLES`)
- **HUD banner + countdown** (`LaunchEventState` → `DACStarterGui/EventBanner.luau`)

## Values at last edit (confirm before publish)

| Constant | Unix (UTC) | Human (UTC) |
|----------|------------|---------------|
| `FOUNDER_WINDOW_START_UTC` | `1773878400` | 2026-03-19T00:00:00Z |
| `FOUNDER_WINDOW_END_UTC` | `1774051200` | 2026-03-21T00:00:00Z (48h after start) |

If you change the timestamps, update the table above and grep player-facing copy for stale dates or wrong multipliers.

## Player-facing copy — must match economics

All strings below must describe **2× coins** during this window only (no 3×, no unrelated “exclusive egg” hype unless that product exists for the same window).

| Location | What to verify |
|----------|----------------|
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | `FounderEventBannerHeadlines`, `FounderEventCountdown`, `FounderBonusJoinNotification` |
| `DACStarterGui/EventBanner.luau` | Uses founder pools only when `LaunchEventState.founderActive` |
| `DACServerScriptService/Services/EventService.luau` | Join notification uses `MicrocopyConfig.FounderBonusJoinNotification` |
| `DACStarterGui/PayoutPanel.luau` | `PayoutBadgeFounderFormat` — multiplier display, not a schedule |

**Do not** use `MicrocopyConfig.EventBannerHeadlines` for the Founder's Bonus window; that pool is reserved for other timed events and may promise different rewards.

## Related ops docs

- `PreLaunchChecklist.md` — Founder's Bonus go-live checklist (marketing / Discord).
- `DACReplicatedStorage/Constants.luau` — `early_driver` display name (“Early Driver”).
