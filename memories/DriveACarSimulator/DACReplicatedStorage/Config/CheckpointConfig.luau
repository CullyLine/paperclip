--!strict
--[[
	Per-checkpoint coin rewards (sum = coins per full lap in that world).

	Balanced as uniform multiples of the forest row so progression is predictable:
	  forest  20_000   (tutorial / baseline)
	  desert  44_000   = 2.2×
	  ice    100_000   = 5×
	  volcano 240_000  = 12×
	  space  600_000   = 30×
]]

local CheckpointConfig = {}

CheckpointConfig.Count = 10

CheckpointConfig.Rewards = {
	forest = { 750, 950, 1_150, 1_350, 1_700, 2_100, 2_450, 2_800, 3_150, 3_550 },
	desert = { 1_650, 2_090, 2_530, 2_970, 3_740, 4_620, 5_390, 6_160, 6_930, 7_920 },
	ice = { 3_750, 4_750, 5_750, 6_750, 8_500, 10_500, 12_250, 14_000, 15_750, 18_500 },
	volcano = { 9_000, 11_400, 13_800, 16_200, 20_400, 25_200, 29_400, 33_600, 37_800, 42_600 },
	space = { 22_500, 28_500, 34_500, 40_500, 51_000, 63_000, 73_500, 84_000, 94_500, 106_500 },
}

function CheckpointConfig.getRewards(worldId: string): { number }
	return CheckpointConfig.Rewards[worldId] or CheckpointConfig.Rewards.forest
end

return CheckpointConfig
