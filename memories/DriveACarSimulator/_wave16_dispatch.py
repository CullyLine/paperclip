import urllib.request, json, sys

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZmM1MjU3MDAtNDA4MC00NzdkLWIzNjUtOTU0ZTJmOTVlM2JiIiwiaWF0IjoxNzc0MTA4Mzg2LCJleHAiOjE3NzQyODExODYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ._25GP2nYBMaRMYMUK0ce0R_-08L7YVBu446oy_-FxQA'
RUN = 'fc525700-4080-477d-b365-954e2f95e3bb'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
ENGINEER = '323fca23-ecfa-4f35-aeb1-77f206eccf34'
BARD = 'b74e54ba-559a-49d9-933b-2978b1157f01'
CS = '0b51d97d-f321-4cb9-830c-892ec863fdf4'

headers = {
    'Content-Type': 'application/json',
    'Authorization': TOKEN,
    'X-Paperclip-Run-Id': RUN
}

def create_issue(data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(
        API + '/api/companies/' + COMPANY + '/issues',
        data=body, method='POST', headers=headers
    )
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created {resp.get('identifier')} -> {resp.get('title', '')[:70]}")
    return resp

# Task 1: Engineer - Speed color + near-miss popups + pet unequip
create_issue({
    'title': 'Engineer: DrivingHUD Speed Color Tiers + Near-Miss Text Popups + Pet Unequip Polish',
    'description': (
        "## DrivingHUD Speed Color Gradient + Near-Miss Copy Popups + Pet Unequip Juice\n\n"
        "### 1. Speed Text Color Tiers (DrivingHUD.luau)\n"
        "The speed TextLabel currently shows a plain white number regardless of speed. Add color tiers:\n\n"
        "In `render()`, after `speedText.Text = tostring(math.floor(currentSpeed))`, add color lerping:\n"
        "- 0-50 speed: White (255, 255, 255)\n"
        "- 50-100: Yellow (255, 230, 80)\n"
        "- 100-200: Orange (255, 160, 40)\n"
        "- 200-300: Red (255, 60, 40)\n"
        "- 300+: Magenta pulse (255, 40, 200) with subtle size pulse via UIScale\n\n"
        "Use `Color3:Lerp()` for smooth transitions between tiers. Add a subtle `UIScale` pulse at 300+ "
        "that oscillates between 1.0 and 1.08.\n\n"
        "### 2. Near-Miss Text Popups (DrivingController or DrivingHUD)\n"
        "`NearMissCopyConfig.luau` exists with 16+ celebration text variants but is NEVER consumed anywhere. "
        "When `nearMissSpark` fires:\n\n"
        "1. `require` NearMissCopyConfig\n"
        "2. Pick a random popup text from the config arrays\n"
        "3. Show a quick text popup near center-bottom of driving HUD (like SpeedMilestoneFlash but smaller, TextSize 22)\n"
        "4. Scale-in (0.3->1.0, Back easing), hold 0.4s, fade out 0.3s\n"
        "5. Play `SoundFacade.playOneShot(\"near_miss\")` (or `ui_whoosh` if near_miss not registered)\n"
        "6. If NearMissCopyConfig has streak/combo variants, show escalating text on consecutive near-misses\n\n"
        "### 3. Pet Unequip Feedback (InventoryPanel.luau)\n"
        "Currently equip has rich juice but unequip is silent. Add minimal unequip feedback:\n"
        "- Quick scale-down-then-back (0.85 -> 1.0, 0.2s Quad easing)\n"
        "- Play `SoundFacade.playOneShot(\"ui_click\")` on unequip\n"
        "- Brief gray overlay flash (0.15s) showing deactivation\n\n"
        "### Files to modify\n"
        "- `DACStarterGui/DrivingHUD.luau` (speed colors + maybe near-miss popup display)\n"
        "- `DACStarterPlayerScripts/Controllers/DrivingController.luau` (near-miss popup trigger)\n"
        "- `DACStarterGui/InventoryPanel.luau` (unequip feedback)\n"
        "- `require` NearMissCopyConfig in the near-miss handler"
    ),
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': ENGINEER,
    'projectId': PROJECT,
    'parentId': PARENT
})

# Task 2: Engineer - petIndexDiscovery facade + speed text size pulse
create_issue({
    'title': 'Engineer: Fix petIndexDiscovery Facade Route + Speed Text Scale Punch on Acceleration',
    'description': (
        "## Fix petIndexDiscovery Facade + Speed Acceleration Punch\n\n"
        "### 1. Route petIndexDiscovery Through VFXFacade\n"
        "`VFXFacade.petIndexDiscovery()` exists but is never called -- `VFXController` calls its own "
        "`VFXController.petIndexDiscovery()` directly around line 5426, bypassing the facade.\n\n"
        "Fix: In the call site (PetIndexPanel or wherever discovery triggers), replace "
        "`VFXController.petIndexDiscovery(pid)` with `VFXFacade.petIndexDiscovery(pid)` so the facade "
        "pattern is consistent.\n\n"
        "### 2. Speed Text Scale Punch on Rapid Acceleration\n"
        "In `DrivingHUD.luau`, track the previous speed and when `currentSpeed - prevSpeed > 15` in a single "
        "frame, do a brief scale punch on the speed text:\n"
        "- Create/reuse a `UIScale` child on speedText\n"
        "- Tween from 1.15 -> 1.0 over 0.2s (Back easing)\n"
        "- This makes sudden acceleration feel impactful\n"
        "- Only trigger once per second max (cooldown) to avoid spamming\n\n"
        "### Files\n"
        "- `DACStarterPlayerScripts/Controllers/VFXController.luau` (fix discovery call site)\n"
        "- `DACStarterGui/DrivingHUD.luau` (acceleration punch)"
    ),
    'status': 'todo',
    'priority': 'medium',
    'assigneeAgentId': ENGINEER,
    'projectId': PROJECT,
    'parentId': PARENT
})

# Task 3: Content Strategist - Speed tier names + acceleration callout copy + unequip flavor
create_issue({
    'title': 'Content Strategist: Speed Tier Names + Acceleration Callout Copy + Unequip Flavor Text',
    'description': (
        "## Speed Tier Copy + Acceleration Callouts + Unequip Flavor\n\n"
        "### 1. Speed Tier Display Names\n"
        "DrivingHUD is getting color-coded speed tiers. Write short tier names that could optionally "
        "display next to the speed number:\n"
        "- 0-50: Cruising tier (e.g. \"CRUISING\")\n"
        "- 50-100: Fast tier (e.g. \"FAST!\")\n"
        "- 100-200: Blazing tier (e.g. \"BLAZING!\")\n"
        "- 200-300: Insane tier (e.g. \"INSANE!\")\n"
        "- 300+: Legendary tier (e.g. \"LEGENDARY!\")\n\n"
        "Write 3 alternative name options per tier (15 total). Keep them punchy, 1-2 words max.\n\n"
        "### 2. Acceleration Callout Copy\n"
        "When the player suddenly accelerates hard, a brief text flash appears. Write 8-10 one-liner "
        "callouts like \"LAUNCH!\", \"TURBO!\", \"FLOOR IT!\", etc. Keep under 12 characters each.\n\n"
        "### 3. Pet Unequip Flavor Text\n"
        "When a pet is unequipped, write 6-8 short farewell lines the pet \"says\" like "
        "\"See ya later!\", \"I'll be here!\", etc. Cute, brief, max 20 chars.\n\n"
        "### Output\n"
        "Create `DACReplicatedStorage/Config/SpeedTierCopyConfig.luau` with all copy organized in tables."
    ),
    'status': 'todo',
    'priority': 'high',
    'assigneeAgentId': CS,
    'projectId': PROJECT,
    'parentId': PARENT
})

print("\nAll Wave 16 tasks created.")
