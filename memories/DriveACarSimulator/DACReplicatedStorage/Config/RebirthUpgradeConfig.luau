--!strict

local RebirthUpgradeConfig = {}

RebirthUpgradeConfig.Stats = {
	moreGas = {
		id = "moreGas",
		name = "More Gas",
		costPerPoint = 100,
		maxPercent = 100,
		perPoint = 5,
		order = 1,
	},
	moreCurrency = {
		id = "moreCurrency",
		name = "More Currency",
		costPerPoint = 100,
		maxPercent = 100,
		perPoint = 5,
		order = 2,
	},
	moreLuck = {
		id = "moreLuck",
		name = "More Luck",
		costPerPoint = 100,
		maxPercent = 100,
		perPoint = 5,
		order = 3,
	},
	moreAcceleration = {
		id = "moreAcceleration",
		name = "More Acceleration",
		costPerPoint = 100,
		maxPercent = 100,
		perPoint = 5,
		order = 4,
	},
	moreEggsAtOnce = {
		id = "moreEggsAtOnce",
		name = "More Eggs At Once",
		costPerPoint = 100,
		maxPoints = 25,
		perPoint = 1,
		order = 5,
	},
	moreInventorySpace = {
		id = "moreInventorySpace",
		name = "More Inventory Space",
		costPerPoint = 100,
		maxPercent = 100,
		perPoint = 5,
		order = 6,
	},
	moreRebirthSkips = {
		id = "moreRebirthSkips",
		name = "More Rebirth Skips",
		costPerPoint = 100,
		maxPoints = 20,
		perPoint = 1,
		order = 7,
	},
}

function RebirthUpgradeConfig.getMaxPoints(statId: string): number
	local stat = RebirthUpgradeConfig.Stats[statId]
	if not stat then
		return 0
	end
	if (stat :: any).maxPoints then
		return (stat :: any).maxPoints
	end
	if (stat :: any).maxPercent and (stat :: any).perPoint then
		return math.floor((stat :: any).maxPercent / (stat :: any).perPoint)
	end
	return 20
end

function RebirthUpgradeConfig.getCurrentPercent(statId: string, points: number): number
	local stat = RebirthUpgradeConfig.Stats[statId]
	if not stat then
		return 0
	end
	return points * ((stat :: any).perPoint or 5)
end

function RebirthUpgradeConfig.getSortedStats(): { any }
	local sorted = {}
	for _, s in RebirthUpgradeConfig.Stats do
		table.insert(sorted, s)
	end
	table.sort(sorted, function(a, b)
		return a.order < b.order
	end)
	return sorted
end

return RebirthUpgradeConfig
