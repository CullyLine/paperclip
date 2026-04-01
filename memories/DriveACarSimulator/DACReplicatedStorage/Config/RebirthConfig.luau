--!strict

local RebirthConfig = {}

RebirthConfig.BaseCost = 400_000
RebirthConfig.CostMultiplier = 1.45

RebirthConfig.Rewards = {
	trainingBonusPerRebirth = 10,
	gemsGranted = 120,
}

RebirthConfig.ResetOnRebirth = {
	coins = true,
	trainedPower = true,
	cars = false,
	pets = false,
	eggs = false,
}

RebirthConfig.SkipTiers = { 1, 2, 5, 10, 25, 50, 100, 250, 500, 1000 }

return RebirthConfig
