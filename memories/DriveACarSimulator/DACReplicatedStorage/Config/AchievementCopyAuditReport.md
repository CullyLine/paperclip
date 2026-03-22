# Achievement Copy Audit + PremiumUpsell Surface Map + StreakFOMO Review

**POLA-202** | Content Strategist | 2026-03-21

---

## Part 1 — Achievement Copy Audit

Source: `DACReplicatedStorage/Config/AchievementPopupConfig.luau`
30 achievements across 5 categories, 5 copy pools (~59 variant lines).

---

### 1A. Achievement Definitions (30 total)

#### DRIVING (8 achievements) — Score: 4/5

| id | Title | Description | Verdict |
|---|---|---|---|
| first_drive | FIRST DRIVE! | Complete your very first run. | Clean onboarding moment. No change. |
| speed_demon | SPEED DEMON! | Reach 100 studs/s in a single run. | Punchy, clear. No change. |
| centurion_runs | CENTURION! | Complete 100 runs. The road warrior awakens! | Strong flavor. No change. |
| marathon_driver | MARATHON DRIVER! | Complete 1,000 runs. Tireless legend! | "Tireless legend" is lukewarm. See rewrite. |
| near_miss_king | NEAR MISS KING! | Chain 10 near-misses in a single run. | Great skill-flex. No change. |
| combo_master | COMBO MASTER! | Reach a x20 combo multiplier. Legendary chain! | Solid. No change. |
| world_tourer | WORLD TOURER! | Complete a run in every unlocked world. | Nice exploration beat. No change. |
| speed_god | SPEED GOD! | Hit 1,000 studs/s. Simulation broken! | Perfect aspirational endgame. No change. |

**Rewrite suggestion:**
- `marathon_driver` description: "Complete 1,000 runs. Tireless legend!" → **"Complete 1,000 runs. The road NEVER ends for you!"** — Adds specificity and matches the bombastic tone. "Tireless legend" reads like a LinkedIn endorsement.

#### COLLECTION (7 achievements) — Score: 4/5

| id | Title | Description | Verdict |
|---|---|---|---|
| first_hatch | EGG CRACKER! | Hatch your very first pet. | Perfect onboarding. No change. |
| rare_find | RARE FIND! | Hatch a Rare pet. The luck begins! | Good. No change. |
| epic_moment | EPIC MOMENT! | Hatch an Epic pet. Against the odds! | Solid. No change. |
| legendary_pull | LEGENDARY PULL! | Hatch a Legendary pet. 0.5% odds crushed! | Odds framing is psychologically excellent. No change. |
| mythic_miracle | MYTHIC MIRACLE! | Hatch a Mythical pet. One in ten thousand! | Same — odds framing amplifies dopamine. No change. |
| half_index | HALF THE INDEX! | Collect 50% of all pets. Dedicated curator! | "Dedicated curator" is flat. See rewrite. |
| full_index | COMPLETIONIST! | Collect 100% of all pets. Every. Single. One! | Rhythmic punctuation lands. No change. |

**Rewrite suggestion:**
- `half_index` description: "Collect 50% of all pets. Dedicated curator!" → **"Collect 50% of all pets. Halfway to EVERYTHING!"** — "Dedicated curator" sounds like a museum job description, not a Roblox hype moment. "Halfway to EVERYTHING" frames the remaining half as an irresistible pull.

#### ECONOMY (6 achievements) — Score: 3.5/5

| id | Title | Description | Verdict |
|---|---|---|---|
| first_million | MILLIONAIRE! | Earn 1,000,000 total coins. Money moves! | Fun. No change. |
| gem_hoarder | GEM HOARDER! | Accumulate 500 gems. Sparkling! | "Sparkling!" is weak. See rewrite. |
| big_spender | BIG SPENDER! | Spend 500,000 coins in the shop. Baller! | Good tone. No change. |
| rebirth_one | REBORN! | Complete your first rebirth. Power surge! | Great power fantasy. No change. |
| rebirth_ten | ELITE REBIRTHER! | Reach 10 rebirths. Top-tier commitment! | "Top-tier commitment" sounds corporate. See rewrite. |
| rebirth_hundred | IMMORTAL! | 100 rebirths. Nothing left to prove! | Perfect endgame cap. No change. |

**Rewrite suggestions:**
- `gem_hoarder` description: "Accumulate 500 gems. Sparkling!" → **"Accumulate 500 gems. Your wallet is BLINDING!"** — Matches the hyperbolic tone. "Sparkling" is what you'd say about mineral water.
- `rebirth_ten` description: "Reach 10 rebirths. Top-tier commitment!" → **"Reach 10 rebirths. You've died TEN TIMES and came back STRONGER!"** — Leans into the rebirth fantasy with dramatic stakes.

#### SOCIAL (6 achievements) — Score: 3.5/5

| id | Title | Description | Verdict |
|---|---|---|---|
| leaderboard_debut | ON THE BOARD! | Appear on any leaderboard for the first time. | Clean. No change. |
| top_ten | TOP TEN! | Reach top 10 on any leaderboard. Elite! | "Elite!" is generic. See rewrite. |
| number_one | #1 DRIVER! | Claim the #1 spot on a leaderboard. KING! | "KING!" lands. No change. |
| daily_streak_7 | WEEK WARRIOR! | Maintain a 7-day login streak. | Description is bone-dry. See rewrite. |
| daily_streak_30 | MONTHLY MASTER! | 30-day login streak. True dedication! | "True dedication" lacks energy. See rewrite. |
| quest_grinder | QUEST GRINDER! | Complete 50 quests. Mission machine! | Fun. No change. |

**Rewrite suggestions:**
- `top_ten` description: "Reach top 10 on any leaderboard. Elite!" → **"Reach top 10 on any leaderboard. The lobby KNOWS your name!"** — Ties to social validation, which is the whole point of a leaderboard.
- `daily_streak_7` description: "Maintain a 7-day login streak." → **"Maintain a 7-day login streak. A full WEEK of dedication!"** — The bare description has zero emotional payoff. Add a celebration beat.
- `daily_streak_30` description: "30-day login streak. True dedication!" → **"30-day login streak. You basically LIVE here!"** — Mirrors the existing `PlayStreak` copy tone ("At this point you basically live here") for consistency.

#### SECRET (3 achievements) — Score: 3/5

| id | Title | Description | Verdict |
|---|---|---|---|
| easter_egg | EGG HUNTER! | Find a hidden easter egg. Sharp eyes! | Functional. No change. |
| max_car | GARAGE KING! | Own every car in the game. Full fleet! | Strong. No change. |
| world_master | WORLD MASTER! | Master every world. Total domination! | "Master" is vague — what action triggers it? See rewrite. |

**Rewrite suggestion:**
- `world_master` description: "Master every world. Total domination!" → **"Complete every world's challenges. Total domination!"** — "Master" is ambiguous. Does the player need to finish all runs? Hit a speed target? The description should hint at criteria.

**Category concern:** 3 secrets feels thin. Secret achievements are a discovery dopamine loop — more = more "I wonder what else is hidden" motivation. See new suggestions below.

---

### 1B. Copy Pool Scores

#### UnlockToastLines (6 lines) — Score: 3.5/5

Lines are functional but follow a single pattern: `NOUN + {TITLE}`. All six read like variations of the same sentence. The pool needs emotional range — surprise, humor, competitive flex.

**Current pool:**
1. "ACHIEVEMENT UNLOCKED! {TITLE}"
2. "NEW ACHIEVEMENT! {TITLE}"
3. "🏆 UNLOCKED: {TITLE}"
4. "YOU DID IT! {TITLE}"
5. "TROPHY EARNED! {TITLE}"
6. "ACHIEVEMENT GET! {TITLE}"

**Suggested additions (3 new variants):**
- **"Wait — did you just unlock {TITLE}?! INCREDIBLE!"** — Surprise/disbelief angle.
- **"Add {TITLE} to your trophy case! You EARNED this one!"** — Ties to Trophy Case UI (POLA-193).
- **"FLEX ALERT! {TITLE} is now on your profile!"** — Social flex angle.

#### CategoryComplete (15 lines — 3 per category) — Score: 4.5/5

Strong celebration energy. "CONQUERED," "CRUSHED," "ROYALTY" land well with the Roblox audience. The only note: the `secret` category lines could lean harder into mystery/discovery language.

**One suggested rewrite for secret:**
- "The last secret falls. True completionist energy!" → **"The last secret falls. You found what NOBODY else could!"** — Scarcity framing, not just "completionist energy" which is abstract.

#### TotalCompletion (5 lines) — Score: 5/5

Best pool in the config. Scarcity framing ("Fewer than 0.01%"), personal triumph ("The game bows to you"), aspirational cap ("ULTIMATE driver"). No changes needed. This is the model all other pools should aspire to.

#### ProgressNudge (5 lines) — Score: 3.5/5

All five lines say "you're almost there" with slightly different words. The pool lacks emotional variety — no urgency, no FOMO, no competitive edge. For a nudge system, that homogeneity reduces impact over repeat exposures.

**Current pool:**
1. "Almost there! {PERCENT}% to {TITLE}! Keep pushing!"
2. "So CLOSE to {TITLE}! Just a little more!"
3. "{PERCENT}% to {TITLE}! Don't stop now!"
4. "The {TITLE} achievement is WITHIN REACH! ({PERCENT}%)"
5. "Nearly {TITLE}! Finish what you started!"

**Suggested additions (3 new variants with different emotional angles):**
- **"Other players already have {TITLE}. You're {PERCENT}% there — catch up!"** — Competitive/social comparison.
- **"Imagine how GOOD {TITLE} will look in your trophy case... ({PERCENT}%)"** — Visualization/desire.
- **"You've already done {PERCENT}% of the work for {TITLE}. Quitting now would be TRAGIC!"** — Loss aversion/sunk cost framing.

---

### 1C. New Achievement Suggestions (5)

| id | Title | Description | Category | Rationale |
|---|---|---|---|---|
| drift_king | DRIFT KING! | Pull off 5 perfect drifts in a single run. | driving | Driving has no skill-based drift achievement despite near-miss/combo presence. |
| pet_collector_10 | ZOO KEEPER! | Own 10 unique pets simultaneously. | collection | Gap between first_hatch and half_index — no mid-game collection milestone. |
| daily_streak_100 | CENTURY STREAK! | Maintain a 100-day login streak. | social | Bridges the 30→∞ gap. Ultra-retention target. Ties into StreakFOMO systems. |
| code_master | CODE BREAKER! | Redeem 5 different codes. | secret | Rewards community engagement (following socials for codes). Currently no code-related achievement. |
| speed_run_world | BLITZ RUN! | Complete any world in under 60 seconds. | secret | Speedrun-style challenge. Creates "I didn't know that was possible" moments for viewers/streamers. |

---

## Part 2 — PremiumUpsell Surface Mapping

Source: `DACReplicatedStorage/Config/SocialFeedConfig.luau` → `PremiumUpsell` (9 lines)

All 9 lines are currently dark (not surfaced anywhere in the game). Below is a wiring plan for 4 surfaces.

---

### Surface 1: RetentionController Popup (Non-VIP)

**Trigger:** `SessionEndRetention` fires (player idle 3+ minutes or attempting to leave). If `data.isVIP == false`, show one PremiumUpsell line below the retention message.

**Best lines for this surface:**
- Line 3: "Your friends with VIP are earning TWICE what you are right now." — Social comparison at exit = strong pull.
- Line 6: "Still grinding at 1x? Premium makes every run count DOUBLE!" — Frames their current session as wasted potential.
- Line 8: "Premium = more rewards, rarer drops, faster progress. Easy choice!" — Feature dump for the undecided.

**Display:** Small gold text below the main retention toast. No CTA button on the first show — just the text as a seed. On the 2nd retention popup in the same session, add a "Learn More" link that opens the store.

**Suppression rules:**
- Suppress if player purchased ANY Robux product in the last 30 minutes (post-purchase goodwill window).
- Suppress if player has been in-session < 5 minutes (too early, feels pushy).
- Max 1 PremiumUpsell per session via RetentionController.

### Surface 2: Post-Payout Screen (Low-Earn Runs)

**Trigger:** Run payout completes AND `coinEarned < averageVIPPayout * 0.5`. The player just saw a mediocre payout — the contrast with "what VIP could have been" is strongest here.

**Best lines for this surface:**
- Line 1: "VIP drivers earn 2x coins EVERY run. Just saying..." — The understated "just saying" is devastating after a weak payout.
- Line 5: "The fastest drivers go VIP. Double your earnings TODAY!" — Aspirational + actionable.
- Line 6: "Still grinding at 1x? Premium makes every run count DOUBLE!" — Reframes their bad run as a systemic problem (no VIP) rather than a personal one.

**Display:** Below the payout total, in a smaller gold-bordered frame. Include a "Go VIP →" button that opens the Premium section of StorePanel.

**Math reinforcement:** Show `"You earned {actual}. With VIP: {actual * 2}"` alongside the upsell line. Concrete numbers convert better than vague promises.

**Suppression rules:**
- Suppress if the payout was actually decent (above average). Only show on disappointing runs.
- Suppress if player is already VIP (obviously).
- Max 1 per 3 runs — don't show every single time or it becomes banner blindness.
- Suppress for 60 minutes after any Robux purchase.

### Surface 3: Loading Screen Tips (Non-VIP Variant)

**Trigger:** During loading screen, if `data.isVIP == false`, mix PremiumUpsell lines into the LoadingTipsConfig pool at a 1:5 ratio (1 upsell per 5 regular tips).

**Best lines for this surface:**
- Line 2: "Premium unlocks exclusive rides + double rewards. Worth it?" — Informational tone fits loading tips.
- Line 7: "VIP members get exclusive pets you can't find anywhere else!" — FOMO/exclusivity.
- Line 9: "Unlock the full experience — VIP perks are waiting for you!" — Soft CTA.

**Display:** Same style as regular loading tips. No special formatting — it should feel like a "did you know?" tip, not an ad. Gold text color to subtly signal premium.

**Suppression rules:**
- Never show more than 1 upsell line per loading screen session.
- Suppress entirely if player is VIP.
- Rotate through lines 2, 7, 9 sequentially (not random) to avoid repeats across sessions.

### Surface 4: Daily Reward Claim (VIP Bonus Preview)

**Trigger:** When a non-VIP player opens DailyRewardPanel, show a "VIP BONUS" ghost reward next to their current Day N reward, showing what they WOULD have gotten with VIP.

**Best lines for this surface:**
- Line 4: "Go Premium — double coins, exclusive pets, zero regret!" — Direct CTA.
- Line 5: "The fastest drivers go VIP. Double your earnings TODAY!" — Urgency.

**Display:** Below the day calendar, a gold-outlined frame showing:
```
🌟 VIP Bonus: +{bonusAmount} {currency}
"{PremiumUpsell line}"
[Upgrade →]
```

The ghost reward should be slightly transparent (0.35 alpha) with a lock icon — visible enough to create desire, faded enough to show it's locked.

**Suppression rules:**
- Suppress if player already claimed today (show during the anticipation phase, not after the dopamine hit).
- Suppress for the first 3 days of a new player's lifetime (let them enjoy the free experience before upselling).
- Suppress for 24 hours after a declined Premium purchase prompt (respect the "no").

---

### PremiumUpsell Line Assignment Summary

| Line # | Line Text (truncated) | Best Surface |
|---|---|---|
| 1 | "VIP drivers earn 2x coins EVERY run..." | Post-Payout |
| 2 | "Premium unlocks exclusive rides..." | Loading Tips |
| 3 | "Your friends with VIP are earning TWICE..." | RetentionController |
| 4 | "Go Premium — double coins, exclusive pets..." | Daily Reward |
| 5 | "The fastest drivers go VIP..." | Daily Reward / Post-Payout |
| 6 | "Still grinding at 1x?..." | RetentionController / Post-Payout |
| 7 | "VIP members get exclusive pets..." | Loading Tips |
| 8 | "Premium = more rewards, rarer drops..." | RetentionController |
| 9 | "Unlock the full experience..." | Loading Tips |

**Global suppression rules (apply to ALL surfaces):**
1. Never show to VIP players.
2. Never show within 60 minutes of a Robux purchase (any product, not just VIP).
3. Maximum 3 total PremiumUpsell impressions per session across all surfaces.
4. Track `lastUpsellSurface` — never show the same surface twice in a row.
5. After a player dismisses/declines a VIP prompt, cool down for 24 hours on that specific surface.

---

## Part 3 — DailyStreakLossAversion Copy Review

### 3A. Existing MicrocopyConfig StreakFOMO Pools (21 lines)

Source: `DACReplicatedStorage/Config/MicrocopyConfig.luau`

#### StreakFOMOWarning (6 lines) — Score: 4.5/5

**Purpose:** Make the player AFRAID of losing their streak.

| # | Line | Verdict |
|---|---|---|
| 1 | "Your {STREAK}-day streak is ON THE LINE! Come back tomorrow!" | Strong. Clear stakes + CTA. |
| 2 | "Miss tomorrow and {STREAK} days of progress VANISH. Don't risk it!" | Excellent. "VANISH" is visceral. |
| 3 | "Streak x{STREAK} — lose it and you start from DAY ONE. Ouch." | "Ouch" is perfect — casual empathy. |
| 4 | "{STREAK} days built. ONE missed day destroys it ALL!" | Strong loss framing. |
| 5 | "That {STREAK}-day streak took WORK. Don't throw it away!" | Sunk cost framing — effective. |
| 6 | "Your streak is a TROPHY. {STREAK} days — protect it!" | Good ownership framing. |

**Assessment:** This pool is excellent. It hits multiple loss-aversion angles — vanishing progress, sunk cost, ownership, concrete reset pain ("start from DAY ONE"). The only gap: no social comparison angle ("Other players kept THEIR streaks...").

**Suggested addition:**
- **"Players who lose their streak take WEEKS to rebuild. Protect yours!"** — Adds time-cost framing.

#### StreakFOMOTomorrow (5 lines) — Score: 4/5

**Purpose:** Create anticipation/desire for the NEXT reward.

| # | Line | Verdict |
|---|---|---|
| 1 | "Come back tomorrow for Day {STREAK} rewards!..." | Solid CTA. |
| 2 | "Tomorrow's reward is waiting — Day {STREAK} unlocks something GOOD!" | "Something GOOD" is vague — could it preview the actual reward? |
| 3 | "Day {STREAK} is TOMORROW. The longer the streak, the BIGGER the loot!" | Good escalation framing. |
| 4 | "See you tomorrow? Day {STREAK} rewards won't claim themselves!" | Fun personification. |
| 5 | "Your streak multiplier keeps GROWING — Day {STREAK} tomorrow!" | Good — ties to mechanical benefit. |

**Assessment:** Strong but slightly generic. Line 2's "something GOOD" is a missed opportunity — if the system knows the next reward, show it: "Tomorrow: +500 coins!" Concrete > vague.

**Suggested rewrite:**
- Line 2: "Tomorrow's reward is waiting — Day {STREAK} unlocks something GOOD!" → **"Tomorrow's reward: {REWARD}! Day {STREAK} is going to be WORTH IT!"** — If the `{REWARD}` placeholder is available, use it. Concrete rewards drive stronger return behavior than vague promises.

#### StreakFOMOLost (5 lines) — Score: 4/5

**Purpose:** Acknowledge the loss but frame recovery as possible and desirable.

| # | Line | Verdict |
|---|---|---|
| 1 | "Streak BROKEN! You were at {STREAK} days... time to rebuild!" | Good. The pause ("...") adds emotional weight. |
| 2 | "Ouch — {STREAK}-day streak GONE. Start fresh and go HARDER!" | "Ouch" + recovery frame. |
| 3 | "The streak fell! But every champion has a comeback arc!" | Narrative framing. Nice. |
| 4 | "Day 1 again. Your old {STREAK}-day record is waiting to be CRUSHED!" | Turns loss into a new goal. Excellent. |
| 5 | "Streak reset! The road to a new record starts NOW!" | Positive reframe. |

**Assessment:** Good balance of acknowledging pain + recovery motivation. Line 4 is the standout — it reframes the lost streak as a target to beat. No weak lines. Could use one more line with slight humor to lighten the sting.

**Suggested addition:**
- **"Day 1? Been there. The SECOND streak is always better. Let's GO!"** — Humor + confidence.

#### StreakFOMOMilestone (5 lines) — Score: 3.5/5

**Purpose:** Celebrate streak milestones to reinforce the behavior.

| # | Line | Verdict |
|---|---|---|
| 1 | "7-DAY STREAK! A full week of grinding — BONUS UNLOCKED!" | Good. Concrete milestone + reward. |
| 2 | "14-DAY STREAK! Two weeks of dedication! Respect earned!" | "Respect earned" is lukewarm. See rewrite. |
| 3 | "30-DAY STREAK! A FULL MONTH! You're a MACHINE!" | Great escalation. |
| 4 | "50-DAY STREAK! Half a hundred days! Hall of Fame territory!" | "Half a hundred" is an interesting frame — makes 50 sound bigger. |
| 5 | "100-DAY STREAK! CENTURION! Less than 1% reach this!" | Scarcity stat is excellent. |

**Assessment:** Generally good, but line 2 feels flat compared to the others. "Respect earned" doesn't match the escalating energy. Also, the pool only fires at fixed milestones — there's no intermediate reinforcement at 21 days (3 weeks) or 60 days, which are natural psychological checkpoints.

**Rewrite suggestion:**
- Line 2: "14-DAY STREAK! Two weeks of dedication! Respect earned!" → **"14-DAY STREAK! Two weeks LOCKED IN! The casuals could NEVER!"** — Social comparison + competitive framing matches the game's voice.

**Suggested additions (intermediate milestones):**
- **"21-DAY STREAK! Three full weeks! You've built a HABIT! 💪"** — Ties to habit-formation psychology (21-day myth, but effective messaging).
- **"60-DAY STREAK! Two MONTHS of dominance! Absolutely LEGENDARY!"** — Fills the 50→100 gap.

---

### 3B. Design Spec Proposed Pools (12 lines)

Source: `DACStarterGui/DailyStreakLossAversionDesignSpec.luau` → CONFIG ADDITIONS section.

These are NOT yet in MicrocopyConfig. Review for quality before implementation:

#### StreakWarning6h (3 proposed lines) — Score: 3/5

| # | Line | Verdict |
|---|---|---|
| 1 | "Don't let your streak go cold!" | Too gentle for the game's tone. Needs more urgency. |
| 2 | "Your streak needs a little love today." | Way too soft. Sounds like a plant-watering app. |
| 3 | "Keep the fire burning — claim your reward!" | Best of the three but still mild. |

**Recommendation:** These are the FIRST warning the player sees. They should be warm but not toothless. Rewrites:
1. **"Your {STREAK}-day streak is counting on you! Don't let the fire go out!"** — Personification + streak count.
2. **"The clock is ticking on your streak! {HOURS}h left to claim!"** — Concrete time pressure.
3. **"Keep the fire burning — Day {STREAK} rewards are waiting!"** — Upgraded with reward preview.

#### StreakWarning2h (3 proposed lines) — Score: 3.5/5

| # | Line | Verdict |
|---|---|---|
| 1 | "Time's running out on your streak!" | Functional but generic. |
| 2 | "Your streak is fading fast — claim now!" | Good urgency. |
| 3 | "Don't lose {STREAK} days of progress!" | Strong sunk-cost framing. |

**Recommendation:** Line 3 is good. Lines 1-2 need more specificity. Rewrites:
1. **"⚠ {HOURS}h until your {STREAK}-day streak EXPIRES! Claim NOW!"** — Concrete countdown.
2. **"Your streak is DYING — {HOURS}h left! Don't let {STREAK} days vanish!"** — Dramatic verb + time.
3. Keep line 3 as-is — "Don't lose {STREAK} days of progress!" is strong.

#### StreakWarning30m (3 proposed lines) — Score: 4/5

| # | Line | Verdict |
|---|---|---|
| 1 | "FINAL WARNING — your streak dies in minutes!" | Excellent urgency. |
| 2 | "Last chance to save {STREAK} days of work!" | Strong sunk-cost. |
| 3 | "Your streak is about to be gone forever!" | "Forever" is powerful. |

**Recommendation:** This pool is nearly there. The 30-minute warning is the last stand before the Streak Shield upsell. These should be the most emotionally intense copy in the game. One tweak:
- Line 3: "Your streak is about to be gone forever!" → **"Your {STREAK}-day streak dies in MINUTES. This is NOT a drill!"** — Add streak count + urgency intensifier.

#### StreakLost (3 proposed lines) — Score: 4.5/5

| # | Line | Verdict |
|---|---|---|
| 1 | "The flame went out. Time to start again." | Poetic. Perfect for the solemn ceremony moment. |
| 2 | "Every legend starts from Day 1." | Inspirational reframe. |
| 3 | "Your comeback story begins now." | Narrative framing — good for high-engagement players. |

**Recommendation:** These are excellent for the ceremony context (quiet, somber moment after the dots extinguish). The tone correctly shifts from SHOUTING to somber. No changes needed. These complement the existing StreakFOMOLost pool — Lost pool is for recovery energy, these are for the ceremony's emotional beat.

---

## Summary Scoreboard

| Pool | Lines | Score | Action |
|---|---|---|---|
| Achievement Definitions (driving) | 8 | 4/5 | 1 rewrite |
| Achievement Definitions (collection) | 7 | 4/5 | 1 rewrite |
| Achievement Definitions (economy) | 6 | 3.5/5 | 2 rewrites |
| Achievement Definitions (social) | 6 | 3.5/5 | 3 rewrites |
| Achievement Definitions (secret) | 3 | 3/5 | 1 rewrite, add 2 new |
| UnlockToastLines | 6 | 3.5/5 | Add 3 variants |
| CategoryComplete | 15 | 4.5/5 | 1 minor rewrite |
| TotalCompletion | 5 | 5/5 | No changes |
| ProgressNudge | 5 | 3.5/5 | Add 3 variants |
| PremiumUpsell (9 lines) | 9 | N/A | Surface map complete |
| StreakFOMOWarning | 6 | 4.5/5 | Add 1 variant |
| StreakFOMOTomorrow | 5 | 4/5 | 1 rewrite |
| StreakFOMOLost | 5 | 4/5 | Add 1 variant |
| StreakFOMOMilestone | 5 | 3.5/5 | 1 rewrite, add 2 milestones |
| StreakWarning6h (proposed) | 3 | 3/5 | All 3 rewritten |
| StreakWarning2h (proposed) | 3 | 3.5/5 | 2 rewritten |
| StreakWarning30m (proposed) | 3 | 4/5 | 1 rewritten |
| StreakLost (proposed) | 3 | 4.5/5 | No changes |

**Total rewrites:** 16 lines | **Total new additions:** 12 lines | **Total reviewed:** ~80 lines

---

*Content Strategist — POLA-202*
