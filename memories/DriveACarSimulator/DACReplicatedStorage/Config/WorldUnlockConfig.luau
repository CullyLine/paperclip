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

-- Worlds unlock via currency in WorldConfig + WorldService (not rebirth count).
WorldUnlockConfig.RebirthThresholdsByWorldId = {}

WorldUnlockConfig.WorldFlavor = {
	forest = {
		headline = "THE FOREST",
		arrival_headline = "Welcome Home, Driver!",
		arrival_subtext = "Winding roads through the trees and your very first lap.",
		fun_fact = "The Forest has more hidden ramps than any other world!",
		flavor = "Where every journey begins. Canopy roads and open sky.",
	},
	desert = {
		headline = "THE DESERT",
		arrival_headline = "Welcome to the Desert!",
		arrival_subtext = "Heat waves and long straights — built for speed demons.",
		fun_fact = "Desert runs earn Sand Granules at 2x rate — the heat makes every meter count!",
		flavor = "Hot sand, long straights, and bigger payouts. The heat is ON.",
	},
	ice = {
		headline = "THE ICE WORLD",
		arrival_headline = "Welcome to the Ice World!",
		arrival_subtext = "Ice beneath your tires and cold, hard Icycles ahead.",
		fun_fact = "The Ice World has the longest unbroken straight in the game!",
		flavor = "Frozen highways and chilling profits. Don't lose your grip.",
	},
	volcano = {
		headline = "THE VOLCANO",
		arrival_headline = "Welcome to the Volcano!",
		arrival_subtext = "Molten rock, lava flows, and roads that glow red-hot.",
		fun_fact = "Volcano runs earn Magma Cores at 10x rate — risk meets reward!",
		flavor = "Blazing roads over molten earth. Drive fast or melt.",
	},
	space = {
		headline = "OUTER SPACE",
		arrival_headline = "Welcome to Space!",
		arrival_subtext = "Zero gravity, infinite roads, and the stars are yours.",
		fun_fact = "Space runs earn Infinitium at 20x rate — the final frontier pays BIG!",
		flavor = "The cosmos is your highway. No limits. No atmosphere.",
	},
}

WorldUnlockConfig.TravelTeaser = {
	desert = {
		"The desert heat calls to the bold...",
		"The Desert: where the REAL payouts live!",
		"Beyond the Forest lies something hotter...",
		"Think you're fast? The desert will test that.",
		"The sand dunes are waiting for tire tracks.",
		"Save up 500,000 Coins — then the Desert opens!",
	},
	ice = {
		"The Ice World awaits the fearless...",
		"Ice, speed, and zero forgiveness. Ready?",
		"Somewhere beyond the snow line, legends drive.",
		"Can you handle the ice? Only one way to find out.",
		"The Ice World doesn't care how fast you WERE.",
		"Unlock Desert first — then 50,000 Sand Granules opens the Ice World!",
	},
	volcano = {
		"The Volcano awaits...",
		"Molten roads and blazing speed. Soon.",
		"Lava flows and roads that never cool... are you ready?",
		"The hottest lanes in the game are behind that gate.",
		"Volcano: where legends become GODS.",
		"Ice cleared? Save 100,000 Icycles — the Volcano is next!",
	},
	space = {
		"Space awaits the ultimate drivers...",
		"Zero gravity. Infinite speed. No atmosphere.",
		"Beyond the volcano, the stars are calling.",
		"The final frontier has roads you can't imagine.",
		"Space: the last world. The biggest payouts.",
		"Volcano conquered? Save 500,000 Magma Cores — Space is the endgame!",
	},
}

return WorldUnlockConfig
