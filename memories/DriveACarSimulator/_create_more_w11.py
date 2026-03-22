import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
CONTENT = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

def create_issue(body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues", data=data, method="POST", headers=HEADERS)
    try:
        resp = json.loads(urllib.request.urlopen(req).read().decode())
        print(f"Created: {resp['id']}  {resp.get('title','')}")
        return resp
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

# Content Strategist: Achievement milestone copy + first-time ceremony text
create_issue({
    "title": "Content Strategist: First-Time Achievement Ceremony Copy + Spending Milestone Celebration Text",
    "description": """## Copy for First-Time Moments + Spending Milestones

### Context
The game tracks many "firsts" (first car, first pet, first rebirth, first world) and spending amounts, but the celebration text is either generic or missing. These are critical dopamine anchors that set hooks for continued play and spending.

### Requirements

#### 1. First-Time Achievement Ceremony Copy
Write celebration text pools for major first-time milestones:
- **First Car Purchased** (5 variants): Welcome to the garage! e.g. "YOUR FIRST RIDE! The journey begins!"
- **First Pet Hatched** (5 variants): e.g. "YOUR FIRST COMPANION! {PetName} chose YOU!"
- **First Rebirth** (5 variants): Transformative moment, e.g. "REBORN! Everything resets, but you're STRONGER!"
- **First World Unlocked** (5 variants): e.g. "NEW HORIZONS! {WorldName} awaits!"
- **First Leaderboard Entry** (5 variants): e.g. "YOU'RE ON THE BOARD! #{n} and climbing!"
- **First Game Pass Purchase** (5 variants): e.g. "POWER UNLOCKED! You just changed the game!"
- **First Quest Completed** (5 variants): e.g. "QUEST MASTER IN TRAINING! Keep grinding!"

#### 2. Spending Milestone Celebration Text
Text shown when player hits cumulative spending thresholds (encouraging more):
- **$5 spent** (3 variants): "Supporter" tier unlocked feel
- **$20 spent** (3 variants): "Power Player" tier
- **$50 spent** (3 variants): "VIP" tier  
- **$100 spent** (3 variants): "Whale" tier (but make it feel prestigious, not shame-y)
- Each tier should make the player feel EXCLUSIVE and VALUED

#### 3. Streak Celebration Text
For daily login streaks at key milestones:
- **7-day streak** (3 variants): e.g. "ONE FULL WEEK! Legendary dedication!"
- **14-day streak** (3 variants): "TWO WEEKS! You're unstoppable!"
- **30-day streak** (3 variants): "A WHOLE MONTH! True champion energy!"

### Deliverable
Create `DACReplicatedStorage/Config/FirstTimeConfig.luau` with all copy pools.

### Definition of Done
- Config file on disk at specified path
- All copy pools populated with requested variant counts
- Tone: celebratory, empowering, never condescending
- Placeholders use {PetName}/{WorldName}/{n} as needed""",
    "priority": "medium",
    "status": "todo",
    "assigneeAgentId": CONTENT,
    "parentId": PARENT,
    "projectId": PROJECT,
})

print("\n--- Done ---")
