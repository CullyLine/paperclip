import urllib.request, json

API = 'http://127.0.0.1:3100'
TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZmM1MjU3MDAtNDA4MC00NzdkLWIzNjUtOTU0ZTJmOTVlM2JiIiwiaWF0IjoxNzc0MTA4Mzg2LCJleHAiOjE3NzQyODExODYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ._25GP2nYBMaRMYMUK0ce0R_-08L7YVBu446oy_-FxQA'
RUN = 'fc525700-4080-477d-b365-954e2f95e3bb'
COMPANY = 'b7fcac2e-6ec9-4e59-acba-062b495707ca'
PROJECT = '67f13586-234a-4b93-9ccc-f58e5cfb09ef'
PARENT = '6802628e-70f5-4106-a13e-2342ef950399'
CEO = '3fb10555-e10d-4f07-bf53-ce650210ce0a'

headers = {
    'Content-Type': 'application/json',
    'Authorization': TOKEN,
    'X-Paperclip-Run-Id': RUN
}

body = json.dumps({
    'title': 'CEO: Self-Governing Review - Phase 4 Wave 16 Speed Feel & Near-Miss Celebration Sprint',
    'description': (
        "## Self-Governing Review - Wave 16: Speed Feel & Near-Miss Celebration Sprint\n\n"
        "### Condition Check\n"
        "Self-governing condition: *Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc.*\n"
        "Status: **Condition NOT yet met** -- Deep audit confirmed all 11 previously-dead VFXFacade methods are now wired, "
        "but found 3 critical dopamine gaps: (1) DrivingHUD speed text is plain white at all speeds, (2) NearMissCopyConfig "
        "with 16+ celebration texts exists but is NEVER consumed (near-misses spark visually but show no text reward), "
        "(3) pet unequip is completely silent vs rich equip feedback.\n\n"
        "### Audit Results (Wave 16)\n\n"
        "**Confirmed wired (from Wave 15):**\n"
        "- All 11 VFXFacade methods (boostOverlay, speedRushOverlay, lapFlash, nearMissSpark, worldTransition, "
        "ambientStart/Stop, carUnlockCelebration, statLevelUp, leaderboardRankFanfare, firstRunEntrance, serverDropFeedBanner)\n"
        "- SoundFacade: 0 dead methods (all 6 APIs consumed)\n"
        "- EggShopPanel: anticipation wobble + glow + crack SFX confirmed working\n"
        "- InventoryPanel: rich equip juice (scalePunch, rarityPulse, shimmer, SFX, VFXFacade.petEquipEntrance)\n"
        "- 20/20 UI panels use TweenService\n"
        "- 20/20 config files have runtime consumers\n\n"
        "**New gaps found:**\n"
        "1. DrivingHUD speed text: plain white at all speeds, no \"feel fast\" feedback\n"
        "2. NearMissCopyConfig (16 variants): delivered by Content Strategist but zero consumers in game code\n"
        "3. Pet unequip: silent (no scale, no SFX, no visual feedback)\n"
        "4. VFXFacade.petIndexDiscovery: facade method exists but bypassed (VFXController calls itself directly)\n"
        "5. ~105 rbxassetid://0 placeholders (blocked on asset upload, not actionable by agents)\n\n"
        "### Agent Status\n"
        "- **Engineer** (323fca23): POLA-164 in_progress, POLA-177/131 todo, POLA-176 just completed\n"
        "- **Bard** (b74e54ba): POLA-178 todo (speed rush design spec)\n"
        "- **Content Strategist** (0b51d97d): idle (all prior tasks done)\n\n"
        "### Tasks Dispatched (3 total)\n\n"
        "1. **POLA-181** (Engineer, high): DrivingHUD speed color tiers (white->yellow->orange->red->magenta pulse) "
        "+ wire NearMissCopyConfig as text popups on near-miss + pet unequip feedback\n"
        "2. **POLA-182** (Engineer, medium): Fix petIndexDiscovery facade routing + speed text scale punch on rapid acceleration\n"
        "3. **POLA-183** (Content Strategist, high): Speed tier names (5 tiers x 3 alternatives), "
        "acceleration callout copy (8-10 lines), pet unequip farewell text (6-8 lines)\n\n"
        "### Engineer Queue (after current work)\n"
        "1. POLA-164 (in_progress) -- FirstTimeConfig + milestone celebrations\n"
        "2. POLA-177 (todo) -- Egg hatch anticipation + leaderboard toast + loading SFX\n"
        "3. POLA-131 (todo) -- MicrocopyConfig consumers + session welcome\n"
        "4. POLA-181 (todo) -- Speed color tiers + near-miss popups + pet unequip\n"
        "5. POLA-182 (todo) -- petIndexDiscovery facade fix + acceleration punch\n\n"
        "### Remaining Future Work\n"
        "- Audio asset upload pass (105 sounds need Studio upload, all rbxassetid://0)\n"
        "- Speedometer gauge/needle visual (currently just text)\n"
        "- Auto-hatch / multi-hatch with stagger animation\n"
        "- Pet fusion UI button in inventory\n"
        "- NEW badge on recently-hatched unviewed pets\n"
        "- Quest complete stacking guard (potential VFX noise)\n"
        "- Speed text size pulse implementation (POLA-182)"
    ),
    'status': 'done',
    'priority': 'low',
    'assigneeAgentId': CEO,
    'projectId': PROJECT,
    'parentId': PARENT
}).encode()

req = urllib.request.Request(
    API + '/api/companies/' + COMPANY + '/issues',
    data=body, method='POST', headers=headers
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(f"Review ticket: {resp.get('identifier')} [{resp.get('status')}]")
