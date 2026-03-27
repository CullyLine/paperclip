--!strict

local WorldConfig = {}

WorldConfig.Worlds = {
	forest = {
		id = "forest",
		name = "Forest",
		folderName = "1",
		order = 1,
		highwayLength = 5_000,
		unlockCost = 0,
		unlockCurrency = "coins",
		currencyKey = "coins",
		currencyName = "Coins",
		coinMultiplier = 1.0,
		description = "Where every journey begins. Winding roads through the trees.",
	},
	desert = {
		id = "desert",
		name = "Desert",
		folderName = "2",
		order = 2,
		highwayLength = 8_000,
		unlockCost = 500_000,
		unlockCurrency = "coins",
		currencyKey = "sandGranules",
		currencyName = "Sand Granules",
		coinMultiplier = 2.0,
		description = "Hot sand, long roads, and bigger payouts.",
	},
	ice = {
		id = "ice",
		name = "Ice",
		folderName = "3",
		order = 3,
		highwayLength = 12_000,
		unlockCost = 50_000,
		unlockCurrency = "sandGranules",
		currencyKey = "icycles",
		currencyName = "Icycles",
		coinMultiplier = 4.0,
		description = "Frozen highways and chilling profits.",
	},
	volcano = {
		id = "volcano",
		name = "Volcano",
		folderName = "4",
		order = 4,
		highwayLength = 20_000,
		unlockCost = 100_000,
		unlockCurrency = "icycles",
		currencyKey = "magmaCores",
		currencyName = "Magma Cores",
		coinMultiplier = 10.0,
		description = "Molten roads and blazing speed. Don't look down.",
	},
	space = {
		id = "space",
		name = "Space",
		folderName = "5",
		order = 5,
		highwayLength = 30_000,
		unlockCost = 500_000,
		unlockCurrency = "magmaCores",
		currencyKey = "infinitium",
		currencyName = "Infinitium",
		coinMultiplier = 20.0,
		description = "The final frontier. Zero gravity, infinite speed.",
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

function WorldConfig.getCurrencyKey(worldId: string): string
	local world = WorldConfig.Worlds[worldId]
	if world and (world :: any).currencyKey then
		return (world :: any).currencyKey
	end
	return "coins"
end

function WorldConfig.getCurrencyName(worldId: string): string
	local world = WorldConfig.Worlds[worldId]
	if world and (world :: any).currencyName then
		return (world :: any).currencyName
	end
	return "Coins"
end

function WorldConfig.getFolderName(worldId: string): string
	local world = WorldConfig.Worlds[worldId]
	if world and (world :: any).folderName then
		return (world :: any).folderName
	end
	return worldId
end

return WorldConfig
