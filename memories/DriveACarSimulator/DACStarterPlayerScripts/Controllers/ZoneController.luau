--!strict
--[[
	Client-side zone detection. Checks if the player's character is inside
	invisible zone parts under Workspace.Worlds.*.Interact.Zones.*.
	When entering a zone, fires a callback; when leaving, fires another.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local ZoneController = {}

type ZoneCallbacks = {
	onEnter: (zoneName: string, zonePart: BasePart) -> (),
	onLeave: (zoneName: string) -> (),
}

local callbacks: ZoneCallbacks? = nil
local activeZone: string? = nil
local heartbeatConn: RBXScriptConnection? = nil

local ZONE_NAMES = {
	"Training",
	"RebirthUpgrades",
	"Fuse",
	"Daily",
	"EggShop",
	"Worlds",
}

local function getCharacterRoot(): BasePart?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isInsidePart(point: Vector3, part: BasePart): boolean
	local cf = part.CFrame
	local size = part.Size
	local localPos = cf:PointToObjectSpace(point)
	return math.abs(localPos.X) <= size.X / 2
		and math.abs(localPos.Y) <= size.Y / 2
		and math.abs(localPos.Z) <= size.Z / 2
end

local function findAllZoneParts(): { { name: string, part: BasePart } }
	local results: { { name: string, part: BasePart } } = {}
	local worlds = game:GetService("Workspace"):FindFirstChild("Worlds")
	if not worlds then
		return results
	end

	for _, worldFolder in worlds:GetChildren() do
		local interact = worldFolder:FindFirstChild("Interact")
		if not interact then
			continue
		end
		local zones = interact:FindFirstChild("Zones")
		if not zones then
			continue
		end
		for _, zoneName in ZONE_NAMES do
			local part = zones:FindFirstChild(zoneName)
			if part and part:IsA("BasePart") then
				table.insert(results, { name = zoneName, part = part })
			end
		end
	end

	return results
end

local cachedZoneParts: { { name: string, part: BasePart } }? = nil
local lastCacheTime = 0
local CACHE_REFRESH_INTERVAL = 5.0

local function getZoneParts(): { { name: string, part: BasePart } }
	local now = os.clock()
	if not cachedZoneParts or (now - lastCacheTime) > CACHE_REFRESH_INTERVAL then
		cachedZoneParts = findAllZoneParts()
		lastCacheTime = now
	end
	return cachedZoneParts :: any
end

function ZoneController.registerCallbacks(cbs: ZoneCallbacks)
	callbacks = cbs
end

function ZoneController.getActiveZone(): string?
	return activeZone
end

function ZoneController.init()
	heartbeatConn = RunService.Heartbeat:Connect(function()
		local root = getCharacterRoot()
		if not root then
			if activeZone and callbacks then
				callbacks.onLeave(activeZone)
				activeZone = nil
			end
			return
		end

		local pos = root.Position
		local zoneParts = getZoneParts()
		local insideZone: string? = nil

		local matchedPart: BasePart? = nil
		for _, entry in zoneParts do
			if isInsidePart(pos, entry.part) then
				insideZone = entry.name
				matchedPart = entry.part
				break
			end
		end

		if insideZone ~= activeZone then
			if activeZone and callbacks then
				callbacks.onLeave(activeZone)
			end

			activeZone = insideZone

			if activeZone and callbacks and matchedPart then
				callbacks.onEnter(activeZone, matchedPart)
			end
		end
	end)
end

function ZoneController.destroy()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if activeZone and callbacks then
		callbacks.onLeave(activeZone)
		activeZone = nil
	end
end

return ZoneController
