# Tutorial overlay — readability & accessibility QA checklist

**Scope:** Manual QA for the **tutorial overlay path** (`StarterGui.DACTutorialOverlay` + `DACStarterGui/TutorialOverlay.luau`). Use this when validating Phase 4 polish or after Studio tweaks to fonts, colors, layout, or motion.

**Related work:** Pairs with tutorial copy/design specs; sound ducking and HUD layering are tracked separately (e.g. `docs/UILayerStackSpec.md`).

---

## References (must read before changing pass/fail)

| Document | What to use it for |
|----------|-------------------|
| `AGENTS.md` — Visual Design Guide & Typography | Panel/bubble style targets: high-contrast body text (`#1E1E1E` on light surfaces), Gotham family usage, chunky rounded UI, no cramped text. |
| `DACStarterGui/TutorialOverlayDesignSpec.luau` | Intended dimmer range, bubble typography ranges, highlight stroke color, Z-order notes, engineer polish checklist. |
| `DACStarterGui/TutorialOverlay.luau` | Actual motion: highlight stroke pulse, arrow bob, bubble `UIScale` intro, confetti burst on completion. |

---

## Environment

- [ ] **Viewport:** Run checks at **phone** and **tablet** aspect ratios (Studio Device Emulator or hardware). The overlay must remain readable when scaled; do not rely only on desktop 16:9.
- [ ] **Safe area:** With notch / home-indicator overlays enabled, bubble, **Skip**, and highlighted targets are not clipped. Compare against `HudSafeArea` / project safe-area conventions if applicable.
- [ ] **Theme:** Verify on both **light** and **dark** underlying HUD if the game exposes a contrast mode; bubble is light-on-dark dimmer by design — confirm body/title still read clearly.

---

## 1. Font contrast

**Goal:** Text meets the project bar for “readable at a glance” (`AGENTS.md`); tutorial bubble matches `TutorialOverlayDesignSpec` intent (dark text on light card over dimmed playfield).

- [ ] **Title (`Bubble.Title`):** GothamBlack (or project-equivalent), size in **22–26** range at 1080p reference; color **#1E1E1E** or same contrast vs bubble fill. No low-contrast gray on pastel/lavender fills.
- [ ] **Body (`Bubble.Body`):** Gotham secondary text; color **#3C3C50** (or darker if contrast fails on chosen gradient). `TextWrapped` on; no clipped lines for longest tutorial strings (see `docs/TutorialCopyReview.md` if updated).
- [ ] **Skip (`SkipTutorial`):** Tertiary style is OK, but **label must still pass contrast** against its background (ghost/outline must not be faint gray-on-gray). Disabled/hidden states: N/A on completion step (Skip hidden).
- [ ] **Highlight stroke & arrow:** Gold `#FFD54F`-family (`255, 213, 79`) on **both** light panels and dark HUD chrome — no “invisible” stroke on busy backgrounds (per design spec WCAG-ish note).
- [ ] **Dimmer:** Dark blue-black dimmer (`BackgroundColor3` per spec) + transparency **0.35–0.45** keeps lanes perceptible without washing out text. Adjust if title/body look muddy on OLED vs LCD test places.

---

## 2. Tap targets & layout

**Goal:** Primary actions are easy to hit; nothing critical is covered; alignment matches chunky simulator UI (`AGENTS.md`).

- [ ] **Skip control:** Minimum interactive height/width comfortable for thumb reach — **bottom third** on phone (`TutorialOverlayDesignSpec` §E). No overlap with system gestures (home bar).
- [ ] **Bubble vs gameplay:** When `targetName` highlights the action bar / drive affordance, bubble positioning (`layoutBubble`) does **not** fully obscure the drive button or mandatory HUD.
- [ ] **Highlight hit area:** The highlighted `GuiObject` remains scrollable/tappable if the step requires tapping it; stroke does not block input (`ApplyStrokeMode` / input passthrough — verify in play).
- [ ] **Arrow / edge clipping:** Arrow centered on target; on narrow screens, arrow X does not clip off-screen (spec notes future clamp — log if seen).

---

## 3. Motion safety (no seizure-risk flashes)

**Goal:** No patterns that exceed common photosensitivity guidance; motion is “juice,” not strobe. (General practice: avoid **>3 flashes per second** of saturated full-field red; prefer smooth, low-frequency motion.)

**Implemented behaviors (verify in play, don’t guess from code alone):**

| Element | Behavior (from script) | QA question |
|--------|-------------------------|-------------|
| Highlight stroke | Thickness **4 → 6**, **0.8s** sine loop, infinite while step shown | Pulse feels soft, not a sharp strobe; **pause** if any tester reports discomfort. |
| Arrow | **±8 px** vertical bob, **0.6s** sine loop | Bob is gentle; not confused with UI error flicker. |
| Bubble | `UIScale` **Back** overshoot then settle (~0.25s + 0.12s) | One-time per step; acceptable “pop.” |
| Confetti (completion) | Pieces tween fall + rotation; container destroyed after ~3s | Celebration read as festive, not flashing full-screen color at high frequency. |
| Dimmer | Static (no tween in script) | No unexpected brightness pulsing from dimmer. |

- [ ] **No rapid full-screen color alternation** between saturated red/green/blue at high frequency during tutorial steps.
- [ ] **Sound:** `tutorial_step` / `tutorial_complete` / click are distinct and not painfully loud relative to other HUD SFX (pairs with audio ducking work — not a substitute for motion QA).

---

## 4. Layering & regressions

- [ ] **Z-order:** `DACTutorialOverlay` DisplayOrder **≥ 95000** (per design spec) — tutorial reads above main HUD; verify against simultaneous overlays called out in spec (e.g. FriendBonus / payout) if those can appear during first session.
- [ ] **Completion step:** Skip hidden; confetti + chime; auto-dismiss ~**4s** — no stray input focus or stuck overlay.

---

## 5. Sign-off

| Check | Tester | Date | Pass/Fail | Notes |
|-------|--------|------|-----------|-------|
| Font contrast | | | | |
| Tap targets / layout | | | | |
| Motion safety | | | | |
| Layering | | | | |

**Fail criteria:** Any **Fail** in contrast (unreadable title/body/skip), blocked primary action, or reported discomfort from pulse/bob/confetti → file issue with screenshot + device profile and link this checklist.
