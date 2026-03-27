--!strict
--[[
	FRIEND PLAY BONUS — VISUAL & UX DESIGN SPEC
	============================================
	Art direction for POLA-234 (FriendBonusService) client layer: persistent HUD
	chip driven by `FriendBonusUpdate`, and top-of-screen `ServerDropFeed` banners
	when `kind == "friend_play"`.

	Server contracts (already implemented):
	  - `DACServerScriptService/Services/FriendBonusService.luau`
	  - `DACReplicatedStorage/Config/FriendBonusConfig.luau`
	  - `Remotes.getEvent("FriendBonusUpdate")` payload:
	      { active: boolean, friendCount: number, multiplier: number, percentLabel: string }
	    `percentLabel` is "+10%" | "+0%" | "+20%" from server math.
	  - `Remotes.getEvent("ServerDropFeed")` payload for social moment:
	      { kind: "friend_play", line: string, userId: number }
	    `line` is fully resolved copy from `SocialFeedConfig.FriendPlayFeed`.

	Engineer implementation targets:
	  - `DACStarterGui/HUD.luau` — chip UI + `FriendBonusUpdate` listener
	  - `DACStarterPlayerScripts/Controllers/VFXController.luau` — branch
	    `serverDropFeedBanner` so `friend_play` is not treated as a pet hatch
	    (today the queue only understands playerName/petName/rarity and will
	    mis-render friend events).

	Design pillars (match Phase 4 / SocialFeedDesignSpec):
	  - Warm, social, “squad energy” — distinct from cold hatch rarity blues.
	  - Never steal focus from driving: chip is small; banner uses same motion
	    language as hatch banners but different color/audio.
	  - Tier 2 (3+ friends, +20%) must feel noticeably more premium than tier 1.
]]


--[[
================================================================================
  SECTION A — PERSISTENT HUD CHIP ("FriendBonusChip")
================================================================================
  Purpose: Always show whether the friend multiplier is live and the current
  percent. Anchored near existing economy readouts so it reads as a “bonus
  rail” on top of the pet multiplier.

  Parent hierarchy (preferred):
    ScreenGui "DACMain"
      Frame "PlayerInfo"
        Frame "Currency"        ← existing coin/gem rows
        OR insert chip as sibling immediately BELOW "Currency" inside PlayerInfo

  If PlayerInfo uses UIListLayout, add the chip as the next list item after
  Currency so it reflows on mobile.

  Root frame:
    Name             : "FriendBonusChip"
    Visible          : false when inactive (friendCount < tier one); true when active
    Size             : UDim2.fromOffset(200, 26)   (desktop); min scale 0.85 on phone
    Position         : UDim2.new(0, 0, 0, 0) when list-placed; if manually placed,
                       use UDim2.new(0, 8, 1, 4) under Currency bottom edge
    AnchorPoint      : Vector2.new(0, 0)
    BackgroundColor3 : tier-based (see below)
    BackgroundTransparency : 0.12
    BorderSizePixel  : 0
    ZIndex           : 9   (HUD band 1–10 per SocialFeedDesignSpec)
    ClipsDescendants : false

  UICorner:
    CornerRadius     : UDim.new(0, 8)

  UIStroke:
    Color            : tier stroke color
    Thickness        : 1.25
    Transparency     : 0.25

  Layout (horizontal, left to right):
    [Icon 22×22]  [Primary line: "Friends bonus"]  [Badge: +10% / +20%]

  Icon (TextLabel or ImageLabel):
    If TextLabel:
      Text           : "👥"  (fallback — replace with thin vector icon later)
      TextSize       : 14
      BackgroundTransparency: 1
      Size           : UDim2.fromOffset(22, 22)

  Primary label:
    Name             : "Title"
    Text             : "SQUAD BOOST"  (tier 2)  |  "FRIEND BOOST" (tier 1)
    Font             : Enum.Font.GothamBold
    TextSize         : 13
    TextXAlignment   : Left
    TextColor3       : Color3.fromRGB(248, 250, 255)
    Size             : UDim2.new(1, -78, 1, 0)  -- flex minus icon + badge

  Percent badge (pill):
    Name             : "PercentBadge"
    Size             : UDim2.fromOffset(52, 20)
    Position         : UDim2.new(1, -54, 0.5, 0)
    AnchorPoint      : Vector2.new(0, 0.5)
    BackgroundColor3 : Color3.fromRGB(20, 24, 36)
    BackgroundTransparency: 0.35
    Text             : mirrors `percentLabel` from remote (+10% / +20%)
    Font             : GothamBlack
    TextSize         : 12
    TextColor3       : Color3.fromRGB(255, 235, 160)

  Tier color system (background + stroke + subtle gradient):
    Tier 1 (+10%, 1–2 friends in server):
      BG base        : Color3.fromRGB(32, 78, 110)
      UIGradient     : left Color3.fromRGB(24, 60, 95) → right Color3.fromRGB(46, 130, 160)
      Stroke         : Color3.fromRGB(120, 200, 230)

    Tier 2 (+20%, 3+ friends):
      BG base        : Color3.fromRGB(90, 40, 120)
      UIGradient     : Color3.fromRGB(70, 30, 95) → Color3.fromRGB(220, 140, 60)
      Stroke         : Color3.fromRGB(255, 210, 120)
      Title text     : may pick up slight gradient via UIGradient on label (optional)

  Motion:
    On transition inactive → active:
      Pop in UIScale 0.85 → 1.0 over 0.18s, Quad Out.
    On tier 1 → tier 2 while visible:
      Brief gold flare: UIStroke thickness 1.25→2.5→1.25 in 0.35s; optional
      particle spark via VFXFacade if available (non-blocking).
    Idle (active):
      Tier 1: opacity breathe on stroke Transparency 0.25↔0.4 over 2.8s loop.
      Tier 2: add slow UIGradient offset lerp 0→0.15 over 4s (shimmer).

  Driving mode:
    During runs, chip stays visible but drops to 80% opacity (BackgroundTransparency
    +0.08) so speedometer stays hero. No screen-center toasts from this spec.
================================================================================
]]


--[[
================================================================================
  SECTION B — SERVER DROP FEED VARIANT (`kind == "friend_play"`)
================================================================================
  Uses the same slide-in motion as hatch banners (see VFXController queue) but
  MUST use `payload.line` verbatim — do not rebuild from pet/rarity templates.

  Visual differences from hatch banners:
    - No pet icon column; optional small 👥 prefix inside the text line only if
      line does not already include emoji (server copy is authoritative).
    - Width: UDim2.fromOffset(440, 46)  (slightly shorter than 460 hatch width)
    - Background: sunset / social gradient — NOT rarity blues/purples.
      Suggested BG:
        Color3.fromRGB(48, 28, 72) with UIGradient:
          ColorSequenceKeypoint 0   : Color3.fromRGB(60, 35, 95)
          ColorSequenceKeypoint 0.45: Color3.fromRGB(200, 90, 60)
          ColorSequenceKeypoint 1   : Color3.fromRGB(255, 190, 90)
    - Stroke: Color3.fromRGB(255, 220, 150), thickness 1.5
    - Text: GothamBold 17, TextColor3 Color3.fromRGB(255, 248, 240)
    - ZIndex: 8000 (same layer family as hatch feed)

  Audio:
    Prefer `SoundFacade.playOneShot("social_ping")` if registered; otherwise a
    softer one-shot than hatch `notification` (avoid identical SFX for two systems).

  CRITICAL — self visibility:
    Current `serverDropFeedBanner` returns early when `payload.userId == localPlayer`
    (hatch: hide your own pull). For `friend_play`, the celebrated player SHOULD
    see the banner — the copy is about them. Implementation:
      if payload.kind == "friend_play" then
        -- do NOT apply the hatch self-filter; queue friend banner for everyone.
      else
        -- existing hatch behavior + self-filter
      end

  Queue mixing:
    Friend banners share the same throttle queue as hatch banners so the top
    feed never overlaps; priority: friend_play may preempt stale hatch if queue
    depth > 2 (optional polish — default FIFO is OK).
================================================================================
]]


--[[
================================================================================
  SECTION C — COPY & CONFIG HOOKS
================================================================================
  Lines already live in `SocialFeedConfig.FriendPlayFeed`. Do not duplicate in UI.

  Optional future: `MicrocopyConfig` entries for chip title if product wants A/B
  “SQUAD BOOST” vs “FRIENDS +10%” — not required for MVP.

  Sound registration (SoundController / SoundFacade):
    - `social_ping` — short glassy tick (~0.35s)
    - Reuse existing `notification` only if nothing else is available
================================================================================
]]


--[[
================================================================================
  SECTION D — ENGINEER CHECKLIST
================================================================================
  [ ] HUD: create FriendBonusChip per Section A; hide when not `active`.
  [ ] HUD: `FriendBonusUpdate.OnClientEvent` updates title tier text, percent badge,
        colors, and visibility.
  [ ] VFX: parse `payload.kind`; implement friend banner path using `payload.line`.
  [ ] VFX: remove incorrect self-filter for `friend_play` (Section B).
  [ ] QA: two clients, mutual friends, verify +10% → +20% when third friend joins
        (chip anim + banner line placeholders {PLAYER}/{FRIEND}/{PERCENT}).
================================================================================
]]


-- Module export: spec is documentation-only; keep a table for require() parity.
local FriendBonusDesignSpec = {}
FriendBonusDesignSpec.version = 1
return FriendBonusDesignSpec
