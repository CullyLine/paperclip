# Phase 4 — Launch Copy QA checklist §2 smoke session log

**Checklist source:** `docs/Phase4_LaunchCopyQAChecklist.md` §2 (and §3.1 cross-check).  
**Companion evidence:** `docs/Phase4_CopyGrepReport.md` (POLA-490, POLA-495).  
**Issue:** POLA-500 — desk smoke + session record (merge overlaps with POLA-495). **POLA-613** — post-engineer-sweeps RC re-pass (same §2 matrix + tone index). **POLA-650** — LaunchCopyQAChecklist §3.1 **RC** (world audio bed: crossfade, duck, double-hype, settings labels).

---

## Session metadata

| Field | Value |
|--------|--------|
| **Date** | 2026-03-22 |
| **Agent / role** | Content Strategist (POLA-500 baseline; **POLA-613** RC sweep); **Engineer** (POLA-650 §3.1 RC) |
| **Method** | Code + config desk review (no live Roblox client this pass); **POLA-650** adds engineer verification of `SoundController` + settings wiring (subjective loudness still optional; see FOLLOW-UP-2). |
| **Build / tree** | `memories/DriveACarSimulator` current workspace — **after engineer sweeps** (POLA-613) |

---

## §2 — Surface matrix (full table)

Rows that duplicate **POLA-495** are merged here with **same verdict**; see `Phase4_CopyGrepReport.md` § POLA-495 for detailed evidence. **POLA-613** re-verified the same wiring after broad config/script churn; no new contradictions found.

| Surface | Result | Notes / evidence (this pass) |
|---------|--------|------------------------------|
| **Loading** | **PASS** | `LoadingScreen.local.luau` uses `LoadingTipsConfig.Tips` with fallback `{ "Loading..." }`; `baseTips` when config empty. `MicrocopyConfig.FirstSessionTagline` (“Every run pays off.”) is separate from loading carousel — aligns with `Phase4_CopyGrepReport.md` / POLA-404 pattern. **POLA-613:** tip/fallback structure unchanged. |
| **Microcopy / HUD** | **PASS** | Spot-check: run-end and currency flows remain config-driven; no conflicting duplicate-number templates found in quick read of `HUD.luau` / payout paths (POLA-495 deep pass). |
| **Social feed & banners** | **PASS** | `SocialFeedConfig` pools are short, placeholder-tagged; `EventBanner.luau` pulls countdown + copy from config/Microcopy patterns — no raw `§` in visible string sources reviewed. |
| **Achievements** | **PASS** | *Merged with POLA-495* — `AchievementPopupConfig` + trophy case wiring. |
| **Leaderboard panel** | **PASS** | `LeaderboardPanel.luau`: tabs **Distance** / **Rebirths** (`STAT_DISTANCE` / `STAT_REBIRTHS`); motivation lines from `LeaderboardTextConfig` pools (`Number1Flex`, `RankUpMessages`, etc.). |
| **Friend bonus** | **PASS** | `FriendBonusHUD.luau`: `MicrocopyConfig.FriendBonusHudLabelFormat` with `{PCT}` substitution; layout uses `HudLayoutConfig`. |
| **Daily reward & codes** | **PASS** | *Daily merged with POLA-495.* **Codes:** `CodesPanel.luau` uses `MicrocopyConfig` pools for success/error/expired; busy line `Redeeming…` matches `CTAVerbConsistency.md` progressive pattern. |
| **Store** | **PASS** | `StorePanel` / `GamePassConfig` + `DevProductConfig` — rows remain key-driven; product IDs may be `0` until POLA-95 (known). |
| **Retention / Battle Pass** | **PASS** | `BattlePassPanel.luau` uses `BattlePassConfig.Season.name` and dynamic reward descriptions; no new whale-term grep issues per baseline. AFK / retention pools: wiring gaps remain per `Phase4_SessionBoundaryReengagementCopy.md` (engineering follow-up, not a §2 copy regression). |
| **World unlock** | **PASS** | `WorldUnlockConfig`: `RebirthThresholdsByWorldId = {}` (currency framing); `TravelTeaser` uses coin/gem/crystal costs in lines — consistent with checklist currency-not-rebirth note. |

---

## §3.1 — World audio bed + modal copy (RC matrix)

**Checklist:** `Phase4_LaunchCopyQAChecklist.md` §3.1. **POLA-650** fills the **Pass** column from an **engineer RC** (code + config + grep). Subjective **loudness / mix in a live client** remains an optional human pass — tracked as FOLLOW-UP-2.

| Check | Pass | Notes / evidence (POLA-650) |
|-------|------|-----------------------------|
| Preconditions — `Audio/MANIFEST.md` ↔ registry | **PASS** | `SoundController.registerDefaults` + `hydrateFromReplicatedStorageAudio` align with MANIFEST keys; placeholders `rbxassetid://0` warn in Studio per header. |
| Preconditions — modal duck path | **PASS** | `MODAL_DUCK_MUL` (0.35) / `MODAL_DUCK_TWEEN_SEC` (0.2) on `DACDuckBus`; `shouldDuckGameplay()` = menu, payout, or overlay ref-count (`setMenuModalOpen`, `setPayoutModalOpen`, `setModalOverlayOpen`). |
| Crossfade — world music / ambient beds | **PASS** | A/B buffers: `CROSSFADE_TIME` 0.85s music, `AMBIENT_CROSSFADE_TIME` 0.62s ambient; `MUSIC_STAGGER_AFTER_AMBIENT_SEC` 0.12s when both layers change — ambient leads, music follows (`setWorld`). |
| Double-hype — loading vs first-session tagline | **PASS** | `MicrocopyConfig.FirstSessionTagline` = `"Every run pays off."` not duplicated in `LoadingTipsConfig.Tips` / `Headlines` (grep + `MicrocopyConfig` cross-ref comment). |
| Payout / menus — bed readable under UI | **PASS** | Gameplay bed (music, ambient, engine loops) on `duckBus`; UI one-shots on `uiBus` / `UI_ONE_SHOT_IDS`; payout closes resume `NotificationLaneBridge` — matches `Phase4_WorldAudioBedCopyNotes.md`. |
| Settings — audio labels + master toggle | **PASS** | `SettingsPanel.luau`: **Game sound**, **Music volume**, **SFX volume**; `SoundFacade.applyGameSoundMasterToggle` → `SoundController.applyGameSoundMasterToggle` (mute blip + brief `uiBus` duck on unmute, POLA-429). |

---

## Tone matrix (POLA-613)

No separate spreadsheet in-repo — **canonical index:** `docs/Phase4_JuiceToneMatrix.md` (voice glossary, retention/social/store lanes, notification + run-end specs). Cross-checked: doc index still matches active spec paths; no drift vs. POLA-500.

---

## Sign-off

**Content Strategist:** 2026-03-22 — POLA-500 §2 desk smoke complete; overlaps merged with POLA-495 per CEO instruction.

**Content Strategist:** 2026-03-22 — **POLA-613** post-engineer-sweeps RC pass: §2 matrix **PASS** (desk); §1 grep refresh in `Phase4_CopyGrepReport.md` § POLA-613; tone matrix via `Phase4_JuiceToneMatrix.md`.

**Follow-up:** In-game 1080p readability pass on social/banners and store rows when convenient; optional **ears-in-Studio** loudness pass remains FOLLOW-UP-2 (POLA-650 RC covers wiring + policy).

**Engineer:** 2026-03-22 — **POLA-650** §3.1 RC complete — matrix above; files: `docs/Phase4_ChecklistSection2_SmokeNotes.md` (this section), `DACStarterPlayerScripts/Controllers/SoundController.luau`, `DACStarterGui/SettingsPanel.luau`, `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `DACReplicatedStorage/Config/LoadingTipsConfig.luau`.

---

## §4 — Discovery, thumbnails & short hooks (POLA-661)

**Checklist:** `docs/Phase4_LaunchCopyQAChecklist.md` §4. **Bank index:** `docs/Phase4_ThumbnailAndShortHookBank.md`.

**Precondition:** **POLA-95 not closed** — all `gamePassId` / `productId` values in `GamePassConfig.luau` / `DevProductConfig.luau` are **`0`** (desk check 2026-03-22). Live Creator Dashboard verification of store rows and purchase prompts remains **blocked**; this pass is **repo + doc alignment** only.

| Surface | Result | Notes / evidence |
|---------|--------|-------------------|
| **Game page body** | **PASS (desk)** | `GamePageContent.md` title **Drive a Car Simulator**; §2 primary description and tag table align with `docs/GamePageAndDiscoveryCopy.md` Phase 4 achievement insert and keyword additions; no new contradiction vs POLA-626 public-copy audit. |
| **Discovery / weekly updates** | **PASS (desk)** | `docs/Phase4_DiscoveryAndGamePageCopy.md` §5–§8 patterns and paste checklist present; §6 discovery keywords consistent with `GamePageAndDiscoveryCopy.md` §3. |
| **Thumbnails & icon** | **PASS (desk)** | `GamePageContent.md` §4 concepts ↔ `docs/marketing/IconThumbnailLayoutBrief.md` safe zones and variant A/B; both emphasize car-first read + economy/collection secondary. **Live asset uploads** still external (see `LaunchAssets/AssetIdChecklist.md`). |
| **Short hooks** | **PASS (desk)** | `docs/ShortFormHooks_Phase4.md` (5 vertical hooks + shot ideas) and `docs/GamePageAndDiscoveryCopy.md` §4 (5 one-liners) include POLA-95 monetization guardrails; hook sets are complementary, not duplicate. |
| **Store / SKU visibility on game page** | **BLOCKED (live)** | Requires POLA-95 — cannot confirm Dashboard listings or end-to-end purchase display until IDs are wired. |

**Content Strategist:** 2026-03-22 — **POLA-661** §4 desk QA complete; added `docs/Phase4_ThumbnailAndShortHookBank.md` + §4 checklist block. Re-run live row when POLA-95 lands.

---

## Promo codes — `PreLaunchChecklist.md` §1 vs `CodeService` (POLA-664)

**Checklist:** `PreLaunchChecklist.md` Part 1 §1 promo table (codes **DRIVEFAST** through **UPDATE1**). **Source of truth:** `DACServerScriptService/Services/CodeService.luau` `CODES`.

**Method:** Desk cross-check of reward tuples (currency key + amount) per code; no live Roblox client.

| Code | §1 rewards (doc) | `CodeService.rewards` | Match |
|------|------------------|-------------------------|--------|
| DRIVEFAST | 3,000 coins + 50 gems | `coins` 3000, `gems` 50 | **PASS** |
| PETPOWER | 5,000 coins | `coins` 5000 | **PASS** |
| REBIRTH1 | 10,000 coins | `coins` 10000 | **PASS** |
| NEONHYPE | 200 crystals | `crystals` 200 | **PASS** |
| DESERT2X | 5,000 coins + 100 gems | `coins` 5000, `gems` 100 | **PASS** |
| THANKYOU | 7,500 coins + 75 gems + 25 crystals | `coins` 7500, `gems` 75, `crystals` 25 | **PASS** |
| UPDATE1 | 8,000 coins + 150 gems | `coins` 8000, `gems` 150 | **PASS** |

**Drift fixed (same sweep):** `GameCopy.md` §9 listed PETPOWER with a Meadow Egg; implementation is coins-only — row corrected to match `CodeService` and §1.

**Engineer:** 2026-03-22 — **POLA-664** complete; files: `docs/Phase4_ChecklistSection2_SmokeNotes.md` (this section), `PreLaunchChecklist.md` (doc vs repo row), `GameCopy.md` (PETPOWER rewards).
