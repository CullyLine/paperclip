--!strict
--[[
	Resolve lobby / safe spawn CFrames under Workspace.Worlds for world id (POLA-628).
	Supports folder names matching WorldConfig ids; falls back to numeric order (e.g. "1") when present.
]]

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local WorldSpawnUtil = {}

local function firstBasePartUnder(inst: Instance): BasePart?
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

--[[
	Studio often groups LobbySpawn/Spawn as a Model or Folder with a Part inside.
	Prefer direct BasePart; else first child BasePart; else any descendant BasePart.
]]
local function basePartFromSpawnContainer(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	for _, ch in inst:GetChildren() do
		if ch:IsA("BasePart") then
			return ch
		end
	end
	return firstBasePartUnder(inst)
end

local function pickRandomSpawnFromFolder(folder: Instance): BasePart?
	local candidates: { BasePart } = {}
	for _, ch in folder:GetChildren() do
		if ch:IsA("BasePart") then
			table.insert(candidates, ch)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function preferredSpawnPart(worldModel: Instance): BasePart?
	local spawns = worldModel:FindFirstChild("Spawns")
	if spawns then
		local p = pickRandomSpawnFromFolder(spawns)
		if p then
			return p
		end
	end
	local lobby = worldModel:FindFirstChild("LobbySpawn")
	if lobby then
		local p = basePartFromSpawnContainer(lobby)
		if p then
			return p
		end
	end
	local spawn = worldModel:FindFirstChild("Spawn")
	if spawn then
		local p = basePartFromSpawnContainer(spawn)
		if p then
			return p
		end
	end
	return nil
end

local function resolveWorldModel(worldId: string): Instance?
	local worlds = Workspace:FindFirstChild("Worlds")
	if not worlds then
		return nil
	end
	local folderName = WorldConfig.getFolderName(worldId)
	local wm = worlds:FindFirstChild(folderName)
	if wm then
		return wm
	end
	local wm2 = worlds:FindFirstChild(worldId)
	if wm2 then
		return wm2
	end
	return nil
end

--[[
	Standing CFrame for the given world's lobby / highway entry (or nil if no geometry).
]]
function WorldSpawnUtil.getLobbyCFrame(worldId: string): CFrame?
	local wm = resolveWorldModel(worldId)
	if not wm then
		return nil
	end
	local part = preferredSpawnPart(wm)
	if part then
		return part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 2.5, 0)
	end
	if wm:IsA("Model") then
		local m = wm :: Model
		local pivot = m:GetPivot()
		local bp = firstBasePartUnder(m)
		if bp then
			return CFrame.new(pivot.Position.X, bp.Position.Y + 4, pivot.Position.Z)
		end
		return pivot * CFrame.new(0, 5, 0)
	end
	return nil
end

function WorldSpawnUtil.getStartZoneCFrame(worldId: string): CFrame?
	local wm = resolveWorldModel(worldId)
	if not wm then
		return nil
	end
	local startModel = wm:FindFirstChild("Start")
	if not startModel then
		return nil
	end
	for _, ch in startModel:GetChildren() do
		if ch:IsA("BasePart") then
			return ch.CFrame * CFrame.new(0, ch.Size.Y * 0.5 + 3, 0)
		end
	end
	return nil
end

function WorldSpawnUtil.teleportPlayerToStartZone(player: Player, worldId: string): boolean
	local cf = WorldSpawnUtil.getStartZoneCFrame(worldId)
	if not cf then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = cf
	return true
end

function WorldSpawnUtil.teleportPlayerToWorldLobby(player: Player, worldId: string): boolean
	local cf = WorldSpawnUtil.getLobbyCFrame(worldId)
	if not cf then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = cf
	return true
end

return WorldSpawnUtil
