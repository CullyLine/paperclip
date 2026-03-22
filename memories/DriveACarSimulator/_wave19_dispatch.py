import urllib.request, json

API = 'http://127.0.0.1:3100'
TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNmRjNGE5MTYtZDE1YS00ZTg5LWEyZDYtNTM0OGIxMWRhOTFkIiwiaWF0IjoxNzc0MTEwMTc3LCJleHAiOjE3NzQyODI5NzcsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.UlRK8wW_2IBSI6nqhDIw9bh6kaz2VP9_YAZW9P1pep0'
RUN = '6dc4a916-d15a-4e89-a2d6-5348b11da91d'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
ENGINEER = '323fca23-ecfa-4f35-aeb1-77f206eccf34'
CS = '0b51d97d-f321-4cb9-830c-892ec863fdf4'
BARD = 'b74e54ba-559a-49d9-933b-2978b1157f01'
HEADERS = {'Content-Type':'application/json','Authorization':'Bearer '+TOKEN,'X-Paperclip-Run-Id':RUN}

def create_issue(body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API+'/api/companies/'+COMPANY+'/issues', data=data, method='POST', headers=HEADERS)
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print('Created:', resp.get('identifier'), '|', resp.get('title','?')[:80])
    return resp

# Ticket 1: Engineer - Wire remaining dead config consumers
desc1 = """## Config Activation Sprint - Final Dead Configs

Five config files have data that is never consumed at runtime. Wire them all in one pass.

### 1. ComboCelebrationConfig -> DrivingController
- `DACReplicatedStorage/Config/ComboCelebrationConfig.luau` has tiered combo headlines, bodies, PB lines
- Currently `DrivingController.luau` only uses `NearMissCopyConfig` for near-miss popups
- **Wire**: When combo depth hits tier thresholds (5/10/15/20/25+), show `ComboCelebrationConfig` tiered headline + body in a milestone popup or HUD text. On personal-best combo, show PB line.

### 2. SpeedTierCopyConfig -> DrivingHUD
- `DACReplicatedStorage/Config/SpeedTierCopyConfig.luau` has TierNames, TierThresholds, AccelerationCallouts, PetUnequipFarewell
- **Wire**: In `DrivingHUD.luau`, when speed crosses a tier threshold, flash the tier name (e.g. "SUPERSONIC"). On acceleration events, randomly pick an AccelerationCallout.
- **Wire**: In `InventoryPanel.luau` pet unequip flow, show a random PetUnequipFarewell line.

### 3. FomoBadgeLabelConfig -> StorePanel
- `DACReplicatedStorage/Config/FomoBadgeLabelConfig.luau` has Permanent, Event, AlmostEarned, SocialProof pools
- Currently `StorePanel.luau` hardcodes "BEST VALUE" and uses ad-hoc badge logic
- **Wire**: Replace hardcoded FOMO badge text in `StorePanel.luau` with `FomoBadgeLabelConfig` pool picks. Use `Permanent` for always-on badges, `Event` for time-limited, `AlmostEarned` for near-threshold items, `SocialProof` for popular items.

### 4. NearMissCopyConfig lap pools -> VFXController/DrivingHUD
- `NearMissCopyConfig.luau` has `LapComplete`, `LapPersonalBest`, `LapHumor` pools
- `VFXController.lapFlash` fires VFX + horn but NO copy
- **Wire**: On lap complete, show a random `LapComplete` line. On lap PB, show `LapPersonalBest`. Occasionally mix in `LapHumor`.

### 5. LeaderboardTextConfig unused pools -> LeaderboardPanel
- `LeaderboardTextConfig.luau` has `RankUpMessages`, `TopTenMessages`, `RivalApproaching` -- only `Number1Flex` and `CloseToNextRank` are consumed
- **Wire**: Show `RankUpMessages` on rank improvement, `TopTenMessages` when entering top 10, `RivalApproaching` when within 5% of the player above.

### Acceptance
- All 5 configs must have at least one `require()` in a runtime consumer
- Verify: no config file in `DACReplicatedStorage/Config/` should be unreferenced by runtime code"""

create_issue({
    'title': 'Engineer: Wire Dead Config Consumers - ComboCelebration + SpeedTierCopy + FomoBadge + Lap Copy + LeaderboardText',
    'description': desc1,
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': ENGINEER,
    'projectId': PROJECT,
    'parentId': PARENT,
})

# Ticket 2: Engineer - Car equip celebration + MilestoneCeremonyCopyConfig activation + Easter egg fanfare
desc2 = """## Missing Celebration Moments - Car Equip + Ceremony Copy + Easter Egg

### 1. Car Equip Celebration Parity
- `InventoryPanel.luau`: Pet equip uses `equip_item` SFX + `VFXFacade.petEquipEntrance`
- Car equip only uses `click` SFX (~line 338-339) -- no VFX, no celebration
- **Fix**: Add `SoundFacade.playOneShot("equip_item")` + `VFXFacade.purchaseCelebration` or a new `carEquipShowcase` call on car equip. Cars are the core identity of the game -- equipping a new car should feel like an event.

### 2. MilestoneCeremonyCopyConfig -> MilestoneCeremonyService
- `MilestoneCeremonyCopyConfig.luau` has rich tiered ceremony copy for rebirth/collection/world mastery/total runs milestones
- `MilestoneCeremonyService.luau` currently only reads `FirstTimeConfig` and sends a single `body` string
- **Fix**: When firing ceremonies for rebirth/collection/world mastery/total runs milestones, pull the appropriate pool from `MilestoneCeremonyCopyConfig` instead of generic `FirstTimeConfig` text. This gives each milestone its own themed celebration language.

### 3. Easter Egg Discovery Fanfare
- `Bootstrap.local.luau` handles `EasterEggDiscovered` -- currently shows a toast + generic `notification` SFX
- **Fix**: Add `SoundFacade.playOneShot("quest_complete")` or dedicated discovery SFX + `VFXFacade.milestonePopup` or `VFXFacade.rewardChest` for a proper "secret found!" moment.

### Acceptance
- Car equip must trigger SFX + VFX matching or exceeding pet equip celebration
- `MilestoneCeremonyCopyConfig` must be `require()`d by at least one server/client module
- Easter egg discovery must feel like a genuine reward moment with dedicated SFX + VFX"""

create_issue({
    'title': 'Engineer: Car Equip Celebration + MilestoneCeremonyCopy Activation + Easter Egg Fanfare',
    'description': desc2,
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': ENGINEER,
    'projectId': PROJECT,
    'parentId': PARENT,
})

# Ticket 3: Content Strategist - MicrocopyConfig pity/streak/collection pools wiring audit + copy polish
desc3 = """## Unused MicrocopyConfig Pool Audit + Monetization Copy Polish

### Situation
The codebase deep-scan found that several `MicrocopyConfig.luau` subsections have copy that is never surfaced to players. These are all high-value monetization/retention moments.

### Unused Pools to Audit and Recommend Wiring For
1. **Pity pools** (`PityApproaching`, `PityGuaranteed`, `PityStreakReset`) -- egg pity system has VFX in `EggShopPanel.luau` but does NOT use these copy pools
2. **StreakFOMO pools** (`StreakFOMOWarning`, `StreakFOMOLost`) -- daily streak loss aversion copy exists but is never shown
3. **Collection pools** (`CollectionProgress`, `CollectionComplete`) -- collection milestone moments have no text celebration

### Deliverables
1. **Audit doc**: For each unused pool, identify exactly where in the UI/controller the copy should be surfaced, what trigger event fires, and which function to hook into
2. **Copy polish**: Review the existing pool text for each and refine for maximum dopamine/FOMO impact. Write 2-3 additional lines per pool if the current set feels thin.
3. **Combo celebration copy**: Review `ComboCelebrationConfig.luau` tier thresholds and headlines -- ensure the language escalates dramatically from tier 1 to tier 5+

### Format
Comment on this ticket with a structured audit table:
| Pool | File to Wire In | Trigger | Current Lines | Suggested Additions |

This will be used by Engineer to wire the consumers in the next sprint."""

create_issue({
    'title': 'Content Strategist: MicrocopyConfig Pity/Streak/Collection Pool Wiring Audit + Combo Copy Polish',
    'description': desc3,
    'status': 'todo',
    'priority': 'medium',
    'assigneeAgentId': CS,
    'projectId': PROJECT,
    'parentId': PARENT,
})

print("\nAll Wave 19 tickets created.")
