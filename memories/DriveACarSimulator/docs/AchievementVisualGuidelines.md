# Achievement visual hierarchy & toast density (DAC)

**Purpose:** Keep achievement feedback rewarding without **spamming** the HUD as the achievement list grows (coordinates with **POLA-232** Trophy Case / unlock pipeline). Revise this doc after engineer changes to `AchievementController`, `TrophyCasePanel`, or server unlock batching.

**Canonical UI language:** `AGENTS.md` (Drive a Car Simulator) — pastel panel body, charcoal border, GothamBlack titles, chunky rounded shapes.

---

## 1. Rarity tiers vs pastel UI

Achievements use a **four-tier rarity** (bronze → silver → gold → diamond) for **accent and juice**, not for replacing the DAC panel look.

### 1.1 Token roles

| Token | Role | Rule |
|--------|------|------|
| **Panel gradient** | Pastel pink → lavender (`#FFD6EE` → `#E0D6FF`) | **Always** the toast/card body base. Do not swap the whole card to a “metal” gradient by tier. |
| **Outer stroke** | Charcoal `#2A2A40` | **Primary frame** for unlock toasts. Rarity may **slightly** thicken stroke on diamond only; never replace charcoal with raw gold RGB as the only border. |
| **Rarity accent bar** | Thin horizontal strip under the headline | **Primary tier signal** on unlock toasts — saturated but narrow so it reads as “highlight” on pastel. |
| **Trophy Case cell stroke** | Tier-colored `UIStroke` on unlocked cells | Grid uses **dark cell fill** (`~RGB 30,22,55`) with rarity stroke — different surface than HUD toasts; still **one** rarity color per cell, not rainbow outlines. |

### 1.2 Tier RGB (single source of truth in code)

Implementation maps achievement IDs → tier in client UI (`TrophyCasePanel` / `AchievementController`). Approximate values:

| Tier | Accent (toast bar & confetti bias) | Trophy Case stroke (reference) |
|------|--------------------------------------|----------------------------------|
| **Bronze** | `RGB(180, 120, 60)` | Warm brown-gold edge |
| **Silver** | `RGB(180, 195, 210)` | Cool silver edge |
| **Gold** | `RGB(255, 213, 79)` | Coin-gold edge |
| **Diamond** | `RGB(160, 220, 255)` | Ice / cyan edge |

**Contrast rule:** Body copy stays **dark on light** (`~#1E1E1E` on gradient). Tier color is **never** the main text color for paragraphs — only accents, strokes, or particles.

**Saturation rule:** If a future tier or “ultra” rarity is added, keep accents **readable on pink–lavender**; prefer shifting hue/lightness before adding full neon fills.

---

## 2. When to use which channel

The game uses **separate systems** for “moment” celebrations vs the **achievement track**. Do not route everything through one widget.

### 2.1 Compact achievement toast (default unlock)

**Use for:** Single achievement unlock, category-complete line, 100% completion line — as implemented in `AchievementController` (`AchievementToast`).

**Behavior:**

- **One card** at top center — **not** full-screen.
- **Pastel gradient card** + charcoal stroke + white headline + dark subline (see `ConceptArt/phase4-achievement-toast-polish.md`).
- **Escalation by kind / tier:** longer duration, stronger `VFXFacade` shake, flash, and confetti for **gold/diamond**, category complete, and **total completion** — still the **same shell**, more juice.

### 2.2 Progress nudge (non-blocking)

**Use for:** “Almost there” progress (`ProgressNudge` copy), with numeric progress — **separate** bottom-anchored card (`AchievementProgressToast`), not mixed into the unlock queue.

**Rule:** Progress toasts **replace** the previous progress card for that area (deduped); they do not stack three deep like unlocks.

### 2.3 Trophy Case (silent reference)

**Use for:** Browsing, reading descriptions, filters — **no toast** when opening the panel or tapping cells.

**Rules:**

- Unlock **already fired** the HUD toast (if not in a suppressed state).
- Opening Trophy Case **marks achievements seen** (badge/dot clears). The grid is **reference UI**, not a second celebration layer.
- Tooltip/detail is **in-panel** only — keep it calm so it doesn’t compete with HUD.

### 2.4 Full-screen / banner-style celebrations (non-achievement track)

**Use for:** Run distance streaks, world arrival, rebirth flashes, pet index milestones, streak milestones — these go through **`VFXController.milestonePopup`** (and related helpers), **not** the achievement toast queue.

**Rule of thumb:**

| If the moment is… | Channel |
|-------------------|---------|
| Persisted trophy with ID in `AchievementPopupConfig` | Achievement toast queue |
| One-off run / career / world / economy “moment” | Milestone / VFX popup styles |
| Player opens inventory of trophies | Trophy Case only |

When in doubt: **achievements = named trophies + toast**; **milestones = session/career beats + VFX popup**. Avoid duplicating the same headline in both channels on the same frame.

### 2.5 Suppression: driving run

While `DrivingController.isInRun()` is true, the unlock toast **pump** does not run — payloads **queue** (up to the max) and **drain after `EndRun`** (`AchievementController` defers `pump()` on run end). This keeps the lane readable during driving.

**Progress nudges** (`AchievementProgress`) use a **separate layer** and are **not** gated by `isInRun()` in current code. If burst progress spam becomes a problem, consider gating or throttling in engineering — document any change here.

---

## 3. Density, queueing, and burst unlocks

### 3.1 Current limits (reference for POLA-232)

| Mechanism | Limit | Notes |
|-----------|--------|--------|
| **Unlock queue** | Max **3** pending payloads | Additional unlocks while queue is full are **dropped** at enqueue — **avoid** designing server burst unlocks that exceed this without code changes. |
| **Visible unlock** | **1** toast at a time | Serial `pump`; next starts when the previous finishes. |
| **Progress toast** | Effectively **1** active | New progress card clears prior progress card. |

### 3.2 Guidelines if burst unlocks are added (engineer)

1. **Prefer batching:** one combined toast (“**3 achievements unlocked!**”) + Trophy Case refresh, instead of three separate full cards.
2. **If keeping per-unlock toasts:** raise `MAX_QUEUE` and add **merge rules** (e.g. coalesce same-session duplicates) — document new numbers here.
3. **Never** exceed **one** heavy full-screen effect at a time; stagger flashes/shakes if multiple systems fire.

### 3.3 Category and 100% completion

These use the **same toast shell** with **stronger** duration and VFX (see controller). Treat them as **rare** — they should feel epic **because** they are infrequent, not because they block gameplay for long. Cap subjective “noise” by keeping copy short (already constrained in config).

---

## 4. Copy and length

- **Titles:** Short, ALL CAPS, punchy — matches `AchievementPopupConfig` limits culture.
- **Unlock lines:** Rotating variants with `{TITLE}` — avoid adding long sentences that force multi-line layout on small screens.
- **Total completion:** Reserve **diamond-tier** length and sound for true 100% only.

---

## 5. Optional QA artifacts

- **Screenshots:** For worst-case UX, capture: (1) three queued unlocks resolving one-by-one, (2) Trophy Case with many unlocked diamond-tier borders, (3) total-completion toast. Store under `docs/VisualQA_screenshots/` and list in `docs/VisualQA_screenshots/manifest.json` if present.
- **After POLA-232 engineer PR:** Re-verify Section 3 limits and Trophy Case “seen” behavior; update **§3.1** if queue constants change.

---

## 6. Related files

| Area | Path |
|------|------|
| Unlock / queue / progress UI | `DACStarterPlayerScripts/Controllers/AchievementController.luau` |
| Copy & categories | `DACReplicatedStorage/Config/AchievementPopupConfig.luau` |
| Trophy grid & rarity map | `DACStarterGui/TrophyCasePanel.luau` |
| Phase 4 toast polish notes | `ConceptArt/phase4-achievement-toast-polish.md` |
| Milestone popups (non-achievement) | `DACStarterPlayerScripts/Controllers/VFXController.luau` (`milestonePopup`) |
