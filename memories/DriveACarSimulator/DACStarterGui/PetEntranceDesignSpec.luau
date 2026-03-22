--!strict
--[[
	PET EQUIP ENTRANCE ANIMATION + RARITY SHOWCASE AURA — Design Spec
	===================================================================
	This file defines exact parameters for two systems:
	  A) Pet Equip Entrance Animation  (one-shot on equip)
	  B) Rarity Showcase Aura          (persistent while equipped)

	Engineer implementation notes:
	  - Hook into VFXController.petOrbitGlow (phase == "equip") or add a new
	    VFXFacade.petEquipEntrance(petUid, model, rarity) method.
	  - Persistent auras replace the current petOrbitGlow motes/orbitStars for
	    Epic/Legendary/Mythic with richer layered effects.
	  - All particle textures use the engine-stock sparkle and smoke:
	      "rbxasset://textures/particles/sparkles_main.dds"
	      "rbxasset://textures/particles/smoke_main.dds"
	  - Respect the existing LOD tier system (lodTier 1/2/3) — multiply all
	    particle Rate and Emit counts by lodBurstMul() / lodTrailRateMul().
	  - Colors reference Constants.RARITY_COLORS:
	      common    = Color3.fromRGB(180, 180, 180)
	      uncommon  = Color3.fromRGB( 80, 200,  80)
	      rare      = Color3.fromRGB( 60, 130, 255)
	      epic      = Color3.fromRGB(180,  60, 255)
	      legendary = Color3.fromRGB(255, 200,  50)
	      mythic    = Color3.fromRGB(255,  50,  80)
	  - mythicRainbowSequence() already exists in VFXController for rainbow
	    color cycling.
]]

--[[
================================================================================
  SECTION A — PET EQUIP ENTRANCE ANIMATION
================================================================================
  Triggered once when a pet is equipped. Each rarity gets a progressively more
  dramatic entrance. All animations attach to the pet model's PrimaryPart.

  General flow per rarity:
    1. (Optional) Pre-entrance anticipation window
    2. Entrance motion / effect
    3. Landing burst
    4. Sound cue
    5. (Optional) Screen overlay / camera reaction
================================================================================
]]

export type EntranceSpec = {
	anticipationDuration: number,
	entranceStyle: string,
	burstParticleCount: number,
	trailParticleRate: number,
	trailDuration: number,
	trailColor: { number },
	cameraShakeIntensity: number,
	cameraShakeDuration: number,
	screenFlashColor: { number },
	screenFlashDuration: number,
	screenFlashPeakTransparency: number,
	soundCue: string,
	extraSoundCue: string?,
	hitstopDuration: number,
	slowMotionDuration: number,
	beamCount: number,
	beamWidth: number,
	beamLength: number,
	confettiCount: number,
	screenDistortion: boolean,
}

--[[
────────────────────────────────────────────────────────────────────────────────
  COMMON — Simple pop-in with small sparkle
────────────────────────────────────────────────────────────────────────────────
  The pet model scales from 0 → 1 over 0.2s (EasingStyle.Back, Out) and a
  small ring of white sparkles pops outward.

  Model tween:
    Property       : Scale (UIScale on billboard, or Model:ScaleTo)
    From           : 0.01
    To             : 1.0
    Duration       : 0.2s
    EasingStyle    : Back
    EasingDirection: Out

  Sparkle burst (ParticleEmitter on Attachment at pet center):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(Color3.fromRGB(220, 220, 220))
    Emit count     : 8 * lodBurstMul()
    Lifetime       : NumberRange.new(0.15, 0.35)
    Speed          : NumberRange.new(4, 10)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.08, 0.25)
    LightEmission  : 0.4
    Drag           : 1.5
    Acceleration   : Vector3.new(0, -2, 0)

  Sound: "pet_equip_common"
    (short, soft "pop" — 0.15s, high-pass filtered click)

  No camera shake. No screen flash. No anticipation.
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  UNCOMMON — Slide-in from side with green trail
────────────────────────────────────────────────────────────────────────────────
  Pet model slides in from 8 studs to the right (or left, randomized) over
  0.35s, leaving a green particle trail behind it.

  Motion tween:
    Property       : CFrame.Position (offset from target)
    From           : target + Vector3.new(8 * side, 2, 0)
    To             : target position
    Duration       : 0.35s
    EasingStyle    : Quad
    EasingDirection: Out

  Trail emitter (attached to pet, runs during slide):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 230, 100)),
                       ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 60)),
                     })
    Rate           : 35 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.2, 0.5)
    Speed          : NumberRange.new(1, 4)
    SpreadAngle    : Vector2.new(15, 15)
    Size           : NumberSequence.new(0.1, 0.3)
    Transparency   : NumberSequence.new(0.2, 1)
    LightEmission  : 0.55
    Drag           : 2

  Landing burst (on arrival):
    Texture        : sparkles_main.dds
    Color          : uncommon rarity color
    Emit count     : 14 * lodBurstMul()
    Lifetime       : NumberRange.new(0.2, 0.45)
    Speed          : NumberRange.new(6, 14)
    SpreadAngle    : Vector2.new(180, 180)

  Trail disable: set Rate = 0 after motion completes, destroy after 0.6s.

  Sound: "pet_equip_uncommon"
    (quick whoosh + soft chime, ~0.3s)

  No camera shake. No screen flash.
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  RARE — Spiral entrance with blue lightning zaps
────────────────────────────────────────────────────────────────────────────────
  Pet spawns 6 studs above target, spirals down in a helix (radius 2 studs)
  over 0.6s. Blue lightning sparks crackle around it during descent.

  Spiral motion (scripted per-frame, not tween):
    Duration       : 0.6s
    Start position : target + Vector3.new(0, 6, 0)
    Radius         : 2 studs
    Revolutions    : 1.5
    Vertical easing: Quad Out
    Formula        : angle = t * 1.5 * 2π
                     x = cos(angle) * radius * (1 - t)
                     z = sin(angle) * radius * (1 - t)
                     y = 6 * (1 - t^1.5)

  Lightning zap emitter (runs during spiral):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0,   Color3.fromRGB(120, 180, 255)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 230, 255)),
                       ColorSequenceKeypoint.new(1,   Color3.fromRGB( 60, 130, 255)),
                     })
    Rate           : 28 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.06, 0.18)
    Speed          : NumberRange.new(8, 22)
    SpreadAngle    : Vector2.new(60, 60)
    Size           : NumberSequence.new(0.04, 0.15)
    LightEmission  : 1.0
    Drag           : 0.5

  Landing burst:
    Emit count     : 24 * lodBurstMul()
    Same color as zap emitter
    Lifetime       : NumberRange.new(0.2, 0.5)
    Speed          : NumberRange.new(8, 20)
    SpreadAngle    : Vector2.new(180, 180)

  Beam ring (4 beams radiating outward on landing):
    Count          : 4
    Width0         : 0.25
    Width1         : 0.04
    Length          : 3 studs
    Color          : rare rarity color
    Transparency   : NumberSequence.new(0.1, 1)
    FaceCamera     : true
    Duration       : 0.45s then destroy

  Sound: "pet_equip_rare"
    (electric crackle + impact thud, ~0.5s)

  Mild camera nudge:
    Intensity      : 0.08
    Duration       : 0.1s
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  EPIC — Purple vortex swirl-in with energy crackle
────────────────────────────────────────────────────────────────────────────────
  0.3s anticipation: a dark purple disc (screen overlay, radial gradient)
  pulses once, then the pet spirals in from 8 studs above through a vortex
  of purple energy wisps over 0.8s.

  Anticipation overlay (ScreenGui frame):
    Size           : UDim2.fromScale(1, 1)
    BackgroundColor: Color3.fromRGB(60, 10, 80)
    ZIndex         : 997
    UIGradient:
      Transparency : radial-ish (0→0.7, 0.4→1, 1→0.7), Rotation 90
    Tween in       : BackgroundTransparency 1→0.7 over 0.15s
    Tween out      : BackgroundTransparency 0.7→1 over 0.15s

  Vortex motion (scripted per-frame):
    Duration       : 0.8s
    Start          : target + Vector3.new(0, 8, 0)
    Radius         : 3 → 0 studs (linear shrink)
    Revolutions    : 2.5
    Vertical easing: Expo Out

  Vortex particle emitter (purple energy wisps):
    Texture        : smoke_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0,   Color3.fromRGB(180,  60, 255)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140,  30, 200)),
                       ColorSequenceKeypoint.new(1,   Color3.fromRGB(220, 120, 255)),
                     })
    Rate           : 40 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.3, 0.7)
    Speed          : NumberRange.new(2, 8)
    SpreadAngle    : Vector2.new(30, 30)
    Size           : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.3),
                       NumberSequenceKeypoint.new(0.5, 0.6),
                       NumberSequenceKeypoint.new(1, 0.1),
                     })
    Transparency   : NumberSequence.new(0.3, 1)
    LightEmission  : 0.65
    RotSpeed       : NumberRange.new(-60, 60)

  Energy crackle emitter (during descent):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(Color3.fromRGB(220, 180, 255))
    Rate           : 18 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.04, 0.12)
    Speed          : NumberRange.new(12, 30)
    SpreadAngle    : Vector2.new(90, 90)
    Size           : NumberSequence.new(0.03, 0.1)
    LightEmission  : 1.0

  Landing burst:
    Core sparkles  : 35 * lodBurstMul()
    Wisps (smoke)  : 12 * lodBurstMul()
    Color          : epic rarity color
    Speed          : NumberRange.new(8, 24)
    SpreadAngle    : Vector2.new(180, 180)

  Beam ring:
    Count          : 6
    Width0         : 0.3
    Width1         : 0.05
    Length          : 4 studs
    Color          : epic rarity color
    Duration       : 0.6s

  Screen flash:
    Color          : Color3.fromRGB(180, 60, 255)
    Duration       : 0.25s
    Peak transp.   : 0.55

  Camera shake:
    Intensity      : 0.18
    Duration       : 0.2s

  Sound: "pet_equip_epic"
    (deep whorl + energy snap + reverb tail, ~0.7s)
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  LEGENDARY — Golden beam from sky, dramatic landing impact
────────────────────────────────────────────────────────────────────────────────
  0.5s anticipation: a vertical golden beam appears from high above the
  target position. The pet materializes at the top and rides the beam down
  over 0.9s with increasing speed (Quad In easing).

  Sky beam (Beam instance, world-space):
    Attachment0    : pet PrimaryPart center
    Attachment1    : 40 studs directly above
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
                       ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
                     })
    Width0         : 1.2
    Width1         : 0.3
    Transparency   : NumberSequence.new(0, 0.4)
    FaceCamera     : true
    LightInfluence : 0
    Lifetime:
      Appear       : fade in over 0.25s (tween Transparency → visible)
      Hold         : 0.5s + descent time
      Fade         : 0.4s after landing

  Beam glow particles (along beam, high above):
    Texture        : sparkles_main.dds
    Color          : golden (255, 220, 80)
    Rate           : 25 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.5, 1.2)
    Speed          : NumberRange.new(2, 8)
    SpreadAngle    : Vector2.new(10, 10)
    EmissionDir    : Enum.NormalId.Bottom
    Size           : NumberSequence.new(0.15, 0.45)
    LightEmission  : 0.85

  Descent motion:
    Duration       : 0.9s
    Start          : target + Vector3.new(0, 20, 0)
    EasingStyle    : Quad In (accelerating drop)
    No spiral — straight vertical

  Landing impact:
    Ground ring (8 beams radiating outward):
      Count        : 8
      Width0       : 0.4
      Width1       : 0.06
      Length        : 5 studs
      Color        : legendary rarity color
      Duration     : 0.7s

    Shockwave particles:
      Emit count   : 50 * lodBurstMul()
      Texture      : sparkles_main.dds
      Color        : ColorSequence.new({
                       ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
                       ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
                     })
      Lifetime     : NumberRange.new(0.3, 0.7)
      Speed        : NumberRange.new(14, 32)
      SpreadAngle  : Vector2.new(180, 180)
      Acceleration : Vector3.new(0, -20, 0)

    Dust cloud at feet:
      Emit count   : 16 * lodBurstMul()
      Texture      : smoke_main.dds
      Color        : Color3.fromRGB(200, 180, 140)
      Lifetime     : NumberRange.new(0.4, 0.8)
      Speed        : NumberRange.new(4, 10)
      SpreadAngle  : Vector2.new(60, 30)
      EmissionDir  : horizontal outward

  Confetti shower (camera-attached):
    Emit count     : 28 * lodBurstMul()
    Color          : golden
    Lifetime       : NumberRange.new(0.8, 1.4)
    Speed          : NumberRange.new(8, 24)
    Acceleration   : Vector3.new(0, -35, 0)

  Screen flash:
    Color          : Color3.fromRGB(255, 220, 100)
    Duration       : 0.3s
    Peak transp.   : 0.42

  Camera shake:
    Intensity      : 0.35
    Duration       : 0.25s

  Camera FOV punch:
    FOV += 6, tween back over 0.3s (Quad Out)

  Sound sequence:
    t=0.0s : "pet_equip_legendary_beam"
             (ethereal descending tone, sustained, ~1.2s)
    t=0.9s : "pet_equip_legendary_impact"
             (heavy bass impact + metallic ring, ~0.5s)
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  MYTHIC — Reality-tear effect, rainbow explosion, slow-motion pause
────────────────────────────────────────────────────────────────────────────────
  The most dramatic entrance. A 0.5s slow-motion hitstop freezes the world,
  a "reality tear" distortion ripples across the screen, then the pet
  explodes into existence with a full rainbow particle tornado.

  Phase 1 — Reality Tear (0–0.5s):
    Screen overlay (ScreenGui frame):
      Size           : UDim2.fromScale(1, 1)
      BackgroundColor: Color3.new(0, 0, 0)
      BackgroundTransparency: tween 1→0.6→1 (pulse) over 0.3s
      ZIndex         : 1100

    Distortion lines (4–6 horizontal Frame strips):
      Height         : 2–6px each (random)
      Width          : UDim2.fromScale(1, 0)
      BackgroundColor: Color3.new(1, 1, 1)
      Transparency   : 0.3
      Positions      : random Y between 0.2 and 0.8
      Animation      : slide X from -0.5 to 1.5 over 0.15s each, staggered
      Destroy after  : 0.3s

    Sound: "pet_equip_mythic_tear"
      (deep sub-bass rumble + glass-crack sfx, ~0.5s)

    Time dilation visual:
      If in run: freeze speed trail Rate to 0 for 0.5s
      Camera: freeze CFrame for 0.5s (override RenderStepped)

  Phase 2 — Rainbow Explosion (0.5–1.5s):
    Pet model scales from 0.01 → 1.15 over 0.25s (Back Out), then 1.15 → 1.0
    over 0.15s (Quad Out).

    Core rainbow burst (Attachment on pet PrimaryPart):
      Emit count     : 80 * lodBurstMul()
      Texture        : sparkles_main.dds
      Color          : mythicRainbowSequence()
      Lifetime       : NumberRange.new(0.4, 1.0)
      Speed          : NumberRange.new(14, 38)
      SpreadAngle    : Vector2.new(180, 180)
      Size           : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.2),
                         NumberSequenceKeypoint.new(0.4, 0.65),
                         NumberSequenceKeypoint.new(1, 0.08),
                       })
      LightEmission  : 0.9
      Acceleration   : Vector3.new(0, -15, 0)
      Drag           : 0.4

    Tornado wisps (smoke, orbiting):
      Emit count     : 30 * lodBurstMul()
      Texture        : smoke_main.dds
      Color          : mythicRainbowSequence()
      Lifetime       : NumberRange.new(0.6, 1.4)
      Speed          : NumberRange.new(4, 12)
      SpreadAngle    : Vector2.new(360, 90)
      RotSpeed       : NumberRange.new(-120, 120)
      Size           : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 0.4),
                         NumberSequenceKeypoint.new(0.5, 0.9),
                         NumberSequenceKeypoint.new(1, 0.15),
                       })
      Transparency   : NumberSequence.new(0.25, 1)
      LightEmission  : 0.5

    Lightning bolts:
      Emit count     : 20 * lodBurstMul()
      Texture        : sparkles_main.dds
      Color          : Color3.new(1, 1, 1)
      Lifetime       : NumberRange.new(0.04, 0.12)
      Speed          : NumberRange.new(20, 48)
      SpreadAngle    : Vector2.new(45, 45)
      LightEmission  : 1.0

    Confetti shower (camera-attached, from above):
      Emit count     : 45 * lodBurstMul()
      Color          : mythicRainbowSequence()
      Lifetime       : NumberRange.new(0.8, 1.6)
      Speed          : NumberRange.new(10, 28)
      Acceleration   : Vector3.new(0, -40, 0)

  Phase 3 — Screen Overlay + Camera (0.5–1.2s):
    Screen flash sequence:
      t=0.50s: white flash, duration 0.12s, peak transparency 0.35
      t=0.55s: rainbow tinted flash (cycle BackgroundColor3 through
               mythicRainbowSequence keypoints), duration 0.4s, peak 0.25

    Screen-edge rainbow border (UIStroke on full-screen Frame):
      Thickness      : 8
      Color gradient : mythicRainbowSequence()
      Rotation anim  : 120°/s for 2.5s
      Transparency   : 0.1 → 1 over 2.5s
      Destroy after  : 3s

    Camera shake:
      Intensity      : 0.5
      Duration       : 0.35s

    Camera FOV punch:
      FOV += 12, tween back over 0.45s (Quad Out)

  Sound sequence:
    t=0.0s : "pet_equip_mythic_tear" (sub-bass + crack)
    t=0.5s : "pet_equip_mythic_explosion"
             (massive reverb boom + ascending chime cascade, ~1.2s)
    t=0.7s : "hatch_mythic" (reuse existing mythic hatch sfx for familiarity)
]]


--[[
================================================================================
  SECTION B — RARITY SHOWCASE AURA (Persistent Effects)
================================================================================
  These effects remain active while a pet is equipped. They replace the
  current petOrbitGlow particle sets for Epic, Legendary, and Mythic tiers.
  Common, Uncommon, and Rare keep their existing PointLight + basic motes.

  All auras attach to an Attachment named "DACVFX_PetAura" on pet PrimaryPart.
  The existing "DACVFX_PetGlow" Attachment and PointLight remain unchanged.

  LOD gating:
    lodTier 1 (low)  : aura disabled entirely (just PointLight)
    lodTier 2 (mid)  : reduced Rate (0.6x multiplier), no secondary layers
    lodTier 3 (high) : full effect
================================================================================
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  EPIC AURA — Subtle purple energy wisps orbiting the pet
────────────────────────────────────────────────────────────────────────────────
  A ring of translucent purple wisps slowly orbits the pet model.

  Wisp emitter (persistent, on "DACVFX_PetAura" Attachment):
    Texture        : smoke_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0,   Color3.fromRGB(180,  60, 255)),
                       ColorSequenceKeypoint.new(0.4, Color3.fromRGB(140,  40, 210)),
                       ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 100, 255)),
                     })
    Rate           : 3.5 * lodTrailRateMul()
    Lifetime       : NumberRange.new(1.2, 2.5)
    Speed          : NumberRange.new(0.8, 2.5)
    SpreadAngle    : Vector2.new(360, 45)
    Size           : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.15),
                       NumberSequenceKeypoint.new(0.4, 0.4),
                       NumberSequenceKeypoint.new(1, 0.08),
                     })
    Transparency   : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.6),
                       NumberSequenceKeypoint.new(0.3, 0.35),
                       NumberSequenceKeypoint.new(1, 1),
                     })
    LightEmission  : 0.45
    RotSpeed       : NumberRange.new(-25, 25)
    Drag           : 1.5

  Sparkle accent emitter (small bright motes interspersed):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new(Color3.fromRGB(220, 180, 255))
    Rate           : 1.5 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.4, 0.9)
    Speed          : NumberRange.new(0.5, 2)
    SpreadAngle    : Vector2.new(180, 180)
    Size           : NumberSequence.new(0.04, 0.15)
    LightEmission  : 0.8

  PointLight enhancement (replaces base epic settings):
    Brightness     : 1.1  (unchanged)
    Color          : Color3.fromRGB(168, 85, 247)  (unchanged)
    Range          : 10   (unchanged)
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  LEGENDARY AURA — Golden ring halo + light beams
────────────────────────────────────────────────────────────────────────────────
  A golden halo ring hovers above the pet with soft light beams radiating
  downward. Makes the pet look "chosen" / divine.

  Halo ring (simulated via a ParticleEmitter with tight vertical spread):
    Texture        : sparkles_main.dds
    Color          : ColorSequence.new({
                       ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200,  50)),
                       ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
                     })
    Rate           : 12 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.4, 0.8)
    Speed          : NumberRange.new(2, 5)
    SpreadAngle    : Vector2.new(360, 5)
    EmissionDir    : Enum.NormalId.Top
    Size           : NumberSequence.new(0.06, 0.2)
    LightEmission  : 0.85
    Drag           : 3
    Note: Attachment positioned at pet center + Vector3.new(0, 2, 0) so the
    ring orbits above the pet's head.

  Light beams (3 Beam instances, evenly spaced, rotating slowly):
    Attachment0    : halo attachment (above pet)
    Attachment1    : 6 studs below halo (roughly at pet feet)
    Angles         : 0°, 120°, 240° — offset 1 stud from center
    Width0         : 0.35
    Width1         : 0.15
    Color          : ColorSequence.new(Color3.fromRGB(255, 220, 100))
    Transparency   : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.4),
                       NumberSequenceKeypoint.new(0.5, 0.65),
                       NumberSequenceKeypoint.new(1, 1),
                     })
    FaceCamera     : true
    LightInfluence : 0

    Rotation animation (per-frame RenderStepped):
      Angular speed : 15°/s
      Update each beam's Attachment1 offset:
        x = cos(angle + time * 15°) * 1
        z = sin(angle + time * 15°) * 1

  Ambient golden motes (existing petOrbitGlow motes but enhanced):
    Rate           : 4 * lodTrailRateMul()
    Color          : golden (255, 200, 50)
    Lifetime       : NumberRange.new(0.5, 1.2)
    Speed          : NumberRange.new(0.5, 3)

  PointLight enhancement:
    Brightness     : 1.5 (up from 1.3)
    Color          : Color3.fromRGB(255, 200, 50)
    Range          : 14
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  MYTHIC AURA — Full rainbow particle tornado + screen-edge glow
────────────────────────────────────────────────────────────────────────────────
  The ultimate flex. A swirling rainbow tornado of particles orbits the pet,
  and when any player's camera is within 50 studs, a subtle screen-edge glow
  tints the viewer's periphery.

  Rainbow tornado emitter (primary layer):
    Texture        : sparkles_main.dds
    Color          : mythicRainbowSequence()
    Rate           : 8 * lodTrailRateMul()
    Lifetime       : NumberRange.new(0.6, 1.5)
    Speed          : NumberRange.new(2, 7)
    SpreadAngle    : Vector2.new(360, 60)
    Size           : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.1),
                       NumberSequenceKeypoint.new(0.4, 0.35),
                       NumberSequenceKeypoint.new(1, 0.06),
                     })
    Transparency   : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.2),
                       NumberSequenceKeypoint.new(0.5, 0.35),
                       NumberSequenceKeypoint.new(1, 1),
                     })
    LightEmission  : 0.85
    RotSpeed       : NumberRange.new(-45, 45)
    Drag           : 1.2

  Smoke wisps (secondary layer, lodTier >= 3 only):
    Texture        : smoke_main.dds
    Color          : mythicRainbowSequence()
    Rate           : 2.5
    Lifetime       : NumberRange.new(1.0, 2.5)
    Speed          : NumberRange.new(1, 4)
    SpreadAngle    : Vector2.new(360, 30)
    Size           : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.25),
                       NumberSequenceKeypoint.new(0.5, 0.6),
                       NumberSequenceKeypoint.new(1, 0.1),
                     })
    Transparency   : NumberSequence.new(0.5, 1)
    LightEmission  : 0.4
    RotSpeed       : NumberRange.new(-60, 60)

  Orbiting stars (existing orbitStars but amplified):
    Rate           : 8 * lodTrailRateMul()
    Color          : mythicRainbowSequence()
    Lifetime       : NumberRange.new(0.3, 0.8)
    Speed          : NumberRange.new(3, 10)
    SpreadAngle    : Vector2.new(360, 360)
    Size           : NumberSequence.new(0.08, 0.25)

  PointLight enhancement:
    Brightness     : 1.8
    Color          : animate hue cycle via RenderStepped:
                     Color3.fromHSV((time * 0.3) % 1, 0.6, 1)
    Range          : 16

  Screen-edge glow (local player only, when camera < 50 studs from pet):
    Implementation : a ScreenGui Frame with UIGradient, low opacity
    BackgroundColor: cycle through mythicRainbowSequence keypoints
    UIGradient:
      Transparency : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 0.55),
                       NumberSequenceKeypoint.new(0.35, 1),
                       NumberSequenceKeypoint.new(0.65, 1),
                       NumberSequenceKeypoint.new(1, 0.55),
                     })
      Rotation     : animate at 30°/s
    ZIndex         : 990 (below main VFX overlays)
    Active         : false (non-interactive)

    Distance fade formula:
      dist = (camera.CFrame.Position - pet.PrimaryPart.Position).Magnitude
      alpha = math.clamp(1 - (dist - 20) / 30, 0, 1)
      frame.BackgroundTransparency = 1 - alpha * 0.12

    If dist > 50 → alpha = 0 → fully transparent (invisible)
    At dist = 20 → full strength (0.12 opacity, very subtle)
    Between 20–50 → linear fade
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs to add to SoundConfig / SoundController:

  pet_equip_common              — soft pop/click (0.15s)
  pet_equip_uncommon            — quick whoosh + chime (0.3s)
  pet_equip_rare                — electric crackle + impact thud (0.5s)
  pet_equip_epic                — deep whorl + energy snap + reverb (0.7s)
  pet_equip_legendary_beam      — ethereal descending sustain (1.2s)
  pet_equip_legendary_impact    — heavy bass impact + metallic ring (0.5s)
  pet_equip_mythic_tear         — sub-bass rumble + glass crack (0.5s)
  pet_equip_mythic_explosion    — reverb boom + ascending chimes (1.2s)

  Existing sounds reused:
  hatch_mythic                  — layered into mythic entrance at t=0.7s
================================================================================
]]


--[[
================================================================================
  LOD TIER BUDGET SUMMARY
================================================================================

  | Rarity    | LOD 3 (High)       | LOD 2 (Mid)      | LOD 1 (Low)       |
  |-----------|--------------------|------------------|--------------------|
  | Common    | 8 sparkles         | 6 sparkles       | 4 sparkles         |
  | Uncommon  | 14 burst + trail   | 10 burst + trail | 7 burst, no trail  |
  | Rare      | 24 burst + 4 beams | 18 burst + 4 beams | 12 burst, 2 beams |
  | Epic      | 47 total + 6 beams | 35 total + 4 beams | 18 total, 0 beams |
  | Legendary | 94 total + 8 beams | 70 total + 6 beams | 35 total, 4 beams |
  | Mythic    | 175 total          | 130 total         | 65 total           |

  Aura persistent particle budget (per-pet, per-frame):
  | Rarity    | LOD 3  | LOD 2  | LOD 1  |
  |-----------|--------|--------|--------|
  | Epic      | 5/s    | 3/s    | 0      |
  | Legendary | 16/s   | 10/s   | 0      |
  | Mythic    | 18.5/s | 11/s   | 0      |

  Max equipped pets: 8. Worst case (8 mythics, LOD 3) = 148 particles/s
  from auras alone — within the existing TRAIL_BUDGET philosophy.
================================================================================
]]

return nil
