--[[
	SunnyShore_BuildScene.lua
	Paste into Roblox Studio command bar to generate the Sunny Shore prototype zone.
	Generates: terrain, beach parts, rock clusters, tide pools, vegetation,
	spawn point, skybox, and golden-hour lighting.

	Part count target: < 3,000 parts (mobile-friendly).
	Aesthetic: smooth low-poly, pastel ocean palette.
]]

local Workspace = game.Workspace
local Lighting = game:GetService("Lighting")
local Terrain = Workspace.Terrain

----------------------------------------------------------------------
-- CLEANUP: remove previous build if re-running
----------------------------------------------------------------------
local existing = Workspace:FindFirstChild("SunnyShore")
if existing then existing:Destroy() end

local root = Instance.new("Model")
root.Name = "SunnyShore"
root.Parent = Workspace

----------------------------------------------------------------------
-- PALETTE
----------------------------------------------------------------------
local C = {
	sand        = Color3.fromRGB(237, 218, 176),
	sandDark    = Color3.fromRGB(210, 190, 145),
	water       = Color3.fromRGB(64, 164, 212),
	waterDeep   = Color3.fromRGB(32, 100, 160),
	rock        = Color3.fromRGB(140, 135, 130),
	rockDark    = Color3.fromRGB(105, 100, 95),
	rockMoss    = Color3.fromRGB(120, 145, 110),
	grass       = Color3.fromRGB(106, 168, 89),
	grassDark   = Color3.fromRGB(78, 132, 64),
	foam        = Color3.fromRGB(230, 240, 250),
	poolGlow    = Color3.fromRGB(80, 220, 255),
	poolWater   = Color3.fromRGB(90, 190, 220),
	coral       = Color3.fromRGB(230, 130, 140),
	coralPurple = Color3.fromRGB(170, 120, 200),
	kelp        = Color3.fromRGB(60, 120, 70),
	shell       = Color3.fromRGB(240, 220, 200),
	driftwood   = Color3.fromRGB(160, 130, 90),
}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local rng = Random.new(42)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or C.sand
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new(0, 0, 0)
	p.Shape = props.Shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = props.CastShadow ~= false
	p.Name = props.Name or "Part"
	p.Parent = props.Parent or root
	if props.Transparency then p.Transparency = props.Transparency end
	if props.CanCollide ~= nil then p.CanCollide = props.CanCollide end
	return p
end

local function wedge(props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = props.Material or Enum.Material.SmoothPlastic
	w.Color = props.Color or C.sand
	w.Size = props.Size or Vector3.new(4, 4, 8)
	w.CFrame = props.CFrame or CFrame.new(0, 0, 0)
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Name = props.Name or "Wedge"
	w.Parent = props.Parent or root
	return w
end

----------------------------------------------------------------------
-- 1. TERRAIN: SAND BEACH + GRASSY HILLS (using parts, not Terrain voxels,
--    for deterministic low-poly look)
----------------------------------------------------------------------

-- Main beach platform (wide, flat)
part({
	Name = "BeachFloor",
	Size = Vector3.new(300, 3, 200),
	CFrame = CFrame.new(0, -1.5, 0),
	Color = C.sand,
	Material = Enum.Material.Sand,
})

-- Wet sand strip along waterline
part({
	Name = "WetSand",
	Size = Vector3.new(300, 0.2, 40),
	CFrame = CFrame.new(0, 0.05, -80),
	Color = C.sandDark,
	Material = Enum.Material.Sand,
})

-- Grassy hill backdrop behind beach
for i = 1, 5 do
	local x = (i - 3) * 60
	local width = rng:NextNumber(50, 70)
	local height = rng:NextNumber(12, 22)
	part({
		Name = "Hill_" .. i,
		Size = Vector3.new(width, height, 40),
		CFrame = CFrame.new(x, height / 2, 110),
		Color = C.grass,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Block,
	})
	-- Rounded top
	part({
		Name = "HillTop_" .. i,
		Size = Vector3.new(width, width * 0.5, 40),
		CFrame = CFrame.new(x, height + width * 0.15, 110),
		Color = C.grassDark,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Cylinder,
	})
end

----------------------------------------------------------------------
-- 2. WATER: Terrain water for native wave/foam rendering
----------------------------------------------------------------------
local WATER_REGION_MIN = Vector3.new(-200, -30, -250)
local WATER_REGION_MAX = Vector3.new(200, -0.5, -80)
local waterRegion = Region3.new(WATER_REGION_MIN, WATER_REGION_MAX)
waterRegion = waterRegion:ExpandToGrid(4)

local size = waterRegion.Size / 4
local mats = {}
local occs = {}
for x = 1, size.X do
	mats[x] = {}
	occs[x] = {}
	for y = 1, size.Y do
		mats[x][y] = {}
		occs[x][y] = {}
		for z = 1, size.Z do
			mats[x][y][z] = Enum.Material.Water
			occs[x][y][z] = 1
		end
	end
end
Terrain:WriteVoxels(waterRegion, 4, mats, occs)

----------------------------------------------------------------------
-- 3. ROCK CLUSTERS along the shoreline
----------------------------------------------------------------------
local rockPositions = {
	{-100, 0, -60}, {-65, 0, -70}, {-30, 0, -55},
	{20, 0, -65}, {70, 0, -50}, {110, 0, -68},
	{-80, 0, -45}, {50, 0, -40}, {130, 0, -55},
}

for i, pos in ipairs(rockPositions) do
	local cluster = Instance.new("Model")
	cluster.Name = "RockCluster_" .. i
	cluster.Parent = root

	local numRocks = rng:NextInteger(2, 5)
	for j = 1, numRocks do
		local sx = rng:NextNumber(3, 10)
		local sy = rng:NextNumber(2, 7)
		local sz = rng:NextNumber(3, 10)
		local ox = rng:NextNumber(-4, 4)
		local oz = rng:NextNumber(-4, 4)
		local rotY = rng:NextNumber(0, 360)
		local color = ({C.rock, C.rockDark, C.rockMoss})[rng:NextInteger(1, 3)]
		part({
			Name = "Rock_" .. j,
			Size = Vector3.new(sx, sy, sz),
			CFrame = CFrame.new(pos[1] + ox, sy / 2 + pos[2], pos[3] + oz)
				* CFrame.Angles(0, math.rad(rotY), math.rad(rng:NextNumber(-10, 10))),
			Color = color,
			Material = Enum.Material.Slate,
			Parent = cluster,
		})
	end
end

----------------------------------------------------------------------
-- 4. TIDE POOLS — 6 interactive discovery spots
--    Arranged in a crescent from near-spawn to far end.
--    Each has a rocky rim, shallow water basin, and an interaction prompt.
----------------------------------------------------------------------

local tidePoolData = {
	{ name = "TidePool_1_Starter", pos = Vector3.new(-15, 0, -30),  size = 10, glow = true },
	{ name = "TidePool_2",        pos = Vector3.new(-55, 0, -50),  size = 8  },
	{ name = "TidePool_3",        pos = Vector3.new(35, 0, -45),   size = 9  },
	{ name = "TidePool_4",        pos = Vector3.new(-90, 0, -65),  size = 8  },
	{ name = "TidePool_5",        pos = Vector3.new(80, 0, -55),   size = 10 },
	{ name = "TidePool_6",        pos = Vector3.new(120, 0, -40),  size = 9  },
}

for _, tp in ipairs(tidePoolData) do
	local model = Instance.new("Model")
	model.Name = tp.name
	model.Parent = root

	local radius = tp.size

	-- Basin (slightly sunken, water-colored)
	local basin = part({
		Name = "Basin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = CFrame.new(tp.pos.X, -0.3, tp.pos.Z)
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = C.poolWater,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = model,
	})

	-- Rocky rim (ring of small rocks around the basin)
	local rimCount = math.floor(radius * 1.8)
	for r = 1, rimCount do
		local angle = (r / rimCount) * math.pi * 2
		local rx = tp.pos.X + math.cos(angle) * (radius + 1)
		local rz = tp.pos.Z + math.sin(angle) * (radius + 1)
		local rockSize = rng:NextNumber(1.5, 3.5)
		part({
			Name = "Rim_" .. r,
			Size = Vector3.new(rockSize, rockSize * 0.6, rockSize),
			CFrame = CFrame.new(rx, rockSize * 0.25, rz)
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0),
			Color = ({C.rock, C.rockDark, C.rockMoss})[rng:NextInteger(1, 3)],
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end

	-- Small coral/shell decorations inside pool
	for d = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(1, radius * 0.6)
		local dx = tp.pos.X + math.cos(angle) * dist
		local dz = tp.pos.Z + math.sin(angle) * dist
		part({
			Name = "Coral_" .. d,
			Size = Vector3.new(
				rng:NextNumber(0.5, 1.5),
				rng:NextNumber(0.5, 2),
				rng:NextNumber(0.5, 1.5)
			),
			CFrame = CFrame.new(dx, 0, dz),
			Color = ({C.coral, C.coralPurple, C.kelp})[rng:NextInteger(1, 3)],
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end

	-- Glow effect on the starter tide pool (onboarding guide)
	if tp.glow then
		local glow = part({
			Name = "GlowDisc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, radius * 2.4, radius * 2.4),
			CFrame = CFrame.new(tp.pos.X, 0.1, tp.pos.Z)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = C.poolGlow,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
			Parent = model,
		})

		local light = Instance.new("PointLight")
		light.Color = C.poolGlow
		light.Brightness = 2
		light.Range = 25
		light.Parent = glow
	end

	-- ProximityPrompt for interaction
	local promptPart = part({
		Name = "InteractionPoint",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(tp.pos.X, 2, tp.pos.Z),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	local prox = Instance.new("ProximityPrompt")
	prox.ActionText = "Discover"
	prox.ObjectText = "Tide Pool"
	prox.HoldDuration = 0.5
	prox.MaxActivationDistance = 12
	prox.RequiresLineOfSight = false
	prox.Parent = promptPart

	-- Tag for scripts to find
	promptPart:SetAttribute("TidePoolId", tp.name)
	promptPart:SetAttribute("ZoneName", "SunnyShore")
end

----------------------------------------------------------------------
-- 5. VEGETATION — simple beach plants and palm-like trees
----------------------------------------------------------------------

local function createPalmTree(position, height)
	local tree = Instance.new("Model")
	tree.Name = "PalmTree"
	tree.Parent = root

	-- Trunk (slightly curved via 3 segments)
	local segments = 3
	local segHeight = height / segments
	local lean = rng:NextNumber(-3, 3)
	for s = 1, segments do
		local yOff = (s - 0.5) * segHeight
		local xOff = lean * (s / segments)
		part({
			Name = "Trunk_" .. s,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segHeight, 2.5 - s * 0.3, 2.5 - s * 0.3),
			CFrame = CFrame.new(position.X + xOff, yOff, position.Z)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(math.rad(lean * 2), 0, 0),
			Color = C.driftwood,
			Material = Enum.Material.Wood,
			Parent = tree,
		})
	end

	-- Fronds (flat wedges radiating from top)
	local topX = position.X + lean
	local topY = height
	for f = 1, 6 do
		local angle = (f / 6) * math.pi * 2
		local frondLen = rng:NextNumber(6, 10)
		wedge({
			Name = "Frond_" .. f,
			Size = Vector3.new(3, 0.3, frondLen),
			CFrame = CFrame.new(
				topX + math.cos(angle) * frondLen * 0.4,
				topY - 1,
				position.Z + math.sin(angle) * frondLen * 0.4
			) * CFrame.Angles(math.rad(-20), angle, 0),
			Color = C.grass,
			Material = Enum.Material.Grass,
			Parent = tree,
		})
	end
end

-- Place some palm trees on the upper beach area
local treePositions = {
	Vector3.new(-60, 0, 40), Vector3.new(-20, 0, 55), Vector3.new(30, 0, 45),
	Vector3.new(80, 0, 60), Vector3.new(120, 0, 50), Vector3.new(-100, 0, 50),
	Vector3.new(0, 0, 70), Vector3.new(50, 0, 75),
}
for _, tpos in ipairs(treePositions) do
	createPalmTree(tpos, rng:NextNumber(14, 22))
end

-- Beach grass clumps
for i = 1, 25 do
	local gx = rng:NextNumber(-130, 130)
	local gz = rng:NextNumber(20, 90)
	for b = 1, rng:NextInteger(3, 6) do
		local bx = gx + rng:NextNumber(-2, 2)
		local bz = gz + rng:NextNumber(-2, 2)
		local bh = rng:NextNumber(1, 3)
		part({
			Name = "Grass_" .. i .. "_" .. b,
			Size = Vector3.new(0.3, bh, 0.3),
			CFrame = CFrame.new(bx, bh / 2, bz)
				* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(0, 360)), 0),
			Color = ({C.grass, C.grassDark})[rng:NextInteger(1, 2)],
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

-- Driftwood and shells scattered on beach
for i = 1, 8 do
	local dx = rng:NextNumber(-120, 120)
	local dz = rng:NextNumber(-30, 30)
	part({
		Name = "Driftwood_" .. i,
		Size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(0.5, 1.5), rng:NextNumber(0.8, 2)),
		CFrame = CFrame.new(dx, 0.3, dz)
			* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-5, 5))),
		Color = C.driftwood,
		Material = Enum.Material.Wood,
	})
end

for i = 1, 12 do
	local sx = rng:NextNumber(-120, 120)
	local sz = rng:NextNumber(-40, 20)
	part({
		Name = "Shell_" .. i,
		Size = Vector3.new(rng:NextNumber(0.5, 1.5), 0.3, rng:NextNumber(0.5, 1.5)),
		CFrame = CFrame.new(sx, 0.15, sz),
		Color = C.shell,
		Material = Enum.Material.SmoothPlastic,
	})
end

----------------------------------------------------------------------
-- 6. FOAM LINE — translucent white strip at the waterline
----------------------------------------------------------------------
for i = 1, 20 do
	local fx = -140 + i * 14 + rng:NextNumber(-3, 3)
	part({
		Name = "Foam_" .. i,
		Size = Vector3.new(rng:NextNumber(10, 18), 0.15, rng:NextNumber(2, 5)),
		CFrame = CFrame.new(fx, 0.08, -78 + rng:NextNumber(-3, 3)),
		Color = C.foam,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.5,
		CanCollide = false,
	})
end

----------------------------------------------------------------------
-- 7. SPAWN POINT
----------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SunnyShoreSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(0, 0.5, 20)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = C.sand
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = root

-- Player faces toward the ocean (and the glowing first tide pool)
spawn.CFrame = CFrame.new(spawn.Position, Vector3.new(-15, 0, -30))

----------------------------------------------------------------------
-- 8. LIGHTING — Golden hour / warm sunny feel
----------------------------------------------------------------------
Lighting.ClockTime = 17.5 -- late afternoon golden hour
Lighting.GeographicLatitude = 25
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(120, 100, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 120, 90)
Lighting.ColorShift_Top = Color3.fromRGB(255, 220, 170)
Lighting.ColorShift_Bottom = Color3.fromRGB(80, 60, 50)
Lighting.EnvironmentDiffuseScale = 0.8
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.3

-- Atmosphere
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.3
atmo.Offset = 0.1
atmo.Color = Color3.fromRGB(200, 180, 160)
atmo.Decay = Color3.fromRGB(120, 90, 60)
atmo.Glare = 0.3
atmo.Haze = 2
atmo.Parent = Lighting

-- Bloom for that dreamy golden-hour feel
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 30
bloom.Threshold = 1.5
bloom.Parent = Lighting

-- Sun rays
local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
sunRays.Intensity = 0.08
sunRays.Spread = 0.6
sunRays.Parent = Lighting

-- Color correction for warm tint
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Brightness = 0.02
cc.Contrast = 0.05
cc.Saturation = 0.15
cc.TintColor = Color3.fromRGB(255, 245, 230)
cc.Parent = Lighting

----------------------------------------------------------------------
-- 9. SKYBOX
----------------------------------------------------------------------
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
sky.CelestialBodiesShown = true
sky.SunAngularSize = 18
sky.MoonAngularSize = 11
-- Using default Roblox sky textures; swap for custom ocean skybox in production
sky.Parent = Lighting

----------------------------------------------------------------------
-- DONE
----------------------------------------------------------------------
print("✓ Sunny Shore zone built — " .. #root:GetDescendants() .. " instances created")
print("  → 6 tide pools placed")
print("  → Spawn faces first glowing tide pool")
print("  → Golden-hour lighting active")
print("  → Paste TidePoolServer.lua into ServerScriptService")
print("  → Paste TidePoolInteraction.lua into StarterPlayerScripts")
