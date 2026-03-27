# Phase 4 — Launch copy QA checklist

**Purpose:** Fast manual checks before treating a build as “copy-ready” for a milestone or store update.  
**Companion:** `PreLaunchChecklist.md` (full launch), `docs/Phase4_CopyGrepReport.md` (automated grep).

---

## 1. Preconditions

- [x] `docs/Phase4_CopyGrepReport.md` updated for the current build (same day or same PR). — **2026-03-22 POLA-613** grep refresh + § POLA-613 block.  
- [x] No open Content tickets blocking copy (or exceptions listed in report). — none for this RC.  
- [x] `docs/CTAVerbConsistency.md` — primary CTAs still match **Claim / Buy / Redeem / Hatch / Equip** rules for touched surfaces. — desk-checked POLA-613.
- [x] `docs/Phase4_PublicCopyCompliance_POLA626.md` — Community Standards / honest-claims pass (POLA-626); must-fix strings landed in `MicrocopyConfig` + `AchievementPopupConfig`.

---

## 2. Spot-check after a major string drop (touched surfaces)

Use this section when many configs or panels change in one pass. **Skim in-game or in Studio**; do not block on perfect pixel QA here.

| Surface | Check |
|---------|--------|
| **Loading** | Tips rotate; no stale world multipliers vs `WorldConfig`; fallback tip in `LoadingScreen.local.luau` acceptable if config empty. |
| **Microcopy / HUD** | Coin/gem/crystal pick-ups, run-end payout, streak lines — no duplicate contradictory numbers. |
| **Social feed & banners** | `SocialFeedConfig` + `EventBanner` / group banner — headlines readable at 1080p; no raw `§` in visible text. |
| **Achievements** | Toast titles match `AchievementPopupConfig`; trophy case progress string sane; no `ACHIEVEMENT` fallback unless testing missing id. |
| **Leaderboard panel** | Loading/error/empty states; `Distance` / `Rebirths` tabs; motivation lines from `LeaderboardTextConfig` feel varied. |
| **Friend bonus** | Chip label + percent formatting; `%` consistent with `FriendBonusConfig`. |
| **Daily reward & codes** | `Claim` / `Redeem` progressive states (`Claiming...`, `Redeeming…`) match `MicrocopyConfig` / panel wiring. |
| **Store** | Game pass + dev product rows: prices and descriptions match `GamePassConfig` / `DevProductConfig` keys (IDs may still be 0 until POLA-95). |
| **Retention / Battle Pass** | AFK pop-up lines and BP tier strings — no insulting tone; whale-term policy respected. |
| **World unlock** | Travel teaser / nudges use **currency** framing (not rebirth gates) per `WorldUnlockConfig` + `CopyPolishAudit`. |

**Quick pass:** also run `docs/FirstSessionOnboardingCopyQA.md` whale grep if celebration or flex pools were edited.

---

## 3. Sign-off

- **Content Strategist:** date + initials in `Phase4_CopyGrepReport.md` or here when §2 is satisfied for a named build.  
- **2026-03-22 — POLA-495:** Focused §2 pass (payout, daily, egg shop/hatch, trophy) recorded in `Phase4_CopyGrepReport.md` (POLA-495 section).
- **2026-03-22 — POLA-500:** Full §2 matrix + §3.1 desk cross-check recorded in `docs/Phase4_ChecklistSection2_SmokeNotes.md` (merged with POLA-495 where surfaces overlap).
- **2026-03-22 — POLA-613:** Post-engineer-sweeps RC — §1 + §2 + tone matrix desk pass; grep refresh **POLA-613** in `Phase4_CopyGrepReport.md`; session log + tone index pointer in `Phase4_ChecklistSection2_SmokeNotes.md`.
- **2026-03-22 — POLA-650:** §3.1 engineer RC — Pass matrix + evidence in `Phase4_ChecklistSection2_SmokeNotes.md` §3.1; FOLLOW-UP-2 updated (optional ears-in-Studio loudness still open).
- **Engineering:** Studio-only label text still requires Roblox visual pass (`AGENTS.md` pre-built UI rule).

### 3.1 World audio bed + modal copy (after POLA-298 / POLA-471)

**Preconditions**

- [x] `Audio/MANIFEST.md` keys align with `SoundController` registry (uploads may still use `rbxassetid://0` placeholders — tracked separately). — **Desk 2026-03-22 (POLA-500 / POLA-613):** MANIFEST documents registry keys; `SoundController` header + `hydrateFromReplicatedStorageAudio` / `registerDefaults` are the source of truth; live Roblox IDs depend on Studio `ReplicatedStorage.Audio` uploads (see backlog FOLLOW-UP-2 for human mix).
- [x] `SoundController` modal duck path active (`MODAL_DUCK_*` on gameplay bed when payout/menus open). — **Desk 2026-03-22:** `MODAL_DUCK_MUL` / `MODAL_DUCK_TWEEN_SEC` + `shouldDuckGameplay()` in `DACStarterPlayerScripts/Controllers/SoundController.luau`.

**Checks**

- [x] No **double-hype** layering: loading / first-session tagline separation per `docs/Phase4_WorldAudioBedCopyNotes.md` (grep + human pass). — **Desk:** cross-check recorded in `docs/Phase4_ChecklistSection2_SmokeNotes.md` §3.1; full client pass still optional for pixel-perfect audio layering.
- [x] Payout + achievement moments: bed ducked enough to read panel copy; trophy stingers not fighting an unducked bed (see `Phase4NotificationLaneJuiceSpec.md`). — **Desk:** policy + `SoundController` routing; **in-Studio loudness/mix** remains human (`Phase4_ContentPolishBacklog.md` FOLLOW-UP-2).

---

## 4. Discovery, game page, thumbnails & short hooks

Run when refreshing **Creator Dashboard** copy, **thumbnails**, or **short-form** assets — or after a major edit to `GamePageContent.md` / discovery docs.

**Canonical bank:** `docs/Phase4_ThumbnailAndShortHookBank.md` (index into `GamePageContent.md` §4, `docs/marketing/IconThumbnailLayoutBrief.md`, `docs/ShortFormHooks_Phase4.md`, `docs/GamePageAndDiscoveryCopy.md`).

| Surface | Check |
|---------|--------|
| **Game page body** | Title + primary description + tags in `GamePageContent.md` match Phase 4 deltas in `docs/GamePageAndDiscoveryCopy.md`; numeric feature claims stay honest vs configs (POLA-626). |
| **Discovery / weekly updates** | `docs/Phase4_DiscoveryAndGamePageCopy.md` §5–§8 — title pattern, first bullet = player benefit, ≥1 discovery keyword in first two lines, no competitor names / false urgency. |
| **Thumbnails & icon** | Creative specs `GamePageContent.md` §4; layout/safe zones `docs/marketing/IconThumbnailLayoutBrief.md`; uploaded image IDs tracked separately (`LaunchAssets/AssetIdChecklist.md`). |
| **Short hooks** | `docs/ShortFormHooks_Phase4.md` + `docs/GamePageAndDiscoveryCopy.md` §4 — POLA-95 guardrails (no “live” monetization claims; no unverified numbers). |

**POLA-95 note:** Live verification of **game-page Game Pass / dev product rows** (icons, prices on Roblox) requires non-zero `gamePassId` / `productId` in `GamePassConfig` / `DevProductConfig`. Until then, desk-check **intended** copy in-repo only; log gap in `Phase4_ContentPolishBacklog.md`.

**Sign-off:** session log + matrix verdicts in `docs/Phase4_ChecklistSection2_SmokeNotes.md` §4.
