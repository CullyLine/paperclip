--[[
	AquariumTemplate_BuildScene.lua — Command Bar Script
	Run in Roblox Studio command bar to generate the player aquarium template.
	
	Produces a Model "AquariumTemplate" under ServerStorage, containing:
	  - Floor platform (sandy island base)
	  - StarterTank (glass-walled tank with terrain water, ambient lighting)
	  - Ambient lighting rig (underwater feel — soft blues/greens)
	  - Decoration anchor points for future cosmetic placement
	  - Pearl collection point
]]

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game.Workspace

local TANK_SIZE = Vector3.new(40, 16, 30)
local GLASS_THICKNESS = 0.4
local GLASS_COLOR = Color3.fromRGB(180, 220, 240)
local GLASS_TRANSPARENCY = 0.7
local GLASS_MATERIAL = Enum.Material.Glass
local SAND_COLOR = Color3.fromRGB(230, 210, 170)
local ROCK_COLOR = Color3.fromRGB(120, 110, 100)
local CORAL_COLORS = {
	Color3.fromRGB(255, 130, 160),
	Color3.fromRGB(255, 180, 100),
	Color3.fromRGB(130, 200, 180),
	Color3.fromRGB(200, 140, 255),
}
local WATER_COLOR = Color3.fromRGB(60, 140, 180)

----------------------------------------------------------------------
-- CLEANUP: remove previous build
----------------------------------------------------------------------
local existing = ServerStorage:FindFirstChild("AquariumTemplate")
if existing then existing:Destroy() end

local existingPreview = Workspace:FindFirstChild("AquariumTemplate_Preview")
if existingPreview then existingPreview:Destroy() end

----------------------------------------------------------------------
-- ROOT MODEL
----------------------------------------------------------------------
local template = Instance.new("Model")
template.Name = "AquariumTemplate"

----------------------------------------------------------------------
-- ISLAND PLATFORM (sandy base)
----------------------------------------------------------------------
local floor = Instance.new("Part")
floor.Name = "IslandFloor"
floor.Size = Vector3.new(80, 3, 60)
floor.Position = Vector3.new(0, -1.5, 0)
floor.Color = SAND_COLOR
floor.Material = Enum.Material.Sand
floor.Anchored = true
floor.CanCollide = true
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = template

-- Rounded edge trim pieces
local edgePositions = {
	{ pos = Vector3.new(0, -1, 32), size = Vector3.new(80, 2, 4) },
	{ pos = Vector3.new(0, -1, -32), size = Vector3.new(80, 2, 4) },
	{ pos = Vector3.new(42, -1, 0), size = Vector3.new(4, 2, 60) },
	{ pos = Vector3.new(-42, -1, 0), size = Vector3.new(4, 2, 60) },
}
for i, e in ipairs(edgePositions) do
	local trim = Instance.new("Part")
	trim.Name = "FloorTrim" .. i
	trim.Size = e.size
	trim.Position = e.pos
	trim.Color = Color3.fromRGB(200, 185, 150)
	trim.Material = Enum.Material.Sand
	trim.Anchored = true
	trim.CanCollide = true
	trim.TopSurface = Enum.SurfaceType.Smooth
	trim.BottomSurface = Enum.SurfaceType.Smooth
	trim.Parent = template
end

----------------------------------------------------------------------
-- STARTER TANK
----------------------------------------------------------------------
local tank = Instance.new("Model")
tank.Name = "StarterTank"
tank:SetAttribute("TankId", "starter")
tank:SetAttribute("Capacity", 6)
tank:SetAttribute("HabitatType", "shallow")

-- Tank floor (sand substrate)
local tankFloor = Instance.new("Part")
tankFloor.Name = "Substrate"
tankFloor.Size = Vector3.new(TANK_SIZE.X, 1, TANK_SIZE.Z)
tankFloor.Position = Vector3.new(0, 0.5, 0)
tankFloor.Color = Color3.fromRGB(220, 200, 160)
tankFloor.Material = Enum.Material.Sand
tankFloor.Anchored = true
tankFloor.CanCollide = true
tankFloor.TopSurface = Enum.SurfaceType.Smooth
tankFloor.BottomSurface = Enum.SurfaceType.Smooth
tankFloor.Parent = tank

-- Glass walls (four sides)
local wallDefs = {
	{ name = "GlassFront",  size = Vector3.new(TANK_SIZE.X, TANK_SIZE.Y, GLASS_THICKNESS), pos = Vector3.new(0, TANK_SIZE.Y/2 + 1, TANK_SIZE.Z/2) },
	{ name = "GlassBack",   size = Vector3.new(TANK_SIZE.X, TANK_SIZE.Y, GLASS_THICKNESS), pos = Vector3.new(0, TANK_SIZE.Y/2 + 1, -TANK_SIZE.Z/2) },
	{ name = "GlassLeft",   size = Vector3.new(GLASS_THICKNESS, TANK_SIZE.Y, TANK_SIZE.Z), pos = Vector3.new(-TANK_SIZE.X/2, TANK_SIZE.Y/2 + 1, 0) },
	{ name = "GlassRight",  size = Vector3.new(GLASS_THICKNESS, TANK_SIZE.Y, TANK_SIZE.Z), pos = Vector3.new(TANK_SIZE.X/2, TANK_SIZE.Y/2 + 1, 0) },
}

for _, def in ipairs(wallDefs) do
	local wall = Instance.new("Part")
	wall.Name = def.name
	wall.Size = def.size
	wall.Position = def.pos
	wall.Color = GLASS_COLOR
	wall.Material = GLASS_MATERIAL
	wall.Transparency = GLASS_TRANSPARENCY
	wall.Anchored = true
	wall.CanCollide = true
	wall.TopSurface = Enum.SurfaceType.Smooth
	wall.BottomSurface = Enum.SurfaceType.Smooth
	wall.Reflectance = 0.15
	wall.Parent = tank
end

-- Water volume (visual tinted block inside tank)
local water = Instance.new("Part")
water.Name = "WaterVolume"
water.Size = Vector3.new(TANK_SIZE.X - GLASS_THICKNESS * 2, TANK_SIZE.Y - 2, TANK_SIZE.Z - GLASS_THICKNESS * 2)
water.Position = Vector3.new(0, TANK_SIZE.Y/2, 0)
water.Color = WATER_COLOR
water.Material = Enum.Material.Glass
water.Transparency = 0.85
water.Anchored = true
water.CanCollide = false
water.CastShadow = false
water.Parent = tank

-- Water surface shimmer (thin neon part on top of water)
local surface = Instance.new("Part")
surface.Name = "WaterSurface"
surface.Size = Vector3.new(TANK_SIZE.X - GLASS_THICKNESS * 2, 0.1, TANK_SIZE.Z - GLASS_THICKNESS * 2)
surface.Position = Vector3.new(0, TANK_SIZE.Y - 0.5, 0)
surface.Color = Color3.fromRGB(140, 210, 235)
surface.Material = Enum.Material.Neon
surface.Transparency = 0.8
surface.Anchored = true
surface.CanCollide = false
surface.CastShadow = false
surface.Parent = tank

----------------------------------------------------------------------
-- CREATURE PLACEMENT SLOTS (invisible anchor points inside tank)
----------------------------------------------------------------------
local slotPositions = {
	Vector3.new(-12, 5, -8),
	Vector3.new(-4, 4, 6),
	Vector3.new(6, 6, -4),
	Vector3.new(14, 3, 8),
	Vector3.new(-8, 7, 2),
	Vector3.new(10, 5, -10),
}

local slotsFolder = Instance.new("Folder")
slotsFolder.Name = "CreatureSlots"
slotsFolder.Parent = tank

for i, pos in ipairs(slotPositions) do
	local slot = Instance.new("Part")
	slot.Name = "Slot" .. i
	slot.Size = Vector3.new(1, 1, 1)
	slot.Position = pos
	slot.Transparency = 1
	slot.Anchored = true
	slot.CanCollide = false
	slot.Parent = slotsFolder
	slot:SetAttribute("SlotIndex", i)
	slot:SetAttribute("Occupied", false)
	slot:SetAttribute("CreatureId", "")
end

----------------------------------------------------------------------
-- DECORATIVE ELEMENTS (rocks, coral)
----------------------------------------------------------------------
local decoFolder = Instance.new("Folder")
decoFolder.Name = "Decorations"
decoFolder.Parent = tank

-- Rocks along the substrate
local rockDefs = {
	{ pos = Vector3.new(-15, 1.5, -10), size = Vector3.new(4, 3, 3.5) },
	{ pos = Vector3.new(12, 1.8, 8), size = Vector3.new(3.5, 3.6, 3) },
	{ pos = Vector3.new(-6, 1.2, 12), size = Vector3.new(2.5, 2.4, 2.8) },
	{ pos = Vector3.new(16, 1, -12), size = Vector3.new(2, 2, 2.5) },
}
for i, rd in ipairs(rockDefs) do
	local rock = Instance.new("Part")
	rock.Name = "Rock" .. i
	rock.Shape = Enum.PartType.Ball
	rock.Size = rd.size
	rock.Position = rd.pos
	rock.Color = ROCK_COLOR
	rock.Material = Enum.Material.Slate
	rock.Anchored = true
	rock.CanCollide = true
	rock.Parent = decoFolder
end

-- Coral pieces
local coralDefs = {
	{ pos = Vector3.new(-14, 2.5, 6), size = Vector3.new(1.5, 4, 1.5), colorIdx = 1 },
	{ pos = Vector3.new(8, 2, -8), size = Vector3.new(2, 5, 2), colorIdx = 2 },
	{ pos = Vector3.new(-2, 2, 10), size = Vector3.new(1, 3, 1), colorIdx = 3 },
	{ pos = Vector3.new(15, 2.5, 2), size = Vector3.new(1.8, 4.5, 1.8), colorIdx = 4 },
	{ pos = Vector3.new(-10, 2, -6), size = Vector3.new(1.2, 3.5, 1.2), colorIdx = 1 },
}
for i, cd in ipairs(coralDefs) do
	local coral = Instance.new("Part")
	coral.Name = "Coral" .. i
	coral.Size = cd.size
	coral.Position = cd.pos
	coral.Color = CORAL_COLORS[cd.colorIdx]
	coral.Material = Enum.Material.SmoothPlastic
	coral.Anchored = true
	coral.CanCollide = false
	coral.Parent = decoFolder
end

----------------------------------------------------------------------
-- AMBIENT LIGHTING RIG (underwater glow)
----------------------------------------------------------------------
local lightFolder = Instance.new("Folder")
lightFolder.Name = "AmbientLights"
lightFolder.Parent = tank

-- Main overhead light (soft blue)
local overheadMount = Instance.new("Part")
overheadMount.Name = "OverheadMount"
overheadMount.Size = Vector3.new(1, 1, 1)
overheadMount.Position = Vector3.new(0, TANK_SIZE.Y + 2, 0)
overheadMount.Transparency = 1
overheadMount.Anchored = true
overheadMount.CanCollide = false
overheadMount.Parent = lightFolder

local overhead = Instance.new("PointLight")
overhead.Name = "OverheadLight"
overhead.Color = Color3.fromRGB(120, 200, 240)
overhead.Brightness = 1.2
overhead.Range = 50
overhead.Parent = overheadMount

-- Accent lights along tank floor (warm caustic feel)
local accentPositions = {
	Vector3.new(-10, 1.5, 0),
	Vector3.new(10, 1.5, 0),
	Vector3.new(0, 1.5, -10),
	Vector3.new(0, 1.5, 10),
}
for i, ap in ipairs(accentPositions) do
	local mount = Instance.new("Part")
	mount.Name = "AccentMount" .. i
	mount.Size = Vector3.new(0.5, 0.5, 0.5)
	mount.Position = ap
	mount.Transparency = 1
	mount.Anchored = true
	mount.CanCollide = false
	mount.Parent = lightFolder

	local accent = Instance.new("PointLight")
	accent.Name = "AccentLight" .. i
	accent.Color = Color3.fromRGB(100, 220, 180)
	accent.Brightness = 0.5
	accent.Range = 20
	accent.Parent = mount
end

----------------------------------------------------------------------
-- PEARL COLLECTION POINT (where players claim idle pearls)
----------------------------------------------------------------------
local pearlPoint = Instance.new("Part")
pearlPoint.Name = "PearlCollectionPoint"
pearlPoint.Shape = Enum.PartType.Cylinder
pearlPoint.Size = Vector3.new(1, 4, 4)
pearlPoint.CFrame = CFrame.new(Vector3.new(0, 0.5, -20)) * CFrame.Angles(0, 0, math.pi / 2)
pearlPoint.Color = Color3.fromRGB(240, 230, 200)
pearlPoint.Material = Enum.Material.SmoothPlastic
pearlPoint.Anchored = true
pearlPoint.CanCollide = true
pearlPoint.Reflectance = 0.3
pearlPoint.Parent = template

local pearlPrompt = Instance.new("ProximityPrompt")
pearlPrompt.ActionText = "Collect Pearls"
pearlPrompt.ObjectText = "Pearl Basin"
pearlPrompt.HoldDuration = 0
pearlPrompt.MaxActivationDistance = 12
pearlPrompt.Parent = pearlPoint

-- Pearl glow
local pearlGlow = Instance.new("PointLight")
pearlGlow.Color = Color3.fromRGB(255, 240, 200)
pearlGlow.Brightness = 0.8
pearlGlow.Range = 10
pearlGlow.Parent = pearlPoint

----------------------------------------------------------------------
-- SPAWN POINT (where player appears in aquarium)
----------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "AquariumSpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, -30)
spawn.Color = Color3.fromRGB(200, 220, 240)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Anchored = true
spawn.CanCollide = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = template

----------------------------------------------------------------------
-- GLOBAL LIGHTING (atmospheric underwater feel)
----------------------------------------------------------------------
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(140, 190, 220)
atmosphere.Decay = Color3.fromRGB(100, 160, 200)
atmosphere.Glare = 0
atmosphere.Haze = 2
atmosphere.Name = "AquariumAtmosphere"
atmosphere.Parent = template

local bloom = Instance.new("BloomEffect")
bloom.Name = "AquariumBloom"
bloom.Intensity = 0.4
bloom.Size = 30
bloom.Threshold = 0.9
bloom.Parent = template

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "AquariumCC"
colorCorrection.Brightness = 0.02
colorCorrection.Contrast = 0.08
colorCorrection.Saturation = 0.15
colorCorrection.TintColor = Color3.fromRGB(200, 230, 255)
colorCorrection.Parent = template

----------------------------------------------------------------------
-- DECORATION ANCHOR POINTS (for future cosmetic placement)
----------------------------------------------------------------------
local anchorsFolder = Instance.new("Folder")
anchorsFolder.Name = "DecorationAnchors"
anchorsFolder.Parent = template

local anchorPositions = {
	Vector3.new(-30, 0.5, -10),
	Vector3.new(-30, 0.5, 10),
	Vector3.new(30, 0.5, -10),
	Vector3.new(30, 0.5, 10),
	Vector3.new(-25, 0.5, 0),
	Vector3.new(25, 0.5, 0),
}
for i, apos in ipairs(anchorPositions) do
	local anchor = Instance.new("Part")
	anchor.Name = "DecoAnchor" .. i
	anchor.Size = Vector3.new(2, 0.2, 2)
	anchor.Position = apos
	anchor.Transparency = 0.8
	anchor.Color = Color3.fromRGB(160, 200, 180)
	anchor.Material = Enum.Material.Neon
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Parent = anchorsFolder
	anchor:SetAttribute("AnchorIndex", i)
	anchor:SetAttribute("HasDecoration", false)
end

----------------------------------------------------------------------
-- FINALIZE
----------------------------------------------------------------------
tank.Parent = template
template.PrimaryPart = floor
template.Parent = ServerStorage

-- Also place a preview copy in Workspace for immediate visual feedback
local preview = template:Clone()
preview.Name = "AquariumTemplate_Preview"
preview.Parent = Workspace

print("=== AquariumTemplate built successfully ===")
print("Template saved to ServerStorage.AquariumTemplate")
print("Preview placed in Workspace.AquariumTemplate_Preview")
print(string.format("  Tank size: %dx%dx%d studs", TANK_SIZE.X, TANK_SIZE.Y, TANK_SIZE.Z))
print(string.format("  Creature slots: %d", #slotPositions))
print(string.format("  Decoration anchors: %d", #anchorPositions))
