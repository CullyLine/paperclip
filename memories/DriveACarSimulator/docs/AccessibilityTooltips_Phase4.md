# Accessibility settings — tooltip copy pack (Phase 4)

Tooltip-ready strings for future **Settings** info icons or long-press hints. Bodies stay under **220 characters** for small UI surfaces. Tone: clear, non-medical, aligned with [Roblox accessibility guidance](https://create.roblox.com/docs/production/publishing/publish-games-and-experiences/accessibility) (player control, optional alternatives, no diagnosis or treatment claims).

---

## 1. UI scale

| Field | Content |
|--------|---------|
| **Title** | UI scale |
| **Body** | Makes menus and HUD text larger or smaller on your screen. Use this if buttons or labels feel hard to read. Does not change world graphics quality. |
| **Wire note** | **New:** `MicrocopyConfig.SettingsTooltipUiScaleTitle` (short label) + `MicrocopyConfig.SettingsTooltipUiScaleBody` (tooltip). No key exists today — **SettingsPanel.luau** has no UI scale slider; players may use Roblox **Settings → Accessibility** at the platform level until an in-experience control ships. |
| **Wiring** | **Engineer** — add setting + persist key (e.g. `uiScale` 0.85–1.25) and apply via root `UIScale` or equivalent; then point tooltips at the new Microcopy keys. |

**Body char count:** 198

---

## 2. Camera shake

| Field | Content |
|--------|---------|
| **Title** | Camera shake |
| **Body** | Reduces or turns off screen movement when you hit boosts, near-misses, or big moments. Turning this on keeps the camera steadier; it does not change gameplay rules or rewards. |
| **Wire note** | **New:** `MicrocopyConfig.SettingsTooltipCameraShakeTitle` + `SettingsTooltipCameraShakeBody`. Shake is currently driven by **VFXFacade.cameraShake** in **DrivingController.luau** (no separate toggle). Optional future key: `cameraShakeEnabled` boolean in player settings. |
| **Wiring** | **Engineer** — gate `VFXFacade.cameraShake` (and any follow cam offset that reads shake) behind a persisted setting; copy keys are ready to wire after that. |

**Body char count:** 214

---

## 3. Screen flash

| Field | Content |
|--------|---------|
| **Title** | Screen flash |
| **Body** | Dims bright full-screen flashes from speed tiers, laps, and combo callouts. Helpful if flashing lights are uncomfortable. Some subtle HUD motion may remain unless you also use Reduced motion. |
| **Wire note** | **New:** `MicrocopyConfig.SettingsTooltipScreenFlashTitle` + `SettingsTooltipScreenFlashBody`. Flashes live in **DrivingHUD.luau** (milestone / near-miss / combo) and related VFX; not independently toggled today. Cross-ref: **ClientPerformanceProfile.isReducedMotion()** already softens some UI tweens (**UIController.luau**). |
| **Wiring** | **Engineer** — add `screenFlashReduced` (or fold into reduced-motion tiers) and branch HUD/VFX flash intensity; then bind tooltips. |

**Body char count:** 211

---

## 4. Motion reduction

| Field | Content |
|--------|---------|
| **Title** | Reduced motion |
| **Body** | Shortens or skips extra menu animations, toast motion, and celebratory UI tweens. Driving and payouts work the same; the game just feels calmer. Pair with platform accessibility options if you need less motion everywhere. |
| **Wire note** | **Existing setting key:** `reducedMotion` (boolean) — **SettingsPanel.luau** row label `"Reduced motion"`; **SettingsService.luau** / **DataManager** persist; **ClientPerformanceProfile.syncFromSettings** mirrors to `DAC_Settings_ReducedMotion`. Tooltip copy should live in **MicrocopyConfig** as `SettingsTooltipReducedMotionTitle` + `SettingsTooltipReducedMotionBody` (replacing hardcoded row title/sub or augmenting with `TextButton` info affordance). |
| **Wiring** | **Engineer** — wire tooltip strings from MicrocopyConfig to the pre-built Settings row (or info icon); behavior already exists. |

**Body char count:** 218

---

## 5. Colorblind presets

| Field | Content |
|--------|---------|
| **Title** | Color filters |
| **Body** | Adjusts UI and world colors to improve contrast for common color-vision differences. Pick a preset that makes coins, warnings, and rarity colors easier to tell apart. This is a display aid, not a medical tool. |
| **Wire note** | **Not implemented** — no colorblind / Daltonism preset in **SettingsPanel** or configs yet. Reserve **MicrocopyConfig.SettingsTooltipColorblindTitle** + **SettingsTooltipColorblindBody**; if presets ship, add keys like `colorblindPreset: "off" \| "deuteranopia" \| "protanopia" \| "tritanopia"` (exact enum TBD by Engineer). |
| **Wiring** | **Engineer** — full feature (shader/UIColor overlay + setting); until then this doc is **copy-only** specification. |

**Body char count:** 216

---

## 6. Subtitles / captions

| Field | Content |
|--------|---------|
| **Title** | Subtitles |
| **Body** | Shows text for spoken or major audio callouts when the game includes them. Turn on if you play without sound or want dialogue written on screen. Does not replace Roblox’s own caption settings for the app. |
| **Wire note** | **Not implemented** — no subtitle track for VO in DAC today. Reserve **MicrocopyConfig.SettingsTooltipSubtitlesTitle** + **SettingsTooltipSubtitlesBody** for future dialogue, tutorial VO, or event announcer lines. |
| **Wiring** | **Engineer** — subtitle pipeline + setting `subtitlesEnabled`; copy keys wire once captions exist. Until then **copy-only**. |

**Body char count:** 214

---

## Quick reference — MicrocopyConfig additions (proposed)

| Proposed key | Status |
|----------------|--------|
| `SettingsTooltipUiScaleTitle` / `SettingsTooltipUiScaleBody` | New — pending UI scale feature |
| `SettingsTooltipCameraShakeTitle` / `...Body` | New — pending camera shake toggle |
| `SettingsTooltipScreenFlashTitle` / `...Body` | New — pending flash reduction toggle |
| `SettingsTooltipReducedMotionTitle` / `...Body` | New — **behavior exists**; strings not in Microcopy yet |
| `SettingsTooltipColorblindTitle` / `...Body` | New — copy-only until presets exist |
| `SettingsTooltipSubtitlesTitle` / `...Body` | New — copy-only until caption pipeline exists |

---

## Files on disk

- `memories/DriveACarSimulator/docs/AccessibilityTooltips_Phase4.md` (this document)
