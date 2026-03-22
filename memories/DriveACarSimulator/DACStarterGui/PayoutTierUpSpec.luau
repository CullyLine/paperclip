--!strict
--[[
	PAYOUT TIER-UP MOMENT — Design Spec & Config
	=============================================
	Defines the "TIER UP!" celebration that fires when the player's
	Battle Pass tier increases during a payout sequence.

	Existing state (PayoutPanel.luau):
	  - battlePassTierBeat() fires after the XP bar counter finishes
	  - It flashes the xpBarBg and scales the xpTierLabel with Elastic
	  - Sound "payout_tier_up" plays
	  - Detection: tierAfter > tierBefore (computed before counter starts)

	Problems with current implementation:
	  1. Fires AFTER the counter finishes — by then the player is already
	     reading stats and may miss it.
	  2. No dedicated badge/icon — just a bar flash + label scale.
	  3. No glow ring, no particle burst, no distinct visual landmark.
	  4. Doesn't integrate with payout flow timing (fires on task.delay
	     equal to counter duration, regardless of sequence state).

	This spec designs a proper "tier up!" ceremony that plays AFTER
	base stats finish counting, BEFORE the dismiss buttons activate.
	It owns a distinct 1.2s window in the payout choreography.

	Cross-references:
	  - PayoutPanel.luau             (implementation target)
	  - PayoutPanelDesignSpec.luau   (Moment 5, narrative rationale)
	  - BattlePassConfig.luau        (tierFromXp, xpForTier)
	  - SoundFacade.luau             (sound cue IDs)
]]


--[[
================================================================================
  TIMING INTEGRATION — WHERE IT FITS IN THE PAYOUT FLOW
================================================================================

  Existing sequence (from PayoutPanelDesignSpec):
    t=0.00s   Screen flash + VFX fanfare
    t=0.35s   Card anticipation breath
    t=0.53s   Card pop-in
    t=0.70s   Stat counter roll-up begins (0.85s duration)
    t=1.55s   Stat counter finishes

  Tier-up insertion point:
    t=1.55s   ← Stat counter finishes
    t=1.65s   ← TIER-UP MOMENT BEGINS (0.10s breath after counters)
    t=2.85s   ← Tier-up moment ends (1.2s duration)
    t=2.95s   ← Multiplier badges begin cascading
    t=3.25s   ← "NEW RECORD!" badge appears (if applicable)
    t=3.40s   ← Buttons fully active

  Detection logic (improved from current):
    Calculate the exact interpolation moment when xp crosses the
    tier boundary, so the bar visually fills to 100% at the
    celebration trigger point:

    local boundaryXp = BattlePassConfig.xpForTier(tierBefore + 1)
    local crossFraction = (boundaryXp - xpBefore) / (xpAfter - xpBefore)
    local crossTime = counterStartTime + dur * crossFraction
    task.delay(crossTime - os.clock(), fireTierUpCelebration)

  If no tier increase: skip this window entirely, badges cascade
  at t=1.65s as normal.
================================================================================
]]


--[[
================================================================================
  TIER-UP BADGE DESIGN
================================================================================
  A dedicated badge element that appears above the XP bar, distinct from
  the multiplier badges and the "NEW RECORD!" badge.

  BADGE FRAME:
    Name           : "TierUpBadge"
    AnchorPoint    : Vector2.new(0.5, 1)
    Position       : UDim2.new(0.5, 0, 0, -10)
                     (centered above xpBarBg, 10px gap)
    Size           : UDim2.fromOffset(160, 36)
    BackgroundColor: Color3.fromRGB(80, 50, 180)
    CornerRadius   : UDim.new(0, 10)
    ZIndex         : xpBarBg.ZIndex + 5
    Parent         : card (same parent as xpBarBg)

  BADGE BORDER (UIStroke):
    Thickness      : 2.5
    Color          : Color3.fromRGB(180, 140, 255)
    Transparency   : 0.15

  BADGE TEXT:
    Text           : "TIER {newTier}!"
    Font           : GothamBold
    TextSize       : 18
    TextColor3     : Color3.fromRGB(255, 220, 80)
    TextStrokeColor3: Color3.fromRGB(60, 30, 120)
    TextStrokeTransparency: 0.35

  BADGE ICON (star/chevron to the left of text):
    A small TextLabel acting as an icon:
      Text         : "★"
      Font         : GothamBold
      TextSize     : 20
      TextColor3   : Color3.fromRGB(255, 220, 80)
      Position     : UDim2.new(0, 10, 0.5, 0)
      AnchorPoint  : Vector2.new(0, 0.5)
    The star gives instant visual recognition — this is a TIER badge,
    not a multiplier badge or PB badge.
================================================================================
]]


--[[
================================================================================
  ANIMATION SEQUENCE (1.2s total)
================================================================================

  Phase A — Badge Entrance (0–0.35s):
    The badge scales up from nothing with elastic overshoot.

    t=0.00s  Badge spawns with UIScale = 0
    t=0.00s  Sound: "payout_tier_up"
    t=0.00s  UIScale: 0 → 1.25 over 0.25s (Back Out)
               The 25% overshoot makes it feel like the badge
               "punches" into existence.
    t=0.25s  UIScale: 1.25 → 1.0 over 0.10s (Quad Out)
               Quick settle to rest size.

    Badge position drift during entrance:
      Position Y : -10px → -24px over 0.25s (Quad Out)
      The badge floats upward slightly as it enters.

  Phase B — Glow Ring Pulse (0.10s–0.70s):
    A glowing ring behind the badge pulses twice, drawing the eye.

    Glow ring Frame:
      Name         : "TierUpGlow"
      Size         : UDim2.new(1, 20, 1, 14)  (10px wider, 7px taller each side)
      AnchorPoint  : Vector2.new(0.5, 0.5)
      Position     : UDim2.fromScale(0.5, 0.5)
      CornerRadius : UDim.new(0, 14)
      BackgroundColor: Color3.fromRGB(140, 100, 255)
      BackgroundTransparency: 0.5
      ZIndex       : badge.ZIndex - 1
      Parent       : badge

    Pulse 1 (t=0.10s):
      Size scale   : 1.0 → 1.25 over 0.20s (Quad Out)
      Transparency : 0.5 → 0.75 over 0.20s
    Reset (t=0.30s):
      Size scale   : 1.25 → 1.0 over 0.10s (Quad In)
      Transparency : 0.75 → 0.5 over 0.10s

    Pulse 2 (t=0.40s):
      Size scale   : 1.0 → 1.35 over 0.20s (Quad Out)
      Transparency : 0.5 → 0.85 over 0.20s
    Fade (t=0.60s):
      Size scale   : 1.35 → 1.5 over 0.10s
      Transparency : 0.85 → 1.0 over 0.10s
      Destroy at t=0.70s.

  Phase C — XP Bar Flash (0.00s–0.30s):
    The XP fill bar flashes white at the moment of tier-up.

    xpFill UIGradient.Color:
      t=0.00s  Instantly set to all-white:
               ColorSequence.new(Color3.new(1, 1, 1))
      t=0.00s  Tween back to default gradient over 0.30s (Quad Out):
               ColorSequence.new({
                 ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 100, 255)),
                 ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 220, 255)),
               })

    xpBarBg flash Frame (same as existing battlePassTierBeat):
      Color        : Color3.fromRGB(255, 245, 180)
      Size         : UDim2.new(1, 8, 1, 8)
      Transparency : 0.55 → 1 over 0.40s (Quad Out)
      Destroy at 0.45s.

    xpBarBg UIScale: 1 → 1.08 over 0.20s (Elastic Out)
      Then 1.08 → 1.0 over 0.25s (Quad Out).

  Phase D — Tier Label Update (0.05s):
    At t=0.05s, update xpTierLabel.Text to show the new tier.

    xpTierLabel UIScale: 1 → 1.15 over 0.20s (Elastic Out)
      Then 1.15 → 1.0 over 0.25s (Quad Out).
    Matches existing behavior but with slightly larger scale.

  Phase E — Starburst Particles (0.00s–0.60s):
    Sparkle dots radiate outward from the XP bar fill point.

    Spawn 12 dot Frames from xpFill's right edge:
      Size           : 3×3 to 6×6 px (randomized)
      Color pool     : {
                         Color3.fromRGB(180, 140, 255),  -- purple
                         Color3.fromRGB(255, 220, 80),   -- gold
                         Color3.fromRGB(120, 220, 255),   -- cyan
                       }
      Direction      : radially outward (360° spread)
      Speed          : 60–140 px/s
      Lifetime       : 0.35–0.55s
      Transparency   : 0.1 → 1 over lifetime
      Rotation       : random -40° to 40°
      Stagger        : 0–0.06s random delay per particle
      Destroy after  : 0.60s

  Phase F — Badge Linger + Exit (0.70s–1.20s):
    The badge holds for a beat so the player can read it, then
    floats upward and fades out gracefully.

    t=0.70s  Hold — badge visible at rest position, no motion.

    t=0.85s  Exit begins:
      Position Y   : current → -40px over 0.35s (Quad In)
      UIScale      : 1.0 → 0.7 over 0.30s (Quad In)
      TextTransparency: 0 → 1 over 0.30s
      BackgroundTransparency: 0 → 1 over 0.30s
      UIStroke Transparency: 0.15 → 1 over 0.25s

    t=1.20s  Destroy badge and all children.
================================================================================
]]


--[[
================================================================================
  MULTI-TIER CROSSING
================================================================================
  If the player crosses multiple tiers in a single payout (e.g. gains
  enough XP to jump from Tier 3 to Tier 5), play a compressed version:

  1. Fire the celebration at the FIRST boundary crossing time.
  2. Badge text cycles through each tier with a 0.4s hold per tier:
       "TIER 4!" → (0.4s) → "TIER 5!"
     Each transition: current text scales down (0.08s, Quad In),
     text updates, scales back up (0.12s, Back Out).
  3. Sound "payout_tier_up" plays once per tier crossed, pitched up:
       Pitch: 1.0 + (tierIndex * 0.06)
       Stagger: 0.4s per tier
  4. Glow ring pulses once per tier (not twice).
  5. Total duration extends by 0.4s per additional tier.
     2 tiers: 1.6s, 3 tiers: 2.0s.
  6. Starburst fires once at the first tier crossing; subsequent
     tier crossings get smaller 6-dot bursts.
================================================================================
]]


--[[
================================================================================
  COLOR PALETTE REFERENCE
================================================================================
  Badge background   : Color3.fromRGB(80, 50, 180)    — deep purple
  Badge border       : Color3.fromRGB(180, 140, 255)   — soft lavender
  Badge text         : Color3.fromRGB(255, 220, 80)    — warm gold
  Badge text stroke  : Color3.fromRGB(60, 30, 120)     — dark purple
  Glow ring          : Color3.fromRGB(140, 100, 255)   — medium purple
  XP bar flash       : Color3.fromRGB(255, 245, 180)   — warm white
  Starburst purple   : Color3.fromRGB(180, 140, 255)
  Starburst gold     : Color3.fromRGB(255, 220, 80)
  Starburst cyan     : Color3.fromRGB(120, 220, 255)

  The purple-gold palette ties into the existing XP bar gradient
  (purple→cyan) and the gold text matches the payout title color,
  creating visual cohesion within the payout card.
================================================================================
]]


--[[
================================================================================
  SOUND CUE
================================================================================
  payout_tier_up — ascending chime + soft bell hit (~0.4s)
                   Already referenced in PayoutPanel.luau.
                   Pitch scales for multi-tier: 1.0 + (n * 0.06)
================================================================================
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — FULL PAYOUT WITH TIER-UP
================================================================================

  t=0.00s   Screen flash + VFX fanfare
  t=0.00s   Dim overlay fades in
  t=0.35s   Card anticipation breath
  t=0.53s   Card pop-in + coin rain
  t=0.70s   Stat counter roll-up (0.85s)
  t=~Xs     XP bar crosses tier boundary (visual fill hits 100%)
  t=1.55s   Counter finishes, value stamp
  t=1.65s   ─── TIER-UP WINDOW OPENS ───
  t=1.65s   "payout_tier_up" sound
  t=1.65s   Badge entrance (0.25s elastic)
  t=1.65s   XP bar flash + starburst
  t=1.75s   Glow ring pulse 1
  t=2.05s   Glow ring pulse 2
  t=2.35s   Badge holds at rest
  t=2.50s   Badge exit begins (float up + fade)
  t=2.85s   Badge destroyed
  t=2.85s   ─── TIER-UP WINDOW CLOSES ───
  t=2.95s   Multiplier badges cascade (0.12s stagger)
  t=3.25s   "NEW RECORD!" badge (if applicable)
  t=3.40s   Buttons fully active

  Without tier-up:
  t=1.55s   Counter finishes
  t=1.65s   Multiplier badges cascade (skips tier-up window)
  t=1.95s   "NEW RECORD!" badge
  t=2.10s   Buttons fully active
================================================================================
]]

return nil
