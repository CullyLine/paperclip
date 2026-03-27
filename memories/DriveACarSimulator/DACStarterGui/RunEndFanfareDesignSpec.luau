--!strict
--[[
	RUN-END FANFARE — VISUAL & AUDIO DESIGN SPEC
	=============================================
	Phase 4 dopamine: the first beat after the car stops — **before** the payout
	card timeline (`PayoutPanelDesignSpec`). This spec is the contract for
	`VFXController.runEndFanfare(isRecord, isRunOfDay?)` and must stay synchronized with
	`PayoutPanel.show()` call order.

	Call order today (`PayoutPanel.luau`):
	  1. `VFXFacade.runEndFanfare(isRecord, runOfDayCelebration)`  ← this spec
	  2. `runScreenFlash` (full-screen warm/white flash, UI-layer)
	  3. Payout anticipation dim + center glow + card entrance choreography

	Design goal: a **single camera punch + world-themed sparkle burst** that reads
	instantly as “run over — you survived — here comes the loot.” Record runs
	must feel rarer and hotter than normal finishes without stealing thunder from
	the slot-machine payout card.

	Reference implementation:
	  - `DACStarterPlayerScripts/Controllers/VFXController.luau` (`runEndFanfare`)
	  - `DACStarterGui/PayoutPanel.luau` (lines ~191–193)

	Engineer notes:
	  - `activeWorldId` is set from `onRunStarted` / world switching — use it for
	    per-world accent colors (same semantic family as `WORLD_TRAIL_NEON`).
	  - Add `volcano` to `WORLD_TRAIL_NEON` + fanfare table when that world ships.
	  - Particle textures: stock `rbxasset://textures/particles/sparkles_main.dds`
	  - Never stack a **second** camera FOV tween inside payout UI — this fanfare
	    owns the only FOV punch at t=0 of the payout sequence.
]]

--[[
================================================================================
  SECTION A — CAMERA FOV PUNCH (world-space, t = 0s of payout)
================================================================================
  Purpose: micro-hit of speed → relief. One short overshoot then settle.

  CURRENT IMPLEMENTATION (baseline — do not loosen without design review):
    Phase 1 — Out punch:
      Duration       : 0.14s
      EasingStyle    : Quad
      EasingDirection: Out
      Delta FOV      : +11 studs, clamped so final ≤ 88
      Base reference : `startFov` from `workspace.CurrentCamera.FieldOfView`

    Phase 2 — Return:
      Start delay    : 0.14s after phase 1 start (parallel return)
      Duration       : 0.38s
      EasingStyle    : Quad
      EasingDirection: Out
      Target FOV     : `startFov` (exact restore)

  ACCEPTABLE TUNING BAND (if playtests feel mild):
    | Parameter   | Min  | Max  |
    |-------------|------|------|
    | Out duration| 0.12 | 0.16 |
    | Delta FOV   | +9   | +13  |
    | Return dur  | 0.32 | 0.42 |

  ANTI-PATTERNS:
    - Do **not** add a second FOV bump when the payout card pops (see Section E).
    - Do **not** tie FOV to `isRecord` — save record drama for particles + SFX +
      `runScreenFlash` + payout card.
================================================================================
]]

--[[
================================================================================
  SECTION B — SFX (SoundFacade.playOneShot)
================================================================================
  CURRENT IMPLEMENTATION:
    isRecord == true  → `level_up`
    isRecord == false and isRunOfDay → `purchase` @ pitch 1.07 (panel also plays `payout_run_of_day`)
    else              → `purchase`

  Rationale:
    - Record: achievement cadence — celebratory, matches long-term progression.
    - Normal end: soft “ka-ching” / reward ear candy — leads into payout SFX.

  OPTIONAL FUTURE UPGRADE (P1 — register keys first in `SoundController`):
    Add a **one-shot world stinger** ≤ 0.12s mixed under the primary cue, keyed
    by `activeWorldId`, at **−8 dB** vs primary. Not required for MVP; document
    keys here when added:
      runend_stinger_grasslands
      runend_stinger_desert
      runend_stinger_frozen
      runend_stinger_neon
      runend_stinger_volcano
================================================================================
]]

--[[
================================================================================
  SECTION C — PARTICLE BURST (Attachment above HumanoidRootPart)
================================================================================
  Two emitters: **burst** (omni spark shower) + **shower** (upward cone).

  LOD scaling uses `lodBurstMul()` in `VFXController`:
    | lodTier | Multiplier |
    |---------|------------|
    | 1       | 0.50       |
    | 2       | 0.75       |
    | 3       | 1.00       |

  BASE COUNTS (current code — multiply by `lodBurstMul()`):
    | Mode        | burst emit | shower emit |
    |-------------|------------|-------------|
    | Record (PB) | 140        | 70          |
    | Run of Day  | 140        | 70          |
    | Normal      | 95         | 45          |

  Shared parameters (burst):
    Texture          : sparkles_main
    Lifetime         : 0.5 – 1.2s
    Speed            : 4 – 22
    SpreadAngle      : (180, 180)
    Size sequence    : 0.35 → 0.9 → 0.15
    LightEmission    : 0.85

  Shared parameters (shower):
    Texture          : sparkles_main
    Lifetime         : 0.8 – 1.4s
    Speed            : 8 – 28
    SpreadAngle      : (25, 25)
    EmissionDirection: Top
    Acceleration     : (0, -35, 0)

  Attachment cleanup: destroy attachment after **2s** (existing).

  WORLD ACCENT — target colors (replace flat gold when implementing):
    Use **two** ColorSequence key colors: primary burst + secondary shower.
    Fallback if world unknown: grasslands row.

    | worldId    | burst primary      | shower secondary   | Notes |
    |------------|--------------------|--------------------|-------|
    | grasslands | RGB(130, 255, 150) | RGB(200, 255, 210) | fresh win |
    | desert     | RGB(255, 190, 90)  | RGB(255, 230, 140) | heat |
    | frozen     | RGB(160, 230, 255) | RGB(220, 245, 255) | crisp ice |
    | neon       | RGB(255, 80, 210)  | RGB(180, 120, 255) | synth |
    | volcano    | RGB(255, 95, 45)   | RGB(255, 200, 80)  | ember core |

  RECORD INTENSITY: multiply world accent toward white by **+8%** on the R/G
  channels only (keep blue channel stable) — subtle “hotter” read, not a second
  emitter layer.

  IMPLEMENTATION STATUS:
    ✓ FOV punch + SFX + dual emitter + LOD
    ✓ World-tinted burst/shower (`RUN_END_FANFARE_BURST` / `RUN_END_FANFARE_SHOWER`, `activeWorldId`; PB +8% R/G; ROTD amber lerp)
    ✓ `volcano` presets in `WORLD_TRAIL_NEON` + fanfare tables (ready when biome is active in runs)
================================================================================
]]

--[[
================================================================================
  SECTION D — COORDINATION WITH PAYOUT UI (no double drama)
================================================================================
  Timeline (same session, same `PayoutPanel.show` call):

    t ≈ 0.00s  runEndFanfare + runScreenFlash start
    t ≈ 0.00s  PayoutAnticipationDim begins tween (0.2s darkening)
    t ≈ 0.00s  PayoutAnticipationGlow pulse loop

  Rules:
    - Fanfare FOV completes its return by ~0.52s — **before** heavy card
      elastic overshoot. This keeps vestibular load low.
    - `runScreenFlash` uses UI full-screen frame (`Z.payoutFlash`) — orthogonal
      to camera FOV; both are allowed together.
    - `payout_anticipation_hum` — **deferred** (see `PayoutPanelDesignSpec`, POLA-722); optional future layer.
    - When implemented: start hum at t=0 with **−6 dB** vs run-end SFX so the ear reads:
      fanfare sting → hum → card pop.

  If future design adds **camera shake** on payout card entrance, cap shake at
  **0.02** intensity and **0.12s** duration — lower than near-miss shake tiers.
================================================================================
]]

--[[
================================================================================
  SECTION E — QA CHECKLIST (Studio)
================================================================================
  - [ ] Normal run end: hear `purchase`, see gold-tinted sparkles, FOV returns.
  - [ ] PB run: hear `level_up`, higher emit counts, brighter flash (`runScreenFlash`).
  - [ ] Each world: accent colors match Section C table (once implemented).
  - [ ] LOD 1: visibly fewer particles but still celebratory.
  - [ ] No FOV conflict when opening payout immediately after long session.
================================================================================
]]

return nil
