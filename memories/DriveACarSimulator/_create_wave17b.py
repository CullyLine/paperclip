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
        print(f"Created: {data.get('id')} -- {payload['title']}")
        return data.get("id")
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

# 1. Bard: Payout screen monetization + inventory collection design
bard_task = create_issue({
    "title": "Bard: Payout Screen Monetization Surface + Inventory Collection Game + Daily Streak Loss Aversion Design Specs",
    "body": (
        "## Objective\n"
        "Design three high-revenue UI surfaces that are currently flat and transactional.\n\n"
        "### 1. Payout Screen as Monetization + Flex Surface\n"
        "The PayoutPanel shows run results but wastes the highest-dopamine moment in the game loop. Design:\n"
        "- **Staged coin rain**: rain should BUILD with the count-up, PEAK at the total reveal, BURST on personal best\n"
        "- **PB margin display**: '+12% vs last best!' with scaling celebration based on margin size\n"
        "- **Server rank flash**: 'You passed 3 players!' / '#1 this session!' for competitive flex\n"
        "- **Single high-intent CTA** at the emotional peak: '2x NEXT RUN - 25 gems' or 'Skip to next BP tier'\n"
        "- Button should appear AFTER the count-up finishes (when dopamine peaks), not before\n"
        "- Premium players see exclusive 'VIP Bonus: +15%' line item in the tally\n\n"
        "### 2. Inventory as a Collection Game\n"
        "Current inventory is a flat list. Redesign to make collecting feel like progress:\n"
        "- **Rarity-first pet cards**: border glow color by rarity, large rarity label, star rating\n"
        "- **Collection percentage**: 'You own 23/87 pets (26%)' with progress bar\n"
        "- **Per-rarity completion**: 'Common: 12/15, Rare: 5/20, Epic: 3/18, Legendary: 2/15, Mythic: 1/19'\n"
        "- **Missing pet silhouettes**: greyed out cards for pets you don't have with '???' name, drives completionism\n"
        "- **Best-in-slot highlight**: star badge on your strongest pet per slot\n"
        "- **Compare mode**: tap two pets to see side-by-side stat comparison with green/red delta arrows\n"
        "- **'Upgrade this' nudge**: if a pet can be obtained from an egg the player can afford, show 'Get more from [Egg]!' link\n\n"
        "### 3. Daily Streak Loss Aversion\n"
        "Current daily reward panel barely shows streak risk. Design:\n"
        "- **Broken streak visualization**: if player missed a day, show cracked/broken chain link animation\n"
        "- **Streak freeze purchase**: 'Save your streak! 50 gems' button with ice crystal VFX on the chain\n"
        "- **Premium daily preview for F2P**: show greyed-out premium rewards with 'Get Roblox Premium for 2x daily!' CTA\n"
        "- **Streak milestones on the calendar**: gold borders at 7/14/30/60/100 days, reward chest icon\n"
        "- **Close-to-milestone urgency**: 'Just 2 more days to your 14-day chest!'\n\n"
        "### Deliverables\n"
        "Write as `return nil` design spec .luau files:\n"
        "- `DACStarterGui/PayoutMonetizationDesignSpec.luau`\n"
        "- `DACStarterGui/InventoryCollectionDesignSpec.luau`\n"
        "- `DACStarterGui/DailyStreakDesignSpec.luau`\n\n"
        "Same format as existing specs. Full timing, color hex, tween params, sound cue names."
    ),
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": BARD,
    "parentId": PARENT,
    "projectId": PID,
    "goalId": None
})

# 2. Content Strategist: Payout copy + collection copy + streak copy + egg pity copy
cs_task = create_issue({
    "title": "Content Strategist: Payout Flex Copy + Collection Progress Lines + Streak FOMO + Egg Pity Transparency Copy",
    "body": (
        "## Objective\n"
        "Write all the copy for upcoming revenue-driving surfaces.\n\n"
        "### 1. Payout Flex Copy\n"
        "Create `DACReplicatedStorage/Config/PayoutFlexConfig.luau` with:\n"
        "- PB celebration lines per margin bracket: barely beat (0-5%), solid beat (5-20%), crushed it (20%+)\n"
        "- Server rank lines: 'You climbed past X players!', 'You are #1 this session!'\n"
        "- CTA copy pools for boost upsell: '2x your next run!', 'Double down!', 'Invest in speed!'\n"
        "- VIP bonus line: 'VIP Bonus: +15% coins applied'\n"
        "- Consolation lines for bad runs: 'Rough one. Try a boost?', 'Every run counts toward your streak!'\n\n"
        "### 2. Collection Progress Copy\n"
        "Create `DACReplicatedStorage/Config/CollectionProgressConfig.luau` with:\n"
        "- Percentage milestone lines: 25% ('Quarter of the way!'), 50% ('Halfway there!'), 75%, 90%, 100%\n"
        "- Missing pet tease lines: '??? - Found in [Egg Name]', 'Something rare lurks here...'\n"
        "- Rarity completion celebration lines per tier\n"
        "- Compare flavor text: 'This pet is X% stronger!', 'Consider upgrading...'\n\n"
        "### 3. Streak FOMO Copy\n"
        "Create `DACReplicatedStorage/Config/StreakFOMOConfig.luau` with:\n"
        "- Broken streak lines: 'Your streak was broken!', 'You lost your X-day streak...'\n"
        "- Streak repair CTA: 'Save it for 50 gems!', 'Don\\'t let it end!', 'Freeze your streak!'\n"
        "- Close-to-milestone lines: 'Just X more days!', 'You\\'re so close to the X-day chest!'\n"
        "- Premium daily upsell: 'Premium players get 2x daily rewards!', 'Unlock the premium track!'\n\n"
        "### 4. Egg Pity Transparency Copy\n"
        "Create `DACReplicatedStorage/Config/EggPityConfig.luau` with:\n"
        "- Pity counter display lines: 'X hatches until guaranteed [rarity]!'\n"
        "- Almost-there urgency: 'SO CLOSE! Just X more!', 'The odds are in your favor!'\n"
        "- Luck boost copy: 'Luck Boost active: +50% rare chance!', 'Fortune favors the bold!'\n"
        "- Post-pity celebration: 'The wait was worth it!', 'GUARANTEED!'\n\n"
        "### Deliverables\n"
        "All config files on disk as Luau modules returning tables. Follow existing config format."
    ),
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": CS,
    "parentId": PARENT,
    "projectId": PID,
    "goalId": None
})

print("\nWave 17b tasks created.")
