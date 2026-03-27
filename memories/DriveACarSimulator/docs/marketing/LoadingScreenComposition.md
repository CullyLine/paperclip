# Loading screen composition brief — Drive a Car Simulator

**Purpose:** One-page art direction for **static or lightly animated** loading-splash imagery and any future marketing stills that mirror the in-game loading overlay. Aligns with **`docs/marketing/captures/`** (POLA-259) spirit — same **low-poly, saturated, pastel-panel** simulator read as `hud.png` / `shop.png` — and with runtime layout in `DACReplicatedFirst/LoadingScreen.local.luau`.

**Brand anchors:** Dark navy gradient base (`~#0E0E20` → deep blue), **GothamBold** title treatment (white on dark), gold accent for FOMO headline and progress chrome — see `docs/marketing/IconThumbnailLayoutBrief.md` for type and color consistency.

---

## 1. Safe zones (full-screen 16:9 master; scale for mobile)

Think in **vertical bands**; nothing safety-critical in the **extreme edges** (notches, Roblox chrome).

| Band | Approx. vertical slice | Role | Art guidance |
|------|------------------------|------|--------------|
| **A — Top hero** | **0%–22%** from top | Optional **splash image** slot (when `LoadingScreenImages` is populated). Rounded card, **~42% frame width**, **max height ~140 px** at 1080p reference; **Fit** scaling — letterboxing inside the card is OK. | Keep **focal silhouette** (car or pet) inside this card; treat **corners of the full frame** as disposable for ultra-wide crops. |
| **B — Title + glow** | **~22%–34%** | Game title **“Drive a Car Simulator”** + soft radial glow behind text. | **Do not** place busy detail behind the title block — readability beats texture. |
| **C — FOMO headline** | **~38%–46%** | Single **“Today in DAC: …”** line (when headlines exist); gold text, may wrap to **2 lines** max in design. | Reserve **full width minus ~12% side margin**; avoid high-frequency patterns behind text. |
| **D — Loading tip** | **~48%–58%** | Rotating tip; **Gotham**, **~18px** equivalent, **wrapped** — see §3. | Background stays **calm**; no competing illustrations behind this block. |
| **E — Progress + footer** | **~62%–78%** | Chunky progress bar (~72% width), sparkles, optional micro-flourishes. | Keep **bar area** uncluttered; **no** critical art in the **bottom ~8–10%** (platform/UI overlap on some devices). |

**Horizontal safe zone:** Keep **hero subject and readable faces/logos** within the **central ~80% width**; side notches and safe-area inset can eat the outer 10% per side.

---

## 2. Focal car vs. pet placement

**Default hierarchy:** **Car first** (silhouette reads in **<1 s** at phone size). **Pet second** — small, **lower-third of the splash card** or tucked near the bumper, **smaller than a wheel diameter** in frame so the shot still says “driving sim,” not “pet collector only.”

- **Car-forward splash:** ¾ front hero, motion implied toward camera; horizon in **lower third** of the **splash card** only (the card is small — avoid tiny horizon lines).
- **Pet-forward splash (collection beat):** Single **iconic pet head or egg** beside the car; **pet must not occlude the car grille/headlights** — keep the vehicle silhouette intact.
- **If no splash image** (empty config): composition brief still applies to **any future full-bleed background art** — shift focal interest to **bands B–C** (title + headline) and keep **band D–E** minimal.

---

## 3. Maximum text lines (for shipped copy + art proofs)

| Element | Max lines | Notes |
|---------|-----------|--------|
| Game title | **1** | No subtitle on the loading overlay; campaign taglines belong in **headline** or marketing thumbnails. |
| FOMO headline (`Today in DAC: …`) | **2** | **GothamBold ~16px** equivalent; test at **320px wide** viewport. |
| Loading tip | **4** | **~18px**, wrapped — keep tips **≤ 280 characters** where possible; shorter is better for localization. |
| Progress region | **0** text | Numbers not shown on bar — art must not rely on text in **band E** except the bar itself. |

**VIP / premium tips** (`[VIP]` prefix in UI): same line budget; gold color only — do not add extra glyphs or badges in source art.

---

## 4. Motion, flash, and “no strobe” guidance

**Static marketing exports (game page, ads, Discord):**

- **No** full-frame **strobe** between **high-contrast** states at **≥3 flashes per second**.
- **No** rapid **full-screen** color flipping (red/white, black/white) even once — treat as **out of spec** for Roblox-adjacent promotion and photosensitivity risk.
- **Sparkles / particles** in reference art: OK if **sparse** and **not** synchronized to a fast beat across the whole canvas.

**If animating loading-related promos (GIF / short video):**

- Prefer **slow** ambient motion (drift, parallax, **>2 s** cycles) over sharp flashes.
- **Pulses** (e.g. glow behind title): keep **amplitude modest** and **cycle ≥ ~2.4 s**; **avoid** pairing pulse with **synced** audio hits on every beat.
- **Headline “blink”** in-game is a **soft opacity tween** — any marketing mimic should stay **sub-threshold** (no hard on/off).

---

## 5. Reference captures (on disk)

| Capture | Use for loading-adjacent mood |
|---------|-------------------------------|
| `captures/hud.png` | Readability under **busy but structured** UI — don’t exceed this clutter in **bands C–D**. |
| `captures/payout.png` | **Gold / reward** accent density — OK for **accents**, not for full-screen flash. |
| `captures/trophy.png` | **Pet / collection** warmth without darkening the whole scene. |
| `captures/shop.png` | Monetization **panels** — reference for **pastel cards**, not for loading **background** busyness. |

---

## Per-slot splash masters (Board)

For **four discrete upload slots** (landscape, logo, character, abstract) with filenames and slot-by-slot rules, see **`docs/marketing/LoadingScreenSplashSlotsSpec.md`** (`AssetIdChecklist.md` §3c).

---

## Handoff checklist

- [ ] Hero **car or pet** readable at **splash card** size; hierarchy **drive → collect**.
- [ ] **Title + tip** regions kept **clean**; no critical detail behind **bands B–D**.
- [ ] Tip copy **≤ 4 lines** at reference font sizes; headline **≤ 2 lines**.
- [ ] No **strobe-like** full-frame flashing in stills or approved motion tests.
