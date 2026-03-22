--!strict
--[[
	Speed milestone celebration copy.
	9 thresholds from 50 to 1000 studs/s.
	Each milestone: headline (<=20 chars), subtext (<=40 chars), color hex, FOMO line.
	UI picks a random CelebrationText headline + FlavorText subtext on trigger.
	FlexText shown optionally beneath the toast for social proof.
]]

local SpeedMilestoneConfig = {}

SpeedMilestoneConfig.Thresholds = { 50, 100, 150, 200, 300, 400, 500, 750, 1000 }

SpeedMilestoneConfig.MilestoneColor = {
	[50]   = "#4CAF50",
	[100]  = "#8BC34A",
	[150]  = "#FFEB3B",
	[200]  = "#FF9800",
	[300]  = "#FF5722",
	[400]  = "#E91E63",
	[500]  = "#9C27B0",
	[750]  = "#3F51B5",
	[1000] = "#00E5FF",
}

SpeedMilestoneConfig.CelebrationText = {
	[50] = {
		"GETTING ROLLING!",
		"FIRST GEAR!",
		"WHEELS TURNING!",
		"OFF THE LINE!",
		"ROOKIE SPEED!",
		"ENGINE WARM!",
	},
	[100] = {
		"SPEED DEMON!",
		"PEDAL TO THE METAL!",
		"TRIPLE DIGITS!",
		"FULL THROTTLE!",
		"EAT MY DUST!",
		"FLOOR IT!",
	},
	[150] = {
		"TURBO MODE!",
		"UNSTOPPABLE!",
		"BLAZING FAST!",
		"NITRO ENGAGED!",
		"VELOCITY FREAK!",
		"OVERDRIVE!",
	},
	[200] = {
		"SUPERSONIC!",
		"ABSOLUTE UNIT!",
		"MACH MADNESS!",
		"WARP DRIVE!",
		"TERMINAL VELOCITY!",
		"SONIC BOOM!",
	},
	[300] = {
		"GOD SPEED!",
		"REALITY BLUR!",
		"EVENT HORIZON!",
		"TIME BENDS!",
		"ASCENDED!",
		"VOID WALKER!",
	},
	[400] = {
		"QUANTUM LEAP!",
		"PLASMA TRAIL!",
		"DIMENSION SHIFT!",
		"STAR STREAKER!",
		"WARP FACTOR 4!",
		"UNTOUCHABLE!",
	},
	[500] = {
		"HALF A THOUSAND!",
		"LEGEND STATUS!",
		"ORBITAL VELOCITY!",
		"GRAVITY DENIED!",
		"SPEED ROYALTY!",
		"COMET RIDER!",
	},
	[750] = {
		"COSMIC FURY!",
		"LIGHT BENDER!",
		"BEYOND MORTAL!",
		"GALAXY BURNER!",
		"INFINITE ENGINE!",
		"MYTH MADE REAL!",
	},
	[1000] = {
		"LIGHT SPEED!",
		"THE FINAL FORM!",
		"EXISTENCE SHATTERED!",
		"SPEED GOD!",
		"SIMULATION BROKEN!",
		"ONE THOUSAND!",
		"TRANSCENDENT!",
	},
}

-- Celebration text color per threshold (HUD + screen flash tint).
SpeedMilestoneConfig.CelebrationColor = {
	[100] = Color3.fromRGB(255, 220, 100),
	[150] = Color3.fromRGB(255, 200, 80),
	[200] = Color3.fromRGB(255, 180, 70),
	[250] = Color3.fromRGB(255, 160, 60),
	[300] = Color3.fromRGB(255, 230, 120),
}

SpeedMilestoneConfig.FlavorText = {
	[50] = {
		"Every legend starts somewhere!",
		"Not bad for a warm-up lap.",
		"First milestone — many more to go!",
		"The road just noticed you.",
		"Baby steps... at 50 studs per second.",
		"Your journey has officially begun!",
	},
	[100] = {
		"First triple digits!",
		"Now you're cooking!",
		"The road bows to you.",
		"Most drivers never hit this.",
		"Speed is your language now!",
		"Buckle up, it only gets crazier.",
	},
	[150] = {
		"The wind can't keep up!",
		"You left reality in the mirror.",
		"Your tires are crying for mercy.",
		"Built different. No question.",
		"Other drivers are just... parked.",
		"One fifty and climbing!",
	},
	[200] = {
		"The speedometer is begging for help.",
		"Cars this fast shouldn't exist!",
		"Two hundred reasons to fear you.",
		"Science called — wants an explanation.",
		"The road is melting behind you!",
		"Your shadow can't keep up anymore.",
	},
	[300] = {
		"You broke the simulation.",
		"The universe is buffering.",
		"Speed has a new definition: YOU.",
		"That's not a speed, it's a lifestyle.",
		"Reality just filed a restraining order.",
		"The game engine is sweating.",
	},
	[400] = {
		"Air molecules are apologizing.",
		"Your speedometer just rage-quit.",
		"Even light is taking notes.",
		"The map can barely render you.",
		"Other cars think you're a glitch.",
		"Four hundred. Pure dominance.",
	},
	[500] = {
		"Half a thousand studs per second.",
		"Your car is basically a spacecraft.",
		"The finish line comes to YOU.",
		"Physicists are writing papers about you.",
		"Five hundred and counting. Unreal.",
		"Legend tier confirmed.",
	},
	[750] = {
		"Satellites track you now.",
		"Your car left a crater in the track.",
		"Seven fifty. Inhuman reflexes required.",
		"The server allocated extra bandwidth.",
		"You're rewriting the laws of physics.",
		"Mortals don't belong at this speed.",
	},
	[1000] = {
		"One. Thousand. Studs. Per. Second.",
		"You've transcended the game itself.",
		"The speed cap was a suggestion to you.",
		"Congratulations — you ARE the speed.",
		"The devs didn't think this was possible.",
		"Nothing left to prove. You are eternal.",
		"The final milestone. You won.",
	},
}

SpeedMilestoneConfig.FlexText = {
	[50]   = "Everyone starts here — but not everyone keeps going!",
	[100]  = "Only 40% of players ever hit triple digits!",
	[150]  = "Top 25% of all drivers reach this speed!",
	[200]  = "Only 12% of players break 200. You're elite!",
	[300]  = "Less than 5% of drivers see 300. Flex HARD!",
	[400]  = "Top 2% territory. Most players only dream of this!",
	[500]  = "Under 1% of ALL players reach 500. You're a myth!",
	[750]  = "0.1% club. You're rarer than a Mythical pet!",
	[1000] = "THE rarest achievement in the game. Absolute legend!",
}

return SpeedMilestoneConfig
