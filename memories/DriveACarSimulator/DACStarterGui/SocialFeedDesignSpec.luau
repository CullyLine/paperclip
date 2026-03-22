--!strict
--[[
	SOCIAL FEED, FOMO BADGES & SESSION RETENTION — Visual Design Spec
	==================================================================
	This file defines exact parameters for three dopamine systems:
	  A) Server Drop Feed Banner      (live-stream-style hatch alerts)
	  B) Store FOMO Badges            (urgency/scarcity overlays on store cards)
	  C) Session Retention Popup      (re-engagement when player idles)

	Engineer implementation notes:
	  - Drop feed banner hooks into EggService hatch broadcasts via a new
	    RemoteEvent "ServerDropFeed" fired to all clients on Rare+ hatches.
	  - FOMO badges are injected by StorePanel when building item cards;
	    badge type is driven by config flags on each store item.
	  - Retention popup is managed by a new RetentionController that tracks
	    idle time via UserInputService.LastInputType changes.
	  - Colors reference Constants.RARITY_COLORS (same palette as
	    PetEntranceDesignSpec):
	      rare      = Color3.fromRGB( 60, 130, 255)
	      epic      = Color3.fromRGB(180,  60, 255)
	      legendary = Color3.fromRGB(255, 200,  50)
	      mythic    = Color3.fromRGB(255,  50,  80)
	  - mythicRainbowSequence() from VFXController is reused for mythic
	    banner effects.
	  - All UI elements should respect existing ZIndex layering:
	      HUD base       : 1–10
	      Panels         : 100–200
	      Overlays/popups: 500–900
	      VFX flashes    : 990–1100
]]


--[[
================================================================================
  SECTION A — SERVER DROP FEED BANNER
================================================================================
  A sliding notification banner that appears at the top of the screen when
  any player on the server hatches a Rare or higher pet. Mimics live-stream
  donation/sub alert style: slide in from right, hold, slide out left.

  Only Rare, Epic, Legendary, and Mythic hatches trigger banners.
  Common and Uncommon are ignored to avoid notification fatigue.

  Layout (root frame):

    ┌──[PetIcon 36×36]──[RarityLabel]──[PetName]──[byPlayerName]──────┐
    │  🐉               ★ LEGENDARY    Phoenix     hatched by xGamer  │
    └─────────────────────────────────────────────────────────────────┘

  Root frame dimensions and positioning:
    Name             : "DropFeedBanner"
    Size             : UDim2.new(0, 380, 0, 48)
    AnchorPoint      : Vector2.new(1, 0)
    Rest position    : UDim2.new(1, -16, 0, 52)    (top-right, below topbar)
    Offscreen right  : UDim2.new(1, 400, 0, 52)    (start position, hidden)
    Offscreen left   : UDim2.new(0, -400, 0, 52)   (exit position)
    BackgroundTransparency: 0.08
    ZIndex           : 520
    ClipsDescendants : true

  UICorner:
    CornerRadius     : UDim.new(0, 10)

  UIStroke (outer glow, color varies by rarity — see per-rarity specs):
    Thickness        : 1.5
    ApplyStrokeMode  : Enum.ApplyStrokeMode.Border
    Transparency     : 0.2

  UIGradient on root (horizontal, left = darker, right = lighter):
    Color            : rarity-specific (see per-rarity below)
    Rotation         : 0

  Drop shadow (Frame behind root, ZIndex root-1):
    Size             : UDim2.new(1, 6, 1, 6)
    Position         : UDim2.new(0.5, 0, 0.5, 2)
    AnchorPoint      : Vector2.new(0.5, 0.5)
    BackgroundColor3 : Color3.new(0, 0, 0)
    BackgroundTransparency: 0.65
    CornerRadius     : UDim.new(0, 12)
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  CHILD ELEMENTS (shared across all rarity tiers)
────────────────────────────────────────────────────────────────────────────────

  Pet Icon area (left side):
    Name             : "PetIcon"
    Type             : ViewportFrame (to render 3D pet model) or ImageLabel
    Size             : UDim2.fromOffset(36, 36)
    Position         : UDim2.new(0, 8, 0.5, 0)
    AnchorPoint      : Vector2.new(0, 0.5)
    BackgroundTransparency: 1
    ZIndex           : root + 2

    If ViewportFrame:
      Clone pet model into viewport, position camera to frame it.
      Ambient         : Color3.new(1, 1, 1)
      LightColor      : rarity accent color (0.6 brightness)

    If ImageLabel (fallback, no model available):
      Use a silhouette icon with rarity-tinted color.
      ImageColor3     : rarity accent color

  Rarity Label:
    Name             : "RarityLabel"
    Type             : TextLabel
    Size             : UDim2.new(0, 90, 0, 18)
    Position         : UDim2.new(0, 50, 0, 6)
    Font             : Enum.Font.GothamBlack
    TextSize         : 13
    TextXAlignment   : Enum.TextXAlignment.Left
    BackgroundTransparency: 1
    ZIndex           : root + 2
    Text format      : "★ RARE", "★★ EPIC", "★★★ LEGENDARY", "★★★★ MYTHIC"
    TextColor3       : per-rarity (see below)

  Pet Name Label:
    Name             : "PetNameLabel"
    Type             : TextLabel
    Size             : UDim2.new(0, 120, 0, 16)
    Position         : UDim2.new(0, 50, 0, 26)
    Font             : Enum.Font.GothamBold
    TextSize         : 14
    TextXAlignment   : Enum.TextXAlignment.Left
    BackgroundTransparency: 1
    ZIndex           : root + 2
    TextColor3       : Color3.new(1, 1, 1)

  Player Name Label (right-aligned):
    Name             : "PlayerLabel"
    Type             : TextLabel
    Size             : UDim2.new(0, 130, 0, 14)
    Position         : UDim2.new(1, -8, 0.5, 0)
    AnchorPoint      : Vector2.new(1, 0.5)
    Font             : Enum.Font.Gotham
    TextSize         : 11
    TextXAlignment   : Enum.TextXAlignment.Right
    BackgroundTransparency: 1
    ZIndex           : root + 2
    TextColor3       : per-rarity accent (dimmed, see below)
    Text format      : "hatched by {DisplayName}"
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ANIMATION CHOREOGRAPHY (shared timing)
────────────────────────────────────────────────────────────────────────────────

  Slide-in from right (offscreen → rest):
    Duration         : 0.45s
    EasingStyle      : Back
    EasingDirection  : Out
    Property         : Position

  Hold at rest:
    Duration         : 3.0s (4.0s for Mythic)

  Slide-out to left (rest → offscreen left):
    Duration         : 0.35s
    EasingStyle      : Quad
    EasingDirection  : In
    Property         : Position

  Queue behavior:
    If a new banner arrives while one is visible, the current banner
    immediately begins its slide-out (skip remaining hold time), and the
    new banner enters after a 0.15s gap. Max 1 banner on screen at a time.

  Total lifecycle: ~3.8s per banner (4.8s for Mythic).
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  RARE BANNER — Blue shimmer, clean and bright
────────────────────────────────────────────────────────────────────────────────

  Root background gradient:
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(15, 30, 65)),
                         ColorSequenceKeypoint.new(0.4, Color3.fromRGB(20, 45, 90)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(30, 60, 120)),
                       })

  UIStroke:
    Color            : Color3.fromRGB(80, 160, 255)

  RarityLabel.TextColor3 : Color3.fromRGB(100, 180, 255)
  PlayerLabel.TextColor3 : Color3.fromRGB(120, 160, 200)

  Shimmer overlay (UIGradient on a transparent overlay Frame):
    A horizontal highlight sweeps across the banner once during the hold:
      Overlay Frame    : Size 1,0,1,0 — BackgroundColor3 white, transp 0.88
      UIGradient.Transparency:
        NumberSequence.new({
          NumberSequenceKeypoint.new(0, 1),
          NumberSequenceKeypoint.new(0.42, 0.65),
          NumberSequenceKeypoint.new(0.58, 0.65),
          NumberSequenceKeypoint.new(1, 1),
        })
      Offset animation : X from -1.5 to 1.5 over 1.2s, starts at t=0.3s
      EasingStyle      : Quad InOut

  No particles. No screen effects. Clean and understated.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  EPIC BANNER — Purple gradient with sparkle edge particles
────────────────────────────────────────────────────────────────────────────────

  Root background gradient:
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(30, 10, 55)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 18, 85)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(70, 25, 110)),
                       })

  UIStroke:
    Color            : Color3.fromRGB(200, 100, 255)
    Transparency     : animated 0.2 ↔ 0.05, frequency 1.5 Hz (gentle pulse)

  RarityLabel.TextColor3 : Color3.fromRGB(220, 140, 255)
  PlayerLabel.TextColor3 : Color3.fromRGB(180, 130, 220)

  Shimmer sweep (same mechanism as Rare but tinted purple):
    Overlay tint     : Color3.fromRGB(200, 140, 255)
    Overlay transp   : 0.82
    Duration         : 1.0s, starts at t=0.25s

  Edge sparkle particles (emitted from thin Frames on top and bottom edges):
    Implementation: 2 particle-emitting Frames (top edge, bottom edge)
    Each Frame spawns small dot children that drift inward and fade:
      Dot size       : 3×3 px
      Color          : Color3.fromRGB(220, 160, 255)
      Count          : 6 dots per edge, staggered over the hold duration
      Motion         : drift 8–14px inward (toward banner center) over 0.6s
      Transparency   : 0 → 1 over lifetime
      Destroy after  : 0.7s

  Entrance sound: "drop_feed_epic"
    Character: soft magical chime, ~0.3s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  LEGENDARY BANNER — Gold with animated light rays
────────────────────────────────────────────────────────────────────────────────

  Root background gradient:
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(50, 35, 8)),
                         ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 50, 12)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(90, 65, 15)),
                       })

  UIStroke:
    Color            : Color3.fromRGB(255, 210, 80)
    Thickness        : 2.0 (thicker than other tiers)
    Transparency     : animated 0.1 ↔ 0 at 2 Hz

  RarityLabel:
    TextColor3       : Color3.fromRGB(255, 220, 100)
    Font             : GothamBlack (already set)

  PetNameLabel:
    TextColor3       : Color3.fromRGB(255, 240, 200)

  PlayerLabel.TextColor3 : Color3.fromRGB(200, 170, 100)

  Animated light rays (2 diagonal UIGradient overlays rotating slowly):
    Ray overlay Frame (×2, stacked):
      Size           : UDim2.fromScale(1, 1)
      BackgroundColor3: Color3.fromRGB(255, 220, 100)
      BackgroundTransparency: 0.88
      UIGradient.Transparency:
        NumberSequence.new({
          NumberSequenceKeypoint.new(0, 1),
          NumberSequenceKeypoint.new(0.3, 0.5),
          NumberSequenceKeypoint.new(0.35, 0.5),
          NumberSequenceKeypoint.new(0.65, 1),
          NumberSequenceKeypoint.new(0.7, 0.5),
          NumberSequenceKeypoint.new(0.75, 0.5),
          NumberSequenceKeypoint.new(1, 1),
        })
      Rotation animation:
        Ray 1: 0° → 360° over 6s, loop
        Ray 2: 180° → 540° over 8s, loop (offset + slower for variety)

  Gold shimmer sweep:
    Overlay tint     : Color3.fromRGB(255, 230, 140)
    Overlay transp   : 0.78
    Duration         : 0.8s, starts at t=0.2s

  Entrance sound: "drop_feed_legendary"
    Character: triumphant horn stab + shimmer tail, ~0.5s

  Mild screen-edge flash on entrance (local player only):
    Frame            : UDim2.fromScale(1, 1), IgnoreGuiInset
    BackgroundColor3 : Color3.fromRGB(255, 220, 80)
    BackgroundTransparency: tween 0.88 → 1 over 0.25s
    UIGradient.Transparency (vignette, edges only):
      NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.3, 1),
        NumberSequenceKeypoint.new(0.7, 1),
        NumberSequenceKeypoint.new(1, 0.3),
      })
    ZIndex           : 510
    Destroy after    : 0.3s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  MYTHIC BANNER — Rainbow gradient cycling, reality-crack edges, pulsing glow
────────────────────────────────────────────────────────────────────────────────

  Root background:
    BackgroundColor3 : Color3.fromRGB(20, 8, 30)
    UIGradient.Color : animated — cycles through mythicRainbowSequence()
      Offset animation: X scrolls from 0 to 1 over 2s, loop
      This creates a flowing rainbow effect across the banner background.

  UIStroke:
    Color            : animated — Color3.fromHSV((time * 0.4) % 1, 0.7, 1)
    Thickness        : 2.5
    Transparency     : animated 0.0 ↔ 0.15 at 2.5 Hz (strong pulse)

  RarityLabel:
    TextColor3       : animated rainbow — same hue cycle as stroke, 0.1s offset
    Text             : "★★★★ MYTHIC"

  PetNameLabel.TextColor3 : Color3.new(1, 1, 1)
  PlayerLabel.TextColor3  : Color3.fromRGB(220, 180, 255)

  Reality-crack edge effect:
    4–6 thin horizontal Frame strips along top and bottom edges of the banner,
    styled as glitch lines (similar to PetEntranceDesignSpec mythic tear):
      Height         : 1–3px each (random per strip)
      Width           : UDim2.new(0, random 40–120px, 0, 0)
      BackgroundColor3: Color3.new(1, 1, 1)
      BackgroundTransparency: 0.2
      Positions       : random Y at edges (0–4px from top, 0–4px from bottom)
      Animation       : slide X from random start to random end over 0.4s,
                        transparency 0.2 → 1, then respawn. Stagger spawns
                        so 1–2 are visible at any time during the hold.
      RotationZ       : random ±3° (slight diagonal for organic feel)

  Pulsing glow (background frame, behind root):
    Size             : UDim2.new(1, 16, 1, 16)
    Position         : centered behind root
    BackgroundColor3 : animated rainbow (same cycle as stroke)
    BackgroundTransparency: oscillates 0.7 ↔ 0.5 at 1.5 Hz
    CornerRadius     : UDim.new(0, 14)
    ZIndex           : root - 2

  Rainbow shimmer sweep:
    Overlay Frame    : white, transparency 0.75
    UIGradient       : same transparency pattern as Rare but wider highlight
    Duration         : 0.6s, starts at t=0.15s

  Entrance sound: "drop_feed_mythic"
    Character: deep bass hit + ascending crystalline cascade + reverb,
    ~0.8s. Should feel like a server-wide event.

  Screen-edge rainbow flash on entrance (local player only):
    Same structure as Legendary edge flash but:
      BackgroundColor3: animated rainbow cycle over 0.5s
      Fade duration   : 0.5s (longer than Legendary)
      Peak transp     : 0.82
      ZIndex          : 515

  Hold duration override: 4.0s (1s longer than other tiers).

  Banner size override: UDim2.new(0, 400, 0, 52)
    (slightly larger than other tiers for mythic gravitas)
]]


--[[
================================================================================
  SECTION B — STORE FOMO BADGES
================================================================================
  Badge overlays for store item cards in StorePanel. Each badge is a small
  tag that overlaps the top-right corner of an item row/card.

  All badges share a base structure, with per-type color/icon/animation.

  Badge placement:
    AnchorPoint      : Vector2.new(1, 0)
    Position         : UDim2.new(1, 4, 0, -6)
    (overlaps top-right corner, peeking above and to the right)
    ZIndex           : row.ZIndex + 10

  Base badge structure:
    Type             : Frame (container)
    Size             : UDim2.fromOffset(78, 22)  (auto-resizes with text)
    BackgroundTransparency: 0.05
    UICorner         : UDim.new(0, 6)
    UIStroke:
      Thickness      : 1
      Transparency   : 0.3
      Color          : per-type (see below)
    ClipsDescendants : false

    Icon (TextLabel, left side):
      Size           : UDim2.fromOffset(18, 22)
      Position       : UDim2.new(0, 4, 0, 0)
      Font           : GothamBold
      TextSize       : 13
      BackgroundTransparency: 1

    Label (TextLabel, right of icon):
      Size           : UDim2.new(1, -24, 1, 0)
      Position       : UDim2.new(0, 22, 0, 0)
      Font           : GothamBold
      TextSize       : 10
      BackgroundTransparency: 1
      TextXAlignment : Left

  Entrance animation (when store panel opens or scrolls badge into view):
    UIScale: 0 → 1.1 over 0.15s (Back Out), then 1.1 → 1.0 over 0.1s
    Stagger: each badge delays entrance by 0.05s × index for a cascade feel.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  "HOT" BADGE — Red fire gradient, pulsing
────────────────────────────────────────────────────────────────────────────────
  Applied to items purchased by many players recently (popularity threshold
  driven by server-side analytics or config flag).

  Colors:
    BackgroundColor3 : Color3.fromRGB(200, 40, 30)
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 50, 20)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 30)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(220, 50, 20)),
                       })
    UIStroke.Color   : Color3.fromRGB(255, 120, 40)

  Icon:
    Text             : "🔥"
    TextSize         : 13

  Label:
    Text             : "HOT"
    TextColor3       : Color3.new(1, 1, 1)

  Animation — pulse:
    UIScale on badge oscillates:
      Range          : 1.0 ↔ 1.06
      Formula        : 1 + 0.06 * (math.sin(os.clock() * 4) + 1) / 2
      Frequency      : 4 rad/s (~0.64 Hz) — gentle, not frantic

    UIGradient.Offset scrolls:
      X              : -0.3 → 0.3 over 2s, ping-pong loop
      Simulates flickering fire/heat shimmer
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  "LOW STOCK" BADGE — Orange warning with countdown placeholder
────────────────────────────────────────────────────────────────────────────────
  Applied to limited-quantity items nearing depletion, or time-limited offers.

  Colors:
    BackgroundColor3 : Color3.fromRGB(180, 100, 20)
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 120, 30)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 90, 15)),
                       })
    UIStroke.Color   : Color3.fromRGB(240, 160, 40)

  Icon:
    Text             : "⚠️"
    TextSize         : 12

  Label:
    Text             : "LOW STOCK" or "ENDS {HH:MM}" (if time-limited)
    TextColor3       : Color3.fromRGB(255, 240, 200)

  Badge size override: UDim2.fromOffset(88, 22) (wider to fit countdown)

  Animation — urgency blink:
    BackgroundTransparency oscillates:
      Range          : 0.05 ↔ 0.18
      Frequency      : 1.2 Hz
      Formula        : 0.05 + 0.13 * (math.sin(os.clock() * 7.5) + 1) / 2

    UIStroke.Transparency oscillates in sync:
      Range          : 0.2 ↔ 0.45

    No scale pulse (avoid competing with HOT badge motion).
    The blink alone conveys urgency without being overwhelming.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  "BEST VALUE" BADGE — Green with star
────────────────────────────────────────────────────────────────────────────────
  Applied to items with the highest value-per-cost ratio. A calm, positive
  endorsement rather than an urgency signal.

  Colors:
    BackgroundColor3 : Color3.fromRGB(30, 150, 60)
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(35, 170, 70)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(25, 130, 50)),
                       })
    UIStroke.Color   : Color3.fromRGB(80, 220, 110)

  Icon:
    Text             : "⭐"
    TextSize         : 12

  Label:
    Text             : "BEST VALUE"
    TextColor3       : Color3.new(1, 1, 1)

  Badge size override: UDim2.fromOffset(92, 22) (wider text)

  Animation — gentle float:
    Position.Y oscillates via UDim offset:
      Range          : -6px ↔ -9px (3px float amplitude)
      Formula        : -6 + math.sin(os.clock() * 2.5) * -1.5
      Frequency      : ~0.4 Hz — slow, calming bob

    No color or scale animation. The stillness relative to HOT/LOW STOCK
    badges communicates reliability rather than urgency.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  "PREMIUM DEAL" BADGE — Gold with diamond icon
────────────────────────────────────────────────────────────────────────────────
  Applied to items with special discounts for premium/VIP players.
  Should feel exclusive and prestigious.

  Colors:
    BackgroundColor3 : Color3.fromRGB(160, 120, 20)
    UIGradient.Color : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 140, 30)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 180, 60)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 140, 30)),
                       })
    UIStroke.Color   : Color3.fromRGB(255, 220, 100)

  Icon:
    Text             : "💎"
    TextSize         : 12

  Label:
    Text             : "PREMIUM"
    TextColor3       : Color3.fromRGB(255, 240, 200)

  Animation — shimmer sweep:
    UIGradient.Offset scrolls along X:
      From           : -1.0
      To             : 1.0
      Duration       : 3s, loop
      EasingStyle    : Linear

    Subtle gold shimmer overlay (same technique as Rare drop banner shimmer):
      Overlay Frame  : BackgroundColor3 white, transparency 0.90
      UIGradient.Transparency:
        NumberSequence.new({
          NumberSequenceKeypoint.new(0, 1),
          NumberSequenceKeypoint.new(0.45, 0.6),
          NumberSequenceKeypoint.new(0.55, 0.6),
          NumberSequenceKeypoint.new(1, 1),
        })
      Offset          : X scrolls -1.5 → 1.5 over 2.5s, loop
      Gives a "premium sheen" effect.
]]


--[[
================================================================================
  SECTION C — SESSION RETENTION POPUP
================================================================================
  Shown when the player has been idle for 2+ minutes (no meaningful input:
  mouse movement, key presses, or touch). Designed to feel warm and inviting,
  NOT like a "are you still there?" dismissal. It reminds the player of what
  they'd miss by leaving.

  Trigger conditions:
    - UserInputService: track time since last InputBegan/InputChanged
    - Threshold: 120 seconds of no input
    - Cooldown: do not show again for 5 minutes after dismiss
    - Suppress during: active driving run, any open panel, tutorial overlay
    - Max shows per session: 3 (avoid annoyance)

  Root container (ScreenGui):
    Name             : "DACRetentionPopup"
    DisplayOrder     : 550
    ResetOnSpawn     : false
    IgnoreGuiInset   : true
    Enabled          : false (toggled by controller)

  Backdrop overlay (full-screen dim):
    Size             : UDim2.fromScale(1, 1)
    BackgroundColor3 : Color3.new(0, 0, 0)
    BackgroundTransparency: 0.55
    ZIndex           : 550

    Particle rain (subtle ambient sparkles scrolling down):
      Implementation : 12–18 small Frame dots spawned at random X across
                       the backdrop, drifting downward:
        Dot size     : 2×2 to 4×4 px
        Color        : Color3.fromRGB(180, 140, 255) with ±20 random variation
        Speed        : 30–60 px/s downward
        Lifetime     : viewport height / speed (screen traversal)
        Transparency : fade in over first 0.3s, fade out over last 0.3s
        Spawn rate   : ~4 dots/s
        Rotation     : slight random drift ±8px horizontal over lifetime
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  POPUP CARD (central content)
────────────────────────────────────────────────────────────────────────────────

  Card frame:
    Name             : "RetentionCard"
    Size             : UDim2.fromOffset(340, 300)
    Position         : UDim2.new(0.5, 0, 0.5, 0)
    AnchorPoint      : Vector2.new(0.5, 0.5)
    BackgroundColor3 : Color3.fromRGB(25, 20, 45)
    BackgroundTransparency: 0.04
    ZIndex           : 555

  UICorner:
    CornerRadius     : UDim.new(0, 14)

  UIStroke:
    Thickness        : 1.5
    Color            : Color3.fromRGB(140, 100, 220)
    Transparency     : 0.15

  Inner glow gradient (UIGradient on card):
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(35, 25, 60)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 20, 45)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(35, 25, 60)),
                       })
    Rotation         : 90

  Entrance animation:
    Card UIScale     : 0.85 → 1.0 over 0.35s (Back Out)
    Card BackgroundTransparency: 0.5 → 0.04 over 0.2s
    Backdrop transparency: 1 → 0.55 over 0.3s

  ── Header ──
    Name             : "HeaderLabel"
    Text             : "Don't go yet!"
    Font             : GothamBlack
    TextSize         : 22
    TextColor3       : Color3.fromRGB(255, 220, 140)
    Position         : UDim2.new(0.5, 0, 0, 20)
    AnchorPoint      : Vector2.new(0.5, 0)
    Size             : UDim2.new(1, -32, 0, 28)
    TextXAlignment   : Center
    BackgroundTransparency: 1
    ZIndex           : 560

  ── Dismiss X button (top-right, small and muted) ──
    Name             : "DismissBtn"
    Type             : TextButton
    Text             : "✕"
    Font             : GothamBold
    TextSize         : 14
    TextColor3       : Color3.fromRGB(120, 100, 140)
    Size             : UDim2.fromOffset(28, 28)
    Position         : UDim2.new(1, -6, 0, 6)
    AnchorPoint      : Vector2.new(1, 0)
    BackgroundTransparency: 1
    ZIndex           : 565

    Hover state:
      TextColor3 → Color3.fromRGB(180, 160, 200) on MouseEnter
      TextColor3 → Color3.fromRGB(120, 100, 140) on MouseLeave
      Tween duration: 0.1s

    Intentionally small and low-contrast to de-emphasize dismissal.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  RETENTION CONTENT ROWS (dynamic, 2–3 shown based on player state)
────────────────────────────────────────────────────────────────────────────────
  Each row shows something the player would miss. Rows are populated
  dynamically based on which data is available for the player.

  Row container:
    Name             : "ContentRows"
    Type             : Frame
    Size             : UDim2.new(1, -32, 0, 155)
    Position         : UDim2.new(0, 16, 0, 58)
    BackgroundTransparency: 1
    UIListLayout:
      SortOrder      : LayoutOrder
      Padding        : UDim.new(0, 10)

  ── Row template ──
    Size             : UDim2.new(1, 0, 0, 42)
    BackgroundColor3 : Color3.fromRGB(35, 28, 55)
    BackgroundTransparency: 0.2
    UICorner         : UDim.new(0, 8)
    ZIndex           : 558

    Icon (left):
      Type           : TextLabel
      Size           : UDim2.fromOffset(28, 42)
      Position       : UDim2.new(0, 8, 0, 0)
      TextSize       : 18
      BackgroundTransparency: 1

    Description (center):
      Type           : TextLabel
      Size           : UDim2.new(1, -110, 1, 0)
      Position       : UDim2.new(0, 40, 0, 0)
      Font           : Gotham
      TextSize       : 12
      TextColor3     : Color3.fromRGB(220, 210, 240)
      TextXAlignment : Left
      TextWrapped    : true
      BackgroundTransparency: 1

    Progress bar (right side, if applicable):
      Name           : "ProgressBar"
      Size           : UDim2.new(0, 60, 0, 8)
      Position       : UDim2.new(1, -12, 0.5, 0)
      AnchorPoint    : Vector2.new(1, 0.5)

      Background     : Color3.fromRGB(50, 40, 70)
      Fill color     : per-row accent (see below)
      UICorner       : UDim.new(0, 4)

  ── Row variants ──

  Row: Daily Streak
    Icon             : "🔥"
    Text             : "Your streak is at {n} days!"
    ProgressBar      : n / 7 fill (weekly cycle)
    Fill color       : Color3.fromRGB(255, 140, 40)
    Show condition   : player has active daily streak

  Row: Daily Bonus
    Icon             : "🎁"
    Text             : "Daily bonus in {MM:SS}!"
    ProgressBar      : countdown fraction remaining
    Fill color       : Color3.fromRGB(100, 200, 255)
    Show condition   : daily bonus not yet claimed today

  Row: Rebirth Progress
    Icon             : "⚡"
    Text             : "You're {n}% to next rebirth!"
    ProgressBar      : n / 100 fill
    Fill color       : Color3.fromRGB(180, 100, 255)
    Show condition   : rebirth progress > 30% (don't show if barely started)

  Row: Playtime Gem
    Icon             : "💎"
    Text             : "Playtime gem in {M:SS}!"
    ProgressBar      : timer fraction remaining
    Fill color       : Color3.fromRGB(180, 120, 255)
    Show condition   : playtime gem timer is active

  Row: Battle Pass
    Icon             : "🏆"
    Text             : "{n} unclaimed BP rewards!"
    No progress bar  — just text
    Show condition   : player has unclaimed battle pass rewards

  Row priority order: Daily Streak > Rebirth > Daily Bonus > Playtime Gem > Battle Pass
  Show top 3 available rows. If fewer than 2 rows qualify, do not show the popup
  (not enough value to display).

  Row entrance animation:
    Each row slides in from the right with staggered delay:
      Offset         : UDim2.fromOffset(40, 0)
      Tween to 0     : 0.25s (Quad Out)
      Stagger        : 0.08s per row
      Rows also fade: BackgroundTransparency 0.8 → 0.2 over 0.2s
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  CTA BUTTON — "Keep Playing!"
────────────────────────────────────────────────────────────────────────────────
  The primary action. Larger, brighter, more prominent than the dismiss X.

  Button:
    Name             : "KeepPlayingBtn"
    Type             : TextButton
    Size             : UDim2.new(0.7, 0, 0, 44)
    Position         : UDim2.new(0.5, 0, 1, -22)
    AnchorPoint      : Vector2.new(0.5, 1)
    BackgroundColor3 : Color3.fromRGB(80, 200, 100)
    ZIndex           : 560

  UICorner:
    CornerRadius     : UDim.new(0, 10)

  UIStroke:
    Thickness        : 1.5
    Color            : Color3.fromRGB(120, 255, 150)
    Transparency     : 0.2

  UIGradient on button:
    Color            : ColorSequence.new({
                         ColorSequenceKeypoint.new(0,   Color3.fromRGB(60, 190, 90)),
                         ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 120)),
                         ColorSequenceKeypoint.new(1,   Color3.fromRGB(60, 190, 90)),
                       })

  Label:
    Text             : "Keep Playing!"
    Font             : GothamBlack
    TextSize         : 18
    TextColor3       : Color3.new(1, 1, 1)
    TextStrokeColor3 : Color3.fromRGB(20, 80, 30)
    TextStrokeTransparency: 0.6

  Idle animation (gentle pulse to draw attention):
    UIScale          : oscillates 1.0 ↔ 1.04
    Frequency        : 1.5 Hz
    Formula          : 1 + 0.04 * (math.sin(os.clock() * 9.4) + 1) / 2

    UIStroke.Transparency oscillates:
      Range          : 0.2 ↔ 0.05
      Synced with scale pulse

  Hover state:
    BackgroundColor3 → Color3.fromRGB(100, 230, 130) over 0.12s
    UIScale → 1.06 over 0.12s

  Click feedback:
    UIScale → 0.94 instantly, then → 1.0 over 0.15s (Back Out)
    SoundFacade.playOneShot("ui_confirm")

  On click behavior:
    1. Dismiss popup (exit animation, see below)
    2. Reset idle timer
    3. Optionally: grant a tiny bonus (e.g. +30s on playtime gem timer)
       to reward staying. Configured server-side.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  EXIT ANIMATION (dismiss or "Keep Playing")
────────────────────────────────────────────────────────────────────────────────

  Card:
    UIScale: 1.0 → 0.9 over 0.2s (Quad In)
    BackgroundTransparency: 0.04 → 0.6 over 0.2s
    (card shrinks and fades)

  Backdrop:
    BackgroundTransparency: 0.55 → 1 over 0.25s

  Particle rain: stop spawning immediately, let existing dots finish.

  After 0.3s: gui.Enabled = false, destroy temporary UI elements.

  If "Keep Playing!" was clicked:
    Play "ui_confirm" sound (already handled by click feedback).
    Brief green flash on screen edges (celebratory micro-feedback):
      Same structure as Legendary banner edge flash but green:
        Color          : Color3.fromRGB(80, 220, 100)
        Fade duration  : 0.2s
        Peak transp    : 0.9
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — FULL POPUP LIFECYCLE
================================================================================

  Idle detection:
    t=0s      Last meaningful input recorded
    t=120s    Idle threshold reached → check suppression conditions
    t=120s    If eligible → show popup

  Popup entrance:
    t=0.00s   ScreenGui enabled, backdrop fades in
    t=0.05s   Card scales in (0.85→1.0)
    t=0.15s   Header label visible
    t=0.20s   Row 1 slides in
    t=0.28s   Row 2 slides in
    t=0.36s   Row 3 slides in
    t=0.40s   CTA button pulse begins
    t=0.50s   Particle rain starts

  Player reads content... (~5–15s typically)

  Dismiss ("Keep Playing!" or X):
    t=0.00s   Click feedback
    t=0.00s   Card shrinks, backdrop fades
    t=0.25s   Popup fully hidden
    t=0.25s   Cooldown timer starts (5 minutes)

  Total entrance: ~0.5s. Total exit: ~0.3s.
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs to add to SoundConfig / SoundController:

  drop_feed_epic              — soft magical chime (0.3s)
  drop_feed_legendary         — triumphant horn stab + shimmer (0.5s)
  drop_feed_mythic            — bass hit + crystalline cascade + reverb (0.8s)
  retention_popup_open        — warm ambient chime, inviting (0.4s)
  ui_confirm                  — already exists, reused for CTA click

  Rare banner has no entrance sound (clean and understated by design).
================================================================================
]]


--[[
================================================================================
  ACCESSIBILITY & PERFORMANCE NOTES
================================================================================

  Performance:
    - Drop feed banners: max 1 on screen. Queue excess. Lightweight tweens only.
    - FOMO badges: static once entrance completes. Oscillation anims use
      RenderStepped only while StorePanel is open (disconnect on close).
    - Retention popup: particle rain uses simple Frame dots, not
      ParticleEmitter. Max 18 dots alive. Spawner disconnects on close.
    - All animated UIGradients use Offset tweens (GPU-friendly).

  Accessibility:
    - Drop feed banner text meets 4.5:1 contrast ratio against background.
    - FOMO badge text meets 3:1 contrast (small text, large font exception).
    - Retention popup dismiss X has generous hit area (28×28px) despite
      small visual size.
    - CTA button is large, high-contrast, centered — trivially findable.

  Mobile considerations:
    - Drop feed banner width: use math.min(380, viewportWidth - 32) to
      prevent overflow on narrow screens.
    - FOMO badges: scale down to 70% on screens < 600px wide.
    - Retention popup card: clamp width to math.min(340, viewportWidth - 40).
================================================================================
]]

return nil
