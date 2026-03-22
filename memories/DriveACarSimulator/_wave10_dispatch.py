import urllib.request, json, sys
sys.stdout.reconfigure(encoding='utf-8')

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNTcwYzZkYTEtNGQyNS00NDJiLTlmMDQtZjIzODg4Mzc2ZWI1IiwiaWF0IjoxNzc0MTA0NjU2LCJleHAiOjE3NzQyNzc0NTYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.oC1elHcw4vBiUFH4kGqqAMVtpbCFByPFPjW4JMDps3o'
RUN = '570c6da1-4d25-442b-9f04-f23888376eb5'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
ENGINEER = '323fca23-ecfa-4f35-aeb1-77f206eccf34'
BARD = 'b74e54ba-559a-49d9-933b-2978b1157f01'
CONTENT = '0b51d97d-f321-4cb9-830c-892ec863fdf4'

def create_issue(title, desc, assignee, priority='high'):
    body = json.dumps({
        'title': title,
        'description': desc,
        'status': 'todo',
        'priority': priority,
        'assigneeAgentId': assignee,
        'projectId': PROJECT,
        'parentId': PARENT
    }).encode()
    req = urllib.request.Request(
        f'{API}/api/companies/{COMPANY}/issues',
        data=body, method='POST',
        headers={'Content-Type':'application/json', 'Authorization': TOKEN, 'X-Paperclip-Run-Id': RUN}
    )
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created {resp.get('identifier','?')} - {title[:60]}")
    return resp

# Task 1: Engineer - Silent UI SFX + hatch rarity audio + premium welcome fix
create_issue(
    'Engineer: Silent UI SFX Wiring + Hatch Rarity Audio + Premium Welcome Fix',
    """## Silent UI SFX Wiring + Hatch Tier Audio + Premium Welcome SFX Fix

### Context
Deep audit found multiple UI panels that have VFX celebrations but are completely SILENT (no SFX). Also found registered SFX keys that are never played. These are high-impact, low-effort fixes.

### Requirements

#### 1. PetIndexPanel SFX (highest priority - collection is a core revenue surface)
In `DACStarterGui/PetIndexPanel.luau`:
- Add `SoundFacade` require (match existing pattern from other panels)
- In `showMilestoneCelebration` (around line 133-154): add `SoundFacade.playOneShot("level_up")` at start of celebration
- In NEW badge discovery animation (around line 239-271): add `SoundFacade.playOneShot("notification")`
- In tap-on-newly-discovered-species handler (around line 273-306): add `SoundFacade.playOneShot("click")`

#### 2. QuestPanel SFX
In `DACStarterGui/QuestPanel.luau`:
- Add `SoundFacade` require
- Where `VFXFacade.questComplete` runs (around line 386-399): add `SoundFacade.playOneShot("level_up")` alongside the VFX

#### 3. StorePanel upgrade success SFX
In `DACStarterGui/StorePanel.luau`:
- Where `VFXFacade.upgradeFlash()` runs (around line 262-264): add `SoundFacade.playOneShot("purchase")`

#### 4. LeaderboardPanel rank-up SFX
In `DACStarterGui/LeaderboardPanel.luau`:
- In `RankUpNotification` handler (around line 458-477): add `SoundFacade.playOneShot("level_up")`

#### 5. DrivingHUD speed milestone SFX
In `DACStarterGui/DrivingHUD.luau`:
- In SpeedMilestoneFlash handler (around line 165-203): add `SoundFacade.playOneShot("level_up")`

#### 6. Fix premiumWelcomeFanfare SFX (wrong key)
In `DACStarterPlayerScripts/Controllers/VFXController.luau`:
- `premiumWelcomeFanfare` plays `"purchase"` (around line 5229) but `"premium_welcome"` is already registered in SoundController. Change to `"premium_welcome"`.

#### 7. Wire hatch_common and hatch_uncommon SFX
In `DACStarterPlayerScripts/Controllers/VFXController.luau` in `hatchReveal` crack phase (around line 2250-2257):
- Currently only rare/epic/legendary/mythic have rarity-specific SFX
- Add: common -> `"hatch_common"`, uncommon -> `"hatch_uncommon"` (both already registered in SoundController)

### Verification
After changes, `SoundFacade` should be required in PetIndexPanel, QuestPanel, LeaderboardPanel, DrivingHUD. All registered SFX keys should have at least one play path.""",
    ENGINEER,
    'high'
)

# Task 2: Engineer - RebirthPanel offscreen fix + first-rank leaderboard fanfare
create_issue(
    'Engineer: Rebirth Offscreen Celebration + First Leaderboard Rank Fanfare',
    """## Rebirth Offscreen Celebration Fix + First Leaderboard Rank Fanfare

### Context
Two critical dopamine pipeline failures found in audit:
1. RebirthPanel celebration only fires when the panel is VISIBLE - if player rebirths while panel is closed, they miss the entire ceremony (confetti, rebirthFlash, milestone text)
2. LeaderboardService skips rank-up fanfare on a player's FIRST rank placement

### Requirements

#### 1. RebirthPanel offscreen celebration (critical - rebirth is the endgame loop)
In `DACStarterGui/RebirthPanel.luau` around line 112-114:
- `showRebirthCelebration` is gated on `root.Visible`
- When the panel is NOT visible but rebirth count increased, the celebration is silently skipped
- Fix: Move the VFX/SFX portions (confetti, rebirthFlash, milestone check) to fire regardless of panel visibility
- The UI-specific animations (text tweens, panel-local effects) can stay gated on visibility
- At minimum: `VFXFacade.rebirthFlash()` and `SoundFacade.playOneShot("rebirth_confetti")` (or equivalent) should fire even when panel is closed

#### 2. First leaderboard rank fanfare
In `DACServerScriptService/Services/LeaderboardService.luau` around line 106-108:
- `evaluateRankAfterUpdate`: when `prevRank == nil` (first time placing), code sets the snapshot but does NOT fire `RankUpNotification`
- Fix: When `prevRank == nil`, treat this as a "new entry" and fire `Remotes.RankUpNotification:FireClient(player, { stat = stat, newRank = currentRank, previousRank = nil, isFirstPlacement = true })`
- The client already handles RankUpNotification in LeaderboardPanel; it just never gets one for first placement

### Verification
- Rebirth with panel closed should still trigger world-space VFX (confetti + flash)
- First-time leaderboard placement should show a rank-up toast""",
    ENGINEER,
    'high'
)

# Task 3: Content Strategist - SoundController cleanup + engine idle placeholder fix
create_issue(
    'Content Strategist: SoundController Audit Notes + Dead Code Documentation',
    """## SoundController Cleanup Notes + Placeholder Documentation

### Context
Audit found several loose ends in SoundController that need documentation or cleanup decisions.

### Requirements

#### 1. Document engine idle TBD (SoundController line ~381)
In `DACStarterPlayerScripts/Controllers/SoundController.luau`:
- Comment says "vehicle wiring TBD" around line 381 for engine idle sounds
- Write a brief design note in a comment: is engine idle needed for the game? If yes, what should it sound like? If no, remove the TBD.
- Decision: Since Drive A Car Simulator uses top-down/isometric driving (not first-person), engine idle is LOW priority. Update the comment to `-- Engine idle: deferred (isometric view reduces audio immersion need)` or similar.

#### 2. Document pet equip placeholder IDs (SoundController line ~412)  
- Comment says "placeholder IDs" for pet equip sounds
- These need real asset IDs to work. Add a comment noting they need real Roblox audio asset IDs.

#### 3. Clean up dead code
- `SoundController.play` (line ~265-267) is a legacy alias for `playOneShot` with no callers. Add `-- DEPRECATED: use playOneShot directly` comment.
- `SoundController.setMusic` (line ~269-276) and `SoundController.setSFX` (line ~278-281) have no callers. Add `-- DEPRECATED: settings path uses applySettings from Bootstrap` comment.

#### 4. Fix SoundFacade header comment
In `DACReplicatedStorage/SoundFacade.luau`:
- Header (line ~4) says `Bootstrap.client` but the actual file is `Bootstrap.local.luau`. Fix the reference.

### Verification
All TODO/TBD comments in SoundController should have clear resolution or documentation.""",
    CONTENT,
    'medium'
)

print("\n--- Wave 10 dispatched ---")
