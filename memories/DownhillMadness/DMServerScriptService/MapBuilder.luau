--[[
	MapBuilder — On-demand biome-based map generator for Downhill Madness.

	M1: Supports multiple biomes that rotate between rounds.

	Exports:
	  MapBuilder.build(biomeId?)  — generates a map (random biome if nil)
	  MapBuilder.cleanup()       — destroys Map folder, restores Hub lighting
	  MapBuilder.getAvailableBiomes() → { string }
	  MapBuilder.getNextBiome()  — returns next biome in rotation
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

-- ═══════════════════════════════════════════════════════════════════
-- SHARED CONSTANTS
-- ═══════════════════════════════════════════════════════════════════
local ROAD_WIDTH    = 400
local ROAD_LENGTH   = 2000
local ROAD_THICK    = 8
local SLOPE_DROP    = 400
local WALL_HEIGHT   = 60
local WALL_THICK    = 12
local WALL_OVERLAP  = 8

local SECTION_LENGTH   = 400
local NUM_SECTIONS     = math.floor(ROAD_LENGTH / SECTION_LENGTH)
local BARRIER_ZONE_W   = 80
local BARRIER_DENSITY  = 0.45

local START_Y  = SLOPE_DROP / 2
local FINISH_Y = -SLOPE_DROP / 2

-- Hub lighting defaults
local HUB_LIGHTING = {
	ClockTime = 14, GeographicLatitude = 40, Brightness = 1.5,
	Ambient = Color3.fromRGB(60, 60, 70),
	OutdoorAmbient = Color3.fromRGB(100, 100, 110),
	GlobalShadows = true, ShadowSoftness = 0.3,
}
local HUB_ATMOSPHERE = {
	Density = 0.15, Offset = 0.1,
	Color = Color3.fromRGB(200, 210, 230),
	Decay = Color3.fromRGB(120, 130, 160),
	Haze = 1,
}

-- ═══════════════════════════════════════════════════════════════════
-- BIOME DEFINITIONS
-- ═══════════════════════════════════════════════════════════════════
type BiomeDef = {
	id: string,
	name: string,
	palette: { [string]: Color3 },
	roadMaterial: Enum.Material,
	wallMaterial: Enum.Material,
	wallTopMaterial: Enum.Material,
	barrierTypes: { string },
	sectionThemes: { string },
	lighting: {
		ClockTime: number, Brightness: number, ShadowSoftness: number,
		Ambient: Color3, OutdoorAmbient: Color3,
	},
	atmosphere: {
		Density: number, Offset: number, Haze: number,
		Color: Color3, Decay: Color3,
	},
}

local BIOMES: { [string]: BiomeDef } = {
	test = {
		id = "test",
		name = "Test Track",
		palette = {
			road = Color3.fromRGB(90, 90, 95),
			roadLine = Color3.fromRGB(220, 200, 60),
			cliff = Color3.fromRGB(115, 100, 85),
			cliffTop = Color3.fromRGB(80, 110, 60),
			platform = Color3.fromRGB(60, 60, 65),
			banner = Color3.fromRGB(220, 40, 40),
			obstacle1 = Color3.fromRGB(130, 120, 110),
			obstacle2 = Color3.fromRGB(180, 160, 80),
			obstacle3 = Color3.fromRGB(100, 70, 40),
			mud = Color3.fromRGB(120, 85, 50),
			ice = Color3.fromRGB(180, 220, 240),
			barrier = Color3.fromRGB(220, 160, 30),
			barrierStr = Color3.fromRGB(200, 40, 40),
			barrierNat1 = Color3.fromRGB(100, 95, 85),
			barrierNat2 = Color3.fromRGB(50, 90, 50),
			barrierNat3 = Color3.fromRGB(60, 45, 35),
		},
		roadMaterial = Enum.Material.Asphalt,
		wallMaterial = Enum.Material.Slate,
		wallTopMaterial = Enum.Material.Grass,
		barrierTypes = { "rock", "tree", "bush" },
		sectionThemes = { "boulders", "ice", "bumpy", "ramps", "mud", "barriers", "mixed" },
		lighting = {
			ClockTime = 10, Brightness = 2.5, ShadowSoftness = 0.2,
			Ambient = Color3.fromRGB(80, 80, 90),
			OutdoorAmbient = Color3.fromRGB(120, 120, 130),
		},
		atmosphere = {
			Density = 0.25, Offset = 0.2, Haze = 3,
			Color = Color3.fromRGB(180, 190, 210),
			Decay = Color3.fromRGB(100, 110, 140),
		},
	},

	alpine = {
		id = "alpine",
		name = "Alpine Summit",
		palette = {
			road = Color3.fromRGB(180, 185, 195),
			roadLine = Color3.fromRGB(200, 60, 60),
			cliff = Color3.fromRGB(140, 140, 150),
			cliffTop = Color3.fromRGB(220, 230, 240),
			platform = Color3.fromRGB(70, 75, 80),
			banner = Color3.fromRGB(200, 40, 40),
			obstacle1 = Color3.fromRGB(160, 160, 170),
			obstacle2 = Color3.fromRGB(100, 120, 80),
			obstacle3 = Color3.fromRGB(70, 55, 40),
			mud = Color3.fromRGB(200, 210, 230),
			ice = Color3.fromRGB(200, 230, 250),
			barrier = Color3.fromRGB(180, 190, 200),
			barrierStr = Color3.fromRGB(200, 40, 40),
			barrierNat1 = Color3.fromRGB(150, 150, 160),
			barrierNat2 = Color3.fromRGB(35, 70, 35),
			barrierNat3 = Color3.fromRGB(50, 40, 30),
		},
		roadMaterial = Enum.Material.Concrete,
		wallMaterial = Enum.Material.Slate,
		wallTopMaterial = Enum.Material.Snow,
		barrierTypes = { "rock", "pine", "snowdrift" },
		sectionThemes = { "boulders", "ice", "ice", "bumpy", "boulders", "mixed", "ice" },
		lighting = {
			ClockTime = 11, Brightness = 3.0, ShadowSoftness = 0.15,
			Ambient = Color3.fromRGB(140, 150, 170),
			OutdoorAmbient = Color3.fromRGB(180, 190, 210),
		},
		atmosphere = {
			Density = 0.35, Offset = 0.1, Haze = 6,
			Color = Color3.fromRGB(210, 220, 240),
			Decay = Color3.fromRGB(160, 170, 200),
		},
	},

	desert_canyon = {
		id = "desert_canyon",
		name = "Desert Canyon",
		palette = {
			road = Color3.fromRGB(180, 140, 100),
			roadLine = Color3.fromRGB(240, 220, 80),
			cliff = Color3.fromRGB(180, 100, 60),
			cliffTop = Color3.fromRGB(200, 160, 100),
			platform = Color3.fromRGB(160, 120, 80),
			banner = Color3.fromRGB(220, 160, 30),
			obstacle1 = Color3.fromRGB(190, 120, 70),
			obstacle2 = Color3.fromRGB(200, 180, 130),
			obstacle3 = Color3.fromRGB(40, 80, 40),
			mud = Color3.fromRGB(210, 180, 120),
			ice = Color3.fromRGB(210, 180, 120),
			barrier = Color3.fromRGB(200, 130, 60),
			barrierStr = Color3.fromRGB(220, 160, 30),
			barrierNat1 = Color3.fromRGB(170, 110, 65),
			barrierNat2 = Color3.fromRGB(40, 75, 35),
			barrierNat3 = Color3.fromRGB(160, 100, 55),
		},
		roadMaterial = Enum.Material.Sand,
		wallMaterial = Color3.fromRGB(180, 100, 60) and Enum.Material.Sandstone,
		wallTopMaterial = Enum.Material.Sand,
		barrierTypes = { "rock", "cactus", "mesa" },
		sectionThemes = { "ramps", "boulders", "mixed", "ramps", "boulders", "barriers", "mixed" },
		lighting = {
			ClockTime = 15, Brightness = 3.5, ShadowSoftness = 0.1,
			Ambient = Color3.fromRGB(120, 100, 80),
			OutdoorAmbient = Color3.fromRGB(160, 140, 110),
		},
		atmosphere = {
			Density = 0.4, Offset = 0.3, Haze = 8,
			Color = Color3.fromRGB(240, 210, 160),
			Decay = Color3.fromRGB(200, 160, 100),
		},
	},
}

local BIOME_ROTATION = { "test", "alpine", "desert_canyon" }
local currentBiomeIndex = 0

-- ═══════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════
local map: Folder? = nil

local function roadY(z: number): number
	local t = (z + ROAD_LENGTH / 2) / ROAD_LENGTH
	return START_Y - t * SLOPE_DROP
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material  = props.Material or Enum.Material.SmoothPlastic
	p.Color     = props.Color or Color3.fromRGB(90, 90, 95)
	p.Size      = props.Size or Vector3.new(4, 1, 4)
	p.CFrame    = props.CFrame or CFrame.new(0, 0, 0)
	p.Shape     = props.Shape or Enum.PartType.Block
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name      = props.Name or "Part"
	p.Parent    = props.Parent or map
	if props.Transparency then p.Transparency = props.Transparency end
	if props.CanCollide ~= nil then p.CanCollide = props.CanCollide end
	return p
end

local function makeWedge(props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material  = props.Material or Enum.Material.SmoothPlastic
	w.Color     = props.Color or Color3.fromRGB(180, 160, 80)
	w.Size      = props.Size or Vector3.new(10, 4, 8)
	w.CFrame    = props.CFrame or CFrame.new(0, 0, 0)
	w.TopSurface    = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Name      = props.Name or "Wedge"
	w.Parent    = props.Parent or map
	return w
end

local function makeBanner(text: string, position: Vector3, parent: Instance)
	local bannerPart = makePart({
		Name = text .. "Banner", Size = Vector3.new(60, 10, 2),
		CFrame = CFrame.new(position), Color = Color3.fromRGB(220, 40, 40),
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = bannerPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	local guiBack = Instance.new("SurfaceGui")
	guiBack.Face = Enum.NormalId.Back
	guiBack.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	guiBack.PixelsPerStud = 20
	guiBack.Parent = bannerPart
	local labelBack = label:Clone()
	labelBack.Parent = guiBack
	return bannerPart
end

local function sectionZRange(sectionIndex: number): (number, number)
	local zStart = -ROAD_LENGTH / 2 + (sectionIndex - 1) * SECTION_LENGTH
	return zStart, zStart + SECTION_LENGTH
end

local function applyLighting(biome: BiomeDef)
	local lt = biome.lighting
	Lighting.ClockTime = lt.ClockTime
	Lighting.GeographicLatitude = 40
	Lighting.Brightness = lt.Brightness
	Lighting.Ambient = lt.Ambient
	Lighting.OutdoorAmbient = lt.OutdoorAmbient
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = lt.ShadowSoftness

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	local a = biome.atmosphere
	atmo.Density = a.Density
	atmo.Offset = a.Offset
	atmo.Color = a.Color
	atmo.Decay = a.Decay
	atmo.Haze = a.Haze
	atmo.Parent = Lighting
end

local function applyHubLighting()
	Lighting.ClockTime = HUB_LIGHTING.ClockTime
	Lighting.GeographicLatitude = HUB_LIGHTING.GeographicLatitude
	Lighting.Brightness = HUB_LIGHTING.Brightness
	Lighting.Ambient = HUB_LIGHTING.Ambient
	Lighting.OutdoorAmbient = HUB_LIGHTING.OutdoorAmbient
	Lighting.GlobalShadows = HUB_LIGHTING.GlobalShadows
	Lighting.ShadowSoftness = HUB_LIGHTING.ShadowSoftness
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = HUB_ATMOSPHERE.Density
	atmo.Offset = HUB_ATMOSPHERE.Offset
	atmo.Color = HUB_ATMOSPHERE.Color
	atmo.Decay = HUB_ATMOSPHERE.Decay
	atmo.Haze = HUB_ATMOSPHERE.Haze
	atmo.Parent = Lighting
end

-- ═══════════════════════════════════════════════════════════════════
-- BIOME-AWARE OBSTACLE GENERATION
-- ═══════════════════════════════════════════════════════════════════
local function generateBarriers(biome: BiomeDef, rng: Random)
	local barriersFolder = Instance.new("Folder")
	barriersFolder.Name = "SideBarriers"
	barriersFolder.Parent = map

	local C = biome.palette
	local pitch = math.atan(SLOPE_DROP / ROAD_LENGTH)
	local barrierStepZ = 12
	local barrierStepX = 10
	local count = 0

	for _, side in { -1, 1 } do
		local xBase = side * (ROAD_WIDTH / 2 - WALL_OVERLAP + BARRIER_ZONE_W / 2)
		for z = -ROAD_LENGTH / 2, ROAD_LENGTH / 2 - barrierStepZ, barrierStepZ do
			for xOff = 0, BARRIER_ZONE_W - barrierStepX, barrierStepX do
				if rng:NextNumber() > (1 - BARRIER_DENSITY) then
					local x = xBase + side * (xOff - BARRIER_ZONE_W / 2)
					local y = roadY(z) + ROAD_THICK / 2
					count += 1
					local kind = rng:NextInteger(1, 3)
					if kind == 1 then
						local sz = rng:NextNumber(6, 14)
						makePart({
							Name = "BarrierRock_" .. count, Shape = Enum.PartType.Ball,
							Size = Vector3.new(sz, sz, sz),
							CFrame = CFrame.new(x, y + sz / 2, z),
							Color = C.barrierNat1, Material = Enum.Material.Slate,
							Parent = barriersFolder,
						})
					elseif kind == 2 then
						local h = rng:NextNumber(8, 18)
						local r = rng:NextNumber(2, 4)
						local mat = biome.id == "alpine" and Enum.Material.Brick or
							biome.id == "desert_canyon" and Enum.Material.Sand or Enum.Material.Wood
						makePart({
							Name = "BarrierTree_" .. count, Shape = Enum.PartType.Cylinder,
							Size = Vector3.new(h, r * 2, r * 2),
							CFrame = CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
							Color = C.barrierNat3, Material = mat,
							Parent = barriersFolder,
						})
					else
						local sx = rng:NextNumber(5, 12)
						local sy = rng:NextNumber(3, 7)
						local sz = rng:NextNumber(5, 12)
						local mat = biome.id == "alpine" and Enum.Material.Snow or
							biome.id == "desert_canyon" and Enum.Material.Sand or Enum.Material.Grass
						makePart({
							Name = "BarrierBush_" .. count,
							Size = Vector3.new(sx, sy, sz),
							CFrame = CFrame.new(x, y + sy / 2, z),
							Color = C.barrierNat2, Material = mat,
							Parent = barriersFolder,
						})
					end
				end
			end
		end
	end
end

local function generateObstacles(biome: BiomeDef, rng: Random)
	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = map

	local C = biome.palette
	local halfWidth = ROAD_WIDTH / 2 - 15
	local pitch = math.atan(SLOPE_DROP / ROAD_LENGTH)
	local obstacleCount = 0

	local function randomPosInSection(si: number): (number, number, number)
		local zStart, zEnd = sectionZRange(si)
		local z = rng:NextNumber(zStart + SECTION_LENGTH * 0.05, zEnd - SECTION_LENGTH * 0.05)
		local x = rng:NextNumber(-halfWidth, halfWidth)
		return x, roadY(z) + ROAD_THICK / 2, z
	end

	local function getSectionTheme(si: number): string
		local themes = biome.sectionThemes
		local i = ((si - 1) % #themes) + 1
		return themes[i]
	end

	-- Biome-specific surface material for "ice" zones
	local iceZoneMat = Enum.Material.Ice
	local iceZoneColor = C.ice
	if biome.id == "desert_canyon" then
		iceZoneMat = Enum.Material.Sand
		iceZoneColor = C.mud
	end

	for sectionIndex = 1, NUM_SECTIONS do
		local theme = getSectionTheme(sectionIndex)
		local zStart, zEnd = sectionZRange(sectionIndex)
		local sectionCenterZ = (zStart + zEnd) / 2
		local sectionY = roadY(sectionCenterZ) + ROAD_THICK / 2

		if theme == "boulders" then
			for _ = 1, rng:NextInteger(8, 14) do
				local x, y, z = randomPosInSection(sectionIndex)
				local size = rng:NextNumber(5, 12)
				makePart({
					Name = "Boulder_" .. obstacleCount, Shape = Enum.PartType.Ball,
					Size = Vector3.new(size, size, size),
					CFrame = CFrame.new(x, y + size / 2, z),
					Color = C.obstacle1, Material = Enum.Material.Slate,
					Parent = obstaclesFolder,
				})
				obstacleCount += 1
			end

		elseif theme == "ice" then
			local zonePart = makePart({
				Name = "SurfaceZone_" .. sectionIndex,
				Size = Vector3.new(ROAD_WIDTH - 30, 0.3, SECTION_LENGTH - 20),
				CFrame = CFrame.new(0, sectionY + 0.15, sectionCenterZ) * CFrame.Angles(pitch, 0, 0),
				Color = iceZoneColor, Material = iceZoneMat,
				Parent = obstaclesFolder, CanCollide = false,
			})
			local tag = biome.id == "desert_canyon" and "SandZone" or "IceZone"
			CollectionService:AddTag(zonePart, tag)
			obstacleCount += 1

		elseif theme == "bumpy" then
			local gridStep = 14
			for z = zStart + 15, zEnd - 15, gridStep do
				for x = -halfWidth, halfWidth, gridStep do
					if rng:NextNumber() > 0.08 then
						local jitterX = x + rng:NextNumber(-3, 3)
						local y = roadY(z) + ROAD_THICK / 2
						local bumpH = rng:NextNumber(1.5, 4)
						local bumpW = rng:NextNumber(4, 10)
						makePart({
							Name = "Bump_" .. obstacleCount,
							Size = Vector3.new(bumpW, bumpH, bumpW),
							CFrame = CFrame.new(jitterX, y + bumpH / 2, z),
							Color = C.obstacle1, Material = Enum.Material.Concrete,
							Parent = obstaclesFolder,
						})
						obstacleCount += 1
					end
				end
			end

		elseif theme == "ramps" then
			for _ = 1, rng:NextInteger(5, 9) do
				local x, y, z = randomPosInSection(sectionIndex)
				local width = rng:NextNumber(22, 38)
				local height = rng:NextNumber(5, 10)
				local depth = rng:NextNumber(16, 28)
				local yaw = rng:NextNumber(-15, 15)
				makeWedge({
					Name = "Ramp_" .. obstacleCount,
					Size = Vector3.new(width, height, depth),
					CFrame = CFrame.new(x, y + height / 2, z) * CFrame.Angles(pitch, math.rad(yaw), 0),
					Color = C.obstacle2,
					Material = biome.id == "desert_canyon" and Enum.Material.Sandstone or Enum.Material.Concrete,
					Parent = obstaclesFolder,
				})
				obstacleCount += 1
			end

		elseif theme == "mud" then
			local numPatches = rng:NextInteger(3, 6)
			local mudMat = biome.id == "alpine" and Enum.Material.Snow or
				biome.id == "desert_canyon" and Enum.Material.Sand or Enum.Material.Mud
			for _ = 1, numPatches do
				local x, y, z = randomPosInSection(sectionIndex)
				local sx = rng:NextNumber(25, 55)
				local sz = rng:NextNumber(25, 55)
				local mudPart = makePart({
					Name = "MudZone_" .. obstacleCount,
					Size = Vector3.new(sx, 0.3, sz),
					CFrame = CFrame.new(x, y + 0.15, z) * CFrame.Angles(pitch, 0, 0),
					Color = C.mud, Material = mudMat,
					Parent = obstaclesFolder, CanCollide = false,
				})
				CollectionService:AddTag(mudPart, "MudZone")
				obstacleCount += 1
			end

		elseif theme == "barriers" then
			for _ = 1, rng:NextInteger(4, 7) do
				local x, y, z = randomPosInSection(sectionIndex)
				local count = rng:NextInteger(2, 5)
				for b = 1, count do
					local bx = x + (b - 1) * rng:NextNumber(4, 7)
					local by = roadY(z) + ROAD_THICK / 2
					makePart({
						Name = "Barrier_" .. obstacleCount .. "_" .. b,
						Size = Vector3.new(2, 4, 1),
						CFrame = CFrame.new(bx, by + 2, z),
						Color = C.barrier, Material = Enum.Material.SmoothPlastic,
						Parent = obstaclesFolder,
					})
					makePart({
						Name = "BarrierStripe_" .. obstacleCount .. "_" .. b,
						Size = Vector3.new(2, 0.6, 1),
						CFrame = CFrame.new(bx, by + 4.3, z),
						Color = C.barrierStr, Material = Enum.Material.Neon,
						Parent = obstaclesFolder,
					})
				end
				obstacleCount += 1
			end

		else -- "mixed"
			local types = { "boulder", "ramp", "log", "hay", "barrier" }
			for _ = 1, rng:NextInteger(6, 12) do
				local x, y, z = randomPosInSection(sectionIndex)
				local choice = types[rng:NextInteger(1, #types)]
				if choice == "boulder" then
					local size = rng:NextNumber(5, 12)
					makePart({ Name = "Boulder_" .. obstacleCount, Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(x, y + size / 2, z), Color = C.obstacle1, Material = Enum.Material.Slate, Parent = obstaclesFolder })
				elseif choice == "ramp" then
					local width, height, depth = rng:NextNumber(14, 24), rng:NextNumber(3, 6), rng:NextNumber(10, 18)
					makeWedge({ Name = "Ramp_" .. obstacleCount, Size = Vector3.new(width, height, depth), CFrame = CFrame.new(x, y + height / 2, z) * CFrame.Angles(pitch, math.rad(rng:NextNumber(-15, 15)), 0), Color = C.obstacle2, Material = Enum.Material.Concrete, Parent = obstaclesFolder })
				elseif choice == "log" then
					local logLen, logRad = rng:NextNumber(20, 50), rng:NextNumber(2, 4)
					makePart({ Name = "Log_" .. obstacleCount, Shape = Enum.PartType.Cylinder, Size = Vector3.new(logLen, logRad * 2, logRad * 2), CFrame = CFrame.new(x, y + logRad, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), math.rad(90)), Color = C.obstacle3, Material = Enum.Material.Wood, Parent = obstaclesFolder })
				elseif choice == "hay" then
					local radius, length = rng:NextNumber(3, 5), rng:NextNumber(4, 8)
					makePart({ Name = "HayBale_" .. obstacleCount, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, radius * 2, radius * 2), CFrame = CFrame.new(x, y + radius, z) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), math.rad(90)), Color = C.obstacle2, Material = Enum.Material.Fabric, Parent = obstaclesFolder })
				else
					local count = rng:NextInteger(2, 4)
					for b = 1, count do
						local bx = x + (b - 1) * rng:NextNumber(4, 6)
						makePart({ Name = "Barrier_" .. obstacleCount .. "_" .. b, Size = Vector3.new(2, 4, 1), CFrame = CFrame.new(bx, y + 2, z), Color = C.barrier, Material = Enum.Material.SmoothPlastic, Parent = obstaclesFolder })
						makePart({ Name = "BarrierStripe_" .. obstacleCount .. "_" .. b, Size = Vector3.new(2, 0.6, 1), CFrame = CFrame.new(bx, y + 4.3, z), Color = C.barrierStr, Material = Enum.Material.Neon, Parent = obstaclesFolder })
					end
				end
				obstacleCount += 1
			end
		end
	end

	return obstacleCount
end

-- ═══════════════════════════════════════════════════════════════════
-- BUILD
-- ═══════════════════════════════════════════════════════════════════
function MapBuilder.build(biomeId: string?)
	local existing = workspace:FindFirstChild("Map")
	if existing then existing:Destroy() end

	local biome = BIOMES[biomeId or "test"]
	if not biome then biome = BIOMES.test end

	local newMap = Instance.new("Folder")
	newMap.Name = "Map"
	newMap:SetAttribute("BiomeId", biome.id)
	newMap:SetAttribute("BiomeName", biome.name)
	newMap.Parent = workspace
	map = newMap

	local rng = Random.new(os.clock() * 1000000 + tick() * 1000 + math.random(1, 999999))
	local C = biome.palette

	-- 1. ROAD SURFACE
	local terrainFolder = Instance.new("Folder")
	terrainFolder.Name = "Terrain"
	terrainFolder.Parent = map

	local pitch = math.atan(SLOPE_DROP / ROAD_LENGTH)
	local slopeLen = math.sqrt(ROAD_LENGTH ^ 2 + SLOPE_DROP ^ 2)

	makePart({
		Name = "RoadSurface",
		Size = Vector3.new(ROAD_WIDTH, ROAD_THICK, slopeLen),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(pitch, 0, 0),
		Color = C.road, Material = biome.roadMaterial,
		Parent = terrainFolder,
	})

	for i = 0, 19 do
		local t = (i + 0.5) / 20
		local z = -ROAD_LENGTH / 2 + t * ROAD_LENGTH
		local y = roadY(z) + ROAD_THICK / 2 + 0.1
		makePart({
			Name = "CenterLine_" .. i,
			Size = Vector3.new(2, 0.1, 40),
			CFrame = CFrame.new(0, y, z) * CFrame.Angles(pitch, 0, 0),
			Color = C.roadLine, Material = Enum.Material.Neon,
			CanCollide = false, Parent = terrainFolder,
		})
	end

	-- 2. WALLS
	for _, side in { -1, 1 } do
		local xPos = side * (ROAD_WIDTH / 2 - WALL_OVERLAP + WALL_THICK / 2)
		makePart({
			Name = side == -1 and "WallLeft" or "WallRight",
			Size = Vector3.new(WALL_THICK, WALL_HEIGHT, slopeLen),
			CFrame = CFrame.new(xPos, WALL_HEIGHT / 2 - SLOPE_DROP / 4, 0) * CFrame.Angles(pitch, 0, 0),
			Color = C.cliff, Material = biome.wallMaterial,
			Parent = terrainFolder,
		})
		makePart({
			Name = side == -1 and "CliffTopLeft" or "CliffTopRight",
			Size = Vector3.new(WALL_THICK + 6, 4, slopeLen),
			CFrame = CFrame.new(xPos, WALL_HEIGHT - SLOPE_DROP / 4, 0) * CFrame.Angles(pitch, 0, 0),
			Color = C.cliffTop, Material = biome.wallTopMaterial,
			Parent = terrainFolder,
		})
	end

	-- 2b. SIDE BARRIERS
	generateBarriers(biome, rng)

	-- 3. START PLATFORM + BANNER
	local startFolder = Instance.new("Folder")
	startFolder.Name = "StartZone"
	startFolder.Parent = map

	local startZ = -ROAD_LENGTH / 2 - 30
	local startPlatY = START_Y + ROAD_THICK / 2
	makePart({
		Name = "StartPlatform", Size = Vector3.new(ROAD_WIDTH, ROAD_THICK, 80),
		CFrame = CFrame.new(0, startPlatY, startZ),
		Color = C.platform, Material = Enum.Material.Concrete,
		Parent = startFolder,
	})
	local bannerPoleHeight = 25
	for _, side in { -1, 1 } do
		makePart({
			Name = side == -1 and "StartPoleLeft" or "StartPoleRight",
			Size = Vector3.new(3, bannerPoleHeight, 3),
			CFrame = CFrame.new(side * 28, startPlatY + bannerPoleHeight / 2, startZ + 30),
			Color = C.banner, Parent = startFolder,
		})
	end
	makeBanner("START", Vector3.new(0, startPlatY + bannerPoleHeight - 5, startZ + 30), startFolder)

	-- 4. FINISH PLATFORM + BANNER
	local finishFolder = Instance.new("Folder")
	finishFolder.Name = "FinishZone"
	finishFolder.Parent = map

	local finishZ = ROAD_LENGTH / 2 + 30
	local finishPlatY = FINISH_Y + ROAD_THICK / 2
	makePart({
		Name = "FinishPlatform", Size = Vector3.new(ROAD_WIDTH, ROAD_THICK, 80),
		CFrame = CFrame.new(0, finishPlatY, finishZ),
		Color = C.platform, Material = Enum.Material.Concrete,
		Parent = finishFolder,
	})
	for _, side in { -1, 1 } do
		makePart({
			Name = side == -1 and "FinishPoleLeft" or "FinishPoleRight",
			Size = Vector3.new(3, bannerPoleHeight, 3),
			CFrame = CFrame.new(side * 28, finishPlatY + bannerPoleHeight / 2, finishZ - 30),
			Color = C.banner, Parent = finishFolder,
		})
	end
	makeBanner("FINISH", Vector3.new(0, finishPlatY + bannerPoleHeight - 5, finishZ - 30), finishFolder)

	for row = 0, 3 do
		for col = 0, 19 do
			local isWhite = (row + col) % 2 == 0
			makePart({
				Name = "Checker_" .. row .. "_" .. col,
				Size = Vector3.new(ROAD_WIDTH / 20, 0.15, 3),
				CFrame = CFrame.new(
					-ROAD_WIDTH / 2 + (col + 0.5) * (ROAD_WIDTH / 20),
					finishPlatY + ROAD_THICK / 2 + 0.1,
					finishZ - 12 + row * 3
				),
				Color = isWhite and Color3.new(1, 1, 1) or Color3.new(0, 0, 0),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false, Parent = finishFolder,
			})
		end
	end

	-- 5. SPAWN POINTS
	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "SpawnPoints"
	spawnsFolder.Parent = map

	local SPAWN_COUNT = 16
	local SPAWN_WIDTH = 200
	local SPAWN_SPACING_X = SPAWN_WIDTH / SPAWN_COUNT
	local spawnLineZ = startZ - 15
	local spawnY = startPlatY + ROAD_THICK / 2 + 1
	local downhillFacing = CFrame.Angles(0, math.pi, 0)

	for i = 1, SPAWN_COUNT do
		local x = (i - (SPAWN_COUNT + 1) / 2) * SPAWN_SPACING_X
		local spawnPart = makePart({
			Name = "VehicleSpawn" .. i,
			Size = Vector3.new(12, 0.5, 12),
			CFrame = CFrame.new(x, spawnY, spawnLineZ) * downhillFacing,
			Color = Color3.fromRGB(50, 180, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.6, CanCollide = false,
			Parent = spawnsFolder,
		})
		spawnPart.CanQuery = false
		spawnPart:SetAttribute("SpawnIndex", i)
	end

	-- 6. OBSTACLES
	local obstacleCount = generateObstacles(biome, rng)

	-- 7. POWER-UP SPAWN POINTS
	local powerUpsFolder = Instance.new("Folder")
	powerUpsFolder.Name = "PowerUpSpawns"
	powerUpsFolder.Parent = map

	local POWERUP_COUNT = 25
	local POWERUP_HOVER = 6

	for i = 1, POWERUP_COUNT do
		local t = (i - 0.5) / POWERUP_COUNT
		local z = -ROAD_LENGTH / 2 + t * ROAD_LENGTH
		local x = rng:NextNumber(-ROAD_WIDTH / 2 + 15, ROAD_WIDTH / 2 - 15)
		local y = roadY(z) + ROAD_THICK / 2 + POWERUP_HOVER

		local orb = makePart({
			Name = "PowerUpSpawn_" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(x, y, z),
			Color = Color3.fromRGB(80, 220, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.3, CanCollide = false,
			Parent = powerUpsFolder,
		})
		CollectionService:AddTag(orb, "PowerUpSpawn")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(80, 220, 255)
		light.Brightness = 1.5
		light.Range = 18
		light.Parent = orb
	end

	-- 8. LIGHTING
	applyLighting(biome)

	print("[MapBuilder] " .. biome.name .. " map generated (" .. biome.id .. ")")
	print("  Obstacles: " .. obstacleCount)
end

-- ═══════════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════════
function MapBuilder.cleanup()
	local existing = workspace:FindFirstChild("Map")
	if existing then existing:Destroy() end
	map = nil
	applyHubLighting()
	print("[MapBuilder] Map cleaned up, Hub lighting restored")
end

-- ═══════════════════════════════════════════════════════════════════
-- BIOME ROTATION
-- ═══════════════════════════════════════════════════════════════════
function MapBuilder.getAvailableBiomes(): { string }
	return BIOME_ROTATION
end

function MapBuilder.getNextBiome(): string
	currentBiomeIndex = (currentBiomeIndex % #BIOME_ROTATION) + 1
	return BIOME_ROTATION[currentBiomeIndex]
end

function MapBuilder.getBiomeName(biomeId: string): string
	local biome = BIOMES[biomeId]
	return biome and biome.name or biomeId
end

-- Apply Hub lighting on require
applyHubLighting()

return MapBuilder
