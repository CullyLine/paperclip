import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYWU2YjdjOGUtZDUwZS00MmIzLTgyZjQtNDQ3Mjk3ZDBkYTNkIiwiaWF0IjoxNzc0MTEwNzczLCJleHAiOjE3NzQyODM1NzMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.3qB9sFfRJGo0Zt43F12ZYyE24XLz5KHl1vVIHvEICk0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "ae6b7c8e-d50e-42b3-82f4-447297d0da3d"
PROJECT_ID = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT_ID = "6802628e-70f5-4106-a13e-2342ef950399"  # Phase 4 parent

ENGINEER_ID = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD_ID = "b74e54ba-559a-49d9-933b-2978b1157f01"
CS_ID = "0b51d97d-f321-4cb9-830c-892ec863fdf4"
CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"

HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def create_issue(title, description, assignee_id, priority="high"):
    body = {
        "title": title,
        "description": description,
        "status": "todo",
        "priority": priority,
        "assigneeAgentId": assignee_id,
        "projectId": PROJECT_ID,
        "parentId": PARENT_ID,
    }
    req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues",
        data=json.dumps(body).encode(), method="POST", headers=HEADERS)
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f'Created {resp["identifier"]}: {title[:80]}')
    return resp

# --- TICKET 1: Engineer - PayoutFlex + StreakFOMO + ComboBreak + Pity Text ---
t1 = create_issue(
    "Engineer: Wire PayoutFlex Brag Copy + StreakFOMO DailyReward + ComboBreak Feedback + Pity Transparency",
    """## Summary
Wire 4 of the highest-impact unused copy pools to their natural UI/controller consumer sites. These are the biggest dopamine gaps in the entire game.

## Deliverables

### 1. PayoutFlex copy on PayoutPanel (HIGHEST PRIORITY)
**File:** `DACStarterGui/PayoutPanel.luau`
**Config:** `MicrocopyConfig.PayoutFlexBig` (8), `PayoutFlexPersonalBest` (6), `PayoutFlexMultiplier` (5), `PayoutFlexRunOfDay` (5)

After the coin counter finishes animating, show a contextual brag text label:
- If coins > 10000: pick from `PayoutFlexBig`, replace `{COINS}` with actual count
- If `isPersonalBest`: pick from `PayoutFlexPersonalBest`
- If multiplier > 3: pick from `PayoutFlexMultiplier`, replace `{MULTIPLIER}`
- Default fallback: pick from `PayoutFlexRunOfDay`

Add a `TextLabel` beneath the coin total, tween it in with a slight scale bounce (1.0 → 1.15 → 1.0, 0.3s). Use `MicrocopyConfig.pickVariant()` if available, otherwise random selection.

### 2. StreakFOMO in DailyRewardPanel
**File:** `DACStarterGui/DailyRewardPanel.luau`
**Config:** `MicrocopyConfig.StreakFOMOWarning` (6), `StreakFOMOTomorrow` (5), `StreakFOMOLost` (5), `StreakFOMOMilestone` (5)

After the player claims their daily reward:
- Show `StreakFOMOTomorrow` with `{STREAK}` replaced → incentivize tomorrow's login
- If streak == 7 or 14 or 30: show `StreakFOMOMilestone` instead

When player opens DailyRewardPanel and streak > 3:
- Show `StreakFOMOWarning` as persistent subtitle text: "Your {STREAK}-day streak is ON THE LINE!"

When `hadLongBreak == true` (streak was reset):
- Show `StreakFOMOLost` with old streak count: "Streak BROKEN! You were at {STREAK} days..."

### 3. ComboBreak feedback in DrivingController
**File:** `DACStarterPlayerScripts/Controllers/DrivingController.luau`
**Config:** `ComboCelebrationConfig.ComboBreak` (6), `ComboBreakMotivation` (6)

When `nearMissStreak` resets (timer expiry), if the streak was >= 3:
- Fire a toast with `ComboBreak` text: "x{COMBO} combo broken! But you banked +{COINS}!"
- Below it, show `ComboBreakMotivation`: "Build it back! The next combo could be BIGGER!"
- Replace `{COMBO}` with the combo count, `{COINS}` with bonus coins earned
- Fire `SoundFacade.playOneShot("combo_break")` (register it if not registered: use `rbxassetid://0` placeholder)

### 4. Pity transparency text in EggShopPanel
**File:** `DACStarterGui/EggShopPanel.luau`
**Config:** `MicrocopyConfig.PityStatus` (4), `PityTier1` (5), `PityTier2` (5), `PityTier3` (6), `PityReset` (4), `PityExplainer` (4)

When `pityNoRareStreak` changes:
- 0-4 hatches: show `PityExplainer` as subtle tooltip near the hatch button
- 5-9 hatches (tier 1): show `PityTier1` text below egg display
- 10-14 hatches (tier 2): show `PityTier2` with brighter styling
- 15+ hatches (tier 3): show `PityTier3` with golden text + exclamation
- On rare+ hatch: briefly flash `PityReset` text before resetting

## Files on disk expected
- `DACStarterGui/PayoutPanel.luau`
- `DACStarterGui/DailyRewardPanel.luau`
- `DACStarterPlayerScripts/Controllers/DrivingController.luau`
- `DACStarterGui/EggShopPanel.luau`""",
    ENGINEER_ID,
    "critical"
)

# --- TICKET 2: Engineer - Purchase Celebration + Lap Toast + Accel Callouts ---
t2 = create_issue(
    "Engineer: Robux/GamePass Purchase VFX + Lap Completion Text Toasts + Acceleration Callouts",
    """## Summary
Wire celebration moments to 3 dead action paths: real-money purchases, lap completions, and hard acceleration.

## Deliverables

### 1. Robux/GamePass Purchase Celebration
**Files:** `DACServerScriptService/Services/DevProductService.luau`, `DACServerScriptService/Services/GamePassService.luau`

When a Robux purchase or GamePass purchase is confirmed, fire a client remote that triggers:
- `VFXFacade.purchaseCelebration()` (already exists)
- `SoundFacade.playOneShot("purchase")` (already registered)

In `DevProductService.processReceipt()`, after the success notification, fire:
```lua
Remotes.getEvent("PurchaseCelebration"):FireClient(player, { productName = productDef.name, price = productDef.price })
```

In `GamePassService.onGamePassPurchased()`, do the same.

In `VFXController`, listen for `PurchaseCelebration` and call `VFXFacade.purchaseCelebration()` + `SoundFacade.playOneShot("purchase")`.

Register "PurchaseCelebration" in `Remotes.luau` if not already there.

### 2. Lap Completion Text Toasts
**File:** `DACStarterPlayerScripts/Controllers/VFXController.luau`
**Config:** `NearMissCopyConfig.LapComplete` (6), `LapPersonalBest` (5), `LapHumor` (6)

When `VFXFacade.lapFlash()` fires:
- If `isPersonalBest`: show text from `LapPersonalBest` pool
- Else: 70% chance `LapComplete`, 30% chance `LapHumor`
- Show as a centered toast that tweens in (scale 0.8→1.0, fade 0→1, 0.3s) and fades out after 2s
- Replace `{TIME}` placeholder if present with formatted lap time

### 3. Acceleration Callouts
**File:** `DACStarterPlayerScripts/Controllers/DrivingController.luau`
**Config:** `SpeedTierCopyConfig.AccelerationCallouts` (10)

Add acceleration detection:
- Track `previousSpeed` each frame
- If `currentSpeed - previousSpeed > 30` studs/s in a single frame (or > 50 over 0.5s window):
  - Pick from `AccelerationCallouts` ("LAUNCH!", "TURBO!", "NITRO!", etc.)
  - Show as brief flash text near speedometer (0.5s duration, scale punch 1.0→1.3→1.0)
  - Cooldown: max once every 3 seconds to avoid spam
  - Fire `SoundFacade.playOneShot("boost")` (already registered)

## Files on disk expected
- `DACServerScriptService/Services/DevProductService.luau`
- `DACServerScriptService/Services/GamePassService.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`
- `DACStarterPlayerScripts/Controllers/DrivingController.luau`
- `DACReplicatedStorage/Remotes.luau` (if PurchaseCelebration remote added)""",
    ENGINEER_ID,
    "high"
)

# --- TICKET 3: Engineer - Collection Progress + Speed FlexText + EventExpiring ---
t3 = create_issue(
    "Engineer: Collection Progress Toasts + Speed FlexText + FomoBadge EventExpiring + FuelEmpty Feedback",
    """## Summary
Wire the remaining medium-priority dead config pools to their UI consumers. This is the final config gap closure pass.

## Deliverables

### 1. Collection Progress in InventoryPanel
**File:** `DACStarterGui/InventoryPanel.luau`
**Config:** `MicrocopyConfig.CollectionEarly/Mid/Late/Final/Complete/NewDiscovery`

When the player opens the inventory and has pets:
- Calculate collection % = uniquePetsOwned / totalPetsInGame
- 0-25%: show `CollectionEarly` subtitle
- 25-50%: show `CollectionMid` subtitle
- 50-75%: show `CollectionLate` subtitle
- 75-99%: show `CollectionFinal` subtitle
- 100%: show `CollectionComplete` subtitle
- Replace `{FOUND}`, `{TOTAL}`, `{PERCENT}` placeholders

When VFXController fires `petIndexDiscovery()`, show a toast from `CollectionNewDiscovery` replacing `{PET}` with the pet name.

### 2. Speed Milestone FlexText
**File:** `DACStarterPlayerScripts/Controllers/VFXController.luau`
**Config:** `SpeedMilestoneConfig.FlexText`

When `speedMilestone(speed)` fires, add a 1s delayed secondary text below the celebration text:
- Pick `FlexText` for the matching threshold
- Show in smaller, italicized text: "Only 40% of players hit triple digits!"
- Tween in with a subtle slide-up (Y offset 10→0, fade 0→1, 0.4s)

### 3. EventExpiring FOMO Badge in StorePanel
**File:** `DACStarterGui/StorePanel.luau`
**Config:** `FomoBadgeLabelConfig.EventExpiring` (6)

If any store item has an event badge with an expiry time:
- Show `EventExpiring` text replacing `{BADGE}` and `{TIME}` with badge name and countdown
- Use red/orange pulsing text color to convey urgency

Also wire:
- `EmptySlotCopy` (4): show on empty badge slots in badge profile view
- `FullCollectionCopy` (3): show when all badges collected

### 4. FuelEmpty Failure Feedback
**File:** `DACReplicatedStorage/FailureFeedback.luau`
**Config:** `MicrocopyConfig.FuelEmpty` (5)

Add a `fuelEmpty` feedback path:
- When fuel hits 0 and player tries to drive, show `FuelEmpty` text as a button-shake toast
- Wire it to the driving start flow — if fuel is empty, call `FailureFeedback.show("fuelEmpty")`

## Files on disk expected
- `DACStarterGui/InventoryPanel.luau`
- `DACStarterPlayerScripts/Controllers/VFXController.luau`
- `DACStarterGui/StorePanel.luau`
- `DACReplicatedStorage/FailureFeedback.luau`""",
    ENGINEER_ID,
    "high"
)

# --- TICKET 4: Content Strategist - Achievement system copy review + PremiumUpsell wiring points ---
t4 = create_issue(
    "Content Strategist: Achievement System Copy Audit + PremiumUpsell Wiring Points + SocialFeed PremiumUpsell Surface",
    """## Summary
The Achievement system (AchievementPopupConfig — 28 achievements, 5 copy pools, ~59 variants) is the LARGEST fully-dark config in the game. Bard is designing the Achievement Trophy Case (POLA-193). Your job is to audit the existing achievement copy for quality, completeness, and dopamine punch, then recommend surface points for PremiumUpsell (9 lines, also fully dark).

## Deliverables

### 1. Achievement Copy Audit
**File:** `DACReplicatedStorage/Config/AchievementPopupConfig.luau`

Review all 28 achievements across 5 categories (driving, collection, economy, social, secret):
- Are the titles punchy and memorable?
- Do descriptions clearly state what to do?
- Are the `UnlockToastLines` (6) exciting enough for a popup moment?
- Are the `CategoryComplete` (15) and `TotalCompletion` (5) lines celebratory enough?
- Are `ProgressNudge` (5) lines motivating enough?

Produce a markdown deliverable with:
- Quality score (1-5) for each pool
- Specific rewrite suggestions for any weak lines
- Any missing achievement ideas (max 5 new suggestions)

### 2. PremiumUpsell Surface Mapping
**File:** `DACReplicatedStorage/Config/SocialFeedConfig.luau` — `PremiumUpsell` (9 lines)

These 9 VIP upsell lines are completely dark. Map where they should appear:
- RetentionController popup (non-VIP players)
- Post-payout screen (when coins earned < VIP threshold)
- Loading screen tips (non-VIP variant)
- Daily reward claim (show VIP bonus preview)

Write a specific wiring recommendation for each surface point, including what triggers the upsell and when to suppress it (e.g., don't upsell right after a Robux purchase).

### 3. DailyStreakLossAversion Copy Review
**File referenced:** `DACStarterGui/DailyStreakLossAversionDesignSpec.luau`
**Config:** `MicrocopyConfig.StreakFOMO*` pools (21 variants across 4 pools)

The Engineer is wiring these in a parallel ticket. Review the copy for maximum loss-aversion punch:
- Is the warning urgent enough?
- Is the loss message painful enough?
- Is the tomorrow preview enticing enough?
- Are the milestone messages rewarding enough?

Produce specific rewrite suggestions if any line is weak.

## Format
Write all deliverables to a single markdown file at `DACReplicatedStorage/Config/AchievementCopyAuditReport.md` (or as a .luau comment block if preferred).

## Files on disk expected
- `DACReplicatedStorage/Config/AchievementCopyAuditReport.md` (or updated config files if rewrites are needed)""",
    CS_ID,
    "high"
)

print("\n--- Wave 20 Summary ---")
print(f"POLA-{t1['issueNumber']}: Engineer - PayoutFlex + StreakFOMO + ComboBreak + Pity (CRITICAL)")
print(f"POLA-{t2['issueNumber']}: Engineer - Purchase VFX + Lap Toast + Accel Callouts (HIGH)")
print(f"POLA-{t3['issueNumber']}: Engineer - Collection + FlexText + EventExpiring + FuelEmpty (HIGH)")
print(f"POLA-{t4['issueNumber']}: Content Strategist - Achievement Copy Audit + PremiumUpsell (HIGH)")
