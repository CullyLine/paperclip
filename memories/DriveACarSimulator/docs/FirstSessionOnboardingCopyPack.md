# First-session onboarding copy pack — Drive a Car Simulator

**Date:** 2026-03-22  
**Issue:** POLA-291  
**Tone:** Phase 4 reward-forward; hook line: *Every run pays off.*

## §1 Surfaces

| Surface | Implementation |
|--------|------------------|
| Session welcome toast | `Bootstrap.local.luau` + `MicrocopyConfig.FirstSessionWelcomeToast` |
| First run payout brag | `PayoutPanel.luau` + `FirstSessionOnboardingService.prepareFirstPayout` |
| First hatch | `EggShopPanel.luau` + `prepareFirstHatch` |
| Empty trophy case | `TrophyCasePanel.luau` + `prepareEmptyTrophy` |
| Daily streak framing | `DailyRewardPanel.luau` + `prepareDailyStreak` |
| Tutorial steps 1–5 | `TutorialService.luau` + `MicrocopyConfig.FirstSessionTutorialStep*` |

## §2 Hook line rule

- **Exactly one** use of the tagline **"Every run pays off."** may appear during a player’s **first play session** (before their first disconnect that saves `firstPlaySessionEnded`).
- Server enforces via `firstSessionOnboarding.hookLineConsumed` in `FirstSessionOnboardingService`.
- **Priority** when multiple surfaces could show copy in the same session:
  1. First payout (while `pendingFirstPayout` is set) — preferred for the hook.
  2. First hatch — hook only if first payout overlay has already cleared `pendingFirstPayout`.
  3. Empty trophy / daily streak — hook only if `totalRunsCompleted >= 1` and first payout is not still pending.

## §3 Strings

- Canonical tagline: `MicrocopyConfig.FirstSessionTagline`.
- Pool lines: `FirstSessionPayoutBrag`, `FirstSessionHatchCopy`, `FirstSessionEmptyTrophy`, `FirstSessionDailyStreak`.

## §7 Profile flags (persisted)

Stored under `firstSessionOnboarding` in player data (`DataManager.getDefaultData`):

| Key | Meaning |
|-----|---------|
| `firstPlaySessionEnded` | Set `true` on first successful unload (first session closed). |
| `hookLineConsumed` | Tagline has been shown or skipped by migration. |
| `sessionWelcomeToastSeen` | First-session welcome toast acknowledged. |
| `firstPayoutCopySeen` | First payout copy shown. |
| `firstHatchCopySeen` | First hatch copy shown. |
| `emptyTrophyCaseCopySeen` | Empty-case hint shown. |
| `dailyStreakFramingSeen` | First-session daily streak framing shown. |

**Migration:** Players with `stats.totalRunsCompleted > 0` are treated as veterans: all flags forced to “seen” / ended on join (`migrateForExistingPlayers`).

## §8 Session-only (not persisted)

| Key | Meaning |
|-----|---------|
| `pendingFirstPayout[UserId]` | First run just completed; payout panel may claim first-payout copy + hook. |
| `pendingFirstHatch[UserId]` | First pet hatched this session; hatch notification may claim copy + hook. |

## Files on disk

- `DACServerScriptService/Services/FirstSessionOnboardingService.luau`
- `DACReplicatedStorage/Config/MicrocopyConfig.luau` (first-session tables)
- `DACReplicatedStorage/Remotes.luau` (`FirstSessionOnboarding` RemoteFunction)
- `DACServerScriptService/DataManager.luau` (defaults + unload sets `firstPlaySessionEnded`)
- `DACServerScriptService/MainServer.server.luau` (migrate on join)
- `DACServerScriptService/Services/RunService.luau`, `EggService.luau`, `TutorialService.luau`
- Client: `Bootstrap.local.luau`, `PayoutPanel.luau`, `EggShopPanel.luau`, `TrophyCasePanel.luau`, `DailyRewardPanel.luau`
