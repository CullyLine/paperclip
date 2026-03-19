--[[
	DamageReplication.server — Receives damage reports from owning clients,
	validates them, applies health changes to the authoritative vehicle
	model, and broadcasts panel state changes to all other clients.

	RemoteEvents:
	  DamageReport   (client → server): { panelName, damage, impactSpeed }
	  DamageBroadcast (server → all clients): { vehicleName, panelName, newHealth, destroyed }
	  PanelDetached  (server → all clients): { vehicleName, panelName, impulseDir }

	Rate-limited per player at ~15 Hz to prevent spam.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMRep = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local DownhillConfig = require(DMRep:WaitForChild("DownhillConfig"))
local DamageSystem = require(DMRep:WaitForChild("DamageSystem"))

local MIN_INTERVAL = 1 / 15

----------------------------------------------------------------
-- RemoteEvent setup
----------------------------------------------------------------

local function ensureRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local damageReportEvent = ensureRemoteEvent("DamageReport")
local damageBroadcastEvent = ensureRemoteEvent("DamageBroadcast")
local panelDetachedEvent = ensureRemoteEvent("PanelDetached")

local lastDamageTime: { [number]: number } = {}

----------------------------------------------------------------
-- Panel detach (server-side): unanchor, apply impulse, schedule destroy
----------------------------------------------------------------

local function detachPanel(vehicle: Model, panelName: string, cfg: any)
	local panelsModel = vehicle:FindFirstChild("BodyPanels")
	if not panelsModel then return end

	local panel = panelsModel:FindFirstChild(panelName)
	if not panel or not panel:IsA("BasePart") then return end

	for _, child in panel:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			child:Destroy()
		end
	end

	panel.CanCollide = true
	panel.Anchored = false
	panel.Massless = false

	local impulseDir = (panel.Position - vehicle.PrimaryPart.Position).Unit
		+ Vector3.new(0, 0.5, 0)
	panel:ApplyImpulse(impulseDir * cfg.panelDetachImpulse)
	panel:ApplyAngularImpulse(Vector3.new(
		math.random() * 20 - 10,
		math.random() * 20 - 10,
		math.random() * 20 - 10
	))

	panelDetachedEvent:FireAllClients({
		vehicleName = vehicle.Name,
		panelName = panelName,
		impulseDir = { impulseDir.X, impulseDir.Y, impulseDir.Z },
	})

	task.delay(cfg.panelFadeTime, function()
		if panel and panel.Parent then
			panel:Destroy()
		end
	end)
end

----------------------------------------------------------------
-- Windshield shatter (server-side): make transparent + break pieces
----------------------------------------------------------------

local function shatterWindshield(vehicle: Model)
	local panelsModel = vehicle:FindFirstChild("BodyPanels")
	if not panelsModel then return end

	local windshield = panelsModel:FindFirstChild("Windshield")
	if not windshield or not windshield:IsA("BasePart") then return end

	local shardCount = 6
	local shardSize = windshield.Size / Vector3.new(shardCount / 2, shardCount / 3, 1)

	for i = 1, shardCount do
		local shard = Instance.new("Part")
		shard.Size = shardSize
		shard.Color = Color3.fromRGB(150, 200, 255)
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.4
		shard.CanCollide = true
		shard.Anchored = false
		shard.Massless = false

		local scatter = Vector3.new(
			math.random() * windshield.Size.X - windshield.Size.X / 2,
			math.random() * windshield.Size.Y - windshield.Size.Y / 2,
			0
		)
		shard.CFrame = windshield.CFrame * CFrame.new(scatter)
		shard.Parent = workspace

		shard:ApplyImpulse(Vector3.new(
			math.random() * 30 - 15,
			math.random() * 20 + 10,
			math.random() * 30 - 15
		))

		task.delay(3, function()
			if shard and shard.Parent then
				shard:Destroy()
			end
		end)
	end

	for _, child in windshield:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			child:Destroy()
		end
	end

	windshield:Destroy()
end

----------------------------------------------------------------
-- Incoming damage report handler
----------------------------------------------------------------

damageReportEvent.OnServerEvent:Connect(function(
	player: Player,
	data: { panelName: string, damage: number, impactSpeed: number }
)
	local now = tick()
	if lastDamageTime[player.UserId] and (now - lastDamageTime[player.UserId]) < MIN_INTERVAL then
		return
	end
	lastDamageTime[player.UserId] = now

	if typeof(data) ~= "table" then return end
	if type(data.panelName) ~= "string" then return end
	if type(data.damage) ~= "number" then return end
	if type(data.impactSpeed) ~= "number" then return end

	local vehicle = workspace:FindFirstChild("Vehicle_" .. player.Name)
	if not vehicle then return end
	if vehicle:GetAttribute("OwnerId") ~= player.UserId then return end

	local vehicleId = vehicle:GetAttribute("VehicleId") or "all_rounder"
	local cfg = DownhillConfig.forVehicle(vehicleId)

	if not DamageSystem.validateDamageReport(data.panelName, data.damage, data.impactSpeed, cfg) then
		return
	end

	local panelsModel = vehicle:FindFirstChild("BodyPanels")
	if not panelsModel then return end

	local panel = panelsModel:FindFirstChild(data.panelName)
	if not panel or not panel:IsA("BasePart") then return end

	local currentHealth = panel:GetAttribute("Health") or 0
	if currentHealth <= 0 then return end

	local newHealth = math.max(currentHealth - data.damage, 0)
	panel:SetAttribute("Health", newHealth)

	local destroyed = newHealth <= 0

	damageBroadcastEvent:FireAllClients({
		vehicleName = vehicle.Name,
		panelName = data.panelName,
		newHealth = newHealth,
		maxHealth = panel:GetAttribute("MaxHealth") or 100,
		destroyed = destroyed,
	})

	if destroyed then
		local isWindshield = data.panelName == "Windshield"
		if isWindshield then
			shatterWindshield(vehicle)
		else
			detachPanel(vehicle, data.panelName, cfg)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastDamageTime[player.UserId] = nil
end)

print("[DamageReplication] Initialized")
