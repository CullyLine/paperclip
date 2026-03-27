# Phase 4 — P0 parity spec (config ↔ server ↔ UI)

**Status:** Living document. **Related issues:** POLA-634 (drift), POLA-667 / POLA-668 (cross-links).

## Purpose

Define **P0 parity**: anything player-visible that is named in `DACReplicatedStorage/Config` must match what **servers** enforce and what **clients** display. Drift here is a ship blocker (wrong unlock text, impossible achievements, misleading monetization).

## Canonical map

| Layer | Source of truth |
|--------|------------------|
| Copy pools & thresholds | `DACReplicatedStorage/Config/*.luau` |
| Mechanics & gates | `DACServerScriptService/Services/*.luau` |
| HUD / panels | `DACStarterGui/*.luau`, `DACStarterPlayerScripts/Controllers/*.luau` |

**Full integration index:** [`Phase4_EngineerCopyIntegration_Index.md`](Phase4_EngineerCopyIntegration_Index.md)

## P0 checks (minimum before “parity” sign-off)

1. **Achievements:** IDs and thresholds in config match `AchievementService` / unlock paths — see [`AchievementCopyMatrix.md`](AchievementCopyMatrix.md).
2. **Worlds / travel:** `WorldUnlockConfig` and teaser copy match `WorldService` currency gates (not stale rebirth-only narratives unless code uses rebirth).
3. **Loading tips & microcopy:** Numbers (multipliers, costs, fuse rules) match live tuning in `WorldConfig`, `PetService`, etc. — see [`CopyPolishAudit.md`](CopyPolishAudit.md).
4. **No ship-risk strings:** Run greps in §4 of [`Phase4_EngineerCopyIntegration_Index.md`](Phase4_EngineerCopyIntegration_Index.md) (`TBD`, `lorem`, bad CTAs, `§` in player-visible text).

## When this doc changes

Update in the same change set as any bulk Luau string or config migration; bump the **Last reviewed** line below.

**Last reviewed:** 2026-03-22
