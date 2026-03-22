--!strict
--[[
	World unlock celebration copy.
	UnlockHeadlines: generic pool shown when ANY world is unlocked.
	WorldFlavor: keyed by world ID, each with arrival headline/subtext/fun_fact.
	TravelTeaser: shown BEFORE unlock to build desire for locked worlds.
]]

local WorldUnlockConfig = {}

WorldUnlockConfig.UnlockHeadlines = {
	"NEW WORLD UNLOCKED!",
	"TERRITORY CONQUERED!",
	"NEW ROADS AWAIT!",
	"WORLD DISCOVERED!",
	"MAP EXPANDED!",
	"FRONTIER BREACHED!",
	"UNCHARTED NO MORE!",
	"THE GATES HAVE OPENED!",
}

WorldUnlockConfig.RebirthThresholdsByWorldId = {
	desert = 2,
	frozen = 3,
	neon = 4,
}

WorldUnlockConfig.WorldFlavor = {
	grasslands = {
		headline = "THE GRASSLANDS",
		arrival_headline = "Welcome Home, Driver!",
		arrival_subtext = "Green fields, open roads, and your very first lap.",
		fun_fact = "The Grasslands have more hidden ramps than any other world!",
		flavor = "Where every journey begins. Green fields and open road.",
	},
	desert = {
		headline = "SCORCHING DESERT",
		arrival_headline = "Welcome to the Scorching Sands!",
		arrival_subtext = "Heat waves and long straights — built for speed demons.",
		fun_fact = "Desert runs pay 1.5x coins because the heat tax is REAL!",
		flavor = "Hot sand, long straights, and bigger payouts. The heat is ON.",
	},
	frozen = {
		headline = "FROZEN TUNDRA",
		arrival_headline = "Welcome to the Frozen Wastes!",
		arrival_subtext = "Ice beneath your tires and cold, hard cash ahead.",
		fun_fact = "The Frozen Tundra has the longest unbroken straight in the game!",
		flavor = "Icy highways and chilling profits. Don't lose your grip.",
	},
	neon = {
		headline = "NEON CITY",
		arrival_headline = "Welcome to the Neon District!",
		arrival_subtext = "Neon lights, midnight drives, and the fastest lanes alive.",
		fun_fact = "Neon City never has a day cycle — it's ALWAYS night here!",
		flavor = "The city that never sleeps. The future is bright — and FAST.",
	},
}

WorldUnlockConfig.TravelTeaser = {
	desert = {
		"The desert heat calls to the bold...",
		"Scorching Sands: where the REAL payouts live!",
		"Beyond the Grasslands lies something hotter...",
		"Think you're fast? The desert will test that.",
		"The sand dunes are waiting for tire tracks.",
		"Rebirth again and the desert gates open!",
	},
	frozen = {
		"The Frozen Wastes await the fearless...",
		"Ice, speed, and zero forgiveness. Ready?",
		"Somewhere beyond the snow line, legends drive.",
		"Can you handle the ice? Only one way to find out.",
		"The Tundra doesn't care how fast you WERE.",
		"Rebirth further and the ice roads are yours!",
	},
	neon = {
		"The Neon District awaits...",
		"Neon lights and midnight records. Soon.",
		"The city that never sleeps... and neither will you.",
		"The fastest lanes in the game are behind that gate.",
		"Neon City: where legends become GODS.",
		"One more rebirth and the city is yours!",
	},
}

return WorldUnlockConfig
