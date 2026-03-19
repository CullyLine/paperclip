--[[
	WheelReplication.server — Receives visual-wheel CFrame updates from
	the owning client and writes them to the replicated VisualWheels
	parts inside the vehicle model. Roblox replication distributes the
	CFrames to all other clients automatically.

	Rate-limited to ignore bursts faster than ~12 Hz per player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WHEEL_NAMES = { "WheelFL_Visual", "WheelFR_Visual", "WheelRL_Visual", "WheelRR_Visual" }
local MIN_INTERVAL = 1 / 12

local function ensureRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local wheelUpdateEvent = ensureRemoteEvent("WheelReplication")

local lastUpdateTime: { [number]: number } = {}

wheelUpdateEvent.OnServerEvent:Connect(function(player: Player, cframes: { CFrame })
	local now = tick()
	if lastUpdateTime[player.UserId] and (now - lastUpdateTime[player.UserId]) < MIN_INTERVAL then
		return
	end
	lastUpdateTime[player.UserId] = now

	if typeof(cframes) ~= "table" or #cframes ~= 4 then return end

	local vehicle = workspace:FindFirstChild("Vehicle_" .. player.Name)
	if not vehicle then return end

	if vehicle:GetAttribute("OwnerId") ~= player.UserId then return end

	local vwFolder = vehicle:FindFirstChild("VisualWheels")
	if not vwFolder then return end

	for i, name in WHEEL_NAMES do
		local part = vwFolder:FindFirstChild(name)
		if part and part:IsA("BasePart") and typeof(cframes[i]) == "CFrame" then
			part.CFrame = cframes[i]
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastUpdateTime[player.UserId] = nil
end)

print("[WheelReplication] Initialized")
