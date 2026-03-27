# Icon & thumbnail layout brief — Drive a Car Simulator

**Purpose:** Layout-only direction for a future art pass (no generated imagery here). Informed by **`docs/marketing/captures/`** (POLA-259): `hud.png`, `shop.png`, `trophy.png`, `payout.png`, `friend_bonus.png` — see `captures/README.md` for role of each shot.

**Brand anchors (stay consistent with in-game UI):** Pastel pink–lavender panels, chunky rounded shapes, high-contrast white titles with stroke, **GothamBlack / GothamBold** for headlines, emerald **#2ECC71** for positive actions, simulator “juice” (particles, fanfare moments) where it reads at small size.

---

## Game icon (512×512 target)

**Focal subject**

- **Primary:** A **hero vehicle** (one recognizable car silhouette) angled ¾ front, slightly above horizon — reads as “driving sim” in a circular crop.
- **Secondary read:** A **small coin stack or single large coin** tucked near the front wheel or lower corner to signal economy/progression without competing with the car silhouette.

**Composition & safe zones**

- **Center-weighted hero:** Keep the car’s body mass in the **central ~70% diameter circle**; Roblox and store UIs often mask icons as circles — **corners are frequently clipped**.
- **Top arc reserved:** Leave the **top 12–15%** of the frame visually quieter (sky gradient, soft burst, or light VFX) so platform chrome or notification badges don’t fight the subject.
- **Bottom arc:** Optional **short title treatment** (“DRIVE” / “DAC”) only if type is **extra-bold, high stroke, max 1–2 words** — keep inside the **lower third**, above where circular crops cut deepest at left/right.

**Text / logo**

- Prefer **no paragraph text** on the icon. If a wordmark is used, **single line**, **GothamBlack**, white fill + dark stroke, **never** smaller than ~12% of frame height in the final asset.

---

## Experience thumbnail (wide — e.g. 1920×1080 or 1280×720)

**Focal subject**

- **Primary:** **Gameplay moment** — road perspective + HUD readout (speed, distance, or combo) so it reads as “live play,” not a menu.
- **Secondary:** **Reward signal** — either a **coin burst** near the HUD or a **small pet silhouette** peeking from UI chrome (aligns with pets/eggs pillar) so progression + collection are visible at a glance.

**Composition & safe zones**

- **Rule of thirds:** Horizon / road vanishing point ~**lower third**; sky or world color in upper area for title overlay.
- **Left third — UI-heavy:** Assume **HUD, currency, and primary buttons** sit **left or bottom-left** (matches safe-area–aware HUD from `hud.png`). Do **not** place the main title over dense HUD clusters.
- **Right third — breathing room:** Reserve for **short headline** (“DRIVE. EARN. COLLECT.”) or **event chip**; keep **40% of the right side** relatively clean for text or Roblox store overlay.
- **Bottom edge:** Keep **~8–10% vertical band** free of critical detail — store pages may crop or add badges.

**Text**

- **Title:** Top **safe band** (full width, **upper 18–22%**): large **GothamBlack**, white + stroke, optional small subtitle in **GothamBold** below in **#1E1E1E** on a light pill if contrast fails on busy backgrounds.

---

## Variant ideas (pick one direction per campaign; A/B in ads)

### Variant A — **Car + coin pile (economy-first)**

- **Icon:** Car ¾ hero; **coin pile** as foreground anchor at **bottom center** (in the safe inner circle). Tiny speed lines or motion blur on road only — keep silhouette readable at 64×64.
- **Thumbnail:** Wide road shot; **large payout-style numbers** or coin pop (see `payout.png` language) in **lower-left** near HUD; headline emphasizes **earn / rebirth / upgrades**.

### Variant B — **Car + pet (collection-first)**

- **Icon:** Same car hero; replace secondary prop with a **single iconic pet** (egg silhouette or pet head) at **lower right** inside the safe circle — smaller than the car wheel footprint so hierarchy stays “drive first.”
- **Thumbnail:** Slightly wider FOV to show **pet slot or egg iconography** in UI; headline emphasizes **pets, eggs, collection**; use **trophy / collection** mood from `trophy.png` as color reference (pastel panel, not dark UI).

---

## Reference captures (on disk)

| Capture | Reuse for layout mood |
|--------|------------------------|
| `captures/hud.png` | Icon crop stress-test; thumbnail gameplay framing + HUD clutter zones |
| `captures/payout.png` | Coin burst / big numbers placement for Variant A |
| `captures/trophy.png` | Collection framing for Variant B |
| `captures/friend_bonus.png` | Social / viral angle — top banner safe zone |
| `captures/shop.png` | Monetization storyboards — **not** default hero thumbnail unless running a sale creative |

---

## Handoff checklist for art

- [ ] Icon legible at **64×64** (silhouette + one prop read).
- [ ] Icon critical content inside **central circle**; corners disposable.
- [ ] Thumbnail title readable at **~320px wide** preview; no text on busy HUD clusters.
- [ ] Two masters exported: **Variant A (coins)** and **Variant B (pet)** — same brand colors and type rules.
