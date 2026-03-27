# Retention & win-back microcopy pack (POLA-284)

**Parent:** POLA-104 — Phase 4: Dopamine maximization & juice polish  
**Role:** Content Strategist — session hooks, streak framing, soft absence win-back  
**Status:** Implemented in `MicrocopyConfig`, `SocialFeedConfig`, `Bootstrap.local.luau`, `RetentionController.luau`, server `DataManager` / `MainServer`.

## Phase 4 tone matrix alignment

Aligned with `docs/MicrocopyWhaleTermCleanup_Phase4.md` and `docs/store/PremiumUpsellToneMatrix.md`:

| Lane | How we use it here |
|------|---------------------|
| **Reward-forward** | Lines emphasize coins, streaks, pets, Battle Pass, PB — never shame spend or identity. |
| **Bubbly / sim** | Short, loud, playful — same voice as `SessionWelcome` and payout flex. |
| **Avoid** | Player-directed “whale” slang; guilt trips for absence; implying guaranteed rare drops. |

## Server: absence signal

- **Persisted:** `stats.lastSessionEndUnix` (set on player unload / save path that runs on leave).
- **Client-only (not saved):** `retention.daysSinceLastSession` — whole calendar days between last session end and current join (`DataManager.injectClientSessionFields`).
- **Stripped before DataStore write:** `data.retention` removed in `DataManager.save`.

## Session-start priority (welcome toast)

Order in `DACStarterPlayerScripts/Bootstrap.local.luau`:

1. **`daysSinceLastSession >= 14`** → `MicrocopyConfig.SessionWinback14d`
2. **`>= 7`** → `MicrocopyConfig.SessionWinback7d`
3. **`streak >= 2` and `daysAway >= 1`** → `MicrocopyConfig.ReturnStreakWelcome` (`{STREAK}`)
4. **`streak >= 2`** → `MicrocopyConfig.SessionWelcomeStreak`
5. Else → `MicrocopyConfig.SessionWelcome`

## Idle / AFK retention modal

- **Header:** `MicrocopyConfig.RetentionIdleHeader` (random; one pick per client session — set when the popup UI is built).
- **Body line:** `SocialFeedConfig.SessionEndRetention` (existing pool + Phase 4 lines).
- **Context rows:** Still informational (daily / Battle Pass / pity) from `RetentionController.buildContextLines`.

## Related pools (unchanged but same voice)

- Daily streak FOMO / countdown: `StreakFOMOWarning`, `StreakWarning6h`, etc.
- Push-style streak loss: `StreakLost` (separate from welcome win-back).

## Maintenance

- Add new lines to the tables above; keep placeholders documented (`{STREAK}` only where substituted).
- Grep: `SessionWinback`, `ReturnStreakWelcome`, `RetentionIdleHeader`, `retention.daysSinceLastSession`.

#### Files on disk

| File | Role |
|------|------|
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | Win-back, return+streak, idle headers |
| `DACReplicatedStorage/Config/SocialFeedConfig.luau` | `SessionEndRetention` body lines |
| `DACStarterPlayerScripts/Bootstrap.local.luau` | Welcome toast priority |
| `DACStarterPlayerScripts/Controllers/RetentionController.luau` | Idle modal header |
| `DACServerScriptService/DataManager.luau` | `lastSessionEndUnix`, inject/strip retention |
| `DACServerScriptService/MainServer.server.luau` | Inject before `GetPlayerData` / join `DataUpdate` |
