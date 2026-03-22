--!strict
--[[
	DRIVING VFX DESIGN SPEC — Speed Rush + Lap Flash + Near-Miss Spark + Ambient World Particles
	=============================================================================================
	This file defines exact visual parameters for four driving-feel VFX systems.
	All four are already partially implemented in VFXController.luau — this spec
	formalizes the intended design language, refines existing values, and adds
	missing visual layers for Phase 4 dopamine maximization.

	Reference files:
	  - DACReplicatedStorage/VFXFacade.luau (method signatures)
	  - DACStarterPlayerScripts/Controllers/VFXController.luau (implementations)
	  - DACStarterPlayerScripts/Controllers/DrivingController.luau (call sites)
	  - DACReplicatedStorage/Config/SpeedMilestoneConfig.luau (speed thresholds)
	  - DACReplicatedStorage/Config/NearMissCopyConfig.luau (popup copy)
	  - DACReplicatedStorage/Config/WorldUnlockConfig.luau (world IDs)

	Engineer implementation notes:
	  - All particle textures use engine-stock assets:
	      "rbxasset://textures/particles/sparkles_main.dds"
	      "rbxasset://textures/particles/smoke_main.dds"
	  - LOD multipliers apply: lodBurstMul() for Emit counts, lodTrailRateMul()
	    for Rate-based emitters. LOD 1 disables many layers.
	  - Screen overlay Frames share the same ScreenGui as existing VFX layers.
	    ZIndex assignments:
	      993 = ambient underlays
	      994 = SpeedRushEdge (existing)
	      995 = SpeedRushChroma (existing)
	      996 = near-miss edge flash
	      999 = lap flash (existing)
	  - cameraShake(intensity, duration) is the existing utility in VFXController.
	  - SoundFacade.playOneShot(name) for all SFX triggers.
]]


--[[
================================================================================
  SECTION A — SPEED RUSH OVERLAY
================================================================================
  Triggered continuously via VFXFacade.speedRushOverlay(speed) every render
  frame when the player's current speed >= 70% of their car's max speed.
  DrivingController passes 0 when below threshold or when the run ends.

  Design goal: Make high-speed driving feel DANGEROUS and THRILLING. The screen
  should progressively tighten, darken, and vibrate — the player is pushing
  their car to the absolute limit. Three visual tiers ramp the intensity.

  CURRENT IMPLEMENTATION STATUS:
    ✓ SpeedRushEdge frame (orange vignette, ZIndex 994)
    ✓ SpeedRushChroma frame (cyan-top / magenta-bottom fringe, ZIndex 995)
    ✓ Smooth interpolation toward target intensity
    ✓ Pulse modulation (sin wave) for organic feel
    ✗ Missing: speed lines / streak layer
    ✗ Missing: screen shake at extreme speed
    ✗ Missing: tier-based color shift (orange → red → white-hot)
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — INTENSITY TIERS
────────────────────────────────────────────────────────────────────────────────
  Speed is normalized against the car's max speed (runMaxSpeedForRush).
  Three tiers define the visual ramp:

  | Property              | TIER 1 (70-84%)     | TIER 2 (85-94%)     | TIER 3 (95-100%)    |
  |-----------------------|---------------------|---------------------|---------------------|
  | Threshold             | speed >= 0.70 * max | speed >= 0.85 * max | speed >= 0.95 * max |
  | Edge Vignette Opacity | 0.08 → 0.25         | 0.25 → 0.42         | 0.42 → 0.55         |
  | Chroma Fringe Opacity | 0.00                | 0.05 → 0.22         | 0.22 → 0.42         |
  | Speed Lines           | none                | subtle (Rate 4/s)   | intense (Rate 12/s) |
  | Screen Shake          | none                | none                | micro (0.04, cont.)  |
  | Edge Color            | warm orange          | hot orange-red       | red → white-hot      |
  | Pulse Frequency       | 2.8 Hz base         | 4.0 Hz base          | 6.0 Hz base          |
  | Pulse Amplitude       | ±12%                | ±15%                | ±18%                |
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — EDGE VIGNETTE FRAME (SpeedRushEdge, ZIndex 994)
────────────────────────────────────────────────────────────────────────────────
  Full-screen Frame with radial UIGradient creating edge darkening / tinting.
  Already implemented — this section formalizes and refines the color ramp.

  Frame properties:
    Name               : "SpeedRushEdge"
    Size               : UDim2.fromScale(1, 1)
    ZIndex             : 994
    Active             : false
    BorderSizePixel    : 0

  UIGradient (horizontal, edges → center transparency):
    Rotation           : 0

  COLOR RAMP by normalized speed (t = speedPercent):
    t in [0.70, 0.84] — WARM ORANGE:
      ColorSequence    : {
        (0,    Color3.fromRGB(255, 140, 50)),
        (0.45, Color3.fromRGB(255, 160, 70)),
        (0.50, Color3.fromRGB(255, 255, 255)),
        (0.55, Color3.fromRGB(255, 160, 70)),
        (1,    Color3.fromRGB(255, 140, 50)),
      }

    t in [0.85, 0.94] — HOT ORANGE-RED:
      Lerp edge keypoints toward red:
        Edge color     : Color3.fromRGB(255, 80, 30)
        Mid color      : Color3.fromRGB(255, 120, 50)
      Implementation   : edgeColor = warmOrange:Lerp(hotRed, (t - 0.85) / 0.10)

    t in [0.95, 1.00] — RED → WHITE-HOT:
      Edge color       : Color3.fromRGB(255, 40, 20) → Color3.fromRGB(255, 200, 180)
      The "white-hot" feel at max speed — edges glow almost white with a
      red inner rim. Communicates "you are AT the limit."
      Implementation   : edgeColor = hotRed:Lerp(whiteHot, (t - 0.95) / 0.05)

  Transparency gradient (edge visibility ramp):
    Edge keypoints (0 and 1) transparency = 1 - edgeOpacity
    Center keypoints (0.45–0.55) = 1.0 (fully transparent center)
    edgeOpacity = math.clamp(mapped value from tier table above)

  Smoothing:
    Exponential lerp each frame: smoothed += (target - smoothed) * 0.15
    Prevents jarring snap when crossing tier boundaries.

  Pulse modulation:
    pulseFreq = 2.8 + speed * 0.035  (already implemented — keeps this)
    pulse = 0.88 + 0.12 * math.sin(os.clock() * pulseFreq)
    At Tier 3, widen amplitude:
    pulse = 0.82 + 0.18 * math.sin(os.clock() * pulseFreq)
    Final opacity = smoothed * pulse * maxOpacity
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — CHROMATIC FRINGE FRAME (SpeedRushChroma, ZIndex 995)
────────────────────────────────────────────────────────────────────────────────
  Simulates chromatic aberration via a vertical UIGradient: cyan on top,
  magenta on bottom, transparent center. Already implemented — refine opacity.

  Frame properties:
    Name               : "SpeedRushChroma"
    Size               : UDim2.fromScale(1, 1)
    ZIndex             : 995
    Active             : false

  UIGradient (vertical):
    Rotation           : 90
    ColorSequence      : {
      (0,    Color3.fromRGB( 80, 200, 255)),   -- cyan top
      (0.35, Color3.fromRGB(255, 255, 255)),   -- white center
      (0.65, Color3.fromRGB(255, 255, 255)),   -- white center
      (1,    Color3.fromRGB(255,  80, 160)),   -- magenta bottom
    }
    TransparencySequence: {
      (0,   0.35),   -- visible at edges
      (0.5, 1.0),    -- transparent center
      (1,   0.35),
    }

  Visibility:
    Tier 1: BackgroundTransparency = 1 (invisible — no chroma at casual speed)
    Tier 2: BackgroundTransparency = 1 - chromaOpacity * 0.42
    Tier 3: BackgroundTransparency = 1 - chromaOpacity * 0.42 (same formula,
            but chromaOpacity is higher — up to 0.42)

  Smoothing:
    chromaSmoothed += (targetChroma - chromaSmoothed) * 0.12

  Color shift at extreme speed (optional enhancement):
    At t >= 0.95, lerp top keypoint toward Color3.fromRGB(120, 255, 255) and
    bottom toward Color3.fromRGB(255, 40, 120) for a more saturated fringe.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — SPEED LINES (NEW — Suggested Addition)
────────────────────────────────────────────────────────────────────────────────
  Screen-space speed lines streaming inward from edges. Only at Tier 2+ and
  LOD tier >= 2. These are short-lived UI Frames animating from screen edge
  toward center, then fading.

  Implementation approach: Pool of 8–12 thin Frame strips. Each spawns at a
  random edge position, tweens toward center, and fades to transparent.

  Per-line properties:
    Size               : UDim2.new(0, math.random(60, 140), 0, 2)
    BackgroundColor3   : Color3.new(1, 1, 1) (pure white)
    BackgroundTransparency: 0.4 → 1 over lifetime
    Rotation           : angle toward screen center from spawn edge

  Spawn rate:
    Tier 2 (85-94%)    : 4 lines/s
    Tier 3 (95-100%)   : 12 lines/s

  Lifetime per line    : 0.15s – 0.25s

  Spawn regions (randomized per line):
    Left edge          : X = -0.02, Y = random(0.1, 0.9)
    Right edge         : X = 1.02,  Y = random(0.1, 0.9)
    Top edge           : X = random(0.1, 0.9), Y = -0.02
    Bottom edge        : X = random(0.1, 0.9), Y = 1.02

  Motion:
    Tween Position toward UDim2.fromScale(0.5, 0.5) at 60–80% of distance,
    then destroy. The line never reaches center — it streaks partway and
    dissolves, creating the illusion of convergence.

  LOD gating:
    LOD 1: disabled entirely
    LOD 2: max 4 lines, spawn rate halved
    LOD 3: full effect
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — MICRO SCREEN SHAKE (Tier 3 only)
────────────────────────────────────────────────────────────────────────────────
  At 95%+ speed, a continuous micro-shake simulates the car rattling at the
  edge of control. This is NOT the same as cameraShake() — it's a continuous
  per-frame camera offset, not a burst.

  Implementation:
    Each RenderStepped while Tier 3 is active:
      offset = Vector3.new(
        math.random() * 0.08 - 0.04,
        math.random() * 0.06 - 0.03,
        0
      ) * shakeIntensity

    shakeIntensity = math.clamp((t - 0.95) / 0.05, 0, 1) * 0.04
    Apply as CFrame offset to camera, removed when speed drops below 95%.

  At exactly 100% max speed:
    shakeIntensity = 0.04 (4 pixels of jitter at 1080p equivalent)
    This is subtle — just enough to feel the vibration, not enough to impair
    gameplay or readability.

  LOD gating: LOD 1 = disabled, LOD 2 = 0.6x intensity, LOD 3 = full
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED RUSH — SOUND DESIGN
────────────────────────────────────────────────────────────────────────────────
  No new one-shot SFX for speed rush — the engine loop in DrivingController
  already pitch-shifts with speed, providing audio feedback. The visual
  overlay supplements the existing audio.

  Optional future enhancement: a subtle wind whistle loop that fades in at
  Tier 2 and intensifies at Tier 3. Low priority — engine loop covers this.
    Candidate sound ID : "speed_wind_loop" (if added)
    Fade in at         : Tier 2, volume 0 → 0.15 over 0.5s
    Max volume         : 0.35 at Tier 3
    Pitch              : 0.8 → 1.4 mapped to speed
]]


--[[
================================================================================
  SECTION B — LAP FLASH
================================================================================
  Triggered via VFXFacade.lapFlash(isPersonalBest) when a lap is completed.
  DrivingController fires this when state.laps increments.

  Design goal: Every lap completion should feel like a VICTORY — the player
  just survived another circuit. Personal best laps get dramatically enhanced
  treatment that makes the player feel like a record-breaker.

  CURRENT IMPLEMENTATION STATUS:
    ✓ White → gold screen flash (0.08s in, 0.27s out)
    ✓ Vignette pulse
    ✓ Camera shake (0.12/0.2 for regular/PB)
    ✓ Downward particle streaks
    ✓ PB confetti (24 gold sparkles)
    ✗ Missing: radial burst shape (currently full-screen flat)
    ✗ Missing: PB text popup with glow
    ✗ Missing: PB enhanced sound layering
    ✗ Missing: near-miss copy integration for popup text
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  LAP FLASH — REGULAR LAP
────────────────────────────────────────────────────────────────────────────────
  Quick, satisfying, not overpowering. The player should register "lap done"
  without being pulled out of their flow state.

  SCREEN FLASH (full-screen Frame, ZIndex 999):
    Phase 1 — White primer (0–0.08s):
      Color            : Color3.new(1, 1, 1)
      BackgroundTransparency: tween 1 → 0.65 over 0.08s (Quad In)
    Phase 2 — Gold fade (0.08–0.35s):
      Color            : Color3.fromHex("FACC15") — warm gold
      BackgroundTransparency: tween peak → 1 over 0.27s (Quad Out)

    Design rationale: White primer "resets" the eye for 1 frame, then the
    gold wash confirms the lap with warmth. Two-color flash reads as a
    single satisfying pop, not two separate events.

  VIGNETTE PULSE (existing vignette Frame):
    BackgroundTransparency: tween 1 → 0.88 over 0.15s, then back to 1 over 0.2s
    Adds subtle edge darkening that frames the flash.

  CAMERA:
    Shake            : intensity 0.12, duration 0.12s
    LOD gate         : LOD 1 = no shake, LOD 2+ = shake

  WORLD-SPACE PARTICLES (Attachment on HumanoidRootPart, y=-4):
    Downward streaks:
      Texture          : sparkles_main.dds
      Color            : white (no ColorSequence — neutral)
      Lifetime         : NumberRange.new(0.35, 0.45)
      Speed            : NumberRange.new(18, 32)
      SpreadAngle      : Vector2.new(15, 15)
      EmissionDirection: Enum.NormalId.Bottom
      Emit count       : 12 (LOD 1) / 16 (LOD 2+)
      Rate             : 0 (burst only)

  POPUP TEXT:
    Pick random line from NearMissCopyConfig.LapComplete:
      "LAP COMPLETE!", "ANOTHER ONE!", "KEEP IT ROLLING!",
      "CLEAN LAP!", "NAILED IT!", "SMOOTH OPERATOR!"
    Display via milestonePopup(text, "lap_complete")
    TextColor3       : Color3.fromHex("FACC15")
    Duration         : 1.2s

  SOUND:
    "lap_horn" (existing — short honk/ding, ~0.3s)

  Attachment cleanup : destroy after 0.8s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  LAP FLASH — PERSONAL BEST LAP
────────────────────────────────────────────────────────────────────────────────
  The player just set a new fastest time. This should feel SIGNIFICANTLY more
  impactful than a regular lap — it's a personal achievement moment.

  SCREEN FLASH (enhanced, ZIndex 999):
    Phase 1 — White primer (0–0.08s):
      Color            : Color3.new(1, 1, 1)
      BackgroundTransparency: tween 1 → 0.55 over 0.08s (brighter than regular)
    Phase 2 — Gold hold (0.08–0.18s):
      Color            : Color3.fromHex("FACC15")
      BackgroundTransparency: hold at 0.55 for 0.10s (lingers for emphasis)
    Phase 3 — Gold fade (0.18–0.50s):
      BackgroundTransparency: tween 0.55 → 1 over 0.32s (Quad Out)

    Design rationale: The extended hold at Phase 2 makes PB flashes feel
    "heavier" — the gold lingers just long enough to register as special.

  RADIAL ACCENT (NEW — screen-space radial burst):
    A second Frame behind the main flash, with a radial UIGradient:
      Name             : "PBRadialBurst"
      ZIndex           : 998
      BackgroundColor3 : Color3.fromRGB(255, 220, 80)
      UIGradient:
        Type           : radial-approximation (Rotation cycles 4 keypoints)
        Transparency   : center opaque → edges transparent
          {
            (0,   0.3),
            (0.3, 0.6),
            (0.6, 1),
            (1,   1),
          }
      Animation        : BackgroundTransparency 0.6 → 1 over 0.4s (Quad Out)
      Size             : start UDim2.fromScale(0.3, 0.3), tween to (1.5, 1.5)
                         over 0.35s (expanding outward from center)
      Position         : UDim2.fromScale(0.5, 0.5), AnchorPoint (0.5, 0.5)
      Destroy          : 0.5s

    This creates a gold shockwave radiating from screen center on PB only.

  CONFETTI SHOWER (world-space, gold sparkles):
    Texture            : sparkles_main.dds
    Color              : ColorSequence.new(Color3.fromHex("FACC15"))
    Emit count         : 24 (existing — keep this count)
    Lifetime           : NumberRange.new(0.4, 0.8)
    Speed              : NumberRange.new(4, 14)
    SpreadAngle        : Vector2.new(180, 180)
    Acceleration       : Vector3.new(0, -20, 0)
    Rate               : 0 (burst only)

  CAMERA:
    Shake              : intensity 0.20, duration 0.12s (stronger than regular)

  POPUP TEXT:
    Pick random line from NearMissCopyConfig.LapPersonalBest:
      "NEW RECORD!", "FASTEST LAP!", "PERSONAL BEST!",
      "YOU BEAT YOURSELF!", "NEW PB! INSANE!"
    Display via milestonePopup(text, "lap_pb")
    TextColor3         : Color3.fromRGB(255, 220, 80)
    TextSize           : 36 (larger than regular lap at 28)
    Duration           : 1.8s (longer than regular for emphasis)

    Subtitle line (below headline):
      Pick from NearMissCopyConfig.LapHumor
      TextSize         : 18
      TextColor3       : Color3.fromRGB(255, 240, 180)

  SOUND:
    t=0.0s : "lap_horn" (existing)
    t=0.05s: "lap_pb_chime" (NEW — bright ascending 3-note bell phrase, ~0.4s)
      Pitch: C6–E6–G6 (triumphant major triad, fast arpeggio)
      Timbre: metallic bell + subtle synth pad tail

  Attachment cleanup  : destroy after 0.8s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  LAP FLASH — COMPARISON TABLE
────────────────────────────────────────────────────────────────────────────────

  | Property              | REGULAR LAP          | PERSONAL BEST LAP    |
  |-----------------------|----------------------|----------------------|
  | Flash Peak Transp.    | 0.65                 | 0.55                 |
  | Flash Duration        | 0.35s (0.08 + 0.27)  | 0.50s (0.08+0.10+0.32)|
  | Flash Color           | white → gold          | white → gold (held)   |
  | Radial Burst          | no                   | yes (gold shockwave)  |
  | Confetti              | no                   | 24 gold sparkles      |
  | Camera Shake          | 0.12 / 0.12s         | 0.20 / 0.12s          |
  | Popup Text Pool       | LapComplete (6)      | LapPersonalBest (5)   |
  | Popup Duration        | 1.2s                 | 1.8s                  |
  | Sound Layers          | 1 (lap_horn)         | 2 (horn + pb_chime)   |
  | Particle Streaks      | 12–16                | 12–16 + 24 confetti   |

  NEW SOUND CUE NEEDED:
    lap_pb_chime — bright ascending bell arpeggio (0.4s)
]]


--[[
================================================================================
  SECTION C — NEAR-MISS SPARK
================================================================================
  Triggered via VFXFacade.nearMissSpark(fromRight) when the player narrowly
  avoids an obstacle. DrivingController detects proximity and passes the
  approach direction.

  Design goal: Transform a near-death moment into a REWARD moment. The player
  almost crashed — instead of fear, they should feel a rush of adrenaline and
  pride. The visual language shifts from danger (red) to reward (gold/white)
  over a split second.

  CURRENT IMPLEMENTATION STATUS:
    ✓ Side-mounted spark burst (3–5 orange particles)
    ✓ Edge vignette red pulse (nearMissEdgeEnterFx)
    ✓ "CLOSE CALL!" milestone popup (nearMissRecover)
    ✗ Missing: danger-to-reward color shift (currently static orange)
    ✗ Missing: screen-space edge flash matching approach side
    ✗ Missing: points popup (+50 SKILL BONUS!)
    ✗ Missing: combo multiplier for consecutive near-misses
    ✗ Missing: sparkle trail on the car side post-dodge
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEAR-MISS — WORLD-SPACE SPARK BURST
────────────────────────────────────────────────────────────────────────────────
  Particles spawn on the side of the car facing the dodged obstacle.
  Enhanced from current 3-5 orange to a two-phase color shift.

  Attachment position:
    fromRight = true  : Vector3.new( 1.8, 0.35, 2.4) on trailPart
    fromRight = false : Vector3.new(-1.8, 0.35, 2.4) on trailPart

  Phase 1 — Danger sparks (instant, t=0):
    Texture            : sparkles_main.dds
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 60, 30)),
                           ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 40)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 200, 80)),
                         })
    Emit count         : math.floor(6 * lodBurstMul())
    Lifetime           : NumberRange.new(0.10, 0.25)
    Speed              : NumberRange.new(10, 26)
    SpreadAngle        : Vector2.new(50, 50)
    EmissionDirection  : if fromRight then Right else Left
    Size               : NumberSequence.new(0.10, 0.40)
    LightEmission      : 0.9
    Drag               : 0.8

    Design: Hot red sparks fly outward from the near-miss side. The
    ColorSequence shifts from danger-red at birth to warm gold at death,
    visually transitioning the moment from "DANGER" to "REWARD."

  Phase 2 — Reward flash motes (t=0.06s):
    A second emitter fires on the same attachment after a 1-frame delay:
    Texture            : sparkles_main.dds
    Color              : ColorSequence.new(Color3.fromRGB(255, 240, 160))
    Emit count         : math.floor(4 * lodBurstMul())
    Lifetime           : NumberRange.new(0.15, 0.35)
    Speed              : NumberRange.new(4, 12)
    SpreadAngle        : Vector2.new(90, 90)
    Size               : NumberSequence.new(0.06, 0.22)
    LightEmission      : 0.7
    Acceleration       : Vector3.new(0, 3, 0) (float upward — "reward" feel)

    Design: Softer gold motes float upward from the dodge point.
    The upward drift reads as "you gained something" — contrasting the
    outward scatter of Phase 1's danger sparks.

  Cleanup: destroy Attachment after 0.5s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEAR-MISS — SCREEN-SPACE EDGE FLASH
────────────────────────────────────────────────────────────────────────────────
  A directional screen flash on the side matching the near-miss approach.
  The existing nearMissEdgeEnterFx uses the vignette frame (full-screen red
  pulse). This spec adds a DIRECTIONAL accent on the relevant screen edge.

  Side flash Frame (NEW):
    Name               : "NearMissEdgeFlash"
    ZIndex             : 996
    Size               : UDim2.new(0.15, 0, 1, 0)  (thin strip, 15% width)
    Position:
      fromRight = true : UDim2.new(0.85, 0, 0, 0)  (right edge)
      fromRight = false: UDim2.new(0, 0, 0, 0)     (left edge)

  UIGradient (horizontal, edge → inward fade):
    fromRight = true:
      Transparency     : { (0, 1), (0.7, 0.4), (1, 0) }  -- opaque at right
    fromRight = false:
      Transparency     : { (0, 0), (0.3, 0.4), (1, 1) }  -- opaque at left

  Color animation:
    t=0.00s: BackgroundColor3 = Color3.fromRGB(255, 40, 20) (danger red)
    t=0.06s: Tween to Color3.fromRGB(255, 200, 80) over 0.08s (reward gold)
    t=0.14s: Tween BackgroundTransparency to 1 over 0.18s (fade out)

    Design: The edge lights up RED (danger!) then shifts to GOLD (reward!)
    in under 150ms. The player's peripheral vision catches the color shift
    subconsciously — it trains the brain to associate near-misses with
    positive feedback.

  Total visible duration: ~0.32s
  Destroy: 0.4s
  LOD gate: LOD 1 = skip, LOD 2+ = show
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEAR-MISS — POPUP TEXT + POINTS
────────────────────────────────────────────────────────────────────────────────
  The existing nearMissRecover() fires a "CLOSE CALL!" popup. This spec
  enhances it with rotation through NearMissCopyConfig variants and a
  points callout.

  Popup line selection:
    Pick random from NearMissCopyConfig.NearMiss (16 variants)
    Display via milestonePopup(text, "near_miss")

  Text styling:
    TextColor3         : Color3.fromRGB(255, 200, 80) (reward gold)
    TextSize           : 24
    TextStrokeColor3   : Color3.fromRGB(180, 80, 0) (dark orange stroke)
    TextStrokeTransparency: 0.5
    Duration           : 0.8s

  Points popup (displayed below main text, optional):
    Text               : "+50" (fixed near-miss bonus)
    TextColor3         : Color3.fromRGB(255, 255, 200) (pale gold)
    TextSize           : 18
    Animation          : scale 0 → 1.2 over 0.08s (Back Out), then 1.2 → 1
                         over 0.1s. Float upward 30px over 0.6s.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEAR-MISS — COMBO SYSTEM (Suggested Enhancement)
────────────────────────────────────────────────────────────────────────────────
  If the player chains near-misses within a short window, escalate the visual
  feedback. This rewards skilled aggressive driving.

  Combo window        : 3.0 seconds between consecutive near-misses
  Combo counter       : 1 → 2 → 3 → 5 → ... (resets on crash or timeout)

  | Combo Count | Popup Text Source              | Spark Count Multiplier |
  |-------------|--------------------------------|------------------------|
  | 1           | NearMissCopyConfig.NearMiss    | 1.0x                   |
  | 2           | "NEAR MISS x2!"               | 1.3x                   |
  | 3           | "NEAR MISS x3!"               | 1.6x                   |
  | 5+          | NearMissCopyConfig.StreakHeadlines ("UNTOUCHABLE!") | 2.0x |

  At combo 3+:
    Additional screen flash: gold, 0.15s, peak transparency 0.70
    Camera shake: intensity 0.08, duration 0.08s

  At combo 5+:
    Text color shifts to Color3.fromRGB(255, 100, 200) (hot pink — "on fire")
    Additional sound: "combo_ding" (ascending pitch per combo level)

  Implementation: maintain a nearMissComboCount and nearMissComboLastClock
  in VFXController. Reset on run end or 3s timeout.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEAR-MISS — SOUND DESIGN
────────────────────────────────────────────────────────────────────────────────
  Existing:
    nearMissEdgeEnterFx plays "screech" or "rebirth_whoosh" (50/50 random)

  Enhancement:
    Keep the existing tire screech/whoosh for the danger moment.
    Layer a reward chime on top 0.08s after the screech:
      "near_miss_chime" (NEW — short bright ping, ~0.15s, pitch C6)
      Volume: 0.4 (quieter than the screech — accent, not dominant)

  Combo sounds:
    combo_ding (NEW — ascending pitch per combo, ~0.1s each)
    At combo 2: pitch D6
    At combo 3: pitch E6
    At combo 5+: pitch G6

  NEW SOUND CUES NEEDED:
    near_miss_chime    — bright reward ping (0.15s)
    combo_ding         — ascending pitch ding (0.1s, parameterized pitch)
]]


--[[
================================================================================
  SECTION D — AMBIENT WORLD PARTICLES
================================================================================
  Triggered via VFXFacade.ambientStart() when the player is NOT in a run
  (idling in the world). Stopped via VFXFacade.ambientStop() when a run
  begins. Also re-triggered on world transition.

  Design goal: Each world should have a distinct atmospheric PERSONALITY that
  the player can feel without looking at anything specific. Ambient particles
  are the world's breath — subtle, persistent, and immersive.

  CURRENT IMPLEMENTATION STATUS:
    ✓ Grasslands: pollen motes + dandelion seeds
    ✓ Desert: heat shimmer + sand motes
    ✓ Frozen: snowflakes + ice sparkles
    ✓ Neon: neon flecks + static crackle
    ✓ LOD gating (disabled at LOD 1, reduced at LOD 2)
    ✗ Missing: enhanced secondary layers for each world
    ✗ Missing: distinct size/speed/color palettes are functional but
      could be richer with additional particle layers

  Worlds: grasslands, desert, frozen, neon
  (WorldUnlockConfig defines the active world set)
  Particles attach to a "DACVFX_Ambient" Folder on HumanoidRootPart.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  GRASSLANDS — Pollen + Dandelion Seeds + Butterflies
────────────────────────────────────────────────────────────────────────────────
  Warm, alive, nostalgic. The first world should feel like a pleasant meadow.
  Gentle, sun-drenched particles drifting lazily.

  COLOR PALETTE:
    Pollen           : Color3.fromRGB(255, 250, 200)  -- warm cream
    Seeds            : Color3.fromRGB(200, 180, 120)  -- tan/amber
    Butterfly accent : Color3.fromRGB(255, 180, 100)  -- sunset orange

  LAYER 1 — Pollen motes (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new(Color3.fromRGB(255, 250, 200))
    Rate             : 3 * rateMul (LOD 2: 2)
    Lifetime         : NumberRange.new(4, 8)
    Speed            : NumberRange.new(0.2, 1.2)
    SpreadAngle      : Vector2.new(180, 180)
    Size             : NumberSequence.new(0.08, 0.2)
    LightEmission    : 0.3
    Drag             : 0.5

  LAYER 2 — Dandelion seeds (existing):
    Texture          : smoke_main.dds
    Color            : ColorSequence.new(Color3.fromRGB(200, 180, 120))
    Rate             : 2.5 * rateMul (LOD 2: 1.5)
    Lifetime         : NumberRange.new(5, 9)
    Speed            : NumberRange.new(0.5, 2)
    SpreadAngle      : Vector2.new(180, 180)
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.15),
                         NumberSequenceKeypoint.new(0.5, 0.35),
                         NumberSequenceKeypoint.new(1, 0.1),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.3),
                         NumberSequenceKeypoint.new(0.6, 0.5),
                         NumberSequenceKeypoint.new(1, 1),
                       })
    Acceleration     : Vector3.new(0.3, 0.15, 0)  -- gentle wind drift
    RotSpeed         : NumberRange.new(-8, 8)

  LAYER 3 — Butterfly accent (NEW, LOD 3 only):
    Texture          : smoke_main.dds
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 180, 100)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 150)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 160, 80)),
                       })
    Rate             : 0.4 * rateMul (rare — only ~1 visible at a time)
    Lifetime         : NumberRange.new(6, 12)
    Speed            : NumberRange.new(0.8, 2.5)
    SpreadAngle      : Vector2.new(120, 120)
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.1),
                         NumberSequenceKeypoint.new(0.3, 0.25),
                         NumberSequenceKeypoint.new(0.7, 0.25),
                         NumberSequenceKeypoint.new(1, 0.08),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.4),
                         NumberSequenceKeypoint.new(0.2, 0.15),
                         NumberSequenceKeypoint.new(0.8, 0.15),
                         NumberSequenceKeypoint.new(1, 1),
                       })
    LightEmission    : 0.4
    RotSpeed         : NumberRange.new(-30, 30)
    Acceleration     : Vector3.new(0, 0.1, 0)  -- slight upward float

  PARTICLE BUDGET:
    LOD 3: ~6/s total (pollen 3 + seeds 2.5 + butterfly 0.4)
    LOD 2: ~3.5/s total (pollen 2 + seeds 1.5 + butterfly 0)
    LOD 1: disabled
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  DESERT — Heat Shimmer + Sand Wisps + Dust Devils
────────────────────────────────────────────────────────────────────────────────
  Hot, arid, hostile. The desert is the first "earned" world — particles
  should feel harsher and more dynamic than the pastoral Grasslands.

  COLOR PALETTE:
    Heat shimmer     : blend of accent neon + Color3.fromRGB(255, 240, 200)
    Sand             : Color3.fromRGB(230, 190, 120)  -- golden sand
    Dust             : Color3.fromRGB(180, 150, 90)   -- darker dust

  LAYER 1 — Heat shimmer (existing):
    Texture          : smoke_main.dds
    Color            : ColorSequence.new(accent:Lerp(Color3.fromRGB(255, 240, 200), 0.35))
    Rate             : 2.2 * rateMul
    Lifetime         : NumberRange.new(2.5, 4.5)
    Speed            : NumberRange.new(0.4, 2.2)
    SpreadAngle      : Vector2.new(180, 180)
    EmissionDirection: Enum.NormalId.Top
    Acceleration     : Vector3.new(0, 0.8, 0)
    Drag             : 1.2
    LightEmission    : 0.25
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.4),
                         NumberSequenceKeypoint.new(0.5, 1.1),
                         NumberSequenceKeypoint.new(1, 0.2),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.55),
                         NumberSequenceKeypoint.new(0.6, 0.75),
                         NumberSequenceKeypoint.new(1, 1),
                       })

    Design: Large, soft, semi-transparent rising wisps. They expand as they
    rise (like real heat shimmer) and fade before reaching full height.

  LAYER 2 — Sand motes (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new(Color3.fromRGB(230, 190, 120))
    Rate             : 2.5 * rateMul
    Lifetime         : NumberRange.new(3, 6)
    Speed            : NumberRange.new(1.5, 4)
    SpreadAngle      : Vector2.new(25, 25)
    EmissionDirection: Enum.NormalId.Right (directional wind)
    Acceleration     : Vector3.new(0, -0.15, 0)
    Drag             : 0.8
    RotSpeed         : NumberRange.new(-20, 20)
    Size             : NumberSequence.new(0.06, 0.18)

  LAYER 3 — Dust devil wisps (NEW, LOD 3 only):
    Occasional larger dust clouds that spiral lazily — evoking mini
    dust devils forming and dissolving on the horizon.
    Texture          : smoke_main.dds
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 150, 90)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 170, 110)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 130, 80)),
                       })
    Rate             : 0.5 * rateMul
    Lifetime         : NumberRange.new(4, 7)
    Speed            : NumberRange.new(1.5, 4)
    SpreadAngle      : Vector2.new(60, 30) (wider horizontal than vertical)
    EmissionDirection: Enum.NormalId.Right
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.3),
                         NumberSequenceKeypoint.new(0.4, 0.8),
                         NumberSequenceKeypoint.new(1, 0.15),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.5),
                         NumberSequenceKeypoint.new(0.3, 0.35),
                         NumberSequenceKeypoint.new(1, 1),
                       })
    RotSpeed         : NumberRange.new(-40, 40) (tumbling rotation)
    Acceleration     : Vector3.new(0.5, 0.3, 0) (drift with wind)

  PARTICLE BUDGET:
    LOD 3: ~5.2/s total (heat 2.2 + sand 2.5 + dust 0.5)
    LOD 2: ~3.1/s total (heat 1.4 + sand 1.6 + dust 0)
    LOD 1: disabled
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  FROZEN TUNDRA — Snowflakes + Ice Sparkles + Frost Mist
────────────────────────────────────────────────────────────────────────────────
  Cold, pristine, crystalline. Particles should feel delicate and airy.
  The ice sparkles catch "light" and glint. Occasional frost mist drifts
  at ground level.

  COLOR PALETTE:
    Snow             : Color3.fromRGB(240, 248, 255)  -- ghost white
    Ice sparkle      : accent:Lerp(Color3.new(1, 1, 1), 0.4) — icy white
    Frost mist       : Color3.fromRGB(200, 220, 240)  -- pale blue

  LAYER 1 — Snowflakes (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new(Color3.fromRGB(240, 248, 255))
    Rate             : 2.8 * rateMul
    Lifetime         : NumberRange.new(4, 7)
    Speed            : NumberRange.new(0.8, 2.5)
    SpreadAngle      : Vector2.new(180, 180)
    EmissionDirection: Enum.NormalId.Top
    Acceleration     : Vector3.new(0, -1.2, 0)  -- gentle fall
    Drag             : 0.5
    Size             : NumberSequence.new(0.1, 0.28)

  LAYER 2 — Ice sparkles (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.4))
    Rate             : 2 * rateMul
    Lifetime         : NumberRange.new(1.2, 2.8)
    Speed            : NumberRange.new(0.2, 1.4)
    SpreadAngle      : Vector2.new(180, 180)
    LightEmission    : 0.75
    Size             : NumberSequence.new(0.05, 0.2)
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.2),
                         NumberSequenceKeypoint.new(0.5, 0.45),
                         NumberSequenceKeypoint.new(1, 1),
                       })

    Design: These are the "diamond dust" effect — tiny ice crystals
    catching light and flashing briefly. High LightEmission makes them
    glow against dark backgrounds.

  LAYER 3 — Frost mist (NEW, LOD 3 only):
    Low-lying wispy fog that drifts horizontally.
    Texture          : smoke_main.dds
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 220, 240)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 235, 250)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(190, 210, 230)),
                       })
    Rate             : 0.6 * rateMul
    Lifetime         : NumberRange.new(5, 10)
    Speed            : NumberRange.new(0.3, 1.5)
    SpreadAngle      : Vector2.new(60, 15) (wide horizontal, narrow vertical)
    EmissionDirection: Enum.NormalId.Right
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.3),
                         NumberSequenceKeypoint.new(0.4, 1.0),
                         NumberSequenceKeypoint.new(1, 0.4),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.6),
                         NumberSequenceKeypoint.new(0.3, 0.45),
                         NumberSequenceKeypoint.new(1, 1),
                       })
    RotSpeed         : NumberRange.new(-10, 10)
    Drag             : 0.3
    Acceleration     : Vector3.new(0.2, -0.05, 0) -- drift + slight sink

    Design: Creates a subtle mist that crawls along the ground near the
    player. Large, soft, transparent — evokes frozen breath or ground fog.

  PARTICLE BUDGET:
    LOD 3: ~5.4/s total (snow 2.8 + ice 2.0 + mist 0.6)
    LOD 2: ~3.1/s total (snow 1.8 + ice 1.3 + mist 0)
    LOD 1: disabled
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEON CITY — Neon Flecks + Static Crackle + Digital Rain
────────────────────────────────────────────────────────────────────────────────
  Electric, futuristic, alive. The highest-tier world should feel like
  the air itself is charged with energy. Bright, fast particles with high
  LightEmission. The only world with particles that move UPWARD naturally.

  COLOR PALETTE:
    Neon fleck       : world accent color (WORLD_TRAIL_NEON.neon)
    Static crackle   : white → accent → pale blue cycle
    Digital rain     : Color3.fromRGB(0, 255, 160) — matrix green

  LAYER 1 — Neon flecks (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new(accent)
    Rate             : 3 * rateMul
    Lifetime         : NumberRange.new(1.5, 3)
    Speed            : NumberRange.new(1.5, 5)
    SpreadAngle      : Vector2.new(40, 40)
    EmissionDirection: Enum.NormalId.Top
    Acceleration     : Vector3.new(0, 1.2, 0) (rise upward — anti-gravity)
    LightEmission    : 0.9
    Size             : NumberSequence.new(0.08, 0.22)

    Design: Bright accent-colored motes that defy gravity, rising upward
    like neon sparks from the city below. High LightEmission ensures
    they pop against the dark neon cityscape.

  LAYER 2 — Static crackle (existing):
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
                         ColorSequenceKeypoint.new(0.5, accent),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 220, 255)),
                       })
    Rate             : 8 * rateMul
    Lifetime         : NumberRange.new(0.08, 0.22)
    Speed            : NumberRange.new(4, 14)
    SpreadAngle      : Vector2.new(180, 180)
    LightEmission    : 1.0
    Size             : NumberSequence.new(0.04, 0.12)

    Design: Ultra-short-lived electric zaps. High Rate + tiny lifetime
    creates a constant "static electricity" crackle around the player.
    Full LightEmission makes them feel self-illuminated.

  LAYER 3 — Digital rain motes (NEW, LOD 3 only):
    Slow-falling green-tinted particles evoking the "digital rain" /
    matrix aesthetic appropriate for the cyberpunk neon world.
    Texture          : sparkles_main.dds
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 255, 160)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 200)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 200, 120)),
                       })
    Rate             : 1.2 * rateMul
    Lifetime         : NumberRange.new(2, 4)
    Speed            : NumberRange.new(2, 6)
    SpreadAngle      : Vector2.new(10, 10) (narrow vertical columns)
    EmissionDirection: Enum.NormalId.Bottom (falling downward)
    Acceleration     : Vector3.new(0, -2, 0)
    LightEmission    : 0.85
    Size             : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.04),
                         NumberSequenceKeypoint.new(0.3, 0.12),
                         NumberSequenceKeypoint.new(1, 0.02),
                       })
    Transparency     : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.2),
                         NumberSequenceKeypoint.new(0.7, 0.4),
                         NumberSequenceKeypoint.new(1, 1),
                       })

    Design: Thin green motes stream downward in narrow columns. They start
    small, briefly expand, then shrink and fade — like data packets
    raining through the air. The narrow SpreadAngle creates distinct
    vertical "streams" rather than random scatter.

  PARTICLE BUDGET:
    LOD 3: ~12.2/s total (fleck 3 + crackle 8 + rain 1.2)
    LOD 2: ~7.2/s total (fleck 2 + crackle 5.2 + rain 0)
    LOD 1: disabled

    Note: Neon has a higher budget than other worlds because the short
    lifetime of static crackle means few particles exist at any frame.
    Effective on-screen count at any instant ≈ 3-5 particles.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  AMBIENT PARTICLES — CROSS-WORLD COMPARISON TABLE
────────────────────────────────────────────────────────────────────────────────

  | Property              | GRASSLANDS        | DESERT             | FROZEN             | NEON               |
  |-----------------------|-------------------|--------------------|--------------------|--------------------|
  | Mood                  | Warm, pastoral     | Hot, harsh          | Cold, crystalline   | Electric, alive     |
  | Primary Particle      | Pollen motes       | Heat shimmer        | Snowflakes          | Neon flecks         |
  | Secondary Particle    | Dandelion seeds    | Sand motes          | Ice sparkles        | Static crackle      |
  | Tertiary (LOD3)       | Butterfly accent   | Dust devil wisps    | Frost mist          | Digital rain        |
  | Dominant Direction    | Neutral (all dirs)  | Rightward (wind)    | Downward (falling)  | Upward (anti-grav)  |
  | Dominant Color Temp   | Warm (cream/amber)  | Hot (gold/tan)      | Cool (white/blue)   | Saturated (accent)  |
  | Max Rate (LOD 3)      | ~6/s               | ~5.2/s              | ~5.4/s              | ~12.2/s             |
  | Max Rate (LOD 2)      | ~3.5/s             | ~3.1/s              | ~3.1/s              | ~7.2/s              |
  | LightEmission Range   | 0.3–0.4            | 0.25                | 0.3–0.75            | 0.85–1.0            |
  | Avg Particle Lifetime | 4–9s (long-lived)   | 2.5–6s (medium)     | 1.2–7s (mixed)      | 0.08–3s (varied)    |

  WORLD-TO-WORLD TRANSITION:
    When the player switches worlds, ambientStop() clears all emitters,
    then ambientStart() recreates for the new world. No cross-fade needed —
    the world transition VFX (worldTransition method) provides the visual
    bridge between environments.
]]


--[[
================================================================================
  SOUND CUE REFERENCE — ALL NEW SOUNDS NEEDED FOR THIS SPEC
================================================================================

  | Sound ID            | Description                             | Duration | Priority |
  |---------------------|-----------------------------------------|----------|----------|
  | lap_pb_chime        | Bright ascending bell arpeggio (C6-E6-G6)| 0.4s     | high     |
  | near_miss_chime     | Short bright reward ping                 | 0.15s    | medium   |
  | combo_ding          | Ascending pitch ding (parameterized)     | 0.1s     | low      |
  | speed_wind_loop     | Wind whistle loop for speed rush         | loopable | low      |

  Existing sounds reused:
    lap_horn           — regular lap completion
    screech            — near-miss danger moment
    rebirth_whoosh     — near-miss danger moment (alternates with screech)

================================================================================
]]


--[[
================================================================================
  LOD TIER BUDGET SUMMARY — ALL FOUR SYSTEMS
================================================================================

  SPEED RUSH OVERLAY:
    LOD 1: edge vignette only (no chroma, no speed lines, no shake)
    LOD 2: edge + chroma (no speed lines, no shake)
    LOD 3: full effect (edge + chroma + speed lines + micro shake)
    No particle budget — purely screen-space Frames.

  LAP FLASH:
    LOD 1: screen flash only, 12 particle streaks, no camera shake
    LOD 2+: screen flash + vignette + shake + 16 streaks (+ PB confetti)
    PB radial burst: LOD 2+ only
    Max one-shot particles: 40 (16 streaks + 24 confetti)

  NEAR-MISS SPARK:
    LOD 1: 4 particles (reduced lodBurstMul), no edge flash
    LOD 2: 8 particles + edge flash, no reward motes
    LOD 3: 10 particles + 4 reward motes + edge flash
    Max one-shot particles: 14

  AMBIENT PARTICLES (per-frame, while idle):
    | World       | LOD 3    | LOD 2    | LOD 1    |
    |-------------|----------|----------|----------|
    | Grasslands  | ~6/s     | ~3.5/s   | 0        |
    | Desert      | ~5.2/s   | ~3.1/s   | 0        |
    | Frozen      | ~5.4/s   | ~3.1/s   | 0        |
    | Neon        | ~12.2/s  | ~7.2/s   | 0        |

    Neon's higher rate is safe due to ultra-short crackle lifetimes
    (~0.15s average) — on-screen count stays comparable to other worlds.

================================================================================
]]

return nil
