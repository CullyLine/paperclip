# Drive a Car Simulator — Daily Rewards, Launch Playbook & Update Roadmap

**Prepared by:** Content Strategist (POLA-11)
**Date:** March 20, 2026
**References:** CompetitiveAnalysis_EconomyDesign.md, GameCopy.md, DailyRewardService.luau, CodeService.luau

---

## Part 1: Daily Reward Schedule (7-Day Cycle)

### 1.1 Design Philosophy

The daily reward system serves three purposes:

1. **Retention hook** — give players a reason to open the game every single day
2. **Economy drip-feed** — provide meaningful free resources without undermining spending pressure
3. **Day 7 jackpot moment** — build anticipation across the week so the final reward feels genuinely exciting

The current code has basic ascending rewards. This redesign makes each day feel distinct by mixing currencies, escalating excitement, and building toward a Day 7 jackpot.

### 1.2 Reward Schedule

| Day | Reward | Currency | Amount | Rationale |
|-----|--------|----------|--------|-----------|
| **1** | Coins | coins | 1,000 | Low-friction welcome back. Enough for ~1 Meadow Egg hatch or partial car upgrade. |
| **2** | Gems | gems | 25 | Introduces premium currency early in the week. Teases gem-gated content. |
| **3** | Coins (larger) | coins | 3,000 | Midweek boost. Covers 1-2 egg purchases or several upgrade levels. |
| **4** | Coins + Gems combo | coins + gems | 2,000 coins + 50 gems | First multi-currency day. Feels generous, builds momentum toward Day 7. |
| **5** | Crystals | crystals | 10 | First crystal drop of the week. Scarce currency makes this feel special even at low quantity. |
| **6** | Gems (large) | gems | 100 | Second-best day. Big gem payout rewards commitment through the week. |
| **7** | **JACKPOT** | coins + gems + crystals | 10,000 coins + 200 gems + 25 crystals | The payoff. All three earnable currencies in one drop. Players screenshot this. |

**Weekly totals (free player):** 16,000 coins + 375 gems + 35 crystals

**Weekly totals (premium player, 2x):** 32,000 coins + 750 gems + 70 crystals

### 1.3 Streak Break Rules

- **Missed 1 day (24-48h since last claim):** Streak continues. No penalty. Life happens.
- **Missed 2+ days (48h+ since last claim):** Streak resets to Day 1. This creates soft urgency without punishing occasional absences.
- The 48-hour grace window is already implemented in `DailyRewardService.luau` — no code change needed for this behavior.

### 1.4 Post-Cycle Behavior: Escalating Reset

After completing Day 7, the cycle resets to Day 1 — but with a **cycle multiplier**:

| Cycle | Multiplier | Day 7 Jackpot Becomes |
|-------|------------|----------------------|
| 1 (Days 1-7) | 1.0x | 10,000 coins + 200 gems + 25 crystals |
| 2 (Days 8-14) | 1.25x | 12,500 coins + 250 gems + 31 crystals |
| 3 (Days 15-21) | 1.5x | 15,000 coins + 300 gems + 37 crystals |
| 4 (Days 22-28) | 1.75x | 17,500 coins + 350 gems + 43 crystals |
| 5+ (Days 29+) | 2.0x (cap) | 20,000 coins + 400 gems + 50 crystals |

**Why cap at 2.0x:** Uncapped escalation would eventually outpace the economy's intended drip rate. A 2x cap means dedicated daily players earn double the base rate at max — generous enough to feel rewarding, controlled enough to preserve spending pressure.

**Streak break resets cycle multiplier to 1.0x.** This is the real penalty for missing days — not losing a day of rewards, but losing your accumulated multiplier. Players who maintain a 28+ day streak feel genuinely rewarded.

### 1.5 Premium Daily Gift Box (Roblox Premium Members)

Premium players receive a **separate** daily gift box on top of their doubled streak reward. This is a distinct UI element styled as a golden gift box.

**Premium Gift Box Contents (random roll each day):**

| Roll Weight | Reward | Notes |
|-------------|--------|-------|
| 40% | 5,000 coins | Solid daily bonus |
| 25% | 50 gems | Premium gem drip |
| 15% | 10 crystals | Crystal access ahead of curve |
| 10% | 1 random egg (from current world) | Exciting RNG element — could be a Neon Egg for endgame players |
| 7% | Speed Boost consumable (2x speed, 1 run) | Useful QoL item |
| 3% | 5 skulls | Ultra-rare skull drop — makes premium feel exclusive |

**Design notes:**
- Gift box appears as a golden animated present in the Daily Reward UI, separate from the streak calendar
- Box opening should have a particle effect and dramatic reveal animation (similar to egg hatch)
- 3% skull chance is deliberately low — premium players will talk about it when it hits, creating word-of-mouth for both Premium and the skull currency
- The random egg roll uses the player's current world, so it scales with progression

### 1.6 DailyRewardService Code Update Summary

The current `STREAK_REWARDS` table in `DailyRewardService.luau` should be updated to:

```lua
local STREAK_REWARDS = {
    { rewards = {{ currency = "coins", amount = 1000 }} },
    { rewards = {{ currency = "gems", amount = 25 }} },
    { rewards = {{ currency = "coins", amount = 3000 }} },
    { rewards = {{ currency = "coins", amount = 2000 }, { currency = "gems", amount = 50 }} },
    { rewards = {{ currency = "crystals", amount = 10 }} },
    { rewards = {{ currency = "gems", amount = 100 }} },
    { rewards = {{ currency = "coins", amount = 10000 }, { currency = "gems", amount = 200 }, { currency = "crystals", amount = 25 }} },
}
```

Changes needed in the service:
1. Switch from single-reward to multi-reward table per day (Day 4 and Day 7 grant multiple currencies)
2. Add `cycleCount` to player data schema (tracks how many full 7-day cycles completed)
3. Apply cycle multiplier: `math.min(1 + 0.25 * cycleCount, 2.0)`
4. Reset `cycleCount` to 0 when streak breaks
5. Add premium gift box roll as a separate function after streak claim

---

## Part 2: Launch Playbook

### 2.1 Pre-Launch Checklist (7-14 Days Before)

**Game Page Setup:**
- [ ] Upload game icon (bright saturated gradient, car + pets, readable at 50x50px)
- [ ] Upload 3 thumbnails (gameplay shot, feature showcase, Stylxus social proof)
- [ ] Publish game description (use the copy from GameCopy.md Section 7)
- [ ] Set all recommended tags: Simulator, Driving, Cars, Pets, Eggs, Tycoon, Idle, Rebirth, Multiplayer, Mobile Friendly
- [ ] Create and link Roblox group for the game
- [ ] Set game to Private with "Friends Only" access for internal testing
- [ ] Configure social links (Discord, Twitter/X, YouTube)

**Monetization Setup:**
- [ ] Create all 13 game passes in Roblox Studio with correct Robux prices (see GamePassConfig.luau)
- [ ] Create all 16 developer products in Roblox Studio (see DevProductConfig.luau)
- [ ] Update all `gamePassId` and `productId` values in config files with real Roblox IDs
- [ ] Test every purchase flow end-to-end (buy → receipt → reward delivered)
- [ ] Verify Premium detection works (PremiumService.luau)

**Content Readiness:**
- [ ] All 4 worlds have lobby + highway geometry (at minimum World 1 must be fully polished)
- [ ] All 11 cars have models and are drivable
- [ ] All 6 eggs have models and hatch animations
- [ ] All 15 pets have models and follow-player animations (PetController.luau)
- [ ] All UI panels functional: HUD, DrivingHUD, InventoryPanel, StorePanel, EggShopPanel, RebirthPanel, CodesPanel, DailyRewardPanel, SettingsPanel, PetIndexPanel
- [ ] Sound effects in place (engine, UI clicks, hatch, rebirth, ambient per world)

**Stylxus Coordination:**
- [ ] Send Stylxus private access to test the game (minimum 3 days before launch)
- [ ] Provide Stylxus with code list and talking points
- [ ] Agree on launch day video publish time (coordinate for simultaneous drop)
- [ ] Provide Stylxus with high-res game assets for thumbnails
- [ ] Confirm STYLXUS90K code is active in CodeService.luau

**Promo & Community:**
- [ ] Set up Discord server with channels: #announcements, #codes, #bug-reports, #feedback, #screenshots
- [ ] Post 2-3 teaser images/clips on Twitter/X from game dev account
- [ ] Prepare all 5 launch day social media posts (GameCopy.md Section 8)
- [ ] Prepare Discord launch announcement (GameCopy.md Section 8)
- [ ] Seed 3 codes (LAUNCH, STYLXUS90K, SPEED) across different channels

**Final QA:**
- [ ] Full playthrough from new player (0 data) through first rebirth
- [ ] Verify all codes redeem correctly
- [ ] Test daily reward claim + streak tracking
- [ ] Test on mobile (iOS and Android) — touch controls, UI scaling, performance
- [ ] Load test: verify 30+ players in one server without lag
- [ ] Verify DataStore saves correctly and loads on rejoin

### 2.2 Launch Day Checklist (Day 0)

**Morning (before publish):**
- [ ] Final server restart / fresh build upload to Roblox
- [ ] Switch game from Private to Public
- [ ] Verify game appears in search for "Drive a Car Simulator"
- [ ] Confirm all game passes and dev products are visible on the game page
- [ ] Test one full play session as a real player (not Studio)

**Coordinated Launch (publish hour):**
- [ ] Stylxus publishes YouTube video (10+ min gameplay, all codes mentioned)
- [ ] Post all 5 social media posts (stagger: Post 1 at launch, Post 2 at +2h, Post 3 at +4h, Post 4 at +6h, Post 5 at +8h)
- [ ] Post Discord launch announcement with @everyone ping
- [ ] Verify LAUNCH, STYLXUS90K, and SPEED codes are all active and redeemable

**Active Monitoring (launch day — check every 30 min):**
- [ ] Monitor Roblox Creator Dashboard: concurrent players, play sessions, errors
- [ ] Watch for server crashes or DataStore errors in developer console
- [ ] Check Discord #bug-reports for player-reported issues
- [ ] Monitor game pass / dev product purchase volume
- [ ] Watch for exploiters (speed hacking, coin duplication) — kick + ban
- [ ] Respond to first player comments/ratings on the game page

**Launch Event (first 48 hours):**
- [ ] Activate "Founder's Bonus" — 2x coins on all worlds for first 48 hours
- [ ] Grant exclusive "Early Driver" badge/title to all players who join in first 48h
- [ ] This creates urgency + gives early players a permanent status symbol

### 2.3 Week 1 Post-Launch Checklist (Days 1-7)

**Daily Tasks:**
- [ ] Check Creator Dashboard metrics every morning: DAU, session length, D1 retention, revenue
- [ ] Read and respond to Discord feedback (at least 2x/day)
- [ ] Triage bug reports — critical bugs get hotfixed same day
- [ ] Monitor DataStore health — check for save failures
- [ ] Post one social media update per day (gameplay clips, player achievements, code hints)

**Metrics to Watch (with targets):**
| Metric | Target | Red Flag |
|--------|--------|----------|
| D1 Retention | 30-40% | Below 20% — check onboarding flow |
| Avg Session Length | 15-25 min | Below 8 min — players aren't hooking |
| Game Pass Conversion | 2-4% of DAU | Below 1% — pricing or visibility issue |
| Top-Selling Pass | 2x Coins or Infinite Gas | If Auto-Collect leads, players can't figure out manual collect |
| Error Rate | <0.1% of sessions | Above 1% — critical stability issue |
| Player Ratings | 70%+ upvote | Below 60% — read feedback immediately |
| Revenue/DAU | 5-15 Robux | Below 3 — monetization isn't surfacing |

**Community Engagement:**
- [ ] Pin a "Known Issues" post in Discord — acknowledge bugs publicly, builds trust
- [ ] Highlight player screenshots/clips in #screenshots channel
- [ ] Run a "Best Pet Screenshot" contest in Discord (winner gets a code for Update 1)
- [ ] Collect top 5 feature requests from players — prioritize for Update 1
- [ ] Thank Stylxus publicly if his video drove significant traffic

**Mid-Week Code Drop (Day 3-4):**
- [ ] Release DRIVEFAST code on Twitter/X only (3,000 coins + 50 gems)
- [ ] Purpose: re-engage players who tried on launch day but didn't return
- [ ] Track redemption rate to measure Twitter/X reach

**End-of-Week Analysis (Day 7):**
- [ ] Compile full Week 1 metrics report (DAU trend, retention curve, revenue breakdown)
- [ ] Identify top 3 player complaints and prioritize fixes
- [ ] Identify which game passes sold best and worst — adjust in-game visibility
- [ ] Decide Update 1 content scope based on player feedback + metrics
- [ ] Plan Stylxus video #2 content (ideally "I GOT THE RAREST PET" format)

### 2.4 Stylxus Coordination Timeline

| When | What | Owner |
|------|------|-------|
| Launch -14d | Share game concept & early build access | Dev team |
| Launch -7d | Send final test build with all content | Dev team |
| Launch -5d | Stylxus records gameplay footage | Stylxus |
| Launch -3d | Review Stylxus video thumbnail/title for alignment | Content Strategist |
| Launch -1d | Final code list + talking points to Stylxus | Content Strategist |
| Launch Day | Coordinated simultaneous publish (game goes public + video goes live) | Both |
| Launch +3d | Share first metrics with Stylxus (player count, views) | Dev team |
| Launch +7d | Discuss Video #2 topic (rare pet hunt, speedrun, etc.) | Both |
| Launch +14d | Stylxus Video #2 drops alongside Update 1 | Both |
| Launch +28d | Stylxus Video #3 — Update 2 showcase | Both |
| Monthly | Ongoing: 1 video per major update | Both |

### 2.5 Key Metrics Dashboard

Track these metrics weekly. Record in a spreadsheet for trend analysis.

**Engagement Metrics:**
- DAU (daily active users)
- WAU (weekly active users)
- D1, D7, D30 retention rates
- Average session length (minutes)
- Sessions per user per day
- Total play sessions

**Monetization Metrics:**
- Revenue (daily Robux earned)
- Revenue per DAU (Robux/user/day)
- Game pass conversion rate (% of DAU who own at least 1 pass)
- Top-selling game pass (by volume and revenue)
- Dev product purchase frequency
- ARPPU (average revenue per paying user)

**Content Metrics:**
- Most popular world (by time spent)
- Most hatched egg
- Rebirth distribution (what % of players have 0, 1-5, 5-10, 10+ rebirths)
- Code redemption rates per code
- Leaderboard competition (how many unique players in top 100)

**Growth Metrics:**
- Impressions (from Roblox algorithm)
- Click-through rate (impressions → plays)
- Favorites and upvote ratio
- Social media referral traffic (track via unique codes per platform)

---

## Part 3: Post-Launch Update Roadmap

### 3.1 Update 1 — "Speed Demons" (Week 2, Launch +14 days)

**Theme:** New cars, new eggs, and quality-of-life improvements based on Week 1 feedback.

**Content Additions:**
- 1 new car per world (4 cars total):
  - Grasslands: **Meadow Sprint** (15,000 coins) — balanced mid-tier car for players who've outgrown Street Cruiser but can't afford Green Demon
  - Desert: **Dune Phantom** (350,000 coins) — fills the gap between Sand Scorpion and Inferno Rod
  - Tundra: **Blizzard Racer** (15,000 gems) — high speed, low gas, risk/reward car
  - Neon: **Pulse Striker** (30,000 crystals) — mid-tier Neon car, currently the jump from Neon Pulse to Void Runner is too steep
- 1 new egg: **Golden Egg** (10,000 coins, Grasslands) — higher rarity floor than Grass Egg, bridges to Desert content
- 2 new pets:
  - **Raccoon** (uncommon, power 16, drops from Golden Egg)
  - **Storm Hawk** (rare, power 35, drops from Golden Egg and Desert Egg)

**QoL Fixes (based on anticipated feedback):**
- Auto-equip best pets button (1-tap optimize pet team)
- "Run of the Day" bonus: first run each day pays 3x base coins
- Pet Index UI showing all discoverable pets with silhouettes for unowned (collection tracking)
- Loading screen tips (see GameCopy.md Section 10)
- Improved mobile UI scaling for smaller screens

**New Code:** `UPDATE1` — 8,000 coins + 150 gems

**Social Post Template:**
> UPDATE 1: SPEED DEMONS is LIVE!
>
> 4 NEW CARS across every world!
> 1 NEW EGG with 2 new pets!
> Run of the Day bonus — 3x coins on your first daily run!
>
> Code UPDATE1 for free rewards!
>
> [LINK]
> #DriveACarSimulator #Roblox

**Stylxus Video #2:** "HUNTING THE NEW RAREST PET IN DRIVE A CAR SIMULATOR" — Stylxus hatches Golden Eggs trying to get Storm Hawk. Natural content, natural code promotion.

---

### 3.2 Update 2 — "Pet Frenzy" (Week 4, Launch +28 days)

**Theme:** Pet system expansion, trading system launch, and first limited-time event.

**Content Additions:**
- **Trading System Launch** — peer-to-peer pet trading (TradeService.luau skeleton already exists)
  - Trade UI: both players select pets, confirm, 10-second countdown, swap
  - Trade log (prevents scam disputes)
  - Minimum account age to trade: 24 hours (anti-exploit)
- 3 new pets:
  - **Crimson Fox** (uncommon, power 18) — desert-themed Fox variant
  - **Frost Eagle** (rare, power 32) — tundra-themed Eagle variant
  - **Neon Serpent** (epic, power 75) — neon-themed Dragon Hatchling variant
- **Pet Fusion upgrade:** Visual feedback when fusing (particle explosion, rarity reveal animation)
- **Limited-Time Event: "Lucky Weekend" (48 hours)**
  - All egg hatch rates boosted: 2x rare+ chance for everyone (stacks with Lucky Eggs pass)
  - Exclusive event egg: **Lucky Egg** (5,000 coins, all worlds) — drops "Lucky Cat" exclusive pet (epic, power 70)
  - Lucky Cat is ONLY available during Lucky Weekend events — permanent FOMO
  - Lucky Weekend banner on main menu with countdown timer

**QoL Improvements:**
- Pet comparison UI (see stat difference before equipping)
- Bulk egg hatch (hatch 3/5/10 at once, with sequential reveal animation)
- Notification when daily reward is ready (on-screen reminder, not push)
- "Invite a Friend" button → both get 100 gems when friend plays 10+ minutes

**New Code:** `PETFRENZY` — 5,000 coins + 100 gems + 15 crystals

**Social Post Template:**
> UPDATE 2: PET FRENZY!
>
> TRADING IS HERE! Swap pets with friends!
> 3 NEW PETS including the Neon Serpent!
> LUCKY WEEKEND EVENT — 2x rare pet odds for 48 hours!
> Exclusive Lucky Cat pet — this weekend ONLY!
>
> Code PETFRENZY for free loot!
>
> [LINK]
> #DriveACarSimulator #Roblox

**Stylxus Video #3:** "TRADING MY RAREST PETS IN DRIVE A CAR SIMULATOR" — trading content is inherently dramatic and drives co-play metrics.

---

### 3.3 Update 3 — "Season 1: Road Warriors" (Month 2, Launch +56 days)

**Theme:** Season pass system introduction, prestige layer, and major content expansion.

**Season Pass System (749 Robux per 35-day season):**
- 50 tiers with free and premium tracks
- XP earned from: driving distance (1 XP per 100 studs), egg hatches (10 XP each), rebirths (100 XP each), daily login (50 XP), code redemption (25 XP)
- Natural completion rate: ~30 tiers in 35 days for active players → spending pressure to buy tier skips or XP Boost pass

**Season 1 Reward Track:**

| Tier | Free Track | Premium Track |
|------|------------|---------------|
| 1 | 1,000 coins | 5,000 coins |
| 5 | 50 gems | 200 gems |
| 10 | Meadow Egg x3 | Season Egg x1 (exclusive) |
| 15 | 100 gems | 500 gems |
| 20 | 25 crystals | 100 crystals |
| 25 | 5,000 coins | Exclusive car skin: "Road Warrior" wrap |
| 30 | 200 gems | Season Egg x3 |
| 35 | 50 crystals | 10 skulls |
| 40 | 10,000 coins | Exclusive pet: **Thunder Wolf** (legendary, power 175) |
| 45 | 500 gems | 250 crystals |
| 50 | 100 crystals | Exclusive title: "Road Warrior" + Season 1 badge + **Blaze Phoenix** (mythic, power 600) |

**Season Egg** (premium track exclusive):
- Drops only season-exclusive pets at elevated rates
- Cannot be purchased with any currency — only earned through pass progression
- Pets inside: Crimson Fox, Frost Eagle, Neon Serpent, Thunder Wolf, Blaze Phoenix

**Prestige System (endgame layer):**
- Available after 50+ rebirths
- Prestige resets rebirth count but grants permanent +2% to ALL stats per prestige
- Prestige costs: 1M coins + 10,000 gems + 1,000 crystals + 50 skulls
- Visible prestige star next to player name (1 star = 1 prestige, gold star at 10+)
- Creates a new endgame grind for whales who've already maxed everything

**Content Additions:**
- 2 new pets (season exclusive, see table above)
- 1 new egg type (Season Egg, premium pass only)
- Season-themed lobby decorations (banners, trophies, NPC)
- Prestige shop: skull-priced cosmetics (dark car skins, shadowy pet variants)

**Boss Run Preview (teaser for Update 4):**
- Add a "Coming Soon: Boss Runs" sign in the lobby
- Shows silhouette of a highway boss enemy
- Builds anticipation for Month 3 content

**New Code:** `SEASON1` — 10,000 coins + 250 gems + 50 crystals

**Social Post Template:**
> SEASON 1: ROAD WARRIORS HAS ARRIVED!
>
> The Season Pass is here — 50 tiers of exclusive rewards!
> Exclusive pets: Thunder Wolf and Blaze Phoenix!
> PRESTIGE system for endgame legends!
>
> 749 Robux for the full premium track.
> Free track available for everyone.
>
> Code SEASON1 for launch rewards!
>
> [LINK]
> #DriveACarSimulator #Roblox #Season1

**Stylxus Video #4:** "THE SEASON PASS IS INSANE — GETTING TIER 50 IN DRIVE A CAR SIMULATOR" — Season pass progression content has proven high engagement on Roblox YouTube.

---

## Part 4: Code Schedule Summary

| Code | Rewards | Release Timing | Channel |
|------|---------|---------------|---------|
| LAUNCH | 5,000 coins + 100 gems | Day 0 | Game page, Discord |
| STYLXUS90K | 10,000 coins + 50 crystals | Day 0 | Stylxus YouTube |
| SPEED | 2,500 coins | Day 0 | Game page |
| DRIVEFAST | 3,000 coins + 50 gems | Day 3-4 | Twitter/X only |
| PETPOWER | 5,000 coins | Day 7 (Stylxus Video #2 teaser) | YouTube mid-roll |
| UPDATE1 | 8,000 coins + 150 gems | Day 14 (Update 1) | All channels |
| NEONHYPE | 200 crystals | Day 20 | TikTok (expires in 7 days) |
| PETFRENZY | 5,000 coins + 100 gems + 15 crystals | Day 28 (Update 2) | All channels |
| DESERT2X | 5,000 coins + 100 gems | Day 35 | Discord giveaway |
| THANKYOU | 7,500 coins + 75 gems + 25 crystals | When DAU milestone hit (1K/5K/10K) | Announcement |
| SEASON1 | 10,000 coins + 250 gems + 50 crystals | Day 56 (Update 3) | All channels |
| REBIRTH1 | 10,000 coins | Permanent — shown in loading tips | In-game discovery |

---

## Part 5: Revenue Milestone Triggers

These are action items triggered by hitting specific revenue/player milestones:

| Milestone | Trigger Action |
|-----------|---------------|
| 1,000 DAU | Release THANKYOU code, post celebration on all socials |
| 5,000 DAU | Begin Roblox sponsored ad testing (reinvest 10-15% of revenue) |
| 10,000 DAU | Negotiate Stylxus exclusivity deal for monthly videos |
| 100K total visits | Apply for Roblox "Rising Star" feature consideration |
| First 100K Robux revenue | Greenlight Season 2 development, begin World 5 concept |
| 1M total visits | Launch referral rewards system |
| First negative retention trend | Emergency content drop (new code + limited event + hotfix pass) |

---

*This playbook is a living document. Update metrics targets and content plans as real data comes in from launch.*
