# Achievement copy ↔ server parity matrix

**Player-facing strings:** `DACReplicatedStorage/Config/AchievementPopupConfig.luau` (`AchievementPopupConfig.Achievements`).

**Unlocks:** `AchievementService.tryUnlock` in `DACServerScriptService/Services/AchievementService.luau`. Additional callers: `EggService` (egg rarity), `MilestoneCeremonyService` (`world_elite`).

**Rarity for trophy UI:** `RARITY_BY_ID` in `AchievementService.luau` (bronze / silver / gold / diamond).

| id | Unlock condition (server truth) | Popup title | Popup body | Rarity tone |
|----|--------------------------------|-------------|------------|-------------|
| `first_drive` | `totalRunsCompleted` ≥ 1 after a run | FIRST DRIVE! | Complete your very first run. | bronze |
| `speed_demon` | Run peak/effective speed ≥ 100 (same run) | SPEED DEMON! | Reach 100 studs/s in a single run. | bronze |
| `world_tourer` | At least one completed run in every **unlocked** world | WORLD TOURER! | Complete a run in every world you've unlocked. | gold |
| `runs_10` | `totalRunsCompleted` ≥ 10 | ROAD REGULAR! | Complete 10 runs. You're getting the hang of it! | bronze |
| `runs_100` | `totalRunsCompleted` ≥ 100 | HIGHWAY VETERAN! | Complete 100 runs. The asphalt knows your name! | gold |
| `combo_inferno` | Near-miss chain ≥ 20 in one run | COMBO INFERNO! | Hit a ×20 near-miss chain in a single run. Untouchable! | gold |
| `garage_full` | Own every car in `CarConfig` (`#data.cars` ≥ car def count) | FULL GARAGE! | Own every car in the showroom. Collector supreme! | diamond |
| `world_elite` | World mastery milestone claimed for the **last** world in `WorldConfig.getWorldsSorted()` (`milestoneCopyClaimed.worldMastery[lastId]`) | WORLD ELITE! | Complete world mastery for the final map. End of the road! | gold |
| `first_hatch` | `totalEggsHatched` ≥ 1 | EGG CRACKER! | Hatch your very first pet. | bronze |
| `hatch_100` | `totalEggsHatched` ≥ 100 | HATCH CENTURY! | Hatch 100 eggs total. Keep cracking! | silver |
| `full_index` | Discovered pet species count ≥ total `PetConfig` pets | COMPLETIONIST! | Discover every pet in the index. Every. Single. One! | diamond |
| `legendary_hatch` | Any hatch with Legendary or Mythic rarity | JACKPOT HATCH! | Hatch a Legendary or Mythic pet from an egg! | gold |
| `big_spender` | `coinsSpentTotal` ≥ 500,000 | BIG SPENDER! | Spend 500,000 coins in the shop. Baller! | silver |
| `rebirth_one` | `rebirths` ≥ 1 | REBORN! | Complete your first rebirth. Power surge! | bronze |
| `coin_tycoon` | `stats.totalCoinsEarned` ≥ 1,000,000 | COIN TYCOON! | Earn 1,000,000 lifetime coins. The economy runs through you! | gold |
| `daily_streak_7` | Daily reward streak ≥ 7 | WEEK WARRIOR! | Hit a 7-day login streak. | silver |
| `daily_streak_30` | Daily reward streak ≥ 30 | MONTH MONSTER! | Maintain a 30-day login streak. Dedication! | gold |
| `number_one` | Leaderboard rank == 1 on distance or rebirths board | #1 DRIVER! | Reach #1 on a leaderboard. KING! | gold |
| `top_ten` | Rank ≤ 10 and (first snapshot or moved from outside top 10) | TOP 10 TITAN! | Break into the top 10 on a global leaderboard! | silver |
| `quest_veteran` | `stats.questsCompletedTotal` ≥ 10 | QUEST VETERAN! | Complete 10 quests total. Always on the board! | silver |
| `egg_hunter` | Any entry in `discoveredEasterEggs` | EGG HUNTER! | Discover a hidden easter egg in the world! | diamond |
| `night_owl` | Same server session ≥ 60 minutes (`noteSessionStart` → `checkNightOwlSession`) | NIGHT OWL! | 60+ minutes in one session — the road never sleeps! | silver |
| `secret_speed_demon` | Run speed ≥ 500 in one run | MACH 500! | Hit 500+ speed in one run. Pure engine violence! | gold |
| `egg_straordinary` | `basic_egg` hatch → Legendary or Mythic | EGG-STRAORDINARY! | Legendary/Mythic from a Basic Egg. Luck on a budget! | gold |
| `lap_legend` | `laps` ≥ 100 in one run | LAP LEGEND! | 100 laps in one run. The highway is your treadmill! | diamond |
| `rebirth_royalty` | `rebirths` ≥ 10 | REBIRTH ROYALTY! | Reach Rebirth 10. The crown belongs to the persistent! | gold |

**Progress HUD (`fireProgress` only, no duplicate unlock):** `big_spender`, `hatch_100`, `daily_streak_7` (streak progress toward 7), `full_index`, `world_tourer`, `runs_100`, `coin_tycoon` — same ids as above.

## Board / product notes

- **POLA-95:** Game pass / dev-product asset IDs are separate from achievement ids.

## Change checklist

1. Add a row to `AchievementPopupConfig.Achievements` **and** wire `AchievementService.tryUnlock` (or call from `EggService` / `MilestoneCeremonyService` / etc.).
2. Add `RARITY_BY_ID` for the new id in `AchievementService.luau`.
3. Update this matrix in the same PR.
