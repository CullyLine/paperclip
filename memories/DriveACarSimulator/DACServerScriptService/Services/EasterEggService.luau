--!strict
--[[
	Spawns easter eggs from Config/EasterEggConfig, optional proximity discovery + persistence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local EasterEggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EasterEggConfig"))
local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local Remotes = require(DAC:WaitForChild("Remotes"))

type EggPlacement = typeof(EasterEggConfig.Placements[1])
type GalleryFrameT = typeof(EasterEggConfig.SecretGallery.frames[1])

local EasterEggService = {}

local PLACEHOLDER = "rbxassetid://0"
local DISCOVER_RADIUS = 26
local HEARTBEAT_INTERVAL = 0.4

-- First valid texture under ReplicatedStorage.Images (Board library) — used when imageId/imageKey are unset.
local cachedLibraryFallback: string? = nil

local trackedEggs: {{id: string, position: Vector3, radius: number, hint: string?, rarity: string?}} = {}

local lastDiscoveryCheck: { [number]: number } = {}

local function isPlaceholderAssetId(id: string?): boolean
	if not id or id == "" then
		return true
	end
	if id == PLACEHOLDER then
		return true
	end
	local n = string.match(id, "rbxassetid://(%d+)")
	if not n then
		return false
	end
	return tonumber(n) == 0
end

local function textureFromInstance(inst: Instance): string?
	if inst:IsA("Decal") or inst:IsA("Texture") then
		return inst.Texture
	end
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return inst.Image
	end
	return nil
end

-- "ReplicatedStorage.Images.Foo" → instance
local function resolveInstanceFromPath(path: string): Instance?
	local segments = string.split(path, ".")
	local inst: Instance? = nil
	for _, seg in segments do
		if inst == nil then
			if seg == "ReplicatedStorage" then
				inst = game:GetService("ReplicatedStorage")
			elseif seg == "Workspace" then
				inst = game:GetService("Workspace")
			else
				return nil
			end
		else
			local nextInst = inst:FindFirstChild(seg)
			if not nextInst then
				return nil
			end
			inst = nextInst
		end
	end
	return inst
end

local function resolveImageId(entry: { imageId: string, imageKey: string?, imageSource: string? }): string?
	local src = entry.imageSource
	if type(src) == "string" and src ~= "" then
		local node = resolveInstanceFromPath(src)
		if node then
			local t = textureFromInstance(node)
			if t and not isPlaceholderAssetId(t) then
				return t
			end
		end
	end
	if not isPlaceholderAssetId(entry.imageId) then
		return entry.imageId
	end
	local key = entry.imageKey
	if not key or key == "" then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Images")
	if not folder then
		return nil
	end
	local inst = folder:FindFirstChild(key)
	if not inst then
		return nil
	end
	return textureFromInstance(inst)
end

local function cacheFallbackFromImageLibrary()
	local folder = ReplicatedStorage:FindFirstChild("Images")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		local t = textureFromInstance(d)
		if t and not isPlaceholderAssetId(t) then
			cachedLibraryFallback = t
			return
		end
	end
end

local function resolveImageIdOrFallback(entry: { imageId: string, imageKey: string?, imageSource: string? }): string?
	local id = resolveImageId(entry)
	if id then
		return id
	end
	return cachedLibraryFallback
end

local function eulerToCFrame(deg: Vector3): CFrame
	return CFrame.Angles(math.rad(deg.X), math.rad(deg.Y), math.rad(deg.Z))
end

local function ensureEggFolder(parent: Instance): Folder
	local f = parent:FindFirstChild("EasterEggs")
	if f and f:IsA("Folder") then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = "EasterEggs"
	folder.Parent = parent
	return folder
end

local function applyBasePartProps(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.CastShadow = false
	p.Massless = true
end

local function createSurfaceImage(
	parent: BasePart,
	face: Enum.NormalId,
	imageId: string,
	sizeStuds: Vector2,
	framed: boolean
)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "EggSurface"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.LightInfluence = 1
	sg.AlwaysOnTop = false
	sg.ResetOnSpawn = false
	sg.Parent = parent

	local w = math.max(1, math.floor(sizeStuds.X * 20))
	local h = math.max(1, math.floor(sizeStuds.Y * 20))
	sg.CanvasSize = Vector2.new(w, h)

	if framed then
		local wrap = Instance.new("Frame")
		wrap.Name = "Frame"
		wrap.Size = UDim2.fromOffset(w, h)
		wrap.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
		wrap.BackgroundTransparency = 0.2
		wrap.BorderSizePixel = 0
		wrap.Parent = sg
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.8
		stroke.Color = Color3.fromRGB(180, 180, 200)
		stroke.Parent = wrap
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = wrap
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1, 0, 1, 0)
		img.Image = imageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = wrap
	else
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(w, h)
		img.Image = imageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = sg
	end
end

local function spawnBillboard(parent: Instance, cf: CFrame, imageId: string, sizeStuds: Vector2)
	local p = Instance.new("Part")
	p.Name = "EasterEggBillboard"
	p.Size = Vector3.new(0.4, 0.4, 0.4)
	p.Transparency = 1
	applyBasePartProps(p)
	p.CFrame = cf
	p.Parent = parent

	local bb = Instance.new("BillboardGui")
	bb.Name = "EggBillboard"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 1
	bb.Size = UDim2.new(0, math.max(32, math.floor(sizeStuds.X * 8)), 0, math.max(32, math.floor(sizeStuds.Y * 8)))
	bb.StudsOffset = Vector3.new(0, sizeStuds.Y * 0.05, 0)
	bb.ResetOnSpawn = false
	bb.Parent = p

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb
end

local function spawnDecal(parent: Instance, cf: CFrame, imageId: string, sizeStuds: Vector2)
	local p = Instance.new("Part")
	p.Name = "EasterEggDecal"
	local w = math.max(0.25, sizeStuds.X * 0.05)
	local h = math.max(0.25, sizeStuds.Y * 0.05)
	p.Size = Vector3.new(w, h, 0.15)
	applyBasePartProps(p)
	p.CFrame = cf
	p.Transparency = 1
	p.Parent = parent

	local d = Instance.new("Decal")
	d.Name = "EggDecal"
	d.Texture = imageId
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

local function spawnPosterLike(parent: Instance, cf: CFrame, imageId: string, sizeStuds: Vector2, displayType: string)
	local p = Instance.new("Part")
	p.Name = if displayType == "framed" then "EasterEggFramed" else "EasterEggPoster"
	local thickness = 0.15
	p.Size = Vector3.new(sizeStuds.X, sizeStuds.Y, thickness)
	applyBasePartProps(p)
	p.CFrame = cf
	p.Color = Color3.fromRGB(35, 35, 40)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent

	createSurfaceImage(p, Enum.NormalId.Front, imageId, sizeStuds, displayType == "framed")
end

local function trackEgg(id: string, worldPos: Vector3, entry: EggPlacement | GalleryFrameT)
	local e = entry :: any
	local hint = if type(e.hint) == "string" then e.hint :: string else nil
	local rarity = if type(e.rarity) == "string" then e.rarity :: string else "common"
	table.insert(trackedEggs, {
		id = id,
		position = worldPos,
		radius = DISCOVER_RADIUS,
		hint = hint,
		rarity = rarity,
	})
end

local function spawnWorldPlacement(worldModel: Model, entry: EggPlacement, imageId: string)
	local folder = ensureEggFolder(worldModel)
	local pivot = worldModel:GetPivot()
	local base = pivot * CFrame.new(entry.position) * eulerToCFrame(entry.rotation)

	if entry.displayType == "billboard" then
		spawnBillboard(folder, base, imageId, entry.size)
	elseif entry.displayType == "decal" then
		spawnDecal(folder, base, imageId, entry.size)
	else
		spawnPosterLike(folder, base, imageId, entry.size, entry.displayType)
	end
	trackEgg(entry.id, base.Position, entry)
end

local function buildGalleryRoom(config: any): Model
	local model = Instance.new("Model")
	model.Name = "EasterEggGallery"

	local cx, cy, cz = config.centerPosition.X, config.centerPosition.Y, config.centerPosition.Z
	local sx, sy, sz = config.interiorSize.X, config.interiorSize.Y, config.interiorSize.Z
	local t = 0.6
	local hx, hy, hz = sx / 2, sy / 2, sz / 2

	local function wall(name: string, size: Vector3, rel: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = true
		p.Material = Enum.Material.Concrete
		p.Color = Color3.fromRGB(55, 55, 62)
		p.Size = size
		p.CFrame = CFrame.new(cx, cy, cz) * CFrame.new(rel)
		p.Parent = model
	end

	wall("Floor", Vector3.new(sx + t * 2, t, sz + t * 2), Vector3.new(0, -hy - t / 2, 0))
	wall("Ceiling", Vector3.new(sx + t * 2, t, sz + t * 2), Vector3.new(0, hy + t / 2, 0))
	wall("WallNorth", Vector3.new(sx + t * 2, sy, t), Vector3.new(0, 0, -hz - t / 2))
	wall("WallSouth", Vector3.new(sx + t * 2, sy, t), Vector3.new(0, 0, hz + t / 2))
	wall("WallEast", Vector3.new(t, sy, sz + t * 2), Vector3.new(hx + t / 2, 0, 0))
	wall("WallWest", Vector3.new(t, sy, sz + t * 2), Vector3.new(-hx - t / 2, 0, 0))

	model:PivotTo(CFrame.new(cx, cy, cz))
	model.Parent = Workspace
	return model
end

local function spawnGalleryFrame(galleryModel: Model, frame: GalleryFrameT, imageId: string)
	local folder = ensureEggFolder(galleryModel)
	local roomCf = galleryModel:GetPivot()
	local base = roomCf * CFrame.new(frame.localPosition) * eulerToCFrame(frame.rotation)

	if frame.displayType == "billboard" then
		spawnBillboard(folder, base, imageId, frame.size)
	elseif frame.displayType == "decal" then
		spawnDecal(folder, base, imageId, frame.size)
	else
		spawnPosterLike(folder, base, imageId, frame.size, frame.displayType)
	end
	trackEgg(frame.id, base.Position, frame)
end

local function ensureDiscoveredMap(player: Player): { [string]: boolean }
	local data = DataManager.get(player)
	if not data then
		return {}
	end
	if type(data.discoveredEasterEggs) ~= "table" then
		data.discoveredEasterEggs = {}
	end
	return data.discoveredEasterEggs :: { [string]: boolean }
end

local function tickDiscovery(_dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local last = lastDiscoveryCheck[player.UserId] or 0
		if now - last < HEARTBEAT_INTERVAL then
			continue
		end
		lastDiscoveryCheck[player.UserId] = now

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		local disc = ensureDiscoveredMap(player)
		local data = DataManager.get(player)
		if not data then
			continue
		end

		local pos = hrp.Position
		for _, egg in trackedEggs do
			if disc[egg.id] then
				continue
			end
			if (pos - egg.position).Magnitude <= egg.radius then
				disc[egg.id] = true
				DataManager.save(player)
				Remotes.getEvent("EasterEggDiscovered"):FireClient(player, {
					id = egg.id,
					hint = egg.hint,
					rarity = egg.rarity,
				})
				Remotes.getEvent("DataUpdate"):FireClient(player, data)
			end
		end
	end
end

function EasterEggService.init()
	cacheFallbackFromImageLibrary()
	if not cachedLibraryFallback then
		warn(
			"[EasterEggService] No texture in ReplicatedStorage.Images — placeholders use rbxassetid://0 until imageKey/imageSource or library assets exist."
		)
	end

	local skippedNoTexture: { string } = {}
	local skippedNoWorld: { string } = {}

	local worldsRoot = Workspace:FindFirstChild("Worlds")
	if not worldsRoot then
		warn("[EasterEggService] Workspace.Worlds missing — world eggs skipped")
	else
		for _, entry in EasterEggConfig.Placements do
			local imageId = resolveImageIdOrFallback(entry)
			if not imageId then
				table.insert(skippedNoTexture, entry.id)
				continue
			end
			local worldModel = worldsRoot:FindFirstChild(entry.worldId)
			if not worldModel or not worldModel:IsA("Model") then
				table.insert(skippedNoWorld, `{entry.id} ({entry.worldId})`)
				continue
			end
			spawnWorldPlacement(worldModel :: Model, entry, imageId)
		end
	end

	local sg = EasterEggConfig.SecretGallery
	if sg.enabled then
		local galleryModel = buildGalleryRoom(sg)
		for _, frame in sg.frames do
			local imageId = resolveImageIdOrFallback(frame)
			if not imageId then
				table.insert(skippedNoTexture, "gallery:" .. frame.id)
				continue
			end
			spawnGalleryFrame(galleryModel, frame, imageId)
		end
	end

	if #skippedNoTexture > 0 then
		warn(
			`[EasterEggService] Skipped {#skippedNoTexture} placements (set imageKey / imageSource or imageId): {table.concat(skippedNoTexture, ", ")}`
		)
	end
	if #skippedNoWorld > 0 then
		-- Common in Studio before world models are placed; keep log level low.
		local msg = `[EasterEggService] Missing world models: {table.concat(skippedNoWorld, ", ")}`
		if RunService:IsStudio() then
			print(msg .. " (ok until Workspace.Worlds is populated)")
		else
			warn(msg)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		tickDiscovery(dt)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastDiscoveryCheck[player.UserId] = nil
	end)
end

return EasterEggService
