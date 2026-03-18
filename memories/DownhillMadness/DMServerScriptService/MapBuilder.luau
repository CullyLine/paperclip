--[[
	MapBuilder — On-demand map generator for Downhill Madness.

	ModuleScript required by MatchManager. Call build() to create
	the map under Workspace.Map, cleanup() to destroy it and
	restore Hub lighting.

	Exports:
	  MapBuilder.build()    — generates the full test map
	  MapBuilder.cleanup()  — destroys Map folder, restores Hub lighting
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

-- ═══════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════
local ROAD_WIDTH    = 400
local ROAD_LENGTH   = 2000
local ROAD_THICK    = 8
local SLOPE_DROP    = 400
local WALL_HEIGHT   = 60
local WALL_THICK    = 12

local START_Y       = SLOPE_DROP / 2
local FINISH_Y      = -SLOPE_DROP / 2

-- ═══════════════════════════════════════════════════════════════════
-- PALETTE
-- ═══════════════════════════════════════════════════════════════════
local C = {
	road       = Color3.fromRGB(90, 90, 95),
	roadLine   = Color3.fromRGB(220, 200, 60),
	cliff      = Color3.fromRGB(115, 100, 85),
	cliffTop   = Color3.fromRGB(80, 110, 60),
	startPlat  = Color3.fromRGB(60, 60, 65),
	finishPlat = Color3.fromRGB(60, 60, 65),
	banner     = Color3.fromRGB(220, 40, 40),
	bannerText = Color3.fromRGB(255, 255, 255),
	boulder    = Color3.fromRGB(130, 120, 110),
	ramp       = Color3.fromRGB(180, 160, 80),
	log        = Color3.fromRGB(100, 70, 40),
	mud        = Color3.fromRGB(120, 85, 50),
	ice        = Color3.fromRGB(180, 220, 240),
	barrier    = Color3.fromRGB(220, 160, 30),
	barrierStr = Color3.fromRGB(200, 40, 40),
	hayBale    = Color3.fromRGB(200, 180, 100),
	powerUp    = Color3.fromRGB(80, 220, 255),
	spawn      = Color3.fromRGB(50, 180, 80),
}

-- Hub lighting defaults (restored on cleanup)
local HUB_LIGHTING = {
	ClockTime = 14,
	GeographicLatitude = 40,
	Brightness = 1.5,
	Ambient = Color3.fromRGB(60, 60, 70),
	OutdoorAmbient = Color3.fromRGB(100, 100, 110),
	GlobalShadows = true,
	ShadowSoftness = 0.3,
}

local HUB_ATMOSPHERE = {
	Density = 0.15,
	Offset = 0.1,
	Color = Color3.fromRGB(200, 210, 230),
	Decay = Color3.fromRGB(120, 130, 160),
	Haze = 1,
}

-- ═══════════════════════════════════════════════════════════════════
-- HELPERS (use map reference set by build())
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
	p.Color     = props.Color or C.road
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
	w.Color     = props.Color or C.ramp
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
		Name   = text .. "Banner",
		Size   = Vector3.new(60, 10, 2),
		CFrame = CFrame.new(position),
		Color  = C.banner,
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
	label.TextColor3 = C.bannerText
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

local function applyMapLighting()
	Lighting.ClockTime = 10
	Lighting.GeographicLatitude = 40
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(80, 80, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.25
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(180, 190, 210)
	atmo.Decay = Color3.fromRGB(100, 110, 140)
	atmo.Haze = 3
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
-- BUILD
-- ═══════════════════════════════════════════════════════════════════
function MapBuilder.build()
	local existing = workspace:FindFirstChild("Map")
	if existing then existing:Destroy() end

	local newMap = Instance.new("Folder")
	newMap.Name = "Map"
	newMap.Parent = workspace
	map = newMap

	local rng = Random.new(2025)

	-- 1. ROAD SURFACE
	local terrainFolder = Instance.new("Folder")
	terrainFolder.Name = "Terrain"
	terrainFolder.Parent = map

	local pitch = math.atan(SLOPE_DROP / ROAD_LENGTH)
	local slopeLen = math.sqrt(ROAD_LENGTH ^ 2 + SLOPE_DROP ^ 2)

	makePart({
		Name     = "RoadSurface",
		Size     = Vector3.new(ROAD_WIDTH, ROAD_THICK, slopeLen),
		CFrame   = CFrame.new(0, 0, 0) * CFrame.Angles(pitch, 0, 0),
		Color    = C.road,
		Material = Enum.Material.Asphalt,
		Parent   = terrainFolder,
	})

	for i = 0, 19 do
		local t = (i + 0.5) / 20
		local z = -ROAD_LENGTH / 2 + t * ROAD_LENGTH
		local y = roadY(z) + ROAD_THICK / 2 + 0.1
		makePart({
			Name   = "CenterLine_" .. i,
			Size   = Vector3.new(2, 0.1, 40),
			CFrame = CFrame.new(0, y, z) * CFrame.Angles(pitch, 0, 0),
			Color  = C.roadLine,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = terrainFolder,
		})
	end

	-- 2. TERRAIN BORDERS
	for _, side in { -1, 1 } do
		local xPos = side * (ROAD_WIDTH / 2 + WALL_THICK / 2)

		makePart({
			Name     = side == -1 and "WallLeft" or "WallRight",
			Size     = Vector3.new(WALL_THICK, WALL_HEIGHT, slopeLen),
			CFrame   = CFrame.new(xPos, WALL_HEIGHT / 2 - SLOPE_DROP / 4, 0)
				* CFrame.Angles(pitch, 0, 0),
			Color    = C.cliff,
			Material = Enum.Material.Slate,
			Parent   = terrainFolder,
		})

		makePart({
			Name     = side == -1 and "CliffTopLeft" or "CliffTopRight",
			Size     = Vector3.new(WALL_THICK + 6, 4, slopeLen),
			CFrame   = CFrame.new(xPos, WALL_HEIGHT - SLOPE_DROP / 4, 0)
				* CFrame.Angles(pitch, 0, 0),
			Color    = C.cliffTop,
			Material = Enum.Material.Grass,
			Parent   = terrainFolder,
		})
	end

	-- 3. START PLATFORM + BANNER
	local startFolder = Instance.new("Folder")
	startFolder.Name = "StartZone"
	startFolder.Parent = map

	local startZ = -ROAD_LENGTH / 2 - 30
	local startPlatY = START_Y + ROAD_THICK / 2

	makePart({
		Name     = "StartPlatform",
		Size     = Vector3.new(ROAD_WIDTH, ROAD_THICK, 80),
		CFrame   = CFrame.new(0, startPlatY, startZ),
		Color    = C.startPlat,
		Material = Enum.Material.Concrete,
		Parent   = startFolder,
	})

	local bannerPoleHeight = 25
	for _, side in { -1, 1 } do
		makePart({
			Name   = side == -1 and "StartPoleLeft" or "StartPoleRight",
			Size   = Vector3.new(3, bannerPoleHeight, 3),
			CFrame = CFrame.new(side * 28, startPlatY + bannerPoleHeight / 2, startZ + 30),
			Color  = C.banner,
			Parent = startFolder,
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
		Name     = "FinishPlatform",
		Size     = Vector3.new(ROAD_WIDTH, ROAD_THICK, 80),
		CFrame   = CFrame.new(0, finishPlatY, finishZ),
		Color    = C.finishPlat,
		Material = Enum.Material.Concrete,
		Parent   = finishFolder,
	})

	for _, side in { -1, 1 } do
		makePart({
			Name   = side == -1 and "FinishPoleLeft" or "FinishPoleRight",
			Size   = Vector3.new(3, bannerPoleHeight, 3),
			CFrame = CFrame.new(side * 28, finishPlatY + bannerPoleHeight / 2, finishZ - 30),
			Color  = C.banner,
			Parent = finishFolder,
		})
	end

	makeBanner("FINISH", Vector3.new(0, finishPlatY + bannerPoleHeight - 5, finishZ - 30), finishFolder)

	for row = 0, 3 do
		for col = 0, 19 do
			local isWhite = (row + col) % 2 == 0
			makePart({
				Name   = "Checker_" .. row .. "_" .. col,
				Size   = Vector3.new(ROAD_WIDTH / 20, 0.15, 3),
				CFrame = CFrame.new(
					-ROAD_WIDTH / 2 + (col + 0.5) * (ROAD_WIDTH / 20),
					finishPlatY + ROAD_THICK / 2 + 0.1,
					finishZ - 12 + row * 3
				),
				Color    = isWhite and Color3.new(1, 1, 1) or Color3.new(0, 0, 0),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent   = finishFolder,
			})
		end
	end

	-- 5. SPAWN POINTS (16 in a single row, facing downhill)
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
			Name   = "VehicleSpawn" .. i,
			Size   = Vector3.new(12, 0.5, 12),
			CFrame = CFrame.new(x, spawnY, spawnLineZ) * downhillFacing,
			Color  = C.spawn,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			Parent = spawnsFolder,
		})
		spawnPart:SetAttribute("SpawnIndex", i)
	end

	-- 6. OBSTACLES
	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = map

	local ZONE_COUNT   = 10
	local ZONE_LENGTH  = ROAD_LENGTH / ZONE_COUNT
	local MIN_OBS      = 3
	local MAX_OBS      = 12
	local halfWidth    = ROAD_WIDTH / 2 - 15

	local function zoneZ(zone: number, t: number): number
		local zStart = -ROAD_LENGTH / 2 + (zone - 1) * ZONE_LENGTH
		return zStart + t * ZONE_LENGTH
	end

	local function randomRoadPos(zone: number): (number, number, number)
		local t = rng:NextNumber(0.05, 0.95)
		local z = zoneZ(zone, t)
		local x = rng:NextNumber(-halfWidth, halfWidth)
		local y = roadY(z) + ROAD_THICK / 2
		return x, y, z
	end

	local obstacleCount = 0

	for zone = 1, ZONE_COUNT do
		local density = MIN_OBS + math.floor((zone / ZONE_COUNT) * (MAX_OBS - MIN_OBS))

		for _ = 1, density do
			local obsType = rng:NextInteger(1, 7)
			local x, y, z = randomRoadPos(zone)

			if obsType == 1 then
				local size = rng:NextNumber(5, 12)
				makePart({
					Name     = "Boulder_" .. obstacleCount,
					Shape    = Enum.PartType.Ball,
					Size     = Vector3.new(size, size, size),
					CFrame   = CFrame.new(x, y + size / 2, z),
					Color    = C.boulder,
					Material = Enum.Material.Slate,
					Parent   = obstaclesFolder,
				})

			elseif obsType == 2 then
				local width = rng:NextNumber(14, 28)
				local height = rng:NextNumber(3, 7)
				local depth = rng:NextNumber(10, 20)
				local yaw = rng:NextNumber(-15, 15)
				makeWedge({
					Name     = "Ramp_" .. obstacleCount,
					Size     = Vector3.new(width, height, depth),
					CFrame   = CFrame.new(x, y + height / 2, z)
						* CFrame.Angles(pitch, math.rad(yaw) + math.pi, 0),
					Color    = C.ramp,
					Material = Enum.Material.Concrete,
					Parent   = obstaclesFolder,
				})

			elseif obsType == 3 then
				local logLen = rng:NextNumber(20, 60)
				local logRad = rng:NextNumber(2, 4)
				local yaw = rng:NextNumber(-30, 30)
				makePart({
					Name     = "Log_" .. obstacleCount,
					Shape    = Enum.PartType.Cylinder,
					Size     = Vector3.new(logLen, logRad * 2, logRad * 2),
					CFrame   = CFrame.new(x, y + logRad, z)
						* CFrame.Angles(0, math.rad(yaw), math.rad(90)),
					Color    = C.log,
					Material = Enum.Material.Wood,
					Parent   = obstaclesFolder,
				})

			elseif obsType == 4 then
				local sx = rng:NextNumber(20, 50)
				local sz = rng:NextNumber(20, 50)
				local mudPart = makePart({
					Name       = "MudZone_" .. obstacleCount,
					Size       = Vector3.new(sx, 0.3, sz),
					CFrame     = CFrame.new(x, y + 0.15, z) * CFrame.Angles(pitch, 0, 0),
					Color      = C.mud,
					Material   = Enum.Material.Mud,
					Parent     = obstaclesFolder,
					CanCollide = false,
				})
				CollectionService:AddTag(mudPart, "MudZone")

			elseif obsType == 5 then
				local sx = rng:NextNumber(20, 50)
				local sz = rng:NextNumber(20, 50)
				local icePart = makePart({
					Name       = "IceZone_" .. obstacleCount,
					Size       = Vector3.new(sx, 0.3, sz),
					CFrame     = CFrame.new(x, y + 0.15, z) * CFrame.Angles(pitch, 0, 0),
					Color      = C.ice,
					Material   = Enum.Material.Ice,
					Parent     = obstaclesFolder,
					CanCollide = false,
				})
				CollectionService:AddTag(icePart, "IceZone")

			elseif obsType == 6 then
				local count = rng:NextInteger(2, 5)
				for b = 1, count do
					local bx = x + (b - 1) * rng:NextNumber(4, 7)
					makePart({
						Name     = "Barrier_" .. obstacleCount .. "_" .. b,
						Size     = Vector3.new(2, 4, 1),
						CFrame   = CFrame.new(bx, y + 2, z),
						Color    = C.barrier,
						Material = Enum.Material.SmoothPlastic,
						Parent   = obstaclesFolder,
					})
					makePart({
						Name     = "BarrierStripe_" .. obstacleCount .. "_" .. b,
						Size     = Vector3.new(2, 0.6, 1),
						CFrame   = CFrame.new(bx, y + 4.3, z),
						Color    = C.barrierStr,
						Material = Enum.Material.Neon,
						Parent   = obstaclesFolder,
					})
				end

			elseif obsType == 7 then
				local radius = rng:NextNumber(3, 5)
				local length = rng:NextNumber(4, 8)
				local yaw = rng:NextNumber(0, 360)
				makePart({
					Name     = "HayBale_" .. obstacleCount,
					Shape    = Enum.PartType.Cylinder,
					Size     = Vector3.new(length, radius * 2, radius * 2),
					CFrame   = CFrame.new(x, y + radius, z)
						* CFrame.Angles(0, math.rad(yaw), math.rad(90)),
					Color    = C.hayBale,
					Material = Enum.Material.Fabric,
					Parent   = obstaclesFolder,
				})
			end

			obstacleCount += 1
		end
	end

	-- 7. POWER-UP SPAWN POINTS
	local powerUpsFolder = Instance.new("Folder")
	powerUpsFolder.Name = "PowerUpSpawns"
	powerUpsFolder.Parent = map

	local POWERUP_COUNT = 25
	local POWERUP_HOVER = 6

	for i = 1, POWERUP_COUNT do
		local t = (i - 0.5) / POWERUP_COUNT
		local z = -ROAD_LENGTH / 2 + t * ROAD_LENGTH
		local x = rng:NextNumber(-halfWidth, halfWidth)
		local y = roadY(z) + ROAD_THICK / 2 + POWERUP_HOVER

		local orb = makePart({
			Name         = "PowerUpSpawn_" .. i,
			Shape        = Enum.PartType.Ball,
			Size         = Vector3.new(4, 4, 4),
			CFrame       = CFrame.new(x, y, z),
			Color        = C.powerUp,
			Material     = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide   = false,
			Parent       = powerUpsFolder,
		})
		CollectionService:AddTag(orb, "PowerUpSpawn")

		local light = Instance.new("PointLight")
		light.Color = C.powerUp
		light.Brightness = 1.5
		light.Range = 18
		light.Parent = orb
	end

	-- 8. MAP LIGHTING
	applyMapLighting()

	print("[MapBuilder] Test map generated under Workspace.Map")
	print("  Road: " .. ROAD_WIDTH .. " wide x " .. ROAD_LENGTH .. " long, " .. SLOPE_DROP .. " stud drop")
	print("  Spawn points: 16 (single row, 200-stud spread)")
	print("  Obstacles: " .. obstacleCount .. " placed across " .. ZONE_COUNT .. " zones")
	print("  Power-up spawns: " .. POWERUP_COUNT)
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

-- Apply Hub lighting on require so the server starts in Hub state
applyHubLighting()

return MapBuilder
