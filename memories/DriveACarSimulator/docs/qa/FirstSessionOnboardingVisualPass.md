# First-session onboarding — visual pass (Phase 4 QA)

**Issue:** POLA-294 · **Parent:** POLA-104 · **Pairs with:** POLA-291 (onboarding wiring). If first-session flows are not wired or panels fail to open, **stop and unblock POLA-291** before signing off visuals.

**Goal:** Capture a consistent **screenshot checklist** for the first minutes of a new player experience, plus **spacing / contrast** notes testers can fill in during Studio or device playtests.

**Related docs:**

| Document | Use |
|----------|-----|
| `docs/qa/TutorialOverlayReadability.md` | Deep checklist for `DACTutorialOverlay` (fonts, motion, layering). |
| `DACStarterGui/TutorialOverlayDesignSpec.luau` | Target colors, dimmer range, typography bands. |
| `DACReplicatedStorage/Config/UILayerStack.luau` | DisplayOrder / ZIndex expectations (payout vs HUD vs tutorial). |

---

## Test setup

- [ ] **Account:** Fresh session (new alt or data reset) so tutorial, first payout, and first hatch fire naturally.
- [ ] **Viewport:** Capture at least once on **phone** and **tablet** aspect ratios (Device Emulator or hardware). First-session players are mostly mobile.
- [ ] **Safe area:** Enable notch / home-indicator overlay in emulator; note any clipped text or buttons.
- [ ] **Capture:** PNG or Studio screenshot; name files using the **Shot ID** column below.

---

## Screenshot checklist

Fill **Pass/Fail** and **Notes** during the run. For spacing/contrast, refer to the criteria column — log specific elements (e.g. “title vs panel edge”, “coin text on flash”).

| Shot ID | Moment (when to capture) | What must be visible | Spacing & contrast criteria |
|---------|--------------------------|----------------------|-----------------------------|
| **FSO-01 Welcome** | First onboarding beat after playable load — **either** (a) initial `DACTutorialOverlay` step with dimmer + bubble, **or** (b) first “welcome” style panel your build uses if tutorial is deferred. | Full frame: dimmer level, bubble/card, **Skip** (if shown), any highlighted HUD target + gold stroke/arrow. | Dimmer ~0.35–0.45 transparency; lanes still readable. Title **#1E1E1E** (or equivalent) on light bubble; body not gray-on-pastel. Skip readable on its background. Highlight gold `#FFD54F`-family visible on both light and dark HUD. No critical tap target fully covered by bubble. |
| **FSO-02 First payout** | First **end-of-run** results after at least one completed run (`StarterGui.DACPayout` — `DACStarterGui/PayoutPanel.luau`). | Payout card, coin/currency line, multiplier breakdown if shown, flex line, any PB / tier flash. | Card not cramped against screen edges; text not clipped on small width. Flash / tier elements readable against background (see `UILayerStack` payout Z bands). Numbers and labels distinguishable at a glance. |
| **FSO-03 First hatch** | Immediately when the **first egg hatches** (server hatch result → client preview / shop feedback). | Whatever the player sees first: egg reveal, pet reveal, rarity emphasis, toast or panel tied to hatch. | Pet/name text readable; rarity color does not destroy contrast. If multiple UI layers stack (toast + HUD), nothing illegible. Capture **before** dismissing if modal. |
| **FSO-04 Empty trophy** | Open **Trophy Case** from menu with **no** or minimal achievements unlocked (`DACMain.Panels.TrophyCase` — `DACStarterGui/TrophyCasePanel.luau`). | Grid area showing **locked / empty** cells, progress header, tabs, close control. | Empty state doesn’t look “broken” (consistent cell size, readable labels). Progress line and % readable on pastel panel. Category tabs readable; no overlapping title/closing ✕. |

---

## Layering spot-check (first session)

Quick pass to avoid regressions when payout, tutorial, and toasts can overlap:

- [ ] `DACTutorialOverlay` DisplayOrder **≥ 95000** (above main HUD; see `TutorialOverlayDesignSpec`).
- [ ] `DACPayout` uses `UILayerStack.screenGui.runResults` (**48**) — above `DACMain` base HUD.
- [ ] First hatch notification / achievement toast does not render **under** payout if both could occur close together (note actual order if seen).

---

## Spacing / contrast — free-form notes

_Use this section during QA; paste observations from phone vs tablet._

### Welcome (FSO-01)

- **Spacing:**
- **Contrast:**

### First payout (FSO-02)

- **Spacing:**
- **Contrast:**

### First hatch (FSO-03)

- **Spacing:**
- **Contrast:**

### Empty trophy (FSO-04)

- **Spacing:**
- **Contrast:**

---

## Sign-off

| Area | Tester | Date | Pass/Fail | Follow-up issue |
|------|--------|------|-----------|-----------------|
| FSO-01 Welcome | | | | |
| FSO-02 First payout | | | | |
| FSO-03 First hatch | | | | |
| FSO-04 Empty trophy | | | | |

**POLA-291 gate:** UI wired and reachable in a fresh session — **Yes / No** (if No, do not mark POLA-294 complete).
