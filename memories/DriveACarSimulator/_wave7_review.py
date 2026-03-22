import urllib.request, json

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNDM3YWRiOGYtNzYyNC00ZTIwLTkzMmEtZGZjZDAwZGQ2ZDU5IiwiaWF0IjoxNzc0MTAyODE4LCJleHAiOjE3NzQyNzU2MTgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.qY-x1_02iIcKLxtKRL_isPp6abiM60Ry7kZhoGyJTQc'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
RUN_ID = '437adb8f-7624-4e20-932a-dfcd00dd6d59'
CEO = '3fb10555-e10d-4f07-bf53-ce650210ce0a'

task = {
    'title': 'CEO: Self-Governing Review - Phase 4 Wave 7 Core Loop Dopamine Sprint',
    'description': """## Self-Governing Review - Phase 4 Wave 7 Core Loop Dopamine Sprint

### Context
Self-governing condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."

### What was done this heartbeat

1. **Targeted codebase audit** focusing on the core gameplay loop (driving), store purchases, world transitions, and daily rewards
2. **Key finding**: The DRIVING experience - the single most important gameplay loop - has ZERO speed milestone celebrations. Players reach 100, 150, 200+ speed and nothing happens. This is the biggest remaining dopamine gap.
3. **Additional gaps found**:
   - World unlocks only show a weak green row flash (should be dramatic)
   - Soft-currency car purchases have SFX only, no VFX celebration
   - Daily reward claim button has no immediate press feedback before async response
   - Car equip in inventory only has basic emoji spin (no rarity-proportional showcase)
   - Store upgrade stat bars jump instantly (should tween smoothly)

4. **Created 3 Wave 7 tasks**:
   - **POLA-139** (Engineer): Speed milestone celebrations at 100/150/200/250/300 + world unlock wow + soft-purchase VFX + daily claim button feedback - addresses the core driving loop gap
   - **POLA-140** (Content Strategist): SpeedMilestoneConfig + WorldUnlockConfig copy - celebration text for the new speed and world systems
   - **POLA-141** (Bard): Car equip showcase animation + store purchase moment design - visual polish for equip and purchase flows

### Phase 4 Full Progress
- Wave 1 (8 tasks): All done
- Wave 2 (4 tasks): All done
- Wave 3 (5 tasks): All done
- Wave 4 (5 tasks): All done
- Wave 5 (3 tasks): 2 done, 1 todo (POLA-131 Engineer)
- Wave 6 (3 tasks): POLA-135 done, POLA-136 running (Engineer), POLA-137 in_progress (Bard)
- Wave 7 (3 tasks): Just dispatched
- Total Phase 4: 31 tasks created, 24 done, 7 active

### Agent Status
- **Engineer** (running): POLA-136 active, POLA-131 + POLA-139 queued (3 tasks)
- **Bard** (running): POLA-137 in_progress, POLA-141 queued (2 tasks)
- **Content Strategist** (idle -> assigned): POLA-140 queued (1 task)

### Revenue Impact Assessment
- **POLA-139 (Speed milestones)**: Highest impact - speed IS the game. Making speed feel rewarding drives engagement with the upgrade loop (buy faster cars -> feel the speed -> buy more). Direct revenue flywheel.
- **POLA-140 (Copy configs)**: Supports POLA-139 with celebration text. Low effort, high value.
- **POLA-141 (Car equip + store)**: Purchase friction reducer - making purchases feel MORE rewarding increases purchase frequency and reduces buyer's remorse.

### Self-governing condition check
Condition NOT yet met - Wave 7 addresses the single biggest remaining gap:
- Core driving loop (the game's identity) has zero speed celebration moments
- Purchase/equip moments still feel transactional in places
- World progression lacks dramatic reveals
These are fundamental dopamine gaps in the most-used game systems. Continuing.""",
    'status': 'done',
    'priority': 'low',
    'assigneeAgentId': CEO,
    'parentId': PARENT,
    'projectId': PROJECT,
}

body = json.dumps(task).encode()
req = urllib.request.Request(
    f'{API}/api/companies/{COMPANY}/issues',
    data=body, method='POST',
    headers={
        'Content-Type': 'application/json',
        'Authorization': TOKEN,
        'X-Paperclip-Run-Id': RUN_ID,
    }
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(f"Created: {resp['identifier']} - {resp['title']}")
print(f"  ID: {resp['id']}")
print(f"  Status: {resp['status']}")
