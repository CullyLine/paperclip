# World Atmosphere & Juice Bible — Drive a Car Simulator

Authoritative Phase 4 reference for ambient particles, UI accents, run-end fanfare, and VFX color matching. Aligns with `DACReplicatedStorage/Config/WorldConfig.luau` world IDs and order.

**Style lock:** Low-poly, saturated, eye-candy Polymita — premium simulator that reads clearly on phone and in motion blur.

---

## grasslands — Grasslands

| Token | Hex | Usage |
|--------|-----|--------|
| Primary | `#3DDC84` | Lane markers, positive pickup flashes |
| Secondary | `#87E8A8` | Soft glows, streak trails |
| Sky / calm | `#5BC0EB` | HUD safe-zone, ambient sky wash |
| Accent / rare | `#FFD93D` | Rarity pings, coin sparkles |
| Danger lane | `#E85D4C` | Near-miss, hazard vignette edge |

**Mood:** Friendly, infinite summer road trip. **Fog:** None to light white (`#E8F5E9` haze). **Particle density:** **Medium** — pollen, soft leaves, occasional butterflies (sparse so lanes stay readable).

**DesignSpec cross-refs:** `DACStarterGui/DrivingVFXDesignSpec.luau` (speed lines: bias toward sky blue + grass green mix), `DACStarterGui/PayoutPanelDesignSpec.luau` (celebration: gold accent pairs with primary green).

**Splice search terms (ambient):** `summer highway`, `open road loop`, `light wind meadow`, `upbeat driving ambient`, `cartoon whoosh bright`

---

## desert — Scorching Desert

| Token | Hex | Usage |
|--------|-----|--------|
| Primary | `#F4A259` | Heat shimmer, sun flare core |
| Secondary | `#D97D55` | Sand spray, tire dust |
| Sky / calm | `#FCE7B2` | Haze layer, horizon wash |
| Accent / rare | `#FF6B35` | High-tier drops, heat “pop” |
| Danger lane | `#C73E1D` | Obstacle proximity pulse |

**Mood:** Relentless sun, long straight payouts. **Fog:** Heat haze amber (`#F9E0B4` at 25–40% opacity). **Particle density:** **High** for dust/sand near wheels; **low** for screen-center so UI stays legible.

**DesignSpec cross-refs:** `DACStarterGui/NearMissComboRewardDesignSpec.luau` (streak fire: blend accent orange with secondary), `DACStarterGui/MilestoneCeremonyDesignSpec.luau` (use sky wash for “epic but not blinding”).

**Splice search terms:** `desert wind loop`, `heat shimmer drone`, `middle eastern highway`, `sand sweep`, `dry whoosh`

---

## frozen — Frozen Tundra

| Token | Hex | Usage |
|--------|-----|--------|
| Primary | `#7DD3FC` | Ice crystals, clean highlights |
| Secondary | `#38BDF8` | Lane energy, boost trails |
| Sky / calm | `#E0F2FE` | Frost UI panels, soft vignette |
| Accent / rare | `#C084FC` | Aurora streaks, mythic pings |
| Danger lane | `#1E3A5F` | Deep freeze edge, blizzard wall |

**Mood:** Cold clarity, sharp rewards. **Fog:** Pale blue-white (`#F0F9FF`) low fog bands. **Particle density:** **Medium-high** snow sparkles; throttle during heavy UI (trophy toasts).

**DesignSpec cross-refs:** `DACStarterGui/PayoutPanelDesignSpec.luau` (stagger reveal: cool white key light + purple accent), `DACStarterGui/AchievementTrophySpec.luau` (Diamond tier: align accent with aurora purple).

**Splice search terms:** `arctic wind`, `ice sparkle`, `cold drone ambient`, `blizzard gust`, `crystalline chime`

---

## neon — Neon City

| Token | Hex | Usage |
|--------|-----|--------|
| Primary | `#F472B6` | Neon core, billboard bounce |
| Secondary | `#22D3EE` | Cyan edge light, underglow |
| Sky / calm | `#0F172A` | Night base, letterbox safe |
| Accent / rare | `#FBBF24` | Jackpot, legendary ping |
| Danger lane | `#EF4444` | Traffic danger, overload streak |

**Mood:** Future-money, slot-machine energy without clutter. **Fog:** Violet-pink bloom (`#4C1D95` → `#F472B6` radial). **Particle density:** **High** on run-end / milestone only; **low** during driving HUD.

**DesignSpec cross-refs:** `DACStarterGui/MilestoneCeremonyDesignSpec.luau` (full-screen celebration: pair primary pink + secondary cyan), `DACStarterGui/EggShopPanel` pity tiers (tier 3 golden text uses accent gold on dark sky base).

**Splice search terms:** `cyberpunk city night`, `neon synth drone`, `rain street`, `synthwave whoosh`, `digital riser`

---

## Global rules (engineering)

1. **Rarity glow ladder:** Bronze → Silver → Gold → Diamond uses shared ramp: increase saturation + bloom radius, never shift hue family per world (stay within that world’s accent column).
2. **Driving vs ceremony:** If `suppressDuringDriving` (see trophy toasts / VFX controller), particle budget drops to **low** everywhere.
3. **Thumbnail crops:** Use 16:9 master concept; safe title-safe zone center 60% for icons.

---

## Assets

Concept boards (PNG): `docs/concept_art/world_atmosphere/` — one file per world ID for art direction lock-in.
