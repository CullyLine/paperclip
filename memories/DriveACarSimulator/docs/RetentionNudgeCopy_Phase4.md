# Retention nudge copy — Phase 4 (streak risk & return)

**Parent:** POLA-104 — Phase 4 polish  
**Scope:** Pools that drive **streak-at-risk** urgency, **come-back-tomorrow** hooks, and **return-session** streak framing.  
**Sources:** `DACReplicatedStorage/Config/MicrocopyConfig.luau` (see comments for consumers: `DailyRewardPanel.luau`, `RetentionController.luau`, `Bootstrap.local.luau`, `PayoutPanel.luau`).

## Tone (Phase 4 matrix)

- **Reward-forward / bubbly:** energy and stakes without shaming the player (see `docs/RetentionWinbackMicrocopySpec.md`).
- **Fair urgency:** streak loss is real, but lines avoid guilt-tripping; soft pools (`RetentionStreakSoftReminder`, `RetentionReturnTomorrow`) deliberately sit below panic tiers.
- **Placeholders:** `{STREAK}` is substituted client-side; **Max chars** assumes a 2-digit streak (`{STREAK}` → 2 chars) unless noted.

---

| Pool key | Variant A | Variant B | Max chars |
|----------|-----------|-----------|-----------|
| `StreakFOMOWarning` | Your {STREAK}-day streak is ON THE LINE! Come back tomorrow! | Miss tomorrow and {STREAK} days of progress VANISH. Don't risk it! | ~78 |
| `StreakFOMOTomorrow` | Come back tomorrow for Day {STREAK} rewards! Don't break the chain! | Tomorrow's reward is waiting — Day {STREAK} unlocks something GOOD! | ~72 |
| `StreakWarning6h` | Your streak is fading! Come back before it's too late! | Don't let {STREAK} days of grinding go to WASTE! | ~62 |
| `StreakWarning2h` | ONLY 2 HOURS LEFT! Don't lose your {STREAK}-day streak! | TWO HOURS! {STREAK} days of progress on the LINE! | ~58 |
| `StreakWarning30m` | 30 MINUTES! Your streak is about to VANISH! | FINAL WARNING — {STREAK} days GONE in minutes! | ~52 |
| `RetentionStreakSoftReminder` | Day {STREAK} streak is active — claim when today's window fits you. | Your {STREAK}-day streak is still glowing — a short visit keeps it effortless. | ~88 |
| `RetentionReturnTomorrow` | Tomorrow's claim is a fresh stack — drop in when your day opens up. | See you tomorrow? The lobby keeps your lane warm. | ~72 |
| `ReturnStreakWelcome` | You're BACK — and still on a {STREAK}-day streak?! Main character energy! | Missed you! Streak still alive: {STREAK} days. Don't leave us hanging! | ~78 |
| `StreakLost` | Your {STREAK}-day streak is gone... Start rebuilding NOW! | The flame went out. {STREAK} days — GONE. Come back STRONGER. | ~68 |
| `StreakFOMOLost` | Streak BROKEN! You were at {STREAK} days... time to rebuild! | Ouch — {STREAK}-day streak GONE. Start fresh and go HARDER! | ~62 |
| `PlayStreak` | Day {STREAK} streak! You're on FIRE! 🔥 | STREAK x{STREAK}! Come back tomorrow to keep the party going! | ~58 |
| `PayoutStreakContinuation` | Day {STREAK} daily streak — keep claiming to stack bigger rewards! | Streak x{STREAK} still rolling! Tomorrow's claim levels you up! | ~72 |

**Row count:** 12.

## Related pools (out of table cap)

For absence win-back and first-session streak education, see `SessionWinback7d`, `SessionWinback14d`, and `FirstSessionDailyStreak` in the same config file — same voice, different gates (`Bootstrap.local.luau` / onboarding).

## Maintenance

When editing lines in `MicrocopyConfig`, update **Variant A/B** here to match two live strings (or refresh counts if placeholders change).
