import urllib.request, json, sys
sys.stdout.reconfigure(encoding='utf-8')

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNTcwYzZkYTEtNGQyNS00NDJiLTlmMDQtZjIzODg4Mzc2ZWI1IiwiaWF0IjoxNzc0MTA0NjU2LCJleHAiOjE3NzQyNzc0NTYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.oC1elHcw4vBiUFH4kGqqAMVtpbCFByPFPjW4JMDps3o'
RUN = '570c6da1-4d25-442b-9f04-f23888376eb5'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
CEO = '3fb10555-e10d-4f07-bf53-ce650210ce0a'

desc = """## Self-Governing Review - Phase 4 Wave 10 Silent UI Audit & SFX Completeness Sprint

### Context
Self-governing condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."

### What was done this heartbeat

1. **Verified Wave 9 deliverables** (POLA-147, POLA-148, POLA-151):
   - POLA-147 (Engineer): Rebirth ceremony overhaul, collision camera shake, pet equip entrance, hatch rarity SFX - all delivered
   - POLA-148 (Content Strategist): Fixed 3 factual errors in LoadingTipsConfig, added 5 dopamine-forward tips - delivered
   - POLA-151 (Engineer): SFX semantic fixes, quest celebration dedup, world unlock identity - delivered (self-created by Content Strategist)

2. **Deep 3-axis codebase audit** (VFX/Sound systems, all UI panels, all server services):
   - VFXFacade: 30+ methods, all have matching VFXController implementations
   - SoundFacade: 6 methods, all wired correctly
   - Found 7 critical "silent UI" gaps where VFX plays but no SFX
   - Found 2 registered-but-never-played SFX keys (hatch_common, hatch_uncommon)
   - Found 1 wrong SFX key (premiumWelcomeFanfare uses "purchase" instead of "premium_welcome")
   - Found rebirth celebration skipped when panel is closed
   - Found first leaderboard placement gets no rank-up fanfare

3. **Created 3 Wave 10 tasks**:
   - **POLA-152** (Engineer): Silent UI SFX wiring across 5 panels + hatch rarity audio + premium welcome fix (7 subtasks)
   - **POLA-153** (Engineer): Rebirth offscreen celebration fix + first leaderboard rank fanfare
   - **POLA-154** (Content Strategist): SoundController audit notes cleanup + dead code documentation

### Phase 4 Full Progress
- Wave 1-7: All done (28 tasks)
- Wave 8: 2 done (POLA-143, POLA-144), 1 in_progress (POLA-145 Bard)
- Wave 9: 2 done (POLA-147, POLA-148), 1 todo (POLA-149 Bard)
- Wave 10: Just dispatched (POLA-152, POLA-153, POLA-154)
- Older open: POLA-131 (Engineer MicrocopyConfig wiring)
- POLA-151 done (bonus Engineer task from Content Strategist)
- Total Phase 4: ~40 tasks created, ~31 done, 9 active/queued

### Agent Status
- **Engineer** (idle): POLA-131, POLA-152, POLA-153 queued (3 tasks)
- **Bard** (running): POLA-145 in_progress + POLA-149 queued (2 tasks)
- **Content Strategist** (running): POLA-154 queued (1 task)

### Revenue Impact Assessment
- **POLA-152 (Silent UI SFX)**: HIGHEST impact - PetIndexPanel (collection = spending driver), QuestPanel (engagement loop), StorePanel (purchase validation), LeaderboardPanel (competitive spending), DrivingHUD (core loop). Every silent celebration is a missed dopamine hit.
- **POLA-153 (Rebirth offscreen + first rank)**: HIGH impact - rebirth is THE endgame prestige mechanic; missing its celebration when panel is closed means the most invested players (who rebirth frequently) get the worst experience
- **POLA-154 (Cleanup)**: LOW impact - code hygiene, but placeholder IDs and TBD comments suggest unfinished audio work

### Self-governing condition check
Condition NOT yet met - Wave 10 addresses the most fundamental gap found so far:
- 5 UI panels play VFX celebrations with ZERO audio - players see sparkles but hear nothing
- 2 registered sound effects are never played (hatch_common, hatch_uncommon)
- Premium welcome fanfare plays the wrong sound
- Rebirth ceremony is invisible when panel is closed
These are basic sensory completeness failures. The game cannot be considered "polished with lots of fun effects and dopamine-grabbing" while core celebrations are silent. Continuing."""

body = json.dumps({
    'title': 'CEO: Self-Governing Review - Phase 4 Wave 10 Silent UI Audit & SFX Completeness Sprint',
    'description': desc,
    'status': 'done',
    'priority': 'low',
    'assigneeAgentId': CEO,
    'projectId': PROJECT,
    'parentId': PARENT
}).encode()

req = urllib.request.Request(
    f'{API}/api/companies/{COMPANY}/issues',
    data=body, method='POST',
    headers={'Content-Type':'application/json', 'Authorization': TOKEN, 'X-Paperclip-Run-Id': RUN}
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(f"Created review ticket: {resp.get('identifier','?')} - {resp.get('id','?')}")
