--!strict
--[[
	DAILY STREAK LOSS AVERSION — DESIGN SPEC
	=========================================
	Defines visual, audio, and psychological systems that make the
	player TERRIFIED of losing their daily streak. Loss aversion —
	the principle that losing something feels 2× worse than gaining
	the same thing — is the most powerful retention lever in
	free-to-play games. This spec weaponizes it tastefully.

	Psychology: A 5-day streak represents 5 days of INVESTMENT. The
	player doesn't just lose tomorrow's reward — they lose the SUNK
	COST of the 5 days they already played. Every system in this spec
	makes that sunk cost viscerally visible and emotionally painful
	to abandon.

	Existing state (DailyRewardPanel.luau):
	  - 7-day streak calendar with day cells
	  - Claim button with shimmer press effect
	  - Celebration overlay on claim (banner, dots, rewards cascade)
	  - DailyRewardConfig: 7 reward tiers, cycle multiplier (1.25× per cycle)
	  - Constants.DAILY_REWARD_COOLDOWN = 86400 (24h)
	  - Streak resets if player misses 2+ days (mentioned in multLabel)

	This spec adds:
	  1. Streak health indicator (time until expiry)
	  2. Streak decay visual progression (dot dimming + fire dying)
	  3. "Streak at risk" warning notifications
	  4. Streak protection monetization surface
	  5. Streak loss ceremony (when reset actually happens)
	  6. Regret-inducing "what you'll lose" preview
	  7. Return incentive after streak loss

	Reference files:
	  - DACStarterGui/DailyRewardPanel.luau (implementation target)
	  - DACReplicatedStorage/Config/DailyRewardConfig.luau
	  - DACReplicatedStorage/Config/MicrocopyConfig.luau
	  - DACReplicatedStorage/Constants.luau
	  - DACStarterGui/HUD.luau (for persistent streak indicator)
]]


--[[
================================================================================
  SECTION A — STREAK HEALTH INDICATOR
================================================================================
  A persistent mini-display on the main HUD (not just inside the
  Daily Reward panel) that shows the player's current streak status
  and countdown to expiry. The streak is ALWAYS VISIBLE — the player
  can never forget about it.

  HUD placement:
    Small frame in the top-left area, below any existing HUD elements.

  HEALTHY STATE (> 12 hours remaining):
    Frame:
      Name         : "StreakHUD"
      Size         : UDim2.fromOffset(140, 32)
      BackgroundColor3: Color3.fromRGB(25, 22, 40)
      BackgroundTransparency: 0.2
      CornerRadius : UDim.new(0, 8)

    Fire icon:
      Text         : "🔥"
      TextSize     : 16
      Position     : UDim2.new(0, 6, 0.5, 0)
      AnchorPoint  : Vector2.new(0, 0.5)

    Streak count:
      Text         : `{streak}-day streak`
      Font         : GothamBold
      TextSize     : 12
      TextColor3   : Color3.fromRGB(255, 180, 60)
      Position     : UDim2.new(0, 26, 0, 2)

    Time remaining:
      Text         : `{hours}h left`
      Font         : Gotham
      TextSize     : 10
      TextColor3   : Color3.fromRGB(160, 170, 200)
      Position     : UDim2.new(0, 26, 0, 17)

  CAUTION STATE (4–12 hours remaining):
    Time text color shifts:
      Color3.fromRGB(255, 200, 80) (warm amber)
    Fire icon gains gentle pulse:
      UIScale oscillates 1.0 ↔ 1.08, period 2s
    Border appears:
      UIStroke Color: Color3.fromRGB(255, 180, 60)
      Thickness: 1, Transparency: 0.5

  WARNING STATE (1–4 hours remaining):
    Time text color shifts:
      Color3.fromRGB(255, 120, 60) (orange-red)
    Time text changes to: `⚠ {hours}h {min}m left!`
    Fire icon pulse increases:
      UIScale oscillates 1.0 ↔ 1.12, period 1.2s
    Border intensifies:
      UIStroke Color: Color3.fromRGB(255, 100, 40)
      Thickness: 1.5, Transparency: 0.3
    Background subtly shifts:
      Color3.fromRGB(40, 25, 20) (warm, like embers cooling)

  CRITICAL STATE (< 1 hour remaining):
    Time text:
      Color3.fromRGB(255, 60, 60) (red)
      Text: `⚠ {min}m LEFT!`
      Text blinks: TextTransparency oscillates 0 ↔ 0.3 at 2 Hz
    Fire icon frantic pulse:
      UIScale oscillates 1.0 ↔ 1.15, period 0.6s
    Border alarm:
      UIStroke Color oscillates:
        Color3.fromRGB(255, 60, 40) ↔ Color3.fromRGB(255, 160, 60)
        Period: 1s
      Thickness: 2
      Transparency: 0.15
    Background:
      Color3.fromRGB(50, 20, 15) (deep ember red)
    Entire HUD element gains subtle glow:
      Outer glow Frame, BackgroundTransparency oscillates 0.8 ↔ 0.9

  EXPIRED STATE (streak lost, before claim reset):
    Fire icon:
      Text: "💨" (smoke — the fire is out)
      Desaturated, no pulse
    Streak count:
      Text: "Streak lost"
      TextColor3: Color3.fromRGB(120, 120, 140)
    Background: Color3.fromRGB(25, 25, 30) (cold, dark)
    No border glow

  TIME CALCULATION:
    local lastClaim = data.dailyReward.lastClaimTime or 0
    local deadline = lastClaim + Constants.DAILY_REWARD_COOLDOWN * 2
    local remaining = deadline - os.time()
    -- 2× cooldown: player has 48 hours, but after 24h they CAN
    -- claim again. Between 24-48h is the grace window. After 48h,
    -- streak resets. This matches "resets if you miss 2+ days."
================================================================================
]]


--[[
================================================================================
  SECTION B — STREAK DECAY VISUAL PROGRESSION
================================================================================
  As the deadline approaches, the daily reward panel's streak dots
  visually "cool down" — their fire dims, their glow fades. The
  player watches their investment literally dying.

  DOT STATE MAPPING:
    Each claimed dot transitions through visual states based on
    remaining time to deadline:

    Vibrant (> 12h remaining):
      BackgroundColor3: flameColorForDay(i) (existing bright fire color)
      UIStroke.Color: same, Transparency 0.3
      UIStroke.Thickness: 2

    Warm (4–12h remaining):
      BackgroundColor3: flameColor:Lerp(Color3.fromRGB(120, 80, 40), 0.3)
      UIStroke.Transparency: 0.5
      Glow dims by 30%

    Cooling (1–4h remaining):
      BackgroundColor3: flameColor:Lerp(Color3.fromRGB(80, 60, 50), 0.55)
      UIStroke.Color: Color3.fromRGB(160, 100, 50)
      UIStroke.Transparency: 0.65
      UIScale: dots shrink slightly to 0.9
      Subtle smoke effect: tiny gray dots (2×2px) drift upward from
        each claimed dot at 1 particle per 2s per dot

    Dying (< 1h remaining):
      BackgroundColor3: flameColor:Lerp(Color3.fromRGB(50, 45, 45), 0.75)
      UIStroke.Color: Color3.fromRGB(100, 80, 70)
      UIStroke.Transparency: 0.8
      UIScale: dots at 0.8
      Smoke increases: 1 particle per 0.8s per dot
      Dots flicker: BackgroundTransparency oscillates 0 ↔ 0.3 at 0.5 Hz
        Staggered per dot so they don't all flicker in sync.

    Dead (expired):
      BackgroundColor3: Color3.fromRGB(40, 40, 50) (gray ash)
      UIStroke: hidden
      UIScale: 0.7
      No animation — stillness communicates finality.

  FLAME HEADER:
    Above the dot row, a flame icon that tracks overall streak health:

    Healthy: "🔥" at TextSize 28, warm glow behind it
    Cooling: "🔥" shrinks to 24, glow dims
    Dying:   "🔥" shrinks to 20, flickers (TextTransparency oscillates)
    Dead:    "💨" at TextSize 24, gray tint

  FIRE HEALTH BAR:
    A thin horizontal bar below the dots that represents time remaining:

    Frame:
      Size         : UDim2.new(0.7, 0, 0, 4)
      AnchorPoint  : Vector2.new(0.5, 0)
      Position     : centered below dots
      BackgroundColor3: Color3.fromRGB(40, 40, 55)
      CornerRadius : UDim.new(0, 2)

    Fill:
      Size         : UDim2.new(remainingFraction, 0, 1, 0)
      Color based on fraction:
        > 0.5  : Color3.fromRGB(255, 180, 60) (amber)
        0.25-0.5: Color3.fromRGB(255, 120, 40) (orange)
        < 0.25 : Color3.fromRGB(255, 60, 40) (red)
        0      : empty
================================================================================
]]


--[[
================================================================================
  SECTION C — "STREAK AT RISK" WARNING NOTIFICATIONS
================================================================================
  Push-style warnings that appear outside the daily reward panel,
  during normal gameplay. These interrupt the player's attention to
  remind them their streak is dying.

  Trigger thresholds:
    6 hours remaining → first warning
    2 hours remaining → urgent warning
    30 minutes remaining → final warning

  Each warning fires once per session per threshold. Store last
  warned threshold to prevent spam.

  WARNING TOAST (in-game overlay):
    Frame appears at top of screen, slides down:
      Size         : UDim2.new(0.8, 0, 0, 56)
      AnchorPoint  : Vector2.new(0.5, 0)
      Position start: UDim2.new(0.5, 0, -0.1, 0)
      Position end : UDim2.new(0.5, 0, 0.02, 0)
      BackgroundColor3: varies by urgency
      CornerRadius : UDim.new(0, 12)
      ZIndex       : 9000 (above most UI)

    Entrance: slide down over 0.35s (Back Out)
    Hold: 4s
    Exit: slide back up over 0.25s (Quad In)

  6-HOUR WARNING (gentle):
    BackgroundColor3: Color3.fromRGB(50, 40, 20)
    UIStroke: Color3.fromRGB(255, 200, 80), Thickness 1.5

    Icon: "🔥" left side
    Title: "Your streak needs you!"
    Subtitle: `{streak}-day streak expires in {hours}h`
    Title color: Color3.fromRGB(255, 200, 80)
    Subtitle color: Color3.fromRGB(200, 190, 160)

    Sound: "notification_gentle"
      Character: soft warm chime, ~0.3s
      Non-alarming, just attention-getting.

  2-HOUR WARNING (urgent):
    BackgroundColor3: Color3.fromRGB(60, 30, 15)
    UIStroke: Color3.fromRGB(255, 120, 40), Thickness 2

    Icon: "⚠" left side
    Title: "Streak in danger!"
    Subtitle: `Claim now or lose your {streak}-day streak!`
    Title color: Color3.fromRGB(255, 120, 40)

    Sound: "notification_urgent"
      Character: two-note ascending alarm chime, ~0.35s
      More insistent than gentle warning.

    CTA button on the right:
      Text: "Claim!"
      BackgroundColor3: Color3.fromRGB(255, 180, 40)
      On click: open DailyRewardPanel

  30-MINUTE WARNING (critical):
    BackgroundColor3: Color3.fromRGB(70, 20, 15)
    UIStroke: Color3.fromRGB(255, 60, 40), Thickness 2.5
    Border pulse: UIStroke transparency oscillates 0 ↔ 0.3

    Icon: "💀" left side (skull — your streak is about to DIE)
    Title: "LAST CHANCE!"
    Subtitle: `{minutes}m until your {streak}-day streak is gone forever!`
    Title color: Color3.fromRGB(255, 60, 40)
    Title blinks: TextTransparency oscillates 0 ↔ 0.2 at 1 Hz

    Sound: "notification_critical"
      Character: sharp descending alert + bass pulse, ~0.4s
      Unmistakable urgency. The player MUST notice.

    CTA button:
      Text: "SAVE STREAK!"
      BackgroundColor3: Color3.fromRGB(255, 60, 40)
      Pulse: UIScale oscillates 1.0 ↔ 1.05
================================================================================
]]


--[[
================================================================================
  SECTION D — STREAK PROTECTION MONETIZATION
================================================================================
  A purchasable "Streak Shield" that saves the player's streak if
  they miss a day. This is the monetization payoff of all the loss
  aversion pressure — the player will PAY to avoid the pain.

  STREAK SHIELD PRODUCT (DevProductConfig):
    streak_shield = {
      id            : "streak_shield"
      name          : "Streak Shield"
      robuxPrice    : 99
      description   : "Protects your streak for 48 hours. If you miss
                       a day, your streak stays safe."
      productId     : 0
      reward        : { type = "streak_shield", hours = 48 }
    }

  SERVER LOGIC:
    When streak_shield is active (data.dailyReward.shieldExpiresAt > now):
      - If player doesn't claim within the normal deadline, streak
        does NOT reset. Instead, the shield absorbs the miss.
      - Shield expires after 48 hours or one use, whichever is first.
      - After shield absorbs a miss, it's consumed. Player must
        repurchase for future protection.

  UI — SHIELD INDICATOR IN DAILY PANEL:
    When shield is active, show a small badge on the streak HUD:

    Shield badge:
      Text         : "🛡️"
      TextSize     : 14
      AnchorPoint  : Vector2.new(1, 0)
      Position     : UDim2.new(1, -4, 0, -4) (top-right of StreakHUD)
      Gentle blue glow behind it

    In daily panel, shield status line below the calendar:
      Active: "🛡️ Streak Shield active — {hours}h remaining"
        TextColor3: Color3.fromRGB(100, 180, 255)
      Inactive: "🛡️ Get Streak Shield — 99 R$"
        TextColor3: Color3.fromRGB(160, 160, 180)
        Clickable → MarketplaceService:PromptProductPurchase

  UI — SHIELD UPSELL IN WARNINGS:
    The 2-hour and 30-minute warnings include a secondary CTA:

    "Or protect it →" link text next to the main CTA:
      TextColor3   : Color3.fromRGB(100, 180, 255)
      Font         : GothamMedium
      TextSize     : 11
      On click     : prompt streak_shield purchase

    After the 30-minute warning, if no shield and no claim:
      Show a DEDICATED shield prompt overlay:
        "Your {streak}-day streak dies in {min} minutes."
        "Protect it for just 99 R$?"
        Two buttons: [Buy Shield] [Let It Die]
        The "Let It Die" button is deliberately small (60px wide),
        gray, low-contrast. The "Buy Shield" button is large (180px),
        bright gold, pulsing.

        This is ethically the most aggressive upsell in the game.
        The player must actively choose to lose their streak.

  PRICING PSYCHOLOGY:
    99 R$ is extremely cheap relative to the perceived value of a
    multi-day streak (which took real-world DAYS to build). The low
    price point minimizes purchase friction. Players who have played
    5+ days in a row are high-engagement users — the conversion rate
    on this product should be very high.
================================================================================
]]


--[[
================================================================================
  SECTION E — STREAK LOSS CEREMONY
================================================================================
  When the streak actually resets (either because no shield was active
  or the shield was already consumed), play a brief, solemn ceremony.
  This makes the loss FEEL heavy — so the player works harder to
  prevent it next time.

  Trigger: on DataUpdate, if streak went from N > 0 to 0 (or lower
  than expected based on lastClaimTime).

  CEREMONY SEQUENCE:

  Phase 1 — Fire Goes Out (0–0.6s):
    The streak dots in the daily panel (and HUD indicator) transition
    to their dead state with a staggered extinguishing animation.

    Per dot (reverse order — last claimed dies first):
      BackgroundColor3 tween: current → Color3.fromRGB(40, 40, 50)
        Duration: 0.15s (Quad Out)
      UIScale tween: current → 0.7
        Duration: 0.20s (Quad In)
      Spawn smoke puff: 3 small gray dots (3×3px) drift upward
        Color: Color3.fromRGB(100, 100, 110)
        Speed: 20–50 px/s upward
        Lifetime: 0.4s
        Transparency: 0.3 → 1

    Stagger: 0.08s per dot (total ~0.56s for 7 dots)

    Sound: "streak_extinguish"
      Character: hissing flame going out + soft sad chime, ~0.5s
      Think: candle being snuffed in a quiet room.

  Phase 2 — Loss Banner (0.5–3.0s):
    A banner appears in the daily panel:

    Frame:
      Size         : UDim2.new(0.9, 0, 0, 48)
      AnchorPoint  : Vector2.new(0.5, 0.5)
      Position     : centered in panel
      BackgroundColor3: Color3.fromRGB(35, 25, 25)
      CornerRadius : UDim.new(0, 10)

    UIStroke:
      Color        : Color3.fromRGB(120, 60, 60)
      Thickness    : 1.5
      Transparency : 0.4

    Text:
      Line 1       : "Streak lost"
      Font         : GothamBold
      TextSize     : 20
      TextColor3   : Color3.fromRGB(200, 100, 100)

      Line 2       : `You were on a {previousStreak}-day streak`
      Font         : Gotham
      TextSize     : 13
      TextColor3   : Color3.fromRGB(160, 130, 130)

    Entrance: UIScale 0 → 1.0 over 0.3s (Quad Out)
      No overshoot — the animation is somber, not bouncy.

    Hold: 2.5s
    Exit: TextTransparency 0 → 1 over 0.4s, then destroy.

  Phase 3 — Cycle Multiplier Loss Flash (if cycle resets):
    If the cycle multiplier was > 1.0 and resets:
      Flash the multLabel text:
        Old text briefly visible in gold
        Tween to new (lower) value in red
        Color: gold → Color3.fromRGB(255, 80, 80) over 0.3s
        Then settle to normal color

    This makes the player feel the COMPOUND loss — not just the
    streak, but the multiplier they built over multiple cycles.

  Phase 4 — HUD Update (immediate):
    StreakHUD transitions to Expired state (Section A).
    Fire icon swaps to smoke. Count text updates.

  SOUND:
    streak_extinguish — hissing flame out + sad chime (0.5s)
    Plays once during Phase 1. No other sounds — silence after
    the extinguish is powerful. Let the absence of sound
    communicate the loss.
================================================================================
]]


--[[
================================================================================
  SECTION F — "WHAT YOU'LL LOSE" PREVIEW
================================================================================
  Before the streak expires, while the player is in the daily reward
  panel, show a preview of what they'll lose if they don't claim.
  This makes the abstract loss concrete and painful.

  Trigger: When daily panel is open AND remaining time < 12 hours.

  PREVIEW SECTION (below calendar row, above claim button):
    Frame:
      Name         : "LossPreview"
      Size         : UDim2.new(1, -16, 0, 0)
      AutomaticSize: Y
      BackgroundColor3: Color3.fromRGB(40, 20, 20)
      BackgroundTransparency: 0.15
      CornerRadius : UDim.new(0, 10)

    UIStroke:
      Color        : Color3.fromRGB(200, 80, 60)
      Thickness    : 1
      Transparency : 0.5

    Header:
      Text         : "If you don't claim today, you'll lose:"
      Font         : GothamBold
      TextSize     : 13
      TextColor3   : Color3.fromRGB(255, 120, 80)

    Loss items (stacked):
      For each:
        TextLabel:
          Text       : `✕ {description}`
          Font       : Gotham
          TextSize   : 12
          TextColor3 : Color3.fromRGB(200, 150, 140)

    Loss items to show:
      1. `✕ Your {streak}-day streak progress`
      2. `✕ Day {nextDay} reward: {reward description}`
         (show the specific reward they'll miss)
      3. `✕ {multiplier}× cycle multiplier`
         (if cycle > 1, show the multiplier they'll lose)
      4. `✕ {daysUntilJackpot} days until JACKPOT reward`
         (if close to day 7, emphasize the jackpot they'll miss)

    At < 4 hours, add emphasis:
      Header text changes to: "⚠ You're about to lose:"
      Header color: Color3.fromRGB(255, 80, 40)
      UIStroke thickness increases to 2
      UIStroke transparency decreases to 0.3
      Subtle red pulse on the frame:
        BackgroundColor3 oscillates:
          Color3.fromRGB(40, 20, 20) ↔ Color3.fromRGB(55, 25, 20)
          Period: 2s

    At < 1 hour, add urgency:
      Header: "💀 LOSING IN {min} MINUTES:"
      All loss items flash briefly red on appear
      Frame border blinks
================================================================================
]]


--[[
================================================================================
  SECTION G — RETURN INCENTIVE AFTER STREAK LOSS
================================================================================
  After a streak resets, the player feels deflated. If we don't catch
  them, they might not come back. This section provides a "soft
  landing" that acknowledges the loss and offers a path back.

  Trigger: On first session after a streak loss (detected by comparing
  data.dailyReward.streak == 0 and previousStreak > 0).

  WELCOME BACK OVERLAY:
    ScreenGui overlay (similar to celebration but somber tone):

    Dim background:
      BackgroundTransparency: 0.45

    Banner:
      Size         : UDim2.new(0.8, 0, 0, 100)
      AnchorPoint  : Vector2.new(0.5, 0.5)
      Position     : UDim2.new(0.5, 0, 0.35, 0)
      BackgroundColor3: Color3.fromRGB(25, 25, 45)
      CornerRadius : UDim.new(0, 16)

    UIStroke:
      Color        : Color3.fromRGB(100, 140, 255)
      Thickness    : 2

    Title:
      Text         : "Welcome back!"
      Font         : GothamBold
      TextSize     : 24
      TextColor3   : Color3.fromRGB(200, 210, 255)

    Subtitle:
      Text         : "Your streak reset, but your journey continues."
      Font         : Gotham
      TextSize     : 14
      TextColor3   : Color3.fromRGB(160, 170, 200)

    Incentive card:
      Frame below banner:
        Text       : "Claim today and start a new streak! Day 1 →"
        BackgroundColor3: Color3.fromRGB(40, 60, 40)
        UIStroke color: Color3.fromRGB(80, 200, 120)

    Day 1 reward preview:
      Show the Day 1 reward below incentive card:
        Text       : `Today: +{amount} {currency}`
        TextColor3 : Color3.fromRGB(120, 255, 160)

    CTA button:
      Text         : "Start New Streak"
      BackgroundColor3: Color3.fromRGB(76, 175, 80) (green — positive)
      Size         : UDim2.new(0.6, 0, 0, 44)
      On click     : open DailyRewardPanel + dismiss overlay

    Entrance: banner slides from Y=0.2 to Y=0.35 over 0.5s (Quad Out)
    Dismiss: tap anywhere or CTA button, fade out 0.3s

    Sound: "welcome_back"
      Character: gentle ascending three-note chime, ~0.4s
      Warm and encouraging — "glad you're here" energy.
      Contrast with the streak_extinguish — this is the recovery.

  COMEBACK BONUS (optional server-side config):
    If the player returns within 24 hours of losing their streak,
    give them a small bonus on their Day 1 claim:
      +50% Day 1 rewards
    Display as: "Comeback Bonus: +50%!" badge on the Day 1 cell
    Badge color: Color3.fromRGB(80, 200, 120)

    This rewards players for coming back quickly rather than
    abandoning the game entirely. The psychological message:
    "You lost your streak, but we still value you."
================================================================================
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — STREAK LIFECYCLE
================================================================================
  A complete lifecycle of streak pressure from healthy to death:

  HEALTHY (just claimed, > 12h remaining):
    - HUD shows green/amber streak counter
    - Panel dots are vibrant with fire colors
    - No warnings, no pressure

  COOLING (4–12h):
    - HUD time text turns amber
    - Panel dots begin dimming (30% toward ash)
    - No warnings yet (don't cry wolf too early)

  FIRST WARNING (6h):
    - Gentle toast notification slides in
    - "notification_gentle" chime
    - Toast holds 4s, auto-dismisses

  ANXIOUS (4h):
    - HUD border appears, fire pulses faster
    - Panel dots at 55% dim, smoke particles begin
    - "What you'll lose" preview appears in panel

  SECOND WARNING (2h):
    - Urgent toast with CTA button
    - "notification_urgent" chime
    - Panel loss preview header changes to "⚠"

  DESPERATE (1h):
    - HUD in critical state: red text blinking
    - Panel dots at 75% dim, heavy smoke, flickering
    - Panel loss preview at maximum urgency

  FINAL WARNING (30min):
    - Critical toast with skull icon
    - "notification_critical" alarm
    - Shield upsell overlay if no shield active

  DEATH (0h — expired):
    - Streak loss ceremony fires (Section E)
    - Dots extinguish in reverse order with smoke
    - "streak_extinguish" sound
    - Loss banner appears
    - HUD transitions to expired state
    - Cycle multiplier loss flash

  NEXT SESSION (return after loss):
    - Welcome back overlay
    - "welcome_back" chime
    - Comeback bonus if within 24h
    - New streak begins fresh
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - StreakHUD update: 1 Heartbeat connection, throttled to 1/s
      (time remaining changes once per second at most)
    - Dot decay: recalculated on panel open, not continuously
    - Smoke particles: max 7 particles active (1 per dot, during
      cooling/dying states only) — cleared on panel close
    - Warning toasts: one-shot TweenService, self-cleanup
    - Shield upsell overlay: created on demand, destroyed on dismiss

  Accessibility:
    - Streak status communicated via text AND color AND icon
    - Warning toasts include text descriptions (not just color)
    - Critical warnings use both visual and audio cues
    - "Let It Die" button is small but still meets minimum 44×20px
      touch target and is clearly labeled
    - All text meets 3:1 contrast minimum

  Mobile scaling:
    - StreakHUD: on viewports < 500px, collapse to icon + count only
      (hide time remaining text, show on tap)
    - Warning toasts: full width on mobile (0.95 scale)
    - Shield overlay: full-screen modal on mobile

  Budget:
    - 1 persistent Heartbeat connection for HUD timer
    - 0-7 smoke particle Frames during decay states
    - 1-3 TweenService one-shots for warning toast lifecycle
    - 0-1 overlay ScreenGui for shield upsell
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  notification_gentle   — soft warm chime (0.3s)
                          6-hour streak warning
  notification_urgent   — two-note ascending alarm chime (0.35s)
                          2-hour streak warning
  notification_critical — sharp descending alert + bass pulse (0.4s)
                          30-minute streak warning
  streak_extinguish     — hissing flame out + sad chime (0.5s)
                          plays when streak dots die
  welcome_back          — gentle ascending three-note chime (0.4s)
                          return-after-loss greeting

  Existing sounds reused:
  click                 — CTA button interactions
  purchase              — streak shield purchase
================================================================================
]]


--[[
================================================================================
  CONFIG ADDITIONS
================================================================================

  MicrocopyConfig additions for streak warning text pools:

  MicrocopyConfig.StreakWarning6h = {
    "Don't let your streak go cold!",
    "Your streak needs a little love today.",
    "Keep the fire burning — claim your reward!",
  }

  MicrocopyConfig.StreakWarning2h = {
    "Time's running out on your streak!",
    "Your streak is fading fast — claim now!",
    "Don't lose {STREAK} days of progress!",
  }

  MicrocopyConfig.StreakWarning30m = {
    "FINAL WARNING — your streak dies in minutes!",
    "Last chance to save {STREAK} days of work!",
    "Your streak is about to be gone forever!",
  }

  MicrocopyConfig.StreakLost = {
    "The flame went out. Time to start again.",
    "Every legend starts from Day 1.",
    "Your comeback story begins now.",
  }

  DevProductConfig addition:
    streak_shield (see Section D for full definition)
================================================================================
]]

return nil
