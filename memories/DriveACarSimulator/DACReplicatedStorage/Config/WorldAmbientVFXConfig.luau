--!strict
--[[
	Phase 4 ambient particle colors per world (matches WorldConfig IDs).
	Sound registry keys use the same world id: `ambient_<worldId>` in SoundController (see Audio/MANIFEST.md).
]]

export type WorldAmbientPalette = {
	primary: Color3,
	secondary: Color3,
	sky: Color3,
	accent: Color3,
}

local WorldAmbientVFXConfig = {}

WorldAmbientVFXConfig.ByWorldId = {
	forest = {
		primary = Color3.fromHex("3DDC84"),
		secondary = Color3.fromHex("87E8A8"),
		sky = Color3.fromHex("5BC0EB"),
		accent = Color3.fromHex("FFD93D"),
	},
	desert = {
		primary = Color3.fromHex("F4A259"),
		secondary = Color3.fromHex("D97D55"),
		sky = Color3.fromHex("FCE7B2"),
		accent = Color3.fromHex("FF6B35"),
	},
	ice = {
		primary = Color3.fromHex("7DD3FC"),
		secondary = Color3.fromHex("38BDF8"),
		sky = Color3.fromHex("E0F2FE"),
		accent = Color3.fromHex("C084FC"),
	},
	volcano = {
		primary = Color3.fromHex("FF6B35"),
		secondary = Color3.fromHex("D94423"),
		sky = Color3.fromHex("1A0A00"),
		accent = Color3.fromHex("FBBF24"),
	},
	space = {
		primary = Color3.fromHex("6366F1"),
		secondary = Color3.fromHex("A78BFA"),
		sky = Color3.fromHex("020617"),
		accent = Color3.fromHex("22D3EE"),
	},
} :: { [string]: WorldAmbientPalette }

function WorldAmbientVFXConfig.get(worldId: string): WorldAmbientPalette
	local row = WorldAmbientVFXConfig.ByWorldId[worldId]
	if row then
		return row
	end
	return WorldAmbientVFXConfig.ByWorldId.forest
end

return WorldAmbientVFXConfig
