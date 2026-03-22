--!strict
--[[
	INVENTORY COLLECTION GAME — DESIGN SPEC
	========================================
	Transforms the Garage/Inventory panel from a flat item list into a
	collection game with visible progress, rarity tiers, set completion
	bonuses, and discovery mechanics. The goal: players open the
	inventory not just to equip — they open it to ADMIRE, to COUNT,
	and to hunt the gaps.

	Psychology: Collection completion is one of the most powerful
	retention drivers in simulator games. A 12/14 progress bar is
	inherently more motivating than a list of 12 items. The "Zeigarnik
	effect" — uncompleted tasks nag at the brain — turns every missing
	pet or car into a reason to play another session.

	Existing state (InventoryPanel.luau):
	  - "Garage" title, scrolling grid of car + pet cards
	  - Cars show name, stats, equip button
	  - Locked cars show "???" with buy/unlock prompt
	  - Pets show name, power, equip button
	  - Equip triggers scalePunch, rarityPulseStroke, worldGlowPulse
	  - No collection progress, no rarity grouping, no completion tracking

	This spec adds:
	  1. Collection header with overall progress ring
	  2. Rarity-grouped sections with section progress bars
	  3. "Set bonus" display for completed rarity tiers
	  4. Mystery silhouettes for undiscovered pets
	  5. "New!" badge system for recently acquired items
	  6. Collection milestone celebrations

	Reference files:
	  - DACStarterGui/InventoryPanel.luau (implementation target)
	  - DACReplicatedStorage/Config/PetConfig.luau (pet catalog)
	  - DACReplicatedStorage/Config/CarConfig.luau (car catalog)
	  - DACReplicatedStorage/Constants.luau (rarity colors/order)
	  - DACStarterGui/PetIndexPanel.luau (existing pet index, if any)
]]


--[[
================================================================================
  SECTION A — COLLECTION HEADER WITH PROGRESS RING
================================================================================
  A prominent header at the top of the inventory panel that shows
  overall collection completion. This is the first thing the player
  sees — a big, satisfying number that demands to be 100%.

  Layout (replaces or augments existing "Garage" title bar):

    ┌──────────────────────────────────────────────┐
    │  ◐  COLLECTION  ·  23 / 28  ·  82%          │
    │  [████████████████████░░░░]  3 new!          │
    └──────────────────────────────────────────────┘

  HEADER FRAME:
    Name           : "CollectionHeader"
    Size           : UDim2.new(1, -24, 0, 72)
    BackgroundColor3: Color3.fromRGB(20, 18, 40)
    BackgroundTransparency: 0.1
    LayoutOrder    : 0

    UICorner       : UDim.new(0, 12)

    UIStroke:
      Color        : Color3.fromRGB(100, 120, 200)
      Thickness    : 1.5
      Transparency : 0.4

  PROGRESS RING (left side):
    Implemented as a circular Frame with a conic gradient stroke.
    Since Roblox doesn't have native conic gradients, approximate
    with a ring of 12 small arc segments (Frame wedges) or use a
    simple filled arc via ImageLabel with radial fill.

    Simplified approach — circular progress via two overlapping arcs:
      Ring background Frame:
        Name         : "ProgressRing"
        Size         : UDim2.fromOffset(48, 48)
        Position     : UDim2.new(0, 12, 0.5, 0)
        AnchorPoint  : Vector2.new(0, 0.5)
        BackgroundColor3: Color3.fromRGB(40, 40, 60)
        CornerRadius : UDim.new(0.5, 0) (circular)

      Inner circle (cutout):
        Size         : UDim2.fromOffset(36, 36)
        AnchorPoint  : Vector2.new(0.5, 0.5)
        Position     : UDim2.fromScale(0.5, 0.5)
        BackgroundColor3: Color3.fromRGB(20, 18, 40) (match header bg)
        CornerRadius : UDim.new(0.5, 0)
        ZIndex       : ring.ZIndex + 2

      Percentage text (centered in ring):
        Text         : `{percent}%`
        Font         : GothamBold
        TextSize     : 12
        TextColor3   : Color3.new(1, 1, 1)
        ZIndex       : ring.ZIndex + 3

      Ring fill:
        Use UIGradient on the ring background to show fill.
        At completion, the ring color shifts from blue to gold.
        < 50%  : Color3.fromRGB(100, 140, 255)  (cool blue)
        50-89% : Color3.fromRGB(180, 140, 255)  (purple)
        90-99% : Color3.fromRGB(255, 200, 80)   (gold, almost there!)
        100%   : Color3.fromRGB(120, 255, 160)  (green, COMPLETE)

  TITLE + COUNT (center):
    Title label:
      Text         : "COLLECTION"
      Font         : GothamBold
      TextSize     : 18
      TextColor3   : Color3.fromRGB(230, 230, 255)
      Position     : UDim2.new(0, 70, 0, 8)

    Count label:
      Text         : `{owned} / {total}`
      Font         : GothamMedium
      TextSize     : 15
      TextColor3   : Color3.fromRGB(180, 190, 220)
      Position     : UDim2.new(0, 70, 0, 30)

  PROGRESS BAR (below title):
    Frame:
      Name         : "CollectionBar"
      Size         : UDim2.new(1, -80, 0, 8)
      Position     : UDim2.new(0, 70, 0, 52)
      BackgroundColor3: Color3.fromRGB(40, 40, 60)
      CornerRadius : UDim.new(0, 4)

    Fill Frame:
      Size         : UDim2.new(percent/100, 0, 1, 0)
      BackgroundColor3: ring fill color (same tier)
      CornerRadius : UDim.new(0, 4)

      UIGradient on fill:
        Color       : ColorSequence.new({
                        ColorSequenceKeypoint.new(0, fillColor),
                        ColorSequenceKeypoint.new(1, fillColor:Lerp(Color3.new(1,1,1), 0.2)),
                      })

  "NEW" COUNT (right side, if any new items):
    TextLabel:
      Text         : `{newCount} new!`
      Font         : GothamBold
      TextSize     : 13
      TextColor3   : Color3.fromRGB(80, 220, 255)
      AnchorPoint  : Vector2.new(1, 0.5)
      Position     : UDim2.new(1, -12, 0.5, 0)

    Pulse animation:
      UIScale oscillates 1.0 ↔ 1.05, period 2s
================================================================================
]]


--[[
================================================================================
  SECTION B — RARITY-GROUPED SECTIONS
================================================================================
  Items are organized into collapsible sections by rarity tier. Each
  section has its own header with a mini progress bar, creating
  multiple parallel collection goals.

  Section order (top to bottom):
    Mythic → Legendary → Epic → Rare → Uncommon → Common

  Reverse order (rarest first) is intentional — it puts the exciting,
  aspirational items at the top where they're visible immediately.
  Players scroll DOWN to see their common items, not UP to find the
  rare ones. This creates a "window shopping" effect for uncollected
  rarity tiers.

  SECTION HEADER:
    Frame:
      Name         : "RarityHeader_{rarity}"
      Size         : UDim2.new(1, 0, 0, 36)
      BackgroundColor3: Color3.fromRGB(30, 28, 55)
      BackgroundTransparency: 0.2

      UICorner     : UDim.new(0, 8)

    Rarity dot (color indicator):
      Frame:
        Size       : UDim2.fromOffset(12, 12)
        Position   : UDim2.new(0, 10, 0.5, 0)
        AnchorPoint: Vector2.new(0, 0.5)
        BackgroundColor3: Constants.RARITY_COLORS[rarity]
        CornerRadius: UDim.new(0.5, 0)

    Section title:
      Text         : `{RARITY_NAME}  ·  {owned}/{total}`
      Font         : GothamBold
      TextSize     : 14
      TextColor3   : Constants.RARITY_COLORS[rarity]
      Position     : UDim2.new(0, 28, 0, 0)

    Mini progress bar:
      Frame:
        Size       : UDim2.new(0.3, 0, 0, 4)
        AnchorPoint: Vector2.new(1, 0.5)
        Position   : UDim2.new(1, -10, 0.5, 0)
        BackgroundColor3: Color3.fromRGB(40, 40, 60)
        CornerRadius: UDim.new(0, 2)

      Fill:
        Size       : UDim2.new(owned/total, 0, 1, 0)
        BackgroundColor3: Constants.RARITY_COLORS[rarity]

    COMPLETE badge (when owned == total):
      TextLabel to the left of the progress bar:
        Text       : "✓ COMPLETE"
        Font       : GothamBold
        TextSize   : 10
        TextColor3 : Color3.fromRGB(120, 255, 160)

  COLLAPSE BEHAVIOR:
    Tapping a section header toggles visibility of items in that section.
    Default state: all sections expanded.
    Collapsed sections show only the header (items hidden).
    Arrow indicator on right: "▼" (expanded) / "▶" (collapsed)
================================================================================
]]


--[[
================================================================================
  SECTION C — SET COMPLETION BONUSES
================================================================================
  When a player completes an entire rarity tier (owns every pet of
  that rarity), they earn a permanent passive bonus. This transforms
  collection from "nice to have" into a strategic power goal.

  Set bonuses (displayed on section header when complete):

    Common complete    : +2% coin earnings (permanent)
    Uncommon complete  : +3% coin earnings (permanent)
    Rare complete      : +5% coin earnings (permanent)
    Epic complete      : +8% coin earnings (permanent)
    Legendary complete : +12% coin earnings (permanent)
    Mythic complete    : +20% coin earnings (permanent)
    ALL COMPLETE       : +50% coin earnings (stacks with above)
                         "Collector Crown" title

  Bonus display on section header (when complete):
    TextLabel appended to title line:
      Text         : `+{bonus}% coins`
      Font         : GothamBold
      TextSize     : 11
      TextColor3   : Color3.fromRGB(255, 220, 80)
      Shimmer      : UIGradient offset scroll -1→1 over 4s

  ALL COMPLETE banner (at top of inventory, above CollectionHeader):
    Only visible when every single item is collected.
    Frame:
      Size         : UDim2.new(1, -24, 0, 40)
      BackgroundColor3: Color3.fromRGB(40, 30, 15)

    UIGradient with animated gold sweep:
      Color        : gold → white → gold sequence
      Offset scroll: -1 → 1 over 3s, loop

    Text: "MASTER COLLECTOR — +50% All Coins"
    Font: GothamBlack, TextSize 16
    TextColor3: Color3.fromRGB(255, 220, 80)

  Config storage (for server validation):
    SetBonusConfig module in DACReplicatedStorage/Config/:
      Maps rarity → bonus multiplier
      Server applies multiplicatively to base coin earnings
      Client displays on inventory UI
================================================================================
]]


--[[
================================================================================
  SECTION D — MYSTERY SILHOUETTES
================================================================================
  Undiscovered pets show as dark silhouettes with "???" names. This
  creates curiosity and the urge to discover what's hidden. Players
  can see HOW MANY they're missing without knowing WHAT — the gap
  between knowledge and ignorance is the curiosity engine.

  For pets the player has NEVER owned (not in data.pets history):

    Card appearance:
      BackgroundColor3: Color3.fromRGB(25, 25, 35) (very dark)
      BackgroundTransparency: 0.15

    Silhouette icon:
      TextLabel:
        Text       : "?"
        Font       : GothamBlack
        TextSize   : 32
        TextColor3 : Color3.fromRGB(60, 60, 80)
        AnchorPoint: Vector2.new(0.5, 0.5)
        Position   : UDim2.fromScale(0.5, 0.4)

    Name label:
      Text       : "???"
      TextColor3 : Color3.fromRGB(80, 80, 100)

    Rarity hint (subtle border glow):
      UIStroke:
        Color      : Constants.RARITY_COLORS[rarity]:Lerp(Color3.new(0,0,0), 0.6)
                     (very dim version of the rarity color — hints at tier)
        Thickness  : 1
        Transparency: 0.6

    Source hint:
      Small text at bottom of card:
        Text       : `From {eggName} Egg` or `From {worldName}`
        Font       : Gotham
        TextSize   : 9
        TextColor3 : Color3.fromRGB(100, 100, 120)
      This tells the player WHERE to hunt without telling them WHAT.

  Tap on mystery card:
    Brief shake animation (card Rotation: 0→2→-2→0 over 0.25s)
    No information revealed — just a tactile acknowledgment.
    Optional: SoundFacade.playOneShot("ui_tick")
================================================================================
]]


--[[
================================================================================
  SECTION E — "NEW!" BADGE SYSTEM
================================================================================
  Items acquired since the player's last inventory visit get a "NEW!"
  badge. This creates a reason to check inventory after every session.

  Tracking:
    Client tracks `lastInventoryViewTimestamp` (local, per session).
    On DataUpdate, compare each pet/car's acquisition timestamp
    against lastInventoryViewTimestamp. If newer → mark as "new".
    When inventory panel becomes Visible, update the timestamp.

  "NEW!" badge per card:
    Frame:
      Name         : "NewBadge"
      AnchorPoint  : Vector2.new(0, 0)
      Position     : UDim2.new(0, -4, 0, -4)
      Size         : UDim2.fromOffset(44, 18)
      BackgroundColor3: Color3.fromRGB(60, 180, 255)
      CornerRadius : UDim.new(0, 6)
      ZIndex       : card.ZIndex + 5

    TextLabel:
      Text         : "NEW!"
      Font         : GothamBold
      TextSize     : 10
      TextColor3   : Color3.new(1, 1, 1)

    Animation:
      Badge entrance on panel open:
        UIScale: 0 → 1.15 over 0.15s (Back Out)
        Then 1.15 → 1.0 over 0.08s
        Stagger: 0.05s per new-badge index

      Idle pulse:
        UIScale oscillates 1.0 ↔ 1.06, period 2s
        BackgroundTransparency oscillates 0 ↔ 0.08

    Badge removal:
      After 3 seconds of the card being visible on screen, fade
      the badge: TextTransparency 0→1, BackgroundTransparency 0→1
      over 0.3s. Destroy after fade.
      The "new" feeling is fleeting — the badge serves its purpose
      (draw attention) and then gets out of the way.
================================================================================
]]


--[[
================================================================================
  SECTION F — COLLECTION MILESTONE CELEBRATIONS
================================================================================
  When the player crosses a collection percentage threshold, fire
  a micro-celebration. These thresholds create predictable dopamine
  hits spaced throughout the collection journey.

  Milestone thresholds: 25%, 50%, 75%, 90%, 100%

  Detection:
    On DataUpdate, compute new percentage. Compare against stored
    last-milestone. If a new threshold was crossed, fire celebration.
    Store reached milestones in player data to prevent repeats.

  Celebration (25%, 50%, 75%):
    Banner popup at top of inventory:
      Text         : `{percent}% COLLECTED!`
      Font         : GothamBold
      TextSize     : 22
      TextColor3   : milestone-tier color (blue→purple→gold)

      Entrance:
        Position Y : -40px → 10px over 0.35s (Bounce Out)
        UIScale    : 0 → 1.15 → 1.0

      Hold: 2.5s

      Exit:
        TextTransparency: 0 → 1 over 0.3s
        Destroy

    Sparkle burst: 8 dot Frames from banner center, radial spread
      Color      : milestone color
      Speed      : 60–120 px/s
      Lifetime   : 0.3–0.5s

    Sound: "level_up" (existing)

  Celebration (90%):
    Same as above but larger, with additional:
      Text         : "90% — ALMOST THERE!"
      Subtitle     : `Only {remaining} left to find!`
      Banner color shifts to gold

  Celebration (100% — GRAND):
    Full-screen overlay (similar to daily reward jackpot):
      Dim background
      Title        : "MASTER COLLECTOR!"
      Subtitle     : "+50% Coin Bonus Unlocked!"
      Rainbow gradient scroll on title
      Firework burst particles (reuse from PayoutPanelDesignSpec)
      Crown icon above title: "👑"
      Sound: "level_up" × 2 (double sting, staggered 0.3s)
      Duration: 4s + dismiss on tap

    This is the game's biggest non-purchase celebration. The player
    has done something genuinely hard and should feel it.
================================================================================
]]


--[[
================================================================================
  SECTION G — CARD VISUAL ENHANCEMENTS BY RARITY
================================================================================
  Each rarity tier gets a distinct visual treatment on the item card.
  This makes higher-rarity cards feel more valuable at a glance.

  Common:
    Border        : 1px, Color3.fromRGB(180, 180, 180), transparency 0.5
    Background    : Color3.fromRGB(240, 240, 240)
    No special effects.

  Uncommon:
    Border        : 1.5px, Color3.fromRGB(80, 200, 80), transparency 0.35
    Background    : Color3.fromRGB(235, 250, 235)
    Subtle green tint.

  Rare:
    Border        : 2px, Color3.fromRGB(60, 130, 255), transparency 0.25
    Background    : Color3.fromRGB(230, 240, 255)
    UIGradient    : faint blue shimmer sweep (offset scroll, 6s period)

  Epic:
    Border        : 2px, Color3.fromRGB(180, 60, 255), transparency 0.2
    Background    : Color3.fromRGB(245, 235, 255)
    UIGradient    : purple shimmer sweep (4s period)
    Corner sparkle: spawn 1 small sparkle dot every 3s at random corner

  Legendary:
    Border        : 2.5px, Color3.fromRGB(255, 200, 50), transparency 0.15
    Background    : Color3.fromRGB(255, 250, 235)
    UIGradient    : gold shimmer sweep (3s period)
    Corner sparkles: 2 dots every 2.5s
    Border pulse  : thickness oscillates 2.5 ↔ 3.5 over 3s

  Mythic:
    Border        : 3px, animated color cycle:
                    red → orange → gold → purple → blue → red (5s loop)
    Background    : Color3.fromRGB(250, 240, 245)
    UIGradient    : rainbow shimmer sweep (2.5s period)
    Corner sparkles: 3 dots every 2s, rainbow colors
    Glow ring     : outer Frame behind card, 4px larger each side,
                    BackgroundColor3 cycles with border
                    BackgroundTransparency oscillates 0.7 ↔ 0.85

  Performance: RenderStepped animations only active while the card
  is visible within the ScrollingFrame's canvas. Disconnect when the
  inventory panel is hidden.
================================================================================
]]


--[[
================================================================================
  SECTION H — TAB SYSTEM
================================================================================
  Split inventory into two tabs: Cars and Pets. Each tab maintains
  its own collection progress and section grouping.

  Tab bar (below CollectionHeader):
    Frame:
      Size         : UDim2.new(1, -24, 0, 36)
      BackgroundTransparency: 1
      LayoutOrder  : 1

    Two TextButtons, each 50% width:
      Active tab:
        BackgroundColor3: Color3.fromRGB(60, 55, 100)
        TextColor3    : Color3.new(1, 1, 1)
        Bottom border : 3px UIStroke, Color3.fromRGB(120, 140, 255)

      Inactive tab:
        BackgroundColor3: Color3.fromRGB(30, 28, 55)
        TextColor3    : Color3.fromRGB(140, 140, 160)
        Bottom border : none

    Tab switch animation:
      Active tab indicator slides horizontally:
        Position X tween: 0.25s, Quad Out
      Content fades: TextTransparency 0→0.5→0 (0.15s cross-fade)

  Cars tab:
    Groups by world: Grasslands → Desert → Frozen → Neon → Volcano
    Each world section shows world-themed header color
    Progress per world: "3/5 cars collected"

  Pets tab:
    Groups by rarity: Mythic → Legendary → Epic → Rare → Uncommon → Common
    Mystery silhouettes for undiscovered
    Set bonus indicators
================================================================================
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — INVENTORY PANEL OPEN
================================================================================

  t=0.00s   Panel becomes Visible
  t=0.00s   CollectionHeader enters:
              Progress ring counts up from 0% to actual% over 0.6s
              Count text counts up in sync
              Bar fill animates from 0 to actual width
  t=0.05s   Tab bar appears (instant, no animation)
  t=0.10s   First rarity section header fades in
  t=0.15s   Item cards begin cascading:
              Stagger: 0.03s per card
              Per card: UIScale 0 → 1.05 → 1.0 (0.18s total)
  t=0.20s   "NEW!" badges begin entering on new items
              Stagger: 0.05s per badge
  t=0.40s   Mystery silhouettes fade in (slightly delayed for drama)
  t=0.60s   Progress ring settles at final value
  t=0.65s   If milestone crossed → milestone celebration fires

  Total entrance: ~0.65s for a visually rich, information-dense panel.
  Cards are interactable immediately (no blocking animations).
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Card shimmer effects: max 6 active RenderStepped connections
      (only for visible Epic+ cards in the viewport)
    - Mystery silhouette shake: one-shot TweenService (no persistent conn)
    - Progress ring counter: one connection, disconnects after 0.6s
    - "NEW!" badge pulses: max 5 concurrent (oldest badges auto-fade)
    - Section collapse: instant Visible toggle, no tween needed

  Accessibility:
    - Rarity is communicated via color AND text label AND border treatment
    - Mystery cards have "Undiscovered" aria hint
    - All touch targets >= 44×44px
    - Progress percentage shown as number AND visual bar (dual encoding)
    - Colorblind: rarity names displayed alongside color indicators

  Mobile scaling:
    - Viewports < 600px: 2 cards per row (down from 3)
    - Viewports < 400px: 1 card per row, section headers compress
    - CollectionHeader reduces to 56px height, ring to 36×36

  Budget:
    - Max 6 RenderStepped property updates per frame
    - Card cascade uses TweenService (one-shot per card)
    - No ParticleEmitters (all effects are Frame property animations)
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  No new sound effects needed. Reuse existing:

  ui_tick     — mystery card tap
  click       — tab switch, section collapse
  level_up    — collection milestone celebrations
  equip_item  — existing equip interactions
================================================================================
]]

return nil
