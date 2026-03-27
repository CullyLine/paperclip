--!strict
--[[
	IN-MENU LEADERBOARD PANEL — DESIGN SPEC (Luau mirror)
	======================================================
	Authoritative narrative + layout detail lives in:
	  `ConceptArt/leaderboard-panel-design.md`

	This module exists so Engineers grep the StarterGui tree and find the same
	rules without leaving the Rojo project. Numbers below stay aligned with the
	markdown; update both when product changes copy or colors.

	Context:
	  - World mesh leaderboard exists; this spec is the **menu** panel under
	    `DACMain`, opened from HUD (trophy / chart icon).
	  - `GetLeaderboard` is live: `LeaderboardPanel.luau` invokes it via
	    `RemoteFailSafe.invokeFunction` per tab; server-side `LeaderboardService`
	    + rate limits. See `PostPhase3Audit.md` §3 (2026-03-23 refresh).

	Style lock: AGENTS.md panel anatomy, pastel Polymita simulator language.
]]


--[[
================================================================================
  SECTION A — PANEL CHROME (AGENTS.md)
================================================================================
  Tab bar: white pill **above** body, centered. Four tabs — dark silhouette icons
  (road, coins, rebirth, friends). Active tab: slightly larger icon + soft fill
  `#FFD6EE`.

  Title: **outside** body, top-left — trophy/podium icon + GothamBlack white text,
  TextStroke transparency ~0.45–0.55. Copy: "Leaderboard" or "Top Drivers".

  Close: `#FF2222` rounded square, white ✕, top-right of **body** frame.

  Body frame:
    UIGradient     : `#FFD6EE` (top) → `#E0D6FF` (bottom)
    UIStroke       : `#2A2A40`, thickness 2–3 px
    UICorner       : ≥ 14 px
    Optional watermark: car/pet silhouettes @ 6–10% opacity

  Pre-built vs runtime:
    Shell (root, tabs, scroll, footer chrome, close) = Studio pre-built.
    Rows = runtime Instance.new into ScrollingFrame (inventory row pattern).
================================================================================
]]


--[[
================================================================================
  SECTION B — TABS & DATA MODES
================================================================================
  | Tab id   | Stat source (LeaderboardService)     |
  |----------|-------------------------------------|
  | distance | Total distance (formatted)          |
  | coins    | Lifetime / contract from service    |
  | rebirths | Rebirth count                       |
  | friends  | Same stat as active tab, list filtered to friends in server |

  Inactive tab label: `#5C5C70`. Active: `#1E1E1E` GothamBold.

  Friends tab empty state copy (centered, GothamBold `#1E1E1E`):
    "No friends here yet — invite some!"
================================================================================
]]


--[[
================================================================================
  SECTION C — ROW LAYOUT (TOP 100)
================================================================================
  ScrollingFrame + UIListLayout vertical, 8 px between rows, 12 px inner padding.
  Row height: 48–56 px @ 1080p reference.

  Columns (left → right):
    1) Rank (~56 px fixed)
         Ranks 1–3: crown icons — gold `#FFD700`, silver `#C0C0C0`, bronze `#CD7F32`
         + UIStroke for readability.
         Ranks 4–100: GothamBold numeral `#1E1E1E`, centered.
    2) Avatar: circular 40–44 px, stroke `#2A2A40` 1–2 px.
    3) Display name: GothamBold `#1E1E1E`, ellipsis truncate.
    4) Stat: right-aligned GothamBold; optional Coin Gold `#FFD54F` / emerald
       `#2ECC71` accents for emphasis.

  Local player row: UIStroke highlight `#4FC3F7` or `#AB47BC` @ 2 px, plus soft
  white fill BackgroundTransparency 0.15 OR pastel UIGradient band — must read
  instantly while scrolling.
================================================================================
]]


--[[
================================================================================
  SECTION D — LOADING & FOOTER
================================================================================
  Loading: 3–5 skeleton rounded bars (DAC pastel) — avoid default Roblox spinner.

  Sticky footer "YOUR RANK" (~52–60 px), top border 2 px `#2A2A40`:
    Background strip: `#E8DEFF` or white @ 0.2 transparency.
    Left: "YOUR RANK" GothamBold `#5C5C70`
    Center-left: compact avatar + name
    Right: rank numeral + stat for active tab
    If outside top 100: show truthful global rank e.g. "#142 globally".
================================================================================
]]


--[[
================================================================================
  SECTION E — REGISTRATION
================================================================================
  `MenuHub.registerPanel("leaderboard", rootFrame)` (or agreed key per UIController).
  HUD button opens panel; driving pause behavior TBD by product.
================================================================================
]]


local LeaderboardPanelDesignSpec = {}
LeaderboardPanelDesignSpec.version = 1
LeaderboardPanelDesignSpec.conceptArtPath = "ConceptArt/leaderboard-panel-design.md"
return LeaderboardPanelDesignSpec
