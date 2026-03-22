--!strict
--[[
	PAYOUT SCREEN MONETIZATION SURFACE — DESIGN SPEC
	=================================================
	Defines contextual monetization upsells that appear on the run-end
	payout card. Each upsell is surfaced AFTER the player has seen
	their earnings — when regret for missing potential coins is highest.

	Psychology: The payout screen is the single highest-intent moment in
	the session. The player just earned N coins and can viscerally feel
	what 2× N would have been. Every upsell shows a concrete, personal
	"you missed out on X" number anchored to the run they just completed.

	Existing state (PayoutPanel.luau):
	  - Card shows: distance, laps, coins earned, multiplier badges,
	    XP bar, "Play Again" / "Back to Lobby" buttons
	  - GamePassConfig has: double_coins, double_speed, auto_collect,
	    infinite_gas, coin_boost, etc.
	  - DevProductConfig has: coin packs, gem packs, battle_pass_premium
	  - Player data includes: ownedPasses, equippedCar, pets, rebirths

	This spec adds three monetization surfaces to the payout card:
	  1. "You could have earned" contextual pass upsell strip
	  2. "Boost Next Run" quick-purchase row (dev products)
	  3. "Upgrade Path" nudge for the next car/world/rebirth

	Reference files:
	  - DACStarterGui/PayoutPanel.luau (implementation target)
	  - DACStarterGui/PayoutPanelDesignSpec.luau (timing choreography)
	  - DACReplicatedStorage/Config/GamePassConfig.luau
	  - DACReplicatedStorage/Config/DevProductConfig.luau
	  - DACStarterGui/StorePanel.luau (FOMO badge patterns)
]]


--[[
================================================================================
  SURFACE 1 — "YOU COULD HAVE EARNED" CONTEXTUAL PASS UPSELL
================================================================================
  A single horizontal strip below the coins stat row. Shows the pass
  that would have given the LARGEST incremental gain for THIS specific run.

  Trigger logic:
    After stat counter finishes (t=1.55s in payout choreography), scan
    the player's owned passes. Find the highest-value unowned pass by
    computing the hypothetical coin delta for the run just completed:

    Priority order (first unowned wins):
      1. double_coins  — delta = coinsEarned (they'd get 2× total)
      2. coin_boost    — delta = coinsEarned * 0.10
      3. infinite_gas  — delta = estimate from remaining gas headroom
      4. double_speed  — delta = coinsEarned * 0.30 (speed→distance→coins)

    If all are owned → Surface 1 is hidden (the player is already maxed).

  STRIP LAYOUT:
    Inserted as a new row in the card layout (LayoutOrder = 4.5,
    between coins row and XP header):

    Container Frame:
      Name           : "UpsellStrip"
      Size           : UDim2.new(1, 0, 0, 44)
      BackgroundColor3: Color3.fromRGB(30, 25, 50)
      BackgroundTransparency: 0.15
      LayoutOrder    : 5  (after coins row at 4)

    UICorner:
      CornerRadius   : UDim.new(0, 10)

    UIStroke:
      Color          : Color3.fromRGB(255, 200, 60)
      Thickness      : 1.5
      Transparency   : 0.4

    Left section — missed earnings callout:
      TextLabel:
        Name         : "MissedLabel"
        Size         : UDim2.new(0.55, 0, 1, 0)
        Position     : UDim2.new(0, 12, 0, 0)
        Text         : `+{Utils.formatNumber(delta)} coins missed!`
        Font         : GothamBold
        TextSize     : 15
        TextColor3   : Color3.fromRGB(255, 100, 80)
        TextXAlignment: Left
        BackgroundTransparency: 1

    Right section — pass CTA button:
      TextButton:
        Name         : "PassCTA"
        AnchorPoint  : Vector2.new(1, 0.5)
        Position     : UDim2.new(1, -8, 0.5, 0)
        Size         : UDim2.fromOffset(140, 32)
        BackgroundColor3: Color3.fromRGB(255, 200, 50)
        Text         : `Get {passName} →`
        Font         : GothamBold
        TextSize     : 13
        TextColor3   : Color3.fromRGB(30, 20, 0)

      UICorner on CTA:
        CornerRadius : UDim.new(0, 8)

      On click:
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
        SoundFacade.playOneShot("click")

  ANIMATION:
    The strip enters AFTER stat counters finish (t=1.60s in sequence):

    Entrance (t=1.60s):
      Strip spawns with UIScale = 0, BackgroundTransparency = 1
      UIScale: 0 → 1.05 over 0.25s (Back Out)
      Then 1.05 → 1.0 over 0.10s (Quad Out)
      BackgroundTransparency: 1 → 0.15 over 0.20s

    MissedLabel entrance (t=1.70s):
      TextTransparency: 1 → 0 over 0.20s
      TextColor3 flash: start at Color3.fromRGB(255, 200, 60) (gold),
        tween to Color3.fromRGB(255, 100, 80) (red) over 0.30s
        The gold-to-red transition reads as "loss" — this was YOUR money.

    PassCTA entrance (t=1.80s):
      UIScale on button: 0 → 1.1 over 0.18s (Back Out)
      Then settle to 1.0 over 0.08s

    Idle loop (while strip is visible):
      MissedLabel text gentle scale pulse:
        UIScale oscillates 1.0 ↔ 1.02, period 2.5s
        Formula: 1 + 0.02 * (0.5 + 0.5 * math.sin(os.clock() * 2.5))
      Subtle enough to draw peripheral attention without being obnoxious.

      UIStroke shimmer:
        UIGradient.Offset on stroke scrolls X: -1 → 1 over 4s, loop

  SOUND:
    At t=1.60s, play a subtle "missed opportunity" tone:
      "payout_upsell_hint"
      Character: soft descending two-note chime, ~0.25s
      Think: a gentle "aww" — empathetic, not punishing.
      Volume: 60% of normal UI sounds (background awareness level).

  DESIGN RATIONALE:
    The player just watched their coins count up. Showing what they
    MISSED makes the value proposition concrete and personal. The
    gold-to-red color transition subconsciously frames it as loss.
    The button is warm gold (positive) — the solution to the red loss.
================================================================================
]]


--[[
================================================================================
  SURFACE 2 — "BOOST NEXT RUN" QUICK-PURCHASE ROW
================================================================================
  A row of 2-3 small purchase cards that offer immediate value for
  the NEXT run. Positioned below the upsell strip, above the XP bar.

  These are dev products (repeatable purchases), not game passes.
  They offer a temporary or instant boost tied to the next session.

  Card selection logic:
    Always show these in order, max 3 visible:

    Card A — Coin Pack (contextual sizing):
      Pick the smallest coin pack where pack.amount >= coinsEarned * 0.5
      This ensures the offer feels proportional to their run earnings.
      Fallback: coins_1k if all packs are too large.
      Label: `+{amount} Coins`
      Sublabel: `{robuxPrice} R$`

    Card B — Battle Pass Premium (if not owned):
      Only shows if player hasn't purchased battle_pass_premium.
      Label: "Battle Pass"
      Sublabel: "749 R$ — 2× XP"

    Card C — Instant Rebirth (if rebirth is available):
      Only shows if player meets rebirth level threshold.
      Label: "Instant Rebirth"
      Sublabel: "299 R$"

  CARD LAYOUT:
    Container Frame:
      Name           : "BoostRow"
      Size           : UDim2.new(1, 0, 0, 70)
      BackgroundTransparency: 1
      LayoutOrder    : 6  (after upsell strip)

    UIListLayout:
      FillDirection  : Horizontal
      HorizontalAlignment: Center
      Padding        : UDim.new(0, 10)

    Per-card Frame:
      Size           : UDim2.fromOffset(110, 62)
      BackgroundColor3: Color3.fromRGB(25, 22, 45)
      BackgroundTransparency: 0.08

      UICorner       : UDim.new(0, 8)
      UIStroke:
        Color        : Color3.fromRGB(120, 140, 220)
        Thickness    : 1
        Transparency : 0.45

      Title label (top):
        Font         : GothamBold
        TextSize     : 12
        TextColor3   : Color3.new(1, 1, 1)
        Position     : UDim2.new(0, 0, 0, 4)
        Size         : UDim2.new(1, 0, 0, 18)

      Price label (bottom):
        Font         : GothamMedium
        TextSize     : 11
        TextColor3   : Color3.fromRGB(120, 255, 160)
        Position     : UDim2.new(0, 0, 0, 22)
        Size         : UDim2.new(1, 0, 0, 16)

      Buy button:
        Size         : UDim2.new(1, -8, 0, 20)
        Position     : UDim2.new(0, 4, 1, -24)
        BackgroundColor3: Color3.fromRGB(76, 175, 80)
        Text         : "Buy"
        Font         : GothamBold
        TextSize     : 11
        UICorner     : UDim.new(0, 6)

      On click:
        MarketplaceService:PromptProductPurchase(player, productId)
        SoundFacade.playOneShot("click")

  ANIMATION:
    Cards cascade in after the upsell strip (t=1.90s):

    Per-card entrance, staggered 0.10s:
      UIScale: 0 → 1.08 over 0.20s (Back Out)
      Then 1.08 → 1.0 over 0.08s (Quad Out)

    Total cascade for 3 cards: ~0.48s

    Idle shimmer on each card:
      UIGradient overlay with transparency highlight sweep:
        Transparency : {(0,1), (0.42,0.7), (0.58,0.7), (1,1)}
        Offset       : scroll X from -1.5 to 1.5 over 5s, loop
        Stagger each card's start by 1.5s for a wave effect.

  SOUND:
    No dedicated sound — the upsell strip sound is sufficient.
    Card interactions use existing "click" sound.

  DESIGN RATIONALE:
    Small, non-intimidating price points shown at the moment of
    maximum engagement. The contextual coin pack sizing ensures
    the offer always feels relevant. Battle Pass and Instant Rebirth
    target the player's known progression blockers.
================================================================================
]]


--[[
================================================================================
  SURFACE 3 — "UPGRADE PATH" PROGRESSION NUDGE
================================================================================
  A slim banner at the very bottom of the card (above buttons) that
  surfaces the player's NEXT meaningful progression milestone and
  frames it as attainable.

  Nudge selection logic (first match wins):
    1. Next car affordable: if player has enough coins to buy their
       next-tier car but hasn't yet → "You can afford the {carName}!"
    2. Rebirth available: if player meets rebirth threshold →
       "Ready to rebirth! +{bonus} permanent stats"
    3. World unlock close: if player is within 30% of the currency
       needed for the next world → "Only {remaining} coins to {world}!"
    4. Pet team upgrade: if player has unequipped pets with higher
       power → "Equip your {petName} for +{delta} modifier!"
    5. Fallback: hide the nudge.

  BANNER LAYOUT:
    Frame:
      Name           : "ProgressNudge"
      Size           : UDim2.new(1, 0, 0, 32)
      BackgroundColor3: Color3.fromRGB(20, 40, 30)
      BackgroundTransparency: 0.2
      LayoutOrder    : 19  (just above button row at 20)

    UICorner       : UDim.new(0, 8)

    UIStroke:
      Color          : Color3.fromRGB(80, 200, 120)
      Thickness      : 1
      Transparency   : 0.55

    TextLabel:
      Name           : "NudgeText"
      Size           : UDim2.new(1, -16, 1, 0)
      Position       : UDim2.new(0, 8, 0, 0)
      Font           : GothamBold
      TextSize       : 13
      TextColor3     : Color3.fromRGB(120, 255, 160)
      TextXAlignment : Left
      BackgroundTransparency: 1

    Arrow icon (right side):
      TextLabel:
        Text         : "→"
        AnchorPoint  : Vector2.new(1, 0.5)
        Position     : UDim2.new(1, -8, 0.5, 0)
        Font         : GothamBold
        TextSize     : 16
        TextColor3   : Color3.fromRGB(120, 255, 160)

  ANIMATION:
    Entrance at t=2.20s (after boost row):
      Position Y offset: slide from +15px to 0 over 0.25s (Quad Out)
      TextTransparency: 1 → 0 over 0.20s

    Arrow idle pulse:
      Position X oscillates: -8 ↔ -14 px (6px amplitude)
      Period: 1.8s
      Formula: -8 + math.sin(os.clock() * 3.5) * -3
      The arrow "beckons" the player forward.

    TextColor3 subtle warmth cycle:
      Color3.fromRGB(120, 255, 160) ↔ Color3.fromRGB(180, 255, 200)
      Period: 3s
      Formula: baseColor:Lerp(warmColor, 0.5 + 0.5 * math.sin(os.clock() * 2.1))

  SOUND:
    None — the nudge is purely visual encouragement.

  ON CLICK (entire banner is a TextButton):
    If nudge type is car/world → open StorePanel or WorldPanel
    If nudge type is rebirth → open RebirthPanel
    If nudge type is pet → open InventoryPanel
    Close payout panel, SoundFacade.playOneShot("click")

  DESIGN RATIONALE:
    The progression nudge catches players who are CLOSE to a milestone
    and gives them a reason to play again immediately. By framing the
    next step as attainable ("only X more coins"), it reduces the
    psychological barrier to another session. The green color palette
    signals "go" and "growth" — the opposite of the red "missed" upsell.
================================================================================
]]


--[[
================================================================================
  LAYOUT INTEGRATION — FULL PAYOUT CARD ORDER
================================================================================
  Updated LayoutOrder map with monetization surfaces inserted:

  LayoutOrder  Element                      Monetization?
  ──────────── ──────────────────────────── ─────────────
  1            Title bar (+ PB badge)       No
  2            Distance stat row            No
  3            Laps stat row                No
  4            Coins stat row               No
  5            ★ Upsell Strip               YES — Surface 1
  6            ★ Boost Row (dev products)   YES — Surface 2
  7            XP header                    No (was 5)
  8            XP tier label                No (was 6)
  9            XP gain label                No (was 7)
  10           XP bar                       No (was 8)
  11           Multiplier badges wrap       No (was 9)
  19           ★ Progress Nudge             YES — Surface 3
  20           Button row                   No

  Existing LayoutOrders shift by 2 to accommodate the two new
  surfaces above the XP section.
================================================================================
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — MONETIZATION SURFACES IN PAYOUT FLOW
================================================================================
  These surfaces appear AFTER the player has absorbed their earnings
  but BEFORE they make their next-action decision (Play Again / Lobby).

  Existing sequence (abbreviated):
  t=0.00s   Screen flash + card entrance
  t=0.53s   Card pop-in, coin rain
  t=0.70s   Stat counter roll-up begins (0.85s)
  t=1.55s   Counter finishes, value stamp
  t=1.60s   ★ UPSELL STRIP enters (Surface 1)
              "You missed out on X coins!" with gold→red flash
              "payout_upsell_hint" soft chime
  t=1.70s   MissedLabel text fades in
  t=1.80s   Pass CTA button enters
  t=1.90s   ★ BOOST ROW enters (Surface 2)
              Cards cascade in, 0.10s stagger
  t=2.10s   Last boost card settles
  t=2.20s   ★ PROGRESS NUDGE slides in (Surface 3)
              "Only X coins to {next milestone}!"
  t=2.45s   Nudge fully settled
  t=2.50s+  Multiplier badges + PB badge (existing flow)
  ∞         All surfaces visible until player clicks a button

  Total added time: ~0.90s layered into the existing sequence.
  Surfaces animate concurrently with existing badge cascade where
  possible to avoid feeling slow.
================================================================================
]]


--[[
================================================================================
  CONDITIONAL VISIBILITY RULES
================================================================================
  Not every surface shows every time. This prevents banner fatigue.

  Surface 1 (Upsell Strip):
    Show if: player is missing at least one high-value pass
    Hide if: all relevant passes owned (double_coins, coin_boost,
             infinite_gas, double_speed)
    Frequency cap: show every run (it's contextual and different each time)

  Surface 2 (Boost Row):
    Show if: at least one card qualifies
    Hide if: zero qualifying products (e.g., player owns battle pass,
             can't rebirth, and has already bought coins this session)
    Frequency cap: none (cards change based on context)

  Surface 3 (Progress Nudge):
    Show if: a qualifying nudge exists
    Hide if: no milestone is close enough to surface
    Frequency cap: none (content varies per run)

  If ALL three surfaces are hidden (rare — player owns everything):
    The payout card renders exactly as it does today with no
    monetization elements. This avoids showing an empty "buy" section
    to a whale who already bought everything.
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Surface 1: 1 RenderStepped connection for idle pulse (lightweight)
    - Surface 2: 0 active connections (shimmer via TweenService loop)
    - Surface 3: 1 RenderStepped connection for arrow pulse
    - Total: 2 extra RenderStepped connections (trivial overhead)
    - All elements destroyed when payout panel closes

  Accessibility:
    - All text meets WCAG 3:1 contrast minimum
    - CTA buttons have 44×32px minimum touch targets
    - Boost row cards have 110×62px touch targets (comfortably tappable)
    - No flashing exceeds 3 Hz (safe for photosensitive users)

  Mobile scaling:
    - On viewports < 600px wide: boost row shows max 2 cards
    - On viewports < 400px wide: upsell strip text size drops to 13,
      boost row shows max 1 card, progress nudge text size drops to 12
    - All surfaces scale with card width (1, 0 UDim2 x-scale)

  Budget:
    - 3 additional UI elements in card layout
    - 1-3 MarketplaceService prompt calls possible per payout
    - 0 network requests (all data sourced from cached player data)
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  payout_upsell_hint  — soft descending two-note chime (0.25s)
                         plays when the upsell strip enters
                         60% volume — background awareness, not alarm

  Existing sounds reused:
  click               — all CTA / card interactions
  purchase            — triggered by MarketplaceService on successful buy
================================================================================
]]

return nil
