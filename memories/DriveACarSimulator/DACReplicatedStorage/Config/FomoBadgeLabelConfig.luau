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
	speed_500    = { label = "COMET",             tooltip = "500 studs/s — rarer than a Mythical pet." },
	speed_1000   = { label = "SPEED GOD",         tooltip = "1,000 studs/s. The final form." },
	rebirth_5    = { label = "VETERAN",           tooltip = "5 rebirths — proving you're committed." },
	rebirth_10   = { label = "ELITE",             tooltip = "10 rebirths — top-tier driver." },
	rebirth_25   = { label = "MASTER",            tooltip = "25 rebirths — built different." },
	rebirth_50   = { label = "LEGEND",            tooltip = "50 rebirths — your name echoes." },
	rebirth_100  = { label = "IMMORTAL",          tooltip = "100 rebirths. Nothing left to prove." },
	pets_25      = { label = "COLLECTOR",         tooltip = "25% pet index. The hunt is on!" },
	pets_50      = { label = "CURATOR",           tooltip = "50% pet index — halfway to LEGEND." },
	pets_100     = { label = "COMPLETIONIST",     tooltip = "100% pet index. Every. Single. One." },
	runs_1000    = { label = "ROAD WARRIOR",      tooltip = "1,000 runs complete. Tireless." },
	runs_10000   = { label = "ETERNAL DRIVER",    tooltip = "10,000 runs. You ARE the simulation." },
	streak_30    = { label = "MONTHLY GRINDER",   tooltip = "30-day login streak. Dedication!" },
	streak_100   = { label = "CENTURION",         tooltip = "100-day streak. Absolute machine." },
	first_mythic = { label = "MYTHIC FINDER",     tooltip = "Hatched a Mythical pet. 0.01% odds!" },
	whale_500    = { label = "WHALE",             tooltip = "500 Robux invested. Big leagues!" },
	tycoon_2500  = { label = "TYCOON",            tooltip = "2,500 Robux. Empire builder." },
}

--------------------------------------------------------------------------
-- LIMITED-TIME EVENT BADGES
-- Scarcity-driven labels. Shown with countdown or "GONE FOREVER" text.
-- {EVENT} = event name, {TIME} = remaining time string.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.EventBadgeLabels = {
	launch_driver   = { label = "LAUNCH DRIVER",   tooltip = "Played during LAUNCH WEEK. Gone forever!" },
	holiday_racer   = { label = "HOLIDAY RACER",   tooltip = "Drove during the Holiday Event. Exclusive!" },
	beta_tester     = { label = "OG TESTER",       tooltip = "Tested before anyone else. Respect earned." },
	event_champion  = { label = "EVENT CHAMP",     tooltip = "Completed the event challenge. Ultra-rare!" },
	seasonal_legend = { label = "SEASONAL LEGEND",  tooltip = "Season reward — this one never comes back!" },
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
}

FomoBadgeLabelConfig.EventExpiring = {
	"⚠️ {BADGE} badge expires in {TIME}! Earn it NOW or NEVER!",
	"LAST CHANCE for the {BADGE} badge! {TIME} left!",
	"The {BADGE} badge vanishes in {TIME}! No second chances!",
	"⏳ {TIME} remaining for {BADGE}! This one's GONE FOREVER after!",
	"Clock's ticking on {BADGE}! {TIME} left — don't be the one who missed it!",
	"FINAL HOURS for {BADGE}! Players who miss this regret it FOREVER!",
}

--------------------------------------------------------------------------
-- SOCIAL PROOF — shown to OTHER players who hover/inspect a badge
-- {PLAYER} = badge owner name, {BADGE} = badge label.
--------------------------------------------------------------------------

FomoBadgeLabelConfig.SocialProofInspect = {
	"{PLAYER} earned the {BADGE} badge. Can YOU?",
	"Only the elite carry {BADGE}. {PLAYER} is one of them.",
	"{BADGE} — fewer than 5% of players have this. {PLAYER} does!",
	"{PLAYER} flexing {BADGE}. What's YOUR rarest badge?",
	"That {BADGE} badge? Yeah, {PLAYER} EARNED that.",
	"Rare badge alert: {PLAYER} owns {BADGE}. Jealous yet?",
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
