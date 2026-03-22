import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYWU2YjdjOGUtZDUwZS00MmIzLTgyZjQtNDQ3Mjk3ZDBkYTNkIiwiaWF0IjoxNzc0MTEwNzczLCJleHAiOjE3NzQyODM1NzMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.3qB9sFfRJGo0Zt43F12ZYyE24XLz5KHl1vVIHvEICk0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "ae6b7c8e-d50e-42b3-82f4-447297d0da3d"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

body = {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 20 Final Config Gap Closure + Celebration Saturation",
    "description": """## Self-Governing Review - Wave 20 (2026-03-21)

### Situation
Self-governing active (condition: keep adding dopaminergic features). Inbox empty after POLA-198 (Wave 19 review). Ran deep codebase audit via subagent to identify ALL remaining dead config pools and uncelebrated action paths.

### Comprehensive Audit Results
Scanned all 16 Config files, 13 UI panels, 9 server services, 4 controllers, and 16 design spec files.

**Grand totals:**
- **35 config pools completely dark** across 9 config files
- **~263 authored copy variants** with zero runtime consumers
- **16 design specs**: 4 fully implemented, 7 partially implemented, 3 not implemented, 2 OK
- **~70 sound entries** all using placeholder `rbxassetid://0` (blocking for audio, but expected — real IDs come from Roblox Studio upload)

### Highest-Impact Gaps Found
1. **PayoutFlex** (24 brag lines) — run-end moment has VFX but no verbal validation. CRITICAL.
2. **StreakFOMO** (21 loss-aversion lines) — DailyRewardPanel has no streak warnings/losses. CRITICAL.
3. **ComboBreak** (12 lines) — near-miss combo vanishes silently. No loss feedback. HIGH.
4. **Pity Transparency** (28 lines) — egg pity glows but player doesn't understand why. HIGH.
5. **Purchase Celebration** — Robux purchases get generic text notification, no VFX/SFX. HIGH.
6. **Collection Progress** (28 lines) — pet collection has no granular journey text. HIGH.
7. **Lap Completion** (17 lines) — lap events have screen flash but no text toast. HIGH.
8. **Acceleration Callouts** (10 lines) — no burst detection for "LAUNCH! TURBO!" text. MEDIUM.
9. **Speed FlexText** (9 lines) — social proof rarity text dark at speed milestones. MEDIUM.
10. **EventExpiring FOMO** (6 lines) — highest-pressure scarcity copy completely dark. MEDIUM.
11. **FuelEmpty** (5 lines) — no failure feedback path for fuel depletion. MEDIUM.
12. **PremiumUpsell** (9 lines) — VIP upsell copy never surfaces to non-VIP players. MEDIUM.
13. **AchievementPopupConfig** (59 variants) — ENTIRE achievement system has no service/UI. Bard designing Trophy Case (POLA-193).

### Tickets Created (Wave 20)
- **POLA-199** → Engineer (CRITICAL): Wire PayoutFlex + StreakFOMO + ComboBreak + Pity Transparency — the 4 biggest dead copy pools
- **POLA-200** → Engineer (HIGH): Robux/GamePass Purchase VFX + Lap Text Toasts + Acceleration Callouts — 3 uncelebrated action paths
- **POLA-201** → Engineer (HIGH): Collection Progress + Speed FlexText + EventExpiring + FuelEmpty — final medium-priority config gaps
- **POLA-202** → Content Strategist (HIGH): Achievement Copy Audit + PremiumUpsell surface mapping + StreakFOMO copy review

### Current Pipeline
**Engineer (323fca23)**: POLA-164 (in_progress), POLA-131 (todo), now queued POLA-199 (critical), POLA-200, POLA-201
**Bard (b74e54ba)**: POLA-193 (in_progress) — Achievement Trophy Case design
**Content Strategist (0b51d97d)**: Idle → assigned POLA-202

### Self-Governing Condition Assessment
Condition: "Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc."

**Not yet met** — 263 authored copy variants remain disconnected from runtime. The run-end payoff moment (PayoutFlex), the strongest retention lever (StreakFOMO), the combo loss loop (ComboBreak), real-money purchases (no VFX), and the entire achievement system are all still dark. After Wave 20 + the existing pipeline complete, the remaining gap will primarily be:
1. Achievement Trophy Case implementation (pending POLA-193 Bard design)
2. PremiumUpsell wiring (pending POLA-202 Content Strategist recommendations)
3. Audio asset ID upload (requires Roblox Studio — not automatable from code)

Continuing to dispatch.""",
    "status": "done",
    "priority": "medium",
    "assigneeAgentId": CEO_ID,
    "projectId": PROJECT_ID,
    "parentId": PARENT_ID,
}

req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues",
    data=json.dumps(body).encode(), method="POST", headers=HEADERS)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(f'Created {resp["identifier"]}: {resp["title"][:80]}')
