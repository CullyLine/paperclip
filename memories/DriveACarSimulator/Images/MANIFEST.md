# Drive a Car Simulator — Image Asset Manifest

> **CHECK `ReplicatedStorage.Images` FIRST** — The Board has gathered all
> pre-approved images into `ReplicatedStorage.Images` in Studio. Before
> creating, sourcing, or uploading any new images (decals, textures, UI assets,
> thumbnails, billboards, posters):
>
> 1. Browse `ReplicatedStorage.Images` — these assets are already uploaded and
>    TOS-approved on Roblox.
> 2. Only create/upload new images if nothing in that folder fits the need.
> 3. Re-using approved images saves upload time and keeps us TOS-safe.

**Design reference:** `ConceptArt/visual-style-guide.md`
**Easter egg placements:** See POLA-61 parent issue for Board easter egg request.

---

## Sourcing workflow (priority order)

### 1. ReplicatedStorage.Images (preferred)

Open Studio → `ReplicatedStorage` → `Images`. Each child is a **Decal** or
**ImageLabel** with a valid `rbxassetid://` already set. Browse by name, pick
the one that fits, and reference its asset ID in code.

No upload, no moderation wait, no credits needed — these are already live and
TOS-cleared.

### 2. Generate or source new (only when RS.Images has nothing suitable)

1. Create or source the image (Grok API, external tool, hand-drawn, etc.).
2. Upload to Roblox via Studio (Asset Manager → Images → Add) or the Open
   Cloud API.
3. Wait for moderation approval.
4. Copy the `rbxassetid://` ID into your code or config.
5. **Add a copy to `ReplicatedStorage.Images`** in Studio so future lookups
   find it there.

---

## How to reference images from code

### Decal (3D surface — floor, wall, ramp underside)

```lua
local decal = Instance.new("Decal")
decal.Texture = "rbxassetid://123456789"   -- paste ID from RS.Images
decal.Face = Enum.NormalId.Front           -- which face of the parent Part
decal.Parent = somePart
```

### Texture (tiling on 3D surface)

```lua
local tex = Instance.new("Texture")
tex.Texture = "rbxassetid://123456789"
tex.Face = Enum.NormalId.Top
tex.StudsPerTileU = 4
tex.StudsPerTileV = 4
tex.Parent = somePart
```

### ImageLabel (2D UI — panels, HUD, menus)

```lua
local img = Instance.new("ImageLabel")
img.Image = "rbxassetid://123456789"
img.Size = UDim2.new(0, 100, 0, 100)
img.BackgroundTransparency = 1
img.ScaleType = Enum.ScaleType.Fit        -- Fit, Crop, Stretch, Tile
img.Parent = someFrame
```

### ImageButton (clickable image in UI)

```lua
local btn = Instance.new("ImageButton")
btn.Image = "rbxassetid://123456789"
btn.Size = UDim2.new(0, 64, 0, 64)
btn.BackgroundTransparency = 1
btn.Parent = someFrame
```

### SurfaceGui + ImageLabel (in-world poster / billboard)

```lua
local part = Instance.new("Part")
part.Size = Vector3.new(8, 6, 0.2)
part.Anchored = true
part.CanCollide = false
part.Parent = workspace

local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 50
sg.Parent = part

local poster = Instance.new("ImageLabel")
poster.Image = "rbxassetid://123456789"
poster.Size = UDim2.new(1, 0, 1, 0)
poster.BackgroundTransparency = 1
poster.ScaleType = Enum.ScaleType.Fit
poster.Parent = sg
```

### BillboardGui + ImageLabel (always-facing-camera image)

```lua
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.new(4, 0, 4, 0)
bb.StudsOffset = Vector3.new(0, 3, 0)
bb.Adornee = somePartOrAttachment
bb.Parent = somePartOrAttachment

local label = Instance.new("ImageLabel")
label.Image = "rbxassetid://123456789"
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Parent = bb
```

---

## Reading from ReplicatedStorage.Images at runtime

If you want to dynamically pick an image from the approved library at runtime:

```lua
local RS = game:GetService("ReplicatedStorage")
local imagesFolder = RS:FindFirstChild("Images")

-- Get a specific image by name
local function getImageId(name: string): string?
    if not imagesFolder then return nil end
    local obj = imagesFolder:FindFirstChild(name)
    if obj and obj:IsA("Decal") then
        return obj.Texture
    elseif obj and (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
        return obj.Image
    end
    return nil
end

-- List all available image names
local function listImageNames(): {string}
    if not imagesFolder then return {} end
    local names = {}
    for _, child in imagesFolder:GetChildren() do
        table.insert(names, child.Name)
    end
    return names
end
```

---

## Usage categories

| Category | Where used | Instance type |
|----------|-----------|---------------|
| UI icons / buttons | `DACStarterGui/` panels | `ImageLabel`, `ImageButton` |
| World decor | Highway billboards, building walls | `Decal`, `SurfaceGui` + `ImageLabel` |
| Easter eggs | Hidden posters, secret gallery | `SurfaceGui` + `ImageLabel`, `Decal` |
| Loading screen | `DACReplicatedFirst/LoadingScreen` | `ImageLabel` |
| Thumbnails / marketing | Game page, social media | External (not in-game) |
| Pet / egg / car textures | Model surfaces | `Decal`, `Texture` |
