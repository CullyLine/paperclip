--!strict
--[[
	PAYOUT PANEL — DRAMATIC MOMENTS DESIGN SPEC
	=============================================
	Defines visual direction for the run-end payout screen. Each section
	specifies exact timing, easing, colors, and particle parameters so an
	Engineer can implement without further clarification.

	Existing state (PayoutPanel.luau):
	  - Card pops in with EasingStyle.Elastic (0.4s)
	  - Coin rain is 14 gold dots falling linearly
	  - Multiplier badges scale from 0→1 with Back easing, staggered 0.08s
	  - "NEW RECORD!" badge pulses scale sinusoidally (0.85–1.15)
	  - XP bar fills via smoothstep over 0.85s

	This spec layers drama on top of that foundation. All tweens use
	TweenService unless noted as "scripted per-frame."
]]


--[[
================================================================================
  MOMENT 1 — CARD ENTRANCE WITH SLOT-MACHINE ANTICIPATION
================================================================================
  Replace the current instant elastic pop with a THREE-phase entrance:
  slot-machine pause → anticipation breath → explosive pop-in → particle shower.
  The slot-machine pause is the key enhancement — it creates a beat of
  "what did I get?" tension before anything is revealed.

  Phase A — Slot-Machine Pause (0–0.35s):  *** ENHANCED ***
    Before the card appears, a brief "drumroll" pause builds suspense.
    The screen dims and a subtle pulsing glow hints that something is coming.

    Dim overlay entrance:
      dim.BackgroundTransparency: 0.75 → 0.25 over 0.20s (Quad In)
      Faster and deeper dim than before — draws focus hard.

    Center glow hint (spawn before card):
      Frame at screen center:
        Size           : UDim2.fromOffset(60, 60)
        AnchorPoint    : Vector2.new(0.5, 0.5)
        Position       : UDim2.fromScale(0.5, 0.5)
        BackgroundColor3: Color3.fromRGB(130, 140, 220)
        BackgroundTransparency: 0.7
        CornerRadius   : UDim.new(0.5, 0) (circular)
        ZIndex         : card.ZIndex - 1

      Pulse tween (loops during pause):
        Size           : 60×60 → 90×90 → 60×60 over 0.30s (Sine InOut)
        Transparency   : 0.7 → 0.5 → 0.7 in sync
      Destroy when card pop-in starts.

    Sound: low tonal hum begins at t=0, fading in over 0.20s
      "payout_anticipation_hum"
      Character: deep sine-wave hum with slight tremolo, ~0.40s
      Builds tension — cut off sharply when card pops.

  Phase B — Anticipation Breath (0.35–0.53s):
    The card begins to materialize as a ghost silhouette.

    cardUIScale tween:
      From           : 0.3
      To             : 0.25   (pull-back — the "inhale")
      Duration       : 0.18s
      EasingStyle    : Quad
      EasingDirection: In

    cardFrame tween:
      BackgroundTransparency: 1 → 0.8  (barely visible silhouette)
      Duration       : 0.18s
      EasingStyle    : Quad

  Phase C — Pop-In (0.53–0.93s):
    cardUIScale tween:
      From           : 0.25
      To             : 1.0
      Duration       : 0.40s
      EasingStyle    : Back
      EasingDirection: Out
      Overshoot      : ~1.6 (Back easing natural overshoot)

    cardFrame tween:
      BackgroundTransparency: 0.8 → 0
      Duration       : 0.35s
      EasingStyle    : Quad
      EasingDirection: Out

  Phase D — Edge Particle Shower (0.50–1.00s):
    Particles spray inward from the card's four edges on arrival, giving
    the impression the card "burst" into existence.

    Per-edge emitter (pseudo-ParticleEmitter via scripted Frames):
      Count per edge : 8 (32 total)
      Size           : 3×3 px to 6×6 px (randomized)
      Color          : card border color glow — Color3.fromRGB(130, 140, 220)
                       with ±20 per channel random variance
      Spawn position : along each edge of the card, random offset along length
      Direction      : perpendicular inward toward card center
      Speed          : 80–160 px/s inward
      Lifetime       : 0.25–0.45s
      EasingStyle    : Quad Out (decelerate as they approach center)
      Fade           : TextTransparency 0.1 → 1 over lifetime
      Rotation       : random -30° to 30°
      Stagger        : 0–0.12s random delay per particle
      Destroy after  : 0.5s

  Sound cue at t=0.53s (pop-in start):
    "payout_card_pop"
    Character: punchy whoosh with sub-bass thump, ~0.3s
    The hum cuts out sharply at the same instant — the silence-to-pop
    transition makes the pop feel twice as powerful.
]]


--[[
================================================================================
  MOMENT 2 — MULTIPLIER BADGE CASCADE
================================================================================
  Current: badges scale from 0→1 with Back Out, staggered 0.08s.
  Enhancement: add a gold trail behind each badge as it enters, plus a
  subtle left-to-right sweep motion.

  Badge Entrance Sequence:
    Stagger delay  : 0.12s per badge (up from 0.08s for more drama)
    Base delay     : 0.45s after card pop (let the card settle first)

    Per-badge animation:
      Step 1 — Slide + Scale (0–0.30s from badge's start time):
        UIScale    : 0 → 1.15 over 0.22s (Back Out)
        Position X : offset -20px from final → final over 0.22s (Quad Out)
        This creates a subtle left-to-right sweep effect.

      Step 2 — Settle (0.22–0.35s):
        UIScale    : 1.15 → 1.0 over 0.13s (Quad Out)

    Gold trail per badge:
      Implementation: spawn 3 small gold dot Frames behind badge
      Size         : 4×4 px
      Color        : Color3.fromRGB(255, 215, 60)
      Initial pos  : badge's left edge
      Motion       : drift left + down over 0.25s (Quad Out)
                     X: badge.X - 15 to badge.X - 45 px
                     Y: badge.Y + 5 to badge.Y + 15 px
      Transparency : 0.3 → 1 over 0.25s
      Destroy after: 0.3s

  Sound cue per badge:
    "payout_badge_tick"
    Character: short metallic clink / coin tap, ~0.08s
    Pitch varies per badge: 1.0, 1.05, 1.1, 1.15, 1.2 (ascending)
    This creates an ascending musical scale as badges cascade.
]]


--[[
================================================================================
  MOMENT 3 — "NEW RECORD!" BADGE WITH ROTATING GLOW + SHIMMER
================================================================================
  Current: sinusoidal scale pulse between 1.0–1.15, period 1.5s.
  Enhancement: add a ROTATING glow ring, shimmer sweep, particle emission,
  and color pulse. The PB badge should feel like it's radiating energy.

  Scale pulse (keep existing but refine):
    Range          : 1.0 → 1.12
    Period         : 1.8s (slightly slower, more confident)
    Easing         : smoothstep-shaped sine (current is fine)

  *** ENHANCED — Rotating Glow Ring ***
  Rotating outer glow (new dedicated Frame, NOT just UIStroke):
    Spawn a container Frame behind pbBadge:
      Name           : "PBGlowRing"
      Size           : UDim2.new(1, 16, 1, 16)  (8px larger each side)
      AnchorPoint    : Vector2.new(0.5, 0.5)
      Position       : UDim2.fromScale(0.5, 0.5)
      BackgroundTransparency: 1
      ZIndex         : pbBadge.ZIndex - 1
      Parent         : pbBadge (or titleBar)

    UIStroke on glow ring:
      Thickness      : 3
      Transparency   : oscillates 0.1 ↔ 0.5
      Color          : animated via UIGradient on the UIStroke

    UIGradient on UIStroke:
      Color          : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 60, 120)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 100)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 60, 120)),
                       })
      Rotation       : animated, continuous spin
        Formula      : (os.clock() * 120) % 360  — 120°/s rotation
        This creates a sweeping gradient that orbits the badge.

    CornerRadius on glow ring: match pbBadge UICorner (UDim.new(0, 10))

  *** ENHANCED — Shimmer Sweep ***
  UIGradient shimmer on pbBadge surface:
    Transparency   : NumberSequence.new({
                       NumberSequenceKeypoint.new(0, 1),
                       NumberSequenceKeypoint.new(0.4, 0.6),
                       NumberSequenceKeypoint.new(0.5, 0.4),
                       NumberSequenceKeypoint.new(0.6, 0.6),
                       NumberSequenceKeypoint.new(1, 1),
                     })
    Color          : ColorSequence.new(Color3.new(1, 1, 1))
    Offset animation: scroll X from -1 to 1 over 2.5s, loop
    This creates a metallic shimmer sweep across the badge surface.

  Glow ring UIStroke (on pbBadge itself):
    UIStroke:
      Thickness    : 3
      Color cycle  : oscillate between two colors over the pulse period:
                     Color3.fromRGB(255, 60, 120) ↔ Color3.fromRGB(255, 140, 200)
                     Formula: Color3.fromRGB(255, 60, 120):Lerp(
                       Color3.fromRGB(255, 140, 200), pulse)
                     where pulse = 0.5 + 0.5 * sin(time * 2π / 1.8)
      Transparency : oscillate 0.15 ↔ 0.45 in sync with scale pulse

  Rotation wobble:
    pbBadge.Rotation: ±3° oscillation
    Formula        : 3 * sin(time * 2π / 2.4)  (slower than scale pulse)
    This gives a confident "wiggle" that draws the eye without being frantic.

  Sparkle emission (scripted dot-Frames, periodic):
    Every 2.2s, emit 4 small sparkle dots from the badge:
      Size         : 2×2 px to 4×4 px
      Color        : Color3.fromRGB(255, 200, 240)
      Spawn pos    : random position within the badge bounds
      Direction    : radially outward from badge center
      Speed        : 30–70 px/s
      Lifetime     : 0.35–0.55s
      Transparency : 0 → 1 over lifetime
      Destroy after: 0.6s

  Background color pulse:
    pbBadge.BackgroundColor3: oscillate between
      Color3.fromRGB(255, 60, 120) (base) ↔ Color3.fromRGB(255, 90, 150) (highlight)
    In sync with scale pulse.

  Sound: none (looping badge should be visual-only to avoid audio fatigue)
]]


--[[
================================================================================
  MOMENT 4 — RUN OF THE DAY TITLE TREATMENT
================================================================================
  When results.runOfDayCelebration == true, the title "RUN OF THE DAY!" gets
  special treatment that clearly distinguishes it from normal "Run complete!"

  Color scheme:
    Title TextColor3 changes from:
      Normal : Color3.fromRGB(255, 213, 79)   (warm gold)
      RotD   : Color3.fromRGB(255, 160, 40)   (deeper amber-orange)

    Title TextStrokeColor3:
      Color3.fromRGB(200, 80, 0)
    Title TextStrokeTransparency:
      0.55

  Animated color gradient (UIGradient on the title label):
    Color         : ColorSequence.new({
                      ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 200, 60)),
                      ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 30)),
                      ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 200, 60)),
                    })
    Offset animation: scroll horizontally at 0.3 units/s
      Formula     : UIGradient.Offset = Vector2.new(
                      0.5 * math.sin(os.clock() * 0.6), 0)
    This gives the title a warm "shimmer" effect.

  Animated border (UIStroke on the card, special for RotD):
    Swap card UIStroke to:
      Color        : Color3.fromRGB(255, 160, 40)
      Thickness    : 3  (up from 2)
      Transparency : oscillate 0.1 ↔ 0.4 over 2s period
    After payout panel closes, restore default card stroke.

  Title entrance slam (one-shot at card pop):
    Title scale   : 1.4 → 1.0 over 0.35s (Elastic Out)
    Title rotation: -5° → 0° over 0.25s (Quad Out)
    Creates a dramatic "stamp" feeling.

  Corner flame particles (4 corners of the card):
    Per corner, spawn 6 flame dot Frames:
      Size         : 4×4 px to 8×8 px
      Color        : Color3.fromRGB(255, 140, 30) with variance ±30 on G channel
      Spawn pos    : card corner
      Direction    : diagonally inward, 45° toward card center
      Speed        : 40–90 px/s
      Lifetime     : 0.4–0.7s
      Transparency : 0.2 → 1 over lifetime
      Total count  : 24 (6 per corner)
      Stagger      : 0–0.1s random delay

  *** NEW — FIREWORK BURST ***
  Full firework explosion at card center on RotD reveal:
    Triggered at t=0.55s (just after card pop-in completes).

    Firework Ring 1 (large):
      24 dot Frames emitting radially from card center:
        Size         : 4×4 px to 7×7 px (randomized)
        Color pool   : {
                         Color3.fromRGB(255, 180, 40),   -- amber
                         Color3.fromRGB(255, 100, 30),   -- orange
                         Color3.fromRGB(255, 220, 80),   -- gold
                         Color3.fromRGB(255, 255, 180),  -- white-gold
                       }
        Direction    : radially outward (360°, evenly spaced + ±8° jitter)
        Speed        : 200–400 px/s (fast burst)
        Lifetime     : 0.5–0.8s
        EasingStyle  : Quad Out (fast start, slow fade)
        Gravity      : Y velocity += 80 px/s² (dots arc downward)
        Transparency : 0 → 1 over lifetime
        Stagger      : 0–0.04s random
        Destroy after: 0.9s

    Firework Ring 2 (small, delayed):
      At t=0.70s, a second smaller burst:
        12 dots, speed 120–250 px/s
        Same color pool but biased toward white-gold
        Lifetime     : 0.35–0.55s
        Destroy after: 0.65s

    Firework flash:
      Brief white flash at card center:
        Frame 20×20 px, BackgroundColor3 = Color3.new(1, 1, 1)
        UIScale 1 → 3 over 0.08s, transparency 0 → 1 over 0.12s
        Destroy at 0.15s

  Sound cue at t=0.15s:
    "payout_run_of_day"
    Character: triumphant brass stab + shimmer tail, ~0.6s
    Think: game show "winner" sting, short and punchy

  Additional sound at t=0.55s (firework burst):
    "payout_firework"
    Character: crisp sparkle burst + soft crackle tail, ~0.4s
    Think: indoor sparkler igniting — bright but not jarring

  Screen flash override for RotD:
    Color          : Color3.fromRGB(255, 180, 40)  (amber instead of gold)
    Duration       : 0.28s  (slightly longer)
    Peak transp.   : 0.38   (slightly more opaque)
]]


--[[
================================================================================
  MOMENT 5 — BATTLE PASS TIER CROSSING CELEBRATION
================================================================================
  Triggered when the XP bar animation crosses a tier boundary. Detect by
  comparing BattlePassConfig.tierFromXp(xpBefore) vs tierFromXp(xpAfter).
  If tier changed, fire this at the moment the bar fill reaches the boundary.

  Detection logic:
    local tierBefore = BattlePassConfig.tierFromXp(xpBefore)
    local tierAfter  = BattlePassConfig.tierFromXp(xpAfter)
    if tierAfter > tierBefore then
      -- fire tier-up at the interpolation moment when xp crosses the boundary
      local boundaryXp = BattlePassConfig.xpForTier(tierBefore + 1)
      local crossFraction = (boundaryXp - xpBefore) / (xpAfter - xpBefore)
      local crossTime = dur * crossFraction  -- time within the counter anim
      task.delay(crossTime, fireTierUpCelebration)
    end

  Tier-Up Celebration:
    1. XP bar flash:
       The xpFill frame flashes white briefly.
       xpFill.BackgroundColor3 → Color3.new(1, 1, 1) instantly
       Tween back to gradient colors over 0.25s (Quad Out)
       Implementation note: since xpFill uses a UIGradient, flash the
       UIGradient.Color to all-white then tween back.

    2. "TIER UP!" badge popup:
       Spawn a TextLabel above the XP bar:
         Text           : `TIER {newTier}!`
         Font           : GothamBold
         TextSize       : 20
         TextColor3     : Color3.fromRGB(255, 220, 80)
         TextStrokeColor3: Color3.fromRGB(80, 50, 180)
         TextStrokeTransparency: 0.3
         BackgroundTransparency: 1
         AnchorPoint    : Vector2.new(0.5, 1)
         Position       : centered above xpBarBg, Y offset -8px

       Entrance:
         UIScale from 0 → 1.2 over 0.2s (Back Out)
         Then 1.2 → 1.0 over 0.1s (Quad Out)
         Position Y drift: -8px → -22px over 0.8s (Quad Out) — floats up
         TextTransparency: hold 0 for 0.6s, then 0 → 1 over 0.4s
         Destroy after 1.0s.

    3. Starburst particles around the XP bar:
       Emit 10 sparkle dot Frames from the fill point:
         Size           : 3×3 to 5×5 px
         Color          : Color3.fromRGB(180, 140, 255) and
                          Color3.fromRGB(255, 220, 80) alternating
         Spawn position : at xpFill's right edge (the crossing point)
         Direction      : radially outward (360° spread)
         Speed          : 50–120 px/s
         Lifetime       : 0.3–0.5s
         Transparency   : 0.1 → 1 over lifetime
         Destroy after  : 0.6s

    4. Camera/screen effect: none (keep it contained to the bar area)

    Sound cue:
      "payout_tier_up"
      Character: ascending chime + soft bell hit, ~0.4s
      Pitched higher for each consecutive tier crossed in the same payout
      Pitch scale: 1.0 + (tiersGained - 1) * 0.08
]]


--[[
================================================================================
  MOMENT 6 — STAT COUNTER ROLL-UP ENHANCEMENT
================================================================================
  The existing smoothstep counter is functional but flat. Add these layers:

  Digit color flash:
    As each stat label's number increases, flash the TextColor3 briefly:
      Normal color   : Color3.new(1, 1, 1)
      Flash color    : Color3.fromRGB(255, 215, 60)  (gold)
    Apply at counter start, tween back to white over the counter duration.
    Use TweenInfo.new(dur, Quad, Out) on TextColor3.

  Final value stamp:
    When the counter finishes (u >= 1):
      UIScale on each stat value label: 1.0 → 1.08 instantly
      Tween back to 1.0 over 0.15s (Quad Out)
    This gives a satisfying "lock-in" feeling.

  Coins label special treatment:
    Since coins are the primary reward, give the coins counter extra flair:
      During roll-up, the coinsLabel.TextColor3 transitions:
        Start: Color3.fromRGB(200, 200, 220)  (muted)
        End:   Color3.fromRGB(255, 215, 60)    (rich gold)
      At counter completion, briefly scale to 1.12 instead of 1.08.

  Sound: the existing coin rain provides audio. No additional sound needed.
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — FULL SEQUENCE
================================================================================
  A complete payout sequence from run end to interactive panel:

  t=0.00s  Screen flash + VFX fanfare (existing)
  t=0.00s  Dim overlay fades in FAST (0.20s, deeper than before)
  t=0.00s  Slot-machine center glow hint appears + pulsing
  t=0.00s  "payout_anticipation_hum" sound begins
  t=0.35s  Center glow destroyed, hum cuts off
  t=0.35s  Card anticipation breath starts (silhouette, 0.18s)
  t=0.53s  Card pop sound cue ("payout_card_pop") — silence→pop transition
  t=0.53s  Card pop-in starts (0.40s, Back Out)
  t=0.50s  Edge particle shower begins (staggered over 0.12s)
  t=0.53s  Coin rain begins (existing, 14 coins)
  t=0.70s  Stat counter roll-up begins (0.85s)
  t=0.70s  Stat labels flash gold
  t=0.98s  First multiplier badge enters
  t=1.10s  Second badge...  (0.12s stagger)
  t=1.22s  Third badge...
  t=1.34s  Fourth badge...
  t=1.46s  Fifth badge (if present)
  t=1.55s  Stat counter finishes, value stamp effect
  t=~Xs    XP bar crosses tier boundary → tier-up celebration
  t=1.65s  "NEW RECORD!" badge begins looping with rotating glow (if isRecord)
  ∞        PB badge: rotating gradient ring + shimmer sweep + sparkles loop
  ∞        Panel remains interactive until player clicks a button

  Total entrance sequence: ~1.65s before player can absorb all info.
  Buttons are clickable immediately after card pop (t=0.93s).

  The slot-machine pause adds ~0.35s to the total sequence but the
  emotional impact is worth it — the player feels anticipation before
  any information is revealed.

  For Run of the Day:
    Same sequence plus:
    t=0.15s  "payout_run_of_day" triumphant brass stab
    t=0.53s  RotD title slam, amber card border, corner flame particles
    t=0.55s  FIREWORK BURST — Ring 1 (24 dots, 200-400 px/s, gravity arc)
    t=0.55s  Firework center flash (white, 0.15s)
    t=0.55s  "payout_firework" sparkle burst sound
    t=0.70s  Firework Ring 2 (12 dots, smaller, white-gold bias)
    t=0.90s  Ring 1 dots begin fading
    t=1.20s  Ring 2 dots fully faded, all firework debris destroyed
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  payout_anticipation_hum  — deep sine-wave hum + tremolo (0.40s)
                             plays during slot-machine pause, cut on pop
  payout_card_pop          — punchy whoosh + sub-bass thump (0.3s)
  payout_badge_tick        — short metallic clink (0.08s), pitch varies
  payout_run_of_day        — triumphant brass stab + shimmer (0.6s)
  payout_firework          — crisp sparkle burst + crackle tail (0.4s)
  payout_tier_up           — ascending chime + bell (0.4s)

  Existing sounds reused:
  cha_ching                — already used in coin award contexts
================================================================================
]]

return nil
