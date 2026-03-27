--!strict
--[[
	FOMO badge labels, tooltip text, and urgency copy.

	Badges are collectible prestige markers displayed on the player's
	profile/nametag. Each badge has a short label (<=16 chars), a tooltip
	(<=60 chars), and rarity-tier urgency text shown when the badge is
	almost earnable or about to expire. Designed to trigger "I NEED that"
	energy.

	Categories:
	  - Permanent badges (earned via milestones)
	  - Limited-time event badges (scarcity-driven)
	  - Social proof copy (seen by other players hovering on badges)
]]

local FomoBadgeLabelConfig = {}

--------------------------------------------------------------------------
-- PERMANENT MILESTONE BADGES
-- Earned by hitting thresholds. Never expire — but still flex-worthy.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.PermanentBadges = {
	speed_50     = { label = "FIRST GEAR",        tooltip = "Hit 50 studs/s — everyone starts here!" },
	speed_100    = { label = "TRIPLE DIGITS",     tooltip = "Broke 100 studs/s. The road respects you." },
	speed_300    = { label = "VOID WALKER",       tooltip = "300 studs/s — reality is optional." },
	speed_500    = { label = "COMET",             tooltip = "500 studs/s — rarer than a Mythic pet." },
	speed_1000   = { label = "SPEED GOD",         tooltip = "1,000 studs/s. The final form." },
	rebirth_5    = { label = "VETERAN",           tooltip = "5 rebirths — proving you're committed." },
	rebirth_10   = { label = "ELITE",             tooltip = "10 rebirths — top-tier driver." },
	rebirth_25   = { label = "MASTER",            tooltip = "25 rebirths — built different." },
	rebirth_50   = { label = "DYNASTY",           tooltip = "50 rebirths — apex of the leaderboard." },
	rebirth_100  = { label = "ETERNAL",           tooltip = "100 rebirths. Nothing left to prove." },
	pets_25      = { label = "COLLECTOR",         tooltip = "25% pet index. The hunt is on!" },
	pets_50      = { label = "CURATOR",           tooltip = "50% pet index — halfway to LEGEND." },
	pets_100     = { label = "COMPLETIONIST",     tooltip = "100% pet index. Every. Single. One." },
	runs_1000    = { label = "ROAD WARRIOR",      tooltip = "1,000 runs complete. Tireless." },
	runs_10000   = { label = "ETERNAL DRIVER",    tooltip = "10,000 runs. You ARE the simulation." },
	streak_30    = { label = "MONTHLY GRINDER",   tooltip = "30-day login streak. Dedication!" },
	streak_100   = { label = "CENTURION",         tooltip = "100-day streak. Absolute machine." },
	first_mythic = { label = "MYTHIC FINDER",     tooltip = "Hatched a Mythic pet. 0.01% odds!" },
	mega_500     = { label = "MEGA",              tooltip = "500 Robux invested. Big leagues!" },
	tycoon_2500  = { label = "TYCOON",            tooltip = "2,500 Robux. Empire builder." },
}

--------------------------------------------------------------------------
-- LIMITED-TIME EVENT BADGES
-- Scarcity-driven labels. Shown with countdown or "GONE FOREVER" text.
-- {EVENT} = event name, {TIME} = remaining time string.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.EventBadgeLabels = {
	launch_driver   = { label = "LAUNCH DRIVER",   tooltip = "Played during launch week — limited-time event badge." },
	holiday_racer   = { label = "HOLIDAY RACER",   tooltip = "Drove during the Holiday Event — seasonal badge." },
	beta_tester     = { label = "OG TESTER",       tooltip = "Tested before anyone else. Respect earned." },
	event_champion  = { label = "EVENT CHAMP",     tooltip = "Completed the event challenge — rare flex!" },
	seasonal_legend = { label = "SEASONAL LEGEND",  tooltip = "Season reward — don't miss the window!" },
}

--------------------------------------------------------------------------
-- URGENCY COPY — shown when a badge is close to being earned or expiring
-- {BADGE} = badge label, {TIME} = time remaining, {PERCENT} = progress.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.AlmostEarned = {
	"You're {PERCENT}% to the {BADGE} badge! Don't stop NOW!",
	"SO close to {BADGE}! A few more runs and it's YOURS!",
	"The {BADGE} badge is RIGHT THERE — push through!",
	"{PERCENT}% to {BADGE}! Players who have it NEVER stop flexing!",
	"Almost {BADGE} status! The lobby will notice. KEEP GOING!",
	"One more push to {BADGE}! Once it's on your profile, it's FOREVER!",
	"{PERCENT}% — {BADGE} is one good session away!",
	"You're THIS close to {BADGE}! Finish strong!",
}

-- Store FOMO badges: no fake progress % — {BADGE} only (wired from StorePanel).
FomoBadgeLabelConfig.AlmostEarnedStore = {
	"SO close to {BADGE}! A few more runs and it's YOURS!",
	"The {BADGE} badge is RIGHT THERE — push through!",
	"Almost {BADGE} status! The lobby will notice. KEEP GOING!",
	"One more push to {BADGE}! Once it's on your profile, it's yours to keep!",
	"You're THIS close to {BADGE}! Finish strong!",
	"The {BADGE} flex is almost yours — keep driving!",
}

FomoBadgeLabelConfig.BestValueGemsCopy = {
	"Best value per Robux in this shop!",
	"Top value — same shop, bigger stacks!",
	"Max bang-for-buck right here!",
}

FomoBadgeLabelConfig.EventExpiring = {
	"⚠️ {BADGE} badge ends in {TIME}! Grab it before the window closes!",
	"LAST CALL for {BADGE}! {TIME} left on this rotation!",
	"The {BADGE} window closes in {TIME} — claim it while it's live!",
	"⏳ {TIME} left to earn {BADGE}! After this event, it's gone for good!",
	"Clock's ticking on {BADGE}! {TIME} left — don't miss this run!",
	"FINAL STRETCH for {BADGE}! {TIME} — earn it before the timer hits zero!",
}

--------------------------------------------------------------------------
-- SOCIAL PROOF — shown to OTHER players who hover/inspect a badge
-- {PLAYER} = badge owner name, {BADGE} = badge label.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.SocialProofInspect = {
	"{PLAYER} earned the {BADGE} badge. Can YOU?",
	"Only the elite carry {BADGE}. {PLAYER} is one of them.",
	"{BADGE} — rare flex. {PLAYER} earned it!",
	"{PLAYER} flexing {BADGE}. What's YOUR rarest badge?",
	"That {BADGE} badge? Yeah, {PLAYER} EARNED that.",
	"Rare badge: {PLAYER} earned {BADGE} — go earn yours!",
	"{BADGE} on {PLAYER}'s profile — that's top-driver energy!",
	"If {PLAYER} can earn {BADGE}, the road's open for you too!",
}

--------------------------------------------------------------------------
-- BADGE SHOWCASE — tooltip copy for the profile badge wall
--------------------------------------------------------------------------

FomoBadgeLabelConfig.EmptySlotCopy = {
	"Empty slot — what will YOU fill it with?",
	"A badge could live here. Keep driving!",
	"Unclaimed! Your next achievement goes RIGHT HERE.",
	"This slot is waiting for something LEGENDARY.",
}

FomoBadgeLabelConfig.FullCollectionCopy = {
	"EVERY BADGE COLLECTED. You are the completionist!",
	"Full badge wall — the rarest sight in the game!",
	"Nothing left to earn. You've conquered EVERYTHING.",
}

--------------------------------------------------------------------------
-- HELPER
--------------------------------------------------------------------------

function FomoBadgeLabelConfig.pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

return FomoBadgeLabelConfig
