--!strict
--[[
	PET FUSION CLIENT UI — Design Spec
	====================================
	This file specifies the complete client-side UI, UX flow, animation,
	and sound design for the Pet Fusion system.

	Server-side:
	  - PetService.fusePets() already handles validation, cost, and result.
	  - Remote: "FusePets" (client → server), "FusionResult" (server → client).
	  - PetConfig.FuseCost = { petsRequired = 3, coinCost = 10_000, coinCostMultiplier = 5 }.
	  - Rarity progression: common → uncommon → rare → epic → legendary → mythic.
	  - Mythic pets cannot be fused (terminal rarity).

	Reference files:
	  - DACStarterGui/InventoryPanel.luau (inventory grid, equip badge patterns)
	  - DACStarterGui/PetEntranceDesignSpec.luau (per-rarity entrance VFX)
	  - DACStarterGui/RebirthHatchDesignSpec.luau (dramatic reveal sequences)
	  - DACReplicatedStorage/Config/PetConfig.luau (pet definitions, fuse cost)
	  - DACServerScriptService/Services/PetService.luau (fusePets handler)
	  - DACReplicatedStorage/Remotes.luau (FusePets, FusionResult events)
]]


--[[
================================================================================
  SECTION A — ACCESS POINT & ENTRY
================================================================================
  Where players find and launch the fusion UI. Must be discoverable but not
  disruptive — fusion is a mid-game feature that new players shouldn't see
  until they have enough pets to use it.
================================================================================
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  ACCESS POINT: "FUSE" TAB IN INVENTORY PANEL
────────────────────────────────────────────────────────────────────────────────
  The Inventory (Garage) panel gains a horizontal tab bar at the top, below
  the title bar:

    ┌─────────────────────────────────────────────┐
    │  Garage                              [X]    │
    │  [Cars]  [Pets]  [★ Fuse]                   │
    │  ─────────────────────────────────────────── │
    │               (content area)                 │
    └─────────────────────────────────────────────┘

  Tab bar specs:
    Position     : UDim2.new(0, 12, 0, 46)
    Size         : UDim2.new(1, -24, 0, 36)
    Layout       : UIListLayout (Horizontal, 8px padding)
    Each tab     : TextButton, 90×32, rounded 6px corners
    Active tab   : BackgroundColor3 = Color3.fromRGB(76, 175, 80), white text
    Inactive tab : BackgroundColor3 = Color3.fromRGB(50, 55, 70), gray text

  The [★ Fuse] tab label uses a star prefix to signal "special". The tab
  is HIDDEN until the player owns >= 3 pets of any single species rarity
  (the minimum needed to fuse). Once visible, it stays visible for the
  session even if pets are consumed.

  Tapping [★ Fuse] replaces the scroll content with the Fusion UI
  (Section B below). Tapping [Cars] or [Pets] returns to the existing
  InventoryPanel scroll content (split into two tabs for clarity, though
  this is optional — the Engineer may keep a single "All" view if simpler).

  ALTERNATIVE ENTRY — "Fuse" button per pet card:
    On each pet card in the Pets tab, if the player owns >= 3 pets of that
    rarity, show a small "Fuse" icon button (16×16, positioned top-left
    corner). Tapping it switches to the Fuse tab with that rarity pre-
    filtered and the tapped pet pre-selected as the first sacrifice.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  VISIBILITY GATING
────────────────────────────────────────────────────────────────────────────────
  The Fuse tab only appears when canFuse(data) returns true:

    function canFuse(data): boolean
      Count pets by rarity (excluding mythic).
      Return true if ANY rarity group has >= PetConfig.FuseCost.petsRequired.

  This prevents new players from seeing a confusing "Fuse" tab before they
  have enough pets. The check runs on DataUpdate so the tab appears live
  when the player's 3rd pet of a rarity arrives from a hatch.
]]


--[[
================================================================================
  SECTION B — FUSION UI LAYOUT
================================================================================
  The fusion screen occupies the same content area as the inventory scroll.
  It has three zones stacked vertically:
    1. Rarity filter bar
    2. Pet selection grid
    3. Fusion preview & confirm area
================================================================================
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  ZONE 1 — RARITY FILTER BAR
────────────────────────────────────────────────────────────────────────────────
  A horizontal row of rarity filter pills. Only rarities with >= 3 owned
  pets are interactable; others are dimmed.

    [Common ✓] [Uncommon] [Rare] [Epic] [Legendary]   (no Mythic pill)

  Layout:
    Position     : UDim2.new(0, 0, 0, 0)   (relative to content area top)
    Size         : UDim2.new(1, 0, 0, 34)
    UIListLayout : Horizontal, 6px padding, center-aligned

  Each pill:
    Size         : UDim2.new(0, 90, 0, 28)
    Font         : GothamBold, 12px
    Corners      : UICorner 6px
    Active       : BackgroundColor3 = RARITY_UI_GLOW[rarity], white bold text
    Inactive OK  : BackgroundColor3 = Color3.fromRGB(60, 60, 75), light gray text
    Inactive dim : BackgroundColor3 = Color3.fromRGB(40, 40, 50), dark gray text,
                   AutoButtonColor = false

  A count badge (small circle, top-right) shows owned count per rarity:
    Size         : UDim2.fromOffset(22, 18)
    Position     : UDim2.new(1, -4, 0, -2)
    AnchorPoint  : Vector2.new(1, 0)
    BackgroundColor3 : Color3.fromRGB(30, 30, 40)
    Font         : GothamBold, 10px, white
    Text         : tostring(count)

  Selecting a rarity pill filters the grid below to show only pets of that
  rarity. Default selection: the lowest rarity with >= 3 pets.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ZONE 2 — PET SELECTION GRID
────────────────────────────────────────────────────────────────────────────────
  A scrolling grid showing all owned pets of the selected rarity. Each card
  is tappable to add/remove it from the fusion selection.

  Grid container:
    Position     : UDim2.new(0, 0, 0, 42)
    Size         : UDim2.new(1, 0, 0.55, -42)   (fills ~55% of content height)
    ScrollingFrame with UIGridLayout:
      CellSize   : UDim2.fromOffset(110, 100)
      CellPadding: UDim2.fromOffset(8, 8)

  Each pet card:
    Size         : 110×100
    BackgroundColor3 : Color3.fromRGB(230, 230, 250)  (same as InventoryPanel)
    UICorner     : 8px
    UIStroke     : 2px, RARITY_UI_GLOW[rarity], transparency 0.35

    Content:
      Pet name   : TextLabel, GothamBold 11px, top 4px
      Power      : TextLabel, Gotham 10px, "Pow {power}"
      Species    : TextLabel, Gotham 10px, pet.id

    States:
      UNSELECTED : default background, no overlay
      SELECTED   : green check overlay (top-right), green UIStroke (thickness 3),
                   subtle green tint overlay (transparency 0.8)
      EQUIPPED   : orange "EQUIPPED" badge (same as InventoryPanel). Tapping
                   shows error toast: "Unequip this pet first!"
                   Card is NOT selectable while equipped.

  Selection logic:
    - Tap to toggle select/deselect.
    - Max selection = PetConfig.FuseCost.petsRequired (3).
    - Once 3 are selected, additional taps on unselected cards do nothing
      (or flash a "3 max" micro-toast on the card).
    - Selected pets must all be the same rarity (enforced by the filter —
      grid only shows one rarity at a time).
    - Sound: "click" on select, "click" on deselect.

  Selected card animation:
    On select: scalePunch (same as InventoryPanel equip — 1→1.1→1 elastic).
    Green check mark: scale from 0→1, Back Out, 0.2s.
    On deselect: quick scale to 0.95→1 over 0.12s.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ZONE 3 — FUSION PREVIEW & CONFIRM
────────────────────────────────────────────────────────────────────────────────
  The bottom ~45% of the content area shows the fusion equation and
  confirm button.

    ┌─────────────────────────────────────────────┐
    │  [Pet A]  +  [Pet B]  +  [Pet C]  →  [???] │
    │                                             │
    │     Cost: 10,000 coins                      │
    │     Result: ??? (next rarity)                │
    │                                             │
    │         [ FUSE! ]                            │
    └─────────────────────────────────────────────┘

  Layout — equation row:
    Position     : top of Zone 3
    Size         : UDim2.new(1, 0, 0, 80)
    Horizontal layout: 3 sacrifice slots, plus sign separators, arrow, result slot

  Sacrifice slot (×3):
    Size         : UDim2.fromOffset(60, 70)
    BackgroundColor3 : Color3.fromRGB(60, 60, 75) when empty
    UICorner     : 8px
    UIStroke     : 2px, rarity color (when filled)
    Content when filled:
      Pet name   : GothamBold 10px, centered
      "Pow {n}"  : Gotham 9px
    Content when empty:
      "?" text   : GothamBold 24px, Color3.fromRGB(120, 120, 140)
      Dashed border effect: UIStroke with dashed-style (if available) or
      alternating transparency segments

  Plus signs between slots:
    TextLabel "+"
    GothamBold 20px, Color3.fromRGB(180, 180, 200)
    Size: 20×70, centered vertically

  Arrow separator:
    TextLabel "→"
    GothamBold 24px, Color3.fromRGB(200, 200, 220)
    Size: 24×70

  Result preview slot:
    Size         : UDim2.fromOffset(70, 80)
    BackgroundColor3 : Color3.fromRGB(40, 40, 55) when no selection
    UICorner     : 8px
    UIStroke     : 3px, RARITY_UI_GLOW[nextRarity], transparency 0.2
    Content when 3 pets selected:
      "???" text : GothamBold 18px, RARITY_UI_GLOW[nextRarity]
      Rarity label: Gotham 11px, e.g. "RARE" (the next rarity tier)
      Pulsing glow: UIStroke thickness oscillates 3→5→3 at 1Hz
    Content when < 3 selected:
      "?" text   : GothamBold 22px, dim gray
      "Select 3" : Gotham 10px, dim gray

  Cost display:
    Position     : below equation row, 8px gap
    TextLabel    : Gotham 14px
    Text         : "Cost: {formattedCost} coins"
    Color        : Color3.fromRGB(255, 213, 79) (gold, same as store prices)
    Visible only when 3 pets are selected.
    If player can't afford: TextColor3 = Color3.fromRGB(255, 100, 100),
    text appends " (not enough!)"

  Fuse button:
    Size         : UDim2.new(0.6, 0, 0, 44)
    Position     : centered, below cost
    AnchorPoint  : Vector2.new(0.5, 0)
    BackgroundColor3 :
      Enabled    : Color3.fromRGB(255, 120, 50) (vivid orange — distinct from
                   green equip buttons)
      Disabled   : Color3.fromRGB(80, 80, 90)
    Text         : "★ FUSE!" when enabled, "Select 3 Pets" when < 3 selected
    Font         : GothamBold 18px
    TextColor3   : white
    UICorner     : 10px
    UIStroke     : 2px, Color3.fromRGB(255, 180, 100) when enabled
    AutoButtonColor : true when enabled, false when disabled

  Enabled conditions (ALL must be true):
    1. Exactly 3 pets selected
    2. Player has enough coins for the cost
    3. No fusion currently in progress (debounce)
    4. None of the selected pets are equipped
]]


--[[
================================================================================
  SECTION C — CONFIRMATION DIALOG
================================================================================
  Before sending the FusePets remote, show a modal confirmation overlay.
  Fusion is DESTRUCTIVE (3 pets are permanently consumed). Players must
  clearly understand what they're sacrificing and what they might get.
================================================================================
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  CONFIRMATION MODAL
────────────────────────────────────────────────────────────────────────────────
  Full-screen semi-transparent overlay (BackgroundTransparency 0.4, black)
  with a centered dialog card.

  Dialog card:
    Size         : UDim2.fromOffset(340, 280)
    AnchorPoint  : Vector2.new(0.5, 0.5)
    Position     : UDim2.fromScale(0.5, 0.5)
    BackgroundColor3 : Color3.fromRGB(30, 32, 45)
    UICorner     : 12px
    UIStroke     : 2px, RARITY_UI_GLOW[nextRarity]

  Content layout (top to bottom):
    Title        : "Confirm Fusion" — GothamBold 20px, white
    Divider      : 1px Frame, Color3.fromRGB(60, 60, 80), 90% width

    Sacrifice summary:
      "You will LOSE these 3 pets:"
      3 pet name labels in a row: GothamBold 12px, rarity color
      Each shows: "{petName} (Pow {power})"

    Arrow + result:
      "↓"
      "You will receive a random {NEXT_RARITY} pet"
      Rarity label in RARITY_UI_GLOW color, bold

    Cost line:
      "Cost: {formattedCost} coins" — gold color

    Warning:
      "This cannot be undone!" — Color3.fromRGB(255, 100, 100), Gotham 11px

    Button row (horizontal, centered):
      [Cancel] : 120×36, Color3.fromRGB(80, 80, 95), "Cancel", white text
      [FUSE!]  : 120×36, Color3.fromRGB(255, 120, 50), "★ FUSE!", white text
      Gap      : 16px between buttons

  Animations:
    Enter: card scales from 0.85→1 (Back Out, 0.25s), overlay fades from
           transparent to 0.4 over 0.15s.
    Cancel: card scales 1→0.9 + fades out over 0.15s, overlay fades out.

  Sound: "click" on open, "click" on cancel.
  On confirm: play "purchase" sound, disable both buttons (debounce), fire
  FusePets remote with the 3 pet UIDs.
]]


--[[
================================================================================
  SECTION D — FUSION ANIMATION SEQUENCE
================================================================================
  After confirming fusion, the UI transitions into a dramatic reveal
  sequence. This is the "moment of truth" — it must feel exciting and
  rewarding regardless of which specific pet the player gets, because
  they're always getting a RARITY UPGRADE.

  The animation plays in the same ScreenGui space, overlaying everything.
  Duration scales with output rarity (higher = more dramatic).

  General flow:
    Phase 1 — Sacrifice Departure (0.5s)
    Phase 2 — Energy Convergence (0.6–1.2s, rarity-scaled)
    Phase 3 — Reveal Flash + Result (0.3–0.8s, rarity-scaled)
    Phase 4 — Result Showcase (held until dismiss)
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PHASE 1 — SACRIFICE DEPARTURE (0–0.5s)
────────────────────────────────────────────────────────────────────────────────
  The 3 selected pet cards in the equation row animate away.

  Full-screen overlay appears:
    BackgroundColor3 : Color3.new(0, 0, 0)
    BackgroundTransparency : 1 → 0.55 over 0.3s

  Each sacrifice card (3 in parallel, staggered by 0.05s):
    1. Scale punch to 1.15 (0.08s, Quad Out)
    2. Shrink to 0 while moving toward screen center (0.35s, Quad In)
    3. At the end, emit a small burst of rarity-colored sparkles (6 each)

  The result preview slot pulses its UIStroke thickness 3→6→3 once.

  Sound: "equip_item" at t=0, one per card staggered.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PHASE 2 — ENERGY CONVERGENCE (0.5s → variable end)
────────────────────────────────────────────────────────────────────────────────
  A central "fusion orb" appears at screen center. Energy particles from the
  sacrifice positions spiral into it. Duration and intensity scale by the
  OUTPUT rarity:

    | Output Rarity | Convergence Duration | Particle Count |
    |---------------|----------------------|----------------|
    | uncommon      | 0.6s                 | 18             |
    | rare          | 0.8s                 | 28             |
    | epic          | 1.0s                 | 40             |
    | legendary     | 1.2s                 | 55             |
    | mythic        | N/A (mythic can't be fused TO) |      |

  Fusion orb (centered Frame):
    Size         : starts 0px, grows to 80×80 over convergence duration
    Shape        : circular (UICorner = UDim.new(0.5, 0))
    BackgroundColor3 : RARITY_UI_GLOW[outputRarity]
    UIStroke     : 3px, white, transparency 0.3
    Glow         : outer UIGradient (radial) with transparency fade

  Orb pulse: size oscillates ±5px at 3Hz during convergence.
  Orb color: for epic+, the BackgroundColor3 subtly shifts between two
  tones of the rarity color (e.g. deep purple → light purple for epic).

  Spiral particles (screen-space TextLabel sparkles):
    Start positions: the 3 sacrifice slot positions on screen
    End position: screen center (the orb)
    Path: bezier curve with randomized control point for spiral feel
    Color: source rarity color → output rarity color gradient
    Size: 6–12px, shrinking to 4px as they reach the orb
    Staggered emission: particles spawn every (duration / count) seconds

  Orb wobble at end: orb shakes ±3px randomly for the final 0.15s,
  signaling the imminent "break".

  Sound: "rebirth_riser" for epic+ output rarity (building tension).
         For uncommon/rare output: a shorter ascending chime.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PHASE 3 — REVEAL FLASH (end of Phase 2 → +0.3–0.8s)
────────────────────────────────────────────────────────────────────────────────
  The fusion orb "explodes" and reveals the result. Intensity scales by
  output rarity.

  UNCOMMON result:
    Orb scales 80→200px in 0.08s, then fades out over 0.2s.
    Screen flash: uncommon green, 0.2s, peak transparency 0.6.
    Sparkle burst: 12 particles from center, uncommon color.
    Sound: "pet_equip_uncommon"

  RARE result:
    Orb scales 80→250px in 0.06s, then fades.
    Screen flash: rare blue, 0.25s, peak transparency 0.5.
    Sparkle burst: 20 particles + 4 beam lines from center (0.4s).
    Mild camera shake: intensity 0.1, 0.1s.
    Sound: "pet_equip_rare"

  EPIC result:
    Orb scales 80→300px in 0.05s.
    Screen flash: epic purple, 0.3s, peak transparency 0.4.
    Sparkle burst: 35 particles + 6 beam lines (0.5s).
    Wisp smoke emitters: 8 smoke puffs drifting outward.
    Camera shake: intensity 0.2, 0.15s.
    Sound: "pet_equip_epic"

  LEGENDARY result:
    Orb scales 80→400px in 0.04s.
    Double screen flash: white (0.15s, peak 0.35) then golden (0.3s, peak 0.4).
    Sparkle burst: 50 particles + 8 golden beam lines (0.6s).
    Confetti shower: 20 golden confetti pieces from top of screen.
    Camera shake: intensity 0.35, 0.2s.
    FOV punch: +4, tween back 0.25s.
    Sound: "pet_equip_legendary_impact"

  After the flash settles, the result card appears at center (Phase 4).
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PHASE 4 — RESULT SHOWCASE (held until player dismisses)
────────────────────────────────────────────────────────────────────────────────
  A large showcase card displays the fused pet's details. This is the
  "victory screen" — it must feel rewarding.

  Showcase card:
    Size         : UDim2.fromOffset(260, 320)
    AnchorPoint  : Vector2.new(0.5, 0.5)
    Position     : UDim2.fromScale(0.5, 0.45)
    BackgroundColor3 : Color3.fromRGB(25, 28, 40)
    UICorner     : 14px
    UIStroke     : 3px, RARITY_UI_GLOW[outputRarity]

  Entrance animation:
    Scale from 0.5→1.05 (Back Out, 0.3s), then 1.05→1 (Quad Out, 0.12s).

  Card content (top to bottom):
    Rarity banner:
      Full-width strip, 28px tall, RARITY_UI_GLOW[outputRarity] background
      Text: "{RARITY}" (e.g. "RARE"), GothamBold 14px, white
      UICorner: top corners only (14px top, 0 bottom)

    Pet viewport / placeholder:
      Size: 160×120, centered
      ViewportFrame showing the pet 3D model (if available), or a large
      emoji/icon placeholder
      Background: radial gradient, dark center → rarity-tinted edge

    Pet name:
      GothamBold 22px, white
      Text: result petName from FusionResult payload

    Power display:
      Gotham 16px, Color3.fromRGB(255, 220, 100)
      Text: "Power: {fusedPower}"
      Below it: "({previousPowerTotal} → {fusedPower})" in Gotham 12px,
      Color3.fromRGB(140, 255, 140) — showing the power upgrade

    Bonus tag (if fusedPower > basePower):
      Small badge: "+{bonus} FUSION BONUS" in GothamBold 11px, orange

    Source line:
      Gotham 11px, Color3.fromRGB(160, 165, 180)
      Text: "Fused from: {sacrificedName1}, {sacrificedName2}, {sacrificedName3}"

  Action buttons (below card, horizontal):
    [Equip Now]  : 130×38, Color3.fromRGB(63, 81, 181), "Equip Now"
                   Fires EquipPet with the new pet UID
    [Close]      : 100×38, Color3.fromRGB(60, 60, 75), "Close"
                   Returns to fusion UI

  Persistent VFX during showcase:
    Rarity-colored sparkle motes drift slowly around the card (4/s rate).
    UIStroke on the card subtly pulses thickness 3→4→3 at 0.5Hz.
    For legendary output: golden particle rain from top of card.
]]


--[[
================================================================================
  SECTION E — ERROR STATES & EDGE CASES
================================================================================
]]

--[[
────────────────────────────────────────────────────────────────────────────────
  ERROR TOASTS
────────────────────────────────────────────────────────────────────────────────
  All errors display as small toast labels near the fusion area. Use the
  existing UIHelpers toast pattern (or similar to InventoryPanel farewell
  text animation — fade in from bottom, hold 1.2s, fade out).

  | Condition                         | Toast Text                              | Color          |
  |-----------------------------------|-----------------------------------------|----------------|
  | Tap equipped pet in grid          | "Unequip this pet first!"               | orange warning |
  | Tap 4th pet (3 already selected)  | "Max 3 — deselect one first"            | gray info      |
  | Fuse button tapped, can't afford  | "Not enough coins! Need {cost}"         | red error      |
  | Server returns error              | "{error message from Notification}"     | red error      |
  | Try to fuse mythic pets           | "Mythic pets are the peak — can't fuse!"| purple info    |
  | No pets of selected rarity        | "No {rarity} pets to fuse"              | gray info      |

  Toast animation:
    Appear : Position.Y offset -20→0, TextTransparency 1→0, 0.15s (Quad Out)
    Hold   : 1.2s
    Vanish : TextTransparency 0→1, 0.2s (Quad In)
    Sound  : none (avoids spam since tapping equipped pets is common)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  EDGE CASES
────────────────────────────────────────────────────────────────────────────────
  1. Player opens fusion, selects 3 pets, then one is auto-unequipped by
     another system (e.g. equip-best): Re-validate selection on DataUpdate.
     If any selected UID is missing from data.pets, remove it from selection
     and flash the empty slot.

  2. Player has exactly 3 pets of a rarity and fuses them: After fusion
     completes, the rarity filter for that tier dims (count drops to 0).
     Auto-switch to the next available rarity filter, or show "No pets
     available — hatch more eggs!" centered in the grid.

  3. Rapid double-tap on Fuse button: The confirmation modal's Fuse button
     disables itself immediately on click (set Active = false, dim color).
     Re-enable only after FusionResult or a 10s timeout.

  4. Player closes the inventory during fusion animation: The reveal
     animation should be parented to a top-level ScreenGui (above MenuHub)
     so closing the panel doesn't interrupt it. The animation completes
     independently.

  5. Mobile layout: All elements use scale-based sizing where possible.
     The equation row stacks vertically on very narrow screens
     (ViewportSize.X < 400):
       [Pet A]
         +
       [Pet B]
         +
       [Pet C]
         ↓
       [???]
]]


--[[
================================================================================
  SECTION F — SOUND CUE REFERENCE
================================================================================
  Fusion uses existing sounds — no new sound IDs needed:

  | Moment                    | Sound Key                  | Notes                          |
  |---------------------------|----------------------------|--------------------------------|
  | Select pet in grid        | "click"                    | existing                       |
  | Deselect pet              | "click"                    | existing                       |
  | Open confirm dialog       | "click"                    | existing                       |
  | Cancel confirm            | "click"                    | existing                       |
  | Confirm fusion            | "purchase"                 | existing                       |
  | Sacrifice departure       | "equip_item" (×3 stagger)  | existing                       |
  | Convergence (epic+)       | "rebirth_riser"            | existing, tension build        |
  | Reveal: uncommon result   | "pet_equip_uncommon"       | from PetEntranceDesignSpec     |
  | Reveal: rare result       | "pet_equip_rare"           | from PetEntranceDesignSpec     |
  | Reveal: epic result       | "pet_equip_epic"           | from PetEntranceDesignSpec     |
  | Reveal: legendary result  | "pet_equip_legendary_impact"| from PetEntranceDesignSpec    |
  | Equip from showcase       | "equip_item"               | existing                       |
]]


--[[
================================================================================
  SECTION G — MOBILE UX CONSIDERATIONS
================================================================================

  TOUCH TARGET SIZES:
    All buttons >= 44×44 touch area (even if visually smaller).
    Pet cards at 110×100 are comfortable for touch.
    Rarity filter pills at 90×28 are tight — add 8px invisible padding.

  SCROLLING:
    Pet selection grid must scroll smoothly. Disable page-level scroll
    when interacting with the grid (CanvasSize calculated from pet count).

  HAPTICS:
    On devices that support it (via HapticService):
      Select pet     : light haptic
      Confirm fusion : medium haptic
      Reveal result  : strong haptic (epic+ only)

  ORIENTATION:
    Portrait: use vertical equation layout (Section E, edge case 5).
    Landscape: use horizontal equation row (default).

  THUMB ZONE:
    The Fuse button and confirm dialog buttons are positioned in the lower
    40% of the screen — reachable by thumb in one-handed portrait mode.
]]


--[[
================================================================================
  SECTION H — IMPLEMENTATION CHECKLIST FOR ENGINEER
================================================================================

  1. Add tab bar to InventoryPanel (Cars / Pets / ★ Fuse)
  2. Create FusionSubPanel module (content for the Fuse tab)
  3. Wire rarity filter bar with pet count badges
  4. Build pet selection grid with select/deselect toggling
  5. Build equation row with sacrifice slots + result preview
  6. Build cost display + Fuse button with enable/disable logic
  7. Build confirmation modal overlay
  8. Listen for FusionResult event → play Phase 1-4 animation
  9. Build result showcase card with Equip Now / Close buttons
  10. Handle all error states from Section E
  11. Test mobile layout (vertical stacking for narrow screens)
  12. Verify DataUpdate re-validation clears stale selections
]]

return nil
