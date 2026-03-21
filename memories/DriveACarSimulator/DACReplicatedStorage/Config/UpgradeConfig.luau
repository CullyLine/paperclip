--!strict

local UpgradeConfig = {}

UpgradeConfig.Stats = {
	gas = {
		baseCost = 100,
		costMultiplier = 1.15,
		currency = "coins",
		perLevel = 5, -- +5 gas capacity per level
		maxLevel = 100,
	},
	power = {
		baseCost = 150,
		costMultiplier = 1.18,
		currency = "coins",
		perLevel = 3, -- +3 power per level
		maxLevel = 100,
	},
	speed = {
		baseCost = 200,
		costMultiplier = 1.20,
		currency = "coins",
		perLevel = 2, -- +2 speed per level
		maxLevel = 100,
	},
}

return UpgradeConfig
