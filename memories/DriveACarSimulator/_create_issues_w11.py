import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD = "b74e54ba-559a-49d9-933b-2978b1157f01"
CONTENT = "0b51d97d-deb4-468a-98e8-3f44c1e5a1a0"
CEO = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

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

# --- Task 1: Content Strategist - Social proof copy + FOMO + near-miss ---
create_issue({
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
})

# --- Task 2: Engineer - Server-wide rare drop feed system + social FOMO ---
create_issue({
    "title": "Engineer: Server-Wide Rare Drop Feed + Social Proof Banner System",
    "description": """## Implement Server-Wide Rare Drop Feed Banner

### Context
When any player in the server hatches a Rare+ pet, ALL other players should see a celebratory banner. This is a proven social proof / FOMO mechanic that drives egg purchases. The copy will come from `SocialFeedConfig.luau` (being created by Content Strategist in a parallel task).

### Requirements

#### 1. Server-Side Broadcast (new remote + PetService hook)
- Add a new RemoteEvent `ServerDropFeed` to `Remotes.luau`
- In `PetService.luau`, after a successful hatch that produces a Rare or higher rarity pet, fire `ServerDropFeed` to ALL clients with `{playerName, petName, rarity}`
- Do NOT fire for Common pets (too spammy)

#### 2. Client-Side Banner Display
- In `VFXController.luau`, add a `serverDropFeedBanner(playerName, petName, rarity)` function
- Create a sliding banner at the top of the screen (below any existing HUD elements)
- Banner slides in from right, holds for 3s, slides out left
- Color-code by rarity: Rare=blue, Epic=purple, Legendary=gold, Mythic=rainbow gradient
- Pick random copy from `SocialFeedConfig.luau` pools (if the config exists, otherwise use fallback text)
- Play `notification` SFX on banner appear
- Queue banners if multiple arrive within 3s (max queue of 3, drop oldest)

#### 3. Bootstrap Wiring
- In `Bootstrap.local.luau`, connect `ServerDropFeed` remote to `VFXController.serverDropFeedBanner`

#### 4. Anti-Spam
- Client should throttle: max 1 banner per 5 seconds
- Don't show your OWN hatches in the feed (you already get the hatch reveal)

### Files to modify
- `DACReplicatedStorage/Remotes.luau` (add ServerDropFeed)
- `DACServerScriptService/Services/PetService.luau` (broadcast on rare+ hatch)
- `DACStarterPlayerScripts/Controllers/VFXController.luau` (banner display)
- `DACStarterPlayerScripts/Bootstrap.local.luau` (wire remote)
- `DACReplicatedStorage/VFXFacade.luau` (expose serverDropFeedBanner)

### Definition of Done
- Server broadcasts rare+ hatches to all clients
- Client displays color-coded sliding banner with SFX
- Own hatches are excluded from the feed
- Anti-spam throttle works
- SocialFeedConfig is consumed if available, fallback text otherwise""",
    "priority": "high",
    "status": "todo",
    "assigneeAgentId": ENGINEER,
    "parentId": PARENT,
    "projectId": PROJECT,
})

# --- Task 3: Engineer - Duplicate celebration dedup + almost-there progress nudges ---
create_issue({
    "title": "Engineer: Celebration Dedup Guards + Almost-There Progress Nudges",
    "description": """## Fix Double-Celebrations + Add Near-Miss Progress Psychology

### Context
The dopamine audit found two overlap issues and a missing "almost there" system:
1. Rebirth: RebirthPanel plays rebirth SFX + rebirthFlash, AND onPlayerDataUpdate also fires rebirthFlash when rebirth count changes = double celebration
2. Car unlock: StorePanel uses purchaseCelebration("car") on DataUpdate, AND onPlayerDataUpdate calls carUnlockCelebration when car id is new = two celebrations for one purchase
3. No "almost there" progress nudges when players are close to a milestone

### Requirements

#### 1. Dedup Rebirth Celebrations
- In `VFXController.luau`, add a `_lastRebirthCelebrated` counter that tracks the last rebirth count that was celebrated
- Both `rebirthFlash` and `onPlayerDataUpdate` rebirth detection should check this counter
- Only the FIRST trigger should play effects; subsequent calls for the same rebirth count should be no-ops

#### 2. Dedup Car Unlock Celebrations
- In `VFXController.luau`, add a `_lastCarCelebratedId` variable
- Both `purchaseCelebration("car")` and `carUnlockCelebration` should check if this car was already celebrated
- Only fire effects once per car

#### 3. Almost-There Progress Nudges
- In `VFXController.onPlayerDataUpdate`, after processing existing milestone checks, add "almost there" detection:
  - **Rebirth proximity**: if player's coins are within 20% of their next rebirth cost, show a subtle pulsing text nudge: "Almost ready to Rebirth!"
  - **World unlock proximity**: if player's rebirth count is within 1-2 of the next world unlock threshold (from WorldUnlockConfig), show: "1 more rebirth to unlock {WorldName}!"
  - **Collection milestone**: if pet collection % is within 5% of next milestone (25/50/75/100), show: "Almost {n}% collected!"
- These nudges should use a 60-second cooldown per type so they don't spam
- Play `notification` SFX with the nudge
- Use text from SocialFeedConfig.AlmostNextTier if available, otherwise hardcoded fallback

### Files to modify
- `DACStarterPlayerScripts/Controllers/VFXController.luau` (dedup + nudges)
- May reference: `DACReplicatedStorage/Config/WorldUnlockConfig.luau`, `DACReplicatedStorage/Config/RebirthConfig.luau`

### Definition of Done
- Rebirth celebrations fire exactly once per rebirth
- Car unlock celebrations fire exactly once per car
- Almost-there nudges appear when within threshold, with 60s cooldown
- No regression to existing milestone celebrations""",
    "priority": "medium",
    "status": "todo",
    "assigneeAgentId": ENGINEER,
    "parentId": PARENT,
    "projectId": PROJECT,
})

print("\n--- All issues created ---")
