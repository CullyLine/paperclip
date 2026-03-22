import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZTMzNTNlNjktNzkzMS00Yzc5LTkyOTktOGIxNjQwMmM3NzA2IiwiaWF0IjoxNzc0MTA3MjU1LCJleHAiOjE3NzQyODAwNTUsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zC1cKO4uq9qGwxf9NwJWrm0JY7M3JOhv4wYoaceE_pw"
RUN_ID = "e3353e69-7931-4c79-9299-8b16402c7706"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
CEO = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN_ID,
}

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

# Create self-governing review ticket
review = api_post(f"/api/companies/{COMPANY}/issues", {
    "title": "CEO: Self-Governing Review - Phase 4 Wave 14 Final Dopamine Gap Closure Sprint",
    "description": """## Self-Governing Review - Wave 14: Final Dopamine Gap Closure

### Condition Check
Self-governing condition: Keep working on having them polish the game, and add lots of fun effects, dopamine-grabbing, etc.
Status: **Condition NOT yet met** — deep codebase audit revealed remaining dopamine gaps: PayoutPanel has 4 registered SFX keys never played, hatch crack phases don't vary by rarity, PlaytimeGemHUD award punch is basic, SettingsPanel has zero tweens, and TravelTeaser copy is dead data.

### What happened this heartbeat

#### Deep Codebase Audit Results
Ran comprehensive 13-point audit of all systems. Major findings:

**Already wired & functional (previous waves delivered):**
- FailureFeedback.luau — runtime module with 3+ consumers (VFXController, EggShopPanel, StorePanel)
- SpeedMilestoneConfig — wired into VFXController + DrivingHUD
- WorldUnlockConfig — partial (UnlockHeadlines + WorldFlavor used; TravelTeaser dead)
- RetentionController — fully wired, 15min idle detection, SocialFeedConfig integration
- SocialFeedConfig — 3 consumers (VFXController, StorePanel, RetentionController)
- RunResultsBridge — wired in PayoutPanel + UIController
- MicrocopyConfig — 11 runtime consumers
- FirstTimeConfig — wired via MilestoneCeremonyService (5 service integrations)
- CodesPanel — redemption celebration with MicrocopyConfig, SFX, rewardChestBurst

**Remaining gaps:**
1. PayoutPanel: 4 payout SFX keys registered but never called (`payout_card_pop`, `payout_badge_tick`, `payout_run_of_day`, `payout_tier_up`)
2. Hatch crack: One shared wobble for all rarities; RebirthHatchDesignSpec per-rarity phases not implemented
3. PlaytimeGemHUD: Basic award notification, no elastic scale punch
4. SettingsPanel: Zero TweenService usage
5. WorldUnlockConfig TravelTeaser: Dead data, zero consumers
6. Audio: 60+ registered sounds still `rbxassetid://0` (runtime hydration from ReplicatedStorage.Audio)

#### Agent Status
- **Engineer** (323fca23): idle → assigned POLA-172 + POLA-173
- **Bard** (b74e54ba): running POLA-168 → also assigned POLA-174
- **Content Strategist** (0b51d97d): running POLA-169

#### Tasks Dispatched (3 total)

1. **POLA-172** (Engineer, high): PayoutPanel SFX Wiring + PlaytimeGemHUD Award Punch + SettingsPanel Juice + TravelTeaser Consumer
   - Wire all 4 payout SFX keys at correct moments
   - Add BP tier-up detection + visual beat
   - PlaytimeGemHUD elastic scale punch + gem spin
   - SettingsPanel open/close tweens + toggle animations
   - TravelTeaser text on locked worlds in WorldPanel

2. **POLA-173** (Engineer, high): Per-Rarity Hatch Crack Phases from RebirthHatchDesignSpec
   - 5-tier crack system: Common (2s) → Mythic (7s)
   - Per-rarity wobble phases, crack patterns, glow colors, screen effects
   - Mythic = screen darken + full-screen flash + prismatic explosion

3. **POLA-174** (Bard, high): Hatch Crack Visual Language + Settings Micro-Interaction Design + Payout Tier-Up Moment
   - Per-rarity crack color palettes and patterns
   - SettingsPanel micro-interaction specs
   - Payout tier-up moment design

### Engineer Queue (after current work)
1. POLA-164 (in_progress) — FirstTimeConfig wiring
2. POLA-131 (todo) — MicrocopyConfig consumers
3. POLA-172 (todo) — PayoutPanel SFX + PlaytimeGem + Settings + TravelTeaser
4. POLA-173 (todo) — Per-rarity hatch crack phases

### Remaining Future Work
- Audio asset upload pass (60+ sounds need Studio/ReplicatedStorage.Audio upload)
- MicrocopyConfig pool coverage audit (some pools may have zero consumers)
- CodesPanel richer tiered celebration (currently moderate juice)
- Leaderboard social pressure / flex features
- Run near-miss lane effects polish""",
    "status": "done",
    "priority": "low",
    "assigneeAgentId": CEO,
    "projectId": PROJECT,
    "parentId": PARENT,
})
print(f"Created review: {review.get('identifier')}")
print("Done!")
