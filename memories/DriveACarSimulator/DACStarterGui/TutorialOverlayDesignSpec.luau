--!strict
--[[
	TUTORIAL OVERLAY — VISUAL & UX DESIGN SPEC
	============================================
	Semantic layer on top of `DACStarterGui/TutorialOverlay.luau` + pre-built
	`StarterGui.DACTutorialOverlay`. The script wires server-driven steps; Studio
	owns static hierarchy (Root, Dimmer, Bubble, Skip).

	Remote: `TutorialStep` (client) — payload drives `show()`.
	Remote: `TutorialSkip` — client fires when player taps skip.

	Design goals:
	  - Read as friendly coach, not modal spam — soft dim, readable bubble.
	  - Highlight targets without obscuring HUD chrome; stroke must pass WCAG-ish
	    contrast on both light and dark panel backgrounds.
	  - Completion moment = celebration (confetti + chime), not a dry dismiss.
]]


--[[
================================================================================
  SECTION A — LAYERING & PRE-BUILT SHELL
================================================================================
  ScreenGui "DACTutorialOverlay":
    DisplayOrder     : UILayerStack.screenGui.tutorialOverlay (= 700); see ReplicatedStorage.DAC.Config.UILayerStack (below loadingScreen 100000)
    ResetOnSpawn     : false
    Enabled          : toggled by script

  Root (Frame) — full screen:
    ZIndexBase       : 1

  Dimmer (Frame) — full bleed:
    BackgroundColor3 : Color3.fromRGB(8, 10, 22)
    BackgroundTransparency: 0.35–0.45 (tune in Studio; script does not tween)
    Purpose          : focus without full black-out; lanes still perceptible.

  Bubble (Frame) — speech card:
    Max width        : ~520 px at 1080p reference (use UISizeConstraint)
    UICorner         : ≥ 12 px
    UIStroke         : #2A2A40 or soft charcoal, 1.5–2 px
    UIGradient (opt) : top #FFFFFF → bottom #F3F6FF at low contrast
    Child UIScale    : driven by animateBubbleIn (Back overshoot → settle)

  Title (TextLabel):
    Font             : GothamBlack
    TextSize         : 22–26
    TextColor3       : #1E1E1E
    TextWrapped      : true

  Body (TextLabel):
    Font             : Gotham
    TextSize         : 16–18
    TextColor3       : #3C3C50
    TextWrapped      : true
    Line height      : comfortable (RichText optional for bold keywords)

  SkipTutorial (TextButton) — root child:
    Visible          : hidden on completion step
    Style            : tertiary — outline or ghost; must not compete with bubble CTA
    Text             : "Skip" or "Skip tutorial"

  SkipConfirm (Frame) — root child (POLA-455); starts Visible = false; ZIndex above bubble:
    ConfirmDimmer    : extra dim over tutorial dimmer when confirming skip
    Panel            : pastel card; ConfirmTitle / ConfirmBody from MicrocopyConfig.TutorialSkipConfirm*
    KeepLearning     : green — dismisses modal
    SkipAnyway       : red — fires TutorialSkip remote after tutorial_skip_confirm SFX
================================================================================
]]


--[[
================================================================================
  SECTION B — TARGET HIGHLIGHT & ARROW
================================================================================
  When `payload.targetName` matches a GuiObject.Name under PlayerGui:
    UIStroke "TutorialHighlightStroke" parented to target:
      Color            : Color3.fromRGB(255, 213, 79)  (tutorial gold)
      Thickness        : 4 → 6 loop (0.8s Sine InOut, infinite)
      ApplyStrokeMode  : Border

    Arrow (TextLabel) — Unicode ▼ U+25BC above target:
      TextColor3       : same gold
      TextSize         : 28
      Position         : centered over target top edge, bobbing ±8 px / 0.6s loop

  When no target: bubble centers at ~0.42 Y (landscape-safe).

  Mobile: ensure highlight stays inside safe area; if target near screen edge,
    clamp arrow X so it does not clip (future enhancement).
================================================================================
]]


--[[
================================================================================
  SECTION C — COMPLETION MOMENT
================================================================================
  When `payload.done == true` (and step sentinel):
    Title/body       : from payload or defaults ("Tutorial Complete!", etc.)
    Sound            : `tutorial_complete`
    Skip             : hidden
    Confetti         : 40 pieces, palette CONFETTI_COLORS in TutorialOverlay
    Auto-dismiss     : ~4 s after show (screenGui.Enabled = false)

  Non-done steps:
    Sound            : `tutorial_step`
    Skip             : visible
================================================================================
]]


--[[
================================================================================
  SECTION D — PAYLOAD CONTRACT (REFERENCE)
================================================================================
  TutorialStep → client:
    {
      done?: boolean,
      step?: number,
      title?: string,
      body?: string,
      targetName?: string,   -- GuiObject.Name to highlight; optional
    }

  Edge case: done + step 0/nil → hard hide overlay (tutorial reset / abort path).
================================================================================
]]


--[[
================================================================================
  SECTION E — ENGINEER CHECKLIST (POLISH)
================================================================================
  [ ] Dimmer transparency in spec range on OLED + LCD test places.
  [ ] Bubble does not cover critical Drive button when target is action bar.
  [ ] Skip is reachable with one thumb (bottom third on phone).
  [ ] tutorial_complete / tutorial_step registered in SoundController (non-zero ids).
  [ ] Z-order verified vs FriendBonus / payout overlays during simultaneous edge QA.
================================================================================
]]


local TutorialOverlayDesignSpec = {}
TutorialOverlayDesignSpec.version = 1
return TutorialOverlayDesignSpec
