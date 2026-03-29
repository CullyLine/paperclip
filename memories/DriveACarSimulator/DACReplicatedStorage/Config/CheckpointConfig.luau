--!strict

local CheckpointConfig = {}

CheckpointConfig.Count = 10

CheckpointConfig.Rewards = {
	forest  = { 100,  200,  350,   500,   700,  1_000,  1_500,  2_000,  3_000,   5_000 },
	desert  = { 200,  400,  700, 1_000, 1_400,  2_000,  3_000,  4_000,  6_000,  10_000 },
	ice     = { 400,  800, 1_400, 2_000, 2_800,  4_000,  6_000,  8_000, 12_000,  20_000 },
	volcano = { 1_000, 2_000, 3_500, 5_000, 7_000, 10_000, 15_000, 20_000, 30_000, 50_000 },
	space   = { 2_000, 4_000, 7_000, 10_000, 14_000, 20_000, 30_000, 40_000, 60_000, 100_000 },
}

function CheckpointConfig.getRewards(worldId: string): { number }
	return CheckpointConfig.Rewards[worldId] or CheckpointConfig.Rewards.forest
end

return CheckpointConfig
