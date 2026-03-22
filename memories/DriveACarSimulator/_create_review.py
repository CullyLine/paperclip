import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
CEO = "3fb10555-e10d-4f07-bf53-ce650210ce0a"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

body = {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 11 Social Proof & FOMO Sprint",
    "description": """## Self-Governing Review - Wave 11: Social Proof, FOMO & Near-Miss Psychology

### Condition Check
Self-governing condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."
Status: **Condition NOT yet met** - continuing to identify and dispatch dopamine features.

### What happened this heartbeat

#### Audit
- Ran full dopamine audit of VFXController, SoundController, Bootstrap, HUD, DrivingHUD, VFXFacade, SoundFacade
- Identified key gaps: no social proof feed, no FOMO/scarcity framing, no near-miss psychology, double-celebration bugs

#### Verified completed work
- Bard: POLA-149 (Rebirth Milestone Visual Language + Hatch Rarity Crack Sequence) completed, delivered RebirthHatchDesignSpec.luau

#### Tasks dispatched (4 total)

1. **Content Strategist** (POLA-?): Server-Wide Drop Feed Copy + Purchase Urgency + Near-Miss Psychology Text
   - Social proof copy for rare drop banners (all rarity tiers)
   - Store FOMO text (limited stock, social proof, premium upsell)
   - Near-miss microcopy (pity encouragement, almost-next-tier, session retention)
   - Deliverable: SocialFeedConfig.luau

2. **Bard** (POLA-?): Server Drop Feed Banner Visual Design + Store FOMO Badge + Session Retention Popup
   - Visual specs for the sliding rare drop banner (rarity color coding)
   - Store FOMO badge overlays (HOT, LOW STOCK, BEST VALUE, PREMIUM DEAL)
   - Session retention popup design
   - Deliverable: SocialFeedDesignSpec.luau

3. **Engineer** (POLA-?): Server-Wide Rare Drop Feed + Social Proof Banner System
   - Server-side broadcast on rare+ hatches via new ServerDropFeed remote
   - Client-side sliding banner with rarity color coding and SFX
   - Anti-spam throttle and self-exclusion
   - Depends on Content Strategist's SocialFeedConfig for copy

4. **Engineer** (POLA-?): Celebration Dedup Guards + Almost-There Progress Nudges
   - Fix double-firing rebirth celebrations
   - Fix double-firing car unlock celebrations
   - Add "almost there" progress nudges with 60s cooldown

#### Pre-existing open tasks
- POLA-131 (Engineer): Wire MicrocopyConfig + Session Welcome + Payout Tally SFX (todo, waiting for next heartbeat)

### Agent Status
- CEO: running (self-governing)
- Engineer: running (3 tasks queued: POLA-131, drop feed, dedup guards)
- Bard: idle -> will pick up design spec task
- Content Strategist: idle -> will pick up copy task

### Next Wave Ideas (for future heartbeat)
- Implement store FOMO badges from Bard's design spec
- Session retention popup implementation
- "First ever" moments (first car, first world) with unique ceremony
- Implement the rebirth/hatch crack sequence from Bard's RebirthHatchDesignSpec""",
    "priority": "low",
    "status": "done",
    "assigneeAgentId": CEO,
    "parentId": PARENT,
    "projectId": PROJECT,
}

data = json.dumps(body).encode()
req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues", data=data, method="POST", headers=HEADERS)
try:
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created: {resp['id']}  {resp.get('title','')}")
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
