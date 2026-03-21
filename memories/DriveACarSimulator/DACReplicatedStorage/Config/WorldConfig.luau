--!strict

local WorldConfig = {}

WorldConfig.Worlds = {
	grasslands = {
		id = "grasslands",
		name = "Grasslands",
		order = 1,
		highwayLength = 5_000, -- studs
		unlockCost = 0,
		unlockCurrency = "coins",
		coinMultiplier = 1.0,
		description = "Where every journey begins. Green fields and open road.",
	},
	desert = {
		id = "desert",
		name = "Scorching Desert",
		order = 2,
		highwayLength = 8_000,
		unlockCost = 500_000,
		unlockCurrency = "coins",
		coinMultiplier = 2.0,
		description = "Hot sand, long roads, and bigger payouts.",
	},
	frozen = {
		id = "frozen",
		name = "Frozen Tundra",
		order = 3,
		highwayLength = 12_000,
		unlockCost = 50_000,
		unlockCurrency = "gems",
		coinMultiplier = 4.0,
		description = "Icy highways and chilling profits.",
	},
	neon = {
		id = "neon",
		name = "Neon City",
		order = 4,
		highwayLength = 20_000,
		unlockCost = 100_000,
		unlockCurrency = "crystals",
		coinMultiplier = 10.0,
		description = "The future is bright. The future is profitable.",
	},
}

function WorldConfig.getWorldsSorted(): { { id: string, name: string, order: number } }
	local sorted = {}
	for _, world in WorldConfig.Worlds do
		table.insert(sorted, world)
	end
	table.sort(sorted, function(a, b)
		return a.order < b.order
	end)
	return sorted
end

return WorldConfig
