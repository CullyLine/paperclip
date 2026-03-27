# Phase 4 copy grep report

**Issue:** POLA-490 (post-audio launch copy QA + session-boundary audit; grep refresh)  
**Prior snapshots:** POLA-472, POLA-423, POLA-394  
**Run date:** 2026-03-22 (**POLA-657** §4 rescan post POLA-643 / stabilization; prior same-day baselines POLA-490 / POLA-613)  
**Trigger:** Post-merge content pass — same patterns as `Phase4_EngineerCopyIntegration_Index.md` §4.  
**Method:** Python scan over all `*.luau` under `memories/DriveACarSimulator` (**158** files as of POLA-657). Equivalent CLI when `rg` is on PATH:

`rg -n "<pattern>" --glob "*.luau" memories/DriveACarSimulator`

---

## Summary

| Pattern | Line hits | Result |
|---------|-----------|--------|
| `whale\|Whale` | 9 | **OK** — comments + species/product (`Cosmic Whale`, `cosmic_whale`, “whale-forward” tier note in `AchievementPopupConfig`); still no player-directed whale *slang* in celebration/UI strings. |
| `lorem\|Lorem\|\bTBD\b\|\bFIXME\b` (case-insensitive) | 3 (`TBD` only) | **OK for ship** — `SoundController` sound-key notes (`combo_ding`, `lap_pb_chime`); `LeaderboardPanelDesignSpec` product note. No `lorem` / `FIXME` hits. |
| `Click here\|click here` | 0 | **Clean** |
| `§` | 14 | **OK** — comments / spec cross-refs only (adds `BattlePassConfig` → `Season1_ContentPlan.md` §2); **no** `Text = "…§…"` hits in `*.luau`. |
| `rbxassetid://0` | 74 lines, **9 files** | **Known debt** — placeholders documented in manifests / Easter eggs / services; not a regression from this pass. |
| `Every run pays off` | 0 in `LoadingTipsConfig.luau` | **OK (POLA-404)** — Phase 4 store hook lives only in `MicrocopyConfig.FirstSessionTagline`; loading carousel does not repeat it. See `docs/Phase4_LoadingAndQueueTips.md`. |

---

## POLA-657 — Phase 4 §4 grep refresh (POLA-104 / POLA-373 lineage)

**Issue:** POLA-657 — Re-run §4 greps on the primary DAC Luau tree after POLA-643 stabilization.  
**Parent:** POLA-104 epic; tracks POLA-373-style engineer ↔ content copy integration (must-fix rows for Content only on **player-visible** regressions).  
**Run date:** 2026-03-22  

- **Files scanned:** 158 `*.luau` (Python walk; patterns match `Phase4_EngineerCopyIntegration_Index.md` §4).  
- **Delta vs POLA-613:** +3 Luau files; `whale` **9** line hits (policy/spec + species); `§` **14** (comments only — adds `BattlePassConfig.luau` cross-ref to `Season1_ContentPlan.md` §2); `rbxassetid://0` **74** lines across **9** files.  
- **Content must-fix:** **none** this run — no new player-visible `TBD` / `lorem` / “click here” / `§` in HUD strings; `grep` spot-check: no `Text = …§…` in `*.luau`.

**Sign-off (Engineer):** 2026-03-22 — POLA-657 report stamp + Summary table updated.

---

## Whale / Whale (detail)

- `MicrocopyConfig.luau` — policy comments (Phase 4 whale-term cleanup).  
- `AchievementPopupConfig.luau` — header comment on metallic trophy tier (“whale-forward”); not player-facing toast text.  
- `EggConfig.luau` — `petId = "cosmic_whale"`.  
- `LoadingTipsConfig.luau` — “Cosmic Whale” as mythic species.  
- `PetConfig.luau` — species definition `Cosmic Whale`.

---

## Placeholder / TBD (detail)

- `SoundController.luau` — `TBD` in comments for future sound swaps (`combo_ding`, `lap_pb_chime`).  
- `LeaderboardPanelDesignSpec.luau` — design/spec line “TBD by product” (not HUD copy).

---

## POLA-613 — Post-engineer-sweeps RC grep + `Phase4_LaunchCopyQAChecklist.md` §1 refresh

**Issue:** POLA-613 — Content Strategist RC pass after engineer sweeps (copy + tone matrix desk check).  
**Run date:** 2026-03-22  

**§1 preconditions**

- **Grep:** Python rescan of **155** `*.luau` files — patterns per Summary table (updated counts: `whale` 10, `§` 13 comment-only, `lorem/TBD/FIXME` 0, `click here` 0).  
- **CTA doc:** `docs/CTAVerbConsistency.md` unchanged since POLA-307 pass; primary surfaces still align **Claim / Buy / Redeem / Hatch / Equip** for config-driven copy.  
- **Open Content blockers:** none identified for copy ship; retention microcopy consumer gaps remain engineering-owned per `Phase4_SessionBoundaryReengagementCopy.md`.

**Tone matrix (desk):** Canonical index unchanged — `docs/Phase4_JuiceToneMatrix.md` (voice glossary, retention lanes, notification specs, store matrix).

**Sign-off (Content Strategist):** 2026-03-22 — POLA-613 §1 satisfied for current tree; §2 matrix recorded in `docs/Phase4_ChecklistSection2_SmokeNotes.md`.

---

## POLA-490 — Launch copy QA (`Phase4_LaunchCopyQAChecklist.md` §2, §3.1) + session audit

**Grep refresh:** Counts match **POLA-472** snapshot — no new `*_Config.luau` string landings this cycle beyond already-tracked patterns.

**§2 — Surface smoke (code + config review; full in-Studio mix still recommended)**

| Surface | Result | Notes |
|---------|--------|--------|
| **Payout (run-end)** | **PASS** | `PayoutPanel.luau` binds live run stats; `SoundController` modal duck applies to gameplay bed when payout UI is open (`docs/Phase4_WorldAudioBedCopyNotes.md`). |
| **Daily reward** | **PASS** | `DailyRewardPanel.luau` uses `MicrocopyConfig` claim button states + streak FOMO pools consistently. |
| **Egg shop** | **PASS** | No new grep regressions; egg/rarity copy remains config-driven (`EggConfig` + shop panel patterns). |
| **Trophy / achievement toast** | **PASS** | `AchievementPopupConfig` + `AchievementController` align with notification-lane / duck policy in `SoundController` header comments. |

**§3.1 — World audio bed + modal copy**

- **Preconditions:** `SoundController` exposes `MODAL_DUCK_*`; `Audio/MANIFEST.md` present in tree; registry/placeholder policy unchanged.  
- **Double-hype:** **PASS** — `LoadingTipsConfig` does not duplicate `FirstSessionTagline`; modal duck documented for payout/menus. See `docs/Phase4_WorldAudioBedCopyNotes.md` (added this run).

**Session boundary**

- Cross-check doc: `docs/Phase4_SessionBoundaryReengagementCopy.md` — maps Bootstrap welcome + AFK modal + soft-retention pools; **gaps:** `RetentionSoftSessionWrap`, `RetentionReturnTomorrow`, `RetentionStreakSoftReminder` have **no consumer** yet (engineering follow-up in `docs/Phase4_ContentPolishBacklog.md`).

**Sign-off (Content Strategist):** 2026-03-22 — POLA-490 complete.

---

## POLA-495 — Launch copy QA (`Phase4_LaunchCopyQAChecklist.md` §2 focused surface smoke)

**Issue:** POLA-495 — payout, daily reward, egg shop/hatch, trophy case (RC areas not fully covered in a single prior pass).  
**Run date:** 2026-03-22  
**Method:** Code + config cross-check against `Phase4_EngineerCopyIntegration_Index.md`, `CTAVerbConsistency.md`, and existing grep baseline (no new automated grep run this cycle).

| Surface | Result | Evidence |
|---------|--------|----------|
| **Payout (run-end)** | **PASS** | `PayoutPanel.luau` binds titles, badges, flex lines, and season/BP lines from `MicrocopyConfig` (`PayoutTitle*`, `PayoutFlex*`, `PayoutBadge*`, `PayoutSeasonXpFormat`, `PayoutBattlePassTierFormat`). No contradictory duplicate-number patterns in templates vs. `pickPayoutFlexLine` / `pickPayoutSecondaryLine`. |
| **Daily reward & claim states** | **PASS** | `DailyRewardPanel.luau` uses `MicrocopyConfig.DailyRewardClaimButtonDefault` (`Claim reward`) and `DailyRewardClaimButtonProgress` (`Claiming...`) per `CTAVerbConsistency.md`. Streak FOMO pools from `MicrocopyConfig`; meter chrome from `DailyRewardConfig`. |
| **Egg shop / hatch wiring** | **PASS (config + scripts)** | `UIController.luau` drives `EggConfig` slots, buy popup, and `HatchEgg` remotes; `MicrocopyConfig.UiEggStoreSpotlightBadge` for spotlight. **Player-visible hatch CTA text** on pre-built `EggOpenPrompt` remains a **Studio** item per `CTAVerbConsistency.md` deferred list (not represented in `.luau` shells). |
| **Trophy case** | **PASS** | `TrophyCasePanel.luau` pulls achievement titles/descriptions from `AchievementPopupConfig.Achievements`; progress header `{n}/{total} Achievements Unlocked` + `%` is consistent and sane. |

**Sign-off (Content Strategist):** 2026-03-22 — POLA-495 complete.

---

## POLA-472 — Launch copy QA (historical)

**§2 (surfaces after audio / string integration)**  
- **Loading:** `LoadingTipsConfig` tips + headlines rotate; no `Every run pays off` duplicate vs `MicrocopyConfig.FirstSessionTagline`; species mention “Cosmic Whale” is consistent with pet copy.  
- **Achievements / trophy lane:** Toast copy sourced from `AchievementPopupConfig`; unlock lines avoid raw `§` in visible strings.  
- **Social / banners:** No extra pass required this cycle beyond grep — `SocialFeedConfig` / `EventBanner` unchanged in hit patterns.

**§3 — Juice / matrix alignment**  
- `SoundController` implements modal ducking (`duckBus` / `MODAL_DUCK_*`) per `Phase4NotificationLaneJuiceSpec` (achievement stingers on gameplay bus; menus duck bed).  
- **Achievement popup body length:** Four secret-category descriptions exceeded the file header limit (≤60 chars). **Tightened** in `AchievementPopupConfig.luau` (and `docs/AchievementCopyMatrix.md`) so all achievement bodies are ≤60.  
- World-audio / copy layering notes now live in `docs/Phase4_WorldAudioBedCopyNotes.md` (POLA-490).

**Sign-off (Content Strategist):** 2026-03-22 — POLA-472 grep + §2–3 pass complete.

---

## Follow-up

- Re-run after the **next** large string merge or at least weekly during active Phase 4 polish.  
- RC comms stubs: `docs/PatchNotesTemplate_Phase4.md`, `docs/Phase4_LaunchCommsOnePager.md`.
