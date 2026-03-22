import urllib.request, json

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMmY4Y2ZjMmItY2Y4My00NzliLWE4NDQtN2VlYTIzNTI2YWUxIiwiaWF0IjoxNzc0MTEzMTM2LCJleHAiOjE3NzQyODU5MzYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.fAyxpq_uICQflq0D6X-ACmyl4WoBOUpiFL9uvu8IqCM"
BASE = "http://127.0.0.1:3100"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "2f8cfc2b-cf83-479b-a844-7eea23526ae1"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

description = """## Self-Governing Review - Wave 23 (2026-03-21)

### Situation
Self-governing active (condition: keep adding dopaminergic features). Inbox empty after POLA-213 (Wave 22 review). Ran comprehensive 3-subagent parallel audit:
1. **Config consumer audit** - scanned all 27 config files + 44 remotes for dead/orphan wiring
2. **VFX/Sound dead code audit** - checked every facade/controller method for callers
3. **UI panel juice audit** - rated every panel's dopamine level (HIGH/MEDIUM/LOW/NONE)

### Comprehensive Audit Results

**Config Health: EXCELLENT**
- 0 dead configs — all 27 Lua config files are `require()`d by at least one runtime module
- No orphan configs remaining

**Remote Health: GOOD (2 dead, 2 one-sided)**
- Dead: `PurchaseCelebration`, `TradeRespond` (never referenced anywhere outside Remotes.luau)
- One-sided: `FusePets` (server handler exists, no client wiring), `AchievementProgress` (covered by POLA-211)
- Trade remotes intentionally deferred to M5

**VFX/Sound Health: EXCELLENT**
- 0 dead VFXFacade methods — all used
- 0 dead SoundFacade methods — all used
- 1 dead VFXController wrapper (`nearMissEdgeEnter`) — cleanup ticket created
- 3 deprecated SoundController methods (cleanup, not functional gap)

**UI Panel Juice Levels:**
- HIGH: 15 panels (HUD, StorePanel, EggShopPanel, InventoryPanel, PayoutPanel, DailyRewardPanel, CodesPanel, LeaderboardPanel, QuestPanel, WorldPanel, BattlePassPanel, RebirthPanel, PlaytimeGemHUD, TutorialOverlay, RewardChestAnimation)
- MEDIUM: 5 panels (DrivingHUD, EventBanner, SettingsPanel, PetIndexPanel, TrophyCasePanel)
- LOW: 1 (UIHelpers - shared chrome, acceptable)
- NONE: 2 (MenuHub, GuiBootstrap - infrastructure, acceptable)

**Critical Finding: DrivingHUD Audio Gap**
The core driving gameplay loop — where players spend 80% of their time — has `SoundFacade` imported but **zero** `playOneShot()` calls. Speed milestones, near-miss flashes, combo celebrations, and tier transitions are all visual-only. This is the single biggest remaining dopamine leak.

**FusePets Client Gap**
Bard designed fusion UI (POLA-207 done), server handler exists, but client never fires `FusePets` remote. Feature is designed but unwired.

### Tickets Created (Wave 23)
- **POLA-214** -> Engineer (HIGH): Wire DrivingHUD audio feedback for 5 driving moments + FusePets client UI wiring + dead code cleanup
- **POLA-215** -> Engineer (MEDIUM): Wire MicrocopyConfig StreakWarning timed nudges in RetentionController (6h/2h/30m thresholds + PlayStreak celebration)

### Current Pipeline After Wave 23
**Engineer (323fca23)**: 
  - POLA-210 (in_progress, HIGH): SocialFeedConfig server drop copy bug fix
  - POLA-164 (in_progress, HIGH): FirstTimeConfig consumers + milestones
  - POLA-131 (todo, HIGH): MicrocopyConfig consumers + session welcome + payout SFX
  - POLA-211 (todo, MEDIUM): AchievementProgress client handler + MilestoneColor
  - POLA-214 (todo, HIGH): DrivingHUD audio + FusePets client + dead code cleanup
  - POLA-215 (todo, MEDIUM): StreakWarning timed nudges
  - Total: 6 tickets (2 in_progress, 4 queued)

**Bard (b74e54ba)**: Idle (all design work complete)
**Content Strategist (0b51d97d)**: Idle (all copy work complete)

### Self-Governing Condition Assessment
Condition: 'Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc.'

**Not yet met** — Remaining dopaminergic gaps:
1. DrivingHUD has ZERO audio feedback during core gameplay (POLA-214 assigned)
2. FusePets feature designed but unwired — players can't fuse pets (POLA-214 assigned)
3. StreakWarning timed nudges unimplemented — 5 MicrocopyConfig pools unused (POLA-215 assigned)
4. SocialFeedConfig server drop copy bug still suppressing social proof text (POLA-210 in-progress)
5. FirstTimeConfig ceremonies not wired yet (POLA-164 in-progress)
6. MicrocopyConfig session welcome + payout SFX (POLA-131 queued)
7. AchievementProgress invisible to players (POLA-211 queued)

After current pipeline + Wave 23 completes, remaining gaps shrink to:
- Audio asset IDs (requires Roblox Studio upload — not automatable)
- Minor MEDIUM-juice panels could be elevated (EventBanner, PetIndexPanel, TrophyCasePanel)

Continuing to dispatch — condition NOT met."""

body = {
    "title": "CEO: Self-Governing Review - Wave 23 DrivingHUD Audio Gap + FusePets Wiring + Streak Nudges",
    "description": description,
    "priority": "medium",
    "status": "done",
    "assigneeAgentId": CEO_ID,
    "projectId": PROJECT_ID,
    "parentId": PARENT_ID
}

data = json.dumps(body).encode()
req = urllib.request.Request(
    f"{BASE}/api/companies/{COMPANY}/issues",
    data=data, method="POST", headers=HEADERS
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(f"Created review ticket: {resp['identifier']} - {resp['title'][:80]}")
