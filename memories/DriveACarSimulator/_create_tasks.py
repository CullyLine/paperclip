import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYTY1NmVjNGYtYjZmYi00N2ExLTk3N2UtMmQ5NDk0ZmFkNDFhIiwiaWF0IjoxNzc0MTAxNjQzLCJleHAiOjE3NzQyNzQ0NDMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.2m8HOz26XBqstRzNR1rhCAf-MBrgrwGFMspmBAQl9mw"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "a656ec4f-b6fb-47a1-977e-2d9494fad41a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
CONTENT = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"

def create(body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues", data=data, method="POST", headers=HEADERS)
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created: {resp.get('identifier', '?')} - {resp.get('title', '')[:60]}")
    return resp

# Task 1: Engineer - Wire MicrocopyConfig + Session Welcome + Payout Tally SFX
create({
    "title": "Engineer: Wire MicrocopyConfig Consumers + Session Welcome + Payout Tally SFX",
    "description": """## Wire MicrocopyConfig into UI + Session-start celebration + Payout coin tally SFX

### Context
`DACReplicatedStorage/Config/MicrocopyConfig.luau` was created in Wave 4 with rich dopamine text pools for codes, currency, events, playtime, premium, etc. but NO module currently requires or consumes it. This is the biggest dopamine gap remaining.

### Requirements

#### 1. Wire MicrocopyConfig into consuming modules
- **CodesPanel.luau**: On successful code redemption, pick a random string from `MicrocopyConfig.CodeRedeemSuccess` and display it. On error, use `CodeRedeemError`. On expired, use `CodeRedeemExpired`.
- **HUD.luau**: When showing `currencyPopup`, pick tier-appropriate text from `MicrocopyConfig.CoinGainSmall/Medium/Large` or `GemGain` based on amount thresholds.
- **EventBanner.luau** (if it exists): Use `EventBannerHeadlines` for rotating banner text.

#### 2. Bootstrap session-start celebration
- After initial `GetPlayerData` completes in `Bootstrap.local.luau`, fire `SoundFacade.playOneShot("notification")` and show a brief welcome toast via the notification system.
- If player has a daily streak, mention it in the welcome message.

#### 3. PayoutPanel coin tally SFX
- In `PayoutPanel.luau`, during the smoothstep coin count-up animation, play staggered `SoundFacade.playOneShot("currency")` ticks (every ~0.15s during the tally, max 8 ticks) to give the count-up a slot-machine feel.

#### 4. Wire premium_welcome sound
- In `VFXController.premiumWelcomeFanfare`, replace the generic `purchase` SFX with `premium_welcome` which is already registered but never played.

### Files to modify
- `DACStarterGui/CodesPanel.luau`
- `DACStarterGui/HUD.luau`  
- `DACStarterGui/PayoutPanel.luau`
- `DACStarterPlayerScripts/Bootstrap.local.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`

### Definition of done
- MicrocopyConfig is required and consumed in at least 3 modules
- Session start has audible+visual welcome
- Coin tally has rhythmic SFX
- premium_welcome sound is used in premiumWelcomeFanfare""",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": ENGINEER,
    "parentId": PARENT,
    "projectId": PROJECT
})

# Task 2: Engineer - Dead Sound Cleanup + BattlePass XP Tween + Rebirth Panel Polish
create({
    "title": "Engineer: Dead Sound Wiring + BattlePass XP Bar Tween + Rebirth Panel Polish",
    "description": """## Wire unused registered sounds + BattlePass XP bar animation + Rebirth panel celebration

### Context
Several sounds are registered in SoundController but never played. The BattlePass XP bar jumps instantly with no animation. The RebirthPanel is a UI stub that doesn't reinforce the massive rebirth moment.

### Requirements

#### 1. Wire dead sounds to their intended triggers
- **boost**: Play in `DrivingController` when boost is active (speed multiplier from game pass or consumable)
- **lap_horn**: Play in `VFXController.lapFlash` when a new lap begins
- **tab_switch**: Play in StorePanel and any other panel with tab bars when switching tabs
- **coin_pickup**: Play when coins are collected during a run (in DrivingController on coin pickup events if they exist, otherwise skip)

#### 2. BattlePass XP bar tween
- In `BattlePassPanel.luau`, when `barFill` is updated on `DataUpdate`, tween the Size.X from current to target over 0.4s with `Quad.Out` easing instead of instant set.
- When XP is above 90% of the next tier, add a subtle pulse glow to the bar fill.

#### 3. Rebirth Panel celebration reinforcement
- In `RebirthPanel.luau`, after a successful rebirth (detected via DataUpdate callback), show an in-panel "You are now Rebirth #N!" text with a scale-in tween.
- Add a brief stat preview showing what reset and what was gained.
- Play `rebirth_confetti` SFX from the panel (the VFXController rebirth flash handles the main VFX).

### Files to modify
- `DACStarterPlayerScripts/Controllers/SoundController.luau` (verify registrations)
- `DACStarterPlayerScripts/Controllers/DrivingController.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`
- `DACStarterGui/BattlePassPanel.luau`
- `DACStarterGui/RebirthPanel.luau`
- `DACStarterGui/StorePanel.luau` (tab_switch)

### Definition of done
- boost, lap_horn, tab_switch sounds play at appropriate moments
- BattlePass XP bar tweens smoothly
- RebirthPanel shows celebratory text after rebirth""",
    "status": "todo",
    "priority": "high",
    "assigneeAgentId": ENGINEER,
    "parentId": PARENT,
    "projectId": PROJECT
})

# Task 3: Content Strategist - Session Welcome Copy + Quest Panel Flavor Text
create({
    "title": "Content Strategist: Session Welcome Copy + Quest Flavor Text + Pet Index Celebration Copy",
    "description": """## Session welcome messages + Quest panel flavor text + Pet index celebration copy

### Context
Bootstrap session start currently has no welcome message. Quest panel rows are plain text with no personality. Pet Index panel shows % progress but has no celebration copy when milestones are hit.

### Requirements

#### 1. Session Welcome Messages
Add to MicrocopyConfig.luau:
- `SessionWelcome` pool: 8-10 fun welcome-back messages. Examples: "The road missed you!", "Time to burn rubber!", "Your pets were getting lonely..."
- `SessionWelcomeStreak` pool: 5 messages for players with active daily streaks. Include {STREAK} placeholder. Examples: "Day {STREAK} of domination!", "{STREAK}-day streak? You're UNSTOPPABLE!"

#### 2. Quest Panel Flavor Text  
Add to MicrocopyConfig.luau:
- `QuestComplete` pool: 8 one-liners shown when a quest completes. Examples: "CRUSHED IT!", "Another one bites the dust!", "Quest? More like CONQUERED!"
- `QuestProgress` pool: 5 encouragement lines for quests near completion (80%+). Examples: "Almost there...", "So close you can taste it!"

#### 3. Pet Index Milestones
Add to MicrocopyConfig.luau:
- `PetIndexMilestone` pool: 5 celebration lines for hitting collection milestones (25%, 50%, 75%, 100%). Include {PERCENT} placeholder. Examples: "{PERCENT}% collected! You're a PET LEGEND!", "Halfway there - keep hatching!"

#### 4. Rebirth Panel Copy
Add to MicrocopyConfig.luau:
- `RebirthCelebration` pool: 6 lines shown after rebirthing. Include {COUNT} placeholder. Examples: "Rebirth #{COUNT} complete! POWER SURGE!", "Born again, STRONGER than ever!"
- `RebirthTeaser` pool: 4 lines shown to tease players into rebirthing. Examples: "Your next rebirth unlocks INSANE power...", "Reset to rise HIGHER!"

### Style guidelines
- Keep the energetic, dopaminergic tone matching existing LoadingTipsConfig and MicrocopyConfig
- Use CAPS for emphasis words, not entire sentences
- Include appropriate placeholders for dynamic values
- All pools should be Luau table arrays of strings

### Files to modify
- `DACReplicatedStorage/Config/MicrocopyConfig.luau`

### Definition of done
- All 5 new text pools added to MicrocopyConfig
- Tone matches existing config style
- Placeholders documented in comments""",
    "status": "todo",
    "priority": "medium",
    "assigneeAgentId": CONTENT,
    "parentId": PARENT,
    "projectId": PROJECT
})

print("\nAll Wave 5 tasks created!")
