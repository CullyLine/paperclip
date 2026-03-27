# Loading splash — slot checklist (marketing vs engineering)

**Purpose:** Single table reconciling **`LaunchAssets/AssetIdChecklist.md` §3c** (filenames + slot roles) with **`docs/marketing/LoadingScreenSplashSlotsSpec.md`** (POLA-287 / per-slot creative brief — expanded art direction). Use this when uploading PNGs and when wiring `rbxassetid://` values.

**Runtime wiring:** `DACReplicatedStorage/Config/EasterEggConfig.luau` → `EasterEggConfig.LoadingScreenImages` (array of IDs, **display order is random** — see spec handoff). **Consumer:** `DACReplicatedFirst/LoadingScreen.local.luau`.

**Shared composition / crop rules:** `docs/marketing/LoadingScreenComposition.md`.

---

## Slot reconciliation table

| Slot | AssetIdChecklist §3c (filename + role) | Spec file reference (POLA-287 brief) | Status | Notes |
|------|----------------------------------------|----------------------------------------|--------|--------|
| **1** | `loading_landscape.png` — Landscape / scene | `LoadingScreenSplashSlotsSpec.md` — **Slot 1** (`loading_landscape.png`) | **placeholder** | Code table empty; no `rbxassetid://` yet. Establishes world fantasy; car + road hero. |
| **2** | `loading_logo.png` — Logo / branding | `LoadingScreenSplashSlotsSpec.md` — **Slot 2** (`loading_logo.png`) | **placeholder** | Only slot where **text/wordmark in source art** is allowed per spec. |
| **3** | `loading_character.png` — Character / avatar | `LoadingScreenSplashSlotsSpec.md` — **Slot 3** (`loading_character.png`) | **placeholder** | Illustration-only (no readable props with text). |
| **4** | `loading_abstract.png` — Artistic / abstract | `LoadingScreenSplashSlotsSpec.md` — **Slot 4** (`loading_abstract.png`) | **placeholder** | Abstract juice; avoid HUD-like numbers. |

**Status legend**

- **ready** — Asset uploaded to Roblox and ID present in `EasterEggConfig.LoadingScreenImages` (or documented out-of-band with ID for engineer).
- **placeholder** — Slot defined in checklist + spec; **no production ID in config** yet (`LoadingScreenImages` is still `{}` as of last doc sync).

---

## Count and naming sanity check

| Source | Slot count | Filenames |
|--------|------------|-----------|
| AssetIdChecklist §3c | **4** | `loading_landscape.png`, `loading_logo.png`, `loading_character.png`, `loading_abstract.png` |
| LoadingScreenSplashSlotsSpec (POLA-287) | **4** | Same four filenames (§ per-slot headers) |

**Match:** Four slots, same suggested filenames and roles — no drift between marketing spec and engineering manifest.

---

## Traceability

| Artifact | Role |
|----------|------|
| `LaunchAssets/AssetIdChecklist.md` §3c | Board-facing table + suggested filenames |
| `docs/marketing/LoadingScreenSplashSlotsSpec.md` | Per-slot creative brief (POLA-287 / expanded §3c) |
| `docs/marketing/LoadingSplashSlotChecklist.md` | This file — **status + cross-links** for upload QA |
