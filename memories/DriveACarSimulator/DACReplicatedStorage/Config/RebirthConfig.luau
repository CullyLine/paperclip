--!strict

local RebirthConfig = {}

RebirthConfig.BaseCost = 1_000_000
RebirthConfig.CostMultiplier = 1.5

RebirthConfig.Rewards = {
	speedBoost = 5,
	powerBoost = 5,
	gasBoost = 5,
}

RebirthConfig.ResetOnRebirth = {
	coins = true,
	carUpgrades = true,
	cars = false,
	pets = false,
	eggs = true,
}

return RebirthConfig
