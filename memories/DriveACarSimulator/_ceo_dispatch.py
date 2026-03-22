import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f6389f70-14bf-43bb-9a6e-97c7f3aeb81a"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def create_issue(title, description, assignee_id, priority="medium"):
    body = {
        "title": title,
        "description": description,
        "assigneeAgentId": assignee_id,
        "projectId": PROJECT_ID,
        "parentId": PARENT_ID,
        "status": "todo",
        "priority": priority,
    }
    resp = api_post(f"/api/companies/{COMPANY}/issues", body)
    ident = resp.get("identifier", "?")
    iid = resp.get("id", "?")
    print(f"Created {ident} ({iid}): {title}")
    return resp

ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD = "b74e54ba-559a-49d9-933b-2978b1157f01"
CONTENT = "0b51d97d-f321-4cb9-830c-892ec863fdf4"

if sys.argv[1] == "wave9":
    create_issue(
        "Engineer: Rebirth Ceremony Overhaul + Collision Shake + Pet Equip Entrance Wiring",
        """## Rebirth Ceremony Overhaul

RebirthPanel.luau `showRebirthCelebration` currently only plays `rebirth_confetti` + a text tween. This is the weakest celebration in the game despite rebirth being a core revenue driver (players grind to rebirth).

### Tasks

#### 1. Wire full rebirth ceremony in RebirthPanel.luau (~line 75-100)
After `SoundFacade.playOneShot("rebirth_confetti")`, add:
```lua
local milestone = RebirthMilestoneConfig.getHighestMilestoneCrossed(newCount)
VFXFacade.rebirthFlash(newCount, milestone)
```
- Import `RebirthMilestoneConfig` and `VFXFacade` at top of file
- The `rebirthFlash` method already exists in VFXFacade/VFXController and handles tiered celebrations (riser, boom, confetti intensity scaling)
- This gives rebirth the milestone-aware ceremony it deserves

#### 2. Collision camera shake in DrivingController.luau (~line 113-129)
In `hookCollisionSfx`, after `SoundFacade.playOneShot("collision")`, add:
```lua
VFXFacade.cameraShake(0.4, 0.25)
```
- Collision currently only plays audio — zero screen feedback
- Small shake (0.4 intensity, 0.25s) to make barrier hits feel impactful without being annoying

#### 3. Pet equip world-space entrance in InventoryPanel.luau (~line 499-512)
After `SoundFacade.playOneShot("equip_item")` in the pet equip path, add:
```lua
VFXFacade.petEquipEntrance(newPetUid, nil, r)
```
- `petEquipEntrance` already exists and is implemented — it's just never called from the inventory panel
- Cars get full spin animation + world glow + premium shimmer on equip; pets deserve the same treatment
- The `r` (rarity) variable is already computed on line ~506: `local r = def and def.rarity or "common"`

#### 4. Per-rarity hatch SFX in VFXController.luau hatchReveal (~line 2131+)
In `VFXController.hatchReveal`, at the crack/reveal moment (after particles fire), add rarity-based SFX:
```lua
local rarity = petData.rarity or "common"
if rarity == "rare" then
    SoundFacade.playOneShot("hatch_rare")
elseif rarity == "epic" then
    SoundFacade.playOneShot("hatch_epic")
elseif rarity == "legendary" then
    SoundFacade.playOneShot("hatch_legendary")
elseif rarity == "mythic" then
    SoundFacade.playOneShot("hatch_mythic")
end
```
- All four hatch SFX keys are already registered in SoundController (~line 407-410)
- Currently only legendary/mythic are played in fusion paths — standard hatching has NO rarity distinction

### Files to modify
- `DACStarterGui/RebirthPanel.luau`
- `DACStarterPlayerScripts/Controllers/DrivingController.luau`
- `DACStarterGui/InventoryPanel.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`

### Revenue Impact
- Rebirth ceremony: HIGH — players who feel the rush of rebirth will chase the next one harder
- Collision shake: MEDIUM — makes driving feel visceral, increases perceived speed/danger
- Pet equip entrance: MEDIUM — pets are the #2 monetization vector after speed upgrades
- Hatch rarity SFX: HIGH — distinct audio per rarity creates anticipation and disappointment/elation cycle""",
        ENGINEER,
        "high"
    )

    create_issue(
        "Content Strategist: Fix LoadingTipsConfig Factual Errors + Add Dopamine Tips",
        """## LoadingTipsConfig Factual Accuracy Pass

Several loading tips contain factual errors that erode player trust. Players who read inaccurate tips learn to distrust the game, which weakens all messaging.

### Errors to Fix (in DACReplicatedStorage/Config/LoadingTipsConfig.luau)

1. **"Players with VIP earn 2x coins"** — WRONG. VIP pass is cosmetic/inventory slots. The 2x coins pass is `double_coins` (separate game pass). Fix: Either "VIP players get extra inventory slots!" or reference the correct pass "The 2x Coins pass doubles your earnings!"

2. **"Leaderboard resets weekly"** — WRONG. LeaderboardService uses OrderedDataStore with no weekly reset logic. Fix: Remove or change to "Climb the leaderboard to earn bragging rights!" or similar.

3. **"Challenge mode unlocks at Rebirth 5"** — UNVERIFIED. No challenge mode gating found in server code. Fix: Remove or replace with verified tip like "Each rebirth permanently boosts your gas, power, and speed!"

### Tips to Add (dopamine-forward)

Add 3-5 new tips that drive monetization awareness and excitement:
- Something about egg hatching rarities (mythic pets exist!)
- Something about the battle pass rewards
- Something about speed milestones having celebrations
- Something about the daily reward streak
- Something about world exploration

### Tone
- Excited, short, punchy
- Use exclamation marks
- Create FOMO ("Did you know mythic pets exist? Keep hatching!")
- Reference concrete game features players can chase

### Files to modify
- `DACReplicatedStorage/Config/LoadingTipsConfig.luau`

### Deliverable
Updated LoadingTipsConfig.luau on disk with corrected facts and new dopamine tips.""",
        CONTENT,
        "medium"
    )

    create_issue(
        "Bard: Rebirth Milestone Visual Language + Hatch Rarity Crack Sequence Design",
        """## Design Specs for Rebirth Milestones + Hatch Rarity Moments

### 1. Rebirth Milestone Visual Language
RebirthPanel is getting a ceremony overhaul (Engineer task). Design the visual language for milestone tiers:

Reference `DACReplicatedStorage/Config/RebirthMilestoneConfig.luau` for the milestone thresholds. Design how each milestone tier should LOOK different:
- What color palette per milestone tier
- What particle density/type escalation
- Screen flash duration/intensity scaling
- Any unique visual elements (crown, aura, wings) at high milestones

### 2. Hatch Rarity Crack Sequence
Currently all egg hatches look the same until the pet appears. Design a visual spec for how the egg crack sequence should differ by rarity:
- **Common**: Simple crack, minimal particles, quick reveal
- **Rare**: Crack with colored sparks, brief hold for anticipation
- **Epic**: Dramatic crack lines spreading, purple/gold particles, camera zoom
- **Legendary**: Slow-motion crack, golden explosion, light rays, extended hold
- **Mythic**: Full-screen takeover, reality-breaking effects, shockwave, maximum hold time

### 3. Pet Equip World-Space Entrance Polish
`PetEntranceDesignSpec.luau` already exists. Review it and verify it covers:
- Rarity-appropriate entrance scale (mythic should be MORE dramatic than common)
- Sound timing alignment with visual keyframes
- Whether `petEquipEntrance` in VFXController matches the spec

### Deliverable
A design spec file (like PetEntranceDesignSpec.luau) with:
- Rebirth milestone visual parameters per tier
- Hatch rarity crack sequence timing and effects per rarity
- Any corrections to PetEntranceDesignSpec.luau

### Files to reference
- `DACReplicatedStorage/Config/RebirthMilestoneConfig.luau`
- `DACStarterGui/PetEntranceDesignSpec.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau` (hatchReveal ~line 2131)""",
        BARD,
        "medium"
    )

    print("\nWave 9 dispatched!")
