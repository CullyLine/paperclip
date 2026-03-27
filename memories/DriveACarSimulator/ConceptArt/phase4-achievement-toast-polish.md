# Phase 4 — Achievement toast & progress nudge (DAC style alignment)

**Goal:** Runtime achievement UI (`AchievementController.luau`) should read as part of the same **bubbly pastel simulator** language as inventory / store panels (`AGENTS.md`), not as a separate dark-HUD skin.

## Principles (from AGENTS.md)

| Element | Direction |
|--------|-----------|
| Panel body | Pastel pink `#FFD6EE` → lavender `#E0D6FF` gradient (vertical) |
| Border | Charcoal `#2A2A40`, **thick** (2–3 px) — rarity tint is **accent**, not the outer chrome |
| Title | **GothamBlack**, **white** + dark `TextStroke` for pop |
| Body copy | Dark `#1E1E1E` on light background |
| Positive / progress | Emerald `#2ECC71` for fills and “good” affordances |

Ephemeral toasts are built at runtime (allowed), but they should still **feel** like DAC panels.

## Unlock toast (`AchievementToast`)

- **Background:** `UIGradient` on white base fill — top `#FFD6EE`, bottom `#E0D6FF`.
- **Stroke:** `UIStroke` charcoal `#2A2A40`, thickness scales slightly with rarity (diamond a hair thicker).
- **Rarity accent:** Thin horizontal bar under the headline (3 px) in `RARITY_ACCENT` — reads as “juice” without abandoning the pastel card.
- **Headline:** White, black stroke (~0.45–0.55 transparency).
- **Subline:** `#1E1E1E`, `GothamBold` or `GothamMedium` as today.

Confetti, camera shake, and `SoundFacade` keys are unchanged — this pass is **visual hierarchy** only.

## Progress nudge (`AchievementProgressToast`)

- Same gradient + charcoal stroke as unlock toasts.
- **Count** (e.g. `3 / 10`): keep gold emphasis but slightly warmer so it sits on pastel (`#FFC94A` range).
- **Bar track:** Dark inset `#37324A` (readable on gradient).
- **Bar fill:** Emerald `#2ECC71` (canonical “positive” action color).

## Engineer notes

- All colors live in-controller next to `RARITY_ACCENT` for a single place to tune Phase 4 juice.
- If Studio screenshots show banding on gradient, reduce `BackgroundTransparency` slightly or add a 1 px inner `Frame` with `UIGradient` only on large displays.

## Files

- `DACStarterPlayerScripts/Controllers/AchievementController.luau` — implementation
- This doc — art direction + QA checklist
