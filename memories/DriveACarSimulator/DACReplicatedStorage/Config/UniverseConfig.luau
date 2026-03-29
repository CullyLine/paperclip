--!strict

local UniverseConfig = {}

UniverseConfig.Universes = {
	universe1 = {
		id = "universe1",
		name = "Universe 1",
		order = 1,
		currencyKey = "coins",
		currencyName = "Coins",
		worlds = { "forest", "desert", "ice", "volcano", "space" },
		description = "The origin universe. Five worlds of asphalt and ambition.",
	},
}

function UniverseConfig.getUniverseForWorld(worldId: string): typeof(UniverseConfig.Universes.universe1)?
	for _, universe in UniverseConfig.Universes do
		for _, wId in universe.worlds do
			if wId == worldId then
				return universe
			end
		end
	end
	return nil
end

function UniverseConfig.getCurrencyKey(worldId: string): string
	local universe = UniverseConfig.getUniverseForWorld(worldId)
	if universe then
		return universe.currencyKey
	end
	return "coins"
end

function UniverseConfig.getCurrencyName(worldId: string): string
	local universe = UniverseConfig.getUniverseForWorld(worldId)
	if universe then
		return universe.currencyName
	end
	return "Coins"
end

function UniverseConfig.getUniversesSorted(): { typeof(UniverseConfig.Universes.universe1) }
	local sorted = {}
	for _, u in UniverseConfig.Universes do
		table.insert(sorted, u)
	end
	table.sort(sorted, function(a, b)
		return a.order < b.order
	end)
	return sorted
end

return UniverseConfig
