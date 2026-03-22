--!strict
--[[
	STORE FOMO BADGE SYSTEM — COMPREHENSIVE DESIGN SPEC
	=====================================================
	Extends the existing FOMO badge system (StorePanel.luau, SocialFeedDesignSpec.luau)
	with new badge types, dynamic rotation, time-based urgency, and server-driven
	popularity signals.

	Existing implementation (StorePanel.luau):
	  ✓ Four badge kinds: "hot" | "low_stock" | "best_value" | "premium"
	  ✓ createFomoBadge(row, kind, copy) builds UI
	  ✓ assignFomoBadges() distributes badges across store rows
	  ✓ RenderStepped animation loop for pulse/shimmer per badge kind
	  ✓ Refreshes every 300s via task.spawn loop

	This spec adds:
	  1. Four NEW badge types: "new", "sale", "trending", "limited_edition"
	  2. Dynamic rotation system — badges shuffle on panel open
	  3. Countdown timer integration for time-limited offers
	  4. Server-driven popularity signals (purchase count broadcasts)
	  5. Badge entrance cascade animation
	  6. Mobile scaling and performance budgets

	Reference files:
	  - DACStarterGui/StorePanel.luau (existing badge implementation)
	  - DACStarterGui/SocialFeedDesignSpec.luau (Section B — existing spec)
	  - DACReplicatedStorage/Config/SocialFeedConfig.luau (copy pools)
	  - DACReplicatedStorage/Config/DevProductConfig.luau (product definitions)
	  - DACReplicatedStorage/Config/GamePassConfig.luau (pass definitions)
]]


--[[
================================================================================
  BADGE TYPE CATALOG — ALL EIGHT KINDS
================================================================================
  The system supports eight badge types. Each item can have at most ONE badge.
  Assignment priority determines which badge wins when multiple apply.

  Priority (highest → lowest):
    1. limited_edition  — rarest, manual config flag
    2. sale             — time-limited discount, server-driven
    3. new              — recently added items (<7 days)
    4. low_stock        — artificial scarcity signal
    5. hot              — social proof (purchase count)
    6. trending         — rising purchase velocity
    7. best_value       — best ratio (calculated)
    8. premium          — VIP/premium upsell

  EXISTING TYPES (refined):

  "hot"          — Red fire gradient, pulsing UIScale
                   Copy: SocialFeedConfig.SocialProofStore (with {n} fill)
                   Animation: UIScale 1.0↔1.06, UIGradient offset shimmer

  "low_stock"    — Orange warning, transparency blink
                   Copy: SocialFeedConfig.LimitedStock
                   Animation: transparency oscillation 0.05↔0.18

  "best_value"   — Green star, gentle float
                   Copy: "BEST VALUE" (static)
                   Animation: Position Y float ±1.5px

  "premium"      — Gold diamond, shimmer sweep
                   Copy: SocialFeedConfig.PremiumUpsell
                   Animation: UIGradient.Offset scroll -1→1 over 3s
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEW BADGE: "new" — Fresh Arrival
────────────────────────────────────────────────────────────────────────────────
  Applied to items added to the store in the last 7 days (server timestamp
  comparison against item's addedAt field in config).

  Colors:
    BackgroundColor3   : Color3.fromRGB(30, 120, 220)
    UIGradient.Color   : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 140, 240)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 160, 255)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(40, 140, 240)),
                         })
    UIStroke.Color     : Color3.fromRGB(100, 190, 255)

  Icon:
    Text               : "✨"
    TextSize           : 12

  Label:
    Text               : "NEW!"
    TextColor3         : Color3.new(1, 1, 1)
    Font               : GothamBlack

  Badge size           : UDim2.fromOffset(68, 22)

  Animation — sparkle pulse:
    UIScale oscillates  : 1.0 ↔ 1.05
    Frequency          : 2.5 Hz
    Formula            : 1 + 0.05 * (math.sin(os.clock() * 5 * math.pi) + 1) / 2

    UIStroke.Transparency oscillates:
      Range            : 0.1 ↔ 0.35
      Synced with scale

  Design rationale: Blue signals freshness and novelty. The sparkle icon
  and gentle pulse draw attention without competing with red "hot" badges.
  "NEW!" is universally understood as a positive discovery cue.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEW BADGE: "sale" — Time-Limited Discount
────────────────────────────────────────────────────────────────────────────────
  Applied when a server-driven sale event is active for a specific item.
  The sale config includes: discountPercent (number), expiresAt (number, UTC).

  Colors:
    BackgroundColor3   : Color3.fromRGB(220, 30, 60)
    UIGradient.Color   : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(240, 40, 70)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 100)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(240, 40, 70)),
                         })
    UIStroke.Color     : Color3.fromRGB(255, 120, 140)

  Icon:
    Text               : "🏷️"
    TextSize           : 12

  Label:
    Text               : `-{discountPercent}%` or "SALE!"
    TextColor3         : Color3.new(1, 1, 1)
    Font               : GothamBlack

  Badge size           : UDim2.fromOffset(74, 22)

  Animation — urgent flash:
    BackgroundTransparency oscillates:
      Range            : 0.02 ↔ 0.15
      Frequency        : 2 Hz (faster than low_stock — more urgent)
      Formula          : 0.02 + 0.13 * (math.sin(os.clock() * 4 * math.pi) + 1) / 2

    UIGradient.Offset scrolls:
      X                : -0.4 → 0.4 over 1.5s, ping-pong (faster than premium)

  Countdown timer sub-label (when expiresAt is set):
    Below the badge, a small TextLabel shows remaining time:
      Text             : formatCountdown(expiresAt - os.time())
                          e.g. "2h 15m" or "45m" or "< 5m!"
      Font             : GothamBold
      TextSize         : 8
      TextColor3       : Color3.fromRGB(255, 200, 200)
      Position         : UDim2.new(0.5, 0, 1, 2)
      AnchorPoint      : Vector2.new(0.5, 0)
      BackgroundTransparency: 1

    When remaining < 5 minutes:
      TextColor3       : Color3.fromRGB(255, 60, 60)
      Text blinks      : TextTransparency oscillates 0 ↔ 0.5 at 2 Hz
      Badge UIScale    : increases amplitude to 1.0 ↔ 1.10

  Design rationale: Red signals urgency. The percentage callout is
  concrete social proof of value. The countdown creates time pressure.
  The escalating animation as expiry approaches prevents the player from
  procrastinating the purchase decision.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEW BADGE: "trending" — Rising Popularity
────────────────────────────────────────────────────────────────────────────────
  Applied to items whose purchase velocity has increased significantly in
  the last hour versus their historical average. Server sends a
  "TrendingItems" periodic update with qualifying product IDs.

  Colors:
    BackgroundColor3   : Color3.fromRGB(180, 60, 200)
    UIGradient.Color   : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 80, 220)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 40, 180)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 80, 220)),
                         })
    UIStroke.Color     : Color3.fromRGB(230, 140, 255)

  Icon:
    Text               : "📈"
    TextSize           : 12

  Label:
    Text               : "TRENDING"
    TextColor3         : Color3.fromRGB(255, 230, 255)
    Font               : GothamBold

  Badge size           : UDim2.fromOffset(90, 22)

  Animation — upward drift:
    Position.Y oscillates:
      Range            : -6px ↔ -10px (4px amplitude, larger than best_value)
      Frequency        : 0.6 Hz
      Formula          : -6 + math.sin(os.clock() * 3.8) * -2

    UIGradient.Offset.X scrolls:
      -0.3 → 0.3 over 2.5s, ping-pong

  Design rationale: Purple signals exclusivity and sophistication.
  "TRENDING" implies social momentum — other players are buying this
  RIGHT NOW. The upward float animation mirrors the "rising" concept.
  Distinct from "hot" (which shows raw count) — trending shows VELOCITY.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  NEW BADGE: "limited_edition" — Exclusive Rarity
────────────────────────────────────────────────────────────────────────────────
  Applied to items manually flagged in config as limited edition. These are
  seasonal or event-exclusive items that won't return. The badge communicates
  true scarcity (unlike "low_stock" which is artificial).

  Colors:
    BackgroundColor3   : Color3.fromRGB(20, 20, 20)
    UIGradient.Color   : animated gold-to-platinum cycle:
      ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 170, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 240)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 170, 40)),
      })
    UIStroke:
      Color            : animated — lerps gold ↔ platinum over 2s
                          gold    = Color3.fromRGB(255, 210, 80)
                          platinum= Color3.fromRGB(200, 210, 230)
      Thickness        : 1.5 (thicker than other badges)
      Transparency     : 0.0 (fully visible — premium feel)

  Icon:
    Text               : "👑"
    TextSize           : 12

  Label:
    Text               : "LIMITED"
    TextColor3         : Color3.fromRGB(255, 230, 180)
    Font               : GothamBlack

  Badge size           : UDim2.fromOffset(82, 24) (slightly taller than standard)

  Animation — royal shimmer:
    UIGradient.Offset.X scrolls:
      -1.0 → 1.0 over 4s, loop (slow, dignified sweep)

    UIStroke color lerp:
      gold ↔ platinum over 2s, ping-pong
      Formula: gold:Lerp(platinum, (math.sin(os.clock() * math.pi) + 1) / 2)

    Shimmer overlay (same technique as Legendary drop banner):
      White overlay Frame, transparency 0.92
      UIGradient.Transparency highlight sweep:
        {(0,1), (0.42,0.55), (0.58,0.55), (1,1)}
      Offset: -1.5 → 1.5 over 3s, loop

  Design rationale: Black background with gold-platinum cycling communicates
  luxury and true rarity. The slow, deliberate animations contrast with the
  frantic energy of "hot" and "sale" badges. The crown icon reinforces
  exclusivity. This badge is the highest priority — when present, it
  overrides all others for that item.
]]


--[[
================================================================================
  BADGE ASSIGNMENT SYSTEM — DYNAMIC ROTATION
================================================================================
  On every StorePanel open, badges are reassigned. The algorithm balances
  urgency, variety, and information density.

  Assignment algorithm:

  Step 1 — Hard assignments (based on item flags):
    For each store item:
      if item.limitedEdition → assign "limited_edition"
      if item.saleActive and item.saleExpiresAt > os.time() → assign "sale"
      if item.addedAt and (os.time() - item.addedAt) < 604800 → assign "new"

  Step 2 — Calculated assignments:
    bestGemsProduct → assign "best_value" (existing logic)
    vipPass → assign "premium" (existing logic)

  Step 3 — Server-driven assignments:
    For each item in trendingItemList → assign "trending" (if not already assigned)
    For items in lowStockList → assign "low_stock" (if not already assigned)

  Step 4 — Social proof fill:
    From remaining unassigned items, randomly select 2–3 for "hot" badges
    (existing logic from assignFomoBadges).

  Step 5 — Cap enforcement:
    Max badges visible simultaneously: 6
    If > 6 assigned, drop lowest-priority badges until at 6.
    This prevents badge fatigue — if everything is "special", nothing is.

  ROTATION ON REOPEN:
    Each time the store panel becomes Visible = true:
      1. Recalculate hard assignments (step 1 — these are deterministic)
      2. Re-roll "hot" badge distribution (step 4 — random subset changes)
      3. Refresh countdown timers (step 1 sale badges)
    This means the player sees slightly different badge layouts each visit,
    creating a "something changed" novelty signal.

  PERIODIC REFRESH:
    Every 300s (existing timer), re-run full assignment.
    This catches newly trending items and expired sales.
================================================================================
]]


--[[
================================================================================
  BADGE ENTRANCE CASCADE
================================================================================
  When the store panel opens, badges don't all appear instantly. They
  cascade in with staggered delays for a polished, lively feel.

  Entrance sequence:
    Each badge starts with UIScale = 0, positioned at its final location.
    Stagger delay: 0.06s × badge index (sorted by row LayoutOrder)

    Per-badge entrance (from stagger offset):
      t=0.00s  UIScale: 0 → 1.15 over 0.18s (Back Out)
      t=0.18s  UIScale: 1.15 → 1.0 over 0.10s (Quad Out)

    Total cascade for 6 badges: ~0.56s (fast enough to not feel slow)

  On panel close:
    All badges immediately stop animating (disconnect RenderStepped).
    No exit animation needed — panel closes as a unit.
================================================================================
]]


--[[
================================================================================
  COUNTDOWN TIMER SYSTEM
================================================================================
  For "sale" and "low_stock" badges with time limits, a live countdown
  updates every second while the store panel is visible.

  Implementation:
    local countdownConns: { RBXScriptConnection } = {}

    function startCountdowns()
      for _, badge in activeSaleBadges do
        local conn = RunService.Heartbeat:Connect(function()
          local remaining = badge.expiresAt - os.time()
          if remaining <= 0 then
            badge.timerLabel.Text = "EXPIRED!"
            badge.timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            conn:Disconnect()
            return
          end
          badge.timerLabel.Text = formatCountdown(remaining)
        end)
        table.insert(countdownConns, conn)
      end
    end

    function stopCountdowns()
      for _, conn in countdownConns do
        conn:Disconnect()
      end
      table.clear(countdownConns)
    end

  Format rules:
    >= 1 hour  : "{H}h {M}m"
    >= 5 min   : "{M}m"
    < 5 min    : "< 5m!" (red, blinking)
    <= 0       : "EXPIRED!" (static red)

  Performance: Heartbeat fires at 60Hz but we only need to update text
  once per second. Use a frameCounter modulo to throttle:
    frameCounter += 1
    if frameCounter % 60 == 0 then updateText() end
================================================================================
]]


--[[
================================================================================
  SERVER INTEGRATION — POPULARITY SIGNALS
================================================================================
  The server broadcasts purchase signals to drive "hot" and "trending" badges.

  RemoteEvent: "StorePurchaseSignal"
  Payload: { productKey: string, buyerName: string, totalToday: number }

  Client behavior on receive:
    1. Update local purchase count cache for that productKey.
    2. If store panel is open AND that product doesn't already have a
       higher-priority badge → flash a brief "Just bought!" micro-toast
       on the relevant store row (no badge change, just social proof).
    3. If totalToday crosses a threshold (e.g. 10, 25, 50), consider
       upgrading that item to "hot" if it isn't already.

  Micro-toast (on store row, not a badge):
    Small TextLabel that appears at row right side:
      Text             : "{buyerName} just bought this!"
      Font             : GothamBold
      TextSize         : 9
      TextColor3       : Color3.fromRGB(180, 255, 180)
      BackgroundTransparency: 1
      Entrance         : fade in over 0.15s
      Hold             : 2.0s
      Exit             : fade out over 0.3s
      Destroy          : 2.5s

    Max 1 micro-toast per row. New one replaces existing.
    Max micro-toasts on screen: 2 (avoid visual noise).

  RemoteEvent: "TrendingItemsUpdate"
  Payload: { items: { string } }  — list of productKeys currently trending
  Fires every 60s from server. Client caches and uses in badge assignment.
================================================================================
]]


--[[
================================================================================
  BADGE INTERACTION — TAP-TO-EXPAND
================================================================================
  On mobile and desktop, tapping/clicking a badge expands it briefly to
  show full context. This lets badges use short labels while still
  communicating detailed info.

  Tap behavior:
    1. Badge UIScale: 1.0 → 1.25 over 0.12s (Back Out)
    2. Label text changes to expanded version:
       "HOT"           → "23 bought today!"
       "LOW STOCK"     → "Only a few left!"
       "BEST VALUE"    → "Best gems per Robux!"
       "PREMIUM"       → VIP benefit one-liner
       "NEW!"          → "Added this week!"
       "SALE!"         → "-30% for 2h 15m!"
       "TRENDING"      → "Purchases up 3x!"
       "LIMITED"       → "Won't return!"
    3. Badge width auto-expands to fit text (AutomaticSize = X)
    4. After 2.5s or next tap anywhere: revert to original label, scale back

  Sound: "ui_tick" (existing) on tap
  No tap-to-expand during badge entrance cascade (wait for cascade to finish).
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Max 6 badges with active animations (RenderStepped).
    - Animations use simple math (sin, lerp) — no tweens in the hot loop.
    - RenderStepped connection ONLY while StorePanel is visible.
    - Countdown timers throttled to 1 update/s via frame counter.
    - Micro-toasts use TweenService (one-shot, auto-cleanup).

  Accessibility:
    - Badge text meets 3:1 contrast minimum against badge background.
    - Tap-to-expand provides full context for screen readers.
    - Colorblind support: each badge has a distinct ICON in addition to
      color differentiation (fire, warning, star, diamond, sparkle, tag, chart, crown).
    - Badge animations are subtle enough to not trigger motion sensitivity.

  Mobile scaling:
    - On viewports < 600px wide: badge UIScale *= 0.75
    - On viewports < 400px wide: badge UIScale *= 0.65, hide FlexText
    - Tap-to-expand hit area: entire badge frame (no precision tap needed)

  Budget:
    - 6 RenderStepped property updates per frame (lightweight)
    - 0-2 TweenService tweens active at any time (micro-toasts)
    - No ParticleEmitters (all effects are Frame property animations)
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  No new sound effects needed for the badge system. Reuse existing:

  ui_tick     — badge tap feedback (existing)
  click       — store panel interactions (existing)

  The badge system is intentionally SILENT in its ambient state. Sounds
  are reserved for user-initiated interactions (taps) and purchase events
  (handled by StorePanel's existing purchase flow).

  Rationale: Badges are always visible while the store is open. Ambient
  badge sounds would cause audio fatigue within seconds. Visual animation
  alone is sufficient for passive attention-grabbing.
================================================================================
]]

return nil
