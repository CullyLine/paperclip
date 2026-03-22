import urllib.request, json

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNDM3YWRiOGYtNzYyNC00ZTIwLTkzMmEtZGZjZDAwZGQ2ZDU5IiwiaWF0IjoxNzc0MTAyODE4LCJleHAiOjE3NzQyNzU2MTgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.qY-x1_02iIcKLxtKRL_isPp6abiM60Ry7kZhoGyJTQc'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
RUN_ID = '437adb8f-7624-4e20-932a-dfcd00dd6d59'
ENGINEER = '323fca23-ecfa-4f35-aeb1-77f206eccf34'
CONTENT_STRATEGIST = '0b51d97d-f321-4cb9-830c-892ec863fdf4'
BARD = 'b74e54ba-559a-49d9-933b-2978b1157f01'

def create_issue(task):
    body = json.dumps(task).encode()
    req = urllib.request.Request(
        f'{API}/api/companies/{COMPANY}/issues',
        data=body, method='POST',
        headers={
            'Content-Type': 'application/json',
            'Authorization': TOKEN,
            'X-Paperclip-Run-Id': RUN_ID,
        }
    )
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created: {resp['identifier']} - {resp['title']}")
    print(f"  ID: {resp['id']}")
    return resp

# Task 1: Engineer - Speed Milestones + World Unlock + Soft Purchase + Daily Claim
task1 = {
    'title': 'Engineer: Speed Milestone Celebrations + World Unlock Wow + Soft-Purchase VFX',
    'description': """## Speed Milestone Celebrations + World Unlock Wow + Soft-Purchase VFX

### Context
Deep audit found the CORE GAMEPLAY LOOP (driving) has zero celebration moments for speed achievements. Players can reach 100, 150, 200+ speed and nothing happens. This is the biggest remaining dopamine gap. Additionally, world unlocks only show a green row flash (underwhelming for a major progression moment), and soft-currency car purchases have SFX only with no VFX celebration.

### Requirements

#### 1. Speed Milestone Celebrations (DrivingController + DrivingHUD + VFXController)
Add speed threshold celebrations during a run. When a player crosses a speed milestone FOR THE FIRST TIME in that run:

**Thresholds**: 100, 150, 200, 250, 300 (configurable table at top of DrivingController)

For each threshold crossed:
- `VFXFacade.speedMilestone(speed)` - call a new VFXController method
- `SoundFacade.playOneShot("level_up")` - reuse existing sound
- In DrivingHUD: brief text flash showing "SPEED: {threshold}!" with scale-in + fade-out (TweenService, 0.5s)
- Track crossed thresholds in a local `Set` per run (reset on `StartRun`)
- At 300+: extra camera FOV punch (already have FOV utils in VFXController)

**VFXController.speedMilestone(speed)**:
- Screen edge gold flash (similar to lapFlash but gold, 0.3s)
- Brief speed-line intensity boost
- For 200+: add screen shake (0.1s, 2px amplitude)
- For 300+: full-screen golden overlay flash (0.15s) + `SoundFacade.playOneShot("purchase")` for extra oomph

#### 2. World Unlock Celebration (WorldPanel + VFXFacade)
When a world transitions from locked to unlocked while WorldPanel is open:
- Call `VFXFacade.purchaseCelebration("world", nil)` to trigger the existing full celebration
- Add `SoundFacade.playOneShot("level_up")`
- The world row should do a dramatic scale punch (1.0 -> 1.1 -> 1.0 with Back.Out, 0.4s)
- Add a brief "WORLD UNLOCKED!" label that scales in above the row (Back.Out, then fades out 1s later)
- Make the travel button pulse more aggressively for 3 seconds after unlock

#### 3. Soft-Currency Purchase VFX (StorePanel)
When a car is bought with in-game currency (not Robux):
- After the server confirms (DataUpdate shows car ownership changed), call `VFXFacade.purchaseCelebration("car", nil)`
- This leverages the existing celebration system instead of just playing a sound
- Track `pendingCarBuy` similar to how `pendingUpgrade` works for upgrades

#### 4. Daily Reward Claim Button Feedback (DailyRewardPanel)
Add immediate button feedback on claim press:
- Scale the claim button down to 0.9 on press (TweenService, 0.05s, Quad.Out)
- Set button text to "Claiming..." while waiting
- Add a brief pulse/shimmer to the button frame
- Restore on celebration start or after 3s timeout

### Files to modify
- `DACStarterPlayerScripts/Controllers/DrivingController.luau` (speed milestone tracking + fire VFX)
- `DACStarterGui/DrivingHUD.luau` (speed milestone text flash)
- `DACStarterPlayerScripts/Controllers/VFXController.luau` (speedMilestone method)
- `DACReplicatedStorage/VFXFacade.luau` (add speedMilestone)
- `DACStarterGui/WorldPanel.luau` (world unlock celebration)
- `DACStarterGui/StorePanel.luau` (soft-currency car purchase VFX)
- `DACStarterGui/DailyRewardPanel.luau` (claim button feedback)

### Definition of done
- Speed milestones at 100/150/200/250/300 each trigger visual + audio celebration ONCE per run
- DrivingHUD shows threshold text flash
- World unlock triggers full celebration + dramatic row animation
- Soft-currency car purchase triggers purchaseCelebration
- Daily claim button has immediate press feedback before async response""",
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': ENGINEER,
    'parentId': PARENT,
    'projectId': PROJECT,
}

# Task 2: Content Strategist - Speed Milestone Copy + World Unlock Headlines
task2 = {
    'title': 'Content Strategist: Speed Milestone Copy + World Unlock Celebration Text',
    'description': """## Speed Milestone Celebration Copy + World Unlock Text

### Context
We're adding speed milestone celebrations during driving (100/150/200/250/300 thresholds) and world unlock wow moments. These need dopamine-rich copy that makes players feel powerful and excited. The Content Strategist creates config files that the Engineer wires into the UI.

### Requirements

#### 1. SpeedMilestoneConfig.luau (NEW FILE)
Create `DACReplicatedStorage/Config/SpeedMilestoneConfig.luau` with:

```lua
local SpeedMilestoneConfig = {}

SpeedMilestoneConfig.Thresholds = {100, 150, 200, 250, 300}

-- Pool of celebration texts per tier (random pick on trigger)
SpeedMilestoneConfig.CelebrationText = {
    [100] = {"SPEED DEMON!", "PEDAL TO THE METAL!", ...},  -- 5+ options
    [150] = {"TURBO MODE!", "UNSTOPPABLE!", ...},          -- 5+ options  
    [200] = {"SUPERSONIC!", "LIGHT SPEED!", ...},          -- 5+ options
    [250] = {"HYPERDRIVE!", "BEYOND LIMITS!", ...},        -- 5+ options
    [300] = {"GOD SPEED!", "REALITY BLUR!", ...},          -- 5+ options
}

-- Subtitle flavor text (optional smaller text below the headline)
SpeedMilestoneConfig.FlavorText = {
    [100] = {"First triple digits!", "Now you're cooking!", ...},
    [150] = {...},
    [200] = {...},
    [250] = {...},
    [300] = {...},
}

return SpeedMilestoneConfig
```

**Style requirements**:
- Headlines: SHORT (1-3 words), ALL CAPS, power fantasy, adrenaline
- Flavor text: Casual, fun, 3-8 words, can reference the game world
- At least 5 options per tier so it never feels repetitive
- Higher tiers should feel progressively more INSANE and EPIC
- 300 tier should feel like reality is breaking

#### 2. WorldUnlockConfig.luau (NEW FILE)
Create `DACReplicatedStorage/Config/WorldUnlockConfig.luau` with:

```lua
local WorldUnlockConfig = {}

-- Celebration headline when unlocking a world
WorldUnlockConfig.UnlockHeadlines = {
    "NEW WORLD UNLOCKED!",
    "TERRITORY CONQUERED!",
    "NEW ROADS AWAIT!",
    "WORLD DISCOVERED!",
    "MAP EXPANDED!",
}

-- Per-world flavor text (keyed by world ID from WorldConfig)
WorldUnlockConfig.WorldFlavor = {
    suburbs = "The streets are yours now.",
    highway = "Open highway, no speed limits.",
    desert = "Endless dunes, endless possibilities.",
    frozen = "Ice and glory await.",
    neon = "The city that never sleeps.",
    volcano = "Drive through fire itself.",
}

return WorldUnlockConfig
```

**Style requirements**:
- Headlines: TRIUMPHANT, conquest feel, ALL CAPS
- World flavor: Atmospheric, mysterious, makes the player want to explore
- Match world IDs from the existing `WorldConfig.luau` (check what worlds exist)

### Reference
- Check `DACReplicatedStorage/Config/` for existing config file patterns
- Check `DACReplicatedStorage/Config/WorldConfig.luau` or equivalent for world IDs
- Follow the style of `MicrocopyConfig.luau` and `LoadingTipsConfig.luau`

### Files to create
- `DACReplicatedStorage/Config/SpeedMilestoneConfig.luau`
- `DACReplicatedStorage/Config/WorldUnlockConfig.luau`

### Definition of done
- SpeedMilestoneConfig with 5+ celebration texts per tier (5 tiers)
- WorldUnlockConfig with unlock headlines + per-world flavor text
- Both files follow existing config patterns and export properly""",
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': CONTENT_STRATEGIST,
    'parentId': PARENT,
    'projectId': PROJECT,
}

# Task 3: Bard - Store purchase moment design + car equip showcase design
task3 = {
    'title': 'Bard: Car Equip Showcase Animation + Store Purchase Moment Design',
    'description': """## Car Equip Showcase Animation + Store Purchase Moment Design

### Context
Audit revealed two gaps in visual spectacle: (1) Car equipping in InventoryPanel only has a basic emoji spin + scale punch - there's no dramatic "your new ride" showcase moment proportional to car rarity/tier. (2) In-game store purchases feel transactional - the upgrade flow has upgradeFlash but car purchases lack dedicated celebration moments.

### Requirements

#### 1. Car Equip Showcase Design (InventoryPanel.luau)
Design and implement a mini car showcase animation when equipping a car:

**On car equip in InventoryPanel:**
- The car card should do a rarity-scaled celebration:
  - **Common cars**: Current scale punch + icon spin (keep existing)
  - **Rare/World cars** (highway, desert, frozen): Add a rarity-colored border glow pulse (UIStroke color tween matching world theme color)
  - **Premium cars** (neon, volcano): Golden border glow + brief particle shimmer around the card + "PREMIUM RIDE!" text badge that scales in and fades
- Add a brief "EQUIPPED!" text label that appears above the card with Back.Out scale-in, holds 0.5s, then fades out
- The equipped badge animation should be snappier - current slide-in can be punchier with Elastic.Out easing

**Implementation**: Modify `applyEquipJuice` in `InventoryPanel.luau` to check the car's world tier and apply proportional celebration.

#### 2. Store Purchase Confirmation Moment (StorePanel.luau)
Design and implement a brief in-panel "purchase complete" state:

**After successful Robux purchase (MarketplaceService finish):**
- The purchased row should briefly flash green (BackgroundColor3 tween, 0.3s)
- Show a checkmark icon or "OWNED!" badge that scales in on the row
- The full-screen VFX celebration already fires (purchaseCelebration) - this is just the in-panel complement

**After successful soft-currency car buy:**
- Same row flash treatment
- Button should change from "Buy" to a brief "YOURS!" with a scale punch, then transition to "Owned" state

#### 3. Upgrade Stat Bar Celebration (StorePanel.luau)
When an upgrade is purchased and stat level increases:
- The stat bar fill should tween smoothly to the new value (not instant jump)
- Brief number count-up on the stat value label (current -> new)
- Keep the existing upgradeFlash but make the stat bar tween happen simultaneously

### Files to modify
- `DACStarterGui/InventoryPanel.luau` (car equip showcase)
- `DACStarterGui/StorePanel.luau` (purchase moment + stat bar celebration)

### Implementation notes
- Use TweenService with snappy easings (Back.Out, Elastic.Out for celebrations, Quad.Out for subtle effects)
- Keep all animations under 0.5s - these are micro-celebrations
- Check existing world colors from car card border logic to match rarity themes
- SFX is already handled - focus on VISUAL polish only

### Definition of done
- Car equip has rarity-proportional celebration (common basic, rare glow, premium shimmer)
- "EQUIPPED!" text flash on equip
- Store purchases show in-panel confirmation (row flash + owned badge)
- Upgrade stat bars tween smoothly instead of jumping""",
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': BARD,
    'parentId': PARENT,
    'projectId': PROJECT,
}

# Create all 3 tasks
print("=== Creating Wave 7 Tasks ===")
print()
create_issue(task1)
print()
create_issue(task2)
print()
create_issue(task3)
print()
print("=== Wave 7 Dispatched ===")
