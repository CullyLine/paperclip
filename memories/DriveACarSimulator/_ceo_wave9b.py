import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f6389f70-14bf-43bb-9a6e-97c7f3aeb81a"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

resp = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "Engineer: SFX Semantic Fixes + Quest Celebration Dedup + World Unlock Identity",
    "description": """## Micro-Polish: Sound/VFX Semantic Accuracy

Several sounds and celebrations use the wrong SFX or overlap too heavily. These are small fixes with outsized impact on sensory coherence.

### Tasks

#### 1. Speed milestone 300 uses wrong SFX
In `DACStarterPlayerScripts/Controllers/VFXController.luau` around line 3558-3560, speed milestone 300 plays `purchase` instead of a speed-appropriate sound. Change to `level_up` or `speed_burst` (if registered) to match the achievement context.

#### 2. World unlock should use `world_unlock` SFX instead of `purchaseCelebration`
In `DACStarterGui/WorldPanel.luau` around line 144-146, world unlock calls `purchaseCelebration` + `level_up`. World unlock is a MILESTONE, not a purchase. Change to:
- Call `VFXFacade.milestonePopup` with world-specific headline
- Play `world_unlock` SFX (already registered in SoundController)
- Keep the row celebration but drop `purchaseCelebration` wrapper

#### 3. Quest completion celebration dedup
In `DACStarterGui/QuestPanel.luau` around line 369-395, both `VFXFacade.questComplete` (screen flash + shake) AND `playRowCelebration` (row sparkles + scale punch) fire simultaneously. This double-stacks and feels overwhelming rather than satisfying.
Fix: Make `playRowCelebration` lighter — remove any screen flash/shake from it if present, keeping only the row-local effects (sparkles, scale punch, text highlight). Let `questComplete` own the global screen effects.

#### 4. PayoutPanel panel_open sound
`DACStarterGui/PayoutPanel.luau` is a separate ScreenGui that doesn't go through `UIController.openPanel`, so it lacks the `panel_open` sound. Add `SoundFacade.playOneShot("panel_open")` when the payout screen shows (around the point where gui.Enabled = true).

### Files to modify
- `DACStarterPlayerScripts/Controllers/VFXController.luau`
- `DACStarterGui/WorldPanel.luau`
- `DACStarterGui/QuestPanel.luau`
- `DACStarterGui/PayoutPanel.luau`""",
    "assigneeAgentId": ENGINEER,
    "projectId": PROJECT_ID,
    "parentId": PARENT_ID,
    "status": "todo",
    "priority": "medium",
})

print(f"Created {resp.get('identifier')} ({resp.get('id')})")
