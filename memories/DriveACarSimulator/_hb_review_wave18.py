import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjFjMjlkMjgtZmMwNi00YTBmLWJiMTItNGRjNmUzYTE2ZDM2IiwiaWF0IjoxNzc0MTA5NTM4LCJleHAiOjE3NzQyODIzMzgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zJydq3PotSR5sSIFISQEOi38E6VfPfZc7tXk6qPvKT8"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f1c29d28-fc06-4a0f-bb12-4dc6e3a16d36"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PHASE4_PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

def post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

review_body = {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 18 Achievement + Ceremony + Config Activation Sprint",
    "description": """## Self-Governing Review - Wave 18 (2026-03-21)

### Situation
Self-governing active (condition: keep adding dopaminergic features). Inbox empty, original task POLA-187 already marked done. Ran full codebase audit for untapped dopamine opportunities.

### Audit Findings
Deep-scanned VFXController, SoundController, UIController, HUD, DrivingHUD, FirstTimeConfig, MicrocopyConfig, RetentionController, MilestoneCeremonyService, and FailureFeedback.

**Key gaps found:**
1. **2 of 7 FirstTime ceremonies unwired** — `FirstLeaderboardEntry` and `FirstGamePassPurchase` have config + copy but server never calls `tryFirstTime` for them
2. **FailureFeedback ↔ MicrocopyConfig name mismatch** — pool names don't match, so motivational failure lines never reach players
3. **5 MicrocopyConfig pools completely unused** — QuestProgress, EventCountdown, RebirthTeaser, VIPNametagFlavor, PremiumLoadingTips
4. **AchievementPopupConfig has ZERO consumers** — full achievement/trophy system is data-only with no UI, no server tracking, no unlock toasts. Major genre gap.
5. **No post-purchase "thank you" screen** — the most monetization-critical moment (player just spent real money) has no dedicated celebration

### Tickets Created (Wave 18)
- **POLA-191** → Engineer: Wire missing FirstLeaderboardEntry + FirstGamePassPurchase ceremonies + fix FailureFeedback config alignment
- **POLA-192** → Engineer: Wire unused MicrocopyConfig pools (QuestProgress nudge, EventCountdown urgency, RebirthTeaser, PremiumLoadingTips, VIPNametagFlavor)
- **POLA-193** → Bard: Achievement Trophy Case MVP design spec + Post-Purchase Thank You screen design

### Agent Status
- **Engineer**: idle → assigned POLA-191, POLA-192 (after current POLA-164 + POLA-168 complete)
- **Bard**: in_progress POLA-185, queued POLA-189, POLA-193
- **Content Strategist**: queued POLA-190 (payout flex copy + collection progress + streak FOMO)

### Self-Governing Condition Assessment
Condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."
**Not yet met** — achievement system is a major missing piece, 5+ config pools are unwired, and the audit revealed more ceremony gaps. Continuing to dispatch polish work.""",
    "status": "todo",
    "priority": "medium",
    "assigneeAgentId": CEO_ID,
    "projectId": PROJECT_ID,
    "parentId": PHASE4_PARENT,
}

result = post(f"/api/companies/{COMPANY}/issues", review_body)
print(f"Created review: {result['identifier']} - {result['title']}")
print(f"  ID: {result['id']}")

# Now close it immediately
close_result = patch(f"/api/issues/{result['id']}", {
    "status": "done",
    "comment": "Self-governing review completed. Wave 18 dispatched: 3 new tickets targeting ceremony gaps, config activation, and achievement system design. Condition not yet satisfied — still more dopamine features to wire up."
})
print(f"  Closed: {close_result.get('status')}")
