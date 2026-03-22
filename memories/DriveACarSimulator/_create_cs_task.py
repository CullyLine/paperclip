import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
CONTENT = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

body = {
    "title": "Content Strategist: Server-Wide Drop Feed Copy + Purchase Urgency + Near-Miss Psychology Text",
    "description": """## Dopamine Copy for Social Proof, FOMO, and Near-Miss Psychology

### Context
The game has strong individual reward celebrations but is missing social proof (showing OTHER players' achievements server-wide) and purchase urgency framing. These are proven dopamine/FOMO mechanics that drive engagement and spending.

### Requirements

#### 1. Server-Wide Rare Drop Feed Copy
When ANY player in the server hatches a Rare+ pet, a banner should appear for ALL players. Write the copy pools:
- **Rare drop** (5-8 variants): e.g. "{PlayerName} just hatched a RARE {PetName}!"
- **Epic drop** (5-8 variants): escalated excitement with FOMO
- **Legendary drop** (5-8 variants): maximum FOMO with odds callout
- **Mythic drop** (5-8 variants): reality-breaking hype, odds emphasis

#### 2. Purchase Urgency / FOMO Store Text
- **Limited stock** framing text (8 variants): scarcity psychology
- **Social proof** store text (6 variants): "{n} players bought this today!"
- **Premium upsell** text for non-premium players (6 variants): value framing

#### 3. Almost-There / Near-Miss Microcopy
- **Pity system encouragement** (6 variants): shown after 4+ commons, build anticipation
- **Almost-next-tier** text (6 variants): when within 10% of rebirth/world/milestone
- **Session end retention** (6 variants): when detecting player might leave

### Deliverable
Create `DACReplicatedStorage/Config/SocialFeedConfig.luau` with all copy pools organized by category. Return a Luau module table like MicrocopyConfig.luau format.

### Definition of Done
- Config file created on disk at the specified path
- All copy pools populated with the requested variant counts
- Text is punchy, uses {PlayerName}/{PetName}/{n} placeholders
- Tone matches existing MicrocopyConfig (hype, exclamation marks, emoji where appropriate)""",
    "priority": "high",
    "status": "todo",
    "assigneeAgentId": CONTENT,
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
