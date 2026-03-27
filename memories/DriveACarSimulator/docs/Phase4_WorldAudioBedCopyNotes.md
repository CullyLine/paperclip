# Phase 4 — World audio bed vs copy / hype layering

**Purpose:** Avoid **double-hype** when the world **music + ambient bed** (and engine loops) still read as “full energy” while the UI is shouting celebration or retention copy.

**Engineering anchor:** `DACStarterPlayerScripts/Controllers/SoundController.luau`

- **Modal duck:** `MODAL_DUCK_MUL` / `MODAL_DUCK_TWEEN_SEC` dip the **duckBus** (music, ambient, engine SFX) while payout, menus, and other modals are open so panel copy and one-shots stay legible.
- **Achievement / notification lane:** Trophy stingers and related SFX ride the same bus policy as gameplay; achievement entrances can be **deferred** while heavy UI is up (see comments in `AchievementController` + `Phase4NotificationLaneJuiceSpec.md`).

**Copy anchors**

- **First-session hook:** `MicrocopyConfig.FirstSessionTagline` = `"Every run pays off."` — intentionally **not** duplicated in `LoadingTipsConfig` (see `Phase4_CopyGrepReport.md` / `Phase4_LoadingAndQueueTips.md`).
- **Loading carousel:** `LoadingTipsConfig` tips + headlines rotate; tone is tutorial + feature discovery, not the same CTA as the first-session tagline.

**Quick “no double-hype” check (manual)**

1. Open **payout** after a run — bed should duck; read headline + currency lines without fighting a second “hype” VO line at full volume.
2. Trigger an **achievement toast** with a menu open — stinger should not stack uncomfortably over an unducked bed (bed should already be dipped if modal duck is active).
3. **Loading screen** — confirm no tip repeats the exact `FirstSessionTagline` sentence (grep is the automated guard; human pass confirms feel).

**Sign-off:** Content Strategist — POLA-490 (2026-03-22): preconditions (manifest + `SoundController` runtime) met; separation of loading vs first-session tagline verified by grep + code review; full **in-Studio mix** pass still recommended before store milestone.
