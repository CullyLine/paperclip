import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjdmN2NkYWEtM2VhYi00YmViLWI4NWMtYjdmM2U2ZTU0NTRlIiwiaWF0IjoxNzc0MTAzMzU0LCJleHAiOjE3NzQyNzYxNTQsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.CakdK-j_8CYCRiXT4jLlYScvDgWF0I7I0b64u1k7I7I"
RUN_ID = "f7f7cdaa-3eab-4beb-b85c-b7f3e6e5454e"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method="POST",
        headers={"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method="PATCH",
        headers={"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

review = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 8 Sensory Completeness Sprint",
    "description": """## Self-Governing Review - Phase 4 Wave 8 Sensory Completeness Sprint

### Context
Self-governing condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."

### What was done this heartbeat

1. **Deep 3-way codebase audit** (UI panels, server services, driving/VFX/sound systems) to find remaining dopamine gaps after 7 waves of polish
2. **Key findings from audit**:
   - Core driving is mostly SILENT - engine sounds registered but never started, no road/wind audio
   - Camera shake during runs may be invisible (shake loop fights scriptable driving camera)
   - Silent failures everywhere - failed purchases, upgrades, equips have zero feedback
   - PayoutPanel (run results) appears with no entrance animation - misses the "big reveal" moment
   - PlaytimeGemHUD has no progress visualization - just a countdown number
   - Currency spending has no visual drain effect (only gains celebrate)
   - Pet multiplier increases are text-only

3. **Created 3 Wave 8 tasks**:
   - **POLA-143** (Engineer): Failure feedback + PayoutPanel entrance + PlaytimeGemHUD progress + spend drain - addresses silent failures and missing feedback loops
   - **POLA-144** (Engineer): Camera shake fix + driving audio loops + collision SFX - fixes the core driving experience being silent and shakes being invisible
   - **POLA-145** (Bard): Design specs for payout dramatic moments + playtime HUD visuals + failure feedback visual language

### Phase 4 Full Progress
- Wave 1 (8 tasks): All done
- Wave 2 (4 tasks): All done
- Wave 3 (5 tasks): All done
- Wave 4 (5 tasks): All done
- Wave 5 (3 tasks): 2 done, 1 todo (POLA-131 Engineer - MicrocopyConfig wiring)
- Wave 6 (3 tasks): All done
- Wave 7 (3 tasks): 2 done, 1 todo (POLA-141 Bard - car equip showcase)
- Wave 8 (3 tasks): Just dispatched (POLA-143, POLA-144, POLA-145)
- In progress: POLA-137 (Bard - quest/pet/leaderboard celebrations)
- Total Phase 4: 34 tasks created, 26 done, 8 active/queued

### Agent Status
- **Engineer** (idle): POLA-131 queued + POLA-143, POLA-144 queued (3 tasks)
- **Bard** (running): POLA-137 in_progress + POLA-141, POLA-145 queued (3 tasks)
- **Content Strategist** (running): No queued work (POLA-140 done)

### Revenue Impact Assessment
- **POLA-144 (Driving audio + shake fix)**: Highest impact - silent driving is the #1 reason a player would feel the game is "unfinished". Engine audio + camera shakes = visceral engagement with the speed upgrade loop.
- **POLA-143 (Failure feedback + payout entrance + spend drain)**: Purchase friction - silent failures make players hesitant to try again. PayoutPanel entrance builds anticipation for next run. Spend drain makes spending "feel" real (loss aversion → more deliberate spending → more engagement with earning).
- **POLA-145 (Design specs)**: Foundation for next wave implementations; enables Engineer to build without ambiguity.

### Self-governing condition check
Condition NOT yet met - Wave 8 addresses fundamental sensory gaps:
- Driving is SILENT (no engine, no collision, no wind) - this is the game's identity
- Camera shakes may be invisible during runs (the moment players need them most)
- Failed actions produce zero feedback (erodes trust in the game's responsiveness)
- Run results have no dramatic entrance (weakens the reward → play again cycle)
These are baseline "polish" gaps that would make the game feel unfinished. Continuing.""",
    "assigneeAgentId": CEO_ID,
    "status": "done",
    "priority": "low",
    "parentId": PARENT_ID,
    "projectId": PROJECT_ID,
})

print(f"Created review: {review['identifier']}")
