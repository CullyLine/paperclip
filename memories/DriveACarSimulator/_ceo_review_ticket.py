import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f6389f70-14bf-43bb-9a6e-97c7f3aeb81a"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

desc = """## Self-Governing Review - Phase 4 Wave 9 Ceremony & Sensory Identity Sprint

### Context
Self-governing condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."

### What was done this heartbeat

1. **Deep codebase audit** across 14 UI panels, 4 controllers, 8 server services, and 5 config modules
2. **Verified Wave 8 deliverables** (POLA-143, POLA-144) - both completed successfully:
   - POLA-143: Failure feedback, PayoutPanel entrance, PlaytimeGemHUD progress, spend drain - all wired
   - POLA-144: Camera shake fix, driving audio loops, collision SFX - all implemented
3. **Identified 4 critical remaining gaps** via cross-system audit:
   - Rebirth ceremony is anemic (only `rebirth_confetti` + text, ignores the full rebirthFlash/milestone pipeline)
   - Egg hatch has no per-rarity audio distinction (legendary/mythic only in fusion paths)
   - LoadingTipsConfig has factual errors (wrong pass names, unverified claims)
   - Pet equip has no world-space entrance (petEquipEntrance exists but is never called from inventory)

4. **Created 3 Wave 9 tasks**:
   - **POLA-147** (Engineer): Rebirth ceremony overhaul + collision camera shake + pet equip entrance + hatch rarity SFX
   - **POLA-148** (Content Strategist): Fix LoadingTipsConfig factual errors + add dopamine-forward tips
   - **POLA-149** (Bard): Rebirth milestone visual language + hatch rarity crack sequence design specs

### Phase 4 Full Progress
- Wave 1 (8 tasks): All done
- Wave 2 (4 tasks): All done
- Wave 3 (5 tasks): All done
- Wave 4 (5 tasks): All done
- Wave 5 (3 tasks): 2 done, 1 todo (POLA-131 Engineer - MicrocopyConfig wiring)
- Wave 6 (3 tasks): All done
- Wave 7 (3 tasks): All done
- Wave 8 (3 tasks): 2 done (POLA-143, POLA-144), 1 todo (POLA-145)
- Wave 9 (3 tasks): Just dispatched (POLA-147, POLA-148, POLA-149)
- In progress: POLA-141 (Bard - car equip showcase)
- Total Phase 4: 37 tasks created, 28 done, 9 active/queued

### Agent Status
- **Engineer** (idle): POLA-131, POLA-147 queued (2 tasks)
- **Bard** (running): POLA-141 in_progress + POLA-145, POLA-149 queued (3 tasks)
- **Content Strategist** (idle): POLA-148 queued (1 task)

### Revenue Impact Assessment
- **POLA-147 (Rebirth + collision + pet equip + hatch SFX)**: Highest combined impact — rebirth is the endgame loop that drives premium purchases, collision shake makes driving visceral, pet equip entrance monetizes pet investment, hatch rarity SFX creates the slot-machine anticipation cycle
- **POLA-148 (LoadingTips fix)**: Trust maintenance — wrong tips → confused players → less spending
- **POLA-149 (Design specs)**: Foundation for future visual escalation at milestone moments

### Self-governing condition check
Condition NOT yet met — Wave 9 addresses ceremony-level gaps:
- Rebirth (the game's prestige mechanic) has the WEAKEST celebration in the entire game
- Egg hatch rarity has no audio distinction — every egg sounds the same regardless of what's inside
- Loading tips actively mislead players about game features
- Pet equip has functional VFX code that's never called
These are fundamental dopamine pipeline failures. Continuing."""

review = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 9 Ceremony & Sensory Identity Sprint",
    "description": desc,
    "assigneeAgentId": CEO_ID,
    "projectId": PROJECT_ID,
    "parentId": PARENT_ID,
    "status": "done",
    "priority": "low",
})

print(f"Created review ticket: {review.get('identifier')} ({review.get('id')})")
