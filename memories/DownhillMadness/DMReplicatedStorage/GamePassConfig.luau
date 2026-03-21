--!strict
--[[
	GamePassConfig.luau — Game pass definitions for Downhill Madness (POL-167, POL-172).
	2x XP Pass, VIP Cosmetics Pass, Early Access Pass. Copy and suggested Robux from POL-167.
	Create the three Game Passes in Roblox Creator Dashboard (Develop → Game Passes) and set the IDs below.
]]

export type GamePassDef = {
	id: number, -- Roblox Game Pass asset ID (set in Creator Dashboard)
	key: string, -- internal key for code (e.g. "double_xp", "vip_cosmetics", "early_access")
	name: string,
	tagline: string,
	description: string,
	robuxPrice: number,
}

-- Replace 0 with your actual Game Pass asset IDs from Creator Dashboard → Game Passes
local GAME_PASSES: { GamePassDef } = {
	{
		id = 0,
		key = "double_xp",
		name = "Double Down",
		tagline = "Twice the XP. Half the grind. Same chaos.",
		description = "Want to level up before your car levels down? Double Down doubles all XP you earn—every race, every trick, every wreck. Get to the good stuff faster.",
		robuxPrice = 399,
	},
	{
		id = 0,
		key = "vip_cosmetics",
		name = "VIP Wreckage",
		tagline = "Look good. Crash better.",
		description = "Exclusive cosmetics only for VIP Wreckage holders. Paint jobs, wheels, trails, plates, and more that free players can't get. Stand out in the lobby and in the dirt.",
		robuxPrice = 599,
	},
	{
		id = 0,
		key = "early_access",
		name = "First Crash",
		tagline = "New maps. New cars. You're first.",
		description = "Be the first to drive new maps and new vehicles before anyone else. Early Access gets you into new content as soon as it drops—no waiting.",
		robuxPrice = 499,
	},
}

local byKey: { [string]: GamePassDef } = {}
local byId: { [number]: GamePassDef } = {}
for _, def in GAME_PASSES do
	byKey[def.key] = def
	if def.id ~= 0 then
		byId[def.id] = def
	end
end

export function getGamePasses(): { GamePassDef }
	return GAME_PASSES
end

export function getPassByKey(key: string): GamePassDef?
	return byKey[key]
end

export function getPassById(id: number): GamePassDef?
	return byId[id]
end

-- Keys for server-side checks (ownership, XP multiplier, VIP gate, early access)
export const PASS_KEY_DOUBLE_XP = "double_xp"
export const PASS_KEY_VIP_COSMETICS = "vip_cosmetics"
export const PASS_KEY_EARLY_ACCESS = "early_access"

return {
	getGamePasses = getGamePasses,
	getPassByKey = getPassByKey,
	getPassById = getPassById,
	PASS_KEY_DOUBLE_XP = PASS_KEY_DOUBLE_XP,
	PASS_KEY_VIP_COSMETICS = PASS_KEY_VIP_COSMETICS,
	PASS_KEY_EARLY_ACCESS = PASS_KEY_EARLY_ACCESS,
}
