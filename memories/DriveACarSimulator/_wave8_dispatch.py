import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjdmN2NkYWEtM2VhYi00YmViLWI4NWMtYjdmM2U2ZTU0NTRlIiwiaWF0IjoxNzc0MTAzMzU0LCJleHAiOjE3NzQyNzYxNTQsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.CakdK-j_8CYCRiXT4jLlYScvDgWF0I7I0b64u1k7I7I"
RUN_ID = "f7f7cdaa-3eab-4beb-b85c-b7f3e6e5454e"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"

ENGINEER_ID = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD_ID = "b74e54ba-559a-49d9-933b-2978b1157f01"
CONTENT_STRAT_ID = "0b51d97d-f321-4cb9-830c-892ec863fdf4"

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method="POST",
        headers={"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

tasks = [
    {
        "title": "Engineer: Failure Feedback + PayoutPanel Entrance + PlaytimeGemHUD Progress + Spend Drain Effect",
        "description": """## Failure Feedback + Payout Entrance + Playtime Progress + Spend Drain

### Context
Audit found four high/medium-severity dopamine gaps where player actions lack feedback. These are quick, impactful wins that make the game feel more responsive.

### Requirements

#### 1. Silent Failure Feedback (StorePanel.luau, EggShopPanel.luau)
When an upgrade, car buy, or egg hatch FAILS (not enough currency, server error, timeout):
- Play `SoundFacade.playOneShot("error")` (register "error" in SoundController if not present — use `rbxassetid://0` placeholder)
- Brief red pulse on the button that was pressed (color tween: red → restore over 0.3s)
- Show existing `Notification` remote with the failure reason if not already shown

**Files:** `DACStarterGui/StorePanel.luau`, `DACStarterGui/EggShopPanel.luau`

#### 2. PayoutPanel Card Entrance (PayoutPanel.luau)
When `PayoutPanel.show()` fires:
- Card starts at `Scale = UDim2.new(0.7, 0, 0.7, 0)` with `BackgroundTransparency = 1`
- Tween in over 0.4s with `Elastic` style: scale to full size, transparency to 0
- Multiplier badges stagger in with 0.08s delay each (scale pop from 0 → 1, `Back` style)
- "NEW RECORD!" badge should pulse-scale on loop (1 → 1.15 → 1, 1.5s period)

**Files:** `DACStarterGui/PayoutPanel.luau`

#### 3. PlaytimeGemHUD Progress Ring (PlaytimeGemHUD.luau)
- Add a circular progress indicator (using `UIStroke` + clipping or a simple fill bar) showing time until next gem
- In the last 10 seconds before reward, pulse the frame border with gold color
- When gem is awarded, add `VFXFacade.currencyPopup("gems", amount)` alongside existing SFX

**Files:** `DACStarterGui/PlaytimeGemHUD.luau`

#### 4. Spend Drain Effect (HUD.luau)
When currency DECREASES (negative delta detected in `onCurrencyUpdate`):
- Brief red flash on the currency label (color tween: red → white over 0.4s)
- Scale punch down (0.9) then back to 1.0 over 0.3s
- Play `SoundFacade.playOneShot("click")` for tactile feedback

When pet multiplier INCREASES:
- Gold pulse on the multiplier label
- `SoundFacade.playOneShot("level_up")`

**Files:** `DACStarterGui/HUD.luau`

### Acceptance
- Failed store/egg actions show red flash + error sound
- Payout card animates in with elastic + staggered badges
- PlaytimeGemHUD shows progress toward next gem with urgency
- Currency spend shows red drain flash; pet multiplier up shows gold pulse""",
        "assigneeAgentId": ENGINEER_ID,
        "status": "todo",
        "priority": "high",
        "parentId": PARENT_ID,
        "projectId": PROJECT_ID,
    },
    {
        "title": "Engineer: Camera Shake Fix + Driving Audio Loops + Unused SFX Hookup",
        "description": """## Camera Shake Fix + Driving Audio Loops + Unused SFX Hookup

### Context
Audit found the CORE DRIVING EXPERIENCE has critical gaps:
1. Camera shake (non-fuel-panic) uses a `task.wait` loop that fights the scriptable driving camera — shakes may be invisible during runs
2. No engine/road audio — driving is mostly silent except for milestone dings
3. `collision` and `engine_*` sounds are registered but never called from driving code

### Requirements

#### 1. Fix Camera Shake During Runs (VFXController.luau)
The `cameraShake` function sets `CurrentCamera.CFrame` in a loop, but `DrivingController` also sets it every `RenderStepped`. Fix by:
- During active runs, apply shake as an OFFSET to the camera position that `DrivingController` calculates, rather than setting CFrame directly
- Add a `shakeOffset` variable that `DrivingController` reads and applies additively
- Or use `BindToRenderStep` at a priority AFTER driving camera (driving = `Enum.RenderPriority.Camera.Value`, shake = `Camera.Value + 1`)
- Test: lap flash shake and speed milestone shake should be visible while driving

**Files:** `DACStarterPlayerScripts/Controllers/VFXController.luau`, `DACStarterPlayerScripts/Controllers/DrivingController.luau`

#### 2. Driving Audio Loop (DrivingController.luau, SoundController.luau)
- On `startRun`: start a looping engine sound from SoundController. Use the car's type to pick `engine_buggy`/`engine_sedan`/`engine_sports` etc.
- Modulate pitch based on speed (low speed = low pitch, high speed = high pitch). If SoundController doesn't support pitch modulation, add a `playLoop(name, properties)` / `stopLoop(name)` API.
- On `endRun`: fade out engine loop over 0.5s
- Add a wind/road-noise layer that increases volume with speed (optional, use `engine_wind` or similar)

**Files:** `DACStarterPlayerScripts/Controllers/DrivingController.luau`, `DACStarterPlayerScripts/Controllers/SoundController.luau`, `DACReplicatedStorage/SoundFacade.luau`

#### 3. Wire Collision SFX (DrivingController.luau)
- When the car's root part touches a wall/barrier (use `Touched` event on car body), play `SoundFacade.playOneShot("collision")`
- Throttle to max 1 collision sound per 0.5s

**Files:** `DACStarterPlayerScripts/Controllers/DrivingController.luau`

### Acceptance
- Camera shakes are visible during active driving runs
- Engine sound loops and changes pitch with speed
- Collision with barriers plays impact sound
- All sounds use existing `rbxassetid://0` placeholders (Board will fill real IDs)""",
        "assigneeAgentId": ENGINEER_ID,
        "status": "todo",
        "priority": "high",
        "parentId": PARENT_ID,
        "projectId": PROJECT_ID,
    },
    {
        "title": "Bard: Run Payout Dramatic Moments + PlaytimeGemHUD Visual Design + Failure State Design",
        "description": """## Run Payout Dramatic Moments + PlaytimeGemHUD Visual Design + Failure State Feedback Design

### Context
Audit found the run payout screen and playtime HUD lack visual drama, and failure states across the game have no visual language.

### Requirements

#### 1. PayoutPanel Dramatic Moments Design
Design the visual direction for:
- **Card entrance animation**: How should the run results card appear? Consider anticipation build (brief pause), elastic pop-in, particle shower from the edges
- **Multiplier badge stagger**: How should founder/premium/pet/run-of-day badges reveal? Consider left-to-right cascade, individual bounce-in with gold trail
- **"NEW RECORD!" badge**: Design a looping attention animation — consider glow pulse, rotation wobble, particle ring
- **Run of the Day title**: How should this differ from normal "Run complete!" — consider special color scheme, animated border, unique particle effect
- **Battle Pass tier crossing**: When XP bar fills past a tier boundary, design a "tier up!" micro-celebration — flash, sound sting, badge pop

Write a design spec at `DACStarterGui/PayoutPanelDesignSpec.luau` as a Luau table with timing, easing, colors, and descriptions for each moment.

#### 2. PlaytimeGemHUD Visual Design
Design a compact gem progress indicator:
- Visual treatment for the countdown/progress element (ring? bar? filling gem icon?)
- Urgency escalation design for last 10 seconds (color shift, pulse frequency increase, glow intensity)
- Gem award celebration design (burst direction, particle type, color palette)

Add to the same spec file or create `DACStarterGui/PlaytimeGemDesignSpec.luau`.

#### 3. Failure Feedback Visual Language
Design a consistent "action failed" visual language:
- Button press failure: What happens to the button? (red flash, shake, X icon?)
- Audio: What should the error sound feel like? (short buzz, descending tone, glass clink?)
- How does this differ from "not enough currency" vs "server error" vs "already owned"?

Add to spec file `DACStarterGui/FailureFeedbackDesignSpec.luau`.

### Acceptance
- 3 design spec files with specific timing, color values, easing curves, and descriptions
- Each spec should be implementable by Engineer without further clarification""",
        "assigneeAgentId": BARD_ID,
        "status": "todo",
        "priority": "medium",
        "parentId": PARENT_ID,
        "projectId": PROJECT_ID,
    },
]

for t in tasks:
    result = api_post(f"/api/companies/{COMPANY}/issues", t)
    print(f"Created {result['identifier']}: {result['title']}")
