--!strict

local RebirthConfig = {}

RebirthConfig.BaseCost = 1_000_000
RebirthConfig.CostMultiplier = 1.5

RebirthConfig.Rewards = {
	crystals = 5,
	speedBoost = 5,
	powerBoost = 5,
	gasBoost = 5,
}

RebirthConfig.ResetOnRebirth = {
	coins = true,
	gems = false,
	crystals = false,
	skulls = false,
	carUpgrades = true, -- reset all car upgrade levels
	cars = false, -- keep owned cars
	pets = false, -- keep all pets
	eggs = true, -- reset egg inventory
}

return RebirthConfig
