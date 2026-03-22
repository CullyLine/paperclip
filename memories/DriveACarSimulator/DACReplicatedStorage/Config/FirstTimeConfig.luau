--!strict
--[[
	First-time achievement ceremony copy, spending milestone celebrations,
	and streak milestone text.

	Each category is a flat list of variant strings. The UI picks randomly
	at runtime. Placeholders: {PetName}, {WorldName}, {n}.
]]

local FirstTimeConfig = {}

--------------------------------------------------------------------------
-- FIRST-TIME ACHIEVEMENT CEREMONIES
-- 5 variants per milestone. Shown once per player lifetime.
--------------------------------------------------------------------------

FirstTimeConfig.FirstCarPurchased = {
	"YOUR FIRST RIDE! The journey begins!",
	"GARAGE UNLOCKED! Every legend starts with one car!",
	"KEYS IN HAND! The open road is calling!",
	"FIRST WHEELS! From here, it's all uphill — in speed!",
	"ENGINE ON! You just joined the fastest club on the planet!",
}

FirstTimeConfig.FirstPetHatched = {
	"YOUR FIRST COMPANION! {PetName} chose YOU!",
	"IT'S ALIVE! {PetName} just hatched and already loves you!",
	"PET PARENT! Welcome {PetName} to the squad!",
	"FIRST HATCH! {PetName} is ready to ride with you!",
	"BONDED! {PetName} will never leave your side. Let's GO!",
}

FirstTimeConfig.FirstRebirth = {
	"REBORN! Everything resets, but you're STRONGER!",
	"FIRST REBIRTH! You just unlocked a whole new level of power!",
	"ASCENSION BEGINS! The grind resets — your strength DOESN'T!",
	"REBIRTH COMPLETE! Welcome to the elite. It only gets faster!",
	"RESET. RISE. You just did what most players never dare!",
}

FirstTimeConfig.FirstWorldUnlocked = {
	"NEW HORIZONS! {WorldName} awaits!",
	"WORLD UNLOCKED! Welcome to {WorldName} — new roads, new records!",
	"EXPLORER! {WorldName} is YOURS. Discover every corner!",
	"THE MAP JUST GREW! {WorldName} has secrets waiting for you!",
	"FRONTIER BREAKER! {WorldName} unlocked — fresh asphalt ahead!",
}

FirstTimeConfig.FirstLeaderboardEntry = {
	"YOU'RE ON THE BOARD! #{n} and climbing!",
	"RANKED! Position #{n} — everyone can see your name now!",
	"LEADERBOARD DEBUT! #{n} is just the beginning!",
	"FIRST RANKING! #{n} today, #1 tomorrow. Keep pushing!",
	"ON THE MAP! Rank #{n} — the competition starts NOW!",
}

FirstTimeConfig.FirstGamePassPurchase = {
	"POWER UNLOCKED! You just changed the game!",
	"GAME PASS ACTIVATED! You're playing on another level now!",
	"UPGRADED! Permanent power — no one can take this from you!",
	"ELITE STATUS! That game pass is going to pay for itself TEN times over!",
	"BOOST ENGAGED! You just gave yourself an unfair advantage. Love it!",
}

FirstTimeConfig.FirstQuestCompleted = {
	"QUEST MASTER IN TRAINING! Keep grinding!",
	"FIRST QUEST DOWN! The reward train has left the station!",
	"MISSION ACCOMPLISHED! One quest down, infinite loot to go!",
	"QUEST CLEARED! You just proved you've got what it takes!",
	"NAILED IT! Your first quest is done — the rewards only get BIGGER!",
}

--------------------------------------------------------------------------
-- SPENDING MILESTONE CELEBRATIONS
-- 3+ variants per field per tier. Shown when cumulative Robux spend
-- crosses a threshold. Fields: tierName (label), title (short splash),
-- subtitle (emotional hook), description (validation of investment).
-- Tone: exclusive, prestigious, celebratory — never condescending.
--------------------------------------------------------------------------

FirstTimeConfig.SpendingMilestones = {
	[50] = {
		tierName = "First Timer",
		title = {
			"FIRST TIMER!",
			"YOU'RE IN!",
			"IT BEGINS!",
		},
		subtitle = {
			"Your journey as a supporter starts NOW!",
			"Welcome to the club — you belong here!",
			"Every legend's story has a first chapter!",
		},
		description = {
			"Thanks for investing in your experience — it only gets better from here!",
			"This unlocks perks most players never see. Smart move!",
			"You just separated yourself from the crowd. Enjoy the upgrades!",
		},
	},
	[100] = {
		tierName = "Investor",
		title = {
			"INVESTOR STATUS!",
			"SERIOUS PLAYER!",
			"LEVEL UP!",
		},
		subtitle = {
			"You don't just play — you INVEST in winning!",
			"The smart money is on YOU!",
			"Your garage just got a whole lot more interesting!",
		},
		description = {
			"100 Robux deep and every bit is paying dividends in speed and style!",
			"Players at your level unlock rewards others only dream about!",
			"Your commitment is showing — and so are the results!",
		},
	},
	[250] = {
		tierName = "VIP",
		title = {
			"VIP UNLOCKED!",
			"INNER CIRCLE!",
			"ELITE ACCESS!",
		},
		subtitle = {
			"Welcome to the velvet rope — you're on the guest list!",
			"Only the dedicated reach VIP. You earned this!",
			"The fast lane has your name on it now!",
		},
		description = {
			"VIP status means exclusive perks, priority rewards, and bragging rights!",
			"You've joined a select group — the game looks different from up here!",
			"250 Robux of pure dedication. Your loyalty is legendary!",
		},
	},
	[500] = {
		tierName = "Whale",
		title = {
			"WHALE STATUS!",
			"MAKING WAVES!",
			"BIG LEAGUES!",
		},
		subtitle = {
			"You just became the player everyone talks about!",
			"The ocean is YOURS — everyone else is swimming in your wake!",
			"500 deep and THRIVING. Absolute power move!",
		},
		description = {
			"Whale tier is elite territory — your collection proves it!",
			"At this level, the game basically works for YOU. Enjoy the throne!",
			"Fewer than 5% of players ever reach Whale status. You're built different!",
		},
	},
	[1000] = {
		tierName = "Legend",
		title = {
			"LEGENDARY!",
			"HALL OF FAME!",
			"UNTOUCHABLE!",
		},
		subtitle = {
			"Your name echoes through the leaderboards!",
			"They'll tell stories about YOUR garage!",
			"1,000 Robux of pure commitment — absolute royalty!",
		},
		description = {
			"Legend tier — fewer than 1% of players will EVER stand where you stand!",
			"At this level you don't chase records, records chase YOU!",
			"Your dedication is unmatched. The game bows to your legacy!",
		},
	},
	[2500] = {
		tierName = "Tycoon",
		title = {
			"TYCOON!",
			"EMPIRE BUILDER!",
			"MOGUL STATUS!",
		},
		subtitle = {
			"You don't play the game — you OWN it!",
			"Your empire is the envy of every server!",
			"2,500 Robux deep. You are the definition of POWER!",
		},
		description = {
			"Tycoon tier is reserved for the absolute elite. Welcome to the summit!",
			"At this altitude, the air is rare — and so are you!",
			"Your collection, your stats, your legacy — all UNTOUCHABLE!",
		},
	},
	[5000] = {
		tierName = "Mythic Spender",
		title = {
			"MYTHIC SPENDER!",
			"OFF THE CHARTS!",
			"BEYOND LEGEND!",
		},
		subtitle = {
			"You've transcended every tier. There's nobody above you!",
			"5,000 Robux. The game doesn't have a word for what you are!",
			"You didn't just break the ceiling — you ARE the ceiling!",
		},
		description = {
			"Mythic Spender — the highest honor. Your name is etched in history!",
			"This tier exists because of players like YOU. Absolute pinnacle!",
			"0.1% of players. Maximum prestige. Maximum respect. MYTHIC!",
		},
	},
}

--------------------------------------------------------------------------
-- STREAK CELEBRATIONS
-- 3 variants at key streak milestones: 3, 7, 14, 30, 60, 100 days.
-- Escalating tone from encouragement to awe.
--------------------------------------------------------------------------

FirstTimeConfig.StreakMilestones = {
	[3] = {
		"3 DAYS STRONG! You're building a habit!",
		"HAT TRICK! Three days in a row — momentum is YOURS!",
		"THREE-PEAT! Keep this up and greatness is guaranteed!",
	},
	[7] = {
		"ONE FULL WEEK! Legendary dedication!",
		"7-DAY STREAK! You showed up every single day. RESPECT!",
		"WEEK WARRIOR! Seven days locked in — bonus rewards earned!",
	},
	[14] = {
		"TWO WEEKS! You're unstoppable!",
		"14-DAY STREAK! Half a month of pure GRIND. Incredible!",
		"FORTNIGHT FORCE! Two solid weeks — your loyalty is unmatched!",
	},
	[30] = {
		"A WHOLE MONTH! True champion energy!",
		"30-DAY STREAK! ONE. FULL. MONTH. You're a living legend!",
		"MONTHLY MASTER! 30 days straight — that's elite-tier commitment!",
	},
	[60] = {
		"60 DAYS! Two months of pure dedication — you're UNSTOPPABLE!",
		"DOUBLE MONTH STREAK! Most players dream of this. You LIVED it!",
		"SIXTY AND COUNTING! Your consistency is in a league of its own!",
	},
	[100] = {
		"100 DAYS! ONE HUNDRED. You are an absolute MACHINE!",
		"CENTURION STREAK! 100 days — this is beyond dedication, it's LEGACY!",
		"TRIPLE DIGITS! 100-day streak — you've earned permanent legend status!",
	},
}

return FirstTimeConfig
