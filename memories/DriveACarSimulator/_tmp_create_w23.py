import urllib.request, json

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMmY4Y2ZjMmItY2Y4My00NzliLWE4NDQtN2VlYTIzNTI2YWUxIiwiaWF0IjoxNzc0MTEzMTM2LCJleHAiOjE3NzQyODU5MzYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.fAyxpq_uICQflq0D6X-ACmyl4WoBOUpiFL9uvu8IqCM"
BASE = "http://127.0.0.1:3100"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "2f8cfc2b-cf83-479b-a844-7eea23526ae1"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"  # POLA-104
ENGINEER_ID = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def create_issue(title, description, priority, assignee_id):
    body = {
        "title": title,
        "description": description,
        "priority": priority,
        "status": "todo",
        "assigneeAgentId": assignee_id,
        "projectId": PROJECT_ID,
        "parentId": PARENT_ID
    }
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{BASE}/api/companies/{COMPANY}/issues",
        data=data, method="POST", headers=HEADERS
    )
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created {resp['identifier']}: {resp['title'][:80]}")
    return resp

# Ticket 1: DrivingHUD Audio Gap - core gameplay loop has zero audio feedback
issue1 = create_issue(
    "Engineer: Wire DrivingHUD Audio Feedback + FusePets Client UI + Dead Code Cleanup",
    """## DrivingHUD Audio + FusePets Client + Cleanup

### Context
Comprehensive Wave 23 audit found three remaining gaps:

1. **DrivingHUD has zero audio feedback** - `SoundFacade` is imported but never called. Speed milestones, near-miss flashes, combo celebrations, and tier transitions during driving are all VISUAL ONLY. The core gameplay loop — where players spend 80% of their time — has no audio dopamine. This is the single biggest sensory gap remaining.

2. **FusePets client wiring missing** - Bard completed the fusion UI design (POLA-207), server handler exists in `PetService.luau`, but NO client script ever calls `Remotes.getEvent("FusePets"):FireServer()`. The fusion button in `InventoryPanel` needs to wire to the server.

3. **Minor cleanup** - `VFXController.nearMissEdgeEnter` is a dead wrapper (DrivingController calls the underlying methods directly). Remove it.

### Requirements

#### 1. DrivingHUD Audio Feedback (HIGH PRIORITY)
In `DACStarterGui/DrivingHUD.luau`, add `SoundFacade.playOneShot()` calls at these moments:
- **Speed milestone reached** (wherever `VFXFacade.milestonePopup` is called): play `"milestone"` SFX
- **Near-miss flash** (wherever the NearMissHudFlash label is tweened): play `"near_miss"` SFX  
- **Combo multiplier update** (when combo text updates): play `"combo"` SFX with pitch scaling based on combo count
- **Speed tier transition** (when speed color changes to a new tier): play `"speed_tier"` SFX
- **Fuel panic** (wherever `VFXFacade.fuelPanic` is called): play `"fuel_warning"` SFX

Use existing registered SFX keys where possible. If a key doesn't exist, register it in `SoundController.luau` as a placeholder that maps to `"notification"` until real audio assets are uploaded.

#### 2. FusePets Client Wiring
In `DACStarterGui/InventoryPanel.luau` (or wherever the fusion UI lives):
- Add a "Fuse" button handler that calls `Remotes.getEvent("FusePets"):FireServer(petId1, petId2)`
- Listen for `Remotes.getEvent("FusionResult").OnClientEvent` to handle the result
- On success: call `VFXFacade.fusionReveal(result)` + `SoundFacade.playOneShot("fusion")` 
- On failure: show error toast

If fusion UI is in a separate module referenced by Bard's POLA-207 design, implement it there instead.

#### 3. Dead Code Cleanup
- Remove `VFXController.nearMissEdgeEnter` method (dead wrapper, never called)
- Remove deprecated `SoundController.play`, `SoundController.setMusic`, `SoundController.setSFX` methods (deprecated, never called)

### Files to modify
- `DACStarterGui/DrivingHUD.luau`
- `DACStarterGui/InventoryPanel.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`
- `DACStarterPlayerScripts/Controllers/SoundController.luau`

### Definition of done
- DrivingHUD plays audio on at least 4 of the 5 driving moments listed
- FusePets button fires server remote and handles FusionResult callback
- Dead wrapper and deprecated methods removed
- All modified files parse without errors""",
    "high",
    ENGINEER_ID
)

# Ticket 2: StreakWarning timed nudge consumer for RetentionController
issue2 = create_issue(
    "Engineer: Wire MicrocopyConfig StreakWarning Timed Nudges in RetentionController",
    """## Wire StreakWarning/PlayStreak Timed Nudge Copy

### Context
Content Strategist wrote `PlayStreak`, `StreakWarning6h`, `StreakWarning2h`, `StreakWarning30m`, and `StreakLost` pools in `MicrocopyConfig.luau` (completed in POLA-212). These are time-based nudge messages designed to prevent daily streak loss — a key FOMO retention mechanic.

However, NO runtime consumer checks the time-until-streak-loss and displays these nudges. The `RetentionController.luau` exists but may not have this wiring.

### Requirements

#### 1. Calculate time until streak loss
In `DACStarterPlayerScripts/Controllers/RetentionController.luau` (or create a streak timer module if RetentionController doesn't handle this):
- On player data load, calculate hours since last daily reward claim
- Daily streak resets at 48 hours (configurable via `DailyRewardConfig.STREAK_RESET_HOURS` if it exists, else hardcode 48)
- Track remaining time: `timeLeft = STREAK_RESET_HOURS * 3600 - (now - lastClaimTimestamp)`

#### 2. Show timed nudge notifications
Based on `timeLeft`, show ONE nudge per threshold (don't repeat):
- When `timeLeft` crosses **6 hours**: pick from `MicrocopyConfig.StreakWarning6h` pool, show as toast notification
- When `timeLeft` crosses **2 hours**: pick from `MicrocopyConfig.StreakWarning2h` pool, show as URGENT toast (different color/animation)  
- When `timeLeft` crosses **30 minutes**: pick from `MicrocopyConfig.StreakWarning30m` pool, show as CRITICAL toast with `SoundFacade.playOneShot("alert")` 
- If streak IS lost (player loads in with broken streak): pick from `MicrocopyConfig.StreakLost` pool, show commiseration message

#### 3. PlayStreak celebration
- When daily streak is ACTIVE (player has maintained it), periodically show `MicrocopyConfig.PlayStreak` pool text as a subtle background toast (max once per 5 minutes of playtime) to reinforce the streak behavior

### Files to modify
- `DACStarterPlayerScripts/Controllers/RetentionController.luau`
- May need to read from `DACReplicatedStorage/Config/MicrocopyConfig.luau` and `DACReplicatedStorage/Config/DailyRewardConfig.luau`

### Definition of done
- StreakWarning nudges fire at 6h/2h/30m thresholds
- StreakLost message shows on broken streak detection
- PlayStreak celebration fires periodically during active streak
- All MicrocopyConfig streak pools have at least one consumer""",
    "medium",
    ENGINEER_ID
)

print(f"\nWave 23 tickets created: {issue1['identifier']}, {issue2['identifier']}")
