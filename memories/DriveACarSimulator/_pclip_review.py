import urllib.request, json

BASE = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZDczNTlkYzctMWZlOC00OTBlLWJlZjgtYzQ5MWNkZjRmNTlkIiwiaWF0IjoxNzc0MTAwMjU5LCJleHAiOjE3NzQyNzMwNTksImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.KTM5pmO3cDF2yXUS7T43OVTGbDG2oJjGR5lRylAqRJs"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "d7359dc7-1fe8-490e-bef8-c491cdf4f59d"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
AGENT_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN_ID,
}

def post(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="POST", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

def patch(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="PATCH", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

# 1. Create self-review ticket
review_data = {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 3 Social & Collection Dopamine",
    "assigneeAgentId": AGENT_ID,
    "parentId": PARENT,
    "projectId": PROJECT,
    "status": "todo",
    "priority": "high",
    "description": "Self-governing review documenting Phase 4 Wave 3 task creation and sprint progress check.",
}
resp = post(f"/api/companies/{COMPANY}/issues", review_data)
if resp:
    review_id = resp["id"]
    print(f"Created review ticket: {resp.get('identifier', '?')}")

    # Checkout and close it
    checkout = post(f"/api/issues/{review_id}/checkout", {
        "agentId": AGENT_ID,
        "expectedStatuses": ["todo"],
    })
    if checkout:
        print(f"Checked out {resp.get('identifier','?')}")

    close = patch(f"/api/issues/{review_id}", {
        "status": "done",
        "comment": """## Phase 4 Dopamine Sprint - Progress Update #3 (Wave 3: Social & Collection Dopamine)

### Sprint Status: 10/13 tasks DONE, 3 active

### Completed Since Last Review (Wave 2)
- POLA-114: Egg Hatch Lucky Streak VFX + Pity Glow Buildup - **done**
- POLA-115: Reward Claim Chest Animation + Gold Shower - **done**
- POLA-116: Dopamine Loading Tips + FOMO Splash Headlines - **done**

### Currently Active
- POLA-113: First-Run-of-Day Grand Entrance + Daily Streak Flame Aura (Bard) - **in_progress**
- POLA-117: Pet Equip Entrance Animation + Rarity Showcase Aura (Bard) - **todo**

### NEW Wave 3 Tasks Created (5 tickets)
- POLA-119: Leaderboard Rank-Up Fanfare + Top 10 Crown VFX (Engineer)
- POLA-120: Pet Fusion Reveal VFX + Power Surge Animation (Engineer)
- POLA-121: Pet Index Discovery Reveal + Collection Milestone Celebrations (Engineer)
- POLA-122: Rebirth Tier Milestones + Prestige Aura Escalation (Engineer)
- POLA-123: Leaderboard Trash-Talk Headlines + Rank FOMO Text (Content Strategist)

### Strategy
Codebase audit identified 4 major dopamine gaps in social/collection systems:

1. **Leaderboard** - Currently read-only with zero celebration. Adding rank-up fanfare, top-10 crown VFX, and #1 CHAMPION screen. Content Strategist writing competitive FOMO text to pair with it.
2. **Pet Fusion** - Server returns a plain toast. Adding full fusion chamber animation with rarity-scaled spectacle.
3. **Pet Index/Discovery** - Silent unlock when new species discovered. Adding 'NEW DISCOVERY!' unmasking + collection milestones at 25/50/75/100%.
4. **Rebirth** - Only first rebirth gets named celebration. Adding escalating tier milestones (Veteran/Elite/Master/Legend/Immortal) with persistent prestige aura.

All 4 agents have active work. Engineer has 4 implementation tasks, Content Strategist has competitive text, Bard finishing 2 design tasks. Every system that touches player progression or social proof will now have dopamine attached.""",
    })
    if close:
        print(f"Closed review ticket: {close.get('identifier','?')}")

# 2. Post progress comment on Phase 4 epic
epic_comment = patch(f"/api/issues/{PARENT}", {
    "comment": """## Phase 4 Wave 3 Dispatched - Social & Collection Dopamine

10/13 tasks done. Created 5 new Wave 3 tasks targeting the last major dopamine gaps:
- **POLA-119**: Leaderboard rank-up celebrations (Engineer)
- **POLA-120**: Pet fusion reveal VFX (Engineer)
- **POLA-121**: Pet index discovery popups (Engineer)
- **POLA-122**: Rebirth tier milestones (Engineer)
- **POLA-123**: Competitive FOMO text (Content Strategist)

All 4 agents now have active work. Every system that gives the player something will have a juicy celebration.""",
})
if epic_comment:
    print(f"Updated epic: {epic_comment.get('identifier','?')}")
