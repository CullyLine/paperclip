--!strict
--[[
	Social feed, purchase urgency, and near-miss microcopy pools.

	Placeholders:
	  {PLAYER}  – display name of the player who triggered the event
	  {PET}     – pet display name
	  {RARITY}  – rarity label (fallback)
	  {n}       – numeric count (purchases today, pity counter, etc.)
	  {PERCENT} – progress percentage toward next milestone
	  {TARGET}  – milestone / tier name

	Each category is a flat array of strings. The UI picks randomly at
	runtime. Keep every line punchy and short — these appear in small
	banner frames and toast popups.
]]

local SocialFeedConfig = {}

--------------------------------------------------------------------------
-- 1. SERVER-WIDE RARE DROP FEED  (banner shown to ALL players)
--------------------------------------------------------------------------

SocialFeedConfig.RareDrop = {
	"{PLAYER} just hatched a RARE {PET}!",
	"Rare drop! {PLAYER} cracked into {PET}!",
	"{PLAYER}'s egg just popped — Rare {PET}!",
	"Somebody's lucky! {PLAYER} found a Rare {PET}!",
	"The egg gods smiled! {PLAYER} got Rare {PET}!",
	"Rare {PET} spotted! Congrats, {PLAYER}!",
	"{PLAYER} just pulled {PET} from the egg! (Rare)",
	"Fresh hatch! {PLAYER} rolled a Rare {PET}!",
}

SocialFeedConfig.EpicDrop = {
	"EPIC! {PLAYER} just hatched {PET}! Can you even?!",
	"{PLAYER} pulled an EPIC {PET}! The lobby is SHAKING!",
	"No way — {PLAYER} cracked an Epic {PET} out of NOWHERE!",
	"The server trembles! {PLAYER} hatched Epic {PET}!",
	"EPIC ALERT! {PLAYER} got {PET}! Jealousy is valid.",
	"{PLAYER} is on FIRE! Epic {PET} just dropped!",
	"Everyone look! {PLAYER} scored an Epic {PET}!",
	"That egg never saw it coming — {PLAYER} hatched Epic {PET}!",
}

SocialFeedConfig.LegendaryDrop = {
	"LEGENDARY! {PLAYER} hatched {PET}! (0.5% chance BTW)",
	"Gold lights up the lobby — {PLAYER} pulled Legendary {PET}!",
	"{PLAYER} just scored a LEGENDARY {PET}! 1 in 200! 🏆",
	"IMPOSSIBLE LUCK! {PLAYER} hatched Legendary {PET}!",
	"The server bows. {PLAYER} owns Legendary {PET} now!",
	"LEGENDARY {PET} HATCHED by {PLAYER}! How does it FEEL?!",
	"Stop everything — {PLAYER} just cracked Legendary {PET}!",
}

SocialFeedConfig.MythicDrop = {
	"MYTHIC!!! {PLAYER} hatched {PET}!!! THE ODDS WERE 0.01%!",
	"REALITY BROKEN — {PLAYER} pulled MYTHIC {PET}! 1 in 10,000!",
	"🚨 MYTHIC ALERT 🚨 {PLAYER} hatched {PET}! Is this REAL?!",
	"The universe glitched — {PLAYER} owns Mythic {PET} now!",
	"MYTHIC {PET}! {PLAYER} just achieved the IMPOSSIBLE!",
	"Once in a LIFETIME! {PLAYER} hatched Mythic {PET}! 🌟",
	"STOP THE PRESSES! Mythic {PET} hatched by {PLAYER}!",
	"History made! {PLAYER} cracked a Mythic {PET}! 0.01% odds CRUSHED!",
}

--------------------------------------------------------------------------
-- 2. PURCHASE URGENCY / FOMO STORE TEXT
--------------------------------------------------------------------------

SocialFeedConfig.LimitedStock = {
	"Only a few left — don't miss out!",
	"Almost GONE! Grab yours before they vanish!",
	"SELLING FAST! Limited stock remaining!",
	"⚠️ LOW STOCK — this won't last!",
	"Last chance! Once they're gone, they're GONE!",
	"Running out FAST! Secure yours NOW!",
	"Supply is drying up — act before it's too late!",
	"FINAL UNITS! The clock is ticking on this one!",
}

SocialFeedConfig.SocialProofStore = {
	"{n} players bought this today!",
	"Trending! {n} drivers already grabbed this!",
	"Hot item — {n} purchases in the last hour!",
	"{n} players can't be wrong. Get yours!",
	"Popular pick! {n} bought this TODAY!",
	"Everyone's getting it — {n} sold so far!",
	"Player's choice! {n} drivers picked this one!",
	"Top pick this week — {n} and counting!",
	"Fan favorite! Trusted by {n} drivers!",
}

SocialFeedConfig.PremiumUpsell = {
	"VIP drivers earn 2x coins EVERY run. Just saying...",
	"Premium unlocks exclusive rides + double rewards. Worth it?",
	"Your friends with VIP are earning TWICE what you are right now.",
	"Go Premium — double coins, exclusive pets, zero regret!",
	"The fastest drivers go VIP. Double your earnings TODAY!",
	"Still grinding at 1x? Premium makes every run count DOUBLE!",
	"VIP members get exclusive pets you can't find anywhere else!",
	"Premium = more rewards, rarer drops, faster progress. Easy choice!",
	"Unlock the full experience — VIP perks are waiting for you!",
}

--------------------------------------------------------------------------
-- 3. ALMOST-THERE / NEAR-MISS PSYCHOLOGY
--------------------------------------------------------------------------

SocialFeedConfig.PityEncouragement = {
	"Keep going — your luck is about to FLIP!",
	"{n} hatches in... the big one is DUE!",
	"Common streak? The game OWES you a rare. Keep hatching!",
	"Every common gets you closer. The odds are stacking in YOUR favor!",
	"Don't stop now — guaranteed rare is almost here!",
	"Pity counter rising! Your next hatch is going to be HUGE!",
}

SocialFeedConfig.AlmostNextTier = {
	"You're {PERCENT}% to {TARGET}! So close you can TASTE it!",
	"Almost at {TARGET}! Just a little more — PUSH!",
	"NEARLY THERE! {PERCENT}% of the way to {TARGET}!",
	"One more push to {TARGET}! Don't quit at {PERCENT}%!",
	"Can you feel it? {TARGET} is RIGHT THERE! ({PERCENT}%)",
	"{PERCENT}% to {TARGET}! Finish what you started!",
}

-- Fixed one-liners for VFXController almost-there nudges (not random pools). Placeholders: {WorldName}, {n}
SocialFeedConfig.AlmostThereVFX = {
	rebirth = "Almost ready to Rebirth!",
	worldOneRebirth = "1 more rebirth to unlock {WorldName}!",
	worldTwoRebirth = "2 more rebirths to unlock {WorldName}!",
	worldCurrency = "Almost enough to unlock {WorldName}!",
	collection = "Almost {n}% collected!",
}

SocialFeedConfig.SessionEndRetention = {
	"Wait — you're SO close to your next reward! One more run?",
	"Leaving now? You'll miss the next gem payout in 2 minutes!",
	"Your streak is on the line! One more drive keeps it alive!",
	"Hold up — a bonus multiplier event starts soon! Stick around!",
	"Don't go! Your pity counter is STACKED — one more hatch!",
	"Almost at your next milestone! Quitting now would be TRAGIC!",
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------

local _poolMap = {
	rare = SocialFeedConfig.RareDrop,
	epic = SocialFeedConfig.EpicDrop,
	legendary = SocialFeedConfig.LegendaryDrop,
	mythic = SocialFeedConfig.MythicDrop,
}

function SocialFeedConfig.pickDropLine(rarity: string): string
	local pool = _poolMap[string.lower(rarity)]
	if not pool or #pool == 0 then
		return "{PLAYER} hatched {PET} ({RARITY})!"
	end
	return pool[math.random(1, #pool)]
end

function SocialFeedConfig.pickLine(category: string): string
	local pool = (SocialFeedConfig :: any)[category]
	if not pool or type(pool) ~= "table" or #pool == 0 then
		return ""
	end
	return pool[math.random(1, #pool)]
end

return SocialFeedConfig
