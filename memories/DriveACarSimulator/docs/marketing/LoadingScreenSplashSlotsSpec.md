# Loading screen splash — per-slot art specs (4 images)

**Purpose:** Expand **`LaunchAssets/AssetIdChecklist.md` §3c** into actionable, slot-by-slot direction for Board upload. **Spec-only** — no raster deliverables in-repo.

**Parent briefs (read first):**

- **`docs/marketing/LoadingScreenComposition.md`** — bands A–E, car vs. pet hierarchy, motion/flash rules.
- **`docs/marketing/IconThumbnailLayoutBrief.md`** — brand anchors (pastel panels, Gotham, emerald accents).
- **`docs/marketing/captures/README.md`** — POLA-259 capture mood (`hud.png`, `shop.png`, etc.).

**Code wiring:** `DACReplicatedStorage/Config/EasterEggConfig.luau` → `LoadingScreenImages` (table of `rbxassetid://` strings). **Consumer:** `DACReplicatedFirst/LoadingScreen.local.luau` — **one random** image per session when the table is non-empty.

---

## Runtime crop (what art is judged against)

All four masters are shown inside the **same UI chrome**:

| Property | Value |
|----------|--------|
| Container | Rounded card, **UICorner ~12 px** |
| Size | **~42%** of viewport width × **max 140 px** height (1080p reference) |
| Scale | **`ScaleType.Fit`** — letterboxing **inside** the card is expected |
| Position | Upper band — **~14%** from top, horizontally centered |
| Transparency | Image **~8%** faded (`ImageTransparency` 0.08) over **navy gradient** (`~#0E0E20` → deep blue) |

**Implication:** Focal mass (car silhouette, logo, or readable face) must read in **under one second** at **phone width** inside this **short, wide** card. **Ultra-wide** source frames are OK; **treat left/right card corners as disposable** for crop.

---

## Shared rules (all slots)

1. **Hierarchy:** **Car first**, **pet/economy second** — same as `LoadingScreenComposition.md` §2. No slot should read as “pet collector only” unless the car silhouette remains dominant.
2. **No text in source art** except **Slot 2** (logo/wordmark) — Slots 1, 3, and 4 must be **illustration-only** so they never fight the overlay title / FOMO headline / tips.
3. **Style:** Low-poly or stylized 3D, **saturated**, **pastel-panel** simulator vocabulary — consistent with **`captures/`** references, not photoreal grime.
4. **Safety:** Obey §4 in `LoadingScreenComposition.md` (no strobe, no rapid full-frame contrast flips) for any motion exports later.
5. **Export:** PNG with alpha **or** opaque on **dark** background; avoid light bleed that clashes with the gradient. Prefer **minimum long edge 512 px** for upload crispness (Roblox will downscale).

---

## Slot 1 — Landscape / scene (`loading_landscape.png`)

| Field | Direction |
|-------|-----------|
| **Job** | Establish **world fantasy** — highway, biome silhouette, or stylized horizon; sells “where you drive.” |
| **Hero** | **Road + car** — ¾ or side profile vehicle on a readable road strip; **horizon in lower third of the art** (inside the card this may be a thin band — avoid a **micro-sliver** horizon). |
| **Secondary** | Distant **world cue** (palm strip, aurora strip, neon strip) — **low detail**, no competing silhouettes. |
| **Palette** | Harmonize with **dark navy overlay**; sky or upper area can carry saturated gradient; **no** busy star fields behind where the title sits (title is **below** this card at runtime). |
| **Avoid** | Tiny cars, cluttered junctions, readable UI from gameplay screenshots. |

---

## Slot 2 — Logo / branding (`loading_logo.png`)

| Field | Direction |
|-------|-----------|
| **Job** | **Studio / game identity** on dark — works as a **legible emblem** at small size. |
| **Hero** | **Wordmark or monogram** — **GothamBlack** or custom mark matching in-game title weight; **white fill + dark stroke** or **gold on dark**; **single lockup**, no paragraphs. |
| **Secondary** | Optional **small car silhouette** or **wheel icon** integrated into the lockup — must not shrink type below readable at **card size**. |
| **Palette** | **Transparent or `#0E0E20`**-adjacent background; **gold accent** only if used sparingly (align with FOMO headline gold). |
| **Avoid** | Fine lines, thin sub-brands, legal disclaimers, multi-line slogans. |

---

## Slot 3 — Character / avatar (`loading_character.png`)

| Field | Direction |
|-------|-----------|
| **Job** | **Human warmth** — driver, racer persona, or stylized avatar bust; still says “simulator.” |
| **Hero** | **Character** centered or ⅔ frame; **helmet / visor** or expressive silhouette acceptable — must stay **family-friendly** and **legible** at small size. |
| **Secondary** | **Car interior edge** or **steering wheel** crop to anchor driving context; optional **tiny pet** in **lower corner** — **smaller than a wheel diameter** in frame. |
| **Palette** | Warm skin tones or stylized non-photoreal shading; **no** neon face paint that reads as hazard pattern at thumbnail size. |
| **Avoid** | Busy costumes that read as noise; holding readable props with text (phones, signs). |

---

## Slot 4 — Artistic / abstract (`loading_abstract.png`)

| Field | Direction |
|-------|-----------|
| **Job** | **Eye candy** — reward language without literal gameplay: **particles, streaks, soft bokeh**, trophy-energy **without** duplicating UI. |
| **Hero** | **Abstract motion** or **macro detail** — speed lines, confetti bokeh, **pastel shape stack** echoing `shop.png` cards; **one** focal cluster. |
| **Secondary** | Suggestion of **coin sparkle** or **egg glow** as **abstract shapes** — not literal HUD numbers. |
| **Palette** | **Pink–lavender–gold** accents on dark; keep **center** slightly calmer so the cluster does not look like noise. |
| **Avoid** | Full-frame **high-frequency** noise, checkerboards, or patterns that **pulse** when scaled (moiré risk on phones). |

---

## Handoff checklist (Board / uploader)

- [ ] Four PNGs named per table (or Board naming convention) uploaded to Roblox; **`rbxassetid://`** copied into `EasterEggConfig.LoadingScreenImages` **in slot order 1→4** if the team wants predictable QA ordering (runtime still **randomizes** display).
- [ ] Each asset passes **shared rules** and **slot-specific** “Avoid” rows.
- [ ] Spot-check at **375×667** and **1920×1080** with **`LoadingScreenComposition.md`** band A crop mentally overlaid.

---

## Traceability

| Reference | Link |
|-----------|------|
| POLA-283 (loading marketing brief) | Aligns with **`LoadingScreenComposition.md`** + this doc — per-slot detail for §3c. |
| AssetIdChecklist §3c | Table of filenames; **this doc** is the expanded creative brief. |
