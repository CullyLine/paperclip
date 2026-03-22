--!strict
--[[
	ACHIEVEMENT TROPHY CASE MVP — VISUAL DESIGN SPEC
	==================================================
	Defines exact parameters for the Achievement / Trophy system UI:
	  A) Trophy Case Screen       (full-screen panel, grid of all achievements)
	  B) Unlock Toast             (in-game banner when achievement pops)
	  C) Starter Achievement List (10 achievements spanning game systems)

	Data source:
	  DACReplicatedStorage/Config/AchievementPopupConfig.luau
	    .Achievements           → definition table
	    .UnlockToastLines       → toast headline pool
	    .CategoryComplete       → category sweep copy
	    .TotalCompletion        → 100% copy
	    .ProgressNudge          → near-complete nudge copy
	    .getAchievementById()
	    .getAchievementsByCategory()
	    .pickVariant()

	Server integration:
	  RemoteEvent "AchievementUnlocked" → { id: string, rarity: string }
	  RemoteEvent "AchievementProgress" → { id: string, current: number, target: number }
	  RemoteFunction "GetAchievementData" → returns full player achievement state

	HUD entry point:
	  A trophy button (🏆) in the HUD action bar, beside the inventory button.
	  Badge dot with count of newly-unlocked achievements since last open.

	ZIndex layering:
	  700 = trophy case backdrop
	  710 = trophy case panel
	  715 = panel content (grid, header, filters)
	  720 = achievement detail tooltip
	  900 = unlock toast overlay
	  910 = toast content + particles

	Engineer implementation notes:
	  - State stored in DataManager: achievementsUnlocked (dict<string,bool>),
	    achievementProgress (dict<string,number>), achievementsSeen (dict<string,bool>).
	  - Unlock toast suppressed during active driving run; queue for run-end
	    (same pattern as MilestoneCeremonyDesignSpec ceremony queue).
	  - Trophy case panel managed by UIController.togglePanel("trophyCase").
	  - All tweens use TweenService; per-frame animations use RenderStepped.
	  - SoundFacade.playOneShot(name) for all sound triggers.
]]


--[[
================================================================================
  SECTION A — TROPHY CASE SCREEN
================================================================================
  The primary achievements panel. Accessed from the HUD trophy button or
  from a "View Trophies" shortcut on the unlock toast. Displays all
  achievements in a scrollable grid with filtering, progress tracking, and
  a completion header.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — HUD BUTTON
────────────────────────────────────────────────────────────────────────────────

  Button (added to HUD actionBar, after inventory button):
    Name               : "TrophyButton"
    Type               : ImageButton
    Size               : UDim2.fromOffset(48, 48)
    Image              : "rbxassetid://0"  (trophy icon — placeholder)
    BackgroundColor3   : Color3.fromRGB(30, 22, 55)
    BackgroundTransparency: 0.15
    ZIndex             : 50

    UICorner           : UDim.new(0, 10)
    UIStroke:
      Thickness        : 1.5
      Color            : Color3.fromRGB(255, 213, 79)
      Transparency     : 0.3

  Notification dot (unseen unlocks):
    Frame              : "TrophyNotifDot"
    Size               : UDim2.fromOffset(18, 18)
    Position           : UDim2.new(1, -4, 0, -4)
    AnchorPoint        : Vector2.new(1, 0)
    BackgroundColor3   : Color3.fromRGB(255, 60, 60)
    UICorner           : UDim.new(0.5, 0)
    ZIndex             : 52

    Count label inside:
      Text             : tostring(unseenCount)
      Font             : GothamBlack
      TextSize         : 10
      TextColor3       : Color3.new(1, 1, 1)

    Visible only when unseenCount > 0.
    Pulse: UIScale 1.0 ↔ 1.15, 2 Hz.

  Click: SoundFacade.playOneShot("ui_open")
         UIController.togglePanel("trophyCase")
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — PANEL FRAME
────────────────────────────────────────────────────────────────────────────────

  Backdrop (full-screen dim):
    Size               : UDim2.fromScale(1, 1)
    BackgroundColor3   : Color3.new(0, 0, 0)
    BackgroundTransparency: 0.45
    ZIndex             : 700

  Panel Frame:
    Name               : "TrophyCasePanel"
    Size               : UDim2.fromOffset(520, 480)
    Position           : UDim2.fromScale(0.5, 0.5)
    AnchorPoint        : Vector2.new(0.5, 0.5)
    BackgroundColor3   : Color3.fromRGB(16, 12, 32)
    BackgroundTransparency: 0.02
    ZIndex             : 710
    ClipsDescendants   : true

  UICorner             : UDim.new(0, 16)

  UIStroke:
    Thickness          : 2
    Color              : Color3.fromRGB(255, 213, 79)
    Transparency       : 0.15

  UIGradient (vertical, subtle dark-to-darker):
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(24, 18, 48)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 12, 32)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 15, 40)),
                         })
    Rotation           : 90

  Mobile: Size = UDim2.new(1, -24, 0.85, 0), max 520px wide.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — HEADER
────────────────────────────────────────────────────────────────────────────────

  ── Title ──
    Text               : "🏆 TROPHY CASE"
    Font               : GothamBlack
    TextSize           : 22
    TextColor3         : Color3.fromRGB(255, 213, 79)
    Position           : UDim2.new(0.5, 0, 0, 16)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -24, 0, 28)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 715

  ── Completion Counter ──
    Text               : `{unlocked}/{total} Achievements Unlocked`
    Font               : GothamBold
    TextSize           : 13
    TextColor3         : Color3.fromRGB(200, 200, 220)
    Position           : UDim2.new(0.5, 0, 0, 48)
    AnchorPoint        : Vector2.new(0.5, 0)
    ZIndex             : 715

  ── Completion Progress Bar ──
    Position           : UDim2.new(0.5, 0, 0, 68)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(0.8, 0, 0, 10)
    BackgroundColor3   : Color3.fromRGB(30, 24, 55)
    ZIndex             : 715

    UICorner           : UDim.new(0.5, 0)

    Fill Frame:
      Size             : UDim2.fromScale(unlocked / total, 1)
      BackgroundColor3 : Color3.fromRGB(255, 213, 79)
      UICorner         : UDim.new(0.5, 0)

    Fill animation on open: tween from 0 → target over 0.5s (Quad Out)

    Milestone markers (thin vertical lines at 25%, 50%, 75%, 100%):
      Size             : UDim2.fromOffset(1, 14)
      BackgroundColor3 : Color3.fromRGB(255, 255, 255)
      BackgroundTransparency: 0.5

  ── Completion Percentage Label (right of bar) ──
    Text               : `{math.floor(unlocked/total * 100)}%`
    Font               : GothamBlack
    TextSize           : 12
    TextColor3         : Color3.fromRGB(255, 213, 79)
    Position           : UDim2.new(0.92, 0, 0, 68)

  ── Close Button (top-right) ──
    Text               : "✕"
    Size               : UDim2.fromOffset(32, 32)
    Position           : UDim2.new(1, -12, 0, 12)
    AnchorPoint        : Vector2.new(1, 0)
    BackgroundColor3   : Color3.fromRGB(60, 40, 80)
    TextColor3         : Color3.fromRGB(200, 200, 220)
    Font               : GothamBold
    TextSize           : 16
    ZIndex             : 720
    UICorner           : UDim.new(0, 8)

    Click: SoundFacade.playOneShot("ui_close"), UIController.togglePanel("trophyCase")
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — FILTER TABS
────────────────────────────────────────────────────────────────────────────────

  Horizontal tab row below the progress bar:
    Position           : UDim2.new(0.5, 0, 0, 90)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -24, 0, 28)

  Tabs: "ALL" | "DRIVING" | "COLLECTION" | "ECONOMY" | "SOCIAL" | "SECRET"

  Tab Button (each):
    Size               : UDim2.fromOffset(auto, 26)
    AutomaticSize      : X
    Padding            : UDim.new(0, 10) (UIPadding left+right)
    Font               : GothamBold
    TextSize           : 11

  Active tab:
    BackgroundColor3   : Color3.fromRGB(255, 213, 79)
    TextColor3         : Color3.fromRGB(20, 15, 40)
    UICorner           : UDim.new(0, 6)

  Inactive tab:
    BackgroundTransparency: 1
    TextColor3         : Color3.fromRGB(150, 140, 170)

  Tab transition: active tab BackgroundTransparency tweens 0.5 → 0 over 0.12s.
  Sound on tab switch: SoundFacade.playOneShot("ui_tick")

  UIListLayout: Horizontal, Center, Padding = UDim.new(0, 6)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — ACHIEVEMENT GRID
────────────────────────────────────────────────────────────────────────────────

  ScrollingFrame below filter tabs:
    Position           : UDim2.new(0, 12, 0, 126)
    Size               : UDim2.new(1, -24, 1, -170)
    BackgroundTransparency: 1
    ScrollBarThickness : 4
    ScrollBarImageColor3: Color3.fromRGB(100, 80, 140)
    CanvasSize         : auto (UIGridLayout.AbsoluteContentSize)
    ZIndex             : 715

  UIGridLayout:
    CellSize           : UDim2.fromOffset(110, 130)
    CellPadding        : UDim2.fromOffset(8, 8)
    SortOrder          : LayoutOrder
    FillDirection      : Horizontal
    FillDirectionMaxCells: 4

  Mobile (< 420px viewport): CellSize = UDim2.fromOffset(90, 110), 3 columns.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — ACHIEVEMENT CELL (unlocked)
────────────────────────────────────────────────────────────────────────────────

  Cell Frame:
    BackgroundColor3   : Color3.fromRGB(28, 22, 52)
    BackgroundTransparency: 0.05
    UICorner           : UDim.new(0, 10)
    ZIndex             : 715

    UIStroke:
      Thickness        : 1.5
      Color            : rarity accent color (see RARITY TIERS below)
      Transparency     : 0.2

  ── Icon (top center) ──
    Type               : ImageLabel (or TextLabel for emoji fallback)
    Size               : UDim2.fromOffset(48, 48)
    Position           : UDim2.new(0.5, 0, 0, 10)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundTransparency: 1
    ZIndex             : 716

  ── Rarity Frame (behind icon, subtle glow) ──
    Size               : UDim2.fromOffset(56, 56)
    Position           : same as icon, offset -4
    BackgroundColor3   : rarity accent, transparency 0.85
    UICorner           : UDim.new(0.5, 0)
    ZIndex             : 714

  ── Title ──
    Text               : achievement.title
    Font               : GothamBold
    TextSize           : 10
    TextColor3         : Color3.new(1, 1, 1)
    TextWrapped        : true
    Position           : UDim2.new(0.5, 0, 0, 66)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -8, 0, 26)
    TextXAlignment     : Center
    ZIndex             : 716

  ── Rarity Label ──
    Text               : rarity name (e.g. "GOLD")
    Font               : GothamBlack
    TextSize           : 8
    TextColor3         : rarity accent color
    Position           : UDim2.new(0.5, 0, 1, -20)
    AnchorPoint        : Vector2.new(0.5, 0)
    ZIndex             : 716

  ── "NEW!" Badge (if freshly unlocked and not yet seen) ──
    Frame:
      Size             : UDim2.fromOffset(36, 14)
      Position         : UDim2.new(1, -2, 0, -2)
      AnchorPoint      : Vector2.new(1, 0)
      BackgroundColor3 : Color3.fromRGB(255, 60, 60)
      UICorner         : UDim.new(0, 4)
      ZIndex           : 718

    Label:
      Text             : "NEW!"
      Font             : GothamBlack
      TextSize         : 8
      TextColor3       : Color3.new(1, 1, 1)

    Pulse: UIScale 1.0 ↔ 1.12, 2.5 Hz.
    Cleared on cell first-view (mark achievementsSeen[id] = true).
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — ACHIEVEMENT CELL (locked)
────────────────────────────────────────────────────────────────────────────────

  Cell Frame:
    BackgroundColor3   : Color3.fromRGB(18, 14, 30)
    BackgroundTransparency: 0.08
    UIStroke:
      Color            : Color3.fromRGB(50, 40, 70)
      Transparency     : 0.4

  ── Icon (greyed silhouette) ──
    Same position/size as unlocked icon.
    ImageColor3        : Color3.fromRGB(40, 30, 60) (dark desaturated)
    ImageTransparency  : 0.5
    Or for text emoji: TextColor3 = Color3.fromRGB(40, 30, 60), TextTransparency = 0.5

  ── Title ──
    Text               : "???"
    TextColor3         : Color3.fromRGB(80, 70, 100)

  ── Description Hint ──
    Text               : "???"  (mystery drives curiosity)
    Font               : Gotham
    TextSize           : 9
    TextColor3         : Color3.fromRGB(60, 50, 80)
    Position           : UDim2.new(0.5, 0, 0, 66)

  ── Progress Bar (for multi-step achievements with known progress) ──
    Visible            : true only if progress > 0
    Position           : UDim2.new(0.5, 0, 1, -18)
    AnchorPoint        : Vector2.new(0.5, 0.5)
    Size               : UDim2.new(0.8, 0, 0, 6)
    BackgroundColor3   : Color3.fromRGB(30, 24, 50)
    UICorner           : UDim.new(0.5, 0)

    Fill:
      Size             : UDim2.fromScale(current / target, 1)
      BackgroundColor3 : Color3.fromRGB(100, 90, 140)
      UICorner         : UDim.new(0.5, 0)

    Counter label:
      Text             : `{current}/{target}`
      Font             : Gotham
      TextSize         : 8
      TextColor3       : Color3.fromRGB(120, 110, 150)
      Position         : below bar

  Secret achievements (category == "secret") with no progress:
    Title displays "???", description displays "Find the secret..."
    No progress bar shown until first progress event.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — ACHIEVEMENT DETAIL TOOLTIP
────────────────────────────────────────────────────────────────────────────────
  On click/tap of any cell (locked or unlocked), a tooltip overlay shows
  full details. This avoids cramming info into small cells.

  Tooltip Frame:
    Size               : UDim2.fromOffset(280, 160)
    Position           : centered on screen
    BackgroundColor3   : Color3.fromRGB(20, 16, 38)
    UICorner           : UDim.new(0, 14)
    ZIndex             : 720

    UIStroke:
      Color            : rarity accent (unlocked) or Color3.fromRGB(60, 50, 80) (locked)
      Thickness        : 2

  Content (unlocked):
    ── Icon (left) ──
      Size             : 52×52
      Position         : UDim2.new(0, 16, 0, 16)

    ── Title (right of icon) ──
      Text             : achievement.title
      Font             : GothamBlack
      TextSize         : 16
      TextColor3       : rarity accent

    ── Description ──
      Text             : achievement.description
      Font             : Gotham
      TextSize         : 12
      TextColor3       : Color3.new(1, 1, 1)

    ── Rarity Badge ──
      Inline badge: "[GOLD]" with rarity accent background
      Font             : GothamBlack
      TextSize         : 10

    ── Unlock Date (if tracked) ──
      Text             : "Unlocked: Mar 21, 2026"
      Font             : Gotham
      TextSize         : 10
      TextColor3       : Color3.fromRGB(140, 130, 160)

  Content (locked):
    ── Title ──  "???"
    ── Hint ──   "Keep playing to discover this achievement!"
    ── Progress bar (if applicable, full width) ──

  Dismiss: tap outside tooltip or tap close button.
  Entrance: UIScale 0.85 → 1.0 over 0.15s (Back Out).
  Sound: SoundFacade.playOneShot("ui_tick")
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — RARITY TIERS
────────────────────────────────────────────────────────────────────────────────
  Achievement rarity determines border color, unlock toast intensity, and
  SFX escalation. Separate from pet rarity; uses a 4-tier metallic scheme.

  | Tier     | Accent Color                          | Cell Border | Toast Intensity |
  |----------|---------------------------------------|-------------|-----------------|
  | Bronze   | Color3.fromRGB(180, 120, 60)          | subtle      | minimal         |
  | Silver   | Color3.fromRGB(180, 190, 210)         | mild glow   | moderate        |
  | Gold     | Color3.fromRGB(255, 213, 79)          | warm glow   | dramatic        |
  | Diamond  | Color3.fromRGB(160, 220, 255)         | bright glow | spectacular     |

  Border glow effect (unlocked cells only):
    Bronze  : static UIStroke, no animation
    Silver  : UIStroke.Transparency oscillates 0.2 ↔ 0.35, 1 Hz
    Gold    : UIStroke.Transparency oscillates 0.1 ↔ 0.25, 1.5 Hz
              + UIGradient shimmer sweep on cell (offset -1→1, 5s loop)
    Diamond : UIStroke.Color cycles through ice-blue ↔ white, 1 Hz
              + UIGradient shimmer sweep (offset -1→1, 3s loop)
              + subtle sparkle particles (2 dot Frames orbit cell corners)

  Achievement-to-rarity mapping guidelines:
    Bronze  : easy/introductory (first drive, first hatch, etc.)
    Silver  : moderate effort (100 runs, rare find, 7-day streak)
    Gold    : significant grind (1000 runs, mythic pull, 10 rebirths, #1 leaderboard)
    Diamond : extreme/completionist (full index, 100 rebirths, world master, all secrets)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  TROPHY CASE — PANEL ENTRANCE ANIMATION
────────────────────────────────────────────────────────────────────────────────

  t=0.00s  Backdrop fades in: transparency 1 → 0.45 over 0.2s (Quad Out)
  t=0.05s  Panel UIScale: 0.8 → 1.03 over 0.25s (Back Out)
  t=0.30s  Panel UIScale: 1.03 → 1.0 over 0.1s (Quad Out)
  t=0.15s  Header title fades in: TextTransparency 1 → 0 over 0.2s
  t=0.25s  Progress bar fill tweens from 0 → target over 0.5s (Quad Out)
  t=0.30s  Filter tabs cascade: each tab fades in with 0.04s stagger
  t=0.35s  Grid cells cascade entrance:
             Stagger: 0.03s × cell index (row-major order)
             Per cell: UIScale 0 → 1.08 over 0.15s (Back Out),
                       then 1.08 → 1.0 over 0.08s (Quad Out)
             Max stagger: cap at 30 cells (0.9s max cascade)

  Sound at t=0.05s: SoundFacade.playOneShot("ui_open")

  Exit:
    Panel UIScale: 1.0 → 0.9 over 0.15s (Quad In)
    Panel BackgroundTransparency: 0.02 → 0.6 over 0.15s
    Backdrop: 0.45 → 1 over 0.2s
    Destroy after 0.25s.
    Sound: SoundFacade.playOneShot("ui_close")
]]


--[[
================================================================================
  SECTION B — UNLOCK TOAST
================================================================================
  Full-width banner that slides down from the top when an achievement unlocks
  during gameplay. Non-blocking for toasts (slides over HUD), but queued if
  another toast is showing. Maximum 1 toast visible at a time.

  Suppressed during active driving runs — queued for run-end (same as
  MilestoneCeremonyDesignSpec ceremony suppression).
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNLOCK TOAST — LAYOUT
────────────────────────────────────────────────────────────────────────────────

  Root Frame:
    Name               : "AchievementToast"
    Size               : UDim2.new(0, 380, 0, 72)
    Position           : UDim2.new(0.5, 0, 0, -80)  (offscreen above)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundColor3   : Color3.fromRGB(16, 12, 32)
    BackgroundTransparency: 0.04
    ZIndex             : 900
    ClipsDescendants   : false

  UICorner             : UDim.new(0, 12)

  UIStroke:
    Thickness          : 2
    Color              : rarity accent color
    Transparency       : 0.05

  UIGradient:
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   rarityAccent:Lerp(Color3.new(0,0,0), 0.75)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 12, 32)),
                           ColorSequenceKeypoint.new(1,   rarityAccent:Lerp(Color3.new(0,0,0), 0.75)),
                         })
    Rotation           : 0

  ── Achievement Icon (left) ──
    Type               : ImageLabel / TextLabel
    Size               : UDim2.fromOffset(44, 44)
    Position           : UDim2.new(0, 14, 0.5, 0)
    AnchorPoint        : Vector2.new(0, 0.5)
    BackgroundTransparency: 1
    ZIndex             : 910

  ── Rarity Glow (behind icon) ──
    Size               : UDim2.fromOffset(52, 52)
    BackgroundColor3   : rarity accent, transparency 0.75
    UICorner           : UDim.new(0.5, 0)
    ZIndex             : 908

  ── Headline (right of icon) ──
    Text               : AchievementPopupConfig.pickVariant(UnlockToastLines)
                          with {TITLE} replaced by achievement.title
    Font               : GothamBlack
    TextSize           : 16
    TextColor3         : rarity accent color
    Position           : UDim2.new(0, 70, 0, 10)
    Size               : UDim2.new(1, -80, 0, 22)
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 910

  ── Description ──
    Text               : achievement.description
    Font               : Gotham
    TextSize           : 11
    TextColor3         : Color3.fromRGB(200, 200, 220)
    Position           : UDim2.new(0, 70, 0, 34)
    Size               : UDim2.new(1, -80, 0, 28)
    TextWrapped        : true
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 910

  ── Rarity Tag (right side, vertical) ──
    Frame:
      Size             : UDim2.fromOffset(4, 40)
      Position         : UDim2.new(1, -10, 0.5, 0)
      AnchorPoint      : Vector2.new(1, 0.5)
      BackgroundColor3 : rarity accent
      UICorner         : UDim.new(0, 2)
      ZIndex           : 910

  Mobile: Size = UDim2.new(1, -24, 0, 72), capped at 380px.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNLOCK TOAST — TIERED VISUAL INTENSITY
────────────────────────────────────────────────────────────────────────────────

  | Rarity   | Card Size | Confetti | Screen Flash | Shake | Hold    | Sound             |
  |----------|-----------|----------|--------------|-------|---------|-------------------|
  | Bronze   | 340×66    | 6 dots   | none         | none  | 2.5s    | trophy_bronze     |
  | Silver   | 360×70    | 10 dots  | subtle grey  | 0.03  | 3.0s    | trophy_silver     |
  | Gold     | 380×74    | 16 dots  | warm gold    | 0.06  | 3.5s    | trophy_gold       |
  | Diamond  | 400×80    | 24 dots  | bright ice   | 0.10  | 4.0s    | trophy_diamond    |

  Confetti particles (emitted at entrance):
    Spawn at card edges (top and sides).
    Color              : rarity accent with ±20 per-channel variance
    Size               : 3×3 to 6×6 px (random)
    Direction          : radially outward and slightly downward
    Speed              : 40–120 px/s
    Lifetime           : 0.3–0.6s
    Transparency       : 0.1 → 1 over lifetime
    Stagger            : 0–0.1s random delay

    Rarity-specific confetti color:
      Bronze  : browns, warm oranges
      Silver  : whites, light greys, pale blue
      Gold    : yellows, warm golds, white sparkles
      Diamond : ice blues, whites, rainbow shimmer (3 of 24 use
                mythicRainbowSequence-style cycling)

  Screen flash (Silver+):
    Full-screen Frame, ZIndex 998:
      BackgroundColor3 : rarity accent (silver = white, gold = gold, diamond = ice-blue)
      BackgroundTransparency: peak → 1 over 0.25s
      Peak               : 0.88 (silver) / 0.78 (gold) / 0.65 (diamond)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNLOCK TOAST — ENTRANCE ANIMATION
────────────────────────────────────────────────────────────────────────────────

  t=0.00s  Card drops in from above:
             Position Y: -80 → 50 over 0.3s (Back Out)
  t=0.05s  UIScale: 0.7 → 1.06 over 0.25s (Back Out)
  t=0.30s  UIScale: 1.06 → 1.0 over 0.1s (Quad Out)
  t=0.10s  Icon scale pop: 0 → 1.2 over 0.2s (Back Out),
           then 1.2 → 1.0 over 0.1s
  t=0.15s  Confetti burst (see tiered table)
  t=0.20s  Headline text fades in: TextTransparency 1 → 0 over 0.15s
  t=0.30s  Description fades in: TextTransparency 1 → 0 over 0.2s

  Accent pulse during hold:
    UIStroke.Transparency oscillates 0.05 ↔ 0.2 at 2 Hz
    Creates a breathing glow on the border.

  Gold/Diamond special:
    UIGradient shimmer sweep on card background:
      Offset X: -1 → 1 over 2s, once (not looping)

  Sound cue at t=0.05s:
    "trophy_{rarity}" (see sound reference below)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNLOCK TOAST — EXIT ANIMATION
────────────────────────────────────────────────────────────────────────────────

  After hold duration expires:
    Position Y: current → -100 over 0.3s (Quad In)
    BackgroundTransparency: 0.04 → 1 over 0.2s
    UIScale: 1.0 → 0.85 over 0.2s
    Destroy at 0.35s.

  Tap to dismiss: tapping the toast immediately begins exit.
    Sound: SoundFacade.playOneShot("ui_confirm")

  "View Trophies" button (optional, on the toast):
    Text               : "VIEW →"
    Font               : GothamBold
    TextSize           : 10
    TextColor3         : rarity accent
    Position           : UDim2.new(1, -10, 1, -4)
    AnchorPoint        : Vector2.new(1, 1)
    BackgroundTransparency: 1
    Tap: begin exit, then open trophy case panel.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  UNLOCK TOAST — CATEGORY COMPLETE MOMENT
────────────────────────────────────────────────────────────────────────────────
  When ALL achievements in a category are unlocked, a special enlarged toast
  fires using CategoryComplete copy from AchievementPopupConfig.

  Layout: same as standard toast but:
    Size               : UDim2.new(0, 420, 0, 90)
    Headline           : AchievementPopupConfig.pickVariant(CategoryComplete[category])
    Description        : `All {category} achievements COMPLETE!`
    UIStroke.Color      : animated gold ↔ white cycle, 1.5 Hz
    Confetti           : 32 dots (category accent + gold)
    Screen flash       : gold, peak 0.65
    Hold               : 5s
    Sound              : "trophy_category_complete"

  100% TOTAL COMPLETION:
    When every achievement is unlocked, fire the most dramatic toast:
    Size               : UDim2.new(0, 440, 0, 100)
    Headline           : AchievementPopupConfig.pickVariant(TotalCompletion)
    UIStroke.Color      : animated rainbow (hue cycle 0.3/s)
    Confetti           : 48 dots, rainbow colors
    Screen flash       : white, peak 0.5
    Camera shake       : 0.15, 0.3s
    Hold               : 8s
    Sound              : "trophy_total_completion"
]]


--[[
================================================================================
  SECTION C — STARTER ACHIEVEMENT LIST (10 ACHIEVEMENTS)
================================================================================
  These 10 achievements span the game's core systems. They're designed to
  guide new players through every feature while giving veterans aspirational
  long-term goals. Achievement IDs reference AchievementPopupConfig entries.

  Rarity assignment ensures a healthy distribution:
    4 Bronze (accessible early), 3 Silver (mid-game), 2 Gold (late-game),
    1 Diamond (extreme completionist).
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 1 — DRIVING: "FIRST DRIVE!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : first_drive
  Title              : FIRST DRIVE!
  Description        : Complete your very first run.
  Icon               : 🏎️
  Rarity             : Bronze
  Unlock Condition   : totalRuns >= 1
  Progress Tracking  : none (single trigger)

  Design rationale: Immediate gratification. The player's FIRST action in the
  game earns a trophy. This teaches the achievement system exists and sets
  the expectation that exploration = rewards.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 2 — PETS: "EGG CRACKER!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : first_hatch
  Title              : EGG CRACKER!
  Description        : Hatch your very first pet.
  Icon               : 🐣
  Rarity             : Bronze
  Unlock Condition   : totalPetsHatched >= 1
  Progress Tracking  : none (single trigger)

  Design rationale: Guides the player to the pet system. Most players hatch
  within the first 5 minutes. Early bronze creates a dopamine drip that
  hooks them into checking what other achievements exist.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 3 — EGGS (quantity): "HATCH MACHINE!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : hatch_100
  Title              : HATCH MACHINE!
  Description        : Hatch 100 pets. The eggs never stop!
  Icon               : 🥚
  Rarity             : Silver
  Unlock Condition   : totalPetsHatched >= 100
  Progress Tracking  : bar showing current/100

  Design rationale: Multi-step grind achievement. The progress bar in the
  trophy case creates a visible goal that pulls players back session after
  session. 100 is achievable within a few play sessions of active hatching.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 4 — REBIRTH: "REBORN!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : rebirth_one
  Title              : REBORN!
  Description        : Complete your first rebirth. Power surge!
  Icon               : ⚡
  Rarity             : Bronze
  Unlock Condition   : totalRebirths >= 1
  Progress Tracking  : none (single trigger)

  Design rationale: Teaches the rebirth loop. Many simulator players are
  hesitant to rebirth (losing progress feels scary). A bronze trophy
  validates the decision and makes rebirth feel like progression, not loss.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 5 — SPENDING: "BIG SPENDER!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : big_spender
  Title              : BIG SPENDER!
  Description        : Spend 500,000 coins in the shop. Baller!
  Icon               : 💰
  Rarity             : Silver
  Unlock Condition   : totalCoinsSpent >= 500_000
  Progress Tracking  : bar showing current/500000

  Design rationale: Encourages spending coins (currency sink). Players hoard
  currency by default — showing a progress bar toward a trophy incentivizes
  spending, which drives engagement with the shop and upgrade systems.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 6 — SOCIAL: "WEEK WARRIOR!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : daily_streak_7
  Title              : WEEK WARRIOR!
  Description        : Maintain a 7-day login streak.
  Icon               : 🔥
  Rarity             : Silver
  Unlock Condition   : currentStreak >= 7
  Progress Tracking  : bar showing currentStreak/7

  Design rationale: Retention hook. The trophy is the SECOND reward for
  streaks (after daily rewards). Double-stacking incentives on the same
  behavior maximizes day-7 retention. Progress bar creates daily anticipation.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 7 — SPEED: "SPEED DEMON!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : speed_demon
  Title              : SPEED DEMON!
  Description        : Reach 100 studs/s in a single run.
  Icon               : 💨
  Rarity             : Bronze
  Unlock Condition   : maxSpeedReached >= 100
  Progress Tracking  : none (threshold trigger)

  Design rationale: Celebrates a natural milestone that most players hit
  within their first few runs. Validates the core driving loop and primes
  players to chase higher speed milestones (which have their own ceremonies
  via SpeedMilestoneConfig).
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 8 — COLLECTION: "COMPLETIONIST!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : full_index
  Title              : COMPLETIONIST!
  Description        : Collect 100% of all pets. Every. Single. One!
  Icon               : 📖
  Rarity             : Diamond
  Unlock Condition   : uniquePetsOwned >= totalPetsInGame
  Progress Tracking  : bar showing uniquePetsOwned/totalPetsInGame

  Design rationale: THE aspirational endgame goal. Diamond rarity makes this
  the crown jewel of the trophy case. The progress bar updates with every
  new unique pet, creating a constant pull toward "just one more." Visible
  in the trophy case as a locked Diamond cell, which itself drives curiosity.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 9 — WORLD EXPLORATION: "WORLD TOURER!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : world_tourer
  Title              : WORLD TOURER!
  Description        : Complete a run in every unlocked world.
  Icon               : 🌍
  Rarity             : Gold
  Unlock Condition   : worldsRunCompleted >= totalWorldsUnlocked
  Progress Tracking  : bar showing worldsRunCompleted/totalWorldsUnlocked

  Design rationale: Drives world exploration and world-unlock purchases.
  Players tend to find a favorite world and stay there — this trophy pushes
  them to try every world at least once, increasing engagement breadth and
  creating demand for world unlocks.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  ACHIEVEMENT 10 — LEADERBOARD: "#1 DRIVER!"
────────────────────────────────────────────────────────────────────────────────
  ID                 : number_one
  Title              : #1 DRIVER!
  Description        : Claim the #1 spot on a leaderboard. KING!
  Icon               : 👑
  Rarity             : Gold
  Unlock Condition   : leaderboardRank == 1 (any board)
  Progress Tracking  : none (threshold trigger)

  Design rationale: Social status flex. This is visible in the trophy case,
  meaning other players (if they inspect profiles in the future) will see
  this Gold trophy. The competitive drive for #1 is one of the strongest
  motivators in simulator games. Gold (not Diamond) because leaderboards
  reset, so a dedicated player can achieve this within a season.
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  STARTER ACHIEVEMENTS — SUMMARY TABLE
────────────────────────────────────────────────────────────────────────────────

  | #  | ID              | System       | Rarity  | Condition              |
  |----|-----------------|--------------|---------|------------------------|
  | 1  | first_drive     | Driving      | Bronze  | 1 run completed        |
  | 2  | first_hatch     | Pets         | Bronze  | 1 pet hatched          |
  | 3  | hatch_100       | Eggs         | Silver  | 100 pets hatched       |
  | 4  | rebirth_one     | Rebirth      | Bronze  | 1 rebirth              |
  | 5  | big_spender     | Spending     | Silver  | 500K coins spent       |
  | 6  | daily_streak_7  | Social       | Silver  | 7-day streak           |
  | 7  | speed_demon     | Speed        | Bronze  | 100 studs/s reached    |
  | 8  | full_index      | Collection   | Diamond | 100% pet index         |
  | 9  | world_tourer    | World        | Gold    | All worlds run         |
  | 10 | number_one      | Leaderboard  | Gold    | #1 on any board        |

  Distribution: 4 Bronze / 3 Silver / 2 Gold / 1 Diamond
  Expected unlock timeline:
    Session 1 (0–30 min)   : first_drive, first_hatch, speed_demon
    Week 1                 : rebirth_one, daily_streak_7
    Week 2–4               : hatch_100, big_spender
    Month 1–3              : world_tourer, number_one
    Long-term grind        : full_index
]]


--[[
================================================================================
  TOAST QUEUE SYSTEM
================================================================================
  Achievement toasts share a channel separate from MilestoneCeremony full-screen
  ceremonies. They can coexist with speed/streak toasts (different screen
  regions: achievements at top-center, speed at top-center but stacked below).

  Rules:
    1. Max 1 achievement toast visible at a time.
    2. Queue depth capped at 3; excess toasts silently dropped.
    3. Next toast fires 0.4s after previous exit completes.
    4. Suppress during active driving run. Queue for run-end.
    5. If trophy case panel is open when an unlock fires, skip the toast
       and instead animate the cell directly (glow pulse + "NEW!" badge pop).

  Implementation:
    local toastQueue: { ToastPayload } = {}
    local isShowingToast = false

    function queueAchievementToast(payload)
      if #toastQueue >= 3 then return end
      table.insert(toastQueue, payload)
      if not isShowingToast then
        processNextToast()
      end
    end
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  trophy_bronze              — warm metallic click + soft chime (0.3s)
                                Character: like placing a coin on a shelf
  trophy_silver              — bright chime + bell ring (0.4s)
                                Character: silvery wind chime in a gentle breeze
  trophy_gold                — triumphant horn stinger + sparkle tail (0.6s)
                                Character: mini fanfare — think game show prize reveal
  trophy_diamond             — crystalline cascade + bass swell + shimmer (0.8s)
                                Character: magical discovery — ice crystal forming
  trophy_category_complete   — extended fanfare + crowd cheer hit (1.0s)
                                Character: podium celebration
  trophy_total_completion    — epic orchestral swell + explosion + reverb (1.5s)
                                Character: final boss defeated / credits roll

  Existing sounds reused:
    ui_open      — trophy case panel open
    ui_close     — trophy case panel close
    ui_tick      — tab switch, cell tap
    ui_confirm   — toast tap-to-dismiss

  Pitch scaling:
    None — each rarity has its own distinct sound. No pitch-shifting tricks.
    This ensures each rarity FEELS different, not just "the same sound louder."
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Grid cells are pooled and recycled on filter change (not destroyed/recreated).
    - Max 30 cells rendered at a time in the ScrollingFrame (virtualized if
      total achievements exceed 30).
    - Cell border animations: single RenderStepped connection iterates visible
      cells. Gold/Diamond shimmer uses UIGradient.Offset tweens (GPU-friendly).
    - Toast particles: max 48 dots per toast (one-shot, not looping).
    - "NEW!" badge pulses use a shared RenderStepped connection, batched.

  Accessibility:
    - All text meets 4.5:1 contrast against cell/panel backgrounds.
    - Locked cells use "???" text instead of relying solely on color/opacity
      to distinguish from unlocked (screen-reader friendly).
    - Close button and toast dismiss are large touch targets (>32px).
    - Auto-dismiss on toasts prevents soft-lock.
    - Achievement rarities indicated by BOTH color AND text label ("BRONZE",
      "SILVER", etc.) — no color-only differentiation.

  Mobile:
    - Panel width: math.min(520, viewportWidth - 24)
    - Grid switches to 3 columns on narrow viewports (< 420px)
    - Cell tap opens detail tooltip (no hover state on mobile)
    - Toast width: math.min(380, viewportWidth - 24)
    - Filter tabs scroll horizontally if viewport too narrow

  Memory:
    - Achievement state (unlocked, progress, seen) persists in DataManager.
    - On join: server sends full achievement snapshot via GetAchievementData.
    - Incremental updates via AchievementUnlocked / AchievementProgress remotes.
    - No polling — all updates are server-pushed.
================================================================================
]]

return nil
