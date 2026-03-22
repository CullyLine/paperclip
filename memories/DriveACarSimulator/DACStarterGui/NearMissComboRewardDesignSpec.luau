--!strict
--[[
	NEAR-MISS COMBO REWARD SYSTEM — FULL DESIGN SPEC
	==================================================
	Defines the reward structure, combo counter UI, escalating bonuses, and
	run-end payout integration for near-miss combos during driving runs.

	The DrivingVFXDesignSpec (Section C) defines the VISUAL effects for
	near-misses. This spec defines the GAMEPLAY REWARD loop: how near-miss
	combos translate into tangible in-game rewards that incentivize
	aggressive, skilled driving.

	Reference files:
	  - DACStarterGui/DrivingVFXDesignSpec.luau (Section C — near-miss VFX)
	  - DACReplicatedStorage/Config/NearMissCopyConfig.luau (popup text)
	  - DACStarterPlayerScripts/Controllers/DrivingController.luau (run state)
	  - DACStarterPlayerScripts/Controllers/VFXController.luau (VFX triggers)
	  - DACStarterGui/DrivingHUD.luau (speed display, HUD elements)
	  - DACStarterGui/PayoutPanel.luau (run-end results)
	  - DACReplicatedStorage/RunResultsBridge.luau (run data passing)

	Design philosophy:
	  Near-misses are the #1 underutilized dopamine moment in driving games.
	  Most games punish near-misses with anxiety. We REWARD them. The player
	  should actively seek close calls because each one:
	    1. Feels amazing (VFX + sound — covered by DrivingVFXDesignSpec)
	    2. Gives immediate coin/XP rewards (this spec)
	    3. Builds a combo that multiplies those rewards
	    4. Shows up as a highlight in the run-end payout screen
	  This creates a risk-reward loop: drive closer to obstacles for higher
	  rewards, but crash and lose it all. Pure skill expression.
]]


--[[
================================================================================
  SECTION A — NEAR-MISS DETECTION + COMBO STATE
================================================================================
  DrivingController already detects near-misses via proximity raycasting.
  This spec defines the combo state machine that sits on top of detection.

  State variables (maintained in DrivingController during a run):
    nearMissCombo      : number = 0     -- current combo chain
    nearMissComboTimer : number = 0     -- seconds since last near-miss
    nearMissTotalRun   : number = 0     -- total near-misses this run
    nearMissBestCombo  : number = 0     -- best combo this run
    nearMissCoinsEarned: number = 0     -- total near-miss coins this run
    nearMissXpEarned   : number = 0     -- total near-miss XP this run

  COMBO RULES:
    Window             : 4.0 seconds between consecutive near-misses
    Reset triggers     : crash, run end, or timer expiry
    No upper cap       : combo can grow indefinitely (skill ceiling)

  Per-frame update (during run):
    nearMissComboTimer -= dt
    if nearMissComboTimer <= 0 and nearMissCombo > 0 then
      -- Combo expired: flash "COMBO ENDED" text, store bestCombo
      nearMissBestCombo = math.max(nearMissBestCombo, nearMissCombo)
      nearMissCombo = 0
      hideComboCounter()
    end

  On near-miss detected:
    nearMissCombo += 1
    nearMissTotalRun += 1
    nearMissComboTimer = 4.0
    nearMissBestCombo = math.max(nearMissBestCombo, nearMissCombo)
    local reward = calculateReward(nearMissCombo)
    nearMissCoinsEarned += reward.coins
    nearMissXpEarned += reward.xp
    showComboCounter(nearMissCombo)
    showRewardPopup(reward)
    VFXFacade.nearMissSpark(fromRight)

  On crash:
    if nearMissCombo > 0 then
      nearMissBestCombo = math.max(nearMissBestCombo, nearMissCombo)
      nearMissCombo = 0
      flashComboLost()
      hideComboCounter()
    end

  On run end:
    Package near-miss stats into RunResultsBridge for payout display:
      results.nearMissTotalCount = nearMissTotalRun
      results.nearMissBestCombo  = nearMissBestCombo
      results.nearMissCoins      = nearMissCoinsEarned
      results.nearMissXp         = nearMissXpEarned
================================================================================
]]


--[[
================================================================================
  SECTION B — REWARD STRUCTURE
================================================================================
  Each near-miss awards instant coins and XP. The combo multiplier
  escalates rewards for chained dodges.

  BASE REWARDS (combo = 1, single near-miss):
    Coins              : 15
    XP                 : 5

  COMBO MULTIPLIER TABLE:
    | Combo | Multiplier | Effective Coins | Effective XP | Tier Name        |
    |-------|------------|-----------------|--------------|------------------|
    | 1     | 1.0x       | 15              | 5            | —                |
    | 2     | 1.5x       | 22              | 7            | —                |
    | 3     | 2.0x       | 30              | 10           | COMBO!           |
    | 4     | 2.5x       | 37              | 12           | COMBO!           |
    | 5     | 3.0x       | 45              | 15           | ON FIRE!         |
    | 6     | 3.5x       | 52              | 17           | ON FIRE!         |
    | 7     | 4.0x       | 60              | 20           | ON FIRE!         |
    | 8     | 4.5x       | 67              | 22           | UNSTOPPABLE!     |
    | 9     | 5.0x       | 75              | 25           | UNSTOPPABLE!     |
    | 10    | 6.0x       | 90              | 30           | GOD MODE!        |
    | 15    | 8.0x       | 120             | 40           | LEGENDARY!       |
    | 20    | 10.0x      | 150             | 50           | PERFECTION!      |
    | 25+   | 12.0x      | 180             | 60           | TRANSCENDENT!    |

  Formula:
    function calculateMultiplier(combo: number): number
      if combo <= 1 then return 1.0 end
      if combo <= 2 then return 1.5 end
      if combo <= 4 then return 0.5 * combo + 0.5 end  -- 2.0, 2.5
      if combo <= 9 then return 0.5 * combo + 0.5 end  -- 3.0 → 5.0
      if combo <= 14 then return combo - 4 end          -- 6.0 → 10.0 (approx)
      if combo <= 19 then return 8.0 end
      if combo <= 24 then return 10.0 end
      return 12.0
    end

  Simplified implementation:
    function calculateMultiplier(combo: number): number
      if combo <= 1 then return 1.0 end
      if combo >= 25 then return 12.0 end
      return math.min(12.0, 1.0 + (combo - 1) * 0.5 + math.max(0, combo - 10) * 0.5)
    end

  function calculateReward(combo: number): { coins: number, xp: number }
    local mul = calculateMultiplier(combo)
    return {
      coins = math.floor(15 * mul),
      xp = math.floor(5 * mul),
    }
  end

  SERVER VALIDATION:
    Near-miss rewards are calculated client-side for instant feedback,
    then validated server-side at run end. The server receives the raw
    near-miss count and best combo, recalculates total rewards, and
    caps at the expected maximum. This prevents client-side manipulation.

    Server cap formula:
      maxCoins = nearMissTotalCount * 15 * calculateMultiplier(nearMissBestCombo)
      Actual coins awarded = min(clientReportedCoins, maxCoins)
================================================================================
]]


--[[
================================================================================
  SECTION C — COMBO COUNTER HUD
================================================================================
  A persistent HUD element that appears during active combos and shows
  the current chain count, tier name, and accumulated rewards.

  Positioned below the speedometer, above the gas bar — in the player's
  natural gaze path during driving.

  VISIBILITY RULES:
    Appear when: nearMissCombo >= 2 (single near-misses show popup only)
    Disappear when: combo resets (timer expiry or crash)
    Always hidden outside of driving runs.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  COMBO COUNTER — LAYOUT
────────────────────────────────────────────────────────────────────────────────

  Root Frame:
    Name               : "NearMissComboCounter"
    Size               : UDim2.new(0, 180, 0, 56)
    Position           : UDim2.new(0.5, 0, 0, 140)
    AnchorPoint        : Vector2.new(0.5, 0)
    BackgroundColor3   : Color3.fromRGB(15, 8, 25)
    BackgroundTransparency: 0.15
    ZIndex             : 25
    Visible            : false

  UICorner             : UDim.new(0, 10)

  UIStroke:
    Thickness          : 1.5
    Color              : combo tier color (see below)
    Transparency       : 0.1

  UIGradient (horizontal, dark edges):
    Color              : ColorSequence.new({
                           ColorSequenceKeypoint.new(0,   comboColor:Lerp(Color3.new(0,0,0), 0.8)),
                           ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 8, 25)),
                           ColorSequenceKeypoint.new(1,   comboColor:Lerp(Color3.new(0,0,0), 0.8)),
                         })

  ── Combo Count (left, large) ──
    Name               : "ComboCount"
    Type               : TextLabel
    Text               : "×" .. tostring(nearMissCombo)
    Font               : GothamBlack
    TextSize           : 26
    TextColor3         : combo tier color
    TextStrokeColor3   : combo tier color:Lerp(Color3.new(0,0,0), 0.6)
    TextStrokeTransparency: 0.4
    Position           : UDim2.new(0, 10, 0.5, 0)
    AnchorPoint        : Vector2.new(0, 0.5)
    Size               : UDim2.fromOffset(50, 36)
    BackgroundTransparency: 1
    ZIndex             : 27

  ── Tier Name (right of count) ──
    Name               : "TierLabel"
    Type               : TextLabel
    Text               : tier name from table (e.g. "ON FIRE!")
    Font               : GothamBlack
    TextSize           : 14
    TextColor3         : Color3.new(1, 1, 1)
    Position           : UDim2.new(0, 62, 0, 6)
    Size               : UDim2.new(1, -70, 0, 18)
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 27

  ── Coins Earned (below tier name, small) ──
    Name               : "CoinsLabel"
    Type               : TextLabel
    Text               : `+{totalCoinsThisCombo} coins`
    Font               : GothamBold
    TextSize           : 11
    TextColor3         : Color3.fromRGB(255, 215, 60)
    Position           : UDim2.new(0, 62, 0, 26)
    Size               : UDim2.new(1, -70, 0, 14)
    TextXAlignment     : Left
    BackgroundTransparency: 1
    ZIndex             : 27

  ── Timer Bar (bottom edge, shows combo window remaining) ──
    Name               : "TimerBar"
    Frame background   : Color3.fromRGB(40, 25, 60)
    Position           : UDim2.new(0, 4, 1, -6)
    Size               : UDim2.new(1, -8, 0, 3)
    UICorner           : UDim.new(0.5, 0)
    ZIndex             : 26

    Fill Frame:
      BackgroundColor3 : combo tier color
      Size             : UDim2.new(nearMissComboTimer / 4.0, 0, 1, 0)
      Updated per frame (smooth drain)

    When timer < 1.0s:
      Fill blinks: BackgroundTransparency oscillates 0 ↔ 0.5 at 4 Hz
      Urgency signal: "hurry, dodge something!"

  COMBO TIER COLORS:
    combo 2–4   : Color3.fromRGB(255, 200,  80)  — gold (warm, encouraging)
    combo 5–7   : Color3.fromRGB(255, 140,  40)  — orange (heating up)
    combo 8–9   : Color3.fromRGB(255,  80,  60)  — red-orange (dangerous)
    combo 10–14 : Color3.fromRGB(255,  50,  80)  — hot pink (on fire)
    combo 15–19 : Color3.fromRGB(200,  80, 255)  — purple (legendary)
    combo 20–24 : Color3.fromRGB(100, 180, 255)  — electric blue (transcendent)
    combo 25+   : animated rainbow — Color3.fromHSV((os.clock() * 0.5) % 1, 0.9, 1)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  COMBO COUNTER — ANIMATIONS
────────────────────────────────────────────────────────────────────────────────

  ENTRANCE (combo reaches 2):
    Root Frame:
      UIScale: 0 → 1.15 over 0.2s (Back Out)
      then 1.15 → 1.0 over 0.1s (Quad Out)
      BackgroundTransparency: 0.8 → 0.15 over 0.15s

  ON EACH NEW NEAR-MISS (combo increments):
    ComboCount text updates
    ComboCount UIScale punch: 1.0 → 1.3 instantly, then → 1.0 over 0.15s (Back Out)
    CoinsLabel text updates with new running total
    Timer bar resets to full (smooth tween to 1.0 width over 0.1s)
    UIStroke color transitions to new tier color if tier changed

    Tier change (combo crosses tier boundary):
      Entire root Frame: brief flash BackgroundColor3 → tier color → original
        Duration: 0.15s flash, 0.2s fade back
      ComboCount TextColor3 transitions to new tier color over 0.1s
      2 sparkle dots emit from counter edges (tier color, 0.2s lifetime)
      Sound: "combo_tier_up" — ascending chime, pitch based on tier

  COMBO TIMER DRAIN:
    Timer bar fill width = nearMissComboTimer / 4.0
    Smooth per-frame interpolation (no TweenService — direct set)
    Color shifts from tier color → red as timer approaches 0:
      fill.BackgroundColor3 = tierColor:Lerp(Color3.fromRGB(200, 40, 40),
        1 - (nearMissComboTimer / 4.0))

  COMBO ENDED (timer expired):
    Flash: root BackgroundColor3 → red briefly (0.1s)
    ComboCount text: current number → "×0" with red color
    UIScale: 1.0 → 0.85 over 0.2s (Quad In)
    BackgroundTransparency: 0.15 → 0.8 over 0.2s
    Destroy/hide after 0.25s
    Text popup above counter: "COMBO ENDED" in muted gray, 0.8s

  COMBO LOST (crash):
    More dramatic than timer expiry — the player lost something:
    Flash: root BackgroundColor3 → bright red (0.05s snap)
    cameraShake(0.06, 0.1s)
    ComboCount text: briefly shows "LOST!" in red
    UIScale: 1.0 → 0.7 over 0.15s (Quad In)
    Destroy after 0.2s
    Text popup: random from ["COMBO LOST!", "OUCH!", "SO CLOSE!"]
      Color: Color3.fromRGB(255, 80, 80)
      Duration: 1.0s
]]


--[[
================================================================================
  SECTION D — PER-NEAR-MISS REWARD POPUP
================================================================================
  Each individual near-miss shows a floating reward number. This is
  separate from the combo counter — it's the instant "+coins" feedback.

  Position: slightly above the car, drifting upward and fading.
  This is a 3D-projected HUD element (BillboardGui or screen-space offset).
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  REWARD POPUP — LAYOUT + ANIMATION
────────────────────────────────────────────────────────────────────────────────

  Root Frame (screen-space, positioned near speedometer):
    Spawn position     : UDim2.new(0.5, randomOffset(-30,30), 0, 120)
    AnchorPoint        : Vector2.new(0.5, 1)
    BackgroundTransparency: 1
    ZIndex             : 28

  ── Coin Amount ──
    Type               : TextLabel
    Text               : `+{coins}`
    Font               : GothamBlack
    TextSize           : 20 + math.min(8, combo * 0.5)  (grows with combo)
    TextColor3         : reward gold — Color3.fromRGB(255, 215, 60)
    TextStrokeColor3   : Color3.fromRGB(180, 120, 0)
    TextStrokeTransparency: 0.4
    BackgroundTransparency: 1

    At combo >= 5, text becomes:
      `+{coins} (×{multiplier})`
      with multiplier portion in Color3.fromRGB(255, 140, 40)

    At combo >= 10:
      TextColor3 shifts to combo tier color
      TextSize += 4 (emphasize the escalation)

  ── Coin Icon (small, left of amount) ──
    Text               : "🪙"
    TextSize           : 14
    Position           : left of coin amount, centered vertically

  Animation:
    t=0.00s  Spawn at base position
    t=0.00s  UIScale: 0.5 → 1.2 over 0.08s (Back Out) — punchy pop-in
    t=0.08s  UIScale: 1.2 → 1.0 over 0.1s (Quad Out)
    t=0.00s  Begin float: Position Y drifts -40px over 0.6s (Quad Out)
    t=0.35s  TextTransparency: 0 → 1 over 0.25s
    t=0.60s  Destroy

  At combo >= 10, enhanced:
    Pop-in scale peak: 1.4 instead of 1.2
    Float distance: -55px instead of -40
    Duration: 0.8s instead of 0.6s
    2 gold sparkle dot Frames emit outward from text, 0.2s lifetime

  Sound: none for the popup itself (the near-miss VFX chime covers audio).
  Avoids double-dinging which would feel noisy during rapid combos.
]]


--[[
================================================================================
  SECTION E — RUN-END PAYOUT INTEGRATION
================================================================================
  Near-miss performance is displayed as a dedicated section in the payout
  panel at run end. This validates the player's skill and shows them exactly
  how much their aggressive driving earned.
================================================================================
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PAYOUT PANEL — NEAR-MISS SECTION
────────────────────────────────────────────────────────────────────────────────

  Positioned below the existing stat counters, above the XP bar.
  Only shown if nearMissTotalCount > 0.

  Section Header:
    Text               : "Near-Miss Bonus"
    Font               : GothamBold
    TextSize           : 14
    TextColor3         : Color3.fromRGB(255, 200, 80)

  ── Stat Row: Total Near-Misses ──
    Label              : "Near-Misses"
    Value              : tostring(nearMissTotalCount)
    Icon               : "⚡"

  ── Stat Row: Best Combo ──
    Label              : "Best Combo"
    Value              : `×{nearMissBestCombo}`
    Icon               : "🔥"
    Special treatment if bestCombo >= 10:
      Value TextColor3 : combo tier color for that level
      Value UIScale pulse: 1.0 ↔ 1.08, 1.5 Hz

  ── Stat Row: Bonus Coins ──
    Label              : "Combo Coins"
    Value              : `+{nearMissCoins}`
    Icon               : "🪙"
    TextColor3         : Color3.fromRGB(255, 215, 60)

  ── Stat Row: Bonus XP ──
    Label              : "Combo XP"
    Value              : `+{nearMissXp}`
    Icon               : "✨"
    TextColor3         : Color3.fromRGB(180, 140, 255)

  Row template (same as existing payout stat rows):
    Size               : UDim2.new(1, -16, 0, 22)
    BackgroundTransparency: 1
    Font               : Gotham (label), GothamBold (value)
    TextSize           : 13

  ENTRANCE ANIMATION:
    The near-miss section appears AFTER the main stat counter roll-up
    (at approximately t=1.6s in the payout choreography).

    Section header slides in from right:
      Position X offset: 40px → 0 over 0.25s (Quad Out)
      TextTransparency : 1 → 0 over 0.2s

    Stat rows cascade with 0.1s stagger:
      Each row slides from right (30px offset) and fades in over 0.2s

    Value counter roll-up:
      Coins and XP values count from 0 → final over 0.5s (smoothstep)
      Gold flash on value text during counting (same as main stat enhancement)

  BEST COMBO CELEBRATION (bestCombo >= 5):
    After all rows have entered, if bestCombo >= 5:
      Brief gold sparkle burst (6 dots) around the Best Combo value
      ComboCount text briefly scales 1.0 → 1.15 → 1.0 (0.2s)

  BEST COMBO >= 10 — "COMBO MASTER" BADGE:
    A special badge appears next to the Best Combo stat:
      Frame              : UDim2.fromOffset(88, 18)
      BackgroundColor3   : combo tier color for bestCombo level
      UICorner           : UDim.new(0, 6)
      Label              : tier name (e.g. "GOD MODE!")
      Font               : GothamBlack
      TextSize           : 9
      TextColor3         : Color3.new(1, 1, 1)

    Entrance: UIScale 0 → 1.1 over 0.15s (Back Out), settle to 1.0

  BEST COMBO >= 20 — "NEAR-MISS LEGEND" TITLE:
    An additional celebratory text appears below the section:
      Text               : "🏆 NEAR-MISS LEGEND — " .. random from:
                            ["You dodged EVERYTHING!",
                             "Untouchable driving!",
                             "Are you even human?!",
                             "Reflexes of a god!",
                             "The obstacles feared YOU!"]
      Font               : GothamBold
      TextSize           : 11
      TextColor3         : rainbow animated (hue cycle, 0.4 Hz)
      Entrance           : fade in at t=2.0s, UIScale 0.8 → 1.0 (Back Out)
]]


--[[
────────────────────────────────────────────────────────────────────────────────
  PAYOUT MULTIPLIER BADGE — NEAR-MISS CONTRIBUTION
────────────────────────────────────────────────────────────────────────────────
  If nearMissCoins > 0, add a multiplier badge to the existing badge
  cascade in the payout panel (alongside the existing pet/VIP/rebirth badges).

  Badge properties:
    Text               : `+{nearMissCoins} Near-Miss`
    BackgroundColor3   : Color3.fromRGB(255, 180, 40)
    UICorner           : UDim.new(0, 6)
    TextSize           : 11
    TextColor3         : Color3.fromRGB(30, 20, 10)
    Icon (left)        : "⚡"

  Entrance: follows the same staggered badge cascade timing as existing
  multiplier badges (0.12s stagger, Back Out scale pop).

  This ensures near-miss rewards are visible alongside other multipliers,
  reinforcing that aggressive driving = more rewards.
]]


--[[
================================================================================
  SECTION F — NEAR-MISS COPY INTEGRATION
================================================================================
  The combo system uses NearMissCopyConfig text pools at different combo
  thresholds. This maps combo levels to text categories.

  | Combo Level | Text Source                          | Context              |
  |-------------|--------------------------------------|----------------------|
  | 1           | NearMissCopyConfig.NearMiss           | Single dodge popup   |
  | 2           | NearMissCopyConfig.NearMiss           | Still warming up     |
  | 3–4         | "NEAR MISS ×{n}!" (generated)         | Combo building       |
  | 5–7         | NearMissCopyConfig.StreakHeadlines     | Tier: ON FIRE        |
  | 8–9         | NearMissCopyConfig.StreakHeadlines     | Tier: UNSTOPPABLE    |
  | 10–14       | "GOD MODE!" (static)                  | Tier: GOD MODE       |
  | 15–19       | "LEGENDARY STREAK!" or "CAN'T BE STOPPED!" | Tier: LEGENDARY |
  | 20–24       | "PERFECTION!" (static)                | Tier: PERFECTION     |
  | 25+         | "TRANSCENDENT!" (static)              | Tier: TRANSCENDENT   |

  The tier name also maps to the combo counter's TierLabel text.

  function getComboTierInfo(combo: number): { name: string, color: Color3 }
    if combo >= 25 then
      return { name = "TRANSCENDENT!", color = rainbow }
    elseif combo >= 20 then
      return { name = "PERFECTION!", color = Color3.fromRGB(100, 180, 255) }
    elseif combo >= 15 then
      return { name = "LEGENDARY!", color = Color3.fromRGB(200, 80, 255) }
    elseif combo >= 10 then
      return { name = "GOD MODE!", color = Color3.fromRGB(255, 50, 80) }
    elseif combo >= 8 then
      return { name = "UNSTOPPABLE!", color = Color3.fromRGB(255, 80, 60) }
    elseif combo >= 5 then
      return { name = "ON FIRE!", color = Color3.fromRGB(255, 140, 40) }
    elseif combo >= 3 then
      return { name = "COMBO!", color = Color3.fromRGB(255, 200, 80) }
    end
    return { name = "", color = Color3.fromRGB(255, 200, 80) }
  end
================================================================================
]]


--[[
================================================================================
  SECTION G — SERVER-SIDE VALIDATION + REWARDS APPLICATION
================================================================================
  Near-miss rewards are applied at run end, not during the run. This
  prevents exploits where a player could artificially trigger near-misses.

  CLIENT FLOW:
    1. During run: track combo state, show instant popups (cosmetic only)
    2. On run end: package stats into RunResultsBridge
    3. Server processes run results and validates near-miss claims

  SERVER FLOW (RunService / CarService):
    1. Receive run results with nearMiss data
    2. Validate:
       - nearMissTotalCount <= maxPossibleForRunDuration
         (cap: 1 near-miss per 0.8 seconds of run time)
       - nearMissBestCombo <= nearMissTotalCount
       - Recalculate coins/XP using official formulas
       - Use MIN(clientReported, serverCalculated) for safety
    3. Apply rewards:
       - Add nearMissCoins to player's coin balance
       - Add nearMissXp to player's XP
    4. Include in DataUpdate broadcast so PayoutPanel can display

  ANTI-CHEAT MEASURES:
    - Max near-miss rate: 1 per 0.8s (minimum physical dodge time)
    - Max combo: capped at nearMissTotalCount
    - Reward cap per run: 5000 coins, 1500 XP (prevents absurd exploits)
    - Server recalculates all rewards from raw counts (never trusts client sums)
    - Anomaly flag: if nearMissTotalCount / runDuration > 0.8, log for review
================================================================================
]]


--[[
================================================================================
  SECTION H — NEAR-MISS LEADERBOARD INTEGRATION
================================================================================
  Optional enhancement: near-miss combos contribute to a "Skill Score"
  leaderboard category, separate from the speed/distance leaderboards.

  Skill Score formula:
    skillScore = (nearMissBestCombo * 100) + (nearMissTotalCount * 10)

  This gives players who excel at near-misses their own competitive
  dimension, encouraging a different playstyle from pure speed chasers.

  LeaderboardService integration:
    Add "skillScore" to the leaderboard categories alongside
    "topSpeed", "totalDistance", "totalRebirths".

  Leaderboard display text (LeaderboardTextConfig):
    Header: "SKILL SCORE"
    Subtitle: "Best combo × 100 + total dodges × 10"

  This is optional and can be deferred to a future update.
================================================================================
]]


--[[
================================================================================
  SOUND CUE REFERENCE
================================================================================
  New sound IDs for SoundConfig / SoundController:

  combo_tier_up              — ascending chime, pitch varies by tier (~0.2s)
                                Pitch: 1.0 (COMBO) → 1.5 (TRANSCENDENT)

  Existing sounds reused (from DrivingVFXDesignSpec):
    near_miss_chime          — reward ping on each near-miss (0.15s)
    combo_ding               — ascending ding per combo level (0.1s)
    screech / rebirth_whoosh — danger moment (existing)

  No new sounds for:
    - Combo counter HUD (visual-only to avoid clutter during driving)
    - Reward popup (near_miss_chime covers audio)
    - Payout panel section (main payout sounds suffice)
================================================================================
]]


--[[
================================================================================
  PERFORMANCE & MOBILE
================================================================================

  Performance:
    - Combo counter: 1 RenderStepped connection (timer bar drain + color lerp)
    - Reward popups: max 3 alive simultaneously (older ones fast-fade if exceeded)
    - Sparkle dots: max 4 per near-miss event (one-shot, 0.2s lifetime)
    - Payout section: static after entrance animation completes (no per-frame cost)
    - No ParticleEmitters — all effects are Frame property animations

  Mobile:
    - Combo counter width: math.min(180, viewportWidth * 0.4)
    - Reward popup TextSize: scale by 0.8 on viewports < 600px
    - Timer bar: increase height to 4px on mobile for visibility
    - All tap targets: minimum 44px (dismiss areas in payout panel)

  LOD gating:
    - LOD 1: combo counter + text popups only (no sparkles, no screen effects)
    - LOD 2: + sparkle dots on tier change, reward popup scale punch
    - LOD 3: full effects (all sparkles, enhanced screen flash on high combos)
================================================================================
]]

return nil
