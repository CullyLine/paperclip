--!strict
--[[
	REBIRTH MILESTONE VISUAL LANGUAGE + HATCH RARITY CRACK SEQUENCE — Design Spec
	===============================================================================
	This file defines exact visual parameters for two systems:
	  A) Rebirth Milestone Ceremony VFX (one-shot at milestone thresholds)
	  B) Hatch Rarity Crack Sequence     (per-rarity egg break animation)
	  C) PetEntranceDesignSpec.luau Review Notes

	Reference files:
	  - DACReplicatedStorage/Config/RebirthMilestoneConfig.luau
	  - DACStarterPlayerScripts/Controllers/VFXController.luau (rebirthMilestoneVfx)
	  - DACStarterPlayerScripts/PrestigeAura.local.luau
	  - DACStarterGui/PetEntranceDesignSpec.luau

	Engineer implementation notes:
	  - Rebirth VFX lives in VFXController.rebirthFlash → rebirthMilestoneVfx().
	    Current code already branches per milestone key. This spec formalizes the
	    intended design language and adds missing visual layers.
	  - Hatch crack sequence lives in VFXController.hatchReveal(). Currently all
	    rarities share the same egg wobble and break animation. This spec defines
	    rarity-specific crack phases to layer on top.
	  - All particle textures use engine-stock assets:
	      "rbxasset://textures/particles/sparkles_main.dds"
	      "rbxasset://textures/particles/smoke_main.dds"
	  - LOD multipliers apply: lodBurstMul() for Emit counts, lodTrailRateMul()
	    for Rate-based emitters. Budget stays within TRAIL_BUDGET philosophy.
	  - PrestigeAura.local.luau handles persistent world-space glow per tier.
	    This spec covers the one-shot ceremony only.
]]


--[[
================================================================================
  SECTION A — REBIRTH MILESTONE VISUAL LANGUAGE
================================================================================
  Five milestone tiers, each with a distinct visual identity that makes the
  player immediately recognize HOW prestigious this rebirth is. Each tier
  builds on the previous, adding new layers rather than just scaling numbers.

  Milestone tiers (from RebirthMilestoneConfig):
    Tier 1 — VETERAN   (5 rebirths)
    Tier 2 — ELITE     (10 rebirths)
    Tier 3 — MASTER    (25 rebirths)
    Tier 4 — LEGEND    (50 rebirths)
    Tier 5 — IMMORTAL  (100 rebirths)

  Design philosophy:
    - Each tier owns a unique COLOR IDENTITY that never overlaps with another.
    - Particle DENSITY doubles roughly per tier jump.
    - New EFFECT TYPES unlock at higher tiers (beams, confetti, reality cracks).
    - Screen flash INTENSITY and DURATION scale linearly.
    - Camera shake INTENSITY increases per tier; absent at low tiers.
    - SOUND layering: single SFX at low tiers, multi-layer at high tiers.
    - UNIQUE VISUAL MOTIF per tier: badge icon silhouette baked into the label
      styling and particle shape behavior.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER COMPARISON TABLE
────────────────────────────────────────────────────────────────────────────────

  | Property              | VETERAN        | ELITE          | MASTER         | LEGEND         | IMMORTAL       |
  |-----------------------|----------------|----------------|----------------|----------------|----------------|
  | Threshold             | 5              | 10             | 25             | 50             | 100            |
  | Primary Color         | Bronze         | Silver         | Gold           | Diamond/Cyan   | Rainbow        |
  | Accent Color          | Warm Amber     | Cool White     | Deep Orange    | Ice Blue       | Hot Pink       |
  | Particle Count (LOD3) | 140            | 270            | 420            | 520            | 680            |
  | Screen Flashes        | 2 (staggered)  | 1 + confetti   | 3 (cascade)    | 2 + beams      | 3 + reality    |
  | Flash Peak Transp.    | 0.68 / 0.52    | 0.65           | 0.20/0.55/0.62 | 0.18 / 0.58    | 0.12/0.50/0.52 |
  | Flash Duration (sum)  | 1.05s          | 0.55s          | 1.65s          | 1.10s          | 1.60s          |
  | Camera Shake          | none           | none           | 0.50 / 0.45s   | 0.65 / 0.55s   | 0.85 / 0.75s   |
  | Camera FOV Punch      | none           | none           | none           | +4, 0.3s back  | +8, 0.45s back |
  | Unique Visual         | Shield burst   | Confetti rain  | Crown ring     | Diamond beams  | Reality crack  |
  | Sound Layers          | 1 (boom)       | 1 (confetti)   | 1 (boom)       | 1 (boom)       | 2 (riser+boom) |
  | Banner Text Size      | 80px           | 80px           | 80px           | 88px           | 96px           |
  | Banner Duration       | 1.8s           | 1.8s           | 1.8s           | 1.8s           | 1.8s           |
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER 1 — VETERAN (5 Rebirths) — Bronze Shield Identity
────────────────────────────────────────────────────────────────────────────────
  The player's first milestone. Warm, congratulatory, but understated compared
  to later tiers. The bronze palette evokes earned endurance.

  COLOR PALETTE:
    Primary        : Color3.fromRGB(200, 120, 60)   -- warm bronze
    Accent         : Color3.fromRGB(255, 200, 120)   -- light amber
    Flash Primary  : Color3.fromRGB(200, 120, 60)
    Flash Secondary: Color3.fromRGB(255, 200, 120)
    Text           : Color3.fromRGB(220, 150, 90)

  SCREEN FLASHES:
    Flash 1 (t=0.00s): Color = primary,  duration = 0.55s, peak transp. = 0.68
    Flash 2 (t=0.10s): Color = accent,   duration = 0.50s, peak transp. = 0.52

  PARTICLE BURST (on HumanoidRootPart Attachment):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(primary)
    Emit count     : 140 * lodBurstMul()
    Lifetime       : NumberRange.new(0.35, 0.75)
    Speed          : NumberRange.new(14, 32)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.35, 1.2)
    LightEmission  : 0.6
    Acceleration   : Vector3.new(0, -8, 0)
    Drag           : 0.3

  UNIQUE — Shield burst silhouette:
    (No extra geometry needed — the directional speed bias creates a
    "shield arc" shape. Particles emit with reduced vertical spread.)
    SpreadAngle bias: Vector2.new(140, 60) for 40% of particles
    (Engineer: emit 56 particles with narrow vertical, 84 with full spread)

  CAMERA: No shake. No FOV punch.

  SOUND:
    t=0.0s : "rebirth_boom"

  BANNER:
    Text           : "VETERAN!"
    TextSize       : 80
    TextColor3     : Color3.fromRGB(220, 150, 90)
    Subtitle       : "REBIRTH #{count}"
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER 2 — ELITE (10 Rebirths) — Silver Rain Identity
────────────────────────────────────────────────────────────────────────────────
  Cool silver palette. Confetti rains from above — the first tier where
  particles come from the sky rather than only the player's body.

  COLOR PALETTE:
    Primary        : Color3.fromRGB(210, 220, 235)   -- pale silver
    Accent         : Color3.fromRGB(220, 230, 245)   -- cool white
    Flash          : Color3.fromRGB(220, 230, 240)
    Text           : Color3.fromRGB(220, 230, 245)

  SCREEN FLASH:
    Flash 1 (t=0.00s): Color = flash, duration = 0.55s, peak transp. = 0.65

  CONFETTI SHOWER (3 Attachments on root, staggered heights):
    Positions      : (x=-1.2, y=4.8, z=0), (x=0, y=5.6, z=0), (x=1.2, y=6.4, z=0)
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(primary)
    Emit count     : 90 * lodBurstMul() each (270 total)
    Lifetime       : NumberRange.new(0.6, 1.2)
    Speed          : NumberRange.new(10, 22)
    EmissionDir    : Enum.NormalId.Bottom
    SpreadAngle    : Vector2.new(40, 40)
    Size           : NumberSequence.new(0.25, 0.9)
    Acceleration   : Vector3.new(0, -25, 0)

  SCREEN PARTICLES (camera-attached, world-space feel):
    Color          : ColorSequence.new(Color3.fromRGB(200, 215, 230))
    Emit count     : 160 * lodBurstMul()
    Speed          : NumberRange.new(4, 18)
    SpreadAngle    : Vector2.new(180, 180)

  CAMERA: No shake. No FOV punch.

  SOUND:
    t=0.0s : "rebirth_confetti"

  BANNER:
    Text           : "ELITE!"
    TextSize       : 80
    TextColor3     : Color3.fromRGB(220, 230, 245)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER 3 — MASTER (25 Rebirths) — Gold Crown Identity
────────────────────────────────────────────────────────────────────────────────
  Full gold eruption. The first tier with camera shake. A crown ring of
  golden beam spokes radiates outward from the player — distinguishing this
  from the simple bronze burst of Veteran.

  COLOR PALETTE:
    Primary        : Color3.fromRGB(255, 220, 80)    -- bright gold
    Accent         : Color3.fromRGB(255, 200, 60)    -- deep gold
    Deep           : Color3.fromRGB(255, 170, 40)    -- amber shadow
    Flash 1        : Color3.new(1, 1, 1)             -- white primer
    Flash 2        : Color3.fromRGB(255, 200, 60)
    Flash 3        : Color3.fromRGB(255, 170, 40)
    Text           : Color3.fromRGB(255, 220, 100)

  SCREEN FLASHES (triple cascade — white primers the eye, then gold fills):
    Flash 1 (t=0.00s): Color = white,     duration = 0.45s, peak transp. = 0.20
    Flash 2 (t=0.08s): Color = accent,    duration = 0.65s, peak transp. = 0.55
    Flash 3 (t=0.18s): Color = deep,      duration = 0.55s, peak transp. = 0.62

  PARTICLE BURST:
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(primary)
    Emit count     : 220 * lodBurstMul()
    Lifetime       : NumberRange.new(0.4, 0.95)
    Speed          : NumberRange.new(18, 42)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.5, 2.0)
    LightEmission  : 0.75

  UNIQUE — Crown beam ring (suggested addition):
    (Currently not implemented. Would add 6 short golden beams radiating
    outward from head height to visually echo the "crown" motif.)
    Beam count     : 6
    Origin         : root + Vector3.new(0, 3.5, 0) (above head)
    Length          : 3.5 studs
    Width0         : 0.25
    Width1         : 0.04
    Color          : ColorSequence.new(primary)
    Transparency   : NumberSequence.new(0.15, 1)
    FaceCamera     : true
    Duration       : 0.7s then destroy

  SCREEN PARTICLES:
    Color          : ColorSequence.new(Color3.fromRGB(255, 210, 70))
    Emit count     : 200 * lodBurstMul()
    Speed          : NumberRange.new(8, 28)

  CAMERA:
    Shake          : intensity 0.50, duration 0.45s

  SOUND:
    t=0.0s : "rebirth_boom"

  BANNER:
    Text           : "MASTER!"
    TextSize       : 80
    TextColor3     : Color3.fromRGB(255, 220, 100)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER 4 — LEGEND (50 Rebirths) — Diamond / Cyan Identity
────────────────────────────────────────────────────────────────────────────────
  Icy diamond palette. The first tier with a FOV punch. Vertical diamond
  beams pierce downward from above — a "chosen by the heavens" moment.
  Two-tone particles mix cyan and white for a crystalline feel.

  COLOR PALETTE:
    Primary        : Color3.fromRGB(200, 255, 255)   -- ice white
    Accent         : Color3.fromRGB(120, 220, 255)   -- cyan
    Warm           : Color3.fromRGB(180, 230, 255)   -- frosty blue
    Flash 1        : Color3.fromRGB(200, 250, 255)
    Flash 2        : Color3.fromRGB(120, 220, 255)
    Text           : Color3.fromRGB(200, 250, 255)

  SCREEN FLASHES:
    Flash 1 (t=0.00s): Color = flash1, duration = 0.50s, peak transp. = 0.18
    Flash 2 (t=0.10s): Color = flash2, duration = 0.60s, peak transp. = 0.58

  PARTICLE BURST (primary — crystalline scatter):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0,   primary),
                       ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                       ColorSequenceKeypoint.new(1,   warm),
                     })
    Emit count     : 260 * lodBurstMul()
    Lifetime       : NumberRange.new(0.45, 1.0)
    Speed          : NumberRange.new(14, 38)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.45, 2.2)
    LightEmission  : 0.85

  UNIQUE — Diamond beams from sky (suggested addition):
    (4 vertical beams descending from high above the player, fading after
    the initial burst. These don't exist in current code.)
    Beam count     : 4
    Attachment0    : root + Vector3.new(offset.x, 20, offset.z)
    Attachment1    : root + Vector3.new(offset.x, -1, offset.z)
    Offsets        : (1.5, 0), (-1.5, 0), (0, 1.5), (0, -1.5)
    Width0         : 0.5
    Width1         : 0.15
    Color          : ColorSequence.new(accent)
    Transparency   : fade in over 0.2s, hold 0.4s, fade out over 0.6s
    FaceCamera     : true
    LightInfluence : 0

  SCREEN PARTICLES (two layers for crystalline depth):
    Layer 1: ColorSequence.new(warm),    emit 320, speed 10-32
    Layer 2: ColorSequence.new(white),   emit 280, speed  6-24

  CAMERA:
    Shake          : intensity 0.65, duration 0.55s
    FOV punch      : +4, tween back over 0.3s (Quad Out)

  SOUND:
    t=0.0s : "rebirth_boom"

  BANNER:
    Text           : "LEGEND!"
    TextSize       : 88
    TextColor3     : Color3.fromRGB(200, 250, 255)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TIER 5 — IMMORTAL (100 Rebirths) — Rainbow Reality-Tear Identity
────────────────────────────────────────────────────────────────────────────────
  The ultimate ceremony. Rainbow particles, a reality-crack overlay,
  two-layer sound (riser then boom), maximum camera shake, and a FOV
  punch. This is the only tier that uses mythicRainbowSequence() and
  the only one that gets a persistent overlay effect.

  COLOR PALETTE:
    Primary        : mythicRainbowSequence()
    Flash 1        : Color3.new(1, 1, 1)             -- white primer
    Flash 2        : Color3.fromRGB(255, 100, 200)   -- hot pink
    Flash 3        : Color3.fromRGB(100, 200, 255)   -- electric blue
    Text           : Color3.fromRGB(255, 245, 255)

  SCREEN FLASHES (triple stagger — white → pink → blue):
    Flash 1 (t=0.00s): Color = white,    duration = 0.55s, peak transp. = 0.12
    Flash 2 (t=0.10s): Color = hot pink, duration = 0.50s, peak transp. = 0.50
    Flash 3 (t=0.20s): Color = elec.blue,duration = 0.55s, peak transp. = 0.52

  PARTICLE BURST (rainbow explosion):
    Texture        : sparkles_main.dds
    Color          : mythicRainbowSequence()
    Emit count     : 340 * lodBurstMul()
    Lifetime       : NumberRange.new(0.5, 1.2)
    Speed          : NumberRange.new(14, 45)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.5, 2.4)
    LightEmission  : 0.9
    Drag           : 0.3

  SMOKE WISPS (secondary layer for depth):
    Texture        : smoke_main.dds
    Color          : mythicRainbowSequence()
    Emit count     : 60 * lodBurstMul()
    Lifetime       : NumberRange.new(0.7, 1.5)
    Speed          : NumberRange.new(6, 18)
    SpreadAngle    : Vector2.new(60, 60)
    Size           : NumberSequence.new(0.4, 1.8)
    RotSpeed       : NumberRange.new(-80, 80)

  SCREEN PARTICLES (camera-attached rainbow rain):
    Color          : mythicRainbowSequence()
    Emit count     : 420 * lodBurstMul()
    Speed          : NumberRange.new(12, 36)
    SpreadAngle    : Vector2.new(200, 200)

  UNIQUE — Universe crack overlay:
    (Already implemented. Full-screen Frame with rainbow UIGradient that
    rotates 35°→125° and fades out over 2.2s.)
    Frame:
      BackgroundTransparency : 0.6
      BackgroundColor3       : Color3.fromRGB(10, 20, 40)
      ZIndex                 : CELEBRATION_Z + 2
    UIGradient:
      Color                  : mythicRainbowSequence()
      Rotation               : 35 → 125 over 0.6s (Linear)
    Fade                     : BackgroundTransparency → 1 over 2.2s (Quad Out)
    Destroy                  : t=2.35s

  UNIQUE — Distortion lines (suggested addition):
    (4-6 thin horizontal Frame strips that slide across the screen during the
    flash, evoking a "reality glitch" feel — same approach as the Mythic pet
    entrance reality-tear phase.)
    Strip count    : math.random(4, 6)
    Height         : 2-6px each (random)
    Width          : UDim2.fromScale(1, 0)
    Color          : Color3.new(1, 1, 1)
    Transparency   : 0.3
    Y positions    : random between 0.15 and 0.85
    Slide anim     : X from -0.5 to 1.5 over 0.12s each, staggered by 0.03s
    Destroy        : 0.3s after start

  CAMERA:
    Shake          : intensity 0.85, duration 0.75s
    FOV punch      : +8, tween back over 0.45s (Quad Out)

  SOUND (two-layer build-up):
    t=0.00s : "rebirth_riser"   (ascending synth sweep, builds tension)
    t=0.15s : "rebirth_boom"    (bass impact releases the tension)

  BANNER:
    Text           : "IMMORTAL!"
    TextSize       : 96
    TextColor3     : Color3.fromRGB(255, 245, 255)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PRESTIGE AURA TIER COLORS (for reference — implemented in PrestigeAura.local.luau)
────────────────────────────────────────────────────────────────────────────────
  These are the persistent world-space glows applied to all players based on
  their rebirth milestone band. Included here so the ceremony palette and the
  persistent aura palette stay harmonized.

  | Tier | Key       | Aura Color                           | PointLight Range | Mote Rate |
  |------|-----------|--------------------------------------|------------------|-----------|
  | 1    | veteran   | Color3.fromRGB(180, 110, 60)  bronze | 11.2             | 2/s       |
  | 2    | elite     | Color3.fromRGB(200, 210, 225) silver | 13.4             | 2/s       |
  | 3    | master    | Color3.fromRGB(255, 210, 90)  gold   | 15.6             | 3/s       |
  | 4    | legend    | Color3.fromRGB(190, 245, 255) cyan   | 17.8             | 3/s       |
  | 5    | immortal  | Color3.fromRGB(255, 120, 220) pink   | 20.0             | 5/s       |
]]


--[[
================================================================================
  SECTION B — HATCH RARITY CRACK SEQUENCE
================================================================================
  Currently VFXController.hatchReveal uses a single animation for all rarities:
    1. Egg UI frame wobbles (0–2s)
    2. Color shifts to rarity color (2s)
    3. Frame fades/rotates away, emitBurst fires (3s)
    4. Per-rarity sound + screen flash

  Problem: The wobble/crack feels identical for Common and Mythic until the
  burst fires. Players should know something special is coming BEFORE the
  reveal — the crack itself should telegraph rarity.

  Design principle: Higher-rarity eggs take LONGER to crack (building
  anticipation) and the crack VISUAL differs. Common is a quick pop;
  Mythic is a slow, dramatic, reality-warping shatter.

  All timings are offsets from t=0 (when hatchReveal is called).
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  COMMON — Quick Pop
────────────────────────────────────────────────────────────────────────────────
  Minimal anticipation. The egg is just a vessel — players shouldn't dwell
  on common hatches. Fast in, fast out.

  WOBBLE PHASE (0–1.0s):
    Duration       : 1.0s (shortened from current 2.0s)
    Frequency      : 2Hz (math.pi * 2 / 0.5 unchanged)
    Max amplitude  : 3° (reduced from 4°)
    Ramp           : linear (t / 1.0)

  EGG SHELL COLOR:
    Start          : Color3.fromRGB(240, 230, 210)  (neutral eggshell)
    No color shift before crack.

  CRACK LINES: None. Simple fade-out.

  BREAK (t=1.0s):
    Egg frame tweens: BackgroundTransparency 0.1 → 1, Rotation 0 → 5 over 0.25s
    Vignette release: fade to transparent over 0.3s

  DUST AT FEET:
    Rate           : 4 (LOD1) / 12 (LOD2+)
    Duration       : 1.0s (shortened from 2.0s)

  BURST (t=1.0s):
    Uses BURST_TABLE.common (20 core, 0 stars, 0 beams)

  SCREEN FLASH:
    Color          : rarity color
    Duration       : 0.18s
    Peak transp.   : 0.55

  SOUND: "hatch_common"

  TOTAL DURATION: ~1.5s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNCOMMON — Gentle Crack with Color Leak
────────────────────────────────────────────────────────────────────────────────
  Slightly more ceremony. A single crack line appears on the egg and green
  light leaks through before the shell breaks.

  WOBBLE PHASE (0–1.4s):
    Duration       : 1.4s
    Frequency      : 2.5Hz
    Max amplitude  : 4°
    Ramp           : linear

  EGG SHELL:
    Start          : Color3.fromRGB(240, 230, 210)
    At t=0.8s      : UIStroke appears (thickness 2, Color3.fromRGB(80, 200, 80))
                     simulating a single crack line

  CRACK LINE (t=0.8s):
    Implementation : A thin Frame child inside egg frame
    Size           : UDim2.new(0, 2, 0.7, 0)
    Position       : UDim2.new(0.55, 0, 0.15, 0)
    Rotation       : -15°
    Color          : Color3.fromRGB(80, 200, 80)
    BackgroundTransparency: tween 0.8 → 0.2 over 0.4s (light leaking through)

  COLOR SHIFT (t=1.0s):
    Egg BackgroundColor3 tween to rarity color over 0.3s

  BREAK (t=1.4s):
    Egg frame tweens: Scale × 1.15 over 0.08s, then Transparency → 1 over 0.2s
    Crack line follows parent destruction

  DUST AT FEET:
    Rate           : 5 (LOD1) / 14 (LOD2+)
    Duration       : 1.4s

  BURST (t=1.4s):
    Uses BURST_TABLE.uncommon (30 core, 10 stars, 0 beams)

  SCREEN FLASH:
    Color          : rarity color
    Duration       : 0.18s
    Peak transp.   : 0.55

  SOUND: "hatch_uncommon"

  TOTAL DURATION: ~2.0s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  RARE — Spreading Cracks with Blue Spark Flickers
────────────────────────────────────────────────────────────────────────────────
  Multiple crack lines spread across the egg. Small blue sparks flicker at
  crack intersections. Players start feeling the dopamine ramp here.

  WOBBLE PHASE (0–1.8s):
    Duration       : 1.8s
    Frequency      : 3Hz (faster rocking = more tension)
    Max amplitude  : 5°
    Ramp           : quadratic (t^1.3 / 1.8) — accelerating intensity

  EGG SHELL:
    Start          : Color3.fromRGB(240, 230, 210)

  CRACK LINES (t=0.8s → t=1.5s, staggered):
    3 crack line Frames spawn inside egg at staggered times:
      Crack 1 (t=0.8s): Size(2px, 55%), Position(0.45, 0.1), Rotation -12°
      Crack 2 (t=1.1s): Size(2px, 40%), Position(0.60, 0.3), Rotation 25°
      Crack 3 (t=1.4s): Size(2px, 50%), Position(0.35, 0.2), Rotation -35°
    Color          : Color3.fromRGB(60, 130, 255) (rare blue)
    Each fades Transparency from 0.7 → 0.15 over 0.3s

  SPARK FLICKERS (t=1.0s → t=1.8s):
    Small screen-space sparkle frames (4–6) appear near crack tips:
    Size           : 4–8px squares
    Color          : Color3.fromRGB(120, 180, 255)
    Animation      : scale 0 → 1 → 0 over 0.12s, staggered every 0.15s
    Positions      : jittered around crack endpoints

  COLOR SHIFT (t=1.3s):
    Egg BackgroundColor3 tween to rarity color over 0.4s
    UIStroke appears: thickness 3, Color rare blue, transparency 0.3

  BREAK (t=1.8s):
    Egg frame: Scale × 1.2 over 0.06s, then Transparency → 1 + Rotation 8° over 0.25s
    Crack lines: fade out with parent

  ANTICIPATION SOUND:
    t=0.8s: "egg_crack_small" (subtle crack sfx, ~0.2s, played once)

  DUST AT FEET:
    Rate           : 6 (LOD1) / 16 (LOD2+)
    Duration       : 1.8s
    Color          : tinted toward rarity blue

  BURST (t=1.8s):
    Uses BURST_TABLE.rare (50 core, 20 stars, 4 beams)

  SCREEN FLASH:
    Color          : rarity color
    Duration       : 0.18s
    Peak transp.   : 0.55

  SOUND: "hatch_rare"

  TOTAL DURATION: ~2.5s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  EPIC — Dramatic Fracture Web + Purple Glow Pulse
────────────────────────────────────────────────────────────────────────────────
  The egg develops a full fracture web. Purple energy pulses through the
  cracks. The screen darkens with a vignette before the break. Camera zooms
  in slightly on the egg frame.

  WOBBLE PHASE (0–2.2s):
    Duration       : 2.2s
    Frequency      : 3.5Hz
    Max amplitude  : 6°
    Ramp           : cubic (t^1.6 / 2.2) — builds dramatically

  EGG SHELL:
    Start          : Color3.fromRGB(240, 230, 210)
    Size growth    : egg frame tweens from 140×180 to 155×195 over 2.2s (swelling)

  CRACK WEB (t=0.6s → t=2.0s):
    5–7 crack lines, spawning every 0.2s, radiating from a center point:
    Colors         : Color3.fromRGB(180, 60, 255) (epic purple)
    Thickness      : 2–3px
    Lengths        : 30–70% of egg height
    Rotations      : -40° to 40° range, distributed evenly
    Glow pulse     : each crack line's transparency oscillates
                     0.4 → 0.1 → 0.4 at 2Hz via a RenderStepped connection
                     (creates a "breathing" energy feel)

  PURPLE GLOW PULSE (t=1.2s):
    Egg frame UIGradient:
      Color          : ColorSequence.new({
                         ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 230, 210)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 60, 255)),
                         ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 230, 210)),
                       })
      Offset         : animate Vector2.new(0, -0.5) → (0, 0.5) over 0.8s, repeat
    (Creates an internal glow sweeping through the egg shell)

  VIGNETTE DARKEN (t=1.0s):
    BackgroundTransparency: 0.92 → 0.78 over 1.0s (darker than default)

  ANTICIPATION SOUND:
    t=0.6s : "egg_crack_small"
    t=1.4s : "egg_crack_medium" (louder, more pronounced crack, ~0.3s)

  BREAK (t=2.2s):
    Egg frame: Scale × 1.3 over 0.05s → explode outward
    "Shell shard" simulation: 4 small Frames (shell fragments) fly outward:
      Size         : 20–35px squares
      Color        : egg shell color
      Rotation     : random 0–360°
      Position     : tween to corners of screen over 0.3s
      Transparency : 0 → 1 over 0.3s

  DUST AT FEET:
    Rate           : 8 (LOD1) / 20 (LOD2+)
    Duration       : 2.2s
    Additional sparkle emitter: Rate 6, rarity color

  BURST (t=2.2s):
    Uses BURST_TABLE.epic (80 core, 30 stars, 20 wisps, 6 beams)

  SCREEN FLASH:
    Color          : rarity color
    Duration       : 0.18s
    Peak transp.   : 0.55

  CAMERA:
    Shake          : intensity 0.35, duration 0.2s (at break moment)

  SOUND: "hatch_epic"

  TOTAL DURATION: ~3.0s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  LEGENDARY — Slow-Burn Golden Eruption
────────────────────────────────────────────────────────────────────────────────
  Extended build-up. The egg glows golden from within, cracks spiderweb with
  golden light rays shooting through each crack. A brief slow-motion hitstop
  freezes the world before the explosive reveal.

  WOBBLE PHASE (0–2.8s):
    Duration       : 2.8s
    Frequency      : starts 2Hz, accelerates to 5Hz over duration
    Max amplitude  : starts 3°, accelerates to 8°
    Ramp           : exponential (e^(t*1.5) scaled) — slow start, frantic finish
    Implementation : frequency = 2 + 3 * (t/2.8)^2
                     amplitude = 3 + 5 * (t/2.8)^2

  EGG SHELL:
    Start          : Color3.fromRGB(240, 230, 210)
    Size growth    : 140×180 → 170×215 over 2.8s
    At t=2.0s      : BackgroundColor3 tween to Color3.fromRGB(255, 230, 160) (golden)

  GOLDEN CRACK WEB (t=0.8s → t=2.5s):
    8–10 crack lines, spawning every 0.2s:
    Color          : Color3.fromRGB(255, 200, 50) (legendary gold)
    Thickness      : 2–4px
    Glow pulse     : 3Hz oscillation (faster than epic)

  LIGHT RAY LEAKS (t=1.5s):
    4 thin beam-like Frames extend outward from crack tips past the egg edge:
    Size           : 3px × 60–100px
    Color          : Color3.fromRGB(255, 240, 160)
    Transparency   : 0.3
    Rotation       : aligned with crack angles
    Animation      : length grows from 0 to full over 0.5s, pulses at 2Hz

  VIGNETTE DARKEN:
    t=0s   : 0.92 → 0.75 over 1.5s
    t=2.5s : pulse to 0.65 briefly (dramatic darken before break)

  HITSTOP (t=2.5s):
    Duration       : 0.25s
    Egg freezes mid-wobble at maximum amplitude
    Screen holds — no interpolation for 0.25s
    Subtle desaturation pulse (vignette darkens further)

  ANTICIPATION SOUNDS:
    t=0.8s : "egg_crack_small"
    t=1.5s : "egg_crack_medium"
    t=2.3s : "egg_crack_large" (deep resonant crack, ~0.4s)

  BREAK (t=2.8s):
    Golden explosion: egg frame scales × 1.5 in 0.03s, then shatters
    Shell shard Frames: 6 fragments fly outward with golden trails
    Each shard has a child Frame (2px, gold) trailing behind it

  DUST AT FEET:
    Rate           : 10 (LOD1) / 25 (LOD2+)
    Duration       : 2.8s
    Golden sparkle emitter: Rate 10, Color gold

  BURST (t=2.8s):
    Uses BURST_TABLE.legendary (120 core, 50 stars, 16 bolts, 24 confetti, 8 beams)

  SCREEN FLASH:
    Flash 1 (t=2.8s) : Color rarity, duration 0.18s, peak transp. 0.55

  CAMERA:
    Shake          : intensity 0.35, duration 0.2s
    FOV punch      : +4, tween back 0.25s

  SOUND: "hatch_legendary"

  TOTAL DURATION: ~3.8s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  MYTHIC — Reality Shatter + Full-Screen Takeover
────────────────────────────────────────────────────────────────────────────────
  The most dramatic hatch in the game. The egg doesn't just crack — reality
  itself fractures around it. Full-screen darkening, distortion glitch lines,
  an extended slow-motion freeze, and a rainbow shockwave on break.

  WOBBLE PHASE (0–3.5s):
    Duration       : 3.5s
    Frequency      : starts 1.5Hz, accelerates to 7Hz
    Max amplitude  : starts 2°, accelerates to 10°
    Ramp           : exponential (steeper than legendary)
    Implementation : frequency = 1.5 + 5.5 * (t/3.5)^2.5
                     amplitude = 2 + 8 * (t/3.5)^2.5
    At t=2.5s+     : egg starts subtly "jittering" (add random ±1px position noise)

  EGG SHELL:
    Start          : Color3.fromRGB(240, 230, 210)
    Size growth    : 140×180 → 185×235 over 3.5s (largest swell)
    At t=1.5s      : faint rainbow UIGradient appears (transparency 0.7)
    At t=2.5s      : UIGradient intensifies (transparency 0.3), rotation animates

  REALITY CRACK WEB (t=0.5s → t=3.0s):
    10–14 crack lines, each with rainbow-cycling color:
    Color          : animate hue via per-frame update, stagger phase per crack
    Thickness      : 2–5px (thicker than all other rarities)
    Pulse frequency: 4Hz
    At t=2.0s      : cracks start "bleeding" — small smoke wisps (2px Frames)
                     drift away from crack tips, 1–2 per crack

  DISTORTION GLITCH LINES (t=2.0s → t=3.0s):
    (Same technique as the Immortal rebirth and Mythic pet entrance)
    4–6 horizontal Frame strips across the full screen (outside the egg):
    Height         : 2–6px each
    Color          : Color3.new(1, 1, 1)
    Transparency   : 0.4
    Animation      : slide X from -0.5 to 1.5 over 0.12s, staggered
    Loop           : repeat 2–3 times across the 1s window

  FULL-SCREEN DARKEN (t=1.0s):
    Overlay Frame  : BackgroundColor3 = Color3.new(0, 0, 0)
    Transparency   : 1 → 0.55 over 1.5s (very heavy darken, world nearly gone)
    ZIndex         : 38 (below egg frame at 40)
    Purpose        : isolates the egg as the sole focus

  HITSTOP (t=3.0s):
    Duration       : 0.5s (double legendary's)
    Egg freezes at peak wobble
    Sound: sub-bass hum loops during freeze ("egg_mythic_hum")
    Screen desaturates slightly (overlay at 0.15 opacity, gray)

  LIGHT BEAM ERUPTION (t=2.5s):
    6–8 light ray Frames radiate outward from egg center past screen edges:
    Length         : from egg center to screen corner (~800px)
    Width          : 3–5px
    Color          : mythicRainbowSequence keypoints, one per ray
    Transparency   : 0.5 → 0.2 → 0.5 over 0.8s (pulse during freeze)
    Rotation       : evenly distributed (0°, 45°, 90°, 135°, etc.)

  ANTICIPATION SOUNDS:
    t=0.5s : "egg_crack_small"
    t=1.5s : "egg_crack_medium"
    t=2.2s : "egg_crack_large"
    t=2.8s : "egg_mythic_resonance" (deep otherworldly tone, ~0.5s)

  BREAK (t=3.5s):
    Two-phase explosion:
      Phase A (t=3.5s): White screen flash (0.2s, peak transp. 0.12)
                         Egg frame INSTANTLY disappears (no tween)
      Phase B (t=3.55s): Rainbow screen flash (0.4s, peak transp. 0.25)
                          "Shockwave ring" — expanding circle Frame:
                            Size: 0px → 400px over 0.3s (Quad Out)
                            Border: UIStroke 4px, mythicRainbowSequence color
                            BackgroundTransparency: 1 (just the ring)
                            Fades out during expansion
                          8 shell shard Frames fly outward with rainbow trails
                          Full-screen darken overlay fades back to 1 over 0.5s

  SCREEN-EDGE RAINBOW BORDER (t=3.5s → t=6.0s):
    (Same technique as mythic pet entrance)
    UIStroke on full-screen Frame:
    Thickness      : 6
    Color gradient : mythicRainbowSequence()
    Rotation anim  : 120°/s for 2.5s
    Transparency   : 0.15 → 1 over 2.5s

  DUST AT FEET:
    Rate           : 12 (LOD1) / 30 (LOD2+)
    Duration       : 3.5s
    Rainbow sparkle emitter: Rate 14, mythicRainbowSequence color

  BURST (t=3.5s):
    Uses BURST_TABLE.mythic (200 core, 80 stars, 40 wisps, 24 bolts, 40 confetti)

  SCREEN FLASH:
    Flash 1 (t=3.50s): Color white,   duration 0.20s, peak transp. 0.12
    Flash 2 (t=3.55s): Color rainbow, duration 0.40s, peak transp. 0.25

  CAMERA:
    Shake          : intensity 0.50, duration 0.35s
    FOV punch      : +8, tween back 0.35s

  SOUND: "hatch_mythic"

  TOTAL DURATION: ~5.0s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  HATCH CRACK SEQUENCE — COMPARISON TABLE
────────────────────────────────────────────────────────────────────────────────

  | Property              | COMMON    | UNCOMMON  | RARE      | EPIC      | LEGENDARY | MYTHIC     |
  |-----------------------|-----------|-----------|-----------|-----------|-----------|------------|
  | Total Duration        | ~1.5s     | ~2.0s     | ~2.5s     | ~3.0s     | ~3.8s     | ~5.0s      |
  | Wobble Duration       | 1.0s      | 1.4s      | 1.8s      | 2.2s      | 2.8s      | 3.5s       |
  | Wobble Max Amplitude  | 3°        | 4°        | 5°        | 6°        | 8°        | 10°        |
  | Wobble Frequency      | 2Hz       | 2.5Hz     | 3Hz       | 3.5Hz     | 2→5Hz     | 1.5→7Hz    |
  | Crack Lines           | 0         | 1         | 3         | 5-7       | 8-10      | 10-14      |
  | Crack Color           | —         | green     | blue      | purple    | gold      | rainbow    |
  | Glow Pulse            | no        | no        | no        | yes (2Hz) | yes (3Hz) | yes (4Hz)  |
  | Light Rays            | no        | no        | no        | no        | yes (4)   | yes (6-8)  |
  | Shell Shards on Break | 0         | 0         | 0         | 4         | 6         | 8          |
  | Hitstop               | no        | no        | no        | no        | 0.25s     | 0.50s      |
  | Screen Darken         | default   | default   | default   | 0.78      | 0.65      | 0.55       |
  | Distortion Lines      | no        | no        | no        | no        | no        | yes        |
  | Egg Size Growth       | none      | none      | none      | +10%      | +20%      | +32%       |
  | Camera Shake at Break | no        | no        | no        | 0.35/0.2s | 0.35/0.2s | 0.50/0.35s |
  | FOV Punch             | no        | no        | no        | no        | +4        | +8         |
  | Sound Layers          | 1         | 1         | 1+crack   | 1+2crack  | 1+3crack  | 1+4crack   |

  NEW SOUND CUES NEEDED:
    egg_crack_small    — subtle hairline crack (0.2s, high-pitched snap)
    egg_crack_medium   — multiple cracks spreading (0.3s, crackle)
    egg_crack_large    — deep resonant fracture (0.4s, bass crack)
    egg_mythic_hum     — loopable sub-bass resonance (0.5s loop, for hitstop)
    egg_mythic_resonance — otherworldly deep tone (0.5s, one-shot)
]]


--[[
================================================================================
  SECTION C — PetEntranceDesignSpec.luau REVIEW
================================================================================
  Review of DACStarterGui/PetEntranceDesignSpec.luau for completeness and
  alignment with VFXController.petEquipEntrance implementation.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  OVERALL ASSESSMENT: The spec is thorough and well-structured.
────────────────────────────────────────────────────────────────────────────────

  RARITY-APPROPRIATE ENTRANCE SCALE:
    ✓ Common (8 particles, simple pop) → Mythic (175 particles, reality tear)
    ✓ Clear escalation: more particles, longer duration, more visual layers
    ✓ Camera shake only appears at Rare (mild) and escalates to Mythic
    ✓ Screen flash only at Epic+
    ✓ FOV punch only at Legendary+
    ✓ Slow-motion hitstop only at Mythic
    VERDICT: Scale progression is excellent.

  SOUND TIMING ALIGNMENT WITH VISUAL KEYFRAMES:
    ✓ Common: single sound at instant of pop-in
    ✓ Uncommon: whoosh during slide, no layering needed
    ✓ Rare: crackle during spiral + impact at landing — timing is clear
    ✓ Epic: single sound at vortex start — plays across the full 0.8s descent
    ✓ Legendary: two sounds — beam at t=0, impact at t=0.9s. Beam sustains
      through descent so the impact lands exactly when the pet does.
    ✓ Mythic: three sounds — tear at t=0, explosion at t=0.5, hatch_mythic
      at t=0.7s for familiarity layering.
    VERDICT: Sound timing is well-specified with clear trigger points.

  ALIGNMENT WITH VFXController.petEquipEntrance:
    The implementation closely follows the spec for Common and Uncommon.
    Rare/Epic/Legendary/Mythic implementations should be verified against
    spec parameters (spiral radii, beam counts, particle counts).

  IDENTIFIED GAPS / SUGGESTIONS:

  1. MISSING SUMMARY TABLE:
     The spec would benefit from a side-by-side comparison table (like the
     one in Section A above) showing all rarities' key parameters at a glance.
     Without it, engineers must read each rarity block to compare values.

  2. UNCOMMON SPEC — LANDING BURST PARTICLE SIZE:
     The spec defines the landing burst color and count but doesn't specify
     Size or LightEmission for the burst. These should match the trail
     properties or be explicitly stated.
     Suggested: Size = NumberSequence.new(0.1, 0.35), LightEmission = 0.6

  3. CONFETTI PARAMETERS:
     The EntranceSpec type includes confettiCount but only Legendary (28) and
     Mythic (45) use it. This is correct but not explicitly documented in the
     Common-Epic blocks. Adding "Confetti: none" to those blocks would make
     the intent clearer.

  4. CAMERA SHAKE FUNCTION SIGNATURE:
     The spec references "camera shake" but doesn't specify whether to use the
     existing cameraShake(intensity, duration) utility or a separate system.
     The VFXController already has cameraShake() — spec should reference it.

  5. HITSTOP IMPLEMENTATION DETAIL:
     The Mythic spec mentions "0.5s slow-motion hitstop" and "Camera: freeze
     CFrame for 0.5s (override RenderStepped)" but doesn't specify how this
     interacts with DrivingController if a run is active. During a run, the
     chase camera is driven by DrivingController — freezing CFrame would need
     coordination. Suggest: if runActive, skip CFrame freeze and only apply
     visual time-dilation effects (particle slowdown, frame hold).

  6. SCREEN-EDGE RAINBOW BORDER CLEANUP:
     Mythic aura spec says "Destroy after: 3s" for the rainbow border, but the
     entrance spec says "rotation for 2.5s, transparency fade over 2.5s". The
     destroy timing should be 2.5s + a small buffer (e.g. 2.7s), not 3.0s.
     Minor inconsistency.

  NONE OF THESE GAPS ARE BLOCKING. The spec is implementation-ready.
]]


--[[
================================================================================
  SUGGESTED ENTRANCE COMPARISON TABLE (for inclusion in PetEntranceDesignSpec)
================================================================================

  | Property              | COMMON   | UNCOMMON | RARE     | EPIC     | LEGENDARY | MYTHIC     |
  |-----------------------|----------|----------|----------|----------|-----------|------------|
  | Anticipation          | none     | none     | none     | 0.3s     | 0.5s      | 0.5s       |
  | Motion Style          | pop-in   | slide    | spiral   | vortex   | beam drop | reality    |
  | Motion Duration       | 0.2s     | 0.35s    | 0.6s     | 0.8s     | 0.9s      | 1.0s+      |
  | Burst Particles       | 8        | 14       | 24       | 47       | 94        | 175        |
  | Trail Rate            | —        | 35/s     | 28/s     | 40+18/s  | 25/s beam | 8+18+20/s  |
  | Beam Count            | 0        | 0        | 4        | 6        | 8         | 0 (beams   |
  |                       |          |          |          |          |           |  as wisps) |
  | Screen Flash          | no       | no       | no       | yes      | yes       | yes (×2)   |
  | Camera Shake          | no       | no       | 0.08     | 0.18     | 0.35      | 0.50       |
  | FOV Punch             | no       | no       | no       | no       | +6        | +12        |
  | Hitstop               | no       | no       | no       | no       | no        | 0.5s       |
  | Confetti              | no       | no       | no       | no       | 28        | 45         |
  | Screen Distortion     | no       | no       | no       | no       | no        | yes        |
  | Sound Count           | 1        | 1        | 1        | 1        | 2         | 3          |

================================================================================
]]

return nil
