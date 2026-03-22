--!strict
--[[
	LOADING SCREEN AUDIO DIRECTION BRIEF
	=====================================

	Target: accompanies gold/shimmer loading screen with FOMO headlines
	and rotating tips.

	1. AMBIENT BED (loops entire load)
	   Mood: simmering anticipation — NOT chill, NOT frenetic.
	   Think low-pass filtered synth hum layered with a subtle
	   ticking/revving undertone. The player should feel like
	   something BIG is about to happen, like sitting on the
	   starting grid before a race.
	   Reference vibe: the "hold your breath" moment before a
	   roller-coaster drop. Muted gold shimmer FX woven in —
	   soft metallic sparkle sweeps panned L-R every ~4 seconds.

	2. PROGRESS MILESTONE CHIMES (play at 25%, 50%, 75%)
	   Short, ascending 3-note phrases. Each milestone should be
	   pitched higher than the last, building harmonic tension.
	   Timbre: bright bell/mallet — clean and satisfying, like
	   collecting a coin in a classic platformer but refined.
	   25%: C5–E5–G5  (hopeful)
	   50%: D5–F#5–A5 (momentum)
	   75%: E5–G#5–B5 (almost there, eyes-wide anticipation)

	3. READY SOUND (fires when load hits 100%)
	   Full resolution of all the harmonic tension built by the
	   chimes. A bright, punchy "power-up complete" stinger:
	   short orchestral hit + synthetic whoosh + subtle crowd-
	   roar undercurrent. Should feel like a stadium eruption
	   compressed into 1.2 seconds. The player should
	   PHYSICALLY want to press play.
	   Reference: the "SEGA!" jingle energy — iconic, instant,
	   and impossible to ignore.
]]

local NearMissCopyConfig = {}

--------------------------------------------------------------------------
-- NEAR-MISS CELEBRATION (10-15 variants)
-- Short popup text when the player narrowly dodges an obstacle.
-- Categories: adrenaline, reward, escalating combo, cocky/fun.
--------------------------------------------------------------------------

NearMissCopyConfig.NearMiss = {
	-- adrenaline
	"CLOSE CALL!",
	"HAIR'S BREADTH!",
	"BY A PIXEL!",
	"JUST BARELY!",
	"WHEW!",
	-- reward
	"+50 SKILL BONUS!",
	"REFLEXES!",
	"PRECISION DRIVING!",
	"CLUTCH BONUS!",
	-- escalating combo
	"NEAR MISS x2!",
	"NEAR MISS x3!",
	"UNTOUCHABLE x5!",
	"NEAR MISS STREAK!",
	-- cocky/fun
	"TOO EASY!",
	"CAN'T TOUCH THIS!",
	"NOT EVEN CLOSE!",
}

--------------------------------------------------------------------------
-- STREAK COUNTER HEADLINES (5-8 variants)
-- Displayed when the player chains consecutive near-misses or
-- completes multiple laps without crashing. Intensity escalates.
--------------------------------------------------------------------------

NearMissCopyConfig.StreakHeadlines = {
	"ON FIRE!",          -- low tier
	"UNSTOPPABLE!",      -- mid tier
	"FLAWLESS RUN!",     -- mid tier
	"COMBO KING!",       -- mid-high tier
	"GOD MODE!",         -- high tier
	"LEGENDARY STREAK!", -- max tier
	"CAN'T BE STOPPED!", -- max tier
	"PERFECTION!",       -- max tier
}

--------------------------------------------------------------------------
-- LAP COMPLETION TEXT (5-8 variants)
-- Short celebration text shown at the end of a completed lap.
--------------------------------------------------------------------------

NearMissCopyConfig.LapComplete = {
	"LAP COMPLETE!",
	"ANOTHER ONE!",
	"KEEP IT ROLLING!",
	"CLEAN LAP!",
	"NAILED IT!",
	"SMOOTH OPERATOR!",
}

NearMissCopyConfig.LapPersonalBest = {
	"NEW RECORD!",
	"FASTEST LAP!",
	"PERSONAL BEST!",
	"YOU BEAT YOURSELF!",
	"NEW PB! INSANE!",
}

NearMissCopyConfig.LapHumor = {
	"EZ!",
	"SPEED DEMON!",
	"BUILT DIFFERENT.",
	"TOO FAST, TOO FURIOUS!",
	"YAWN. NEXT.",
	"IS THAT ALL YOU'VE GOT, TRACK?",
}

return NearMissCopyConfig
