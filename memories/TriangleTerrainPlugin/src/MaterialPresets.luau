--[[
	MaterialPresets
	A user-managed library of named (color + material) pairs. Stored via
	plugin:SetSetting so presets persist across all workspaces the user opens
	(it's a personal library, not per-game state).

	Wire:
	  local presets = MaterialPresets.new(plugin)
	  presets.changed:Connect(function() refreshUI() end)
	  presets:Add("Stone", Color3.fromRGB(100,100,100), Enum.Material.Rock)

	On first run, seeds 6 sensible defaults so the dropdown isn't empty.
]]

local HttpService = game:GetService("HttpService")
local Signal = require(script.Parent.Signal)

export type Preset = {
	id: string,
	name: string,
	color: Color3,
	material: Enum.Material,
}

local SETTING_KEY = "TT_MaterialPresets_v1"

local DEFAULT_PRESETS = {
	{ name = "Grass",  color = Color3.fromRGB( 74, 124,  63), material = Enum.Material.Grass },
	{ name = "Dirt",   color = Color3.fromRGB( 85,  65,  40), material = Enum.Material.Ground },
	{ name = "Stone",  color = Color3.fromRGB(110, 110, 110), material = Enum.Material.Rock },
	{ name = "Sand",   color = Color3.fromRGB(200, 180, 140), material = Enum.Material.Sand },
	{ name = "Snow",   color = Color3.fromRGB(220, 220, 230), material = Enum.Material.Snow },
	{ name = "Water",  color = Color3.fromRGB( 50,  90, 140), material = Enum.Material.Water },
}

local MaterialPresets = {}
MaterialPresets.__index = MaterialPresets

function MaterialPresets.new(plugin: Plugin)
	local self = setmetatable({}, MaterialPresets)
	self._plugin = plugin
	self._presets = {} :: { Preset }
	self._nextId = 1
	self.changed = Signal.new()
	self:_load()
	return self
end

------------------------------------------------------------------------
-- Persistence
------------------------------------------------------------------------
function MaterialPresets:_genId(): string
	local id = string.format("preset_%04d", self._nextId)
	self._nextId += 1
	return id
end

function MaterialPresets:_load()
	local raw = self._plugin:GetSetting(SETTING_KEY)
	if type(raw) == "string" and #raw > 0 then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" then
			for _, entry in decoded do
				local c = entry.color or { 200, 200, 200 }
				-- Enum.Material[X] THROWS on unknown names rather than
				-- returning nil, so a single corrupted setting would crash
				-- _load mid-loop and silently truncate the user's library.
				-- pcall it and fall back to Plastic on any failure.
				local mat = Enum.Material.Plastic
				if type(entry.material) == "string" then
					local okMat, m = pcall(function()
						return (Enum.Material :: any)[entry.material]
					end)
					if okMat and m then mat = m end
				end
				local preset: Preset = {
					id = entry.id or self:_genId(),
					name = entry.name or "Untitled",
					color = Color3.fromRGB(c[1] or 200, c[2] or 200, c[3] or 200),
					material = mat,
				}
				table.insert(self._presets, preset)

				-- Keep the id counter ahead of any loaded ids.
				local n = tonumber(string.match(preset.id, "preset_(%d+)"))
				if n and n >= self._nextId then
					self._nextId = n + 1
				end
			end
			return
		end
	end

	-- First run: seed defaults. We bypass change firing during seeding and
	-- save once at the end.
	for _, d in DEFAULT_PRESETS do
		local id = self:_genId()
		table.insert(self._presets, {
			id = id,
			name = d.name,
			color = d.color,
			material = d.material,
		})
	end
	self:_save()
end

function MaterialPresets:_save()
	local serialized = {}
	for _, p in self._presets do
		table.insert(serialized, {
			id = p.id,
			name = p.name,
			color = {
				math.round(p.color.R * 255),
				math.round(p.color.G * 255),
				math.round(p.color.B * 255),
			},
			material = p.material.Name,
		})
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(serialized)
	end)
	if ok then
		self._plugin:SetSetting(SETTING_KEY, encoded)
	else
		warn("[TriTerrain] Failed to serialize material presets:", encoded)
	end
end

------------------------------------------------------------------------
-- CRUD
------------------------------------------------------------------------
function MaterialPresets:Add(name: string, color: Color3, material: Enum.Material): string
	local id = self:_genId()
	table.insert(self._presets, { id = id, name = name, color = color, material = material })
	self:_save()
	self.changed:Fire()
	return id
end

function MaterialPresets:Update(id: string, fields: { name: string?, color: Color3?, material: Enum.Material? })
	for _, p in self._presets do
		if p.id == id then
			if fields.name ~= nil then p.name = fields.name end
			if fields.color ~= nil then p.color = fields.color end
			if fields.material ~= nil then p.material = fields.material end
			self:_save()
			self.changed:Fire()
			return
		end
	end
end

function MaterialPresets:Remove(id: string)
	for i, p in self._presets do
		if p.id == id then
			table.remove(self._presets, i)
			self:_save()
			self.changed:Fire()
			return
		end
	end
end

function MaterialPresets:Get(id: string): Preset?
	for _, p in self._presets do
		if p.id == id then return p end
	end
	return nil
end

function MaterialPresets:GetAll(): { Preset }
	return self._presets
end

------------------------------------------------------------------------
-- Lookup by exact (color + material) match. Used by UI to figure out
-- which preset (if any) corresponds to the current paint settings, so the
-- preset dropdown can label itself with the matching preset's name.
------------------------------------------------------------------------
local function colorsApproxEqual(a: Color3, b: Color3): boolean
	-- 1/255 tolerance is about the precision we get back from RGB roundtrips.
	local tol = 1 / 255 + 1e-4
	return math.abs(a.R - b.R) < tol
		and math.abs(a.G - b.G) < tol
		and math.abs(a.B - b.B) < tol
end

function MaterialPresets:FindByAppearance(color: Color3, material: Enum.Material): Preset?
	for _, p in self._presets do
		if p.material == material and colorsApproxEqual(p.color, color) then
			return p
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Export (human-readable JSON)
--
-- Format: a JSON array, one preset per line. Pretty-printed manually
-- (HttpService:JSONEncode produces compact one-line output) so it's
-- copy-paste-friendly.
--
-- Example output:
--   [
--     { "name": "Grass", "color": [74, 124, 63], "material": "Grass" },
--     { "name": "Dirt",  "color": [85, 65, 40],  "material": "Ground" }
--   ]
------------------------------------------------------------------------
function MaterialPresets:ExportToJSON(): string
	local lines = { "[" }
	local count = #self._presets
	for i, p in self._presets do
		-- Defer string escaping to HttpService for safety (handles quotes,
		-- backslashes, unicode etc).
		local nameJson = HttpService:JSONEncode(p.name)
		local matJson = HttpService:JSONEncode(p.material.Name)
		local r = math.round(p.color.R * 255)
		local g = math.round(p.color.G * 255)
		local b = math.round(p.color.B * 255)
		local trail = if i < count then "," else ""
		table.insert(lines, string.format(
			'  { "name": %s, "color": [%d, %d, %d], "material": %s }%s',
			nameJson, r, g, b, matJson, trail
		))
	end
	table.insert(lines, "]")
	return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Import (parses JSON exported by ExportToJSON, or any structurally
-- equivalent JSON array).
--
-- `replace = true` clears the existing library before importing.
-- `replace = false` appends.
--
-- Returns (importedCount, errorMessage). If errorMessage is non-nil,
-- nothing was imported (validate-then-apply, no partial state).
------------------------------------------------------------------------
function MaterialPresets:ImportFromJSON(text: string, replace: boolean): (number, string?)
	if type(text) ~= "string" or #text:gsub("%s", "") == 0 then
		return 0, "Empty input."
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if not ok then
		return 0, "Invalid JSON: " .. tostring(decoded):match("[^\n]+")
	end
	if type(decoded) ~= "table" then
		return 0, "Expected a JSON array of presets."
	end

	-- Validate every entry up-front before we mutate any state.
	local staged: { Preset } = {}
	for i, entry in decoded do
		if type(entry) ~= "table" then
			return 0, string.format("Entry #%d is not an object.", i)
		end
		if type(entry.name) ~= "string" or #entry.name == 0 then
			return 0, string.format("Entry #%d is missing a non-empty 'name'.", i)
		end
		if type(entry.color) ~= "table" then
			return 0, string.format("Entry #%d is missing 'color' (expected [r, g, b]).", i)
		end
		local r = entry.color[1]
		local g = entry.color[2]
		local b = entry.color[3]
		if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
			return 0, string.format("Entry #%d has invalid 'color' values.", i)
		end
		if type(entry.material) ~= "string" then
			return 0, string.format("Entry #%d is missing 'material' (expected enum name).", i)
		end
		-- Enum.Material[X] throws on unknown names — pcall so an import with
		-- one bad material returns a clean error instead of a Lua traceback.
		local okMat, mat = pcall(function()
			return (Enum.Material :: any)[entry.material]
		end)
		if not okMat or not mat then
			return 0, string.format("Entry #%d uses unknown material '%s'.", i, entry.material)
		end

		table.insert(staged, {
			id = "",  -- will be assigned below
			name = entry.name,
			color = Color3.fromRGB(
				math.clamp(math.round(r), 0, 255),
				math.clamp(math.round(g), 0, 255),
				math.clamp(math.round(b), 0, 255)
			),
			material = mat,
		})
	end

	if replace then
		table.clear(self._presets)
	end

	for _, entry in staged do
		entry.id = self:_genId()
		table.insert(self._presets, entry)
	end

	self:_save()
	self.changed:Fire()
	return #staged, nil
end

return MaterialPresets
