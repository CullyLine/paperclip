import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMWM5NmRlYTctNzE3NC00MmUxLWIwOTUtNTk0MjYyZjY5NGMwIiwiaWF0IjoxNzc0MTA3Njc3LCJleHAiOjE3NzQyODA0NzcsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.Hw5XQW9PMBepbsWusIq2dS8WxS12WC7rfTFuRZQINmA"
RUN_ID = "1c96dea7-7174-42e1-b095-594262f694c0"
CID = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"

ENGINEER_ID = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD_ID = "b74e54ba-559a-49d9-933b-2978b1157f01"
CS_ID = "0b51d97d-f321-4cb9-830c-892ec863fdf4"

def create_issue(title, desc, assignee, priority="high"):
    body = json.dumps({
        "title": title,
        "description": desc,
        "assigneeAgentId": assignee,
        "parentId": PARENT_ID,
        "projectId": PROJECT_ID,
        "status": "todo",
        "priority": priority
    }).encode()
    req = urllib.request.Request(
        API + "/api/companies/" + CID + "/issues",
        data=body, method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + TOKEN,
            "X-Paperclip-Run-Id": RUN_ID
        }
    )
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print("Created:", resp.get("identifier", "?"), resp.get("title", "?"))
    return resp


# === TASK 1: Engineer - Wire Dead VFXFacade Methods ===
t1_desc = """## Context
Comprehensive audit found **11 VFXFacade methods** that are fully defined in VFXController.luau but NEVER called from any game code. These represent the single biggest dopamine gap in the game.

## Requirements

Wire each VFXFacade method into its natural call site:

### DrivingController.luau / DrivingHUD.luau
1. **boostOverlay(isActive)** - Call when boost is active (game pass boost, pet boost, any speed multiplier). Toggle on/off each frame based on boost state.
2. **speedRushOverlay(speed)** - Call every render frame when player speed exceeds 70% of their max speed. Edge-of-screen speed lines / chromatic aberration.
3. **lapFlash(isPersonalBest)** - Call when state.laps increments. Pass true if this lap time beats their best.
4. **nearMissSpark(fromRight)** - Call when player passes within close range of obstacle/wall without colliding. Needs proximity detection in driving loop.
5. **firstRunEntrance()** - Call once when the first drive of a session starts (flag to ensure once-per-session).

### WorldPanel.luau / World transition code
6. **worldTransition(from, to)** - Call when player teleports between worlds.

### Main ambient system
7. **ambientStart()** - Call when a drive begins (player enters car / run starts).
8. **ambientStop()** - Call when a drive ends (player exits car / run ends).

### LeaderboardPanel.luau
9. **leaderboardRankFanfare(payload)** - Call from the RankUpNotification handler. Also add fade-in/fade-out tween to rank-up toast TextTransparency.

### StorePanel.luau
10. **carUnlockCelebration(carId, name)** - Call when a car is purchased (in addition to existing purchaseCelebration).

### StorePanel.luau / stat upgrade handler
11. **statLevelUp(stat, old, new)** - Call when a stat upgrade is purchased. Per-stat level-up cascade.

## Acceptance Criteria
- All 11 methods called from real game code at natural trigger points
- No crashes on nil/missing arguments
- Each call site guarded to only fire at appropriate moment
- nearMissSpark requires basic proximity detection (raycast or distance check)

## Files to modify
- DACStarterPlayerScripts/Controllers/DrivingController.luau
- DACStarterGui/DrivingHUD.luau
- DACStarterGui/LeaderboardPanel.luau
- DACStarterGui/StorePanel.luau
- DACStarterGui/WorldPanel.luau
- DACStarterPlayerScripts/Controllers/VFXController.luau (if needed for ambient wiring)"""

t1 = create_issue(
    "Engineer: Wire Dead VFXFacade Methods into Natural Call Sites (11 stubs)",
    t1_desc, ENGINEER_ID, "high"
)
print("---")


# === TASK 2: Engineer - Egg anticipation + leaderboard toast + loading SFX ===
t2_desc = """## Context
Three smaller but high-impact dopamine gaps found in audit.

## Requirements

### 1. Egg Hatch Anticipation (EggShopPanel.luau)
Currently when user clicks hatch, nothing happens visually until server responds. Add:
- On hatch button click, immediately start a 0.5-1.0 second anticipation animation on the egg icon/button:
  - Wobble the egg icon left-right (small rotation tween, -5 to +5 degrees, 3 cycles)
  - Add a growing glow stroke around the egg
  - Play egg_crack_small SFX at 0.3s
- THEN show the actual hatch reveal when server responds
- If server is slow (>1.5s), keep wobbling until response arrives

### 2. Leaderboard Rank-Up Toast Tween (LeaderboardPanel.luau)
The rank-up notification toast currently appears instantly and disappears after 3.2s with no animation:
- Add fade-in tween: TextTransparency from 1 to 0 over 0.3s with Quad.Out
- Add scale-in tween: Size from 80% to 100% with elastic ease
- Add fade-out tween starting at 2.5s: TextTransparency from 0 to 1 over 0.7s
- Keep the existing 3.2s total duration

### 3. Loading Screen Ambient SFX (LoadingScreen.local.luau)
The loading screen has great visuals but zero audio:
- Play a soft ambient music bed or tone on load start (create a local Sound instance since SoundFacade may not be available in ReplicatedFirst)
- Play a subtle progress chime every 25% completion milestone
- Play a satisfying ready chime/swoosh on load complete (just before fade-out)
- All loading sounds should fade out smoothly with the visual fade-out

## Files to modify
- DACStarterGui/EggShopPanel.luau
- DACStarterGui/LeaderboardPanel.luau
- DACReplicatedFirst/LoadingScreen.local.luau"""

t2 = create_issue(
    "Engineer: Egg Hatch Anticipation Delay + Leaderboard Toast Tween + Loading Screen SFX",
    t2_desc, ENGINEER_ID, "high"
)
print("---")


# === TASK 3: Bard - Speed rush / lap flash / near-miss / ambient design ===
t3_desc = """## Context
Engineer is about to wire 11 dead VFXFacade methods. Bard needs to provide visual design specs for the 4 highest-impact driving VFX so Engineer has a clear visual language to implement.

## Requirements

### 1. Speed Rush Overlay Design Spec
Design the visual treatment for high-speed driving (>70% max speed):
- Edge-of-screen speed lines / vignette darkening intensity curve
- Chromatic aberration / color fringing amount
- Whether the effect ramps linearly or has thresholds (70% = subtle, 90% = intense, 100% = max)
- Color palette (white streaks? blue tint? warm?)
- Screen shake amount at top speed

### 2. Lap Flash Design Spec
Design the screen flash when a lap is completed:
- Regular lap: color, duration, shape (full-screen vs radial burst from center)
- Personal best lap: enhanced version (different color? confetti? time display with glow?)
- SFX recommendation (triumphant chime vs subtle ping)

### 3. Near-Miss Spark Design Spec
Design the near-miss visual reward when player narrowly avoids an obstacle:
- Spark/flash position (edge of screen matching side? around the car?)
- Particle style (electric sparks? gold coins? star burst?)
- Should it show a points popup (e.g. +50 NEAR MISS!)
- Combo system for consecutive near-misses?
- Color: danger red fading to reward gold?

### 4. Ambient World Particles Design Spec
Design per-world ambient particle systems:
- Grass World: floating dandelion seeds, butterflies
- Desert World: sand wisps, heat shimmer
- Snow World: gentle snowflakes, frost sparkles
- Lava World: ember particles, ash
- Space World: star twinkles, cosmic dust
- Each should have a density, speed, color palette, and size range

## Deliverable
Write a design spec file at DACStarterGui/DrivingVFXDesignSpec.luau with a Luau table containing all parameters, color values (Color3), timing curves, and particle configs that Engineer can directly consume."""

t3 = create_issue(
    "Bard: Speed Rush Overlay + Lap Flash + Near-Miss Spark + Ambient World Particles Design Specs",
    t3_desc, BARD_ID, "high"
)
print("---")


# === TASK 4: Content Strategist - Near-miss copy + streak + loading audio brief ===
t4_desc = """## Context
New dopamine features being wired need copy/text content.

## Requirements

### 1. Near-Miss Celebration Copy (10-15 variants)
Short, punchy popup text for when player narrowly avoids an obstacle. Mix of:
- Adrenaline: "CLOSE CALL!", "HAIR'S BREADTH!"
- Reward: "+50 SKILL BONUS!", "REFLEXES!"
- Escalating combo: "NEAR MISS x2!", "UNTOUCHABLE x5!"
- Cocky/fun: "TOO EASY!", "CAN'T TOUCH THIS!"

### 2. Streak Counter Headlines (5-8 variants)
Text that appears when player maintains a long streak of near-misses or consecutive laps without crashing:
- "UNSTOPPABLE!", "ON FIRE!", "LEGENDARY STREAK!"
- Should escalate in intensity with streak length

### 3. Lap Completion Text (5-8 variants)
Short celebration text for lap completion:
- Regular: "LAP COMPLETE!", "ANOTHER ONE!"
- Personal best: "NEW RECORD!", "FASTEST LAP!"
- Humor: "EZ!", "SPEED DEMON!"

### 4. Loading Screen Audio Direction Brief
Write a short creative brief describing:
- The mood/vibe of the loading ambient sound (energetic? chill? mysterious?)
- What the progress milestone chimes should feel like
- What the "ready" sound should convey (excitement, anticipation)
- Reference: the loading screen has gold/shimmer visuals, FOMO headlines, tips rotation

## Deliverable
Write all copy to DACReplicatedStorage/Config/NearMissCopyConfig.luau as a Luau module returning tables of strings. Include the audio brief as a comment block at the top."""

t4 = create_issue(
    "Content Strategist: Near-Miss Celebration Copy + Streak Counter Text + Loading Screen Audio Brief",
    t4_desc, CS_ID, "high"
)

print("\nAll 4 tasks created successfully!")
