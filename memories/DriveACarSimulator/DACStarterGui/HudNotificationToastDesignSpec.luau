--!strict
--[[
	HUD NOTIFICATION TOAST — Visual & Motion Design Spec
	======================================================
	Phase 4 dopamine: the **right-rail toast stack** for generic HUD messages —
	streak warnings, coin grants, errors, and info nudges. This spec is the
	contract for `UIController.showNotification` and must stay synchronized with
	implementation.

  Design goal: **readable in 0.3s**, **premium glass feel**, **no fatigue** —
	max 2 visible toasts (POLA-332), priority queue + coalesce + run deferral,
	smooth repositioning when one dismisses, streak urgency reads hotter than info.

	Reference implementation:
	  - `DACStarterPlayerScripts/Controllers/UIController.luau` (`showNotification`,
	    `repositionToasts`, `dismissToast`, `TOAST_*` locals, `TOAST_ICONS`)
	  - `DACReplicatedStorage/Config/UILayerStack.luau` (ZIndex: hudNotificationToast*)
	  - `DACReplicatedStorage/NewPlayerCalmWindow.luau` (early-session toast deferral)

	Engineer notes:
	  - Toasts parent to `playerGui.DACMain` (`screenGui` after `UIController.init`).
	  - Do not raise Z above `UILayerStack` values without updating this spec.
	  - Sound keys must exist in `SoundController` / `SoundFacade` registry.
]]

--[[
================================================================================
  SECTION A — LAYOUT & STACKING
================================================================================
  Root: programmatic `Frame` named `Toast_<id>`.

  | Constant        | Value | Notes                                      |
  |-----------------|-------|--------------------------------------------|
  | MAX_TOASTS      | 2     | Priority-aware eviction + FIFO; see HudToastConfig |
  | TOAST_WIDTH     | 320   | Fixed width; height = AutomaticSize Y      |
  | TOAST_GAP       | 8     | Vertical gap between stacked toasts          |
  | TOAST_LIFETIME  | 3.5s  | Auto-dismiss after show (seconds); ~2.6s on low graphics |

  Anchor & rail:
    AnchorPoint   : Vector2.new(1, 0)   -- top-right anchored
    Rest X        : UDim2.new(1, -10, 0, startY)   -- 10px inset from right edge
    Offscreen in  : UDim2.new(1, TOAST_WIDTH + 10, 0, startY)  -- starts right of viewport

  Vertical slots (top to bottom, index i = 1..n):
    startY = 10 + (i - 1) * (64 + TOAST_GAP)
    (64px is the nominal single-line height band; multi-line label grows AutomaticSize.)

  Chrome:
    BackgroundColor3   : Color3.fromRGB(24, 26, 40)  default
    BackgroundTransparency : 0.06
    BorderSizePixel    : 0
    ClipsDescendants   : true
    UICorner           : UDim.new(0, 12)

  Left accent bar:
    Frame 4px wide, full height, `BackgroundColor3` = icon / kind color
    ZIndex : UILayerStack.hudNotificationToastAccent (502)

  Icon:
    TextLabel 28×28, GothamBold 20, unicode glyphs per kind (see Section B)

  Body:
    TextLabel, GothamMedium 15, white text, left aligned, wrapped
    Padding on label: top/bottom 12, right 8

  Special background tint:
    `kind == "streak_celebrate"` → BackgroundColor3 = Color3.fromRGB(38, 34, 52)

  ZIndex hierarchy (from `UILayerStack.luau`):
    toast root     : 500  (hudNotificationToast)
    shimmer overlay: 501  (hudNotificationToastShimmer) — only when Section D applies
    accent/icon/lbl: 502  (hudNotificationToastAccent)
================================================================================
]]

--[[
================================================================================
  SECTION B — TOAST KINDS & `TOAST_ICONS` MAP
================================================================================
  `notification.type` string selects visual accent. Unknown kinds fall back to **info**.

  | kind             | Glyph (UTF-8) | Accent RGB           | Stroke rules (Section C) |
  |------------------|---------------|----------------------|---------------------------|
  | success          | ✓ (check)     | (80, 220, 120)       | default 1px               |
  | error            | ✗             | (255, 90, 90)        | default 1px               |
  | info             | ℹ             | (100, 160, 255)      | default 1px               |
  | streak_nudge     | ⚠             | (255, 190, 90)       | default 1px               |
  | streak_urgent    | ⚡            | (255, 120, 60)       | 2px stroke, urgency pulse |
  | streak_critical  | ✗             | (255, 60, 80)        | 2px, transparency 0.25   |
  | streak_celebrate | ★             | (255, 210, 120)      | default 1px + bg tint A   |

  UIStroke on root toast:
    Thickness: 2 if streak_critical OR streak_urgent else 1
    Color: icon accent color
    Transparency: 0.25 if streak_critical else 0.5
================================================================================
]]

--[[
================================================================================
  SECTION C — MOTION
================================================================================
  Entrance (slide in from right + fade via GroupTransparency 1→0):
    Duration       : 0.35s (0.22s on low graphics tier)
    EasingStyle    : Back
    EasingDirection: Out
    Target position: UDim2.new(1, -10, 0, startY)
    Stagger         : +0.06s defer after eviction when replacing (juice)

  Dismiss (slide out to right):
    Duration       : 0.30s
    EasingStyle    : Quad
    EasingDirection: In
    Target X offset: TOAST_WIDTH + 10 (keeps current Y)
    Destroy delay  : 0.35s after tween start (after frame leaves)

  Reposition (when a toast above/below is removed):
    Duration       : 0.25s
    EasingStyle    : Quad
    EasingDirection: Out
    Target Y       : recomputed slot formula in Section A

  Urgency micro-scale (streak_urgent / streak_critical only):
    Pulses: urgent = 1, critical = 2 sequential pulses
    Start delay per pulse: 0.38s + (p-1)*0.28s
    Scale up: 0.11s Quad Out → Scale 1.06
    Scale dn: 0.12s Quad Out → Scale 1.00
================================================================================
]]

--[[
================================================================================
  SECTION D — GOLD-SHIMMER HEURISTIC (“+” IN MESSAGE)
================================================================================
  If `msg` contains the substring "+" (plain find), add a full-bleed shimmer
  `Frame` child:
    BackgroundColor3 white, BackgroundTransparency 0.92
    UICorner 12px to match toast
    UIGradient: white → warm yellow center → white, with transparency notch at center
    Rotation: 25°
    Start Offset: (-1, 0) → tween to (1, 0) over 1.5s Linear, repeat count 1

  Purpose: subtle **loot / currency gain** read without a separate toast kind.
  Anti-pattern: do not enable shimmer on streak-only messages unless copy includes "+".
================================================================================
]]

--[[
================================================================================
  SECTION E — SFX (`SoundFacade.playOneShot`)
================================================================================
  | Condition                         | Key             |
  |-----------------------------------|-----------------|
  | kind == "error"                   | purchase_fail   |
  | kind == "streak_critical"         | alert           |
  | streak_nudge, streak_urgent,      | notification    |
  |   streak_celebrate, or default    |                 |

  Missing keys should be registered in `SoundController` before changing this table.
================================================================================
]]

--[[
================================================================================
  SECTION F — SPECIAL PATHS (NOT STANDARD TOAST CHROME)
================================================================================
  1) `reward_claim`
     If `notification.type == "reward_claim"`, UI may bypass toast entirely and
     route to `getRewardChestAnimation().play(notification)` when available.
     Empty `message` is allowed for this kind.

  2) New player calm window
     If `NewPlayerCalmWindow.shouldDeferHudToast(kind, notification)` returns true,
     enqueue via `NewPlayerCalmWindow.enqueueNotification` — **no toast yet**.
     Ensures tutorial first-run is not spammed by economy toasts.

  3) Console trace
     Implementation prints `[DAC] <msg>` for debugging; strip or gate in shipping if noisy.
================================================================================
]]

--[[
================================================================================
  SECTION G — P1 FUTURE (OPTIONAL ENGINEER PASS)
================================================================================
  If notifications gain a `rarity` field ("common" … "mythic"), tint stroke +
  icon using `Constants.RARITY_COLORS` (same family as `PetEntranceDesignSpec`)
  for hatch / reward toasts — **without** increasing simultaneous toast count.

  Not required for MVP; document keys here when implemented:
    (none yet)
================================================================================
]]

return nil
