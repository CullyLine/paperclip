# Phase 4 — Session boundary & re-engagement copy map

**Purpose:** Single source for **where** session-edge copy lives (welcome, idle, streak, soft wrap) so audits do not miss a pool. Cross-check against `docs/RetentionWinbackMicrocopySpec.md` and `MicrocopyConfig` section headers.

---

## 1. Session start (return / streak / win-back)

| Pool | File | Consumed by |
|------|------|-------------|
| `FirstSessionWelcomeToast` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (first session, before `firstPlaySessionEnded`) |
| `SessionWinback14d` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (`daysAway >= 14`) |
| `SessionWinback7d` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (`daysAway >= 7`) |
| `ReturnStreakWelcome` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (`streak >= 2` and `daysAway >= 1`) |
| `SessionWelcomeStreak` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (`streak >= 2`, same day) |
| `SessionWelcome` | `MicrocopyConfig.luau` | `Bootstrap.local.luau` (default welcome) |

**Server fields:** `retention.daysSinceLastSession`, `dailyReward.streak`, `firstSessionOnboarding.*` — see `Bootstrap.local.luau` + `DataManager.luau`.

---

## 2. Idle (AFK) — high-urgency modal

| Role | Source | Notes |
|------|--------|--------|
| Header | `MicrocopyConfig.RetentionIdleHeader` | `RetentionController` — random variant |
| Body | `SocialFeedConfig.SessionEndRetention` | Same controller — **not** the header pool; paired intentionally |
| Context rows | Built in `RetentionController.buildContextLines` | Daily reward timer, BP XP, egg pity streak, etc. (dynamic) |

**Trigger:** ~15 min idle, not in an active run, once per session (`DACStarterPlayerScripts/Controllers/RetentionController.luau`).

---

## 3. Soft session wrap & “tomorrow” (Phase 4 pools)

| Pool | File | Status (POLA-490 audit) |
|------|------|-------------------------|
| `RetentionSoftSessionWrap` | `MicrocopyConfig.luau` | **Defined — no consumer found** in `*.luau` (engineer wiring follow-up) |
| `RetentionReturnTomorrow` | `MicrocopyConfig.luau` | **Defined — no consumer found** |
| `RetentionStreakSoftReminder` | `MicrocopyConfig.luau` | **Defined — no consumer found** |

**Intent (from config comments):** Calm closure distinct from AFK modal and from streak **panic** lines (`StreakFOMOWarning` / `StreakWarning*`).

---

## 4. Reconnect / Roblox disconnect

No dedicated **“you were disconnected”** client string surfaced in this pass beyond normal Remote failure paths. If product wants explicit reconnect copy, file a **new** engineering issue; do not overload `SessionEndRetention` (wrong tone for network faults).

---

## 5. Gaps & follow-ups

1. **Wire or remove** unused soft-retention pools (`RetentionSoftSessionWrap`, `RetentionReturnTomorrow`, `RetentionStreakSoftReminder`) once timing hooks exist (post-run, menu close, etc.).
2. **Studio pass:** AFK modal + welcome toast at 1080p — readability of header vs body (two different pools).
