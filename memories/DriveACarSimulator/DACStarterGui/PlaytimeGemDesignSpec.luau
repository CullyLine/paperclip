--!strict
--[[
	PLAYTIME GEM HUD — VISUAL DESIGN SPEC
	======================================
	Defines the visual design for the compact gem progress indicator,
	urgency escalation in the final seconds, and the gem award celebration.

	Existing state (PlaytimeGemHUD.luau):
	  - 280×44 dark frame in top-right corner
	  - Text label shows "Playtime gem in M:SS"
	  - Thin 6px progress bar fills left-to-right
	  - UIStroke pulses gold in last 10 seconds
	  - On award: text flashes bright, SoundFacade "cha_ching", VFXFacade popup

	This spec enhances each layer with specific parameters.
]]


--[[
================================================================================
  SECTION A — PROGRESS INDICATOR VISUAL TREATMENT
================================================================================
  The current thin bar is functional but visually flat. Replace with a
  layered progress system: filled gem icon + ring progress + enhanced bar.

  Layout redesign (root frame stays 280×44):

    ┌─[GemIcon 32×32]──[Label]──────────────────────┐
    │  💎              Playtime gem in 2:45           │
    │  ═══════════════════════◯                       │
    └─────────────────────────────────────────────────┘

  Gem icon (left side of root):
    Frame or ImageLabel:
      Name           : "GemIcon"
      Size           : UDim2.fromOffset(32, 32)
      Position       : UDim2.new(0, 6, 0.5, 0)
      AnchorPoint    : Vector2.new(0, 0.5)
      BackgroundTransparency: 1

    If no ImageId available, use TextLabel with gem emoji:
      Text           : "💎"
      TextSize       : 22
      TextColor3     : Color3.fromRGB(180, 100, 255)
      BackgroundTransparency: 1

    Gem fill effect (progress-driven):
      As the bar fills, the gem icon's transparency decreases:
        Transparency formula: 0.4 * (1 - progress)
        At 0% progress: gem is 40% transparent (muted)
        At 100%: fully opaque (gleaming)

      Color shift with progress:
        Start color  : Color3.fromRGB(140, 80, 200)   (muted purple)
        End color    : Color3.fromRGB(220, 160, 255)   (bright lavender)
        Formula      : startColor:Lerp(endColor, progress)

  Label repositioning:
    Move TimeLabel to the right of the gem icon:
      Position       : UDim2.new(0, 42, 0, 4)
      Size           : UDim2.new(1, -48, 0, 22)

  Progress bar enhancement:
    Increase bar height from 6px → 8px for better visibility.

    Bar fill gradient (UIGradient on barFill):
      Color          : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(140, 80, 220)),
                         ColorSequenceKeypoint.new(0.6, Color3.fromRGB(180, 100, 255)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(220, 140, 255)),
                       })
      This makes the bar feel like it's gaining energy as it fills.

    Bar glow (UIStroke on barFill):
      Thickness      : 1
      Transparency   : 0.7
      Color          : Color3.fromRGB(180, 100, 255)
      Only visible when progress > 0.3 (tween transparency 0.7 → 0.5 as
      progress goes from 0.3 → 1.0).

    Fill shimmer (subtle animated UIGradient overlay):
      A second UIGradient with Transparency keypoints creates a moving
      highlight on the filled portion:
        Transparency : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 1),
                         NumberSequenceKeypoint.new(0.45, 0.7),
                         NumberSequenceKeypoint.new(0.55, 0.7),
                         NumberSequenceKeypoint.new(1, 1),
                       })
        Offset animation: scroll X from -1 to 1 over 3s, loop
        This creates a soft "gleam" moving along the bar.
]]


--[[
================================================================================
  SECTION B — URGENCY ESCALATION (LAST 10 SECONDS)
================================================================================
  The current urgency effect is a UIStroke color oscillation. This spec
  defines a multi-layered escalation that builds excitement.

  Urgency triggers at `left <= 10` seconds and `left > 0`.

  Layer 1 — Color Shift (existing, enhanced):
    Ring stroke color oscillation (keep but improve):
      From: Color3.fromRGB(255, 200, 80) ↔ Color3.fromRGB(255, 230, 140)
      Frequency: scale with remaining time for increasing urgency
        sin(os.clock() * (8 + (10 - left) * 2))
        At 10s remaining: 8 Hz oscillation
        At 1s remaining:  26 Hz oscillation (frantic)
      Transparency: 0.15 + 0.15 * pulse  (brighter than current)

    Bar fill color override:
      barFill.BackgroundColor3 transitions to urgency colors:
        Color3.fromRGB(180, 100, 255) → Color3.fromRGB(255, 180, 60)
        Formula: normalColor:Lerp(urgencyColor, urgencyAlpha)
        urgencyAlpha = math.clamp(1 - left / 10, 0, 1)

  Layer 2 — Pulse Frequency Increase:
    Root frame scale pulse (new):
      UIScale on root frame oscillates:
        Range    : 1.0 → 1.03
        Formula  : 1 + 0.03 * pulse
        Frequency: same as stroke color (scales with remaining time)
      Subtle enough not to distract from driving but noticeable in periphery.

  Layer 3 — Glow Intensity:
    Add a glow Frame behind the root (or use UIStroke + drop shadow):
      Frame positioned behind root, slightly larger:
        Size         : UDim2.new(1, 8, 1, 8)
        Position     : UDim2.new(0, -4, 0, -4)  (centered behind)
        BackgroundColor3: Color3.fromRGB(255, 200, 60)
        BackgroundTransparency: oscillates with urgency
          Formula    : 0.85 - urgencyAlpha * 0.3 * pulse
          At 10s: faint glow (0.85 transparency)
          At 1s:  prominent glow (0.55 transparency, pulsing)
        CornerRadius : UDim.new(0, 10)
        ZIndex       : root.ZIndex - 1

  Layer 4 — Text Treatment:
    TimeLabel:
      TextColor3 shifts:
        Normal : Color3.fromRGB(200, 120, 255)
        Urgent : lerp toward Color3.fromRGB(255, 220, 80) based on urgencyAlpha
      TextSize bumps:
        Normal : 14
        At <= 5s: tween to 15 (slight size increase)
        At <= 3s: tween to 16

    When left <= 3, prepend exclamation and use countdown format:
      label.Text = `⚡ GEM IN {left}s!`
      This switches from M:SS to raw seconds for impact.

  Layer 5 — Progress Bar Urgency:
    barFill grows slightly taller in the last seconds:
      barBg.Size.Y: tween from 8px → 10px over the 10s window
      Tween back to 8px after award.

  No sound during countdown (the visual escalation is sufficient;
  audio would be annoying during an active driving run).
]]


--[[
================================================================================
  SECTION C — GEM AWARD CELEBRATION
================================================================================
  Triggered when the playtime gem notification arrives. The current behavior
  flashes the label color briefly. This spec defines a full micro-celebration
  with a signature "gem flies to currency" punch.

  Phase 1 — Flash + Burst (0–0.3s):
    Bar fill flash:
      barFill.BackgroundColor3 → Color3.new(1, 1, 1) instantly
      Tween back to normal gradient over 0.2s (Quad Out)

    Root frame flash:
      root.BackgroundColor3 → Color3.fromRGB(80, 60, 120) (bright purple)
      Tween back to Color3.fromRGB(30, 30, 50) over 0.3s (Quad Out)

    Ring stroke flash:
      ringStroke.Color → Color3.fromRGB(255, 220, 100)
      ringStroke.Transparency → 0
      Tween back to defaults over 0.35s (Quad Out)

    UIScale punch on root:
      root UIScale: 1.0 → 1.08 instantly
      Tween back to 1.0 over 0.25s (Elastic Out)

  Phase 2 — Gem Icon Celebration (0–0.6s):
    Gem icon scales up:
      GemIcon UIScale: 1.0 → 1.5 over 0.15s (Back Out)
      Then 1.5 → 1.0 over 0.2s (Quad Out)

    Gem icon spawns sparkle ring:
      8 small dot Frames emitting radially from gem center:
        Size         : 3×3 to 5×5 px
        Color        : Color3.fromRGB(220, 160, 255) and
                       Color3.fromRGB(255, 220, 100) alternating
        Direction    : radially outward (360° spread, centered on gem icon)
        Speed        : 40–90 px/s
        Lifetime     : 0.3–0.5s
        Transparency : 0.1 → 1 over lifetime
        Destroy after: 0.6s

  Phase 3 — Gem Flies to Currency (0.15–0.70s):  *** NEW — AWARD PUNCH ***
    The gem icon spawns a CLONE that flies from the HUD indicator to the
    main gem currency label in the HUD. This is the signature moment.

    Clone gem creation:
      Duplicate the GemIcon as a new TextLabel/ImageLabel:
        Name           : "FlyingGem"
        Parented to    : PlayerGui ScreenGui (so it can fly across the screen)
        Initial pos    : GemIcon.AbsolutePosition (screen-space)
        Size           : UDim2.fromOffset(32, 32)
        ZIndex         : 9500 (above everything)
        TextSize       : 22 (if TextLabel gem emoji)
        TextColor3     : Color3.fromRGB(220, 160, 255)

    Flight path:
      Target         : HUD gems currency label AbsolutePosition
                       (fetched via HUD.getCurrencyLabelPosition("gems"))
      Duration       : 0.45s
      EasingStyle    : Quad In (accelerates into the target — feels pulled)
      Position       : tween from GemIcon screen pos → HUD gems label pos

    During flight:
      UIScale        : 1.0 → 0.6 at midpoint, then 0.6 → 1.3 at arrival
                       (gem shrinks as it travels, then PUNCHES at impact)
      Rotation       : 0 → 360 over flight duration (full spin)
      Trail effect   : spawn 5 small purple dots behind the gem, staggered:
        Size         : 4×4 px → 2×2 px
        Color        : Color3.fromRGB(180, 100, 255) → Color3.fromRGB(255, 200, 100)
        Transparency : 0.3 → 1 over 0.15s each
        Position     : gem's position at spawn time, stationary once spawned

    On arrival (t≈0.60s):
      Destroy FlyingGem immediately after impact effects fire.

  Phase 4 — Shockwave Ripple at Currency Label (0.60–0.95s):  *** NEW ***
    When the flying gem lands on the HUD currency label:

    Shockwave ring:
      Spawn a circular Frame centered on the currency label:
        Name           : "GemShockwave"
        Size           : UDim2.fromOffset(10, 10)
        AnchorPoint    : Vector2.new(0.5, 0.5)
        Position       : centered on HUD gems label
        BackgroundTransparency: 1
        ZIndex         : 9400

      UIStroke on shockwave:
        Color          : Color3.fromRGB(200, 140, 255)
        Thickness      : 3
        Transparency   : 0

      Expansion tween:
        Size           : UDim2.fromOffset(10, 10) → UDim2.fromOffset(120, 120)
                         over 0.30s (Quad Out)
        UIStroke.Transparency: 0 → 1 over 0.30s (Quad Out)
        UIStroke.Thickness: 3 → 1 over 0.30s
        CornerRadius   : UDim.new(0.5, 0) (keeps it circular)
      Destroy at t=0.35s after spawn.

    Second (smaller) ring at t=0.08s delay:
      Same as above but:
        Max size       : UDim2.fromOffset(80, 80)
        Color          : Color3.fromRGB(255, 220, 100)
        Duration       : 0.25s
      Creates a layered ripple effect.

  Phase 5 — Count Overshoot Increment (0.60–1.10s):  *** NEW ***
    When the gem lands, the HUD currency count updates with overshoot:

    Overshoot number animation (scripted per-frame):
      Target value   : currentGems + 1
      Overshoot peak : currentGems + 1.8  (overshoots past real value)
      Duration       : 0.40s total

      Phase A — Overshoot (0–0.15s):
        Display value counts up: currentGems → currentGems + 1.8
        Use smoothstep easing
        Label.TextColor3: flash to Color3.fromRGB(255, 220, 100) (bright gold)

      Phase B — Settle (0.15–0.40s):
        Display value settles back: currentGems + 1.8 → currentGems + 1
        Use Elastic Out easing (bounces around final value)
        Label.TextColor3: tween back to normal over 0.25s

      Critical: always round display value to integer (math.floor).
      The overshoot briefly shows a higher number then "clicks" to the
      correct value — this creates satisfying weight.

    Label scale punch:
      HUD gems label UIScale: 1.0 → 1.25 instantly at impact
      Tween back to 1.0 over 0.30s (Elastic Out, 2 bounces)

  Phase 6 — Reward Text Popup (0.10–1.20s):
    Spawn a floating "+1 💎" label above the HUD:
      Text           : "+1 💎"
      Font           : GothamBold
      TextSize       : 18
      TextColor3     : Color3.fromRGB(255, 220, 100)
      TextStrokeColor3: Color3.fromRGB(80, 40, 160)
      TextStrokeTransparency: 0.3
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 1)
      Position start : centered above root, Y offset -4px

    Animation:
      Float up       : Y drifts from -4px to -40px over 1.0s (Quad Out)
      UIScale        : 0 → 1.15 over 0.18s (Back Out), then 1.15 → 1.0 (Quad Out)
      TextTransparency: hold 0 for 0.7s, then 0 → 1 over 0.3s
      Destroy after  : 1.1s

  Phase 7 — Reset (0.3–0.5s):
    Bar fill resets to 0 width (new cycle starts):
      barFill.Size tween: current → UDim2.new(0, 0, 1, 0) over 0.2s (Quad In)
    Urgency visuals fully reset:
      barBg height back to 8px, glow frame hidden, colors reset.

  Sound (existing + additions):
    Keep existing "cha_ching" at t=0
    Add: "gem_sparkle" at t=0.05s
      Character: bright crystalline shimmer, ~0.25s
      Think: glass wind chime + sparkle
    Add: "gem_impact" at t=0.60s (when gem lands on currency)
      Character: deep crystalline thump + resonant ring, ~0.20s
      Think: a gemstone dropping into a treasure chest — weight + sparkle
      Slightly bass-heavy to contrast with the high sparkle at t=0.05s
]]


--[[
================================================================================
  SECTION D — ANTICIPATION GLOW (APPROACHING 100%)
================================================================================
  *** NEW SECTION ***
  As the progress bar nears completion (90%+), the entire HUD element builds
  anticipation with a warm glow that says "it's almost time!"

  Trigger: progress >= 0.90 and progress < 1.0

  Layer 1 — Progress Bar Anticipation Glow:
    barFill gains a warm golden edge:
      New UIStroke on barFill (or modify existing):
        Color          : Color3.fromRGB(255, 220, 100)
        Thickness      : 2
        Transparency   : oscillates 0.3 ↔ 0.7
        Frequency      : 1.5 Hz (slow, building)
        Formula        : 0.5 + 0.2 * math.sin(os.clock() * 3 * math.pi)

    barFill shimmer accelerates:
      UIGradient offset scroll speed: normal 3s period → 1.5s period
      This makes the bar's internal shimmer noticeably faster.

  Layer 2 — Gem Icon Ready Glow:
    GemIcon gains a soft outer glow ring:
      Spawn a Frame behind GemIcon:
        Size           : UDim2.fromOffset(40, 40)  (8px larger than icon)
        AnchorPoint    : Vector2.new(0.5, 0.5)
        Position       : centered on GemIcon
        BackgroundColor3: Color3.fromRGB(220, 160, 255)
        BackgroundTransparency: oscillates 0.75 ↔ 0.90
        CornerRadius   : UDim.new(0.5, 0) (circular)
        ZIndex         : GemIcon.ZIndex - 1

    Scale pulse:
      UIScale on glow frame: 1.0 ↔ 1.12, period 1.2s
      Formula: 1 + 0.12 * (0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / 1.2))

  Layer 3 — Label Excitement:
    When progress >= 0.95:
      TimeLabel text prepends "✨ " (sparkle emoji)
      TimeLabel.TextColor3 begins oscillating:
        Normal purple ↔ Color3.fromRGB(255, 220, 140) (warm gold)
        Frequency: 2 Hz
      This visually says "GET READY!"

  Cleanup:
    All anticipation effects are removed instantly when the award fires
    (Phase 1 of Section C takes over). Also clean up if progress drops
    below 0.90 (e.g., if the timer resets for any reason).
================================================================================
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — FULL CYCLE
================================================================================

  Normal state (left > ~30s, progress < 0.90):
    - Gem icon muted, bar fills slowly, shimmer glides
    - No urgency or anticipation effects

  Anticipation zone (progress >= 0.90, left ~30s → 10s):
    t=~30s  Bar fill gets golden UIStroke glow, shimmer accelerates
    t=~30s  Gem icon gains outer glow ring with pulse
    t=~15s  Label prepends "✨ " and color oscillates (at progress >= 0.95)

  Urgency ramp (10s → 0s):
    t=10s  Ring stroke begins pulsing (8 Hz)
    t=10s  Bar color begins shifting to gold
    t=10s  Background glow frame appears
    t=10s  Root scale pulse begins
    t=5s   Label text size bumps to 15
    t=3s   Label switches to "⚡ GEM IN 3s!" format, text size 16
    t=3s   Pulse frequency at 20 Hz
    t=1s   Pulse frequency at 26 Hz, glow at peak brightness
    t=0s   Award fires — anticipation effects cleared instantly

  Award celebration (the "punch"):
    t=0.00s  Flash + burst + cha_ching sound
    t=0.05s  Gem sparkle sound
    t=0.10s  Gem icon scale punch + sparkle ring emits
    t=0.10s  "+1 💎" popup begins floating up
    t=0.15s  Flying gem clone spawns, begins flight to HUD currency
    t=0.30s  Root frame / stroke return to normal
    t=0.30s  Bar fill resets to 0
    t=0.37s  Flying gem at midpoint (shrunk to 0.6 scale)
    t=0.60s  Flying gem arrives at HUD currency label — IMPACT:
               → gem_impact sound
               → shockwave ripple expands from currency label
               → second ripple at t=0.68s
               → count overshoot: value briefly shows +1.8, settles to +1
               → currency label UIScale punches 1.0 → 1.25 → 1.0 (Elastic)
    t=0.60s  Gem icon settles to scale 1.0
    t=0.95s  Shockwave rings fully faded + destroyed
    t=1.00s  Count overshoot settles to final value
    t=1.10s  "+1 💎" popup fades and destroys

  Total celebration: ~1.1s. Non-intrusive during active driving.
  The gem-to-currency flight is the signature moment — it connects
  the progress indicator to the reward, making the payout feel EARNED.
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  gem_sparkle              — crystalline shimmer (0.25s)
  gem_impact               — deep crystalline thump + resonant ring (0.20s)
                             plays on gem landing at currency label

  Existing sounds reused:
  cha_ching                — coin/gem award (already in SoundController)
================================================================================
]]

return nil
