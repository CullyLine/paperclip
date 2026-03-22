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
	"Hmm, that code didn't work. Double-check those letters!",
	"Invalid code — but don't give up, new ones drop all the time!",
	"Nope! That's not it. Try again, speedster!",
	"Code not recognized. Maybe it's case-sensitive?",
}

-- Surface: CodesPanel.luau → expired-code feedback label below the code input field.
-- Show when a code exists but its expiry timestamp has passed.
-- Display as amber/yellow text; append a follow-us CTA nudge to drive social follows.
MicrocopyConfig.CodeRedeemExpired = {
	"That code expired! They go fast — follow us for the next one!",
	"Too late! This one's gone. Stay tuned for fresh codes!",
	"Expired code! The early bird gets the loot. Watch socials!",
}

--------------------------------------------------------------------------
-- CURRENCY GAIN CELEBRATIONS
--------------------------------------------------------------------------

MicrocopyConfig.CoinGainSmall = {
	"+{AMOUNT} coins",
	"{AMOUNT} coins earned",
	"+{AMOUNT}",
}

MicrocopyConfig.CoinGainMedium = {
	"Nice haul! +{AMOUNT} coins!",
	"Cha-ching! {AMOUNT} coins!",
	"Stacking up! +{AMOUNT}!",
	"Money moves! +{AMOUNT} coins!",
	"Keep it rolling! +{AMOUNT}!",
}

MicrocopyConfig.CoinGainLarge = {
	"MASSIVE PAYDAY! +{AMOUNT} COINS!",
	"YOU'RE RICH! {AMOUNT} coins just dropped!",
	"JACKPOT! +{AMOUNT} coins! What a run!",
	"INSANE PAYOUT! {AMOUNT} coins in one go!",
	"MONEY TSUNAMI! +{AMOUNT}! Who even ARE you?!",
	"LEGENDARY HAUL! {AMOUNT} coins! The vault is overflowing!",
}

MicrocopyConfig.GemGain = {
	"Precious! +{AMOUNT} gems!",
	"Gem bonanza! +{AMOUNT}!",
	"SPARKLE! {AMOUNT} gems acquired!",
	"Rare loot! +{AMOUNT} gems incoming!",
	"Shiny! +{AMOUNT} gems just for you!",
	"GEM RUSH! +{AMOUNT}! You're glowing!",
}

--------------------------------------------------------------------------
-- PREMIUM / VIP
--------------------------------------------------------------------------

MicrocopyConfig.PremiumWelcome = {
	"Welcome back, VIP! Double coins are ACTIVE. Let's dominate.",
	"The elite driver returns! All premium perks are live. Floor it!",
	"VIP status: CONFIRMED. You're playing on a whole different level.",
}

MicrocopyConfig.VIPNametagFlavor = {
	"★ VIP DRIVER ★",
	"⚡ ELITE MEMBER ⚡",
}

MicrocopyConfig.PremiumLoadingTips = {
	"VIP perk: You earn 2x coins on EVERY run. Others wish they were you!",
	"VIP perk: Exclusive cars, exclusive flex. Check the VIP garage!",
	"VIP perk: Priority egg hatching — your pets arrive faster than anyone's!",
}

--------------------------------------------------------------------------
-- PLAYTIME MILESTONES
--------------------------------------------------------------------------

MicrocopyConfig.PlaytimeGemReward = {
	"You've been grinding! Here's {AMOUNT} gems for your dedication!",
	"{MINUTES} minutes of pure driving. You EARNED these {AMOUNT} gems!",
	"Time flies when you're fast! +{AMOUNT} gems for sticking around!",
	"Dedicated driver bonus! {AMOUNT} gems — keep that engine running!",
	"Play longer, earn more! {AMOUNT} gems rewarded for your commitment!",
}

-- Surface: HUD.luau or Bootstrap.local.luau → session welcome toast system.
-- Show as an alternative to SessionWelcome when the player has an active multi-day
-- play streak. Pick randomly from this pool and inject {STREAK} count.
-- Display via the same toast frame used by SessionWelcome, amber/gold accent color.
MicrocopyConfig.PlayStreak = {
	"Day {STREAK} streak! You're on FIRE! 🔥",
	"{STREAK}-day streak! Consistency is king — bonus incoming!",
	"STREAK x{STREAK}! Miss a day and it resets. No pressure...",
	"{STREAK} days straight! The grind never stops!",
	"Day {STREAK}! At this point you basically live here. Respect.",
	"Unstoppable! {STREAK}-day streak locked in!",
}

--------------------------------------------------------------------------
-- EVENT BANNERS
--------------------------------------------------------------------------

MicrocopyConfig.EventBannerHeadlines = {
	"LAUNCH EVENT: 3x Coins + Exclusive Egg — GO GO GO!",
	"THE BIG ONE IS HERE: Limited cars, massive rewards, zero chill!",
	"EVENT LIVE: Hatch the Launch Mythical before it's GONE!",
	"DRIVE HARDER: Event multipliers are STACKED right now!",
	"GRAND OPENING: New world, new rides, new records to SMASH!",
}

MicrocopyConfig.EventCountdown = {
	"⏳ LAST HOUR! Event rewards vanish soon — claim them NOW!",
	"⚠️ ALMOST OVER! Minutes left to grab event exclusives!",
	"🚨 FINAL COUNTDOWN! If you don't have it yet, RUN!",
}

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
}

MicrocopyConfig.SessionWelcomeStreak = {
	"Day {STREAK} of domination! Keep it going!",
	"{STREAK}-day streak? You're UNSTOPPABLE!",
	"Streak x{STREAK}! The grind doesn't rest and neither do YOU!",
	"Day {STREAK}! At this point the game should pay YOU rent.",
	"{STREAK} days LOCKED IN. Rewards are stacking!",
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
}

--------------------------------------------------------------------------
-- PAYOUT FLEX
-- Contextual brag lines shown on the run-end payout screen.
-- Placeholders: {COINS}, {DISTANCE}, {LAPS}, {MULTIPLIER}, {RANK}
--------------------------------------------------------------------------

MicrocopyConfig.PayoutFlexBig = {
	"That run just PRINTED! {COINS} coins in one go!",
	"Built DIFFERENT. {DISTANCE}m and counting!",
	"You just out-earned 99% of the lobby. Casually.",
	"{LAPS} laps? That's not driving — that's a STATEMENT.",
	"The bank called. They need a bigger vault. +{COINS}!",
	"Your wallet just flinched. {COINS} coins incoming!",
	"Multipliers STACKED: x{MULTIPLIER}. That payout is OBSCENE.",
	"Ranks #{RANK}+ WISH they had this run. You just did THAT.",
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
	"Founders + Pets + Premium = x{MULTIPLIER}. Other players weep.",
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

MicrocopyConfig.CollectionNewDiscovery = {
	"NEW SPECIES! {PET} added to your index!",
	"Discovery! {PET} catalogued — {REMAINING} more to find!",
	"Never seen before! {PET} is now in your collection!",
	"Index updated! {PET} discovered — you're {PERCENT}% complete!",
	"Fresh find! {PET} registered — keep hatching!",
}

--------------------------------------------------------------------------
-- STREAK FOMO
-- Loss-aversion copy that makes players fear breaking their streak.
-- {STREAK} = current streak count, {REWARD} = next day's reward preview.
--------------------------------------------------------------------------

MicrocopyConfig.StreakFOMOWarning = {
	"Your {STREAK}-day streak is ON THE LINE! Come back tomorrow!",
	"Miss tomorrow and {STREAK} days of progress VANISH. Don't risk it!",
	"Streak x{STREAK} — lose it and you start from DAY ONE. Ouch.",
	"{STREAK} days built. ONE missed day destroys it ALL!",
	"That {STREAK}-day streak took WORK. Don't throw it away!",
	"Your streak is a TROPHY. {STREAK} days — protect it!",
}

MicrocopyConfig.StreakFOMOTomorrow = {
	"Come back tomorrow for Day {STREAK} rewards! Don't break the chain!",
	"Tomorrow's reward is waiting — Day {STREAK} unlocks something GOOD!",
	"Day {STREAK} is TOMORROW. The longer the streak, the BIGGER the loot!",
	"See you tomorrow? Day {STREAK} rewards won't claim themselves!",
	"Your streak multiplier keeps GROWING — Day {STREAK} tomorrow!",
}

MicrocopyConfig.StreakFOMOLost = {
	"Streak BROKEN! You were at {STREAK} days... time to rebuild!",
	"Ouch — {STREAK}-day streak GONE. Start fresh and go HARDER!",
	"The streak fell! But every champion has a comeback arc!",
	"Day 1 again. Your old {STREAK}-day record is waiting to be CRUSHED!",
	"Streak reset! The road to a new record starts NOW!",
}

MicrocopyConfig.StreakFOMOMilestone = {
	"7-DAY STREAK! A full week of grinding — BONUS UNLOCKED!",
	"14-DAY STREAK! Two weeks of dedication! Respect earned!",
	"30-DAY STREAK! A FULL MONTH! You're a MACHINE!",
	"50-DAY STREAK! Half a hundred days! Hall of Fame territory!",
	"100-DAY STREAK! CENTURION! Less than 1% reach this!",
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
	"YOUR STREAK DIES IN 30 MINUTES! MOVE!",
	"LAST CHANCE! {STREAK} days — DON'T let them burn!",
	"This is NOT a drill! Your streak is ALMOST DEAD!",
}

-- Streak lost: loss aversion aftermath, push to rebuild
MicrocopyConfig.StreakLost = {
	"Your {STREAK}-day streak is gone... Start rebuilding NOW!",
	"The flame went out. {STREAK} days — GONE. Come back STRONGER.",
	"Streak DESTROYED. But every legend has a comeback arc!",
	"Day 1 again. Your old {STREAK}-day record is BEGGING to be crushed.",
}

--------------------------------------------------------------------------
-- EGG PITY TRANSPARENCY
-- Honest pity-counter messaging so players feel the system is fair.
-- {HATCHES} = consecutive commons, {TIER} = pity tier (1-3),
-- {RARITY} = guaranteed rarity name, {GLOW} = glow description.
--------------------------------------------------------------------------

MicrocopyConfig.PityStatus = {
	"Pity counter: {HATCHES} hatches since last rare. Odds are shifting!",
	"{HATCHES} commons in a row — the pity system is working FOR you!",
	"Bad luck protection active! {HATCHES} hatches tracked. Keep going!",
	"Your pity counter is at {HATCHES}. Better drops are getting closer!",
}

MicrocopyConfig.PityTier1 = {
	"Pity building! Your rare chance just INCREASED.",
	"The glow means your odds are climbing. Keep hatching!",
	"Notice the shimmer? Your rare odds are above normal now!",
	"Bad luck? Not for long — pity boost ACTIVE! (Tier 1)",
	"Your egg is starting to glow — better drops are on the way!",
}

MicrocopyConfig.PityTier2 = {
	"Pity is STACKING! Rare+ odds significantly boosted!",
	"That golden glow? Your odds are WAY above normal now!",
	"The pity system has your back — a rare is IMMINENT!",
	"Big pity boost! The next hatch could change EVERYTHING!",
	"Glow intensifying! The game OWES you a good one! (Tier 2)",
}

MicrocopyConfig.PityTier3 = {
	"MAX PITY! A rare or better is practically GUARANTEED!",
	"RAINBOW GLOW! The pity system is MAXED — hatch NOW!",
	"The egg is PULSING! Your next hatch is going to be SPECIAL!",
	"Full pity! This is the BEST time to hatch — don't waste it!",
	"Pity at MAXIMUM! The sparkles mean you're about to WIN BIG!",
	"Your odds have NEVER been better! Max pity = max luck!",
}

MicrocopyConfig.PityReset = {
	"Pity counter RESET! You earned that one!",
	"Rare pulled! Pity resets — the hunt begins again!",
	"Nice drop! Your pity counter is back to zero. Fresh start!",
	"The pity system delivered! Counter reset — go again!",
}

MicrocopyConfig.PityExplainer = {
	"Every common hatch increases your rare chance. The game has your back!",
	"Can't get a rare? Don't worry — each hatch makes the next one more likely!",
	"Bad luck protection: the longer you go without a rare, the higher your odds get!",
	"The pity system guarantees you won't go forever without a good drop!",
}

--------------------------------------------------------------------------
-- FAILURE FEEDBACK
-- Motivational copy for denied actions. Turn frustration into fuel.
--------------------------------------------------------------------------

MicrocopyConfig.PurchaseFail = {
	"Not enough coins... yet! One more run should do it!",
	"So close! Keep grinding — that ride is almost yours!",
	"Just a few coins short! The road always pays.",
	"Can't afford it NOW, but future you definitely can!",
	"Save up a little more — that car isn't going anywhere!",
	"Almost there! A couple more laps and it's yours!",
	"Your wallet says no, but your next run says YES!",
}

MicrocopyConfig.EquipLocked = {
	"Locked! Rebirth to unlock this tier.",
	"This one's for higher rebirths — keep climbing!",
	"Rebirth again and this beauty is yours!",
	"Not yet unlocked! Your next rebirth opens new doors.",
	"Patience, speed demon — rebirth to access this gear!",
}

MicrocopyConfig.EggFail = {
	"Need more gems for this egg!",
	"Not enough gems — but playtime rewards are ticking!",
	"This egg is pricey! Stack up and come back!",
	"Gem shortage! Keep driving — gems come to the dedicated!",
	"Almost enough gems! One more milestone should cover it.",
}

MicrocopyConfig.FuelEmpty = {
	"Out of gas! Refuel to keep your streak!",
	"Tank's dry! Time for a quick pit stop!",
	"No fuel, no speed! Fill up and get back out there!",
	"Empty tank! But your next refuel is just a tap away.",
	"Running on fumes! Refuel and keep the momentum going!",
}

MicrocopyConfig.QuestFail = {
	"Almost had it! Try again?",
	"So close! One more attempt and you've got this!",
	"Not quite — but you're CLOSER than you think!",
	"Failed? Nah, you just found one way it doesn't work!",
	"Retry is free and revenge is sweet. Go again!",
	"Miss! But the quest isn't going anywhere — run it back!",
}

function MicrocopyConfig.pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

return MicrocopyConfig
