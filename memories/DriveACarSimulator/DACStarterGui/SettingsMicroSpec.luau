--!strict
--[[
	SETTINGS PANEL MICRO-INTERACTIONS — Design Spec
	=================================================
	Defines polished micro-interactions for SettingsPanel controls.
	Each control type gets a full animation breakdown with timing,
	easing, colors, and sound cues.

	Current state (SettingsPanel.luau):
	  - Toggle: button swaps text "On"/"Off" with color tween (0.16s Quad)
	  - Slider: fill tracks input, bar scales 1→1.06 on grab (0.1s Quad)
	  - Panel: slides from right (offRightPos) to center (0.3s Quad Out),
	    slides back out on close (0.28s Quad In)
	  - No section dividers, no first-visit effects

	This spec layers juice onto that foundation without changing the
	control structure. All tweens use TweenService unless noted.
]]


--[[
================================================================================
  1. TOGGLE SWITCH — Slide + Color + Bounce
================================================================================
  Replace the current text-swap button with a track+knob slide toggle.
  The knob physically slides from one end to the other with an elastic
  settle, and the track color smoothly transitions.

  TRACK (the background Frame):
    Size           : UDim2.new(0, 52, 0, 28)
    CornerRadius   : UDim.new(0.5, 0) (fully rounded, pill shape)
    Colors:
      Off          : Color3.fromRGB(55, 55, 75)
      On           : Color3.fromRGB(60, 165, 95)
    Transition     : TweenInfo.new(0.22, Quad, Out)

  KNOB (the sliding circle inside the track):
    Size           : UDim2.fromOffset(22, 22)
    AnchorPoint    : Vector2.new(0, 0.5)
    CornerRadius   : UDim.new(0.5, 0)
    BackgroundColor: Color3.new(1, 1, 1)
    Positions:
      Off          : UDim2.new(0, 3, 0.5, 0)
      On           : UDim2.new(1, -25, 0.5, 0)

  ANIMATION SEQUENCE (on click):
    t=0.00s  Sound: "click"
    t=0.00s  Track BackgroundColor3 tweens to target (0.22s, Quad Out)
    t=0.00s  Knob Position.X tweens to target:
               TweenInfo.new(0.28, Elastic, Out)
               The Elastic easing creates the bounce at the endpoint.
    t=0.00s  Knob UIScale: 1.0 → 1.12 over 0.06s (Quad Out)
               Knob "squishes" slightly as it begins moving.
    t=0.06s  Knob UIScale: 1.12 → 1.0 over 0.22s (Quad Out)
               Returns to normal as elastic settles.

  HOVER/PRESS FEEDBACK:
    Mouse enter: Knob UIStroke appears (Thickness 2, Color white, Transp 0.6)
                 Tween Transparency 0.6→0.3 over 0.12s
    Mouse leave: UIStroke Transparency → 0.6 over 0.12s, then destroy
    Mouse down:  Knob BackgroundColor3 → Color3.fromRGB(230, 230, 230), 0.06s
    Mouse up:    Knob BackgroundColor3 → white, 0.08s

  LABEL TEXT:
    Keep the "On"/"Off" TextLabel to the left of the track for accessibility.
    The text itself does NOT animate — the track+knob motion is the feedback.
]]


--[[
================================================================================
  2. SLIDER — Handle Glow + Fill Animation + Value Label Pop
================================================================================
  Build on the existing bar+fill slider. Add a visible handle, glow-on-grab,
  animated fill color, and a floating value label.

  HANDLE (circle at the fill edge):
    Size           : UDim2.fromOffset(18, 18)
    AnchorPoint    : Vector2.new(0.5, 0.5)
    Position       : UDim2.new(fillPercent, 0, 0.5, 0)
    CornerRadius   : UDim.new(0.5, 0)
    BackgroundColor: Color3.fromRGB(255, 255, 255)
    Parent         : bar (the TextButton track)

  HANDLE GLOW (on grab):
    A second Frame behind the handle, same center:
      Name         : "HandleGlow"
      Size         : UDim2.fromOffset(34, 34) (ring around handle)
      AnchorPoint  : Vector2.new(0.5, 0.5)
      CornerRadius : UDim.new(0.5, 0)
      BackgroundColor: fill color (Color3.fromRGB(120, 200, 255))
      Transparency : 0.75

    On grab (InputBegan):
      t=0.00s  HandleGlow.BackgroundTransparency: 0.75 → 0.45 (0.12s, Quad Out)
      t=0.00s  HandleGlow.Size: 34×34 → 40×40 (0.12s, Quad Out)
      t=0.00s  Handle UIScale: 1.0 → 1.15 (0.08s, Quad Out)
      t=0.00s  Bar UIScale: 1.0 → 1.04 (0.06s, Quad Out)
               Existing bar scale behavior kept but reduced to 1.04.

    On release (InputEnded):
      t=0.00s  HandleGlow.BackgroundTransparency: current → 0.75 (0.18s, Quad Out)
      t=0.00s  HandleGlow.Size: current → 34×34 (0.18s, Quad Out)
      t=0.00s  Handle UIScale: 1.15 → 1.0 (0.12s, Quad Out)
      t=0.00s  Bar UIScale: 1.04 → 1.0 (0.10s, Quad Out)

  FILL COLOR ANIMATION:
    The fill gradient shifts based on the current value:
      0%   : Color3.fromRGB(80, 140, 200)  (cool blue)
      50%  : Color3.fromRGB(120, 200, 255)  (bright cyan)
      100% : Color3.fromRGB(160, 255, 220)  (teal-green)
    Implementation: interpolate fill.BackgroundColor3 per-frame via Lerp
    based on the slider's relative value.

  VALUE LABEL POP (floating above handle):
    Spawn a TextLabel above the handle on grab:
      Size           : UDim2.fromOffset(44, 22)
      AnchorPoint    : Vector2.new(0.5, 1)
      Position       : UDim2.new(fillPercent, 0, -0.6, 0)
      BackgroundColor: Color3.fromRGB(40, 42, 65)
      BackgroundTransparency: 0
      CornerRadius   : UDim.new(0, 6)
      Font           : GothamBold
      TextSize       : 13
      TextColor3     : Color3.new(1, 1, 1)
      Text           : percentage string, e.g. "72%"
      ZIndex         : bar.ZIndex + 5

    Entrance (on grab):
      UIScale: 0 → 1 over 0.12s (Back Out)
      Position Y offset: -0.3 → -0.6 over 0.12s (slides upward)

    While dragging:
      Position X tracks handle in real-time.
      Text updates to current percentage.

    Exit (on release):
      UIScale: 1 → 0 over 0.10s (Quad In)
      Destroy after 0.12s.

  TRACK TICK MARKS (optional visual):
    At 0%, 50%, 100% positions, thin 1px vertical lines inside bar:
      Color          : Color3.fromRGB(80, 80, 110)
      Transparency   : 0.6
      Height         : 60% of bar height
    These give the slider visual anchoring without cluttering.
]]


--[[
================================================================================
  3. PANEL OPEN / CLOSE — Direction + Easing + Backdrop Fade
================================================================================
  Enhance the existing right-side slide with a subtle scale layer and
  a backdrop blur/darken effect.

  OPEN ANIMATION:
    Phase A — Backdrop (0–0.15s):
      Spawn a dim overlay Frame (full-screen):
        BackgroundColor3      : Color3.fromRGB(0, 0, 0)
        BackgroundTransparency: 1 → 0.45 over 0.15s (Quad Out)
        ZIndex                : root.ZIndex - 1

    Phase B — Panel Slide-In (0–0.32s):
      Start position : UDim2.new(1.12, 0, 0.5, 0)  (off right edge)
      End position   : UDim2.new(0.5, 0, 0.5, 0)    (centered)
      TweenInfo      : 0.32s, Back, Out
        Back easing adds a subtle overshoot — the panel slides
        past center by ~3% then settles back. Feels snappy.

    Phase C — Panel Scale (concurrent with slide):
      UIScale on root: 0.92 → 1.0 over 0.28s (Quad Out)
        The panel slightly grows as it enters, giving depth.

    Phase D — Content Stagger (0.12s–0.32s):
      Each row inside the scroll fades in with a stagger:
        Per-row delay  : 0.025s
        Per-row tween  : BackgroundTransparency 1→0 + Position Y offset
                         12px down → 0 over 0.18s (Quad Out)
      This gives a cascading "items loading in" feel on first open.
      Only triggers once per session (first open). Subsequent opens
      skip the content stagger for snappiness.

  CLOSE ANIMATION:
    Phase A — Panel Slide-Out (0–0.26s):
      End position   : UDim2.new(1.12, 0, 0.5, 0)
      TweenInfo      : 0.26s, Quad, In
        Quad In makes the exit accelerate — the panel "swoops" away.

    Phase B — Panel Scale (concurrent):
      UIScale: 1.0 → 0.95 over 0.22s (Quad In)
        Panel slightly shrinks as it leaves.

    Phase C — Backdrop Fade (0.10s–0.28s):
      BackgroundTransparency: 0.45 → 1 over 0.18s (Quad Out)
      Destroy backdrop Frame at 0.30s.

    Phase D — Cleanup (0.27s):
      root.Position = openPos (reset for next open)
      root.Visible = false

  SOUND CUES:
    Open:  "panel_open"  — soft whoosh + subtle high click, ~0.2s
    Close: "panel_close" — reverse whoosh, slightly faster, ~0.15s
]]


--[[
================================================================================
  4. SECTION DIVIDERS — Subtle Line Draw on First Visit
================================================================================
  Add thin horizontal dividers between logical sections (Audio, Graphics,
  Controls, Social). These draw on first open and stay static after.

  DIVIDER FRAME:
    Size           : UDim2.new(0.85, 0, 0, 1)
    AnchorPoint    : Vector2.new(0.5, 0)
    BackgroundColor: Color3.fromRGB(70, 72, 100)
    BackgroundTransparency: 0.4
    LayoutOrder    : between section groups

  FIRST-VISIT DRAW ANIMATION:
    On first panel open, each divider animates its width from 0 to full:
      Size.X.Scale : 0 → 0.85 over 0.35s (Quad Out)
      Stagger      : 0.08s between dividers (top-to-bottom)
      Transparency : 0.8 → 0.4 over 0.35s (fades in as it draws)

    A UIGradient sweeps along the divider during the draw:
      Color        : ColorSequence.new({
                       ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 130, 180)),
                       ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 72, 100)),
                       ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 72, 100)),
                     })
      Offset       : animate X from -1 → 0 during the draw (tracks leading edge)
      After draw: remove UIGradient, divider stays at uniform color.

  SUBSEQUENT OPENS:
    Dividers are at full width with no animation. Only first-visit gets
    the draw effect.

  SECTION GROUPS (suggested placement):
    Divider 1: after "Game sound" toggle       (Audio section boundary)
    Divider 2: after "SFX volume" slider       (end of Audio section)
    Divider 3: after "Particles & VFX" toggle  (end of Graphics section)
    Divider 4: after "Auto-center camera"      (end of Controls section)
]]


--[[
================================================================================
  5. SECTION HEADER LABELS (suggested addition)
================================================================================
  Small colored header labels above each section group to organize the
  settings visually. Not animated, just static polish.

  Style:
    Font           : GothamBold
    TextSize       : 11
    TextColor3     : Color3.fromRGB(100, 110, 160)
    TextXAlignment : Left
    BackgroundTransparency: 1
    Size           : UDim2.new(1, -20, 0, 18)

  Labels:
    "AUDIO"     — above Game sound toggle
    "VISUALS"   — above Graphics slider
    "CONTROLS"  — above Steering sensitivity
    "SOCIAL"    — above Show other players' pets
]]


--[[
================================================================================
  TIMING CHOREOGRAPHY — FULL SETTINGS OPEN SEQUENCE
================================================================================

  t=0.00s   "panel_open" sound
  t=0.00s   Backdrop dim starts (0→0.45 over 0.15s)
  t=0.00s   Panel slide-in begins (0.32s, Back Out from right)
  t=0.00s   Panel UIScale 0.92→1.0 (0.28s)
  t=0.12s   First row content stagger begins (first-visit only)
  t=0.12s   First section divider draw begins
  t=0.14s   Row 2 fades in...
  t=0.16s   Row 3...
  t=0.20s   Second divider draw begins
  t=0.28s   Third divider draw begins
  t=0.32s   Panel settles at center
  t=0.36s   Fourth divider draw begins
  t=0.45s   Last row fades in
  t=0.50s   All entrance animations complete. Panel fully interactive.

  Total entrance: ~0.50s on first visit, ~0.32s on subsequent opens.
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig:

  panel_open   — soft whoosh + subtle high click (~0.2s)
  panel_close  — reverse whoosh, faster (~0.15s)
  click        — already exists, reused for toggle taps
================================================================================
]]

return nil
