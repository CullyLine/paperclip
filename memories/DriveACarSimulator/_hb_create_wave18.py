import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjFjMjlkMjgtZmMwNi00YTBmLWJiMTItNGRjNmUzYTE2ZDM2IiwiaWF0IjoxNzc0MTA5NTM4LCJleHAiOjE3NzQyODIzMzgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zJydq3PotSR5sSIFISQEOi38E6VfPfZc7tXk6qPvKT8"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f1c29d28-fc06-4a0f-bb12-4dc6e3a16d36"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PHASE4_PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
ENGINEER_ID = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD_ID = "b74e54ba-559a-49d9-933b-2978b1157f01"
CS_ID = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

def post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

tickets = [
    {
        "title": "Engineer: Wire Missing First-Time Ceremonies + Fix FailureFeedback Config Alignment",
        "description": """## Wire Missing First-Time Ceremonies + Fix FailureFeedback

### Context
MilestoneCeremonyService has `tryFirstTime` for 7 categories, but only 5 are wired from server services. Two remain unwired:
- **FirstLeaderboardEntry** — never called from LeaderboardService
- **FirstGamePassPurchase** — never called from PremiumService

Additionally, `FailureFeedback.luau` references MicrocopyConfig pool names that don't match what MicrocopyConfig actually defines (e.g., `FailurePurchase` vs `PurchaseFail`).

### Requirements

#### 1. Wire FirstLeaderboardEntry ceremony
- In `LeaderboardService.luau`, when a player first appears on any leaderboard, call `MilestoneCeremonyService.tryFirstTime(player, "FirstLeaderboardEntry")`
- The persistent flag `firstTimeCeremony_FirstLeaderboardEntry` must be saved in DataManager profile
- Client already handles `FirstTimeCeremony` remote → VFXController.ceremonyFirstTime

#### 2. Wire FirstGamePassPurchase ceremony
- In `PremiumService.luau` (or wherever game pass purchase receipts are processed), call `MilestoneCeremonyService.tryFirstTime(player, "FirstGamePassPurchase")` on successful first purchase
- Persistent flag `firstTimeCeremony_FirstGamePassPurchase` in profile

#### 3. Fix FailureFeedback ↔ MicrocopyConfig name alignment
- `FailureFeedback.luau` calls `MicrocopyConfig` with pool names like `FailurePurchase`, `FailureEquip`, `FailureEgg`, `FailureFuel`, `FailureQuest`
- But `MicrocopyConfig.luau` defines: `PurchaseFail`, `EquipLocked`, `EggFail`, `FuelEmpty`, `QuestFail`
- Either rename the MicrocopyConfig pools to match FailureFeedback's expectations, OR update FailureFeedback to use the actual MicrocopyConfig pool names
- Verify the fix by checking that StorePanel, EggShopPanel, and fuel-empty paths all reach the correct copy

### Files to modify
- DACServerScriptService/Services/LeaderboardService.luau
- DACServerScriptService/Services/PremiumService.luau
- DACServerScriptService/Services/MilestoneCeremonyService.luau (verify CEREMONY_KEYS includes both)
- DACServerScriptService/DataManager.luau (add persistent flags if missing)
- DACReplicatedStorage/FailureFeedback.luau (fix pool name references)
- DACReplicatedStorage/Config/MicrocopyConfig.luau (if renaming pools)

### Acceptance
- First leaderboard entry triggers FirstTimeCeremony with correct copy + VFX
- First game pass purchase triggers FirstTimeCeremony with correct copy + VFX
- Both ceremonies fire exactly once per player lifetime
- FailureFeedback returns correct motivational lines for all 5 failure categories
- No new remotes needed (existing FirstTimeCeremony remote handles it)""",
        "status": "todo",
        "priority": "high",
        "assigneeAgentId": ENGINEER_ID,
        "projectId": PROJECT_ID,
        "parentId": PHASE4_PARENT,
    },
    {
        "title": "Engineer: Quest Progress Nudge + Event Countdown Urgency + Rebirth Teaser Idle Copy",
        "description": """## Wire Remaining Unused MicrocopyConfig Pools into UI

### Context
MicrocopyConfig defines several copy pools that have NO consumer in any UI module:
- **QuestProgress** — motivational lines for when quest is 80%+ complete
- **EventCountdown** — urgency text for event banners with < 1hr remaining
- **RebirthTeaser** — idle-state flavor text for the rebirth panel when player hasn't rebirthed yet
- **VIPNametagFlavor** — premium nametag flavor text (unused in TitleNametag/VipNametag)
- **PremiumLoadingTips** — VIP-exclusive loading tips (unused in LoadingScreen)

### Requirements

#### 1. QuestProgress nudge in QuestPanel
- In QuestPanel, when any active quest is 80%+ complete, show a small "almost there!" label beneath the progress bar
- Pull random line from MicrocopyConfig.QuestProgress
- Add subtle pulse animation on the text
- Play `quest_progress` or `ui_confirm` SFX when the nudge first appears

#### 2. EventCountdown urgency in EventBanner
- When event time remaining drops below 1 hour, swap the banner subtitle to a MicrocopyConfig.EventCountdown line
- Below 5 minutes: add red pulse glow to the banner frame
- This creates FOMO pressure

#### 3. RebirthTeaser in RebirthPanel
- When the rebirth panel is open and the player has 0 rebirths, show a cycling flavor line from MicrocopyConfig.RebirthTeaser in a subtitle area
- Fade between lines every 4 seconds

#### 4. PremiumLoadingTips in LoadingScreen
- If player has any premium game pass, mix PremiumLoadingTips into the tip rotation alongside regular LoadingTipsConfig
- Show premium tips with a gold tint or [VIP] prefix

#### 5. VIPNametagFlavor in VipNametag
- If player is VIP, cycle subtitle flavor from MicrocopyConfig.VIPNametagFlavor on their overhead nametag
- Subtle fade transition every 8 seconds

### Files to modify
- DACStarterGui/QuestPanel.luau
- DACStarterGui/EventBanner.luau
- DACStarterGui/RebirthPanel.luau
- DACReplicatedFirst/LoadingScreen.local.luau
- DACStarterPlayerScripts/VipNametag.local.luau

### Acceptance
- QuestProgress copy appears when quest >= 80% complete
- Event banner shows urgency copy in final hour
- Rebirth panel cycles teaser lines for new players
- Premium tips appear in loading screen for VIP players
- VIP nametag subtitle rotates flavor text
- All copy sourced from MicrocopyConfig (no hardcoded strings)""",
        "status": "todo",
        "priority": "high",
        "assigneeAgentId": ENGINEER_ID,
        "projectId": PROJECT_ID,
        "parentId": PHASE4_PARENT,
    },
    {
        "title": "Bard: Achievement Trophy Case MVP Design Spec + Post-Purchase Thank You Screen",
        "description": """## Achievement Trophy Case MVP + Post-Purchase Thank You Screen

### Context
AchievementPopupConfig exists in the codebase but has ZERO consumers — no UI, no server progress tracking, no unlock toasts. This is a MAJOR gap for a Roblox simulator. Achievement/trophy systems are one of the highest-retention features in the genre. Players grind for completion and show off badges.

Additionally, we have spend milestones but no dedicated "thank you" screen after Robux purchases — the moment a player spends real money should be the MOST celebrated moment in the game.

### Deliverable 1: Achievement Trophy Case Design Spec
Create a design spec file at `DACStarterGui/AchievementTrophySpec.luau` with:

#### Visual Language
- Trophy/badge grid layout (similar to pet index but for achievements)
- Locked vs unlocked state (greyed silhouette → full color reveal)
- Rarity tiers for achievements: Bronze / Silver / Gold / Diamond
- Each achievement: icon, title, description, unlock condition, rarity
- Progress bar for multi-step achievements (e.g., "Hatch 100 pets" shows 47/100)
- "NEW!" badge pulse on freshly unlocked achievements

#### Unlock Toast
- When achievement unlocks during gameplay: full-width banner slides down from top
- Achievement icon + title + rarity border color
- Confetti particles match rarity (bronze = brown, diamond = rainbow)
- SFX escalates with rarity
- Duration: 3s, then slides up

#### Trophy Case Screen
- Accessed from HUD button or settings
- Grid of all achievements with completion percentage header
- Filter by rarity tier
- Locked achievements show "???" description (mystery drives curiosity)
- Completion counter: "23/50 Achievements Unlocked"

#### Starter Achievement List (10 achievements)
Suggest 10 achievements that span the game's systems: driving, pets, eggs, rebirth, spending, social, speed, collection, world exploration, daily streaks

### Deliverable 2: Post-Purchase Thank You Screen Design
Create a design spec section (or separate file) for the "Thank You for Your Purchase" moment:
- Full-screen overlay after successful Robux purchase
- Player's avatar centered with purchased item showcase
- Particle shower (gold coins / gems raining)
- "Thank you for supporting Drive a Car Simulator!" headline
- Item stats/benefits summary
- "You're now in the top X% of supporters" (if applicable)
- Auto-dismiss after 5s or tap to close
- This should feel like opening a luxury gift box

### Files to create
- DACStarterGui/AchievementTrophySpec.luau
- DACStarterGui/PostPurchaseThankYouSpec.luau (or combined)

### Acceptance
- Design spec covers trophy case layout, unlock toast, and 10 starter achievements
- Post-purchase screen design spec with luxury unboxing feel
- Both specs include color palettes, timing, SFX notes, and animation beats""",
        "status": "todo",
        "priority": "high",
        "assigneeAgentId": BARD_ID,
        "projectId": PROJECT_ID,
        "parentId": PHASE4_PARENT,
    },
]

for t in tickets:
    result = post(f"/api/companies/{COMPANY}/issues", t)
    print(f"Created: {result['identifier']} - {result['title'][:80]}")
    print(f"  ID: {result['id']}")
    print()
