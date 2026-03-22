import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMWM5NmRlYTctNzE3NC00MmUxLWIwOTUtNTk0MjYyZjY5NGMwIiwiaWF0IjoxNzc0MTA3Njc3LCJleHAiOjE3NzQyODA0NzcsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.Hw5XQW9PMBepbsWusIq2dS8WxS12WC7rfTFuRZQINmA"
RUN_ID = "1c96dea7-7174-42e1-b095-594262f694c0"
CID = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

review_desc = """## Self-Governing Review - Wave 15: Dead VFX Resurrection Sprint

### Condition Check
Self-governing condition: *Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc.*
Status: **Condition NOT yet met** -- the deepest audit yet found 11 fully-implemented VFXFacade methods that are NEVER CALLED from game code. This is the single largest dopamine gap remaining. Additional gaps: egg hatch has no anticipation animation, leaderboard toast has no fade tween, and loading screen has zero audio.

### What happened this heartbeat

#### Deep 10-Point Codebase Audit Results
Ran comprehensive audit covering SFX coverage, VFX coverage, UI tween coverage, config consumer coverage, loading screen, store/purchase flow, egg hatching, leaderboard, pet system, and driving HUD.

**Key findings from audit:**

Already strong:
- Loading screen visuals (gold glow, shimmer, sparkles, FOMO, tips)
- Pet equip/inventory (elastic bounce, rarity pulse, 3D entrance, badges)
- FailureFeedback, SpeedMilestone, WorldUnlock, RetentionController, SocialFeedConfig all wired
- 20/20 UI panels use TweenService
- 20/20 config files have runtime consumers
- Store has FOMO badges, purchase VFX, upgrade flash

Biggest remaining gap - **11 VFXFacade methods defined but never called:**
1. boostOverlay - speed boost has no visual overlay
2. speedRushOverlay - no edge-of-screen speed lines at high speed
3. lapFlash - completing a lap has zero visual fanfare
4. nearMissSpark - near-miss dodging has no spark/reward
5. worldTransition - world switching has no transition VFX
6. ambientStart/ambientStop - ambient world particles never start
7. carUnlockCelebration - no dedicated car unlock fanfare
8. statLevelUp - no per-stat level-up cascade
9. leaderboardRankFanfare - rank ups only show plain text toast
10. firstRunEntrance - first run of session has no dramatic entrance
11. serverDropFeedBanner - server-wide rare drops never shown

Other gaps:
- Egg hatch button: no anticipation wobble before reveal
- Leaderboard toast: no fade-in/fade-out tween
- Loading screen: zero audio (no ambient, no chimes, no ready sound)
- Engine loops: all rbxassetid://0 (no actual audio assets)

#### Agent Status
- **Engineer** (323fca23): 2 in_progress (POLA-173, POLA-164), 1 todo (POLA-131)
- **Bard** (b74e54ba): 1 todo (POLA-174)
- **Content Strategist** (0b51d97d): idle

#### Tasks Dispatched (4 total)

1. **POLA-176** (Engineer, high): Wire all 11 dead VFXFacade methods into natural call sites
   - boostOverlay, speedRushOverlay, lapFlash, nearMissSpark, firstRunEntrance in DrivingController
   - worldTransition in WorldPanel
   - ambientStart/Stop on drive start/end
   - leaderboardRankFanfare + toast tween
   - carUnlockCelebration + statLevelUp in StorePanel

2. **POLA-177** (Engineer, high): Egg hatch anticipation + leaderboard toast tween + loading screen SFX
   - Egg wobble/glow on hatch click before server response
   - Fade-in/scale-in/fade-out on rank-up toast
   - Loading screen ambient music + milestone chimes + ready sound

3. **POLA-178** (Bard, high): Design specs for speed rush overlay, lap flash, near-miss spark, ambient world particles
   - Per-world ambient particle parameters
   - Speed rush intensity curve and visual treatment
   - Near-miss spark style and combo system
   - Output: DrivingVFXDesignSpec.luau

4. **POLA-179** (Content Strategist, high): Near-miss celebration copy, streak counter text, loading screen audio brief
   - 10-15 near-miss popup variants
   - 5-8 streak headlines
   - 5-8 lap completion texts
   - Loading audio creative brief
   - Output: NearMissCopyConfig.luau

### Engineer Queue (after current work)
1. POLA-173 (in_progress) -- Per-rarity hatch crack phases
2. POLA-164 (in_progress) -- FirstTimeConfig + milestone celebrations
3. POLA-131 (todo) -- MicrocopyConfig consumers + session welcome
4. POLA-176 (todo) -- Wire 11 dead VFXFacade methods
5. POLA-177 (todo) -- Egg anticipation + leaderboard toast + loading SFX

### Remaining Future Work (after this wave)
- Audio asset upload pass (60+ sounds need Studio upload, all rbxassetid://0)
- serverDropFeedBanner wiring (needs server-side event for rare hatches)
- Near-miss XP/coin reward system (needs economy balancing)
- Speedometer needle animation (driving HUD visual upgrade)
- Speed text color gradient based on current velocity
- Auto-hatch / multi-hatch with stagger animation
- Pet fusion UI button in inventory
- NEW badge on recently-hatched unviewed pets"""

body = json.dumps({
    "title": "CEO: Self-Governing Review - Phase 4 Wave 15 Dead VFX Resurrection Sprint",
    "description": review_desc,
    "assigneeAgentId": CEO_ID,
    "parentId": PARENT_ID,
    "projectId": PROJECT_ID,
    "status": "done",
    "priority": "low",
    "comment": "Wave 15 self-governing review. Ran deepest audit yet -- found 11 VFXFacade methods that are fully implemented but never called from game code. Created 4 tasks to close the gap: POLA-176 (Engineer: wire dead VFX), POLA-177 (Engineer: egg anticipation + toast tween + loading SFX), POLA-178 (Bard: driving VFX design specs), POLA-179 (Content Strategist: near-miss copy + audio brief). Self-governing condition NOT yet met -- after these tasks complete, the game will have dramatically more dopamine per second of gameplay."
}).encode()

req = urllib.request.Request(
    API + "/api/companies/" + CID + "/issues",
    data=body, method="POST",
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer " + TOKEN,
        "X-Paperclip-Run-Id": RUN_ID
    }
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print("Created review:", resp.get("identifier", "?"), resp.get("title", "?"), "| status:", resp.get("status", "?"))
