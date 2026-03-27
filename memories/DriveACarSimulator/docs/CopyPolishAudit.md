# Copy Polish Audit — Drive a Car Simulator (POLA-230)

**Date:** 2026-03-22  
**Scope:** Player-facing strings in listed `DACReplicatedStorage/Config/*.luau` modules, cross-checked against `DACServerScriptService/Services/AchievementService.luau`, `WorldService.luau`, `WorldConfig.luau`, and `PetService.luau` (fuse).

## Executive summary

| Area | Finding | Action taken |
|------|---------|--------------|
| Achievements | POLA-230: config listed many trophies; server only exposed **10** IDs. | Trimmed then re-expanded in later work; **current** parity is tracked in `docs/AchievementCopyMatrix.md` (POLA-237). |
| World unlock | `WorldUnlockConfig.RebirthThresholdsByWorldId` did not match `WorldService` — worlds unlock with **currency only** (coins / gems / crystals), not rebirth count. Same data drove misleading “X rebirths to unlock” VFX nudges. | Cleared rebirth threshold table; rewrote `TravelTeaser` lines to reference saving coins/gems/crystals. |
| Loading tips | Several lines used unverifiable global stats; one line read as unsafe driving; fuse/mythic copy was imprecise. | Rephrased to match mechanics and tone rules. |
| Placeholder assets | `EasterEggConfig.luau` documents `rbxassetid://0` placeholders (out of this ticket’s listed files). | Called out below for art follow-up. |
| Emoji | Mixed use across modules (HUD vs feed vs microcopy). | Left celebration/social pools with emoji where they reinforce hype; removed trophy emoji from achievement toast variants for a cleaner HUD line. |

---

## Per-file notes

### MicrocopyConfig.luau

- **Tone:** Energetic, reward-forward, Roblox-appropriate. No changes required for policy.
- **Emoji:** `PlayStreak` uses 🔥; `EventBannerHeadlines` / `EventCountdown` use ⏳⚠️🚨 — intentional tiering (session vs event urgency). Acceptable variety.
- **VIP copy:** Aligns with VIP / premium value props elsewhere.

### LoadingTipsConfig.luau

- **Neon City:** `WorldConfig.neon.coinMultiplier = 10.0`, `unlockCurrency = crystals`, `unlockCost = 100_000` — tip about 10× and crystals is **accurate**.
- **Premium:** `PremiumService` welcome copy uses +50% coin earnings — **aligned**.
- **Fuse:** `PetService.fusePets` fuses 3 same-rarity pets into a **random** pet of the **next** rarity — tips now avoid implying a fixed mythic outcome or fake player-percent stats.
- **Headlines:** Fake “news” lines (e.g. hidden world at Rebirth 10) softened to avoid contradicting `WorldConfig` currency gates.

### AchievementPopupConfig.luau

- **POLA-230 snapshot (10 ids + no secret category) is superseded** by extended server-backed achievements — see **`docs/AchievementCopyMatrix.md`** for the current id list, thresholds, and rarity mapping.
- **Descriptions** must match `AchievementService` / `EggService` / `MilestoneCeremonyService` (e.g. `world_elite` = mastery for the final world, not merely unlocking it; `quest_veteran` = total quests completed, not “season-only”).
- **Category `secret`:** Wired for night owl, speed 500, basic-egg jackpot, laps, easter eggs, etc. — all have `tryUnlock` paths as documented in the matrix.

### NearMissCopyConfig.luau

- Copy is consistent with adrenaline / combo tone. No edits.

### SpeedTierCopyConfig.luau

- Tier thresholds align with `SpeedTierCopyConfig.TierThresholds` and speed milestone systems. No edits.

### ComboCelebrationConfig.luau

- Tier bands documented in header match `getTierKey`. No edits.

### FirstTimeConfig.luau

- Robux spending tiers are product/marketing copy; left unchanged (not validated against live monetization tables in this pass).

### MilestoneCeremonyCopyConfig.luau

- Ceremonial copy; thresholds in code should stay aligned with `MilestoneCeremonyService` (not re-audited line-by-line here).

### FomoBadgeLabelConfig.luau

- Badge keys are aspirational catalog copy. ⚠️ / ⏳ in urgency lines match `SocialFeedConfig` urgency style.

### LeaderboardTextConfig.luau

- Placeholder contract documented in header; strings are consistent.

### SocialFeedConfig.luau

- Drop lines use 🏆 / 🌟 / 🚨 in mythic/legendary pools — **kept** for feed hype; differs from achievement toast style **on purpose**.

### SpeedMilestoneConfig.luau

- Thresholds `{ 50 … 1000 }` match loading-tip references to 100 / 200 / 300 celebrations.
- `CelebrationColor` includes `[250]` but `Thresholds` has no 250 — pre-existing quirk; no player-facing inconsistency in tips.

### WorldUnlockConfig.luau

- **Desert fun_fact** still says “1.5× coins” — matches `WorldConfig.desert.coinMultiplier = 2.0`? **No — mismatch.** `WorldConfig` says **2.0×**. **Fixed** in config: fun_fact now says 2×.
- **RebirthThresholdsByWorldId:** Removed entries so client nudges use currency proximity (`WorldConfig` + `SocialFeedConfig.AlmostThereVFX.worldCurrency`) instead of incorrect rebirth gates.

### RebirthMilestoneConfig.luau

- Numeric thresholds `{ 5, 10, 25, 50, 100 }` — descriptive only; no copy changes.

---

## Placeholder / art debt

- **`DACReplicatedStorage/Config/EasterEggConfig.luau`:** Many `imageId = "rbxassetid://0"` entries and file comment note Bard/asset assignment — **not** in the POLA-230 file list but remains the main `rbxassetid://0` hotspot for player-visible images when wired to UI.

---

## Follow-ups (engineering / design, optional)

- New achievements: add config + `tryUnlock` + matrix row + `RARITY_BY_ID` + `TrophyCasePanel.rarityForId` if needed.
