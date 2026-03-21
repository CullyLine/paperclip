# Drive a Car Simulator — Pre-Launch Checklist & First-Week Content Calendar

**Prepared by:** Content Strategist (POLA-27)
**Date:** March 20, 2026
**References:** GamePassConfig.luau, DevProductConfig.luau, CodeService.luau, CarConfig.luau, GamePageContent.md, LaunchPlaybook.md, Season1_ContentPlan.md

---

## Part 1: Pre-Launch Checklist

### 1. Code Readiness

- [ ] **Rojo sync verified** — All 62+ Luau files synced to Roblox Studio via Rojo. Run `rojo build` and confirm no missing modules in the output log.
- [ ] **Game pass IDs created on Roblox** — Create all 13 game passes in the Roblox Creator Dashboard and update `gamePassId` fields in `GamePassConfig.luau` (currently all set to `0`):

| Pass | Robux Price | Config Key |
|------|-------------|------------|
| 2x Coins | 399 | `double_coins` |
| 2x Speed | 499 | `double_speed` |
| Auto-Collect | 299 | `auto_collect` |
| VIP | 799 | `vip` |
| Extra Pet Slots | 499 | `extra_pet_slots` |
| Lucky Eggs | 599 | `lucky_eggs` |
| Infinite Gas | 999 | `infinite_gas` |
| Ultra Lucky | 1,299 | `ultra_lucky` |
| Auto-Drive | 699 | `auto_drive` |
| 3x Gas | 799 | `gas_3x` |
| Pet Magnet | 399 | `pet_magnet` |
| Rebirth Rush | 599 | `rebirth_rush` |
| Coin Boost | 349 | `coin_boost` |

- [ ] **Dev product IDs created on Roblox** — Create all 16 developer products in the Creator Dashboard and update `productId` fields in `DevProductConfig.luau` (currently all set to `0`):

| Product | Robux Price | Config Key |
|---------|-------------|------------|
| 1,000 Coins | 49 | `coins_1k` |
| 10,000 Coins | 149 | `coins_10k` |
| 100,000 Coins | 399 | `coins_100k` |
| 1,000,000 Coins | 999 | `coins_1m` |
| 100 Gems | 99 | `gems_100` |
| 1,000 Gems | 399 | `gems_1k` |
| 50 Crystals | 199 | `crystals_50` |
| 500 Crystals | 799 | `crystals_500` |
| Instant Rebirth | 299 | `instant_rebirth` |
| Auto-Hatch 3 Eggs | 99 | `auto_hatch_3` |
| Skip World Unlock | 499 | `skip_world` |
| Gem Pack L (10K) | 999 | `gems_pack_l` |
| Crystal Pack L (5K) | 1,999 | `crystals_pack_l` |
| Starter Pack | 199 | `starter_pack` |
| Battle Pass Premium | 749 | `battle_pass_premium` |

- [ ] **All 10 promo codes tested** — Redeem each code on a fresh test account and verify correct rewards:

| Code | Rewards | Channel |
|------|---------|---------|
| LAUNCH | 5,000 coins + 100 gems | Game page, Discord |
| STYLXUS90K | 10,000 coins + 50 crystals | Stylxus YouTube |
| SPEED | 2,500 coins | Game page |
| DRIVEFAST | 3,000 coins + 50 gems | Twitter/X |
| PETPOWER | 5,000 coins | YouTube mid-roll |
| REBIRTH1 | 10,000 coins | Loading tips (permanent) |
| NEONHYPE | 200 crystals | TikTok |
| DESERT2X | 5,000 coins + 100 gems | Discord |
| THANKYOU | 7,500 coins + 75 gems + 25 crystals | Milestone announcement |
| UPDATE1 | 8,000 coins + 150 gems | All channels (Update 1) |

- [ ] **DataStore keys finalized** — Review all DataStore key names in `DataManager.luau`. No key renames after launch or existing saves will be wiped. Confirm: player data, redeemed codes, daily reward streaks, rebirth counts, pet inventory, car ownership, settings, leaderboard entries.
- [ ] **Anti-exploit validation tested** — Verify `RemoteCooldown` rate limits on all remotes. Test: rapid code redemption, rapid purchase attempts, speed hack detection (if implemented), coin amount validation server-side.
- [ ] **Error handling** — Confirm all `pcall` wrappers around DataStore calls. Test: what happens when DataStore is temporarily unavailable? Player should see a retry notification, not lose data.

### 2. Content Readiness

- [ ] **Game page title applied** — "Drive a Car Simulator" (22 characters, fits all mobile displays)
- [ ] **Game description applied** — Use the 997-character primary description from `GamePageContent.md` §2
- [ ] **Tags configured** — All 10 discovery tags applied in priority order: Simulator, Driving, Cars, Pets, Eggs, Tycoon, Rebirth, Idle, Multiplayer, Mobile Friendly
- [ ] **Game icon uploaded** — 512×512 "Speed & Pets" icon per `GamePageContent.md` §4.1 brief (radial gradient, hero car, 2-3 orbiting pets, coin shower). Must be readable at 50×50px mobile size.
- [ ] **Thumbnails uploaded** — At least 3 of 5 thumbnails from §4.2-4.6:
  - [ ] Thumbnail 1: Gameplay Action Shot (1920×1080)
  - [ ] Thumbnail 2: Feature Grid Showcase (1920×1080)
  - [ ] Thumbnail 3: Rare Pet Chase (1920×1080)
  - [ ] Thumbnail 4: Stylxus Social Proof (pending Stylxus approval) OR Thumbnail 5: Update Badge (backup)
- [ ] **All 4 worlds have geometry** — At minimum, each world has a lobby zone and drivable highway loop:
  - [ ] Grasslands — fully polished (primary launch world)
  - [ ] Desert — playable (geometry + lighting + ambient)
  - [ ] Frozen Tundra — playable (geometry + lighting + ambient)
  - [ ] Neon City — playable (geometry + lighting + ambient)
- [ ] **All 11 base cars have models** — Each car in `CarConfig.luau` has a corresponding model in Roblox Studio and is drivable:
  - [ ] Rusty Runabout (Grasslands, free)
  - [ ] Street Cruiser (Grasslands, 5K coins)
  - [ ] Green Demon (Grasslands, 25K coins)
  - [ ] Venom GT (Grasslands, 100K coins)
  - [ ] Tank Roller (Grasslands, 50K coins)
  - [ ] Sand Scorpion (Desert, 200K coins)
  - [ ] Inferno Rod (Desert, 500K coins)
  - [ ] Frost Glider (Frozen, 5K gems)
  - [ ] Glacier Phantom (Frozen, 25K gems)
  - [ ] Neon Pulse (Neon, 10K crystals)
  - [ ] Void Runner (Neon, 50K crystals)
- [ ] **All 6 eggs have models and hatch animations** — Per `EggConfig.luau`
- [ ] **All 15 pets have models and follow-player behavior** — `PetController.luau` handles follow logic
- [ ] **All UI panels functional** — Test each panel opens, displays correctly, and buttons work:
  - [ ] HUD (main)
  - [ ] DrivingHUD
  - [ ] InventoryPanel
  - [ ] StorePanel
  - [ ] EggShopPanel
  - [ ] RebirthPanel
  - [ ] CodesPanel
  - [ ] DailyRewardPanel
  - [ ] SettingsPanel
  - [ ] PetIndexPanel
  - [ ] QuestPanel
  - [ ] BattlePassPanel
  - [ ] PayoutPanel
  - [ ] MenuHub
  - [ ] PlaytimeGemHUD
- [ ] **Sound effects in place** — Via `SoundController.luau`:
  - [ ] Engine loop (per car or generic)
  - [ ] UI click/hover sounds
  - [ ] Egg hatch reveal
  - [ ] Rebirth confirmation
  - [ ] Coin/gem collect chime
  - [ ] World ambient loops (4 worlds)
  - [ ] Code redemption success/fail
- [ ] **Loading tips configured** — `LoadingTipsConfig.luau` populated with tips from `GameCopy.md`

### 3. Marketing Readiness

- [ ] **Stylxus briefed** — Stylxus has been sent:
  - [ ] Private game access link (minimum 3 days before launch)
  - [ ] Full code list with rewards and talking points
  - [ ] High-res game assets for video thumbnails
  - [ ] Agreed launch day + coordinated video publish time
- [ ] **Social media accounts created**:
  - [ ] Twitter/X: @PolymitaMedia or @DriveACarSim
  - [ ] TikTok: @DriveACarSim or @PolymitaMedia
  - [ ] YouTube: Polymita Media channel (secondary to Stylxus)
- [ ] **Discord server configured** — Per `GamePageContent.md` §5.4:
  - [ ] #announcements (admin-only)
  - [ ] #codes (admin-only, pinned active codes)
  - [ ] #rules
  - [ ] #general
  - [ ] #screenshots
  - [ ] #feedback
  - [ ] #bug-reports (with template)
  - [ ] #tips-and-tricks
  - [ ] #mod-chat (staff-only)
  - [ ] Roles: Guest → Member → VIP → Moderator → Admin → Owner
- [ ] **Roblox group created** — "Polymita Media" group with open membership, icon matching game icon
- [ ] **Social links configured on game page** — Discord, Twitter/X, YouTube, Roblox Group all linked
- [ ] **Launch social media posts drafted** — All 5 staggered launch day posts from `GameCopy.md` §8 ready to copy-paste
- [ ] **Discord launch announcement drafted** — @everyone announcement with game link, top features, and code callouts
- [ ] **Teaser content posted** (if time allows):
  - [ ] Teaser image on Twitter/X (Launch -7d)
  - [ ] Short gameplay clip (Launch -3d)
  - [ ] "Codes drop on launch day" announcement (Launch -3d)

### 4. Monetization Readiness

- [ ] **All 13 game passes priced correctly on Roblox** — Cross-reference Robux prices in `GamePassConfig.luau` against Creator Dashboard listings. Every pass must have: name, description, icon, correct Robux price.
- [ ] **All 16 dev products created on Roblox** — Each product registered with correct Robux price in Creator Dashboard
- [ ] **Purchase flow tested end-to-end** — For each pass and product: buy → receipt processed by `GamePassService.luau` / `DevProductService.luau` → reward delivered → DataStore updated → UI reflects change
- [ ] **Premium benefits visible in-game** — Roblox Premium detection works. Premium players see: +50% coin bonus, daily gift box in DailyRewardPanel
- [ ] **Store panel pricing matches** — `StorePanel.luau` displays correct Robux prices matching Creator Dashboard (not stale values)
- [ ] **Refund handling** — If Roblox revokes a purchase, the pass/product benefit is correctly removed on next join

### 5. Final QA

- [ ] **Full new-player playthrough** — Start with 0 data. Drive in Grasslands → buy first car upgrade → hatch first egg → equip pet → reach first rebirth. Entire flow must work without confusion or dead ends.
- [ ] **All codes redeem correctly** — Test all 10 codes on a fresh account. Verify: correct rewards, "already redeemed" on second use, case-insensitive input.
- [ ] **Daily rewards claim** — Claim Day 1 reward. Advance time (or use test override). Claim through Day 7 jackpot. Verify multi-currency Day 4 and Day 7 payouts.
- [ ] **Mobile testing** — iOS and Android:
  - [ ] Touch driving controls responsive
  - [ ] UI panels scale correctly on small screens (no clipping/overlap)
  - [ ] Performance: 30+ FPS on mid-range devices
  - [ ] Text readable at mobile resolution
- [ ] **Load testing** — 30+ players in one server simultaneously. No excessive lag, DataStore throttling, or remote event flooding.
- [ ] **DataStore integrity** — Save data → leave game → rejoin → all data persists: coins, gems, crystals, skulls, cars owned, pets, rebirths, redeemed codes, daily streak, settings.
- [ ] **Leaderboard functionality** — `LeaderboardService.luau` updates correctly. Distance and rebirth leaderboards display real-time data.
- [ ] **Trade service disabled** — `TradeService.luau` should be inactive at launch (trading launches in Update 2). Confirm no UI entry point to trading.

---

## Part 2: Launch Day Checklist (Day 0)

### Morning (Before Publish)

- [ ] Fresh build uploaded to Roblox (final `rojo build` → publish)
- [ ] Game set to **Public** (switch from Private/Friends Only)
- [ ] Verify game appears in search for "Drive a Car Simulator"
- [ ] Confirm all 13 game passes visible on the game page with correct icons and prices
- [ ] Confirm all 16 dev products listed in the store panel
- [ ] One full play session as a real player (not Studio test) — Rusty Runabout → drive → earn coins → buy upgrade → hatch egg

### Coordinated Launch (Publish Hour)

- [ ] Stylxus publishes YouTube video (10+ min, all codes mentioned, coordinated timing)
- [ ] Post launch announcement #1 on all platforms simultaneously
- [ ] Post Discord @everyone announcement with game link and codes
- [ ] Stagger remaining posts: #2 at +2h, #3 at +4h, #4 at +6h, #5 at +8h
- [ ] Verify LAUNCH, STYLXUS90K, and SPEED codes are all active and redeemable in-game

### Active Monitoring (Check Every 30 Minutes)

- [ ] Roblox Creator Dashboard: concurrent players, play sessions, server errors
- [ ] Developer Console: DataStore errors, script errors, memory usage
- [ ] Discord #bug-reports: player-reported issues
- [ ] Game pass / dev product purchase volume trending
- [ ] Watch for exploiters (speed hacking, coin duplication) — kick + ban
- [ ] Respond to first player comments/ratings on the game page

### Launch Event (First 48 Hours)

- [ ] Activate "Founder's Bonus" — 2× coins on all worlds for first 48 hours
- [ ] Grant exclusive "Early Driver" badge to all players who join in first 48h
- [ ] Monitor: if CCU drops below expectations, push an additional social post with code LAUNCH

---

## Part 3: First-Week Content Calendar (Days 0–7)

### Day 0 — LAUNCH DAY

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| 0h (game goes public) | Publish game + Stylxus video | Roblox + YouTube | Coordinated simultaneous drop |
| 0h | Launch post #1 | Twitter/X, Discord, TikTok | Main announcement with game link + codes LAUNCH & STYLXUS90K |
| 0h | @everyone ping | Discord #announcements | Full launch announcement with feature highlights |
| +2h | Launch post #2 | Twitter/X | Feature showcase: "11+ cars, 14+ pets, 4 worlds" |
| +4h | Launch post #3 | TikTok | 15-second hype clip: car racing + pet hatching montage |
| +6h | Launch post #4 | Twitter/X | Aspirational: "Can you hatch the Cosmic Whale? Power: 550!" |
| +8h | Launch post #5 | Discord, Twitter/X | Community invite: "Join the Discord for exclusive codes!" |
| All day | Monitor metrics | Creator Dashboard | CCU, error rate, purchase volume every 30 min |

**Active codes:** LAUNCH, STYLXUS90K, SPEED, REBIRTH1 (permanent via loading tips)
**Founder's Bonus:** 2× coins active for 48h

**Metrics to capture at end of Day 0:**
- Peak concurrent users (CCU)
- Total unique players
- Game pass purchases (count + revenue)
- Error rate (% of sessions with script errors)
- Stylxus video views

---

### Day 1 — OBSERVE & ENGAGE

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Check overnight metrics | Creator Dashboard | DAU, session length, D1 retention baseline, revenue |
| Morning | Read Discord feedback | Discord #feedback, #bug-reports | Triage: critical bugs → hotfix today, QoL → backlog |
| Midday | Player highlight post | Twitter/X | Repost/screenshot a player achievement or funny moment |
| Afternoon | Pin "Known Issues" post | Discord #announcements | Acknowledge any bugs publicly — builds trust |
| Evening | Engagement check | All platforms | Reply to comments, answer questions, thank early players |

**Codes status:** No new codes. LAUNCH, STYLXUS90K, SPEED remain active.
**Track:** D1 retention target: 30-40%. If below 20%, investigate onboarding flow.

---

### Day 2 — COMMUNITY BUILDING

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Metrics review | Creator Dashboard | D1 retention number is now available. Compare to 30-40% target. |
| Midday | "Tips & Tricks" post | Twitter/X, Discord | Share a beginner tip: "Equip pets before driving — they multiply your coin earnings!" |
| Afternoon | Screenshot contest launch | Discord #screenshots | "Best Pet Screenshot" contest — winner gets a shoutout + early access to a future code |
| Evening | TikTok clip | TikTok | 30-second clip: egg hatch compilation showing rarity reveals |

**Founder's Bonus ends at 48h mark.** Post a "Founder's Bonus ends soon!" reminder at the 36h mark.

---

### Day 3 — CODE DROP + RE-ENGAGEMENT

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Metrics review | Creator Dashboard | Watch for Day 2 drop-off vs Day 1. Session length trends. |
| Midday | **Drop DRIVEFAST code** | Twitter/X ONLY | "Exclusive Twitter code! DRIVEFAST = 3,000 coins + 50 gems. Only here. 🏎️" |
| Afternoon | Track DRIVEFAST redemptions | CodeService analytics | Measures Twitter/X reach and conversion |
| Evening | Community Q&A | Discord #general | Informal AMA: answer player questions about upcoming features (tease Update 1 without specifics) |

**New code active:** DRIVEFAST (Twitter/X exclusive)
**Purpose:** Re-engage players who tried on Day 0 but haven't returned.

---

### Day 4 — CONTENT & FEEDBACK

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Compile top 5 player complaints | Discord #feedback, game page ratings | Prioritize: what are players frustrated about? |
| Midday | "Did You Know?" post | Twitter/X | Hidden feature reveal: "Did you know REBIRTH1 is a secret code? 10,000 free coins! 🤫" |
| Afternoon | Gameplay clip | TikTok | 45-second clip: first-to-Neon-City speedrun or rare pet hatch reaction |
| Evening | Bug hotfix (if needed) | Roblox Studio | Deploy any critical fixes identified Days 1-3 |

**Track:** Game pass conversion rate. Target: 2-4% of DAU. If below 1%, review in-game store visibility and pass descriptions.

---

### Day 5 — STYLXUS CHECK-IN + GROWTH

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Share Week 1 metrics with Stylxus | Private | Player count, video views, code redemption rates |
| Midday | Player achievement highlight | Twitter/X | Feature a player who hit a milestone (high rebirths, rare pet, leaderboard rank) |
| Afternoon | Discord screenshot contest judging | Discord #screenshots | Announce winner, share winning screenshot on Twitter/X |
| Evening | Plan Stylxus Video #2 | Private coordination | Topic: "I GOT THE RAREST PET" — Stylxus hunts for Cosmic Whale or Golden Dragon |

**Track:** Revenue/DAU. Target: 5-15 Robux. If below 3, investigate monetization surfacing.

---

### Day 6 — TEASE & BUILD ANTICIPATION

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | Metrics review | Creator Dashboard | D7 retention preview. Compare session length trend. |
| Midday | Update 1 teaser | Twitter/X, Discord | Vague hint: "Something new is coming to the highways... 👀 Stay tuned." |
| Afternoon | Engagement post | Discord #general | Poll: "Which world is your favorite so far? 🌿 Grasslands / 🏜️ Desert / ❄️ Tundra / 🌃 Neon City" |
| Evening | TikTok content | TikTok | "How far can you drive on one tank?" challenge clip |

**Purpose:** Build anticipation for Update 1 (dropping Day 14). Don't reveal specifics yet.

---

### Day 7 — WEEK 1 WRAP-UP & ANALYSIS

| Time | Action | Platform | Details |
|------|--------|----------|---------|
| Morning | **Compile full Week 1 metrics report** | Internal | See metrics table below |
| Midday | "Thank You" post | Twitter/X, Discord | "Thank you to everyone who played this week! X players, Y total visits. You're amazing. More coming soon!" |
| Afternoon | **PETPOWER code drops** (via Stylxus Video #2 teaser) | YouTube mid-roll | Stylxus drops a teaser clip mentioning PETPOWER code for 5,000 coins |
| Evening | Update 1 scope decision | Internal | Based on Week 1 feedback: finalize what goes into "Speed Demons" Update 1 |

**New code active:** PETPOWER (YouTube exclusive)

### Week 1 Metrics Report Template

| Metric | Day 0 | Day 1 | Day 3 | Day 7 | Target | Status |
|--------|-------|-------|-------|-------|--------|--------|
| DAU | — | — | — | — | Growing | |
| Peak CCU | — | — | — | — | — | |
| D1 Retention | N/A | — | — | — | 30-40% | |
| D7 Retention | N/A | N/A | N/A | — | 25-35% | |
| Avg Session Length | — | — | — | — | 15-25 min | |
| Game Pass Conversion | — | — | — | — | 2-4% of DAU | |
| Top-Selling Pass | — | — | — | — | 2x Coins or Infinite Gas | |
| Revenue (daily Robux) | — | — | — | — | Growing | |
| Revenue / DAU | — | — | — | — | 5-15 Robux | |
| Error Rate | — | — | — | — | <0.1% | |
| Player Rating | — | — | — | — | 70%+ upvote | |
| LAUNCH redemptions | — | — | — | — | — | |
| STYLXUS90K redemptions | — | — | — | — | — | |
| DRIVEFAST redemptions | N/A | N/A | — | — | — | |
| Stylxus video views | — | — | — | — | — | |

### Week 1 Red Flags & Emergency Playbook

| Red Flag | Threshold | Emergency Action |
|----------|-----------|-----------------|
| D1 retention below 20% | <20% return after first session | Review onboarding: is the first drive confusing? Is the HUD overwhelming? Add a guided tutorial prompt. |
| Session length below 8 min | Avg <8 min | Players aren't finding the hook. Add a more prominent "Hatch Your First Egg FREE" prompt in the first 2 minutes. |
| Error rate above 1% | >1% sessions with errors | Emergency hotfix. Pull server logs, identify top error, patch within 4 hours. |
| Rating below 60% upvote | <60% positive | Read every negative review. Common complaint = priority hotfix. Post "We hear you" in Discord. |
| Zero game pass sales | 0 purchases in first 24h | Store panel may be broken or invisible. Test purchase flow immediately. Check that passes appear on game page. |
| CCU crashes to 0 | Server crash / outage | Republish immediately. Post status update in Discord. Extend Founder's Bonus by 24h as compensation. |
| No players after Stylxus video | <50 CCU despite video | Video may not have linked correctly. Verify game link in video description. Post link in Stylxus Discord. |
| Exploiters detected | Speed hacks, coin duping | Ban exploiters immediately via developer console. Patch the specific exploit. Add validation in next hotfix. |

---

## Part 4: Post-Week-1 Roadmap Preview

| When | Milestone | Key Action |
|------|-----------|------------|
| Day 14 | **Update 1: Speed Demons** | 4 new cars, 1 new egg, 2 new pets, QoL fixes. Code: UPDATE1. Stylxus Video #2 drops same day. |
| Day 20 | TikTok code drop | Release NEONHYPE on TikTok (200 crystals, 7-day expiry). Track viral potential. |
| Day 28 | **Update 2: Pet Frenzy** | Trading system, 3 new pets, Lucky Weekend event. Code: PETFRENZY. Stylxus Video #3. |
| Day 35 | Discord giveaway | Drop DESERT2X as Discord-exclusive giveaway. Measures Discord community strength. |
| Day 56 | **Season 1: Midnight Velocity** | Battle pass (50 tiers, 749R), Midnight Egg, seasonal lobby transformation. Code: SEASON1. |

---

#### Files on disk

- `memories/DriveACarSimulator/PreLaunchChecklist.md` — This document (pre-launch checklist + first-week content calendar)
