--!strict
--[[
	Rebirth milestone celebrations (VFX) + prestige tier for nametag aura.
	Tiers: 5 / 10 / 25 / 50 / 100 rebirths.
]]

local RebirthMilestoneConfig = {}

export type MilestoneKey = "veteran" | "elite" | "master" | "legend" | "immortal"

RebirthMilestoneConfig.THRESHOLDS = { 5, 10, 25, 50, 100 }

RebirthMilestoneConfig.MILESTONES = {
	{ threshold = 5, key = "veteran", label = "VETERAN!" },
	{ threshold = 10, key = "elite", label = "ELITE!" },
	{ threshold = 25, key = "master", label = "MASTER!" },
	{ threshold = 50, key = "legend", label = "LEGEND!" },
	{ threshold = 100, key = "immortal", label = "IMMORTAL!" },
}

function RebirthMilestoneConfig.getPrestigeTier(rebirths: number): number
	local n = math.max(0, math.floor(rebirths))
	if n >= 100 then
		return 5
	elseif n >= 50 then
		return 4
	elseif n >= 25 then
		return 3
	elseif n >= 10 then
		return 2
	elseif n >= 5 then
		return 1
	end
	return 0
end

-- Highest milestone band crossed in one update (e.g. 0→100 → immortal only).
function RebirthMilestoneConfig.getHighestMilestoneCrossed(prevRebirths: number, newRebirths: number): MilestoneKey?
	local prev = math.max(0, math.floor(prevRebirths))
	local neu = math.max(0, math.floor(newRebirths))
	for i = #RebirthMilestoneConfig.MILESTONES, 1, -1 do
		local row = RebirthMilestoneConfig.MILESTONES[i]
		local th = row.threshold
		if prev < th and neu >= th then
			return row.key
		end
	end
	return nil
end

return RebirthMilestoneConfig
