--!strict
--[[
	MILESTONE CEREMONY UI — VISUAL DESIGN SPEC
	============================================
	Defines exact parameters for rendering five ceremony types triggered
	by MilestoneCeremonyService (server) and speed/rebirth configs.

	Ceremony types:
	  A) First-Time Achievement Popup   (one-per-lifetime events)
	  B) Speed Milestone Toast          (50–1000 studs/s thresholds)
	  C) Rebirth Milestone Ceremony     (5/10/25/50/100 rebirths)
	  D) Spending Milestone Ceremony    (cumulative Robux tiers)
	  E) Streak Milestone Toast         (3/7/14/30/60/100 days)

	Backend references:
	  - DACServerScriptService/Services/MilestoneCeremonyService.luau
	  - DACReplicatedStorage/Config/FirstTimeConfig.luau
	  - DACReplicatedStorage/Config/SpeedMilestoneConfig.luau
	  - DACReplicatedStorage/Config/RebirthMilestoneConfig.luau

	RemoteEvents consumed:
	  "FirstTimeCeremony"  → { ceremonyKey: string, body: string }
	  "SpendMilestone"     → { threshold, tierName, title, subtitle, description }
	  "StreakMilestone"    → { streak: number, body: string }
	  "SpeedMilestone"     → fired by DrivingController locally (no remote)
	  "RebirthMilestone"   → fired by RebirthService via existing VFXFacade call

	ZIndex layering:
	  800 = dim backdrop
	  810 = ceremony card
	  815 = card content
	  820 = particle overlays
	  830 = tier/rank badge

	Engineer implementation notes:
	  - Ceremonies queue if one is already showing; max queue depth 3.
	  - Suppress during active driving run (check DrivingController.isRunning()).
	  - Speed milestone toasts bypass the queue and use a lighter HUD toast.
	  - All tweens use TweenService; per-frame animations use RenderStepped.
	  - Colors reference SpeedMilestoneConfig.MilestoneColor for speed tiers.
	  - SoundFacade.playOneShot(name) for all sound triggers.
]]


--[[
================================================================================
  SECTION A — FIRST-TIME ACHIEVEMENT POPUP
================================================================================
  Triggered by MilestoneCeremonyService.tryFirstTime() → "FirstTimeCeremony"
  remote. These are once-per-lifetime events: first car, first pet, first
  rebirth, first world, first quest, first game pass, first leaderboard.

  Design goal: Make the player feel like they just unlocked something
  IMPORTANT. The ceremony should feel personal and earned — a moment of
  pride that validates their progress.

  BACKDROP (full-screen dim):
    Size               : UDim2.fromScale(1, 1)
    BackgroundColor3   : Color3.new(0, 0, 0)
    BackgroundTransparency: 0.5
    ZIndex             : 800
    Entrance           : transparency 1 → 0.5 over 0.25s (Quad Out)

  CARD FRAME:
    Name               : "CeremonyCard"
    Size               : UDim2.fromOffset(360, 220)
    Position           : UDim2.fromScale(0.5, 0.5)
    AnchorPoint        : Vector2.new(0.5, 0.5)
    BackgroundColor3   : Color3.fromRGB(20, 15, 40)
    BackgroundTransparency: 0.03
    ZIndex             : 810

  UICorner:
    CornerRadius       : UDim.new(0, 16)

  UIStroke:
    Thickness          : 2
    Color              : Color3.fromRGB(255, 213, 79)
    Transparency       : 0.1

  UIGradient (vertical, subtle top-bright):
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(30, 22, 55)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 15, 40)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(25, 18, 48)),
                         })
    Rotation           : 90
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  FIRST-TIME — CARD CONTENT
────────────────────────────────────────────────────────────────────────────────

  ── Crown Icon (top, centered above card) ──
    Type               : TextLabel
    Text               : "👑"  (or ceremony-specific emoji, see map below)
    TextSize           : 36
    Size               : UDim2.fromOffset(48, 48)
    Position           : UDim2.new(0.5, 0, 0, -32)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundTransparency: 1
    ZIndex             : 820

    Icon map by ceremonyKey:
      FirstCarPurchased    : "🏎️"
      FirstPetHatched      : "🐣"
      FirstRebirth         : "⚡"
      FirstWorldUnlocked   : "🌍"
      FirstQuestCompleted  : "📋"
      FirstGamePassPurchase: "💎"
      FirstLeaderboardEntry: "🏆"

  ── Title Label ──
    Text               : "ACHIEVEMENT UNLOCKED!"
    Font               : GothamBlack
    TextSize           : 20
    TextColor3         : Color3.fromRGB(255, 213, 79)
    Position           : UDim2.new(0.5, 0, 0, 28)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -24, 0, 26)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 815

  ── Body Label (ceremony text from FirstTimeConfig) ──
    Text               : payload.body
    Font               : GothamBold
    TextSize           : 16
    TextColor3         : Color3.new(1, 1, 1)
    TextWrapped        : true
    Position           : UDim2.new(0.5, 0, 0, 68)
    AnchorPoint        : Vector2.new(0.5, 0)
    Size               : UDim2.new(1, -32, 0, 80)
    TextXAlignment     : Center
    TextYAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 815

  ── Dismiss Button (bottom) ──
    Type               : TextButton
    Text               : "AWESOME!"
    Font               : GothamBlack
    TextSize           : 16
    TextColor3         : Color3.fromRGB(30, 20, 50)
    Size               : UDim2.new(0.55, 0, 0, 40)
    Position           : UDim2.new(0.5, 0, 1, -20)
    AnchorPoint        : Vector2.new(0.5, 1)
    BackgroundColor3   : Color3.fromRGB(255, 213, 79)
    ZIndex             : 815

    UICorner           : UDim.new(0, 10)
    UIStroke:
      Thickness        : 1.5
      Color            : Color3.fromRGB(255, 240, 140)
      Transparency     : 0.2

    Idle pulse:
      UIScale oscillates 1.0 ↔ 1.03, frequency 1.2 Hz

    Click:
      UIScale → 0.92 instantly, then → 1.0 over 0.12s (Back Out)
      SoundFacade.playOneShot("ui_confirm")
      Begin exit animation
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  FIRST-TIME — ENTRANCE ANIMATION
────────────────────────────────────────────────────────────────────────────────

  t=0.00s  Backdrop fades in (0.25s)
  t=0.05s  Card UIScale: 0.7 → 1.05 over 0.3s (Back Out)
  t=0.35s  Card UIScale: 1.05 → 1.0 over 0.12s (Quad Out)
  t=0.10s  Crown icon drops from above:
             Position Y: -60 → -32 over 0.35s (Back Out)
             UIScale: 0 → 1.15 over 0.25s (Back Out)
             then 1.15 → 1.0 over 0.1s
  t=0.30s  Title label fades in: TextTransparency 1 → 0 over 0.2s
  t=0.45s  Body label fades in: TextTransparency 1 → 0 over 0.3s
  t=0.65s  Button fades in: BackgroundTransparency 1 → 0 over 0.15s

  Particle shower (gold sparkles around card):
    Spawn at t=0.15s, 16 dot Frames around card perimeter:
      Size             : 3×3 to 6×6 px (random)
      Color            : Color3.fromRGB(255, 215, 60) with ±20 per-channel variance
      Direction        : radially outward from card center
      Speed            : 40–100 px/s
      Lifetime         : 0.3–0.55s
      Transparency     : 0.1 → 1 over lifetime
      Stagger          : 0–0.1s random delay
      Destroy after    : 0.6s

  Sound cue at t=0.05s:
    "ceremony_achievement"
    Character: triumphant fanfare stinger — bright horn + sparkle tail, ~0.5s
    Think: chest-open sound from action RPGs
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  FIRST-TIME — EXIT ANIMATION
────────────────────────────────────────────────────────────────────────────────

  Card UIScale: 1.0 → 0.85 over 0.2s (Quad In)
  Card BackgroundTransparency: 0.03 → 0.7 over 0.2s
  Backdrop transparency: 0.5 → 1 over 0.25s
  Destroy all elements after 0.3s.

  Auto-dismiss: if player doesn't click within 8s, begin exit.
]]


--[[
================================================================================
  SECTION B — SPEED MILESTONE TOAST
================================================================================
  Triggered when the player crosses a speed threshold during a run
  (50/100/150/200/300/400/500/750/1000 studs/s). These fire DURING gameplay,
  so the UI must be non-blocking and fast.

  Design goal: Momentary celebration that doesn't interrupt flow. The toast
  appears at the top-center of the screen, celebrates for ~2s, and vanishes.
  Higher thresholds get progressively more dramatic.

  Data sources:
    SpeedMilestoneConfig.CelebrationText[threshold] → headline pool
    SpeedMilestoneConfig.FlavorText[threshold]       → subtext pool
    SpeedMilestoneConfig.FlexText[threshold]          → social proof line
    SpeedMilestoneConfig.MilestoneColor[threshold]    → accent hex
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED TOAST — LAYOUT
────────────────────────────────────────────────────────────────────────────────

  Root Frame:
    Name               : "SpeedMilestoneToast"
    Size               : UDim2.new(0, 320, 0, 80)
    Position           : UDim2.new(0.5, 0, 0, 60)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundColor3   : Color3.fromRGB(15, 12, 30)
    BackgroundTransparency: 0.06
    ZIndex             : 830
    ClipsDescendants   : false

  UICorner             : UDim.new(0, 12)

  UIStroke:
    Thickness          : 2
    Color              : milestone accent color from SpeedMilestoneConfig.MilestoneColor
    Transparency       : 0.05

  UIGradient:
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   accentColor:Lerp(Color3.new(0,0,0), 0.7)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 12, 30)),
                           ColorSequenceKeypoint.new(1,   accentColor:Lerp(Color3.new(0,0,0), 0.7)),
                         })
    Rotation           : 0

  ── Speed Value (left) ──
    Type               : TextLabel
    Text               : tostring(threshold)
    Font               : GothamBlack
    TextSize           : 32
    TextColor3         : accentColor
    Position           : UDim2.new(0, 14, 0.5, 0)
    AnchorPoint        : Vector2.new(0, 0.5)
    Size               : UDim2.fromOffset(60, 40)
    BackgroundTransparency: 1
    ZIndex             : 832

  ── "studs/s" Unit Label ──
    Text               : "studs/s"
    Font               : Gotham
    TextSize           : 10
    TextColor3         : accentColor:Lerp(Color3.new(1,1,1), 0.4)
    Position           : below speed value
    BackgroundTransparency: 1

  ── Headline (center-right) ──
    Text               : random from CelebrationText[threshold]
    Font               : GothamBlack
    TextSize           : 18
    TextColor3         : Color3.new(1, 1, 1)
    Position           : UDim2.new(0, 82, 0, 10)
    Size               : UDim2.new(1, -92, 0, 24)
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 832

  ── Flavor Subtext ──
    Text               : random from FlavorText[threshold]
    Font               : Gotham
    TextSize           : 12
    TextColor3         : Color3.fromRGB(200, 200, 220)
    Position           : UDim2.new(0, 82, 0, 36)
    Size               : UDim2.new(1, -92, 0, 32)
    TextWrapped        : true
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 832

  ── Flex Text (bottom bar, optional) ──
    Text               : FlexText[threshold]
    Font               : GothamBold
    TextSize           : 9
    TextColor3         : accentColor:Lerp(Color3.new(1,1,1), 0.5)
    Position           : UDim2.new(0.5, 0, 1, -2)
    AnchorPoint        : Vector2.new(0.5, 1)
    Size               : UDim2.new(1, -16, 0, 14)
    TextXAlignment     : Center
    BackgroundTransparency: 1
    ZIndex             : 832
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED TOAST — TIERED VISUAL INTENSITY
────────────────────────────────────────────────────────────────────────────────

  | Threshold | Card Size   | Screen Flash | Particles | Shake   | Sound Pitch |
  |-----------|-------------|--------------|-----------|---------|-------------|
  | 50        | 280×70      | none         | 6 dots    | none    | 1.0         |
  | 100       | 300×74      | none         | 8 dots    | none    | 1.05        |
  | 150       | 310×76      | subtle gold  | 10 dots   | 0.04    | 1.1         |
  | 200       | 320×80      | subtle gold  | 12 dots   | 0.06    | 1.15        |
  | 300       | 330×84      | gold         | 16 dots   | 0.08    | 1.2         |
  | 400       | 340×88      | gold+white   | 20 dots   | 0.10    | 1.25        |
  | 500       | 350×92      | bright gold  | 24 dots   | 0.12    | 1.3         |
  | 750       | 360×96      | intense gold | 28 dots   | 0.14    | 1.35        |
  | 1000      | 380×100     | WHITE BLAST  | 36 dots   | 0.18    | 1.4         |

  Screen flash (thresholds >= 150):
    Full-screen Frame, ZIndex 998:
      BackgroundColor3   : accentColor for gold; white for 1000
      BackgroundTransparency: tween peak → 1 over 0.25s
      Peak transparency  : 0.85 (subtle) → 0.55 (1000)

  Camera shake:
    cameraShake(intensity from table, 0.15s)

  Sound: "speed_milestone_chime"
    Character: ascending crystalline ding, ~0.25s
    Pitch scales per table above
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPEED TOAST — ANIMATION
────────────────────────────────────────────────────────────────────────────────

  Entrance (0–0.35s):
    Card Position Y    : -60 → 60 over 0.3s (Back Out) — drops in from above
    UIScale            : 0.6 → 1.08 over 0.25s (Back Out)
    then settle        : 1.08 → 1.0 over 0.1s (Quad Out)
    BackgroundTransparency: 0.8 → 0.06 over 0.2s

  Accent pulse (during hold):
    UIStroke.Color      : accentColor:Lerp(white, pulse)
    pulse              = 0.15 * (math.sin(os.clock() * 5) + 1) / 2
    Creates a gentle glow throb on the border.

  Hold duration:
    1.8s base; +0.3s per 200 above 200 (max 3.0s at 1000)

  Accent spark particles (emitted at entrance):
    Count              : per tiered table above
    Size               : 2×2 to 5×5 px
    Color              : accentColor with ±15 per-channel variance
    Spawn              : top and bottom edges of card
    Direction          : radially outward
    Speed              : 50–130 px/s
    Lifetime           : 0.2–0.4s
    Transparency       : 0.1 → 1 over lifetime
    Stagger            : 0–0.08s random

  Exit (hold end → +0.3s):
    Position Y         : current → -80 over 0.3s (Quad In) — slides up and out
    BackgroundTransparency: 0.06 → 1 over 0.2s
    UIScale            : 1.0 → 0.85 over 0.2s
    Destroy at 0.35s

  1000 STUDS/S SPECIAL — TRANSCENDENCE MOMENT:
    Expanded card with gold-to-white gradient border:
      UIStroke.Color    : animated — cycles gold → white → gold over 1.5s
      UIGradient on card: animated ColorSequence scrolling gold-white-gold
    Firework burst at card center (same spec as PayoutPanelDesignSpec):
      20 dots, speed 150–300 px/s, gravity arc, 0.5–0.8s lifetime
    Screen flash: pure white, peak 0.55, fade over 0.35s
    Sound: "speed_milestone_transcend" — bass hit + ascending cascade, ~0.6s
]]


--[[
================================================================================
  SECTION C — REBIRTH MILESTONE CEREMONY
================================================================================
  Triggered when the player crosses 5/10/25/50/100 rebirths. These are rare,
  high-significance events — each one deserves a FULL-SCREEN ceremony with
  dramatic flair matching the prestige.

  Data sources:
    RebirthMilestoneConfig.MILESTONES → { threshold, key, label }
    key values: "veteran" | "elite" | "master" | "legend" | "immortal"

  Design goal: A full-screen ceremony that interrupts gameplay momentarily.
  The player just hit a major prestige milestone — this should feel like
  being inducted into an exclusive club.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  REBIRTH CEREMONY — BACKDROP + CARD
────────────────────────────────────────────────────────────────────────────────

  Backdrop:
    Same as First-Time (full-screen dim, transparency 0.4)
    Particle rain: colored by tier accent (see tier colors below)

  Card:
    Size               : UDim2.fromOffset(400, 260)
    Position           : UDim2.fromScale(0.5, 0.5)
    AnchorPoint        : Vector2.new(0.5, 0.5)
    BackgroundColor3   : Color3.fromRGB(12, 8, 25)
    ZIndex             : 810

  UICorner             : UDim.new(0, 18)

  UIStroke:
    Thickness          : 2.5
    Color              : tier accent color (see below)
    Transparency       : 0

  TIER ACCENT COLORS:
    veteran  (5)   : Color3.fromRGB(100, 200, 120)  — green (earned, steady)
    elite    (10)  : Color3.fromRGB( 80, 160, 255)  — blue (climbing)
    master   (25)  : Color3.fromRGB(200, 120, 255)  — purple (prestigious)
    legend   (50)  : Color3.fromRGB(255, 200,  50)  — gold (legendary)
    immortal (100) : animated rainbow — Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  REBIRTH CEREMONY — CONTENT
────────────────────────────────────────────────────────────────────────────────

  ── Rank Badge (centered above card) ──
    Type               : Frame (container)
    Size               : UDim2.fromOffset(80, 80)
    Position           : UDim2.new(0.5, 0, 0, -48)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundColor3   : tier accent
    ZIndex             : 830

    UICorner           : UDim.new(0.5, 0) — circular

    UIStroke:
      Thickness        : 3
      Color            : tier accent:Lerp(white, 0.4)

    Inner TextLabel (rank number):
      Text             : tostring(threshold) .. "×"
      Font             : GothamBlack
      TextSize         : 22
      TextColor3       : Color3.new(1, 1, 1)
      TextStrokeColor3 : tier accent:Lerp(black, 0.5)
      TextStrokeTransparency: 0.4

  ── Title ──
    Text               : milestone.label  (e.g. "LEGEND!")
    Font               : GothamBlack
    TextSize           : 28
    TextColor3         : tier accent
    TextStrokeColor3   : tier accent:Lerp(black, 0.6)
    TextStrokeTransparency: 0.4
    Position           : UDim2.new(0.5, 0, 0, 50)
    ZIndex             : 815

  ── Subtitle ──
    Text               : "Rebirth Milestone Reached"
    Font               : GothamBold
    TextSize           : 14
    TextColor3         : Color3.fromRGB(200, 200, 220)
    Position           : UDim2.new(0.5, 0, 0, 84)
    ZIndex             : 815

  ── Prestige Tier Label ──
    Text               : `Prestige Tier {tier}/5`
    Font               : Gotham
    TextSize           : 12
    TextColor3         : tier accent:Lerp(white, 0.5)
    Position           : UDim2.new(0.5, 0, 0, 108)
    ZIndex             : 815

  ── Tier Progress Bar ──
    Position           : UDim2.new(0.5, 0, 0, 130)
    Size               : UDim2.new(0.7, 0, 0, 8)
    AnchorPoint        : Vector2.new(0.5, 0)
    Background         : Color3.fromRGB(30, 20, 50)
    Fill color         : tier accent
    Fill fraction      : tier / 5  (e.g. legend = 4/5 = 0.8)
    UICorner           : UDim.new(0.5, 0)
    ZIndex             : 815

    Fill animation: tween from 0 → target over 0.6s (Quad Out)
    Starts at t=0.5s after card entrance

  ── Dismiss Button ──
    Same spec as First-Time dismiss but text = "LET'S GO!"
    BackgroundColor3   : tier accent
    TextColor3         : contrast color (black for light accents, white for dark)
    Position           : UDim2.new(0.5, 0, 1, -20)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  REBIRTH CEREMONY — TIERED ENTRANCE SPECTACLE
────────────────────────────────────────────────────────────────────────────────

  All tiers share the base entrance (similar to First-Time), but higher
  tiers layer additional effects:

  VETERAN (5):
    Base entrance + 12 accent-colored sparkle particles
    Sound: "ceremony_rebirth_veteran" — warm chime, ~0.4s

  ELITE (10):
    Base entrance + 16 particles + subtle screen-edge blue flash
    UIStroke pulse: 0.0 ↔ 0.15 transparency, 2 Hz
    Sound: "ceremony_rebirth_elite" — deeper chime + bell, ~0.5s

  MASTER (25):
    Base entrance + 20 particles + purple screen-edge flash
    Rank badge entrance: spins 360° during UIScale pop-in (0.3s)
    Card UIGradient shimmer sweep (same as PayoutPanel PB shimmer)
    Sound: "ceremony_rebirth_master" — orchestral swell, ~0.6s

  LEGEND (50):
    Base entrance + 24 particles + gold screen flash (peak 0.65)
    Firework burst at card center (12 gold dots, 150–280 px/s)
    Rank badge: rotating gold glow ring (same as PayoutPanel PB glow)
    Title label entrance slam: scale 1.4 → 1.0 (Elastic Out, 0.35s)
    Sound: "ceremony_rebirth_legend" — brass fanfare + shimmer, ~0.7s

  IMMORTAL (100):
    EVERYTHING from Legend tier, PLUS:
    Rainbow animated border (UIStroke color cycles hue)
    Card background: subtle rainbow UIGradient offset scroll
    36 particles with rainbow color pool
    Full-screen rainbow edge flash (0.5s, peak 0.55)
    Rank badge: pulsing rainbow glow + scale 1.0 ↔ 1.08
    Second firework burst at t=0.7s (8 white-gold dots)
    Screen shake: intensity 0.12, duration 0.2s
    Sound: "ceremony_rebirth_immortal" — epic bass drop + cascade, ~1.0s

  Exit: same as First-Time exit for all tiers.
  Auto-dismiss: 12s for veteran/elite, 15s for master/legend/immortal.
]]


--[[
================================================================================
  SECTION D — SPENDING MILESTONE CEREMONY
================================================================================
  Triggered by MilestoneCeremonyService.recordRobuxSpend() → "SpendMilestone"
  remote. Tiers: 50 / 100 / 250 / 500 / 1000 / 2500 / 5000 Robux.

  Design goal: Make the spender feel VALUED and EXCLUSIVE. The ceremony
  should validate their investment, reinforce their status, and make them
  feel like they belong to a special club. Never condescending.

  Layout: same card structure as Rebirth Ceremony but with spending-specific
  content slots for the three-part message (title / subtitle / description)
  from FirstTimeConfig.SpendingMilestones.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  SPENDING CEREMONY — CARD CONTENT
────────────────────────────────────────────────────────────────────────────────

  Card Size            : UDim2.fromOffset(380, 280)
  BackgroundColor3     : Color3.fromRGB(15, 10, 30)

  UIGradient (gold tint from top):
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 30, 15)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 10, 30)),
                           ColorSequenceKeypoint.new(1,   Color3.fromRGB(25, 18, 10)),
                         })
    Rotation           : 90

  UIStroke:
    Color              : tier-specific (see below)
    Thickness          : 2.5

  TIER COLORS:
    First Timer (50)   : Color3.fromRGB(120, 200, 160)
    Investor   (100)   : Color3.fromRGB(100, 180, 255)
    VIP        (250)   : Color3.fromRGB(200, 140, 255)
    Whale      (500)   : Color3.fromRGB(255, 180,  60)
    Legend    (1000)    : Color3.fromRGB(255, 200,  50)
    Tycoon   (2500)    : Color3.fromRGB(255, 140,  40)
    Mythic   (5000)    : animated rainbow

  ── Tier Badge (top, replaces crown icon) ──
    Frame              : UDim2.fromOffset(100, 28)
    Position           : UDim2.new(0.5, 0, 0, 14)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundColor3   : tier color
    UICorner           : UDim.new(0, 8)
    ZIndex             : 830

    Label inside:
      Text             : payload.tierName  (e.g. "WHALE")
      Font             : GothamBlack
      TextSize         : 12
      TextColor3       : contrast color

  ── Title (from payload) ──
    Text               : payload.title  (e.g. "WHALE STATUS!")
    Font               : GothamBlack
    TextSize           : 24
    TextColor3         : tier color
    Position           : UDim2.new(0.5, 0, 0, 56)

  ── Subtitle ──
    Text               : payload.subtitle
    Font               : GothamBold
    TextSize           : 14
    TextColor3         : Color3.new(1, 1, 1)
    Position           : UDim2.new(0.5, 0, 0, 90)

  ── Description ──
    Text               : payload.description
    Font               : Gotham
    TextSize           : 12
    TextColor3         : Color3.fromRGB(200, 200, 220)
    TextWrapped        : true
    Position           : UDim2.new(0.5, 0, 0, 120)
    Size               : UDim2.new(1, -32, 0, 60)

  ── Total Spent Counter ──
    Text               : `Total: {threshold}R$ invested`
    Font               : GothamBold
    TextSize           : 11
    TextColor3         : tier color:Lerp(white, 0.5)
    Position           : UDim2.new(0.5, 0, 0, 188)

  ── Dismiss ──
    Text               : "THANK YOU!"
    BackgroundColor3   : tier color

  Entrance: same as Rebirth Ceremony with tier-appropriate intensity.
  Tiers 500+ get firework bursts. Tiers 2500+ get rainbow effects.
]]


--[[
================================================================================
  SECTION E — STREAK MILESTONE TOAST
================================================================================
  Triggered by MilestoneCeremonyService.checkStreakMilestones() → "StreakMilestone"
  remote. Milestones: 3 / 7 / 14 / 30 / 60 / 100 days.

  Design goal: Quick, warm celebration. Streaks are RETENTION hooks — the
  ceremony should reinforce the habit and make the player protective of
  their streak. Lighter treatment than Rebirth/Spending ceremonies.

  Uses the same toast format as Speed Milestones but with a flame theme.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  STREAK TOAST — LAYOUT
────────────────────────────────────────────────────────────────────────────────

  Root Frame:
    Same structure as Speed Toast but with flame accents.
    Size               : UDim2.new(0, 340, 0, 76)
    Position           : UDim2.new(0.5, 0, 0, 60)
    BackgroundColor3   : Color3.fromRGB(25, 12, 8)

  UIStroke:
    Color              : streak accent (see below)
    Thickness          : 2

  UIGradient:
    Color              : warm ember gradient
      ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(60, 20, 8)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 12, 8)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(60, 20, 8)),
      })

  STREAK ACCENT COLORS:
    3 days   : Color3.fromRGB(255, 160,  60)  — warm orange
    7 days   : Color3.fromRGB(255, 130,  40)  — deeper orange
    14 days  : Color3.fromRGB(255, 100,  30)  — red-orange
    30 days  : Color3.fromRGB(255,  80,  40)  — fire red
    60 days  : Color3.fromRGB(255,  50,  80)  — hot pink
    100 days : Color3.fromRGB(255, 200,  50)  — gold (eternal flame)

  ── Flame Icon (left) ──
    Text               : "🔥"
    TextSize           : 28
    Position           : UDim2.new(0, 12, 0.5, 0)

  ── Day Counter (beside icon) ──
    Text               : `{streak} DAYS`
    Font               : GothamBlack
    TextSize           : 22
    TextColor3         : streak accent

  ── Body Text ──
    Text               : payload.body  (from StreakMilestones variants)
    Font               : GothamBold
    TextSize           : 13
    TextColor3         : Color3.new(1, 1, 1)
    TextWrapped        : true
    Position           : UDim2.new(0, 90, 0, 8)
    Size               : UDim2.new(1, -100, 1, -16)

  Animation: same as Speed Toast (drop in from above, hold 2.5s, slide out).

  Streak >= 30 days:
    Flame particles emit from bottom of card (4–6 orange-red dot Frames):
      Size             : 3×3 to 5×5 px
      Color            : streak accent ± 20 per-channel
      Direction        : upward
      Speed            : 30–60 px/s
      Lifetime         : 0.4–0.7s
      Spawn rate       : ~3/s during hold
    UIStroke pulse: transparency 0 ↔ 0.2, 1.5 Hz

  Streak == 100 days:
    Gold border, gold particles
    Screen flash: gold, peak 0.75, 0.2s
    Sound: "ceremony_streak_century" — epic chime cascade, ~0.6s

  Default sound: "ceremony_streak"
    Character: warm crackling chime, ~0.3s
    Pitch scales: 1.0 (3d) → 1.3 (100d)
]]


--[[
================================================================================
  CEREMONY QUEUE SYSTEM
================================================================================
  Multiple ceremonies can trigger near-simultaneously (e.g. first rebirth
  + rebirth milestone 5). The queue prevents overlap.

  Rules:
    1. Max 1 ceremony visible at a time.
    2. Toasts (speed/streak) use a separate lightweight channel and can
       coexist with full ceremonies (they occupy different screen regions).
    3. Full ceremonies (first-time, rebirth, spending) queue in FIFO order.
    4. Queue depth capped at 3; excess ceremonies are silently dropped.
    5. Next ceremony starts 0.4s after previous exit completes.
    6. Suppress all ceremonies during active driving run. Queue for run-end.
    7. Speed toasts show during runs (they're non-blocking HUD elements).

  Implementation:
    local ceremonyQueue: { CeremonyPayload } = {}
    local isShowingCeremony = false

    function queueCeremony(payload)
      if #ceremonyQueue >= 3 then return end
      table.insert(ceremonyQueue, payload)
      if not isShowingCeremony then
        processNextCeremony()
      end
    end

    function processNextCeremony()
      if #ceremonyQueue == 0 then
        isShowingCeremony = false
        return
      end
      isShowingCeremony = true
      local payload = table.remove(ceremonyQueue, 1)
      showCeremony(payload, function()
        task.delay(0.4, processNextCeremony)
      end)
    end
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  ceremony_achievement           — triumphant fanfare stinger (0.5s)
  speed_milestone_chime          — ascending crystalline ding (0.25s, pitch varies)
  speed_milestone_transcend      — bass hit + ascending cascade (0.6s)
  ceremony_rebirth_veteran       — warm chime (0.4s)
  ceremony_rebirth_elite         — deeper chime + bell (0.5s)
  ceremony_rebirth_master        — orchestral swell (0.6s)
  ceremony_rebirth_legend        — brass fanfare + shimmer (0.7s)
  ceremony_rebirth_immortal      — epic bass drop + cascade (1.0s)
  ceremony_streak                — warm crackling chime (0.3s, pitch varies)
  ceremony_streak_century        — epic chime cascade (0.6s)

  Spending ceremonies reuse rebirth ceremony sounds at matching intensity:
    50/100  → ceremony_rebirth_veteran
    250     → ceremony_rebirth_elite
    500     → ceremony_rebirth_master
    1000    → ceremony_rebirth_legend
    2500/5000 → ceremony_rebirth_immortal

  Existing sounds reused:
    ui_confirm  — dismiss button click
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & ACCESSIBILITY
================================================================================

  Performance:
    - Max 1 full ceremony + 1 toast on screen. Queue excess.
    - Particle bursts capped at 36 dots per ceremony (one-shot, not looping).
    - Animated UIGradients use Offset tweens (GPU-friendly).
    - RenderStepped connections for pulse/glow effects disconnect on exit.
    - LOD 1: skip particles and screen flashes; show card + text only.

  Accessibility:
    - All text meets 4.5:1 contrast against card background.
    - Dismiss buttons are large (>44px height) and centered.
    - Auto-dismiss prevents soft-lock if button is missed.
    - Sound cues complement but don't replace visual feedback.

  Mobile:
    - Card width: math.min(specWidth, viewportWidth - 40)
    - Toast width: math.min(320, viewportWidth - 24)
    - Dismiss button touch target: full 0.55 card width × 40px height.
================================================================================
]]

return nil
