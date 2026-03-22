import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZTMzNTNlNjktNzkzMS00Yzc5LTkyOTktOGIxNjQwMmM3NzA2IiwiaWF0IjoxNzc0MTA3MjU1LCJleHAiOjE3NzQyODAwNTUsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zC1cKO4uq9qGwxf9NwJWrm0JY7M3JOhv4wYoaceE_pw"
RUN_ID = "e3353e69-7931-4c79-9299-8b16402c7706"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"  # POLA-104 Phase 4
ENGINEER = "323fca23-ecfa-4f35-a8fa-9b67ff tried"  # will get from agents list
CEO = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN_ID,
}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", method="GET", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

# Get agent IDs
agents = api_get(f"/api/companies/{COMPANY}/agents")
agent_map = {}
for a in agents:
    agent_map[a["urlKey"]] = a["id"]
    print(f"  {a['urlKey']}: {a['id']}")

ENGINEER_ID = agent_map.get("engineer")
BARD_ID = agent_map.get("bard")
CS_ID = agent_map.get("content-strategist")

# Task 1: Engineer - PayoutPanel SFX + PlaytimeGemHUD Punch + SettingsPanel Juice + TravelTeaser Wiring
task1 = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "Engineer: PayoutPanel SFX Wiring + PlaytimeGemHUD Award Punch + SettingsPanel Juice + TravelTeaser Consumer",
    "description": """## PayoutPanel SFX Wiring + PlaytimeGem Punch + Settings Juice + TravelTeaser

### 1. PayoutPanel Sound Keys (Critical)
Four payout-specific sound keys are registered in SoundController but NEVER played in PayoutPanel.luau:
- `payout_card_pop` — play when each stat card opens/pops
- `payout_badge_tick` — play when multiplier badges appear 
- `payout_run_of_day` — play on "Run of the Day" detection (personal best)
- `payout_tier_up` — play when BP tier increases during run-end

Add BP tier-up detection: compare pre-run tier vs post-run tier in results. If tier increased, fire `payout_tier_up` + a visual beat (flash, scale pulse on BP badge area).

### 2. PlaytimeGemHUD Award Punch (High)
Current award notification is basic (label color tween + ring pulse). Add:
- Root frame **elastic scale punch** (1.0 → 1.25 → 1.0 over 0.4s, elastic easing)
- Gem icon **spin** (0° → 360° over 0.5s)
- Brief **screen-edge glow** or radial gradient flash
- Use `SoundFacade.playOneShot("level_up")` or `"cha_ching"` for the punch

### 3. SettingsPanel Juice (Medium)
Currently zero TweenService usage:
- Add panel **slide-in** from right on open (Position tween 0.3s)
- Toggle switches: **smooth slide** animation (BackgroundColor3 tween)
- Slider handles: **scale pulse** on grab/release
- Close: **slide-out** to right

### 4. WorldUnlockConfig TravelTeaser Consumer (Medium)
`WorldUnlockConfig.TravelTeaser` table has copy for each world but zero consumers. Wire it:
- In **WorldPanel.luau**: show TravelTeaser text as a subtitle/teaser on locked worlds
- OR in **DrivingHUD.luau**: flash a "next world teaser" after speed milestone near world unlock threshold

### Files to modify
- `DACStarterGui/PayoutPanel.luau`
- `DACStarterGui/PlaytimeGemHUD.luau`
- `DACStarterGui/SettingsPanel.luau` (if exists) or wherever settings UI lives
- `DACStarterGui/WorldPanel.luau` or `DACStarterPlayerScripts/Controllers/DrivingHUD.luau`

### Acceptance
- All 4 payout SFX keys called at appropriate moments
- BP tier-up detection + visual beat
- PlaytimeGem award has elastic scale punch + gem spin
- Settings panel has open/close tweens + toggle animations
- TravelTeaser text visible on at least one surface""",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": ENGINEER_ID,
    "projectId": PROJECT,
    "parentId": PARENT,
})
print(f"\nCreated: {task1.get('identifier')} -> Engineer")

# Task 2: Engineer - Hatch Crack Phases Per Rarity
task2 = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "Engineer: Implement Per-Rarity Hatch Crack Phases from RebirthHatchDesignSpec",
    "description": """## Per-Rarity Hatch Crack Phases

### Context
`RebirthHatchDesignSpec.luau` specifies multi-phase crack sequences that vary by rarity, but `VFXController.hatchReveal` currently uses ONE shared wobble+fade for all rarities. This is a major dopamine gap — mythic hatches should feel 10x more dramatic than common ones.

### Requirements

Read `RebirthHatchDesignSpec.luau` for the full spec. Implement in `VFXController.hatchReveal`:

1. **Common/Uncommon** (fast): 
   - 2 wobble phases, quick crack at t=1.5s, simple pop
   - Total duration: ~2s

2. **Rare** (medium):
   - 3 wobble phases with increasing amplitude
   - Crack lines appear at t=1.5s, widen at t=2.5s
   - Burst at t=3s with colored particles
   - Total: ~3.5s

3. **Epic** (dramatic):
   - 4 wobble phases, camera-aware shake
   - Progressive crack lines at 1.5s, 2.5s, 3.5s
   - Color glow intensifies matching rarity
   - Dramatic burst at t=4s
   - Total: ~4.5s

4. **Legendary** (epic):
   - 5 wobble phases with escalating intensity
   - Golden glow buildup
   - Lightning-style crack flashes
   - Dramatic pause before reveal
   - Burst with gold particle shower
   - Total: ~5.5s

5. **Mythic** (insane):
   - 6+ wobble phases, screen darkens
   - Rainbow/prismatic glow cycle
   - Multiple crack flash sequences
   - Full-screen flash before reveal
   - Massive particle explosion with lingering sparkles
   - Total: ~7s

### Key Technical Notes
- Use `TweenService` for all animations
- Rarity is passed as parameter — index into a duration/phase table
- Each phase = { wobbleAmplitude, wobbleSpeed, crackAlpha, glowIntensity, particleRate }
- Play matching `hatch_common`..`hatch_mythic` SFX at the final burst moment
- Egg model reference from `VFXFacade.hatchReveal` context

### Files to modify
- `DACStarterPlayerScripts/Controllers/VFXController.luau` (main implementation)
- `DACReplicatedStorage/VFXFacade.luau` (if API changes needed)

### Acceptance
- Hatch duration scales with rarity (2s common → 7s mythic)
- Each rarity tier has distinct wobble count, crack visual progression, and glow color
- Mythic hatch causes screen darken + full-screen flash
- SFX matches rarity tier""",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": ENGINEER_ID,
    "projectId": PROJECT,
    "parentId": PARENT,
})
print(f"Created: {task2.get('identifier')} -> Engineer")

# Task 3: Bard - Hatch Crack Visual Language + SettingsPanel Micro-interaction Design
task3 = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "Bard: Hatch Crack Phase Visual Language + Settings Micro-Interaction Design + Payout Tier-Up Moment",
    "description": """## Hatch Crack Visual Design + Settings Micro + Payout Tier-Up

### 1. Hatch Crack Phase Visual Language (High)
Design the visual language for per-rarity egg hatch crack phases:
- **Color palettes** per rarity tier (common→mythic)
- **Crack pattern styles**: simple line cracks (common) → lightning bolts (legendary) → prismatic fractures (mythic)
- **Glow colors**: white (common), green (uncommon), blue (rare), purple (epic), gold (legendary), rainbow cycle (mythic)
- **Screen effects**: none (common) → vignette darken (epic+) → full darken + flash (mythic)
- **Particle burst sizes**: small pop → medium shower → gold rain → prismatic explosion
- Timing curves for each tier (fast→slow buildup→dramatic pause)

Deliver as a `HatchCrackVisualSpec.luau` table with per-rarity entries:
```
{ wobblePhases, crackStyle, glowColor, screenEffect, burstSize, totalDurationSec, sfxTiming }
```

### 2. SettingsPanel Micro-Interactions (Medium)
Design micro-interactions for settings controls:
- Toggle switch: slide animation with color transition, subtle bounce at endpoints
- Slider: handle glow on grab, track fill animation, value label pop
- Panel open/close: entrance direction, easing curve, backdrop fade
- Section dividers: subtle line draw animation on first visit

### 3. Payout Tier-Up Moment Design (Medium)
The PayoutPanel needs a distinct "tier up!" moment when the player's BP tier increases during a run:
- Badge/icon treatment for the tier-up indicator
- Animation sequence: badge appears, scales up with elastic, glow ring pulses
- Sound cue timing
- How it integrates with existing payout card flow (plays AFTER base stats, BEFORE dismiss)

Deliver all specs as Luau config tables the Engineer can directly consume.""",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": BARD_ID,
    "projectId": PROJECT,
    "parentId": PARENT,
})
print(f"Created: {task3.get('identifier')} -> Bard")

print("\n=== Done creating Wave 14 tasks ===")
