--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║          DialoguePro — Thornwood Village Demo                ║
    ╚══════════════════════════════════════════════════════════════════╝

    This script builds "Thornwood Village" — a fantasy village
    with 7 NPCs that demonstrate every feature of the DialoguePro.

    ── OPTION A: Play the published demo ──────────────────────────────

    Open the demo place directly in Roblox Studio and hit Play:
    https://www.roblox.com/games/TODO_PLACE_ID/DialoguePro-Demo

    You can edit anything in the place — it's your copy.

    ── OPTION B: Build the demo in your own place ─────────────────────

    Want to add the demo village to an existing place, or start fresh?

    Method 1 — Command Bar (quickest):
      1. Make sure the DialoguePro model is in ReplicatedStorage
      2. Open View → Command Bar
      3. Paste this entire script into the Command Bar
      4. Press Enter — the village builds instantly in Workspace

    Method 2 — ServerScriptService:
      1. Make sure the DialoguePro model is in ReplicatedStorage
      2. Create a new Script in ServerScriptService
      3. Paste this entire script into it
      4. Hit Play — the village builds itself
      5. Hit Stop — the village stays in Workspace
      6. Delete this script afterward (it only needs to run once)

    ── AFTER BUILDING ─────────────────────────────────────────────────

    To wire up the NPC dialogues:
      1. Open StarterPlayer → StarterPlayerScripts
      2. Create a new LocalScript
      3. Paste the contents of TemplateSetup.local.luau into it
      4. Hit Play and walk up to any NPC — press E to talk!

    ── WHAT GETS BUILT ────────────────────────────────────────────────

      - Green terrain ground + stone paths
      - 6 buildings (Town Hall, Forge, Market, Tavern, Guard Tower, Wizard Tower)
      - Decorations (bench, campfire, lanterns, scattered trees)
      - Dense double-ring forest barrier around the village
      - 7 NPCs using Retro Noob model from Roblox store (in Workspace.NPCs)
      - SpawnLocation at the village entrance
      - Atmospheric lighting
]]

------------------------------------------------------------------------
-- PRE-FLIGHT: Ensure the DialoguePro model is in ReplicatedStorage
------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not ReplicatedStorage:FindFirstChild("DialoguePro") then
    warn("─────────────────────────────────────────────────────────────")
    warn("  DialoguePro model not found in ReplicatedStorage!")
    warn("")
    warn("  Please insert it first:")
    warn("    1. Open the Toolbox (View → Toolbox)")
    warn("    2. Search for 'DialoguePro'")
    warn("    3. Click to insert it into ReplicatedStorage")
    warn("")
    warn("  Or drag DialoguePro.rbxmx into ReplicatedStorage.")
    warn("─────────────────────────────────────────────────────────────")
end

------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------

local function makePart(props)
    local part = Instance.new("Part")
    part.Anchored = true
    part.Size = props.Size or Vector3.new(4, 4, 4)
    part.Position = props.Position or Vector3.new(0, 0, 0)
    part.Color = props.Color or Color3.fromRGB(128, 128, 128)
    part.Material = props.Material or Enum.Material.SmoothPlastic
    part.Name = props.Name or "Part"
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth

    if props.Shape then
        part.Shape = props.Shape
    end
    if props.Transparency then
        part.Transparency = props.Transparency
    end
    if props.CFrame then
        part.CFrame = props.CFrame
    end
    part.Parent = props.Parent or workspace
    return part
end

local function makeModel(name, parent)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent or workspace
    return model
end

local function makeTree(position, trunkHeight, canopySize, parent)
    trunkHeight = trunkHeight or 8
    canopySize = canopySize or 6

    local tree = makeModel("Tree", parent)

    local trunk = makePart({
        Name = "Trunk",
        Size = Vector3.new(2, trunkHeight, 2),
        Position = position + Vector3.new(0, trunkHeight / 2, 0),
        Color = Color3.fromRGB(101, 67, 33),
        Material = Enum.Material.Wood,
        Parent = tree,
    })

    makePart({
        Name = "Canopy",
        Size = Vector3.new(canopySize, canopySize * 0.8, canopySize),
        Position = position + Vector3.new(0, trunkHeight + canopySize * 0.3, 0),
        Color = Color3.fromRGB(34, 120, 34),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        Parent = tree,
    })

    tree.PrimaryPart = trunk
    return tree
end

local function makePineTree(position, height, parent)
    height = height or 14
    local tree = makeModel("PineTree", parent)

    makePart({
        Name = "Trunk",
        Size = Vector3.new(1.5, height * 0.4, 1.5),
        Position = position + Vector3.new(0, height * 0.2, 0),
        Color = Color3.fromRGB(101, 67, 33),
        Material = Enum.Material.Wood,
        Parent = tree,
    })

    for i = 1, 3 do
        local layerSize = (4 - i) * 3
        local layerY = position.Y + height * 0.3 + (i - 1) * (height * 0.2)
        makePart({
            Name = "Foliage" .. i,
            Size = Vector3.new(layerSize, height * 0.25, layerSize),
            Position = Vector3.new(position.X, layerY, position.Z),
            Color = Color3.fromRGB(20, 90 + i * 10, 20),
            Material = Enum.Material.Grass,
            Shape = Enum.PartType.Ball,
            Parent = tree,
        })
    end

    return tree
end

local function makeBuilding(config, parent)
    local building = makeModel(config.name, parent)

    makePart({
        Name = "Floor",
        Size = Vector3.new(config.width, 0.5, config.depth),
        Position = config.position + Vector3.new(0, 0.25, 0),
        Color = config.floorColor or Color3.fromRGB(139, 119, 101),
        Material = Enum.Material.Wood,
        Parent = building,
    })

    local wallHeight = config.wallHeight or 12
    local wallColor = config.wallColor or Color3.fromRGB(200, 190, 170)
    local wallMaterial = config.wallMaterial or Enum.Material.Brick

    makePart({
        Name = "WallFrontLeft",
        Size = Vector3.new(config.width / 2 - 3, wallHeight, 0.6),
        Position = config.position + Vector3.new(-config.width / 4 - 1.5, wallHeight / 2, config.depth / 2),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })
    makePart({
        Name = "WallFrontRight",
        Size = Vector3.new(config.width / 2 - 3, wallHeight, 0.6),
        Position = config.position + Vector3.new(config.width / 4 + 1.5, wallHeight / 2, config.depth / 2),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })
    makePart({
        Name = "DoorHeader",
        Size = Vector3.new(6, wallHeight - 9, 0.6),
        Position = config.position + Vector3.new(0, 9 + (wallHeight - 9) / 2, config.depth / 2),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })

    makePart({
        Name = "WallBack",
        Size = Vector3.new(config.width, wallHeight, 0.6),
        Position = config.position + Vector3.new(0, wallHeight / 2, -config.depth / 2),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })

    makePart({
        Name = "WallLeft",
        Size = Vector3.new(0.6, wallHeight, config.depth),
        Position = config.position + Vector3.new(-config.width / 2, wallHeight / 2, 0),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })
    makePart({
        Name = "WallRight",
        Size = Vector3.new(0.6, wallHeight, config.depth),
        Position = config.position + Vector3.new(config.width / 2, wallHeight / 2, 0),
        Color = wallColor, Material = wallMaterial, Parent = building,
    })

    local roofColor = config.roofColor or Color3.fromRGB(139, 69, 19)
    makePart({
        Name = "Roof",
        Size = Vector3.new(config.width + 3, 1.2, config.depth + 3),
        Position = config.position + Vector3.new(0, wallHeight + 0.6, 0),
        Color = roofColor, Material = Enum.Material.Wood, Parent = building,
    })

    if config.signText then
        local sign = makePart({
            Name = "SignBoard",
            Size = Vector3.new(8, 2, 0.4),
            Position = config.position + Vector3.new(0, wallHeight - 1.5, config.depth / 2 + 0.6),
            Color = Color3.fromRGB(80, 50, 20),
            Material = Enum.Material.Wood,
            Parent = building,
        })
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Front
        sg.Parent = sign
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.Text = config.signText
        tl.TextColor3 = Color3.fromRGB(255, 230, 180)
        tl.TextScaled = true
        tl.Font = Enum.Font.Antique
        tl.Parent = sg
    end

    return building
end

local function makeNPC(name, position, bodyColor, facingDeg, parent, hats)
    local npc = Instance.new("Model")

    local function npcPart(partName, size, offset, color, extra)
        local p = Instance.new("Part")
        p.Name = partName
        p.Size = size
        p.CFrame = CFrame.new(offset)
        p.Anchored = true
        p.Color = color
        p.Material = Enum.Material.SmoothPlastic
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        if extra then
            for k, v in pairs(extra) do p[k] = v end
        end
        p.Parent = npc
        return p
    end

    local skinColor = Color3.fromRGB(234, 194, 157)
    local legColor = Color3.fromRGB(40, 40, 60)

    npcPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), skinColor, { Transparency = 1, CanCollide = false })
    npcPart("Torso",      Vector3.new(2, 2, 1),   Vector3.new(0, 3, 0),    bodyColor)
    npcPart("Left Arm",   Vector3.new(1, 2, 1),   Vector3.new(-1.5, 3, 0), bodyColor)
    npcPart("Right Arm",  Vector3.new(1, 2, 1),   Vector3.new(1.5, 3, 0),  bodyColor)
    npcPart("Left Leg",   Vector3.new(1, 2, 1),   Vector3.new(-0.5, 1, 0), legColor)
    npcPart("Right Leg",  Vector3.new(1, 2, 1),   Vector3.new(0.5, 1, 0),  legColor)

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 1, 1)
    head.CFrame = CFrame.new(0, 4.5, 0)
    head.Anchored = true
    head.Color = skinColor
    head.Material = Enum.Material.SmoothPlastic
    head.TopSurface = Enum.SurfaceType.Smooth
    head.BottomSurface = Enum.SurfaceType.Smooth
    head.Parent = npc

    local headMesh = Instance.new("SpecialMesh")
    headMesh.MeshType = Enum.MeshType.Head
    headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
    headMesh.Parent = head

    local face = Instance.new("Decal")
    face.Name = "face"
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    Instance.new("Humanoid", npc)
    npc.PrimaryPart = npc:FindFirstChild("HumanoidRootPart")
    npc.Name = name

    -- Hats (classic accessories via SpecialMesh)
    if hats then
        for _, hat in ipairs(hats) do
            local acc = Instance.new("Part")
            acc.Name = hat.name or "Hat"
            acc.Size = Vector3.new(1, 1, 1)
            acc.CFrame = CFrame.new(0, 5, 0)
            acc.Anchored = true
            acc.CanCollide = false
            acc.Color = hat.color or Color3.fromRGB(255, 255, 255)
            acc.Material = Enum.Material.SmoothPlastic
            acc.Parent = npc

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = hat.meshId
            mesh.TextureId = hat.textureId or ""
            mesh.Scale = hat.scale or Vector3.new(1, 1, 1)
            mesh.Offset = hat.offset or Vector3.new(0, 0, 0)
            mesh.Parent = acc
        end
    end

    -- Position and rotate
    local rot = CFrame.Angles(0, math.rad(facingDeg or 0), 0)
    npc:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)) * rot)

    -- Hide default Humanoid name display
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    npc.Parent = parent

    -- Name tag
    local bboard = Instance.new("BillboardGui")
    bboard.Name = "NameTag"
    bboard.Size = UDim2.new(0, 200, 0, 50)
    bboard.StudsOffset = Vector3.new(0, 3, 0)
    bboard.Adornee = head
    bboard.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = bboard

    return npc
end

------------------------------------------------------------------------
-- BUILD THE VILLAGE
------------------------------------------------------------------------

print("[DialoguePro Demo] Building Thornwood Village...")

local villageFolder = makeModel("ThornwoodVillage", workspace)
local npcsFolder = makeModel("NPCs", workspace)

-- Ground
makePart({
    Name = "Ground",
    Size = Vector3.new(600, 1, 600),
    Position = Vector3.new(0, -0.5, 0),
    Color = Color3.fromRGB(76, 132, 50),
    Material = Enum.Material.Grass,
    Parent = villageFolder,
})

------------------------------------------------------------------------
-- PATHS
------------------------------------------------------------------------

local pathColor = Color3.fromRGB(160, 145, 120)
local pathMat = Enum.Material.Slate

-- Main road: south gate to town hall (Z: 100 to -110)
makePart({
    Name = "MainRoad",
    Size = Vector3.new(8, 0.2, 220),
    Position = Vector3.new(0, 0.1, -5),
    Color = pathColor, Material = pathMat, Parent = villageFolder,
})

-- East branch to wizard tower
makePart({
    Name = "EastPath",
    Size = Vector3.new(160, 0.2, 7),
    Position = Vector3.new(85, 0.1, 0),
    Color = pathColor, Material = pathMat, Parent = villageFolder,
})

-- West branch to market
makePart({
    Name = "WestPath",
    Size = Vector3.new(70, 0.2, 7),
    Position = Vector3.new(-35, 0.1, 20),
    Color = pathColor, Material = pathMat, Parent = villageFolder,
})

-- Northwest spur to tavern
makePart({
    Name = "TavernPath",
    Size = Vector3.new(7, 0.2, 50),
    Position = Vector3.new(-55, 0.1, -50),
    Color = pathColor, Material = pathMat, Parent = villageFolder,
})

------------------------------------------------------------------------
-- BUILDINGS
------------------------------------------------------------------------

-- Town Hall (far north, center)
makeBuilding({
    name = "TownHall",
    position = Vector3.new(0, 0, -100),
    width = 26, depth = 20, wallHeight = 18,
    wallColor = Color3.fromRGB(210, 195, 170),
    roofColor = Color3.fromRGB(100, 50, 25),
    signText = "Town Hall",
}, villageFolder)

-- Blacksmith Forge (east side)
makeBuilding({
    name = "BlacksmithForge",
    position = Vector3.new(70, 0, 20),
    width = 18, depth = 16, wallHeight = 13,
    wallColor = Color3.fromRGB(140, 120, 100),
    roofColor = Color3.fromRGB(60, 30, 15),
    wallMaterial = Enum.Material.Cobblestone,
    signText = "Brok's Forge",
}, villageFolder)

-- Anvil outside forge
makePart({
    Name = "Anvil",
    Size = Vector3.new(3, 2, 2),
    Position = Vector3.new(70, 1, 30),
    Color = Color3.fromRGB(60, 60, 65),
    Material = Enum.Material.Metal,
    Parent = villageFolder,
})

-- Market Stall (west side, set back from path)
local market = makeModel("MarketStall", villageFolder)
makePart({
    Name = "Counter",
    Size = Vector3.new(14, 4, 4),
    Position = Vector3.new(-65, 2, 35),
    Color = Color3.fromRGB(160, 120, 60),
    Material = Enum.Material.Wood,
    Parent = market,
})
makePart({
    Name = "Awning",
    Size = Vector3.new(16, 0.4, 8),
    Position = Vector3.new(-65, 8, 35),
    Color = Color3.fromRGB(180, 40, 40),
    Material = Enum.Material.Fabric,
    Parent = market,
})
makePart({
    Name = "SupportLeft",
    Size = Vector3.new(0.6, 8, 0.6),
    Position = Vector3.new(-72, 4, 38),
    Color = Color3.fromRGB(101, 67, 33),
    Material = Enum.Material.Wood,
    Parent = market,
})
makePart({
    Name = "SupportRight",
    Size = Vector3.new(0.6, 8, 0.6),
    Position = Vector3.new(-58, 4, 38),
    Color = Color3.fromRGB(101, 67, 33),
    Material = Enum.Material.Wood,
    Parent = market,
})

-- Tavern / Inn (northwest)
makeBuilding({
    name = "ThornedRoseTavern",
    position = Vector3.new(-55, 0, -80),
    width = 22, depth = 18, wallHeight = 15,
    wallColor = Color3.fromRGB(180, 160, 130),
    roofColor = Color3.fromRGB(120, 55, 30),
    signText = "The Thorned Rose",
}, villageFolder)

-- Guard Tower (south entrance)
local guardTower = makeModel("GuardTower", villageFolder)
makePart({
    Name = "TowerBase",
    Size = Vector3.new(10, 20, 10),
    Position = Vector3.new(12, 10, 90),
    Color = Color3.fromRGB(160, 155, 145),
    Material = Enum.Material.Cobblestone,
    Parent = guardTower,
})
makePart({
    Name = "TowerTop",
    Size = Vector3.new(13, 1.2, 13),
    Position = Vector3.new(12, 20.6, 90),
    Color = Color3.fromRGB(130, 120, 110),
    Material = Enum.Material.Cobblestone,
    Parent = guardTower,
})
-- Gate arch
makePart({
    Name = "GateLeft",
    Size = Vector3.new(4, 12, 3),
    Position = Vector3.new(-6, 6, 90),
    Color = Color3.fromRGB(160, 155, 145),
    Material = Enum.Material.Cobblestone,
    Parent = guardTower,
})
makePart({
    Name = "GateRight",
    Size = Vector3.new(4, 12, 3),
    Position = Vector3.new(6, 6, 90),
    Color = Color3.fromRGB(160, 155, 145),
    Material = Enum.Material.Cobblestone,
    Parent = guardTower,
})
makePart({
    Name = "GateArch",
    Size = Vector3.new(16, 3, 3),
    Position = Vector3.new(0, 13.5, 90),
    Color = Color3.fromRGB(160, 155, 145),
    Material = Enum.Material.Cobblestone,
    Parent = guardTower,
})

-- Wizard Tower (far east)
local wizTower = makeModel("WizardTower", villageFolder)
makePart({
    Name = "TowerBase",
    Size = Vector3.new(14, 28, 14),
    Position = Vector3.new(165, 14, 0),
    Color = Color3.fromRGB(100, 85, 120),
    Material = Enum.Material.Cobblestone,
    Parent = wizTower,
})
makePart({
    Name = "TowerRoof",
    Size = Vector3.new(16, 10, 16),
    CFrame = CFrame.new(165, 34, 0),
    Color = Color3.fromRGB(60, 30, 80),
    Material = Enum.Material.Slate,
    Shape = Enum.PartType.Ball,
    Parent = wizTower,
})
makePart({
    Name = "Crystal",
    Size = Vector3.new(3, 5, 3),
    Position = Vector3.new(165, 42, 0),
    Color = Color3.fromRGB(150, 100, 255),
    Material = Enum.Material.Neon,
    Shape = Enum.PartType.Ball,
    Parent = wizTower,
})

------------------------------------------------------------------------
-- DECORATIONS
------------------------------------------------------------------------

-- Bench near town hall
makePart({
    Name = "Bench",
    Size = Vector3.new(7, 2, 2),
    Position = Vector3.new(-14, 1, -85),
    Color = Color3.fromRGB(120, 80, 40),
    Material = Enum.Material.Wood,
    Parent = villageFolder,
})

-- Trees scattered inside the village
local villageTrees = {
    Vector3.new(30, 0, -60),
    Vector3.new(-25, 0, 50),
    Vector3.new(50, 0, -40),
    Vector3.new(-80, 0, 50),
    Vector3.new(100, 0, 55),
    Vector3.new(-90, 0, -50),
    Vector3.new(40, 0, 50),
    Vector3.new(-20, 0, -30),
    Vector3.new(110, 0, -30),
    Vector3.new(-40, 0, 65),
}

for _, pos in ipairs(villageTrees) do
    if math.random() > 0.5 then
        makeTree(pos, 8 + math.random() * 5, 7 + math.random() * 3, villageFolder)
    else
        makePineTree(pos, 12 + math.random() * 6, villageFolder)
    end
end

-- Dense tree ring barrier (inner ring)
for angle = 0, 350, 12 do
    local rad = math.rad(angle)
    local dist = 200 + math.random() * 20
    local pos = Vector3.new(math.cos(rad) * dist, 0, math.sin(rad) * dist)
    if math.random() > 0.4 then
        makeTree(pos, 10 + math.random() * 6, 8 + math.random() * 4, villageFolder)
    else
        makePineTree(pos, 14 + math.random() * 6, villageFolder)
    end
end

-- Outer ring (thicker barrier)
for angle = 6, 354, 12 do
    local rad = math.rad(angle)
    local dist = 230 + math.random() * 15
    local pos = Vector3.new(math.cos(rad) * dist, 0, math.sin(rad) * dist)
    if math.random() > 0.5 then
        makeTree(pos, 12 + math.random() * 5, 9 + math.random() * 3, villageFolder)
    else
        makePineTree(pos, 16 + math.random() * 5, villageFolder)
    end
end

-- Lantern posts along main road
for _, z in ipairs({70, 40, 10, -20, -50, -80}) do
    for _, xSide in ipairs({-6, 6}) do
        local lantern = makeModel("Lantern", villageFolder)
        makePart({
            Name = "Pole",
            Size = Vector3.new(0.5, 9, 0.5),
            Position = Vector3.new(xSide, 4.5, z),
            Color = Color3.fromRGB(50, 45, 40),
            Material = Enum.Material.Metal,
            Parent = lantern,
        })
        makePart({
            Name = "Light",
            Size = Vector3.new(1.5, 1.5, 1.5),
            Position = Vector3.new(xSide, 9.5, z),
            Color = Color3.fromRGB(255, 200, 80),
            Material = Enum.Material.Neon,
            Parent = lantern,
        })
        local pl = Instance.new("PointLight")
        pl.Range = 30
        pl.Brightness = 0.8
        pl.Color = Color3.fromRGB(255, 200, 120)
        pl.Parent = lantern:FindFirstChild("Light")
    end
end

------------------------------------------------------------------------
-- SPAWN POINT
------------------------------------------------------------------------

local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.5, 110)
spawn.Anchored = true
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = Color3.fromRGB(76, 132, 50)
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.CanCollide = true
spawn.Parent = villageFolder

------------------------------------------------------------------------
-- NPCs
------------------------------------------------------------------------

-- Elder Maren — on the bench near Town Hall (facing south toward visitors)
makeNPC("Elder Maren", Vector3.new(-14, 0, -82),
    Color3.fromRGB(120, 90, 150), 180, npcsFolder)

-- Forge Master Brok — at the anvil outside the forge (facing south toward path)
-- Wears a classic top hat
makeNPC("Forge Master Brok", Vector3.new(70, 0, 32),
    Color3.fromRGB(160, 80, 40), 180, npcsFolder, {
    { name = "TopHat", meshId = "rbxassetid://1028713", textureId = "rbxassetid://1028712", scale = Vector3.new(1, 1, 1), offset = Vector3.new(0, 0.2, 0) },
})

-- Merchant Lira — behind the market counter (facing north toward the inn)
makeNPC("Merchant Lira", Vector3.new(-65, 0, 30),
    Color3.fromRGB(200, 60, 80), 0, npcsFolder)

-- Sage Thalindra — at the base of the wizard tower (facing west toward village)
-- Wears a crown
makeNPC("Sage Thalindra", Vector3.new(165, 0, 12),
    Color3.fromRGB(100, 60, 160), 90, npcsFolder, {
    { name = "Crown", meshId = "rbxassetid://20329976", textureId = "rbxassetid://20329918", scale = Vector3.new(1.1, 1.1, 1.1), offset = Vector3.new(0, 0.4, 0) },
})

-- Captain Aldric — at the gate (facing north, watching the road into village)
-- Wears a knight helmet
makeNPC("Captain Aldric", Vector3.new(0, 0, 80),
    Color3.fromRGB(60, 80, 130), 180, npcsFolder, {
    { name = "KnightHelmet", meshId = "rbxassetid://12209666", textureId = "rbxassetid://12209468", scale = Vector3.new(1, 1, 1), offset = Vector3.new(0, 0.1, 0) },
})

-- Innkeeper Mira — in front of the tavern (facing south toward the path)
makeNPC("Innkeeper Mira", Vector3.new(-55, 0, -62),
    Color3.fromRGB(180, 130, 70), 180, npcsFolder)

-- Pip — wandering near the west side (facing east toward the wizard tower)
-- Wears a classic baseball cap
makeNPC("Pip", Vector3.new(-85, 0, -15),
    Color3.fromRGB(255, 180, 100), -90, npcsFolder, {
    { name = "BaseballCap", meshId = "rbxassetid://1028526", textureId = "rbxassetid://1028520", scale = Vector3.new(1, 1, 1), offset = Vector3.new(0, 0.1, 0) },
})

------------------------------------------------------------------------
-- LIGHTING
------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 10
Lighting.GeographicLatitude = 40
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(40, 50, 60)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 100, 90)
Lighting.FogEnd = 1200
Lighting.FogColor = Color3.fromRGB(180, 200, 210)

local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.3
atmo.Offset = 0.25
atmo.Color = Color3.fromRGB(200, 210, 220)
atmo.Decay = Color3.fromRGB(130, 140, 160)
atmo.Glare = 0.2
atmo.Haze = 1
atmo.Parent = Lighting

------------------------------------------------------------------------
-- DONE
------------------------------------------------------------------------

print("[DialoguePro Demo] Thornwood Village built!")
print("[DialoguePro Demo] 7 NPCs placed: Elder Maren, Forge Master Brok,")
print("  Merchant Lira, Sage Thalindra, Captain Aldric, Innkeeper Mira, Pip")
print("")
print("[DialoguePro Demo] Next steps:")
print("  1. Make sure DialoguePro model is in ReplicatedStorage")
print("  2. Paste TemplateSetup.local.luau into StarterPlayerScripts")
print("  3. Hit Play and talk to the NPCs!")
