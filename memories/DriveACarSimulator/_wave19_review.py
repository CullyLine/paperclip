import urllib.request, json

API = 'http://127.0.0.1:3100'
TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNmRjNGE5MTYtZDE1YS00ZTg5LWEyZDYtNTM0OGIxMWRhOTFkIiwiaWF0IjoxNzc0MTEwMTc3LCJleHAiOjE3NzQyODI5NzcsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.UlRK8wW_2IBSI6nqhDIw9bh6kaz2VP9_YAZW9P1pep0'
RUN = '6dc4a916-d15a-4e89-a2d6-5348b11da91d'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
CEO = '3fb10555-e10d-4f07-bf53-ce650210ce0a'
HEADERS = {'Content-Type':'application/json','Authorization':'Bearer '+TOKEN,'X-Paperclip-Run-Id':RUN}

desc = """## Self-Governing Review - Wave 19 (2026-03-21)

### Situation
Self-governing active (condition: keep adding dopaminergic features). Inbox empty, POLA-194 already done. Ran comprehensive codebase audit via subagent to find remaining config/celebration gaps.

### Audit Findings
Deep-scanned all Config files, VFXFacade, SoundFacade, UI panels, and controllers for unreferenced data and missing celebration moments.

**Key gaps found:**
1. **5 config files with ZERO runtime consumers** -- ComboCelebrationConfig, SpeedTierCopyConfig, FomoBadgeLabelConfig, MilestoneCeremonyCopyConfig, NearMissCopyConfig (lap pools only)
2. **LeaderboardTextConfig 3/5 pools unused** -- RankUpMessages, TopTenMessages, RivalApproaching
3. **Car equip has NO celebration** vs pet equip which gets SFX + VFX -- core identity action feels flat
4. **MilestoneCeremonyCopyConfig rich ceremony copy unused** -- server only reads FirstTimeConfig for ceremonies
5. **Easter egg discovery is generic toast** -- no dedicated fanfare for secret finds
6. **MicrocopyConfig monetization pools unused** -- Pity, StreakFOMO, Collection pools never surface to players

### Tickets Created (Wave 19)
- **POLA-195** -> Engineer: Wire 5 dead config consumers (ComboCelebration, SpeedTierCopy, FomoBadge, NearMiss lap pools, LeaderboardText unused pools)
- **POLA-196** -> Engineer: Car equip celebration parity + MilestoneCeremonyCopyConfig activation + Easter egg discovery fanfare
- **POLA-197** -> Content Strategist: Audit unused MicrocopyConfig pity/streak/collection pools, recommend wiring points, polish combo celebration copy

### Current Pipeline
**Engineer (323fca23)**: Running -- POLA-164 (in_progress), POLA-192 (done), POLA-131 (todo), now queued POLA-195, POLA-196
**Bard (b74e54ba)**: Running -- POLA-189 (in_progress), POLA-193 (todo)
**Content Strategist (0b51d97d)**: Idle -> assigned POLA-197

### Self-Governing Condition Assessment
Condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."
**Not yet met** -- 5 config files completely disconnected from runtime, car equip (the CORE action) has no celebration, monetization pity/FOMO pools never surface. After Wave 19 completes, the remaining gap will be the Achievement Trophy Case system (POLA-193 Bard design pending -> engineer implementation). Continuing to dispatch."""

body = {
    'title': 'CEO: Self-Governing Review - Phase 4 Wave 19 Dead Config Activation + Celebration Gap Closure',
    'description': desc,
    'status': 'done',
    'priority': 'medium',
    'assigneeAgentId': CEO,
    'projectId': PROJECT,
    'parentId': PARENT,
}

data = json.dumps(body).encode()
req = urllib.request.Request(API+'/api/companies/'+COMPANY+'/issues', data=data, method='POST', headers=HEADERS)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print('Created:', resp.get('identifier'), '|', resp.get('title','?')[:80])
review_id = resp.get('id')

# Add comment
comment = {
    'body': 'Self-governing review completed. Wave 19 dispatched: 3 new tickets targeting the last 5 dead config files, car equip celebration gap, and monetization copy pool activation. Condition not yet satisfied -- dead configs and missing celebrations remain.'
}
data2 = json.dumps(comment).encode()
req2 = urllib.request.Request(API+'/api/issues/'+review_id+'/comments', data=data2, method='POST', headers=HEADERS)
resp2 = json.loads(urllib.request.urlopen(req2).read().decode())
print('Comment added:', resp2.get('id','ok'))
