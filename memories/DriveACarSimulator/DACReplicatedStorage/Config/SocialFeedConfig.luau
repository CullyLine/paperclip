--!strict
--[[
	Social feed, purchase urgency, and near-miss microcopy pools.
	Phase 4 safety: server-wide lines avoid false timing/scarcity claims, guilt trips,
	and language that spotlights a player in a mocking or commanding way.

	Placeholders:
	  {PLAYER}  – display name of the player who triggered the event
	  {PET}     – pet display name
	  {RARITY}  – rarity label (uppercased in feed)
	  {ODDS}    – honest per-slot odds for this hatch from EggService (e.g. ~2.4%), or "—"
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
	"{PLAYER} just hatched {PET} — {RARITY} roll ({ODDS} on that egg).",
	"Rare drop! {PLAYER} cracked into {PET}! ({ODDS})",
	"{PLAYER}'s egg popped — {RARITY} {PET}! Lobby odds: {ODDS}.",
	"Clean hit! {PLAYER} found {PET} ({RARITY}) — {ODDS} on this egg.",
	"Rare {PET} spotted! {PLAYER} — that's a {ODDS} slot.",
	"{PLAYER} pulled {PET} from the egg — {RARITY} line at {ODDS}.",
	"Fresh hatch! {PLAYER} rolled {RARITY} {PET}! ({ODDS})",
	"Lobby alert: {PLAYER} snagged {PET} ({RARITY}, {ODDS}).",
	"That sparkle? {PLAYER} hatched {PET} — {RARITY} ({ODDS}).",
}

SocialFeedConfig.EpicDrop = {
	"EPIC! {PLAYER} just hatched {PET}! ({ODDS} — big glow energy!)",
	"{PLAYER} pulled EPIC {PET}! {ODDS} on that egg — the lobby felt it!",
	"Purple-screen moment — {PLAYER} cracked Epic {PET}! ({ODDS})",
	"EPIC ALERT! {PLAYER} got {PET}! {RARITY} slot: {ODDS}.",
	"{PLAYER} is on FIRE! Epic {PET} — {ODDS} from this egg.",
	"Epic pull — {PLAYER} scored Epic {PET}! ({ODDS})",
	"That egg never saw it coming — {PLAYER} hatched Epic {PET}! {ODDS}.",
	"High-tier hatch! {PLAYER} — {PET} ({RARITY}) at {ODDS}.",
}

SocialFeedConfig.LegendaryDrop = {
	"LEGENDARY! {PLAYER} hatched {PET}! ({ODDS} — gold-tier pull!)",
	"Gold lights up the lobby — {PLAYER} pulled Legendary {PET}! ({ODDS})",
	"{PLAYER} just scored LEGENDARY {PET}! Honest odds on that egg: {ODDS}.",
	"Banner-worthy! {PLAYER} hatched Legendary {PET}! ({ODDS})",
	"Legendary moment — {PLAYER} hatched {PET}! ({ODDS})",
	"LEGENDARY {PET} — {PLAYER}! {RARITY} slot: {ODDS}.",
	"Big moment — {PLAYER} cracked Legendary {PET}! ({ODDS})",
	"Crown jewel hatch! {PLAYER} — {PET} ({ODDS})",
}

SocialFeedConfig.MythicDrop = {
	"MYTHIC!!! {PLAYER} hatched {PET}!!! ({ODDS} — needle-in-haystack!)",
	"REALITY BENT — {PLAYER} pulled MYTHIC {PET}! ({ODDS} on that egg)",
	"MYTHIC ALERT — {PLAYER} hatched {PET}! {ODDS} from this egg.",
	"The universe glitched — {PLAYER} owns Mythic {PET}! ({ODDS})",
	"MYTHIC {PET}! {PLAYER} — that's a {ODDS} slot. Rare air!",
	"Once-in-a-server energy! {PLAYER} hatched Mythic {PET}! ({ODDS})",
	"History bookmarked — Mythic {PET} for {PLAYER}! ({ODDS})",
	"Top-of-the-tower hatch! {PLAYER} — {PET} ({ODDS})",
}

--------------------------------------------------------------------------
-- 1b. GROUP REWARDS (join prompt, claim, social feed)
--------------------------------------------------------------------------

SocialFeedConfig.GroupJoinBanner = {
	"Join the crew — +5% on every run, plus a one-time welcome drop (coins & a bonus pet). Rejoin after joining to claim!",
	"Group perks: +5% run bonus forever, and a one-time welcome bundle when you join + rejoin. One claim per account!",
	"Want extra juice? Our group gives +5% run bonus plus a one-time welcome pack — join on Roblox, then pop back in!",
	"Roll with us — +5% bonus on runs, and a one-time welcome bundle for new group members (rejoin once to claim).",
	"Squad up: +5% run bonus while you are in the group, plus a one-time coins + pet drop — not a daily chest, just a welcome!",
}

-- Celebration when a player claims the group reward (toast / popup).
SocialFeedConfig.GroupRewardClaim = {
	"Welcome bundle secured — coins and your bonus pet! +5% run bonus is on for good.",
	"Crew perks delivered! Check inventory for your pet — and enjoy +5% bonus every run.",
	"That is the good stuff! One-time welcome claimed — pet and coins are yours!",
	"Group rewards in the bag: bonus pet + coins. +5% run bonus keeps rolling while you are in the group!",
	"Claimed! One-time welcome done — stack that new pet and keep the +5% run bonus!",
}

-- Social feed line when someone joins the group (server-wide banner).
SocialFeedConfig.GroupMemberJoinFeed = {
	"{PLAYER} joined the group — welcome to the crew!",
	"New squad member! {PLAYER} is in — +5% run coins unlocked (and a one-time welcome drop after they rejoin).",
	"{PLAYER} just joined the crew — welcome! (Rejoin once to grab the one-time welcome bundle.)",
	"Crew +1! {PLAYER} is in the group. Welcome!",
	"Lobby shoutout: {PLAYER} joined the group — perks live after they hop back in!",
}

-- Friend play bonus (server-wide banner). Placeholders: {PLAYER}, {FRIEND}, {PERCENT} (e.g. +10%)
SocialFeedConfig.FriendPlayFeed = {
	"{PLAYER} is playing with {FRIEND}! {PERCENT} coins!",
	"Squad up! {PLAYER} + {FRIEND} = {PERCENT} coin bonus!",
	"Friends on the road — {PLAYER} & {FRIEND} stack {PERCENT}!",
	"Party drive! {PLAYER} rolled in with {FRIEND} ({PERCENT} coins)!",
}

--------------------------------------------------------------------------
-- 2. PURCHASE URGENCY / FOMO STORE TEXT
--------------------------------------------------------------------------

-- Flavor lines for store “buzz” badges — avoid implying real inventory counts or live sales data.
SocialFeedConfig.LimitedStock = {
	"Featured deal — grab it while it's in the spotlight!",
	"Hot in the shop right now!",
	"Trending pick — players are eyeing this one!",
	"⚠️ Limited-time rotation — don't sleep on it!",
	"Featured now — this listing rotates on the shop timer!",
	"High demand — snag it if it's on your list!",
	"Offer window closing — check the timer!",
	"Final stretch on this listing — worth a look!",
	"Lobby favorite — grab yours if you love it!",
	"Popular bundle — stacks with your other boosts!",
}

-- Qualitative hype only ({n} removed — was decorative random counts; misleading if not live data).
SocialFeedConfig.SocialProofStore = {
	"Trending in the shop today!",
	"Hot pick — drivers are grabbing this!",
	"A lobby favorite this week!",
	"Popular bundle — worth a look!",
	"Top seller energy — get yours!",
	"Everyone's talking about this one!",
	"Player's choice — grab it while it's featured!",
	"Fan favorite — stacks with passes!",
	"High buzz — snag it if you love it!",
}

-- Roblox Premium run coins: server multiplies by (1 + Constants.PREMIUM_COIN_BONUS) — do not promise 2x here.
SocialFeedConfig.PremiumUpsell = {
	"Roblox Premium: +50% coins on every run — stacks with passes and pets!",
	"Premium members earn more coins per finish — sub and stack the multipliers!",
	"Friends on Premium are getting +50% coins on runs — same drive, fatter payout.",
	"Go Premium for +50% coins + daily premium gifts — easy win!",
	"Serious drivers stack Roblox Premium — +50% coins multiplies with 2x Coins!",
	"Still on base payout? Premium adds +50% to every run's coins!",
	"Premium daily gifts + +50% run coins — worth a look!",
	"Premium + pets + passes = stacked payouts — multiply the math!",
	"Unlock premium daily rewards — plus +50% coins on run payouts!",
	"Treat yourself: Premium turns good runs into GREAT runs!",
	"Want the full garage flex? Premium boosts coins and opens extras!",
}

--------------------------------------------------------------------------
-- 3. ALMOST-THERE / NEAR-MISS PSYCHOLOGY
--------------------------------------------------------------------------

-- Hatch uses per-egg weights (EggService); no server-side pity. Lines are hype + stamina, not odds claims.
SocialFeedConfig.PityEncouragement = {
	"Keep going — Rare+ can pop on the very next hatch!",
	"{n} hatches in — still chasing that Rare+ glow!",
	"Common streak? Next hatch is another clean shot at Rare+.",
	"Every hatch is its own roll — stay in!",
	"Don't stop on the rail — the next one could be the flip!",
	"Streak's cooking — when Rare+ hits, it'll feel huge!",
}

SocialFeedConfig.AlmostNextTier = {
	"You're {PERCENT}% to {TARGET}! So close you can TASTE it!",
	"Almost at {TARGET}! Just a little more — PUSH!",
	"NEARLY THERE! {PERCENT}% of the way to {TARGET}!",
	"One more push to {TARGET}! You're at {PERCENT}% — finish strong!",
	"Can you feel it? {TARGET} is RIGHT THERE! ({PERCENT}%)",
	"{PERCENT}% to {TARGET}! Finish what you started!",
}

-- Fixed one-liners for VFXController almost-there nudges (not random pools). Placeholders: {WorldName}, {n}
-- worldOneRebirth / worldTwoRebirth: only used when WorldUnlockConfig.RebirthThresholdsByWorldId sets a world id → rebirth count (currently unused; worlds are currency-gated in WorldConfig + WorldService).
SocialFeedConfig.AlmostThereVFX = {
	rebirth = "Almost ready to Rebirth!",
	worldOneRebirth = "1 more rebirth to unlock {WorldName}!",
	worldTwoRebirth = "2 more rebirths to unlock {WorldName}!",
	worldCurrency = "Almost enough currency to unlock {WorldName}!",
	collection = "Almost {n}% collected!",
}

SocialFeedConfig.SessionEndRetention = {
	"Wait — you're SO close to your next reward! One more run?",
	"Leaving now? Playtime bonuses tick on their own schedule — another lap might line up!",
	"Your streak is on the line! One more drive keeps it alive!",
	"Hold up — bonus multipliers rotate; stick around for the next boost window!",
	"Don't go — one more hatch could be the one!",
	"Almost at your next milestone — one more run could get you there!",
	"One quick lap could be your best payout yet — stay!",
	"The lobby's buzzing — perfect time for one more run!",
	-- Phase 4 retention pack: softer hooks (aligned with docs/RetentionWinbackMicrocopySpec.md)
	"Battle Pass XP is RIGHT THERE — one more lap could bank it!",
	"Come back after a break? Same — but your daily loop is still warm. One more!",
	"The asphalt cools down fast — one quick drive keeps the dopamine hot!",
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
		return "{PLAYER} hatched {PET} ({RARITY}) • {ODDS}"
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
