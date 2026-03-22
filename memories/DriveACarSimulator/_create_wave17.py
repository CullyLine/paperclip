import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZTA0ZTFhN2EtZmE1My00NDQwLWFjYTMtNWIzOWU2MmQ2NDQ5IiwiaWF0IjoxNzc0MTA4OTkxLCJleHAiOjE3NzQyODE3OTEsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.g_Dxso8qKmrnDJnJGWdBiFJfT8W_cvOzXTKNh7dNX7w"
RUN = "e04e1a7a-fa53-4440-aca3-5b39e62d6449"
CID = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
PID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
BARD = "b74e54ba-559a-49d9-933b-2978b1157f01"
CS = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
ENG = "323fca23-ecfa-4f35-aeb1-77f206eccf34"

HEADERS = {"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN}

def create_issue(payload):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(f"{API}/api/companies/{CID}/issues", data=body, method="POST", headers=HEADERS)
    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read().decode())
        print(f"Created: {data.get('id')} — {payload['title']}")
        return data.get("id")
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

# 1. Bard: Milestone Ceremony + FOMO Badge + Combo design specs
bard_task = create_issue({
    "title": "Bard: Milestone Ceremony UI Design + Store FOMO Badge System + Near-Miss Combo Reward Specs",
    "body": (
        "## Objective\n"
        "Design the **client-side celebration UI** for three milestone ceremony remotes that the server already fires but the client never shows. "
        "Also design Store FOMO badges and a near-miss combo reward moment.\n\n"
        "### 1. First-Time Ceremony UI Spec\n"
        "Server fires `FirstTimeCeremony` with `{milestoneKey, title, subtitle, description}` for events like first car purchase, first pet hatch, first rebirth, first world unlock, first leaderboard entry, first game pass purchase, first quest complete.\n\n"
        "Design a **full-screen moment** (2-3 seconds) with:\n"
        "- Large animated title text with glow/pulse\n"
        "- Subtitle beneath with fade-in delay\n"
        "- Rarity-scaled particle burst (more VFX for bigger milestones like first rebirth vs first quest)\n"
        "- Sound cue timing (impact hit > shimmer > whoosh out)\n"
        "- Background dim/vignette with radial light\n"
        "- Badge/icon that flies to a future achievement tray\n\n"
        "### 2. Spending Milestone Celebration Spec\n"
        "Server fires `SpendMilestone` when player crosses Robux spend thresholds ($5, $25, $50, $100, $250, $500). Design a **VIP recognition moment**:\n"
        "- Crown/diamond/star icon that scales based on tier\n"
        "- Metallic sheen title text per tier\n"
        "- Exclusive particle rain (coins for low, gems for mid, stars for high)\n"
        "- Screen-wide golden flash\n"
        "- Each tier must feel MORE impressive than the last\n\n"
        "### 3. Store FOMO Badge System Spec\n"
        "Design visual badges for store items:\n"
        "- **HOT** - red pulsing badge, fire particle trim\n"
        "- **LOW STOCK** - amber with countdown-style urgency animation\n"
        "- **BEST VALUE** - green with sparkle, slight scale bounce\n"
        "- **PREMIUM** - purple/gold gradient with shimmer sweep\n"
        "- **NEW** - cyan with pop-in spring animation\n"
        "- Badge placement: top-right corner of store item card, slight overhang\n"
        "- Timing: subtle looping animations that draw attention without being annoying\n\n"
        "### 4. Near-Miss Combo Reward Moment\n"
        "When player hits 3+ near-misses in a streak, design a **combo popup**:\n"
        "- Combo counter with escalating scale (x3 > x5 > x10)\n"
        "- Screen edge glow intensifies with streak\n"
        "- At x5: screen shake pulse\n"
        "- At x10: full confetti burst + LEGENDARY REFLEXES banner\n"
        "- Tie to bonus coin multiplier display (2x COINS!)\n\n"
        "### Deliverables\n"
        "Write each as a `return nil` design spec .luau file with full timing, color, sound cue, and tween details. Files:\n"
        "- `DACStarterGui/MilestoneCeremonyDesignSpec.luau`\n"
        "- `DACStarterGui/StoreFOMOBadgeDesignSpec.luau`\n"
        "- `DACStarterGui/NearMissComboDesignSpec.luau`\n\n"
        "Use the same format as existing specs (e.g. `FailureFeedbackDesignSpec.luau`, `PayoutTierUpSpec.luau`)."
    ),
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": BARD,
    "parentId": PARENT,
    "projectId": PID,
    "goalId": None
})

# 2. Content Strategist: Copy for milestone ceremonies, combo rewards, FOMO badges, achievement popups
cs_task = create_issue({
    "title": "Content Strategist: Milestone Ceremony Copy + FOMO Badge Labels + Combo Celebration Lines + Achievement Popup Text",
    "body": (
        "## Objective\n"
        "Write **all** the copy that fuels the new dopamine systems being designed.\n\n"
        "### 1. First-Time Ceremony Copy (config module)\n"
        "We already have `FirstTimeConfig.luau` with `title/subtitle/description` per milestone key. "
        "Review and ADD copy for any missing milestone keys. Make sure each one feels like a celebration moment, not just an info toast. "
        "The copy should make the player feel like they unlocked something special. Use power words: UNLOCKED, ACHIEVED, LEGENDARY, etc.\n\n"
        "### 2. Spending Milestone Copy\n"
        "Write copy for each Robux spend tier ($5, $25, $50, $100, $250, $500) in `FirstTimeConfig.luau` under `SpendMilestones`. "
        "Each tier needs: title (e.g. 'Rising Star', 'Benefactor', 'VIP', 'Diamond Patron', 'Legendary Whale', 'Mythic Overlord'), "
        "subtitle (flattering acknowledgment), description (exclusive/powerful feeling). "
        "Make each tier feel distinctly MORE prestigious.\n\n"
        "### 3. Daily Streak Milestone Copy\n"
        "Review and enhance the streak milestone copy in `FirstTimeConfig.luau` at thresholds 3/7/14/30/60/100 days. "
        "Add FOMO elements: 'Don't break your streak!' / 'Only 2% of players reach this!' etc.\n\n"
        "### 4. Store FOMO Badge Labels\n"
        "Create a new config `DACReplicatedStorage/Config/StoreFOMOConfig.luau` with:\n"
        "- Badge label text pools for HOT, LOW_STOCK, BEST_VALUE, PREMIUM, NEW\n"
        "- Tooltip/subtitle text for each badge type (e.g. 'Trending with top players!', 'Only 3 left at this price!')\n"
        "- Urgency copy for limited-time items (e.g. 'Vanishes in 2h!', 'Last chance!')\n\n"
        "### 5. Near-Miss Combo Lines\n"
        "Create `DACReplicatedStorage/Config/NearMissComboConfig.luau` with:\n"
        "- Combo tier headlines for x3, x5, x7, x10+ (escalating excitement)\n"
        "- Flavor text pools per tier (x3: 'Nice reflexes!', x5: 'DANGER ZONE!', x10: 'UNTOUCHABLE!')\n"
        "- Bonus multiplier announcement lines (e.g. 'DOUBLE COINS ACTIVATED!')\n\n"
        "### 6. Achievement Popup Lines\n"
        "Create `DACReplicatedStorage/Config/AchievementPopupConfig.luau` with:\n"
        "- Generic achievement unlock headlines pool\n"
        "- Per-category flavor text: Speed, Collection, Economy, Social, Mastery\n"
        "- Rare achievement special lines (for achievements < 5% of players have)\n\n"
        "### Deliverables\n"
        "All config files on disk. Each config must be a Luau module returning a table. "
        "Follow the format of existing configs like `NearMissCopyConfig.luau` and `SpeedMilestoneConfig.luau`."
    ),
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": CS,
    "parentId": PARENT,
    "projectId": PID,
    "goalId": None
})

# 3. Engineer: Wire milestone ceremony client handlers + fix spend payload + combo reward system
eng_task = create_issue({
    "title": "Engineer: Wire Milestone Ceremony Client Handlers + Fix SpendMilestone Payload + Near-Miss Combo Reward System",
    "body": (
        "## Objective\n"
        "The server fires `FirstTimeCeremony`, `SpendMilestone`, and `StreakMilestone` remotes via `MilestoneCeremonyService.luau`, "
        "but **no client code listens to them**. Wire up the client side so players actually SEE these celebrations.\n\n"
        "### 1. Fix MilestoneCeremonyService SpendMilestone payload\n"
        "In `DACServerScriptService/Services/MilestoneCeremonyService.luau`, `recordRobuxSpend` looks for `row.celebration` "
        "but `FirstTimeConfig.SpendMilestones` uses `title` / `subtitle` / `description`. Fix the server to send the correct fields.\n\n"
        "### 2. Wire checkStreakMilestones\n"
        "`MilestoneCeremonyService.checkStreakMilestones` exists but is never called. Wire it into `DailyRewardService` "
        "when the player claims their daily reward (after updating the streak counter).\n\n"
        "### 3. Wire missing first-time triggers\n"
        "- `FirstLeaderboardEntry`: fire from `LeaderboardService` when player first appears on any leaderboard\n"
        "- `FirstGamePassPurchase`: fire from `PremiumService` when player buys their first game pass\n\n"
        "### 4. Client-side ceremony handler (VFXController)\n"
        "Add three `OnClientEvent` handlers in `VFXController` (or a new `CeremonyController`):\n"
        "- `FirstTimeCeremony`: full-screen title animation (title text scales in with bounce, subtitle fades in 0.3s later, "
        "background dims to 50% black, particle burst behind text, auto-dismiss after 3s). Use VFXFacade pattern.\n"
        "- `SpendMilestone`: golden variant of same animation, with tier-scaled particle intensity. "
        "Higher tiers get more particles, bigger text, longer duration (up to 4s for $500 tier).\n"
        "- `StreakMilestone`: similar animation with streak-count emphasis, fire/flame particles for long streaks.\n\n"
        "### 5. Near-Miss Combo Reward System\n"
        "In `DACStarterPlayerScripts/Controllers/DrivingController.luau`:\n"
        "- Track consecutive near-misses as a combo counter (reset on collision or 5s without near-miss)\n"
        "- At combo x3: show combo counter UI, play escalating SFX\n"
        "- At combo x5: screen edge glow + screen shake\n"
        "- At combo x10: confetti burst + LEGENDARY REFLEXES banner + 2x coin bonus for 10 seconds\n"
        "- Fire `NearMissCombo` remote to server for the coin bonus multiplier\n"
        "- Server side: add `NearMissCombo` handler in `RunService` that applies a temporary coin multiplier\n\n"
        "### 6. Wire unused SpeedMilestoneConfig fields\n"
        "In `DACStarterGui/DrivingHUD.luau`, wire `FlexText` (FOMO text shown to other players) and `MilestoneColor` "
        "(use as the color for the speed number text when at/above that milestone threshold).\n\n"
        "### 7. Wire SpeedTierCopyConfig\n"
        "In `DACStarterGui/DrivingHUD.luau`, add a speed tier name label (e.g. 'HYPERSONIC') below the speed number "
        "that updates based on current speed, using `SpeedTierCopyConfig` tiers. Also show acceleration callout text briefly when tier changes.\n\n"
        "### Files to modify\n"
        "- `DACServerScriptService/Services/MilestoneCeremonyService.luau` (fix spend payload)\n"
        "- `DACServerScriptService/Services/DailyRewardService.luau` (wire streak check)\n"
        "- `DACServerScriptService/Services/LeaderboardService.luau` (first leaderboard entry)\n"
        "- `DACServerScriptService/Services/PremiumService.luau` (first game pass purchase)\n"
        "- `DACStarterPlayerScripts/Controllers/VFXController.luau` or new CeremonyController (client handlers)\n"
        "- `DACStarterPlayerScripts/Controllers/DrivingController.luau` (combo system)\n"
        "- `DACServerScriptService/Services/RunService.luau` (combo multiplier)\n"
        "- `DACStarterGui/DrivingHUD.luau` (speed tier name + unused config fields)\n"
        "- `DACReplicatedStorage/Remotes.luau` (add NearMissCombo remote if needed)\n\n"
        "Wait for Bard's design specs (MilestoneCeremonyDesignSpec, NearMissComboDesignSpec) before implementing the VFX side. "
        "You can start with server-side fixes (items 1-3) and DrivingHUD wiring (items 6-7) immediately."
    ),
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": ENG,
    "parentId": PARENT,
    "projectId": PID,
    "goalId": None
})

print("\nAll tasks created.")
