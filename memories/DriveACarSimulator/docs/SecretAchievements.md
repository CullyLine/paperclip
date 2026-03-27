# Secret achievements (Drive a Car Simulator)

Design rationale for hidden trophies in `AchievementPopupConfig` and server unlock logic in `AchievementService`.

## Philosophy

Secret achievements reward **curiosity, endurance, and skill spikes** without cluttering the main driving/collection tracks. They appear in the Trophy Case under the **secret** filter and use the same toast pipeline as other trophies.

## Definitions

| ID | Player-facing title | Unlock condition | Notes |
|----|---------------------|------------------|-------|
| `night_owl` | NIGHT OWL! | **60+ minutes** in one server session (wall clock from join) | Checked every 60s for all players with loaded data (not gated on being alive), aligned with the playtime service loop. |
| `secret_speed_demon` | MACH 500! | **500+ effective speed** stat on the car used for a completed run | Uses the run’s stored speed stat (same value as payout math). Distinct from the public `speed_demon` trophy at 100. |
| `egg_straordinary` | EGG-STRAORDINARY! | **Legendary or Mythic** hatch from **`basic_egg` only** | Harder than generic legendary hatch because basic egg odds are the harshest. |
| `lap_legend` | LAP LEGEND! | **100 laps** in a **single** run | Endurance flex; requires gas/upgrades to sustain long runs. |
| `rebirth_royalty` | REBIRTH ROYALTY! | **Rebirth count ≥ 10** | Aligns with prestige cadence and FOMO badge “ELITE” at 10 rebirths. |

Existing secret `egg_hunter` (easter egg discovery) is unchanged.

## Group reward copy

- **`LoadingTipsConfig`**: Loading-screen tips that mention the group bonus pet without pressure.
- **`SocialFeedConfig`**: `GroupJoinBanner` (prompt), `GroupRewardClaim` (celebration), `GroupMemberJoinFeed` (feed line with `{PLAYER}`). Wire these in UI when the Group Rewards feature surfaces each surface.

## Maintenance

- Any new secret achievement must be added to **`AchievementPopupConfig.Achievements`**, **`AchievementService.RARITY_BY_ID`**, **`TrophyCasePanel`’s `rarityForId` map**, and **`AchievementService.tryUnlock`** (or a dedicated hook) so the grid and toasts stay consistent.
