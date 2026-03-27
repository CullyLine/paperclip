--!strict
--[[
	Dopamine microcopy pools for celebration moments, toasts, and popups.

	Each category is a flat table of strings. The UI picks randomly
	(or by tier) at runtime. Keep every line punchy and short — 
	these appear in small toast frames.
]]

local MicrocopyConfig = {}

--------------------------------------------------------------------------
-- CODE REDEMPTION
--------------------------------------------------------------------------

MicrocopyConfig.CodeRedeemSuccess = {
	"Code accepted! Loot incoming!",
	"BOOM — redeemed! Check your inventory!",
	"That code was VALID. You just got paid!",
	"Reward unlocked! Thanks for the code!",
	"Nice find! Rewards are hitting your account NOW.",
	"Code cashed in! You're welcome.",
	"Cha-ching! Code redeemed successfully!",
	"SECRET CODE ACTIVATED. Enjoy the goodies!",
}

-- Surface: CodesPanel.luau → error state label/toast below the code input field.
-- Show on invalid code submit (code not found in server code list).
-- Display as red-tinted text feedback; auto-dismiss after 3s or on next input.
MicrocopyConfig.CodeRedeemError = {
	"Hmm, that code didn't work — double-check the spelling?",
	"We couldn't match that one — new codes drop often, stay tuned!",
	"Not a match this time — try copy/paste so nothing gets lost!",
	"That code isn't active — typos happen; give it another shot!",
	"Doesn't look familiar — try any mix of caps; we match codes case-insensitively.",
	"That combo isn't in our list yet — fresh drops roll out regularly!",
	"No luck yet — it happens; the next code might be the one!",
	"Still hunting? Socials and patch notes are the usual hideouts!",
}

-- Surface: CodesPanel.luau → expired-code feedback label below the code input field.
-- Show when CodeService returns inactive code (CODES[code].active == false) — no live timestamps in CODES.
-- Display as amber/yellow text; append a follow-us CTA nudge to drive social follows.
MicrocopyConfig.CodeRedeemExpired = {
	"That code expired! They go fast — follow us for the next one!",
	"Too late! This one's gone. Stay tuned for fresh codes!",
	"Expired code! The early bird gets the loot. Watch socials!",
	"This one's retired — but the NEXT drop could be even bigger!",
	"Gone in a flash! Turn on notifications so you catch the next!",
	"Missed the window — no worries, another code is always cooking!",
}

-- Surface: CodesPanel → server rate limit (too many attempts per minute).
MicrocopyConfig.CodeRedeemRateLimited = {
	"Whoa — slow down! Too many tries. Give it a minute.",
	"You're hitting that button fast! Chill a sec and try again.",
	"Rate limit: take a breather, then redeem again.",
	"Pump the brakes — wait a bit before the next attempt!",
}

-- Surface: CodesPanel → invalid characters / length (server rejects before lookup).
MicrocopyConfig.CodeRedeemFormatError = {
	"That text doesn't look like a code — letters and numbers only!",
	"Codes are short alphanumeric strings — no spaces or weird symbols!",
	"Try again with a clean code (A–Z, 0–9), no extras!",
}

-- Surface: CodesPanel → server returned "Already redeemed" (CodeService.redeem).
MicrocopyConfig.CodeRedeemAlreadyUsed = {
	"You already cashed that one in — new codes drop all the time!",
	"This code's already on your account — hunt for the next drop!",
	"Double redeem blocked — you grabbed this reward already!",
	"Already unlocked — try a fresh code from socials or patch notes!",
	"That one's in the books — save the next code for a new reward!",
}

--------------------------------------------------------------------------
-- CLIENT HUD / TOAST LANE (Bootstrap, VFX popups, egg spotlight, friend chip, achievements)
--------------------------------------------------------------------------

-- Default when server EasterEggDiscovered has no custom hint string.
MicrocopyConfig.EasterEggDiscoveryDefaultToast = "You found a hidden image!"
-- First arg to milestonePopup on easter egg find (short headline).
MicrocopyConfig.EasterEggSecretFoundHeadline = "SECRET FOUND!"
-- Near-miss coin popup flavor (Bootstrap NearMissClaim). {MULT} = short mult (e.g. %.2g), {STREAK} = int.
MicrocopyConfig.NearMissCurrencyFlavorFormat = "Near miss · x{MULT} · streak {STREAK}"

-- Egg store spotlight chip (UIController ensureSpotlightBadge).
MicrocopyConfig.UiEggStoreSpotlightBadge = "BEST"

-- Friend lobby bonus chip (FriendBonusHUD). {PCT} = server percent label e.g. "+10%".
MicrocopyConfig.FriendBonusHudLabelFormat = "Friends {PCT}"

-- Achievement lane toasts (AchievementController) — fallback + category/total celebration headlines.
MicrocopyConfig.AchievementToastHeadlineGeneric = "ACHIEVEMENT"
MicrocopyConfig.AchievementToastCategoryCompleteHeadline = "CATEGORY COMPLETE!"
MicrocopyConfig.AchievementToastTotalCompletionHeadline = "100% ACHIEVEMENTS!"

--------------------------------------------------------------------------
-- CURRENCY GAIN CELEBRATIONS
--------------------------------------------------------------------------

MicrocopyConfig.CoinGainSmall = {
	"+{AMOUNT} coins",
	"{AMOUNT} coins earned",
	"+{AMOUNT}",
	"Nice! +{AMOUNT} coins",
	"Ka-ching! +{AMOUNT}",
	"Coins incoming: +{AMOUNT}",
	"Small win, big vibes! +{AMOUNT}",
	"Every coin counts! +{AMOUNT}",
}

MicrocopyConfig.CoinGainMedium = {
	"Nice haul! +{AMOUNT} coins!",
	"Cha-ching! {AMOUNT} coins!",
	"Stacking up! +{AMOUNT}!",
	"Coins on the move! +{AMOUNT} coins!",
	"Keep it rolling! +{AMOUNT}!",
}

MicrocopyConfig.CoinGainLarge = {
	"MASSIVE PAYDAY! +{AMOUNT} COINS!",
	"YOU'RE RICH! {AMOUNT} coins just dropped!",
	"JACKPOT! +{AMOUNT} coins! What a run!",
	"INSANE PAYOUT! {AMOUNT} coins in one go!",
	"COIN TSUNAMI! +{AMOUNT}! Who even ARE you?!",
	"LEGENDARY HAUL! {AMOUNT} coins! The vault is overflowing!",
}

-- Optional extra lines for CoinGainLarge (HUD). Merged at pick time — keep base pool stable.
-- Phase 4: reward-forward flex without player-directed "whale" slang (see docs/MicrocopyWhaleTermCleanup_Phase4.md).
MicrocopyConfig.CoinGainLargeOptional = {
	"MEGA STACK! +{AMOUNT} coins — elite haul energy!",
	"HALL-OF-FAME TICK! +{AMOUNT} coins on the board!",
	"TOP-LOBBY VIBES! +{AMOUNT} coins in one grab!",
	"THAT'S A BOSS PICKUP! +{AMOUNT} coins!",
	"Vault-buster! +{AMOUNT} coins — keep the line hot!",
}

MicrocopyConfig.GemGain = {
	"Bonus loot! +{AMOUNT}!",
	"SPARKLE! {AMOUNT} currency acquired!",
	"Nice! +{AMOUNT} incoming!",
	"Shiny! +{AMOUNT} just for you!",
	"BONUS! +{AMOUNT}! Keep going!",
}

--------------------------------------------------------------------------
-- PREMIUM / VIP
--------------------------------------------------------------------------

MicrocopyConfig.PremiumWelcome = {
	"Welcome back, VIP! +50% coins on every run — stacks with passes. Let's dominate.",
	"The elite driver returns! All premium perks are live. Floor it!",
	"VIP status: CONFIRMED. You're playing on a whole different level.",
}

MicrocopyConfig.VIPNametagFlavor = {
	"★ VIP DRIVER ★",
	"⚡ ELITE MEMBER ⚡",
}

MicrocopyConfig.PremiumLoadingTips = {
	"Premium perk: +50% coins on every run (stacks with passes). Others wish they were you!",
	"Premium perk: Daily Claim adds a Premium Box — bonus coins or sometimes an egg!",
	"Premium perk: Your coin math stacks with world tiers, pets, and Game Passes — juice every layer!",
	"Premium perk: Stack Roblox Premium with Double Coins and pets — your finishes get huge!",
	"Premium perk: Roblox's monthly Premium stipend stacks with everything you buy here!",
	"Premium perk: First-class treatment in the lobby. You earned the spotlight!",
}

--------------------------------------------------------------------------
-- PLAYTIME MILESTONES
--------------------------------------------------------------------------

MicrocopyConfig.PlaytimeGemReward = {
	"You've been grinding! Here's a coin bonus for your dedication!",
	"{MINUTES} minutes of pure driving. You EARNED this bonus!",
	"Time flies when you're fast! Coin bonus for sticking around!",
	"Dedicated driver bonus! Keep that engine running!",
	"Play longer, earn more! Bonus coins for your commitment!",
}

-- Surface: RetentionController.luau → periodic streak celebration toast (in claim window).
-- Session-start streak lines use SessionWelcomeStreak / ReturnStreakWelcome in Bootstrap.local.luau.
-- Pick randomly from this pool and inject {STREAK}; same notification lane as streak warnings.
MicrocopyConfig.PlayStreak = {
	"Day {STREAK} streak! You're on FIRE! 🔥",
	"{STREAK}-day streak! Consistency is king — bonus incoming!",
	"STREAK x{STREAK}! Come back tomorrow to keep the party going!",
	"{STREAK} days straight! The grind never stops!",
	"Day {STREAK}! At this point you basically live here. Respect.",
	"Unstoppable! {STREAK}-day streak locked in!",
}

--------------------------------------------------------------------------
-- EVENT BANNERS
-- Generic rotating headlines for future timed events (NOT the Founder's Bonus window).
-- Founder's Bonus uses FounderEventBannerHeadlines / FounderEventCountdown — must match
-- EventService (2x coins; window = FOUNDER_WINDOW_* in EventWindowConfig.luau).
--------------------------------------------------------------------------

MicrocopyConfig.EventBannerHeadlines = {
	"LAUNCH EVENT: 3x Coins + Exclusive Egg — GO GO GO!",
	"THE BIG ONE IS HERE: Limited-time event cars, massive rewards, zero chill!",
	"EVENT LIVE: Hatch the Launch Mythic before the window closes!",
	"DRIVE HARDER: Event multipliers are STACKED right now!",
	"GRAND OPENING: New world, new rides, new records to SMASH!",
}

-- Shown only while LaunchEventState.founderActive (2x coin multiplier from EventService).
MicrocopyConfig.FounderEventBannerHeadlines = {
	"FOUNDER'S BONUS: 2x COINS!",
	"LAUNCH WINDOW: 2x COINS — GRIND WHILE IT LASTS!",
	"FOUNDER'S BONUS LIVE — DOUBLE COINS ON EVERY RUN!",
	"2x COINS FOR THE OPENING WINDOW — FLOOR IT!",
	"FOUNDER WINDOW: STACK COINS AT 2x BEFORE IT ENDS!",
}

MicrocopyConfig.EventCountdown = {
	"⏳ LAST HOUR! Event bonuses end soon — claim what you can!",
	"⚠️ ALMOST OVER! Minutes left on event exclusives!",
	"🚨 FINAL COUNTDOWN! Grab event rewards before the timer ends!",
}

-- Last-hour urgency lines under FounderEventBannerHeadlines (matches 2x / window end only).
MicrocopyConfig.FounderEventCountdown = {
	"⏳ LAST HOUR! Founder's Bonus (2x coins) ends soon!",
	"⚠️ ALMOST OVER! Founder's window closing — squeeze in more runs!",
	"🚨 FINAL COUNTDOWN! 2x coins end when the timer hits zero!",
}

-- One-shot join notification when founder multiplier first applies (EventService).
MicrocopyConfig.FounderBonusJoinNotification = "Founder's Bonus: 2x coins for the launch window!"

--------------------------------------------------------------------------
-- DAILY REWARD PANEL
-- Primary CTA on pre-built ClaimBtn (DailyRewardPanel.luau).
-- Mobile: MultLabel + streak meter use short lines (narrow width).
--------------------------------------------------------------------------
MicrocopyConfig.DailyRewardClaimButtonDefault = "Claim reward"
MicrocopyConfig.DailyRewardClaimButtonProgress = "Claiming..."
-- Streak meter title (optional emoji prefix added in UI for high streaks).
MicrocopyConfig.DailyRewardStreakMeterTitle = "Streak progress"
-- {CYCLE} = int, {MULT} = multiplier string (e.g. 1.25).
-- Server: streak breaks when claim gap is 2+ UTC epoch days (DailyRewardService), not a rolling 48h clock.
MicrocopyConfig.DailyRewardCycleMultFormat = "Cycle {CYCLE} • {MULT}x rewards — claim each UTC day or streak resets"
-- Narrow phones / small Studio viewport: ≤ ~50 chars so one line fits ~320px panels at 15px text.
MicrocopyConfig.DailyRewardCycleMultFormatCompact = "Cycle {CYCLE} • {MULT}x — daily UTC claim keeps streak"
-- {MDAY} = milestone day, {LEFT} = claims remaining, {CLAIM_WORD} = claim | claims.
MicrocopyConfig.DailyRewardNextMilestoneFormat = "Next: Day {MDAY} · {LEFT} {CLAIM_WORD} left"

--------------------------------------------------------------------------
-- SESSION WELCOME
-- Randomly picked when the player loads in. {STREAK} = daily streak count.
--------------------------------------------------------------------------

MicrocopyConfig.SessionWelcome = {
	"The road missed you! Let's GO!",
	"Time to burn rubber!",
	"Your pets were getting lonely...",
	"Engines are warm. YOU'RE UP.",
	"Back behind the wheel where you belong!",
	"Ready to stack some SERIOUS coins?",
	"Another day, another drive. LET'S EAT.",
	"The lobby just got a whole lot faster!",
	"Welcome back, speed demon!",
	"Good to see you — new records are waiting!",
	"Lobby energy: UP. Let's make some coin!",
	"Helmets on, vibes high. Drive time!",
	"Your streak called — it wants another win!",
}

MicrocopyConfig.SessionWelcomeStreak = {
	"Day {STREAK} of domination! Keep it going!",
	"{STREAK}-day streak? You're UNSTOPPABLE!",
	"Streak x{STREAK}! The grind doesn't rest and neither do YOU!",
	"Day {STREAK}! At this point the game should pay YOU rent.",
	"{STREAK} days LOCKED IN. Rewards are stacking!",
}

-- Return + streak: session-start when {STREAK} >= 2 and days away >= 1 (see retention.daysSinceLastSession).
-- Phase 4: reward-forward, bubbly — no player "whale" framing (docs/RetentionWinbackMicrocopySpec.md).
MicrocopyConfig.ReturnStreakWelcome = {
	"You're BACK — and still on a {STREAK}-day streak?! Main character energy!",
	"Return lap + Day {STREAK} streak? The highway saved your spot!",
	"Missed you! Streak still alive: {STREAK} days. Don't leave us hanging!",
	"Back in the lobby with a {STREAK}-day streak locked — that's dedication!",
	"Day {STREAK} streak survived your break — now finish what you started!",
	"Pick up where you left off — {STREAK}-day streak still glowing. Worth the encore!",
	"{STREAK} days deep and you came back again — consistency looks good on you!",
	"Return visit + Day {STREAK} streak locked — the lobby held your lane!",
}

-- Soft win-back after ~7+ calendar days away (server: retention.daysSinceLastSession).
MicrocopyConfig.SessionWinback7d = {
	"A week away? The road's been quiet — your run is overdue!",
	"Welcome BACK — new payouts, same chaos. One lap to shake the rust off!",
	"7+ days gone and the lobby missed the smoke trails. Let's GO!",
	"You vanished — the streak forgave you, the coins didn't. Time to stack!",
	"Re-entry mode: warm up the tires, then break your old PB!",
}

-- Softer win-back after ~14+ calendar days away (gentle FOMO, no guilt-tripping).
MicrocopyConfig.SessionWinback14d = {
	"It's been a MINUTE — cars got faster while you were gone. Catch up!",
	"Two weeks off? No judgment — the track's still YOURS. Floor it!",
	"Long break, big comeback energy. New rewards landed — claim them!",
	"The garage missed you. Hop in — your pets are literally waiting.",
	"Welcome back, driver — let's turn \"later\" into RIGHT NOW!",
}

--------------------------------------------------------------------------
-- IDLE RETENTION POPUP (AFK modal)
-- Header floats above body copy; body line comes from SocialFeedConfig.SessionEndRetention.
-- Phase 4: playful urgency without shaming (see docs/RetentionWinbackMicrocopySpec.md).
--------------------------------------------------------------------------

MicrocopyConfig.RetentionIdleHeader = {
	"Don't go yet!",
	"Hold up — one more lap?",
	"Still here? Perfect — stay a minute!",
	"The finish line's literally glowing!",
	"Wait — rewards are stacking!",
}

--------------------------------------------------------------------------
-- QUEST PANEL
-- QuestComplete: shown when a quest finishes.
-- QuestProgress: shown when a quest is 80%+ done.
--------------------------------------------------------------------------

MicrocopyConfig.QuestComplete = {
	"CRUSHED IT!",
	"Another one bites the dust!",
	"Quest? More like CONQUERED!",
	"Too EASY. What's next?",
	"DONE AND DUSTED. Reward incoming!",
	"You just made that look effortless!",
	"Quest DEMOLISHED. Loot secured!",
	"That quest never stood a CHANCE.",
}

MicrocopyConfig.QuestProgress = {
	"Almost there...",
	"So close you can TASTE it!",
	"Don't stop now — the finish line is RIGHT THERE!",
	"Just a little more! You've GOT this!",
	"Final stretch! FLOOR IT!",
	"Quest bar is basically glowing — one more push!",
	"You're in the clutch zone — finish strong!",
	"So close the rewards can practically wave at you!",
	"This quest is about to POP — stay on it!",
}

--------------------------------------------------------------------------
-- PET INDEX MILESTONES
-- Shown when the player hits collection thresholds. {PERCENT} = % complete.
--------------------------------------------------------------------------

MicrocopyConfig.PetIndexMilestone = {
	"{PERCENT}% collected! You're a PET LEGEND!",
	"Halfway there — keep hatching!",
	"{PERCENT}% of ALL pets! The index fears you!",
	"Collection at {PERCENT}%! Others can only DREAM!",
	"PET MASTER! {PERCENT}% and counting!",
}

--------------------------------------------------------------------------
-- REBIRTH PANEL
-- RebirthCelebration: shown after rebirthing. {COUNT} = rebirth number.
-- RebirthTeaser: shown to tease players into rebirthing.
--------------------------------------------------------------------------

MicrocopyConfig.RebirthCelebration = {
	"Rebirth #{COUNT} complete! POWER SURGE!",
	"Born again, STRONGER than ever!",
	"Rebirth x{COUNT}! Speed permanently boosted!",
	"#{COUNT}! Every rebirth makes you MORE dangerous!",
	"RESET. RISE. REPEAT. Rebirth {COUNT} in the books!",
	"Rebirth #{COUNT}! The universe just got smaller.",
}

MicrocopyConfig.RebirthTeaser = {
	"Your next rebirth unlocks INSANE power...",
	"Reset to rise HIGHER!",
	"One rebirth away from your biggest speed jump yet!",
	"The strongest drivers rebirth early. Just saying...",
	"Rebirth = permanent speed juice. Future you says thanks!",
	"Coins reset, POWER doesn't — that's the rebirth flex!",
	"Ready to glow up? Your next rebirth is a whole new gear!",
	"Big numbers later > small numbers now. Rebirth when you're ready!",
}

--------------------------------------------------------------------------
-- BATTLE PASS PANEL (DACStarterGui — BattlePassPanel.luau)
-- Two tracks: free column (everyone) vs premium column (one purchase per season).
--------------------------------------------------------------------------

-- Progress line. {TIER} = current tier, {TIER_MAX} = BattlePassConfig.TIER_COUNT, {XP} = formatted Pass XP.
MicrocopyConfig.BattlePassSummaryProgress = "Tier {TIER} / {TIER_MAX} • Pass XP: {XP}"
-- Second line under progress (player does not own premium track).
MicrocopyConfig.BattlePassHintFree = "Free: everyone. Premium (one buy): right-column bonus each tier."
-- Second line when premium is owned.
MicrocopyConfig.BattlePassHintOwned = "Premium on — claim both columns each tier."
-- Buy button. {PRICE} = Robux number from DevProductConfig.
MicrocopyConfig.BattlePassBuyPremiumFormat = "UNLOCK PREMIUM TRACK ({PRICE} R)"
-- Shown in the premium reward cell when the player has not purchased the track.
MicrocopyConfig.BattlePassPremiumLockedReward = "\u{1F512} Premium track"
-- Premium column button when not owned (not tappable until pass is purchased).
MicrocopyConfig.BattlePassPremiumColumnLocked = "Unlock track"
-- Tier row column headers + button states (BattlePassPanel.luau dynamic rows).
MicrocopyConfig.BattlePassTrackLabelFree = "Free"
MicrocopyConfig.BattlePassTrackLabelPremium = "Premium"
MicrocopyConfig.BattlePassClaimCta = "Claim"
MicrocopyConfig.BattlePassClaimedState = "Claimed"
MicrocopyConfig.BattlePassLockedState = "Locked"
MicrocopyConfig.BattlePassClaimWorking = "…"

--------------------------------------------------------------------------
-- STORE PANEL + SHARED IAP PLACEHOLDER (StorePanel.luau, BattlePassPanel.luau)
-- Section headers, car-upgrade CTAs, FOMO badge fallbacks when config pools empty.
--------------------------------------------------------------------------

MicrocopyConfig.StoreSectionCarUpgrades = "Car upgrades (equipped car)"
MicrocopyConfig.StoreSectionCarsSoftCurrency = "Cars (soft currency)"
MicrocopyConfig.StoreSectionGamePasses = "Game Passes"
MicrocopyConfig.StoreSectionDevProducts = "Developer Products"
MicrocopyConfig.StoreSectionBadgeProfile = "Badge profile"
MicrocopyConfig.StoreOwnedBadge = "OWNED!"
MicrocopyConfig.StoreBuyButtonYours = "YOURS!"
MicrocopyConfig.StoreBuyButtonOwnedIdle = "Owned"
MicrocopyConfig.StoreUpgradeButton = "Upgrade"
MicrocopyConfig.StoreBuyButton = "Buy"
-- Roblox IAP row when productId/gamePassId is 0 (Studio / unlink).
MicrocopyConfig.IapBuyNotLinked = "Not linked"

-- Client: Marketplace prompt already open (IapPromptGuard) or client debounce (rapid taps).
MicrocopyConfig.IapPurchasePromptBusy = {
	"Hang tight — finish or close the Robux window first!",
	"One purchase at a time — let that checkout finish!",
	"The store's already talking to Roblox — give it a sec!",
	"Almost there — wait for the purchase prompt to close!",
}
MicrocopyConfig.StoreFomoBadgeFallbackEvent = "EVENT"
MicrocopyConfig.StoreFomoBadgeFallbackVip = "VIP"

--------------------------------------------------------------------------
-- WORLD PANEL (WorldPanel.luau — row actions + status; stats line formats)
--------------------------------------------------------------------------

MicrocopyConfig.WorldActionYouAreHere = "You are here"
MicrocopyConfig.WorldActionTravel = "Join"
MicrocopyConfig.WorldActionStartRun = "Start Run"
MicrocopyConfig.WorldActionUnlock = "Unlock"
MicrocopyConfig.WorldStatusFree = "Free"
MicrocopyConfig.WorldStatusUnlocked = "Unlocked"
MicrocopyConfig.WorldStatusStarterWorld = "Starter world"
MicrocopyConfig.WorldCurrentWorldBadge = "CURRENT WORLD"
-- {MULT} = integer or one-decimal multiplier string.
MicrocopyConfig.WorldCoinMultFormat = "{MULT}x Coins"
-- {STUDS} = formatted stud count.
MicrocopyConfig.WorldHighwayStudsFormat = "{STUDS} studs highway"
-- When WorldUnlockConfig.UnlockHeadlines is empty (defensive).
MicrocopyConfig.WorldUnlockHeadlineFallback = "NEW WORLD UNLOCKED!"
-- {COST} formatted, {CURRENCY} currency id.
MicrocopyConfig.WorldLockedStatusFormat = "Locked \u{2022} {COST} {CURRENCY}"

--------------------------------------------------------------------------
-- CODES PANEL — in-flight redeem (CodesPanel.luau)
--------------------------------------------------------------------------

MicrocopyConfig.CodeRedeemInProgress = "Redeeming\u{2026}"

--------------------------------------------------------------------------
-- REWARD CHEST OVERLAY (RewardChestAnimation.luau — run-end / claim total line)
--------------------------------------------------------------------------

MicrocopyConfig.RewardChestTotalValueFormat = "Total value: {VALUE}"
MicrocopyConfig.RewardChestClaimedLine = "Claimed!"

--------------------------------------------------------------------------
-- RETENTION POPUP — Battle Pass one-liner (RetentionController.luau)
--------------------------------------------------------------------------

-- {XP} = Pass XP still needed to finish the current tier segment; {TIER} = tier index (1..TIER_MAX).
MicrocopyConfig.RetentionBattlePassXpToFinishTier = "Battle Pass: {XP} Pass XP to finish tier {TIER}"
MicrocopyConfig.RetentionBattlePassMaxTier = "Battle Pass: max tier reached this season"

--------------------------------------------------------------------------
-- PAYOUT PANEL CHROME (StarterGui DACPayout — PayoutPanel.luau)
-- Static labels: titles, Season XP line, Battle Pass tier line. No HUD layer names here
-- (UIDisplayLayers / UILayerStack owns z-order; copy must not reference layer IDs).
--------------------------------------------------------------------------

MicrocopyConfig.PayoutTitleRunComplete = "Run complete!"
MicrocopyConfig.PayoutTitleRunOfDay = "RUN OF THE DAY!"

-- Season XP line under the bar. {XP} = formatted XP earned this run.
MicrocopyConfig.PayoutSeasonXpFormat = "+{XP} Season XP"

-- Battle Pass progress label. {TIER} = current tier number, {TIER_MAX} = max tier (see BattlePassConfig.TIER_COUNT).
MicrocopyConfig.PayoutBattlePassTierFormat = "Battle Pass • Tier {TIER} / {TIER_MAX}"

-- Multiplier badge chips (buildMultiplierBadges). {MULT} = formatted multiplier (e.g. "2.00").
MicrocopyConfig.PayoutBadgeFounderFormat = "Founder x{MULT}"
MicrocopyConfig.PayoutBadgePetsFormat = "Pets x{MULT}"
MicrocopyConfig.PayoutBadgePremiumFormat = "Premium x{MULT}"
MicrocopyConfig.PayoutBadgePassFormat = "Pass x{MULT}"
-- Coin Boost game pass (+10% on run finish). Matches RunService breakdown.coinBoostMultiplier.
MicrocopyConfig.PayoutBadgeCoinBoostFormat = "Coin Boost x{MULT}"
MicrocopyConfig.PayoutBadgeRunOfDayFormat = "Run of Day x{MULT}"
MicrocopyConfig.PayoutBadgeGroupFormat = "Group x{MULT}"
MicrocopyConfig.PayoutBadgeFriendsFormat = "Friends x{MULT}"

--------------------------------------------------------------------------
-- PAYOUT FLEX
-- Contextual brag lines shown on the run-end payout screen.
-- Placeholders: {COINS}, {DISTANCE}, {LAPS}, {MULTIPLIER}, {RANK}
--------------------------------------------------------------------------

-- Ultra-high coin runs (e.g. coins > 100k). Shown instead of PayoutFlexBig when threshold hits.
MicrocopyConfig.PayoutFlexMega = {
	"ULTRA PAYDAY! {COINS} coins — that's a LOBBY-RESETTING run!",
	"VAULT BUSTER! {COINS} coins in one finish — elite tier unlocked!",
	"MEGA HAUL TIER! {COINS} coins — the highway couldn't keep up!",
	"Signature payout run! {COINS} coins — you're in the top earn bracket!",
	"{COINS} coins?! That's not a payout — that's a STATEMENT!",
}

MicrocopyConfig.PayoutFlexBig = {
	"That run just PRINTED! {COINS} coins in one go!",
	"Built DIFFERENT. {DISTANCE}m and counting!",
	"Elite haul energy — that payout turned heads in the lobby.",
	"{LAPS} laps? That's not driving — that's a STATEMENT.",
	"The bank called. They need a bigger vault. +{COINS}!",
	"Your wallet just flinched. {COINS} coins incoming!",
	"Multipliers STACKED: x{MULTIPLIER}. That payout is OBSCENE.",
	"Ranks #{RANK}+ WISH they had this run. You just did THAT.",
}

-- Optional appendix for PayoutFlexBig (>10k coins). Extends variety without duplicating base lines.
MicrocopyConfig.PayoutFlexBigOptional = {
	"MEGA HAUL! {COINS} coins — that's signature-driver energy!",
	"Signature run! {COINS} coins and the lobby noticed!",
	"Elite payday! {COINS} coins — multipliers did the heavy lifting!",
	"Top-board energy! {COINS} coins in one finish!",
	"That payout is STACKED! {COINS} coins — run it back!",
}

MicrocopyConfig.PayoutFlexPersonalBest = {
	"NEW PERSONAL BEST! This is YOUR road now!",
	"Record SHATTERED! You've never driven this hard!",
	"PB CRUSHED! That old record didn't stand a chance!",
	"New record! You just lapped your former self!",
	"Personal best OBLITERATED! Keep pushing — the ceiling is fake!",
	"That's YOUR best run EVER. Let that sink in.",
}

MicrocopyConfig.PayoutFlexMultiplier = {
	"x{MULTIPLIER} multiplier?! Your bonuses have bonuses!",
	"Everything stacked! x{MULTIPLIER} total — that's elite.",
	"x{MULTIPLIER} from your bonuses on this finish — world, pets, passes, the works!",
	"x{MULTIPLIER} active. Every coin earned HITS DIFFERENT.",
	"Stacked to the MAX! x{MULTIPLIER} makes you untouchable!",
}

MicrocopyConfig.PayoutFlexRunOfDay = {
	"RUN OF THE DAY! Nobody's touching this score!",
	"The DAILY BEST! You just became a server legend!",
	"Run of the Day — the whole lobby just saw YOUR name!",
	"Today's top dog! Run of the Day is YOURS!",
	"That run was HISTORIC. Run of the Day, locked!",
}

-- Modest / low-hype runs (not Run of the Day, below big-coin tiers). Empathetic — never mock low payouts.
-- Same placeholders as PayoutFlex. Shown when pickPayoutFlexLine falls through without ROTD celebration.
MicrocopyConfig.PayoutFlexModest = {
	"Run banked: +{COINS} coins — small hauls still unlock upgrades!",
	"Every lap counts — +{COINS} coins toward your next goal!",
	"Not every finish is flashy — you still earned +{COINS} this run!",
	"Steady driving pays off — +{COINS} coins in the bag!",
	"Tough session? You still moved forward — +{COINS} secured!",
	"Short run, still progress — +{COINS} coins closer to the next unlock!",
}

-- Rare edge: zero coins earned (e.g. instant end). Placeholders: {DISTANCE}, {LAPS}, {MULTIPLIER}, {RANK} (no {COINS}).
MicrocopyConfig.PayoutFlexZeroCoins = {
	"Tough run — no coins this time; longer drives and multipliers stack payouts fast!",
	"Coins didn't land on that one — try another lap when you're ready!",
	"Empty payout — happens! Boosters and distance usually fix it next run!",
	"No coins banked — shake it off; the next drive is a clean slate!",
}

-- Optional second line under the main brag (PayoutPanel appends with newline when present).
-- Daily login streak from server (`dailyLoginStreak` on run results). {STREAK} = current streak day index.
MicrocopyConfig.PayoutStreakContinuation = {
	"Day {STREAK} daily streak — keep claiming to stack bigger rewards!",
	"{STREAK}-day streak still rolling! Next UTC claim day levels you up!",
	"{STREAK}-day login streak active — don't break the chain!",
	"Daily streak at {STREAK}! Consistency = bigger multipliers over time!",
}

-- Near-miss chain highlight after the run. {CHAIN} = best chain this run, {BONUS} = bonus coins from near-misses (formatted).
MicrocopyConfig.PayoutNearMissTease = {
	"Near-miss chain x{CHAIN}! The track was FEEDING you bonus coins!",
	"x{CHAIN} near-miss heat — +{BONUS} bonus coins from pure focus!",
	"You danced the lane for x{CHAIN} — +{BONUS} banked during the run (near-miss bonus)!",
	"Close calls x{CHAIN}! Near-miss juice added +{BONUS} to this run!",
}

-- Soft monetization-adjacent nudges (wording only). Shown when upsell branch runs; no product IDs in strings.
MicrocopyConfig.PayoutSoftUpsellNoPremium = {
	"Tip: Roblox Premium (+50% coins) stacks with pets and passes — bigger payouts next run!",
	"Want fatter finishes? Premium adds +50% to every run's coin payout!",
	"Elite drivers stack Premium + pets — your next run could pop harder!",
}

MicrocopyConfig.PayoutSoftUpsellNoPass = {
	"Double Coins pass doubles the grind — worth a peek in the store!",
	"Passes stack with everything — one upgrade, twice the payday!",
}

--------------------------------------------------------------------------
-- PHASE 4 — SOCIAL PROOF & SHARE PROMPTS (POLA-363)
-- Soft UGC, invite, and lobby hype without a hard friends-graph dependency.
-- Tone: premium, confident (monetization north star). Engineer wires gates + placeholders.
--------------------------------------------------------------------------

-- Surface: PayoutPanel.luau — one-line nudge after a big finish (e.g. PayoutFlexMega / high coin branch,
-- or secondary line under the main brag when share/screenshot moment is enabled). Not a system share sheet;
-- suggests capturing the win. Optional {COINS} for the headline amount.
MicrocopyConfig.PayoutShareScreenshotMoment = {
	"Worth a screenshot — {COINS} coins is a flex moment.",
	"That payout belongs in your highlight reel.",
	"Elite run. Capture it — numbers like {COINS} don't happen every lap.",
	"Signature finish. Screenshot energy if you're feeling it.",
	"Lobby-worthy numbers. Save the frame while it's hot.",
	"This is the run your friends ask about — snag the proof.",
	"Vault-tier payout. A quick capture keeps the brag honest.",
}

-- Surface: HUD toast (info), MenuHub strip, or optional subline on Store/World when invite UX exists.
-- Soft optional invite — never guilt-trips; no "you must invite" framing.
MicrocopyConfig.SocialInviteFriendSoft = {
	"Got a crew? Bring them — co-op energy stacks the fun.",
	"Know someone who'd love this grind? The lobby has room.",
	"Fast friends make faster rivals — invite when it feels right.",
	"Share the lane — every driver lifts the lobby vibe.",
}

-- Surface: Loading tip, HUD margin chip, or menu subtitle — ONLY when server/client has a live concurrent
-- player count. Inject {PLAYERS} as formatted integer (e.g. 1.2K, 842). Do not show if data missing.
MicrocopyConfig.SocialProofPlayerCount = {
	"{PLAYERS} drivers on the road right now — you're in the main lobby.",
	"Trending session: {PLAYERS}+ players stacking coins with you.",
	"Live lobby: {PLAYERS} drivers — peak energy, premium grind.",
	"{PLAYERS} players deep — the highway's never quiet.",
}

-- Surface: same lanes as SocialProofPlayerCount when you want hype without a numeric claim (A/B or fallback).
-- Safe if analytics are unavailable — no false statistics.
MicrocopyConfig.SocialProofLobbyEnergy = {
	"Servers are buzzing — premium grind hours.",
	"The lobby's in motion — elite drivers everywhere.",
	"High-traffic window — stack runs while the energy's up.",
	"Main-character hours — the road's full of rivals worth chasing.",
}

--------------------------------------------------------------------------
-- COLLECTION PROGRESS
-- Granular pet index progress lines. {FOUND}/{TOTAL}, {PERCENT}, {NEXT}.
-- Tiers: early (0-24%), mid (25-49%), late (50-74%), final (75-99%),
-- and complete (100%).
--------------------------------------------------------------------------

MicrocopyConfig.CollectionEarly = {
	"{FOUND}/{TOTAL} discovered — the adventure is just starting!",
	"First finds! {PERCENT}% indexed. SO many more out there!",
	"Barely scratched the surface! {FOUND} found, {TOTAL} to go!",
	"Every hatch reveals something new. {PERCENT}% and climbing!",
	"Just getting warmed up — {FOUND} pets in the book so far!",
}

MicrocopyConfig.CollectionMid = {
	"{PERCENT}% collected! You're building a real menagerie!",
	"Halfway hustle! {FOUND}/{TOTAL} — the rares are calling!",
	"Over {PERCENT}%! The index is filling up FAST!",
	"You've found {FOUND} species — the rare ones are getting closer!",
	"Solid progress! {PERCENT}% indexed. The hunt continues!",
}

MicrocopyConfig.CollectionLate = {
	"{PERCENT}% indexed! The legendary gaps are ALL that's left!",
	"So close to completing the index! {FOUND}/{TOTAL} found!",
	"Only the rarest remain! {PERCENT}% — you can FEEL completion!",
	"The final stretch! {FOUND} found, just a handful left!",
	"Near-completionist! {PERCENT}% — can you find them ALL?",
}

MicrocopyConfig.CollectionFinal = {
	"ONE MORE and you're a COMPLETIONIST! {FOUND}/{TOTAL}!",
	"SO close to 100%! The last pet is out there. FIND IT!",
	"The final hunt! {PERCENT}% — that last slot is TAUNTING you!",
	"Almost... THERE! {FOUND}/{TOTAL} — the index demands completion!",
}

MicrocopyConfig.CollectionComplete = {
	"100%! EVERY PET DISCOVERED! You are the PET MASTER!",
	"Complete index! {TOTAL}/{TOTAL} — there's nothing left to find!",
	"ALL SPECIES CATALOGUED! The rarest achievement in the game!",
	"Pet Index: COMPLETE. Fewer than 0.1% of players do this!",
}

-- Placeholders: {PET}, {RARITY}, {REMAINING}, {PERCENT} (same family as payout / social feed tokens).
MicrocopyConfig.CollectionNewDiscovery = {
	"NEW SPECIES! {PET} ({RARITY}) added to your index!",
	"Discovery! {PET} — {RARITY} — catalogued. {REMAINING} more to find!",
	"Never seen before! {PET} is yours — {RARITY} line secured!",
	"Index updated! {PET} ({RARITY}) — you're {PERCENT}% complete!",
	"Fresh find! {PET} registered — {RARITY} slot filled. Keep hatching!",
	"{RARITY} pickup: {PET} logged! {REMAINING} species left on the hunt!",
}

--------------------------------------------------------------------------
-- STREAK FOMO
-- Loss-aversion copy that makes players fear breaking their streak.
-- Server (DailyRewardService): one claim per UTC calendar day; streak resets if gapDays >= 2 UTC epoch days
-- since last claim — not a rolling 24h/48h wall-clock timer (see DailyRewardConfig).
-- {STREAK} = current streak day (1–7) or next tier index where noted.
--------------------------------------------------------------------------

MicrocopyConfig.StreakFOMOWarning = {
	"{STREAK}-day streak on the line — claim on the next UTC day you can!",
	"Let two UTC days pass between claims and your {STREAK}-day streak resets. Don't risk it!",
	"Streak x{STREAK} — miss daily claim days and you restart from Day 1!",
	"{STREAK} days built. Long gaps between claim days wipe the ladder!",
	"That {STREAK}-day streak took WORK. Don't throw it away!",
	"Your streak is a TROPHY. {STREAK} days — protect it!",
}

MicrocopyConfig.StreakFOMOTomorrow = {
	"Next claim: Day {STREAK} — after the next UTC midnight when you're eligible!",
	"Day {STREAK} loads next — stay inside the streak window!",
	"Stack the ladder — Day {STREAK} on your next timely claim!",
	"Bigger loot ahead — Day {STREAK} when you claim in time!",
	"Multiplier climbing — next stop: Day {STREAK}!",
}

MicrocopyConfig.StreakFOMOLost = {
	"Streak BROKEN! You were at {STREAK} days... time to rebuild!",
	"Ouch — {STREAK}-day streak GONE. Start fresh and go HARDER!",
	"The streak fell! But every champion has a comeback arc!",
	"Day 1 again. Your old {STREAK}-day record is waiting to be CRUSHED!",
	"Streak reset! The road to a new record starts NOW!",
}

-- Fallback when FirstTimeConfig has no ceremony line (DailyRewardPanel celebration). Weekly ladder is 1–7 with wrap.
MicrocopyConfig.StreakFOMOMilestone = {
	"MILESTONE CLAIM — weekly streak rewards spike on this day!",
	"Mid-week heat — streak bonuses are stacking!",
	"Weekly ladder pop-off — this tier hits harder!",
	"Streak milestone — keep the 7-day line rolling!",
	"Big week energy — you're climbing the weekly reward ladder!",
}

--------------------------------------------------------------------------
-- STREAK TIMED NUDGE WARNINGS
-- Push-notification copy triggered at countdown thresholds
-- (DailyStreakLossAversionDesignSpec Section C). {STREAK} = streak count.
--------------------------------------------------------------------------

-- 6-hour warning: gentle nudge, warm urgency
MicrocopyConfig.StreakWarning6h = {
	"Your streak is fading! Come back before it's too late!",
	"Don't let {STREAK} days of grinding go to WASTE!",
	"Your {STREAK}-day streak needs you — clock's ticking!",
	"The fire is cooling down! Keep your streak ALIVE!",
	"Only hours left! Protect your {STREAK}-day streak!",
}

-- 2-hour warning: high urgency, pressure rising
MicrocopyConfig.StreakWarning2h = {
	"ONLY 2 HOURS LEFT! Don't lose your {STREAK}-day streak!",
	"Your {STREAK}-day streak is FADING FAST! Claim NOW!",
	"TWO HOURS! {STREAK} days of progress on the LINE!",
	"STREAK EMERGENCY! Get back before it's too late!",
	"The clock is almost out! Save your {STREAK}-day run!",
}

-- 30-minute warning: full panic, last chance
MicrocopyConfig.StreakWarning30m = {
	"30 MINUTES! Your streak is about to VANISH!",
	"FINAL WARNING — {STREAK} days GONE in minutes!",
	"30 minutes left — claim soon to keep your {STREAK}-day streak!",
	"LAST CHANCE! {STREAK} days — DON'T let them burn!",
	"Urgent: claim before the window closes and your streak resets!",
}

-- Streak lost: loss aversion aftermath, push to rebuild
MicrocopyConfig.StreakLost = {
	"Your {STREAK}-day streak is gone... Start rebuilding NOW!",
	"The flame went out. {STREAK} days — GONE. Come back STRONGER.",
	"Streak reset — fresh start energy. Every legend has a comeback arc!",
	"Day 1 again. Your old {STREAK}-day record is waiting for a new best!",
}

--------------------------------------------------------------------------
-- EGG PITY / STREAK TRANSPARENCY
-- Server hatch is weighted random per EggConfig (EggService) — no pity modifier on rolls yet.
-- Reserve these for UI that shows streak/tier *mood* or wire only if pity parity ships.
-- {HATCHES} = consecutive commons/uncommons below rare, {TIER} = display tier (1-3),
-- {RARITY} = guaranteed rarity name, {GLOW} = glow description.
-- Tier voice: T1 = quiet lift, T2 = momentum, T3 = peak tension — avoid implying fake % odds.
--------------------------------------------------------------------------

MicrocopyConfig.PityStatus = {
	"Streak tracker: {HATCHES} since your last Rare+. Each hatch is its own roll (server: no pity RNG yet).",
	"{HATCHES} rolls deep — commons happen. Keep hatching; rares can pop anytime.",
	"Fair-run counter: {HATCHES} — mood meter only until a server pity system ships.",
	"{HATCHES} since last Rare+ — stay in; EggService rolls are independent each time.",
}

MicrocopyConfig.PityTier1 = {
	"First nudge: early streak — keep rolling; Rare+ can surprise anytime.",
	"Soft glow — the hype rail is warming up. Hatch again when you're ready.",
	"Tier 1 vibe: early tension — no extra odds yet; EggService is still fair dice.",
	"Shimmer online: flavor only until pity parity ships server-side.",
	"Early stretch: the egg's telling you the run is listening (mood, not math).",
}

MicrocopyConfig.PityTier2 = {
	"Tier 2: Momentum's building — feels like Rare+ is riding closer (still fair rolls).",
	"Gold-tint momentum — pure theater until server pity lands.",
	"Mid-stack vibe: keep hatching; the table hasn't tilted yet.",
	"Big-step energy — drama, not a second RNG layer.",
	"Glow intensifies — you're in the serious part of the climb (mood only).",
}

MicrocopyConfig.PityTier3 = {
	"Tier 3: Spotlight window — if you're saving hatches, this is the hype minute!",
	"Max rail: peak tension — still no server-side pity; roll when it feels right.",
	"Rainbow pressure — if Rare+ was ever due, it's now (emotionally, not statistically).",
	"Top vibe: sparkles are flair — check EggConfig odds for real weights.",
	"Final tier: push the hatch — you've earned the spotlight window.",
	"Ceiling hype — Rare+ is never guaranteed; this is max drama, not max odds.",
}

MicrocopyConfig.PityReset = {
	"Rare+ landed! Fresh climb begins — server still uses fair rolls each hatch.",
	"Rare+ landed! Counter clears — fresh climb begins (when pity UI is wired).",
	"That's the drop we were hoping for — no meter to reset on server yet.",
	"Hot hatch delivered — run it again; EggService rolls stay independent.",
}

MicrocopyConfig.PityExplainer = {
	"Each egg uses published drop weights — passes can tilt rare slots; hatches are fair rolls.",
	"Tiers describe streak *mood* (soft → big push → peak), not a second hidden RNG.",
	"Check the shop for odds labels on the egg you're opening.",
	"Streak tracking is transparency — not a guarantee. Have fun cracking!",
}

--------------------------------------------------------------------------
-- FAILURE FEEDBACK
-- Motivational copy for denied actions. Turn frustration into fuel.
--
-- Canonical surfaces (POLA-556): pick ONE pool per failure class so players see consistent tone.
-- | Class | Pool | Typical wiring |
-- | Remote/Invoke failure toast | RemoteLoadError | RemoteFailSafe.notifyRemoteFailure |
-- | Long wait / timeout | SoftFailRemoteTimeout | timeout branches on InvokeServer |
-- | Purchase dismissed | SoftFailPurchaseCancelled | Marketplace prompt finished false |
-- | Inventory cap | SoftFailInventoryFull | hatch / grant with full bag |
-- | Button cooldown | SoftFailCooldownActive | RemoteCooldown / action gates |
-- | Soft can't afford | SoftFailCurrencyShort | panel hints before hard deny |
-- | Car/shop coin gate | PurchaseFail | priced unlocks |
-- | Egg gem gate | EggFail | egg purchase |
-- | Odd state / retry | SoftFailGenericRetry | client/server mismatch |
-- Code redemption: CodeService sends fixed English substrings; CodesPanel maps substring → pool.
-- If you change a server message, update CodesPanel guards to match.
--------------------------------------------------------------------------

MicrocopyConfig.PurchaseFail = {
	"You're a little short on coins — one more lap usually covers it!",
	"So close! That ride's still in the lot — save up and swing back!",
	"Just a few coins away — the road keeps paying patient drivers!",
	"Not enough coins yet — most players clear this on the next run!",
	"Save up a touch more — nothing's leaving without you!",
	"Almost there! A couple more laps and that unlock is yours!",
	"Coins are almost there — queue another run and close the gap!",
}

MicrocopyConfig.EquipLocked = {
	"Locked for now — one more rebirth opens this tier!",
	"This one's for higher rebirths — keep climbing!",
	"Rebirth again and this ride is yours!",
	"Not yet unlocked — your next rebirth opens new gear!",
	"Still gated — rebirth once more and this slot lights up!",
}

MicrocopyConfig.EggFail = {
	"Need a bit more currency for this egg — keep driving!",
	"Not enough yet — keep driving; it adds up quietly!",
	"This egg's a stretch right now — save up, then hatch!",
	"Almost there — regular drives still pay out!",
	"One more milestone should cover it — you're closer than it feels!",
	"A bit more and this egg is yours — keep cruising!",
	"So close! Dailies and drives add up fast!",
	"Patience pays — save up, then crack it open!",
}

MicrocopyConfig.FuelEmpty = {
	"Out of gas — refuel to keep your streak alive!",
	"Tank's dry — quick pit stop, then you're back in the race!",
	"No fuel, no payout stretch — fill up and roll again!",
	"Empty tank — your next refuel is just a tap away!",
	"Running on fumes — refuel and pick up where you left off!",
}

MicrocopyConfig.QuestFail = {
	"Almost had it — want one more try?",
	"So close! One more attempt usually does it!",
	"Not quite — but you're closer than it felt!",
	"Rough beat — that happens. The quest will wait!",
	"Retry's free — go again when you're ready!",
	"Off by a hair — run it back; nothing's lost!",
}

-- Client: fail-soft remote load (InvokeServer / panel refresh). Shown as HUD toast via UIController.
MicrocopyConfig.RemoteLoadError = {
	"Couldn't sync that — give it another sec!",
	"Connection hiccup — tap again when you're ready!",
	"That didn't load right — try reopening the menu!",
	"We couldn't reach the server just now — one more try?",
	"That didn't load — wait a beat and try again!",
}

-- Surface: LeaderboardPanel.luau (world mesh SurfaceGui) — inline status strip when GetLeaderboard fails.
-- Phase 4: calm, recoverable; see docs/PlayerFacingErrorCopy.md / ErrorMicrocopy_Phase4.md.
MicrocopyConfig.LeaderboardLoadError = {
	"Couldn't sync leaderboard — try again in a sec.",
	"Leaderboard didn't sync — try again in a moment.",
}

-- Rate limited with no local snapshot — player must manual refresh.
MicrocopyConfig.LeaderboardRateLimitNoCache = {
	"Leaderboard's cooling down — tap Refresh.",
	"Could not sync — tap Refresh.",
}

--------------------------------------------------------------------------
-- PHASE 4 — SOFT-FAIL TOASTS (POLA-354) — Pair with failure toast wiring (POLA-353).
-- On-brand, calm, never blame the player. ~90 chars max; {ACTION} / {ITEM} where noted.
-- Not for first-session nudges (POLA-352) — avoid duplicating FirstSession* / tutorial lines.
--------------------------------------------------------------------------

-- Remote InvokeServer / HTTP-style wait exceeded; distinct from RemoteLoadError (generic sync miss).
MicrocopyConfig.SoftFailRemoteTimeout = {
	"That took a little long — tap {ACTION} again when you're ready!",
	"Request timed out — no stress, the road's still here. Retry in a sec!",
	"Server didn't answer in time — give {ACTION} another try!",
	"Connection paused too long — one quick retry usually fixes it!",
	"We didn't get an answer in time. Tap again — nothing was lost.",
}

-- Player dismissed Roblox purchase prompt or flow ended without charge.
MicrocopyConfig.SoftFailPurchaseCancelled = {
	"Purchase cancelled — nothing charged. You're still in the clear!",
	"You closed checkout — all good, shop again whenever you want!",
	"No worries — that buy didn't go through. Your balance is untouched!",
	"Window closed before purchase — zero spent, zero stress!",
	"Cancelled at checkout — your balance stayed right where it is!",
}

-- Pet/inventory slot cap; engineer injects {ITEM} when relevant (e.g. egg name) or a generic noun.
MicrocopyConfig.SoftFailInventoryFull = {
	"Inventory's full — make room, then {ITEM} can come home!",
	"No empty slot for {ITEM} yet — free a space or expand, then retry!",
	"Your roster's packed — clear a slot so {ITEM} has somewhere to land!",
	"Can't stash {ITEM} right now — the garage needs a free hook first!",
	"Every slot's taken — swap something out, then grab {ITEM} again!",
}

-- Action-specific cooldown (button spam, hatch, trade, etc.); {ACTION} = short verb phrase.
MicrocopyConfig.SoftFailCooldownActive = {
	"{ACTION} is still cooling down — almost ready, hang tight!",
	"Easy there — {ACTION} needs a moment before it's ready again!",
	"Cooldown's active on {ACTION}. Let the timer finish, then go!",
	"{ACTION} is recharging — give it a sec, then you're clear!",
	"That {ACTION} needs a breather — try again when the ring clears!",
}

-- Soft affordability miss; gentler than PurchaseFail / EggFail (shop panels).
MicrocopyConfig.SoftFailCurrencyShort = {
	"A touch short for that — a quick run or claim should cover the gap!",
	"Almost there — stack a few more coins, then this unlocks easy!",
	"Not quite enough yet — the grind's almost paid for it, promise!",
	"Balance needs one more bump — farm a lap, then you're golden!",
	"You're close — a little more currency and this one's yours!",
}

-- Generic recoverable client/server mismatch; use when no specific bucket fits.
MicrocopyConfig.SoftFailGenericRetry = {
	"Tiny hiccup — nothing lost. Tap again and it should snap back!",
	"Something wobbled — give it another try, you're still good!",
	"That didn't stick — one more go usually clears it up!",
	"Quick glitch — no progress lost. Retry when you feel like it!",
	"Brief bump in the road — try again; the lobby's still with you!",
}

--------------------------------------------------------------------------
-- FIRST PLAY SESSION (POLA-291) — Phase 4 hook: *Every run pays off.*
-- At most one tagline per first session (server: FirstSessionOnboardingService).
--------------------------------------------------------------------------

MicrocopyConfig.FirstSessionTagline = "Every run pays off."

-- Session-start toast (Bootstrap). No tagline here — payout / hatch / trophy / daily compete for the single hook.
-- Platform-neutral: first run begins by entering the track Start zone (not a lobby Drive button).
MicrocopyConfig.FirstSessionWelcomeToast = "First run pays real coins — press Drive when you're ready!"

MicrocopyConfig.FirstSessionPayoutBrag = {
	"First payout on the board! The road keeps paying.",
	"You banked the run — that's how the loop starts!",
	"Coins deposited! This is your first of many paydays.",
}

MicrocopyConfig.FirstSessionHatchCopy = {
	"First hatch! Your pet is already boosting your next run.",
	"New pet unlocked — stack bonuses every time you drive!",
}

MicrocopyConfig.FirstSessionEmptyTrophy = {
	"Case is empty for now — drive, hatch, and climb to fill it with trophies!",
	"Achievements unlock as you play — your first trophies are a few runs away!",
}

MicrocopyConfig.FirstSessionDailyStreak = {
	"Daily streaks stack rewards — claim on a fresh UTC day whenever you can to climb!",
	"Let two UTC days pass between claims and your streak resets — keep the rhythm!",
}

--------------------------------------------------------------------------
-- PHASE 4 — FIRST SESSION / RETURNING PLAYER HINTS (POLA-352)
-- One-line HUD / notification-lane strings. Engineer wires gates (flags, timers).
-- Cross-ref: LoadingTipsConfig.luau (POLA-336 loading screen) — avoid duplicating those lines verbatim.
--------------------------------------------------------------------------

-- When: player has not hatched yet this account, first ~10 min playtime; max 1× until first hatch (or soft daily cap).
-- Surface: HUD hint toast / NotificationLane — not the loading tip carousel.
MicrocopyConfig.FirstSessionHatchNudge = {
	"Pets = multipliers — open Eggs and Hatch as soon as you have one!",
	"First hatch flips on pet bonuses for every run. Crack it when you can!",
	"Shop egg → Hatch — that's how your payout multiplier turns on!",
}

-- When: player owns ≥1 pet but none equipped (inventory check), first session or until first equip.
-- Surface: HUD toast after run or when opening Garage/Pets.
MicrocopyConfig.FirstSessionPetEquipNudge = {
	"Pets only boost runs when equipped — open Pets and pick one!",
	"Unequipped pets = wasted bonus. One equip, instant multiplier!",
	"Garage → Pets → Equip — your Pet Modifier only counts when worn!",
}

-- When: second world unlocked OR first time World panel shows 2+ destinations (milestone flag).
-- Surface: HUD toast or world button pulse copy — not loading tips.
MicrocopyConfig.FirstSessionWorldSwitchNudge = {
	"New map, new coin tier — hop worlds when you want bigger grinds!",
	"Higher worlds = bigger multipliers — pick the track for your goal!",
	"Worlds unlock in order with each world's currency — check the World panel!",
}

-- When: rebirth is available (threshold met) but player has not rebirthed; soft nudge, max 1× per session early window.
-- Tone: softer than RebirthTeaser (panel) — trust first, no urgency spam. Not a substitute for RebirthPanel rotation.
MicrocopyConfig.FirstSessionRebirthTeaserSoft = {
	"Rebirth trades a coin reset for permanent speed — it's the long-game unlock.",
	"When progress feels flat, rebirth is the gear shift that lifts every future run.",
	"Future you wants the permanent boosts — rebirth when the moment feels right!",
}

--------------------------------------------------------------------------
-- DRIVING HUD — STEER HINT (POLA-398 / POLA-381)
-- One line under DrivingUI; swaps by active input (keyboard vs touch vs gamepad).
--------------------------------------------------------------------------

-- Per-input one-liners (DrivingHUD SteerHint). Lane snap = VehicleReset / R / Y per device.
-- Mobile/narrow HUD: keep each line ≤ ~40 chars where possible (POLA-729); still one logical line.
MicrocopyConfig.DrivingHudSteerHintKeyboard = "Steer: A/D or arrows · R×2: center"
MicrocopyConfig.DrivingHudSteerHintTouch = "Drag to steer · RESET×2: center"
MicrocopyConfig.DrivingHudSteerHintGamepad = "Stick: steer · Y×2: center"
-- POLA-438: speed-at-cap proxy (no tach/RPM); brief flash near max speed
MicrocopyConfig.DrivingHudShiftUpFlash = "SHIFT UP!"
-- POLA-436: ignition flash line (~300–600ms) after engine SFX; keep punchy, all-caps energy.
MicrocopyConfig.DrivingHudEngineIgnitionFlash = "ENGINE ON"
-- Travel frame (DrivingHUD): {MILES} = one decimal string (e.g. "12.4"); {LAPS} = integer string.
MicrocopyConfig.DrivingHudTravelMilesLine = "{MILES} mi driven"
MicrocopyConfig.DrivingHudLapsDrivenLine = "{LAPS} laps"
-- Vehicle reset two-tap micro-labels on the compact reset chip (DrivingHUD VehicleReset.Status).
MicrocopyConfig.VehicleResetMicroStatusAgain = "AGAIN!"
MicrocopyConfig.VehicleResetMicroStatusWait = "WAIT"
-- POLA-468: lane snap / unstick (two-step confirm + cooldown; server-authoritative timer)
MicrocopyConfig.VehicleResetConfirmLine = "LINE UP: tap RESET or R again!"
MicrocopyConfig.VehicleResetSuccess = "LANE SNAPPED — you're back on track!"
MicrocopyConfig.VehicleResetCooldown = "WAIT {SEC}s — reset is cooling down."
MicrocopyConfig.VehicleResetNotInRun = "Can't reset — you're not in a run."
MicrocopyConfig.VehicleResetGenericFail = "Can't reset right now. Try again in a moment."

--------------------------------------------------------------------------
-- PHASE 4 — SOFT RETENTION NUDGES (POLA-359)
-- Light-touch copy for natural session breaks and tomorrow return.
-- Complements daily streak work; does NOT duplicate POLA-352 first-session hints or
-- StreakFOMOWarning / StreakWarning* (those stay high-urgency). Premium, no guilt-tripping.
--------------------------------------------------------------------------

-- Surface: HUD toast (info priority) — natural session wrap after last run of visit, payout dismissed,
-- or quiet "stepping away" moment. Engineer may time-gate (e.g. 2+ runs, no AFK modal).
-- NOT RetentionIdleHeader (that's AFK interrupt) — this is calm closure, non-alarming.
MicrocopyConfig.RetentionSoftSessionWrap = {
	"Solid run — everything you earned is banked. The road'll be here.",
	"Nice finish — progress saved. Hop back in whenever the vibe hits.",
	"That's a clean stop. Your garage and streak pick up right where you left off.",
	"Good session — coins are safe, pets are fed. See you on the next lap.",
	"You set the pace today. Rest up; the highway isn't going anywhere.",
	"Wrapping up? All good — your run history and rewards stay put.",
}

-- Surface: HUD toast or thin notification lane — "tomorrow" invite without DailyRewardPanel CTA copy.
-- Distinct from StreakFOMOTomorrow (reward hype) and FirstSessionDailyStreak (onboarding).
-- Optional: menu banner subtitle if MenuHub shows a one-line retention strip (engineer).
MicrocopyConfig.RetentionReturnTomorrow = {
	"Tomorrow's claim is a fresh stack — drop in when your day opens up.",
	"Next calendar day brings new streak juice — no rush, just don't sleep on the fun.",
	"See you tomorrow? The lobby keeps your lane warm.",
	"A quick visit tomorrow keeps rewards rolling — fit it around your schedule.",
	"Future you gets another multiplier bump tomorrow — swing by when you can.",
	"The streak likes consistency — tomorrow's window is yours to claim.",
}

-- Surface: HUD toast (info; below urgent streak warnings) — soft streak-at-risk reminder.
-- NOT StreakFOMOWarning / StreakWarning6h (panic) — gentle heads-up before daily reset pressure.
-- NOT DailyRewardPanel body — optional pairing with streak state from server. {STREAK} = current streak day.
MicrocopyConfig.RetentionStreakSoftReminder = {
	"Day {STREAK} streak is active — claim when the next window fits you.",
	"Your {STREAK}-day streak is still glowing — a short visit keeps it effortless.",
	"Streak x{STREAK}: your next claim in time keeps the line unbroken.",
	"No pressure — just a nudge: your streak likes a quick check-in before UTC days slip by!",
	"{STREAK} days deep — one calm timely claim and the streak stays elite.",
	"The streak's counting on you, not chasing you — grab the next claim when you're free.",
}

-- Tutorial (TutorialService) — strings aligned with FirstSessionOnboardingCopyPack / Phase 4 tone.
MicrocopyConfig.FirstSessionTutorialStep1Title = "Welcome, driver!"
MicrocopyConfig.FirstSessionTutorialStep1Body =
	"Drive → coins → Store → Eggs → Pets. Drive into the Start zone on the track to begin your first run!"

MicrocopyConfig.FirstSessionTutorialStep2Title = "Bank your first payout"
MicrocopyConfig.FirstSessionTutorialStep2Body =
	"Stay on the gas until the tank hits empty — that banks your coins. Faster runs, bigger payouts!"

MicrocopyConfig.FirstSessionTutorialStep3Title = "Spend coins, feel faster"
MicrocopyConfig.FirstSessionTutorialStep3Body =
	"Menu → Store → buy Speed. Each level makes the next run pay more!"

MicrocopyConfig.FirstSessionTutorialStep4Title = "Hatch your first pet"
MicrocopyConfig.FirstSessionTutorialStep4Body =
	"Open Eggs — grab a Meadow Egg if you need one — then Hatch. Pets boost every run; grow your team!"

MicrocopyConfig.FirstSessionTutorialStep5Title = "Equip for bonus coins"
MicrocopyConfig.FirstSessionTutorialStep5Body =
	"Garage → Pets → Equip. More pets equipped = a bigger Pet Modifier every run!"

-- Surface: TutorialOverlay skip confirmation (`DACTutorialOverlay.SkipConfirm`) — reward-forward warning before `TutorialSkip`.
MicrocopyConfig.TutorialSkipConfirmTitle = "Skip the driver tips?"
MicrocopyConfig.TutorialSkipConfirmBody =
	"You'll miss quick wins: bigger payouts, pet bonuses, and hatch juice. Skip the tips anyway?"

-- Optional `optionalAppend` extends the pick space (e.g. Phase 4 optional pool lines) without copying tables.
function MicrocopyConfig.pickVariant(list: { string }, optionalAppend: { string }?): string
	local extra = optionalAppend
	local nMain = #list
	local nExtra = if extra then #extra else 0
	if nMain == 0 and nExtra == 0 then
		return ""
	end
	if nExtra > 0 then
		local idx = math.random(1, nMain + nExtra)
		if idx <= nMain then
			return list[idx]
		end
		return (extra :: { string })[idx - nMain]
	end
	return list[math.random(1, nMain)]
end

return MicrocopyConfig
