--!strict
--[[
	POST-PURCHASE THANK YOU SCREEN — VISUAL DESIGN SPEC
	=====================================================
	Full-screen celebration overlay shown immediately after a successful Robux
	purchase (DevProduct or GamePass). The moment a player spends real money
	should be the MOST celebrated moment in the game — this screen transforms
	a transaction into a luxury gift-box unboxing experience.

	Trigger:
	  DevProductService / GamePassService calls Remotes.fireClient("PurchaseComplete")
	  after MarketplaceService confirmation. Payload:
	    {
	      productType: "devproduct" | "gamepass",
	      productKey: string,
	      displayName: string,
	      iconId: string,
	      benefits: { string },    -- list of benefit lines
	      robuxSpent: number,
	      totalRobuxSpent: number, -- cumulative all-time
	    }

	ZIndex layering:
	  950 = backdrop (very high — above almost everything)
	  960 = showcase card
	  965 = card content
	  970 = particle overlays
	  975 = item spotlight
	  980 = top-layer sparkle overlay

	Engineer implementation notes:
	  - Fire AFTER the Roblox purchase prompt closes (use MarketplaceService
	    PromptProductPurchaseFinished / PromptGamePassPurchaseFinished callbacks).
	  - Never fire on purchase failure or cancellation.
	  - Suppress if player is mid-driving-run; queue and show at run end.
	  - Auto-dismiss after 5s OR tap-to-close (whichever first).
	  - If a spending milestone ceremony (MilestoneCeremonyService) triggers
	    from the same purchase, queue the milestone AFTER the thank-you screen
	    exits (0.5s gap). The thank-you is the immediate emotional payoff;
	    the milestone is the secondary validation.
	  - All tweens use TweenService; per-frame effects use RenderStepped.
	  - SoundFacade.playOneShot(name) for all sound triggers.
]]


--[[
================================================================================
  SECTION A — SCREEN LAYOUT
================================================================================
  Full-screen overlay with a centered showcase card. The design language
  evokes luxury packaging: dark backdrop, gold accents, clean typography,
  and a single spotlighted item.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  BACKDROP
────────────────────────────────────────────────────────────────────────────────

  Full-screen dim:
    Size               : UDim2.fromScale(1, 1)
    BackgroundColor3   : Color3.new(0, 0, 0)
    BackgroundTransparency: 0.3  (darker than ceremony backdrops — premium feel)
    ZIndex             : 950

  Radial vignette overlay (Frame with UIGradient):
    Size               : UDim2.fromScale(1, 1)
    BackgroundColor3   : Color3.fromRGB(10, 5, 20)
    UIGradient:
      Transparency     : NumberSequence-style radial approximation:
        Center          : 1 (transparent)
        Edges           : 0.4 (dark vignette)
      Color            : ColorSequence.new(Color3.fromRGB(10, 5, 20))
      Rotation         : 90
    ZIndex             : 951

  Gold shimmer rain (persistent during hold, camera-attached):
    20–30 small Frame dots falling slowly from above:
      Size             : 2×2 to 4×4 px (random)
      Color            : Color3.fromRGB(255, 213, 79) with ±20 per-channel variance
      Direction        : downward, slight horizontal drift (±15px)
      Speed            : 60–120 px/s (slow, floaty)
      Lifetime         : 1.5–3.0s
      Transparency     : 0.2 → 1 over lifetime
      Spawn rate       : ~10/s, evenly distributed across viewport width
      ZIndex           : 970

  The combined effect: a dark, focused stage with gold rain softly falling.
  The player's eye is drawn to the bright card in the center.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SHOWCASE CARD
────────────────────────────────────────────────────────────────────────────────

  Card Frame:
    Name               : "ThankYouCard"
    Size               : UDim2.fromOffset(400, 340)
    Position           : UDim2.fromScale(0.5, 0.5)
    AnchorPoint        : Vector2.new(0.5, 0.5)
    BackgroundColor3   : Color3.fromRGB(14, 10, 28)
    BackgroundTransparency: 0.02
    ZIndex             : 960

  UICorner             : UDim.new(0, 18)

  UIStroke:
    Thickness          : 2.5
    Color              : Color3.fromRGB(255, 213, 79)
    Transparency       : 0.0  (fully visible — premium feel, no subtlety)

  UIGradient (vertical, warm gold tint from top):
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(35, 28, 15)),
                           ColorSequenceKeypoint.new(0.3, Color3.fromRGB(14, 10, 28)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 15, 10)),
                         })
    Rotation           : 90

  Inner gold line accent (thin horizontal divider):
    Position           : UDim2.new(0.5, 0, 0, 190)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(0.7, 0, 0, 1)
    BackgroundColor3   : Color3.fromRGB(255, 213, 79)
    BackgroundTransparency: 0.4
    ZIndex             : 965

  Mobile: Size = UDim2.new(0.92, 0, 0, 340), max 400px wide.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  CARD CONTENT
────────────────────────────────────────────────────────────────────────────────

  ── Headline ──
    Text               : "THANK YOU FOR YOUR PURCHASE!"
    Font               : GothamBlack
    TextSize           : 18
    TextColor3         : Color3.fromRGB(255, 213, 79)
    Position           : UDim2.new(0.5, 0, 0, 20)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -32, 0, 24)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 965

  ── Gratitude Subline ──
    Text               : "Thank you for supporting Drive a Car Simulator!"
    Font               : GothamBold
    TextSize           : 12
    TextColor3         : Color3.fromRGB(220, 210, 230)
    Position           : UDim2.new(0.5, 0, 0, 48)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -32, 0, 18)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 965

  ── Item Spotlight (centered showcase) ──
    Container Frame:
      Size             : UDim2.fromOffset(90, 90)
      Position         : UDim2.new(0.5, 0, 0, 80)
      AnchorPoint      : Vector2.new(0.5, 0)
      BackgroundColor3 : Color3.fromRGB(30, 24, 55)
      UICorner         : UDim.new(0, 14)
      ZIndex           : 975

      UIStroke:
        Thickness      : 2
        Color          : Color3.fromRGB(255, 220, 100)
        Transparency   : 0.1

    Item Icon (inside container):
      Type             : ImageLabel
      Image            : payload.iconId  (product/pass icon)
      Size             : UDim2.fromOffset(64, 64)
      Position         : UDim2.fromScale(0.5, 0.5)
      AnchorPoint      : Vector2.new(0.5, 0.5)
      BackgroundTransparency: 1
      ZIndex           : 976

    Glow halo (behind container):
      Size             : UDim2.fromOffset(120, 120)
      BackgroundColor3 : Color3.fromRGB(255, 213, 79)
      BackgroundTransparency: 0.85
      UICorner         : UDim.new(0.5, 0)
      ZIndex           : 973

    Glow pulse: UIScale 1.0 ↔ 1.1, 1.5 Hz (slow, regal breathing)

  ── Item Name ──
    Text               : payload.displayName
    Font               : GothamBlack
    TextSize           : 16
    TextColor3         : Color3.new(1, 1, 1)
    Position           : UDim2.new(0.5, 0, 0, 178)
    AnchorPoint        : Vector2.new(0.5, 0)
    TextXAlignment     : Center
    ZIndex             : 965

  ── Benefits List ──
    ScrollingFrame or Frame below item name:
      Position         : UDim2.new(0.5, 0, 0, 205)
      AnchorPoint      : Vector2.new(0.5, 0)
      Size             : UDim2.new(0.85, 0, 0, 70)
      BackgroundTransparency: 1
      ZIndex           : 965

    Each benefit line:
      Text             : "✓ " .. benefit
      Font             : Gotham
      TextSize         : 11
      TextColor3       : Color3.fromRGB(180, 220, 180)
      TextXAlignment   : Left

    UIListLayout: Vertical, Top, Padding = UDim.new(0, 4)
    Max 4 benefit lines shown; truncate with "..." if more.

  ── Dismiss Button ──
    Type               : TextButton
    Text               : "ENJOY!"
    Font               : GothamBlack
    TextSize           : 16
    TextColor3         : Color3.fromRGB(20, 15, 40)
    Size               : UDim2.new(0.5, 0, 0, 42)
    Position           : UDim2.new(0.5, 0, 1, -24)
    AnchorPoint        : Vector2.new(0.5, 1)
    BackgroundColor3   : Color3.fromRGB(255, 213, 79)
    ZIndex             : 965

    UICorner           : UDim.new(0, 10)
    UIStroke:
      Thickness        : 1.5
      Color            : Color3.fromRGB(255, 240, 140)
      Transparency     : 0.15

    Idle pulse:
      UIScale oscillates 1.0 ↔ 1.03, frequency 1 Hz

    Click:
      UIScale → 0.92 instantly, then → 1.0 over 0.12s (Back Out)
      SoundFacade.playOneShot("ui_confirm")
      Begin exit animation
]]


--[[
================================================================================
  SECTION B — ENTRANCE ANIMATION ("GIFT BOX OPENING")
================================================================================
  The entrance is choreographed to feel like unwrapping a luxury gift.
  Each element reveals sequentially, building anticipation before the
  item is shown. The whole sequence takes ~1.5s before reaching hold state.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ENTRANCE TIMELINE
────────────────────────────────────────────────────────────────────────────────

  t=0.00s  SOUND: "purchase_thankyou_buildup"
           Short rising tone — anticipation. ~0.5s.

  t=0.00s  Backdrop fades in:
             BackgroundTransparency 1 → 0.3 over 0.3s (Quad Out)
             Vignette overlay fades in simultaneously.

  t=0.10s  Card appears from below:
             Position Y: 0.65 → 0.5 over 0.4s (Back Out)
             UIScale: 0.6 → 1.05 over 0.35s (Back Out)
             BackgroundTransparency: 0.5 → 0.02 over 0.25s
  t=0.45s  Card settles:
             UIScale: 1.05 → 1.0 over 0.12s (Quad Out)

  t=0.25s  Gold shimmer rain begins (particles start spawning).

  t=0.30s  Headline fades in:
             TextTransparency 1 → 0 over 0.2s
  t=0.45s  Gratitude subline fades in:
             TextTransparency 1 → 0 over 0.2s

  t=0.50s  SOUND: "purchase_thankyou_reveal"
           The "reveal" moment — bright chime + sparkle. ~0.4s.

  t=0.50s  Item spotlight container pops in:
             UIScale: 0 → 1.2 over 0.25s (Back Out)
  t=0.75s  Container settles:
             UIScale: 1.2 → 1.0 over 0.12s (Quad Out)

  t=0.55s  Glow halo fades in:
             BackgroundTransparency: 1 → 0.85 over 0.3s

  t=0.60s  Gold sparkle burst around item (one-shot):
             16 gold dot Frames radiating outward from item center:
               Size             : 3×3 to 5×5 px
               Color            : Color3.fromRGB(255, 213, 79) ±15 per-channel
               Speed            : 40–100 px/s
               Lifetime         : 0.3–0.5s
               Transparency     : 0.1 → 1
               SpreadAngle      : 360° (full radial)

  t=0.65s  Screen flash (gold):
             Full-screen Frame, ZIndex 998:
               BackgroundColor3 : Color3.fromRGB(255, 220, 100)
               BackgroundTransparency: 0.75 → 1 over 0.2s (Quad Out)

  t=0.75s  Item icon fades in inside container:
             ImageTransparency 1 → 0 over 0.2s

  t=0.80s  Item name label fades in:
             TextTransparency 1 → 0 over 0.2s

  t=0.90s  Gold divider line fades in:
             BackgroundTransparency 1 → 0.4 over 0.15s

  t=0.95s  Benefits list cascades in:
             Each line staggers by 0.08s
             Per line: TextTransparency 1 → 0 over 0.15s
             Position X offset: -10 → 0 over 0.15s (slide in from left)

  t=1.30s  Dismiss button fades in:
             BackgroundTransparency 1 → 0 over 0.15s
             TextTransparency 1 → 0 over 0.15s

  t=1.50s  Entrance complete. Hold phase begins.
           Gold shimmer rain continues. Glow halo pulses. Button pulses.
           Card UIStroke: subtle gold shimmer sweep
             (UIGradient.Offset scroll -1→1 over 4s, loop)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  HOLD PHASE AMBIENT EFFECTS
────────────────────────────────────────────────────────────────────────────────

  During hold (1.5s → dismiss):
    - Gold rain continues at 10/s spawn rate.
    - Item glow halo pulses: UIScale 1.0 ↔ 1.1, 1.5 Hz.
    - Card border shimmer: UIStroke UIGradient.Offset scrolls, 4s loop.
    - Dismiss button: UIScale 1.0 ↔ 1.03, 1 Hz.
    - Item container: very slow rotation (UIRotation 0° → 360° over 30s).
      Subtle enough to be subconscious — makes the item feel alive.

  RenderStepped connection for ambient effects disconnects on exit.
]]


--[[
================================================================================
  SECTION C — EXIT ANIMATION
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  EXIT TIMELINE
────────────────────────────────────────────────────────────────────────────────

  Triggered by: dismiss button click OR auto-dismiss at 5s OR tap backdrop.

  t=0.00s  Gold rain stops spawning (existing dots continue falling).
  t=0.00s  Card UIScale: 1.0 → 0.88 over 0.2s (Quad In)
  t=0.00s  Card BackgroundTransparency: 0.02 → 0.6 over 0.2s
  t=0.05s  All text: TextTransparency → 1 over 0.15s
  t=0.10s  Item spotlight: UIScale 1.0 → 0 over 0.2s (Quad In)
  t=0.15s  Backdrop: transparency 0.3 → 1 over 0.25s
  t=0.30s  Destroy all elements.

  Sound: none on exit (the "ui_confirm" from button click is sufficient).

  Auto-dismiss at 5s:
    At t=4.0s, dismiss button text changes to "ENJOY! (1)" countdown.
    At t=4.0s/4.5s: subtle button pulse intensifies (1.0 ↔ 1.06).
    At t=5.0s: begin exit automatically.
]]


--[[
================================================================================
  SECTION D — SUPPORTER TIER ESCALATION
================================================================================
  Higher cumulative spending unlocks more dramatic thank-you screens. The
  escalation rewards repeat purchasers with progressively fancier experiences.

  Tier thresholds (cumulative totalRobuxSpent):
    | Tier         | Threshold | Card Border     | Rain Color   | Special Effect        |
    |--------------|-----------|-----------------|-------------- |-----------------------|
    | Standard     | 0+        | Gold            | Gold          | none                  |
    | Supporter    | 100R$+    | Bright gold     | Gold + white  | Item glow intensified |
    | VIP          | 500R$+    | Animated gold   | Gold + sparkle| Confetti burst at top |
    | Whale        | 2000R$+   | Gold → platinum | Rainbow rain  | Full firework show    |

  Standard (< 100R$):
    Base experience as described above.

  Supporter (100R$+):
    Card UIStroke.Color: Color3.fromRGB(255, 225, 100) (brighter gold)
    Glow halo intensity: transparency 0.8 (brighter)
    Gold rain includes 20% white dots interspersed.
    Item container UIStroke: slightly thicker (2.5px)

  VIP (500R$+):
    Card UIStroke: animated — gold ↔ bright gold cycle, 2s period:
      Color3.fromRGB(255, 213, 79):Lerp(Color3.fromRGB(255, 240, 160), pulse)
    Glow halo: larger (140×140), transparency 0.75
    Rain includes gold sparkle dots that flash briefly (transparency 0→0.8→0 blink)
    Confetti burst at t=0.60s (entrance):
      24 dots from top of card, falling with gravity arc
      Colors: gold, white, warm orange
      Lifetime: 0.5–1.0s, speed 60–140 px/s, gravity 180 px/s²
    Sound upgrade: "purchase_thankyou_reveal_vip" — richer chime with reverb tail

  Whale (2000R$+):
    Card UIStroke: animated gold → platinum → gold cycle:
      gold     = Color3.fromRGB(255, 213, 79)
      platinum = Color3.fromRGB(210, 215, 230)
      Cycle period: 3s
    Rain: rainbow-colored (each dot picks a random hue, saturation 0.7, value 1)
    Glow halo: animated rainbow (Color3.fromHSV cycle, 0.3/s)
    Full firework show at t=0.60s:
      3 bursts staggered at t=0.60s, t=0.80s, t=1.00s
      Each burst: 12 dots, radial, speed 80–200 px/s, gravity arc
      Colors: rainbow pool
      Screen flash on each burst: matching hue, peak 0.82, 0.15s
    Camera shake: 0.06, 0.1s (at each burst)
    Sound upgrade: "purchase_thankyou_reveal_whale" — full fanfare, bass drop, ~0.8s

  Never show the tier label to the player — the escalation should feel
  natural and surprising, not transactional.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SUPPORTER PERCENTAGE LINE (optional, VIP+ tiers only)
────────────────────────────────────────────────────────────────────────────────

  Below the benefits list (above dismiss button), for VIP+ tiers:
    Text               : "You're in the top {X}% of supporters!"
    Font               : GothamBold
    TextSize           : 11
    TextColor3         : Color3.fromRGB(255, 213, 79)
    Position           : UDim2.new(0.5, 0, 1, -72)
    AnchorPoint        : Vector2.new(0.5, 0)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 965

  Percentage calculation (server-side):
    Server maintains a rough percentile based on all-time Robux spend
    distribution. Sent in payload as supporterPercentile: number (1–100).
    Display: if percentile <= 10, show line. Otherwise omit.

  Examples:
    "You're in the top 5% of supporters!"
    "You're in the top 1% of supporters!"

  This line creates IDENTITY — the player is not just spending, they are
  a TOP supporter. This validated identity increases future spend likelihood.

  Entrance: fades in at t=1.15s, after benefits list.
  Gold text glow: TextStrokeColor3 = gold, TextStrokeTransparency 0.6.
]]


--[[
================================================================================
  SECTION E — GAMEPASS VS DEVPRODUCT VARIATIONS
================================================================================
  The screen adapts slightly based on purchase type.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  GAMEPASS PURCHASE
────────────────────────────────────────────────────────────────────────────────
  GamePasses are permanent unlocks — the messaging emphasizes FOREVER.

  Headline variant: "GAMEPASS UNLOCKED!"
  Subline variant : "This power is yours FOREVER!"

  Item spotlight gets a permanent unlock badge:
    Small Frame below item container:
      Size             : UDim2.fromOffset(70, 16)
      Position         : UDim2.new(0.5, 0, 1, 4)
      AnchorPoint      : Vector2.new(0.5, 0)
      BackgroundColor3 : Color3.fromRGB(60, 180, 80)
      UICorner         : UDim.new(0, 4)
      ZIndex           : 976

    Label:
      Text             : "PERMANENT"
      Font             : GothamBlack
      TextSize         : 8
      TextColor3       : Color3.new(1, 1, 1)

  Benefits list uses green checkmarks: "✓ " prefix
  (same as default — green communicates "unlocked")
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  DEVPRODUCT PURCHASE
────────────────────────────────────────────────────────────────────────────────
  DevProducts are consumable — the messaging emphasizes INSTANT VALUE.

  Headline variant: "THANK YOU FOR YOUR PURCHASE!"
  Subline variant : "Your items have been delivered!"

  If the product grants currency (coins/gems), show a currency splash:
    Large animated number counting up from 0 → amount over 0.5s:
      Font             : GothamBlack
      TextSize         : 28
      TextColor3       : currency color from Constants.CURRENCY_DISPLAY
      Position         : below item name, replacing benefits list
      Counter easing   : Quad Out (fast start, slow end)

    Currency icon beside the number, same size as text.

  If the product grants non-currency items (e.g. crates, boosts):
    Use standard benefits list format.
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  purchase_thankyou_buildup    — rising anticipation tone (0.5s)
                                  Character: soft ascending synth pad, building tension
                                  Think: gift box ribbon being untied
  purchase_thankyou_reveal     — bright chime + sparkle (0.4s)
                                  Character: luxury reveal — like opening a jewelry box
                                  Think: crystalline bell with gold shimmer tail
  purchase_thankyou_reveal_vip — richer chime with reverb (0.5s)
                                  Character: same as reveal but with orchestral swell
  purchase_thankyou_reveal_whale — full fanfare + bass drop (0.8s)
                                  Character: red carpet trumpet flourish + chest-thump bass

  Existing sounds reused:
    ui_confirm  — dismiss button click (existing)

  The two-part sound design (buildup → reveal) creates an anticipation arc
  that mirrors the visual entrance. The 0.5s gap between sounds matches the
  visual transition from card-appear to item-reveal.
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Max 1 thank-you screen at a time (purchases can't overlap due to
      MarketplaceService queuing).
    - Gold rain: max 30 active dots. Pool and recycle.
    - Firework bursts (Whale tier): max 36 dots total across 3 bursts.
    - All ambient effects disconnect RenderStepped on exit.
    - Currency counter animation: uses a single RenderStepped for counting,
      not per-frame TweenService calls.
    - Total particle budget worst case (Whale): ~66 dots over 1.5s entrance +
      30 rain dots sustained. Well within budget.

  Accessibility:
    - All text meets 4.5:1 contrast against card background.
    - Dismiss button is large (>42px height, 50% card width) and centered.
    - Auto-dismiss at 5s prevents soft-lock.
    - Benefits list uses text markers ("✓") not just color.
    - Sound cues complement visual reveal — deaf players get full visual
      choreography; blind players hear a clear two-part audio arc.

  Mobile:
    - Card width: math.min(400, viewportWidth - 32)
    - Item spotlight shrinks proportionally on small screens.
    - Dismiss button: full card width minus 32px padding on mobile.
    - Tap anywhere on backdrop also dismisses (larger touch target).
    - Benefits list: max 3 lines on viewport height < 600px.

  Edge cases:
    - Rapid successive purchases (e.g. buying 3 DevProducts quickly):
      Queue thank-you screens. Show each for 3s (shortened from 5s) with
      0.3s gap between. Max queue depth: 3. Excess silently dropped.
    - Player disconnects during animation: no impact — purely visual.
    - Server fails to send payload: show generic "Thank you!" without
      item details. Still celebrate — never let a purchase go unacknowledged.
================================================================================
]]

return nil
