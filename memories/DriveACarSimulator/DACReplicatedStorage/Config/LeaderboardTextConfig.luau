--!strict
--[[
	Competitive / FOMO text pools for the leaderboard UI.

	Placeholders in templates (replaced at runtime via string.gsub):
		{OLD_RANK}    – player's previous rank
		{NEW_RANK}    – player's new rank after climbing
		{NEXT_RANK}   – the rank directly above the player
		{GAP}         – coins/distance remaining to next rank
		{RIVAL_NAME}  – display name of the rival near your rank
		{RIVAL_RANK}  – the rank number of an approaching rival
]]

local LeaderboardTextConfig = {}

LeaderboardTextConfig.RankUpMessages = {
	"You just CRUSHED rank #{OLD_RANK}! Welcome to #{NEW_RANK}!",
	"Moving up! #{NEW_RANK} and climbing — who's next?",
	"#{OLD_RANK} is HISTORY. You're #{NEW_RANK} now. Keep driving!",
	"Rank #{NEW_RANK}! The lobby can feel you coming.",
	"From #{OLD_RANK} to #{NEW_RANK} — that was clean. Do it again!",
	"Another one down! #{NEW_RANK} looks good on you.",
	"#{NEW_RANK}?! You weren't here five minutes ago. Respect.",
	"Rank #{OLD_RANK} didn't stand a chance. You own #{NEW_RANK} now.",
	"Climbed to #{NEW_RANK}! The top isn't far — floor it!",
	"#{OLD_RANK} → #{NEW_RANK}. Someone's on a rampage!",
	"You just leapfrogged into #{NEW_RANK}. The board is shaking!",
	"Rank #{NEW_RANK}, baby! They'll remember this run.",
}

LeaderboardTextConfig.TopTenMessages = {
	"Welcome to the top 10, champion. Only legends live up here.",
	"Top 10! You're officially a name everyone sees.",
	"The elite zone. Top 10. Let that sink in.",
	"Single digits. The entire server knows who you are now.",
	"Top 10 — you didn't just play the game, you dominated it.",
	"You cracked the top 10. Thousands tried. You made it.",
	"Welcome to the leaderboard throne room. Top 10, no debate.",
	"Top 10 locked in. Now the real grind begins — hold your spot.",
}

LeaderboardTextConfig.CloseToNextRank = {
	"You're only {GAP} away from rank #{NEXT_RANK}! One more run!",
	"So close! {GAP} more and #{NEXT_RANK} is yours!",
	"Rank #{NEXT_RANK} is RIGHT THERE — just {GAP} to go!",
	"One good run could push you to #{NEXT_RANK}. You're {GAP} away!",
	"#{NEXT_RANK} is practically begging you to take it. {GAP} left!",
	"Don't stop now — {GAP} separates you from #{NEXT_RANK}!",
	"You can TASTE rank #{NEXT_RANK}. Gap: {GAP}. Finish it!",
	"This close to #{NEXT_RANK} and you're gonna quit? {GAP} to go!",
}

LeaderboardTextConfig.RivalApproaching = {
	"#{RIVAL_RANK} is gaining on you! Drive harder!",
	"{RIVAL_NAME} is creeping up — defend your spot!",
	"Watch your back! #{RIVAL_RANK} wants your rank!",
	"Someone at #{RIVAL_RANK} is coming for you. Move!",
	"{RIVAL_NAME} is closing in fast. One run could flip you!",
	"Your spot is in danger — #{RIVAL_RANK} is RIGHT behind you!",
	"You're about to get passed! {RIVAL_NAME} won't slow down!",
	"#{RIVAL_RANK} has been grinding. Protect your position!",
}

LeaderboardTextConfig.Number1Flex = {
	"You are the #1 driver. EVERYONE is chasing YOU.",
	"The crown is yours — #1 on the board. Hold it tight.",
	"Number one. That's not a rank — that's a statement.",
	"Untouchable. The throne is yours… for now.",
}

return LeaderboardTextConfig
