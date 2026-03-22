--!strict
--[[
	FAILURE FEEDBACK — VISUAL LANGUAGE DESIGN SPEC
	===============================================
	Defines a consistent "action failed" visual language across the game.
	Every failure should feel clear, informative, and non-punishing.
	Players should immediately understand WHAT failed and WHY, without
	feeling scolded.

	Design philosophy:
	  - Red = error/failure, but warm red (not harsh alarm red)
	  - Shake = rejection (the button "refuses" the action)
	  - Differentiate failure types by icon + color accent so repeat
	    players learn the visual vocabulary
	  - Keep audio short and non-harsh — a "nope" not a "WRONG"
	  - All failure feedback is 100% client-side (no server round-trip
	    needed for the visual response)

	Engineer implementation notes:
	  - Create a shared utility: FailureFeedback.fireButton(button, reason)
	  - reason is one of: "insufficient_currency", "server_error",
	    "already_owned", "level_locked", "cooldown", "generic"
	  - The utility handles button animation, icon overlay, sound, and
	    optional toast message.
]]


--[[
================================================================================
  SECTION A — BUTTON PRESS FAILURE (Universal)
================================================================================
  When any interactive button action fails, the button itself communicates
  the rejection. This is the base layer applied to ALL failure types.

  Step 1 — Red Flash (0–0.15s):
    Button.BackgroundColor3 tweens to failure red, then back:
      Flash color    : Color3.fromRGB(220, 60, 60)
      Tween to red   : 0.06s (Quad Out)
      Tween to orig  : 0.18s (Quad Out)
      Total          : 0.24s round-trip

    If button has a UIStroke:
      UIStroke.Color → Color3.fromRGB(255, 80, 80) instantly
      Tween back over 0.25s

  Step 2 — Horizontal Shake (0–0.30s):
    The button shakes left-right rapidly to signal rejection.
    Scripted per-frame (RenderStepped connection, NOT tween):

      Duration       : 0.30s
      Amplitude      : ±6 pixels, decaying linearly to 0
      Frequency      : 3 full cycles (left-right-left) in 0.30s
      Formula:
        local elapsed = os.clock() - startTime
        local t = math.clamp(elapsed / 0.30, 0, 1)
        local decay = 1 - t
        local offset = math.sin(elapsed * 10 * math.pi) * 6 * decay
        button.Position = originalPosition + UDim2.fromOffset(offset, 0)

      After 0.30s: snap button back to originalPosition exactly.
      Disconnect RenderStepped.

    Critical: store the button's original Position before starting, and
    restore it precisely when done. Don't accumulate drift.

  Step 3 — Failure Icon Flash (0–0.40s):
    A brief "✕" icon appears over the button center:
      TextLabel:
        Text           : "✕"
        Font           : GothamBold
        TextSize       : 24
        TextColor3     : Color3.fromRGB(255, 100, 100)
        TextTransparency: 0
        BackgroundTransparency: 1
        AnchorPoint    : Vector2.new(0.5, 0.5)
        Position       : UDim2.fromScale(0.5, 0.5)
        ZIndex         : button.ZIndex + 10
        Parent         : button

      Entrance:
        UIScale 0 → 1.2 over 0.1s (Back Out)
        Then 1.2 → 1.0 over 0.08s (Quad Out)

      Exit:
        TextTransparency 0 → 1 over 0.2s (Quad In), starting at t=0.2s
        Destroy at t=0.4s

  Step 4 — Input Cooldown:
    Disable the button for 0.5s after failure to prevent spam-clicking.
    button.Active = false, button.AutoButtonColor = false
    Restore after 0.5s.

  Base failure sound:
    "ui_fail"
    Character: short muted buzz / dull thud, ~0.12s
    Think: a wooden block tap — acknowledges the press happened but says "no"
    NOT a harsh buzzer. Keep it soft and non-judgmental.
]]


--[[
================================================================================
  SECTION B — "NOT ENOUGH CURRENCY" VARIANT
================================================================================
  The most common failure type. Player tried to buy something they can't
  afford. In addition to the universal button failure (Section A):

  Visual accent color:
    Flash color override: Color3.fromRGB(255, 180, 60) (amber-orange)
    instead of pure red. This communicates "not yet" rather than "error."

  Currency label pulse:
    Find the relevant currency display (coins/gems/skulls label in HUD)
    and pulse it to draw attention to the deficit:
      HUD currency label:
        TextColor3 → Color3.fromRGB(255, 80, 80) (red flash)
        UIScale    : 1.0 → 1.15 over 0.1s (Back Out)
        Then UIScale 1.15 → 1.0 over 0.15s (Quad Out)
        TextColor3 → original over 0.25s (Quad Out)

  Failure icon override:
    Instead of "✕", show the currency icon with a line through it:
      Text: "🪙" (or "💎" or "💀" depending on currency type)
      Overlay a diagonal red line (Frame rotated 45°):
        Size           : UDim2.new(1.2, 0, 0, 2)
        BackgroundColor3: Color3.fromRGB(255, 80, 80)
        AnchorPoint    : Vector2.new(0.5, 0.5)
        Position       : UDim2.fromScale(0.5, 0.5)
        Rotation       : 45
        Same entrance/exit timing as Section A Step 3.

  Toast message (optional, below button):
    Spawn a small TextLabel below the button:
      Text           : "Not enough coins!"  (or gems/skulls)
      Font           : GothamMedium
      TextSize       : 13
      TextColor3     : Color3.fromRGB(255, 180, 100)
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 0)
      Position       : below button, Y offset +4px

    Animation:
      Float down     : Y drifts +4px → +18px over 0.8s (Quad Out)
      TextTransparency: hold 0 for 0.5s, then 0 → 1 over 0.3s
      Destroy after  : 0.9s

  Sound:
    "ui_fail_currency"
    Character: descending two-note tone (high → low), ~0.18s
    Think: a coin dropping and rolling away — musical "nuh-uh"
    Pitched slightly lower than generic "ui_fail" to feel distinct.
]]


--[[
================================================================================
  SECTION C — "SERVER ERROR" VARIANT
================================================================================
  Something went wrong on the backend. Player needs to know it's not their
  fault and they can try again.

  Visual accent color:
    Flash color override: Color3.fromRGB(180, 80, 80) (muted dark red)
    This feels "systemic" rather than "your fault."

  Failure icon override:
    Instead of "✕", show a warning triangle:
      Text           : "⚠"
      TextColor3     : Color3.fromRGB(255, 200, 80)  (yellow warning)
      TextSize       : 22

  Toast message:
    Text             : "Something went wrong. Try again!"
    TextColor3       : Color3.fromRGB(220, 180, 180) (soft pink-grey)
    Same animation as Section B toast.

  Button state after error:
    Instead of 0.5s cooldown, use 1.0s cooldown (give server time).
    During cooldown, show a brief loading indicator:
      TextLabel on button:
        Text cycle   : "..." → ".." → "." → "" (0.25s per step)
        TextColor3   : Color3.fromRGB(180, 180, 200)
        Destroy when cooldown ends.

  Sound:
    "ui_fail_server"
    Character: soft static crackle + descending hum, ~0.2s
    Think: a brief radio static blip — signals technical hiccup
    Distinctly different from currency/generic failures.
]]


--[[
================================================================================
  SECTION D — "ALREADY OWNED" VARIANT
================================================================================
  Player tried to buy something they already have. This is informational,
  not an error — tone is "you're good, you already have this!"

  Visual accent color:
    Flash color override: Color3.fromRGB(80, 180, 255) (cool blue)
    Blue communicates "info" rather than failure.

  Button shake: SKIP the shake entirely for this variant.
    The action isn't rejected — the player already succeeded previously.
    Instead, do a gentle scale pulse:
      UIScale 1.0 → 1.05 over 0.12s (Quad Out), then back to 1.0

  Failure icon override:
    Instead of "✕", show a checkmark:
      Text           : "✓"
      TextColor3     : Color3.fromRGB(80, 220, 120) (green)
      TextSize       : 22

  Toast message:
    Text             : "Already owned!"
    TextColor3       : Color3.fromRGB(140, 200, 255) (light blue)
    Same float animation.

  Sound:
    "ui_already_owned"
    Character: gentle upward chime, ~0.15s
    Think: a soft confirmation bell — friendly, not an error
    Reuse "click" sound pitched up 10% if a new sound isn't available.
]]


--[[
================================================================================
  SECTION E — "LEVEL LOCKED" VARIANT
================================================================================
  Content is locked behind a level or rebirth requirement. Player needs to
  know what they need to unlock it.

  Visual accent color:
    Flash color override: Color3.fromRGB(120, 120, 140) (grey-purple)
    Muted colors signal "not available yet."

  Failure icon override:
    Text             : "🔒"
    TextColor3       : Color3.fromRGB(160, 160, 180)
    TextSize         : 20

  Button dim effect:
    After the flash, button briefly dims:
      BackgroundTransparency: 0 → 0.3 over 0.15s, then back to 0 over 0.3s
    This makes the button feel temporarily "locked."

  Toast message:
    Text             : "Reach Level {X} to unlock!" or "Rebirth {X} required!"
    TextColor3       : Color3.fromRGB(180, 180, 200)

  Sound:
    "ui_fail_locked"
    Character: metallic latch/lock sound, ~0.15s
    Think: a padlock clicking shut — clear "locked" audio icon
]]


--[[
================================================================================
  SECTION F — "COOLDOWN" VARIANT
================================================================================
  Player tried to do something too quickly (rate-limited action).

  Visual accent color:
    Flash color override: Color3.fromRGB(200, 160, 80) (warm amber)

  Button shake: reduced amplitude (±3px instead of ±6px).
    The rejection is softer — "wait a moment" not "no."

  Failure icon override:
    Text             : "⏱"
    TextColor3       : Color3.fromRGB(255, 200, 100)
    TextSize         : 20

  Cooldown bar overlay (if remaining cooldown is known):
    Show a thin progress bar across the bottom of the button:
      Frame:
        Size         : UDim2.new(remainingFraction, 0, 0, 3)
        Position     : UDim2.new(0, 0, 1, -3)
        BackgroundColor3: Color3.fromRGB(255, 200, 80)
        Transparency : 0.3
      Tween Size.X.Scale from remainingFraction → 0 over remaining time.
      Destroy when cooldown ends.

  Toast message:
    Text             : "Wait {X}s!"  (if cooldown time known)
                       or "Too fast!" (if unknown)
    TextColor3       : Color3.fromRGB(255, 210, 140)

  Sound:
    "ui_fail_cooldown"
    Character: brief clock tick, ~0.1s
    Reuse any existing tick/clock sound at normal pitch.
]]


--[[
================================================================================
  SECTION G — "PURCHASE FAIL" SCENE-LEVEL MOMENT
================================================================================
  Triggered by FailureFeedback.fire("purchase_fail", context).
  Goes beyond the button-level Section B — this is a full-screen mini-event
  that communicates "you really can't afford this" with dramatic flair.

  Phase 1 — Red Vignette Flash (0–0.30s):
    Spawn a full-screen Frame parented to PlayerGui ScreenGui:
      Name           : "PurchaseFailVignette"
      Size           : UDim2.fromScale(1, 1)
      BackgroundTransparency: 1
      ZIndex         : 9000

    Inner Frame (vignette ring):
      Size           : UDim2.fromScale(1.2, 1.2)
      Position       : UDim2.fromScale(-0.1, -0.1)
      BackgroundColor3: Color3.fromRGB(180, 30, 30)
      BackgroundTransparency: 1

    Entrance:
      BackgroundTransparency: 1 → 0.65 over 0.08s (Quad Out)
      Then 0.65 → 1 over 0.22s (Quad In)

    Use a UIGradient with radial-style transparency to create vignette:
      Transparency   : NumberSequence.new({
                         NumberSequenceKeypoint.new(0, 1),
                         NumberSequenceKeypoint.new(0.55, 1),
                         NumberSequenceKeypoint.new(0.85, 0),
                         NumberSequenceKeypoint.new(1, 0),
                       })
    Destroy at t=0.35s.

  Phase 2 — Coin Drain Animation (0.05–0.55s):
    Spawn 6 coin dot TextLabels near the triggering button, animate them
    flying UP toward the currency HUD then fading out (visual "drain"):
      Text           : "●"
      TextSize       : 14
      TextColor3     : Color3.fromRGB(255, 200, 60) with ±20 per-channel variance
      AnchorPoint    : Vector2.new(0.5, 0.5)
      Initial pos    : scatter around button center, ±30px random
      ZIndex         : 9010

    Per-coin tween (staggered 0.04s):
      Position       : current → HUD currency label AbsolutePosition over 0.35s (Quad In)
      TextTransparency: 0 → 1 over last 0.12s
      UIScale        : 1.0 → 0.4 over 0.35s (Quad In) — coins shrink as they fly
      Destroy after  : 0.4s

    When first coin reaches HUD label, fire HUD.pulseCurrencyLabel(currencyType)
    with a RED flash instead of normal color.

  Phase 3 — "Not enough!" Shake Text (0.08–0.65s):
    Spawn a TextLabel centered above the button:
      Text           : "Not enough!"
      Font           : GothamBold
      TextSize       : 22
      TextColor3     : Color3.fromRGB(255, 100, 80)
      TextStrokeColor3: Color3.fromRGB(80, 20, 20)
      TextStrokeTransparency: 0.4
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 1)
      Position       : centered above button, Y offset -8px
      ZIndex         : 9010

    Entrance:
      UIScale        : 0 → 1.3 over 0.12s (Back Out)
      Then 1.3 → 1.0 over 0.08s (Quad Out)

    Horizontal shake (scripted RenderStepped, same formula as Section A):
      Duration       : 0.25s
      Amplitude      : ±4 pixels, decaying
      Frequency      : 3 cycles

    Exit:
      TextTransparency: hold 0 for 0.35s, then 0 → 1 over 0.20s
      Destroy at t=0.60s

  Sound:
    "ui_fail_purchase"
    Character: descending three-note cascade (high→mid→low) + metallic rattle, ~0.35s
    Think: coins tumbling out of a bag — reinforces the "drain" visual
    Louder and more dramatic than Section B's two-note tone.
]]


--[[
================================================================================
  SECTION H — "EQUIP FAIL" SCENE-LEVEL MOMENT
================================================================================
  Triggered by FailureFeedback.fire("equip_fail", context).
  Player tried to equip something they can't (wrong slot, locked, prerequisite).
  The item "rejects" the equip with a grey lockout pulse.

  Phase 1 — Grey Pulse Overlay (0–0.25s):
    On the triggering button (or item card Frame):
      Spawn an overlay Frame filling the button:
        BackgroundColor3: Color3.fromRGB(80, 80, 100)
        BackgroundTransparency: 0.3
        ZIndex         : button.ZIndex + 5
        CornerRadius   : match button's UICorner

    Entrance:
      BackgroundTransparency: 1 → 0.3 over 0.08s (Quad Out)
    Exit:
      BackgroundTransparency: 0.3 → 1 over 0.17s (Quad In)
    Destroy at t=0.28s.

  Phase 2 — Lock Icon Bounce (0.04–0.50s):
    Spawn a lock icon centered on the button:
      Text           : "🔒"
      TextSize       : 28
      TextColor3     : Color3.fromRGB(180, 180, 200)
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 0.5)
      Position       : UDim2.fromScale(0.5, 0.5)
      ZIndex         : button.ZIndex + 15

    Bounce animation (scripted per-frame):
      UIScale entrance: 0 → 1.4 over 0.10s (Back Out)
      Then two bounce cycles over 0.25s:
        Scale keyframes: 1.4 → 0.85 → 1.15 → 0.95 → 1.0
        Each transition 0.06s, Quad Out
      This gives the lock a "boing-boing" bounce feeling.

    Exit:
      TextTransparency: 0 → 1 over 0.15s (Quad In), starting at t=0.35s
      Destroy at t=0.50s.

  Phase 3 — Item Desaturation Flash (0–0.40s):
    If the button contains an ImageLabel (item thumbnail):
      Tween ImageColor3 toward grey to simulate desaturation:
        ImageColor3    : current → Color3.fromRGB(120, 120, 130) over 0.12s
        Then back to original over 0.28s (Quad Out)
    If no ImageLabel, skip this phase.

  Sound:
    "ui_fail_equip"
    Character: hollow metallic thunk + lock click, ~0.18s
    Think: trying to push a locked door — solid but denied
]]


--[[
================================================================================
  SECTION I — "EGG FAIL" SCENE-LEVEL MOMENT
================================================================================
  Triggered by FailureFeedback.fire("egg_fail", context).
  Player tried to hatch/buy an egg they can't afford. The egg "cracks" for a
  hopeful moment, then reforms — a tease that drives desire.

  Phase 1 — Egg Crack (0–0.25s):
    On the egg button/image:
      Spawn two hairline crack Frame lines overlaid on the egg:
        Line 1:
          Size         : UDim2.new(0, 2, 0.6, 0)
          Position     : UDim2.fromScale(0.45, 0.2)
          Rotation     : 15
          BackgroundColor3: Color3.fromRGB(255, 255, 240)
          ZIndex       : button.ZIndex + 8
        Line 2:
          Size         : UDim2.new(0, 2, 0.45, 0)
          Position     : UDim2.fromScale(0.55, 0.35)
          Rotation     : -20
          BackgroundColor3: Color3.fromRGB(255, 255, 240)
          ZIndex       : button.ZIndex + 8

    Entrance:
      Both lines: UIScale.Y 0 → 1 over 0.12s (Quad Out) — crack grows
      Slight spread: lines drift 3px apart over 0.10s

    Small particle burst from crack center:
      4 tiny white dots (3×3 px), spray outward 20–50 px/s, lifetime 0.2s
      Color: Color3.fromRGB(255, 250, 220) (eggshell white)

  Phase 2 — Egg Reform (0.25–0.55s):
    Crack lines tween back together:
      Position drift reverses over 0.15s (Quad In)
      UIScale.Y 1 → 0 over 0.15s (Quad In) — crack heals

    Egg button pulses with a warm glow:
      UIStroke spawned around button:
        Color        : Color3.fromRGB(255, 180, 80)
        Thickness    : 3
        Transparency : 0 → 1 over 0.25s (Quad Out)
        Destroy after: 0.30s

    Egg button UIScale: 1.0 → 0.92 → 1.0 over 0.20s (Quad Out)
    The reform makes the egg feel "whole again" — slightly disappointing.

  Phase 3 — "Save up!" Toast (0.15–0.90s):
    Spawn TextLabel below button:
      Text           : "Save up!"
      Font           : GothamBold
      TextSize       : 16
      TextColor3     : Color3.fromRGB(255, 200, 100)
      TextStrokeColor3: Color3.fromRGB(100, 60, 0)
      TextStrokeTransparency: 0.5
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 0)
      Position       : below button center, Y offset +6px

    Animation:
      UIScale        : 0 → 1.1 over 0.10s (Back Out), then 1.1 → 1.0
      Float down     : Y drifts +6px → +22px over 0.65s (Quad Out)
      TextTransparency: hold 0 for 0.45s, then 0 → 1 over 0.25s
      Destroy after  : 0.75s

  Sound:
    "ui_fail_egg"
    Character: ceramic crack + soft reassembly hum, ~0.30s
    Think: an egg tapping against a surface then gently being set back
    The crack sound is satisfying (player almost had it!) followed by the
    reform hum (not this time).
]]


--[[
================================================================================
  SECTION J — "FUEL EMPTY" SCENE-LEVEL MOMENT
================================================================================
  Triggered by FailureFeedback.fire("fuel_empty", context).
  Full-screen effect when the car runs out of fuel mid-run. This is the most
  dramatic failure — it interrupts gameplay.

  Phase 1 — Screen Desaturation (0–0.40s):
    Apply a full-screen desaturation overlay:
      Frame parented to PlayerGui ScreenGui:
        Name           : "FuelEmptyOverlay"
        Size           : UDim2.fromScale(1, 1)
        BackgroundColor3: Color3.fromRGB(40, 40, 50)
        BackgroundTransparency: 1
        ZIndex         : 8000

    Entrance:
      BackgroundTransparency: 1 → 0.55 over 0.30s (Quad Out)
      This drains color from the world, making everything look grey.

    Hold for context.holdDuration or 2.0s, then:
      BackgroundTransparency: 0.55 → 1 over 0.40s (Quad Out)
      Destroy after fade-out.

  Phase 2 — Vignette Darken (0.05–0.45s):
    Dark vignette ring (same technique as purchase_fail but darker):
      Inner color    : Color3.fromRGB(10, 10, 15)
      UIGradient transparency:
        NumberSequence.new({
          NumberSequenceKeypoint.new(0, 1),
          NumberSequenceKeypoint.new(0.45, 1),
          NumberSequenceKeypoint.new(0.80, 0.3),
          NumberSequenceKeypoint.new(1, 0),
        })
      Entrance: Transparency multiplier 1 → 0.4 over 0.35s
      Creates a tunnel-vision effect — the world goes dark at the edges.

  Phase 3 — Warning Klaxon Visual (0.10–1.50s):
    Pulsing amber warning bars at screen top and bottom:
      Top bar:
        Size           : UDim2.new(1, 0, 0, 6)
        Position       : UDim2.new(0, 0, 0, 0)
        BackgroundColor3: Color3.fromRGB(255, 140, 30)
      Bottom bar:
        Size           : UDim2.new(1, 0, 0, 6)
        Position       : UDim2.new(0, 0, 1, -6)
        BackgroundColor3: Color3.fromRGB(255, 140, 30)

    Pulse animation (scripted per-frame):
      BackgroundTransparency: oscillates 0.2 ↔ 0.8
      Frequency      : 4 Hz (fast warning pulse)
      Formula        : 0.5 + 0.3 * math.sin(os.clock() * 8 * math.pi)
      Duration       : 1.4s then fade out over 0.2s

    ZIndex: 8010

  Phase 4 — "FUEL EMPTY" Center Text (0.15–1.80s):
    Large warning text at screen center:
      Text           : "⛽ FUEL EMPTY"
      Font           : GothamBold
      TextSize       : 36
      TextColor3     : Color3.fromRGB(255, 160, 40)
      TextStrokeColor3: Color3.fromRGB(60, 30, 0)
      TextStrokeTransparency: 0.3
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 0.5)
      Position       : UDim2.fromScale(0.5, 0.5)
      ZIndex         : 8020

    Entrance:
      UIScale        : 0 → 1.15 over 0.15s (Back Out)
      Then 1.15 → 1.0 over 0.10s (Quad Out)

    Pulse while visible:
      UIScale oscillates 1.0 ↔ 1.04, period 0.8s
      TextColor3 oscillates toward Color3.fromRGB(255, 200, 80) and back

    Exit:
      TextTransparency: 0 → 1 over 0.30s, starting at t=1.5s
      Destroy at t=1.8s.

  Sound:
    "ui_fuel_empty"
    Character: low engine sputter + descending whine, ~0.8s
    Think: a car engine dying out — the pitch drops and trails off
    This is the longest failure sound, matching the dramatic visual.
]]


--[[
================================================================================
  SECTION K — "QUEST FAIL" SCENE-LEVEL MOMENT
================================================================================
  Triggered by FailureFeedback.fire("quest_fail", context).
  Player failed or timed out on a quest objective. The progress bar drains
  visually, and a "so close!" near-miss message fires if they were near
  completion.

  Phase 1 — Progress Bar Drain (0–0.50s):
    Locate the relevant quest progress bar (context.progressBar or the
    active quest HUD element).

    Drain animation:
      barFill.Size.X.Scale: current value → 0 over 0.45s
      EasingStyle    : Quad In (accelerates — feels like draining away)

      Color shift during drain:
        barFill.BackgroundColor3 transitions:
          Current color → Color3.fromRGB(200, 60, 60) over first 0.20s
          Then Color3.fromRGB(200, 60, 60) → Color3.fromRGB(100, 40, 40) over remaining 0.25s
        The bar turns red then darkens as it empties.

    Drain particle trail:
      As the bar shrinks, emit small red dot Frames from the fill's right edge:
        Count          : 8, staggered across the drain duration
        Size           : 3×3 px
        Color          : Color3.fromRGB(255, 80, 80)
        Direction      : drift downward + slight random X offset
        Speed          : 20–50 px/s
        Lifetime       : 0.25–0.35s
        Transparency   : 0.2 → 1 over lifetime
        Destroy after  : 0.4s

  Phase 2 — Bar Shake (0.45–0.65s):
    After drain completes, the empty bar shakes:
      Horizontal shake on barBg (same formula as Section A):
        Duration       : 0.20s
        Amplitude      : ±4 pixels
        Frequency      : 2 cycles

  Phase 3 — Near-Miss Text (0.10–0.90s):
    Determine near-miss threshold from context:
      context.progress >= 0.75 → show "So close!" text
      context.progress >= 0.90 → show "Almost had it!" text
      context.progress < 0.75  → show "Try again!" text

    Spawn TextLabel above the progress bar:
      Font           : GothamBold
      TextSize       : 18
      TextColor3     : (varies by threshold)
        >= 0.90      : Color3.fromRGB(255, 120, 80)  (hot — they were SO close)
        >= 0.75      : Color3.fromRGB(255, 180, 100) (warm — near miss)
        < 0.75       : Color3.fromRGB(200, 180, 200) (neutral — just encouragement)
      TextStrokeColor3: Color3.fromRGB(60, 20, 20)
      TextStrokeTransparency: 0.5
      BackgroundTransparency: 1
      AnchorPoint    : Vector2.new(0.5, 1)
      Position       : centered above barBg, Y offset -6px

    Entrance:
      UIScale        : 0 → 1.2 over 0.12s (Back Out)
      Then 1.2 → 1.0 over 0.08s (Quad Out)

    Float up:
      Y drifts -6px → -28px over 0.7s (Quad Out)
      TextTransparency: hold 0 for 0.5s, then 0 → 1 over 0.25s
      Destroy after  : 0.80s

  Sound:
    "ui_fail_quest"
    Character: descending slide whistle (comedic but not mocking) + soft thud, ~0.25s
    For near-miss (>= 0.75): add a brief sympathetic chime after the thud
    Think: game show "almost" sound — acknowledges effort, softens the blow
]]


--[[
================================================================================
  IMPLEMENTATION GUIDE — FailureFeedback MODULE
================================================================================
  Create: DACReplicatedStorage/FailureFeedback.luau

  Public API (two tiers):

  Tier 1 — Button-level feedback:
    FailureFeedback.fireButton(button: TextButton|ImageButton, reason: string, context: {
      currencyType: string?,     -- "coins"|"gems"|"skulls" for insufficient_currency
      requiredLevel: number?,    -- for level_locked
      requiredRebirth: number?,  -- for level_locked
      cooldownRemaining: number?, -- seconds, for cooldown
      message: string?,          -- override default toast text
    }?)

  Tier 2 — Scene-level failure moments:
    FailureFeedback.fire(feedbackType: string, context: {
      button: (TextButton|ImageButton)?, -- triggering element (optional)
      currencyType: string?,
      progressBar: Frame?,        -- for quest_fail drain target
      progress: number?,          -- 0–1, for quest_fail near-miss threshold
      holdDuration: number?,      -- seconds, for fuel_empty overlay hold
      message: string?,           -- override default text
    }?)

  Tier 1 reason values (button-level, Sections A–F):
    "insufficient_currency"  → Section B
    "server_error"           → Section C
    "already_owned"          → Section D
    "level_locked"           → Section E
    "cooldown"               → Section F
    "generic"                → Section A only

  Tier 2 feedbackType values (scene-level, Sections G–K):
    "purchase_fail"          → Section G (vignette + coin drain + shake text)
    "equip_fail"             → Section H (grey pulse + lock bounce)
    "egg_fail"               → Section I (crack + reform + save up)
    "fuel_empty"             → Section J (desaturation + vignette + klaxon)
    "quest_fail"             → Section K (bar drain + near-miss text)

  Scene-level moments can optionally chain a button-level reaction:
    If context.button is provided, fire the matching Tier 1 reaction on
    it in parallel with the scene-level effect.

  The module:
    1. Looks up the variant config by reason/feedbackType
    2. For Tier 1: applies universal button failure with variant overrides
    3. For Tier 2: runs the full scene-level animation sequence
    4. Manages cooldown/disable state
    5. Prevents stacking (if fire() called while already animating, skip)

  Anti-spam: if the same button fires failure within 0.5s of the last one,
  only play the shake (skip icon + toast + sound). This prevents visual
  clutter from rapid clicks. Scene-level moments have a 1.0s anti-spam
  window since they are more intrusive.
================================================================================
]]


--[[
================================================================================
  VISUAL LANGUAGE SUMMARY
================================================================================

  TIER 1 — Button-Level (fireButton)
  | Reason              | Accent Color       | Icon | Shake | Sound             |
  |---------------------|--------------------|------|-------|-------------------|
  | generic             | Red (220,60,60)    | ✕    | Full  | ui_fail           |
  | insufficient_currency| Amber (255,180,60)| 🪙/💎/💀| Full  | ui_fail_currency  |
  | server_error        | Dark red (180,80,80)| ⚠   | Full  | ui_fail_server    |
  | already_owned       | Blue (80,180,255)  | ✓    | None  | ui_already_owned  |
  | level_locked        | Grey (120,120,140) | 🔒   | Full  | ui_fail_locked    |
  | cooldown            | Amber (200,160,80) | ⏱    | Soft  | ui_fail_cooldown  |

  TIER 2 — Scene-Level (fire) — Mini-Events
  | Type          | Visual Signature              | Duration | Sound              |
  |---------------|-------------------------------|----------|--------------------|
  | purchase_fail | Red vignette + coin drain     | 0.65s    | ui_fail_purchase   |
  | equip_fail    | Grey pulse + lock bounce      | 0.50s    | ui_fail_equip      |
  | egg_fail      | Crack + reform + "Save up!"   | 0.90s    | ui_fail_egg        |
  | fuel_empty    | Desaturation + klaxon bars     | 1.80s    | ui_fuel_empty      |
  | quest_fail    | Bar drain + near-miss text    | 0.90s    | ui_fail_quest      |

  Shared across Tier 1:
  - Button red flash (with variant color override)
  - Input cooldown (0.5s default, 1.0s for server_error)
  - Toast message floating below button
  - Anti-spam deduplication (0.5s window)

  Shared across Tier 2:
  - Optional button-level reaction chained via context.button
  - Scene-level anti-spam (1.0s window)
  - All scene effects self-clean (Destroy after animation)
  - No two Tier 2 effects stack — second call during active effect is dropped

  Color language:
  - Red shades     = something wrong (error, rejection)
  - Amber/orange   = insufficient / wait (currency, cooldown)
  - Blue           = informational (already owned)
  - Grey           = unavailable (locked)
  - Green icon     = already succeeded (checkmark)
  - Yellow icon    = warning (triangle)
  - Desaturation   = loss of capability (fuel empty)
  - Crack lines    = almost-had-it tease (egg fail)

  Emotional design principle:
  Tier 1 says "no" to a button press. Tier 2 says "here's a MOMENT" —
  each scene-level failure should feel like a brief narrative beat, not
  just a color change. The player should remember the feedback, and it
  should motivate them to try again.
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  Tier 1 — Button-level sounds (SHORT, < 0.2s, soft):
  ui_fail                  — muted thud / wooden tap (0.12s)
  ui_fail_currency         — descending two-note tone (0.18s)
  ui_fail_server           — soft static crackle + hum (0.2s)
  ui_already_owned         — gentle upward chime (0.15s)
  ui_fail_locked           — metallic latch click (0.15s)
  ui_fail_cooldown         — clock tick (0.1s)

  Tier 2 — Scene-level sounds (MODERATE, 0.18–0.8s, more dramatic):
  ui_fail_purchase         — descending three-note cascade + rattle (0.35s)
  ui_fail_equip            — hollow metallic thunk + lock click (0.18s)
  ui_fail_egg              — ceramic crack + reassembly hum (0.30s)
  ui_fuel_empty            — engine sputter + descending whine (0.80s)
  ui_fail_quest            — descending slide whistle + thud (0.25s)
  ui_fail_quest_near       — sympathetic chime addon for near-miss (0.15s)

  Design principle: Tier 1 sounds are SHORT, SOFT, NON-HARSH — they
  acknowledge without punishing. Tier 2 sounds are longer and more
  dramatic, matching the visual scale, but still avoid harshness.
  Even fuel_empty (the loudest) should feel cinematic, not alarming.
================================================================================
]]

return nil
