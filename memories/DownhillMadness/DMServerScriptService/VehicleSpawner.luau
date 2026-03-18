--[[
	VehicleSpawner — Spawns, locks, unlocks, and cleans up vehicles per round.

	ModuleScript required by RoundController.

	- Clones ReplicatedStorage.TemplateVehicle for each player
	- Welds all body parts to chassis (Polaris-style)
	- Places at VehicleSpawn1-16 on the start platform
	- Assigns network ownership to respective players
	- Seats players via Seat or VehicleSeat
	- Lock = Anchored chassis until GO signal
	- Cleans up all spawned vehicles on round end
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleSpawner = {}

type SpawnedVehicle = {
	model: Model,
	player: Player,
	chassis: BasePart,
	seat: Instance,
}

local activeVehicles: { SpawnedVehicle } = {}

local function getSpawnPoints(): { BasePart }
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return {} end

	local spawnsFolder = mapFolder:FindFirstChild("SpawnPoints")
	if not spawnsFolder then return {} end

	local points: { BasePart } = {}
	for i = 1, 16 do
		local spawn = spawnsFolder:FindFirstChild("VehicleSpawn" .. i)
		if spawn and spawn:IsA("BasePart") then
			table.insert(points, spawn)
		end
	end

	return points
end

local function getTemplate(): Model?
	return ReplicatedStorage:FindFirstChild("TemplateVehicle") :: Model?
end

local function weldBodyParts(bodyModel: Model)
	local primary = bodyModel.PrimaryPart or bodyModel:FindFirstChildWhichIsA("BasePart")
	if not primary then return end
	for _, part in bodyModel:GetDescendants() do
		if part:IsA("BasePart") and part ~= primary and not part:FindFirstChildOfClass("WeldConstraint") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.CanCollide = false
		end
	end
end

local function findSeat(vehicle: Model): Instance?
	local seat = vehicle:FindFirstChild("VehicleSeat")
		or vehicle:FindFirstChild("DriverSeat")
	if seat then return seat end
	for _, desc in vehicle:GetDescendants() do
		if desc:IsA("VehicleSeat") or desc:IsA("Seat") then
			return desc
		end
	end
	return nil
end

function VehicleSpawner.spawnVehicles(players: { Player }): { SpawnedVehicle }
	VehicleSpawner.cleanup()

	local template = getTemplate()
	if not template then
		warn("[VehicleSpawner] TemplateVehicle not found in ReplicatedStorage")
		return {}
	end

	local spawnPoints = getSpawnPoints()
	if #spawnPoints == 0 then
		warn("[VehicleSpawner] No spawn points found under Map.SpawnPoints")
		return {}
	end

	for i, player in players do
		if i > #spawnPoints then break end
		if not player:IsDescendantOf(Players) then continue end

		local spawnPoint = spawnPoints[i]
		local vehicle = template:Clone()
		vehicle.Name = "Vehicle_" .. player.Name

		-- DM uses VehicleSpawner + ChassisClient only; Polaris ChassisController
		-- calls SetNetworkOwner on sit, which errors when chassis is still Anchored.
		local chassisController = vehicle:FindFirstChild("ChassisController")
		if chassisController then
			chassisController:Destroy()
		end

		local bodyModel = vehicle:FindFirstChild("Body") :: Model?
		local chassis = bodyModel and (bodyModel:FindFirstChild("Chassis") or bodyModel.PrimaryPart or bodyModel:FindFirstChildWhichIsA("BasePart")) :: BasePart?
		local seat = findSeat(vehicle)

		if not chassis or not seat then
			warn("[VehicleSpawner] Vehicle missing Chassis or seat for " .. player.Name)
			vehicle:Destroy()
			continue
		end

		if bodyModel then
			bodyModel.PrimaryPart = chassis
			weldBodyParts(bodyModel)
		end
		-- So client can fall back to vehicle.PrimaryPart for root
		vehicle.PrimaryPart = chassis

		local spawnCF = spawnPoint.CFrame * CFrame.new(0, 3, 0)
		vehicle:PivotTo(spawnCF)

		chassis.Anchored = true

		vehicle.Parent = workspace

		if not player.Character or not player.Character:FindFirstChildOfClass("Humanoid") then
			player:LoadCharacter()
			task.wait(0.5)
		end

		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				rootPart.CFrame = spawnCF + Vector3.new(0, 5, 0)
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				seat:Sit(humanoid)
			end
		end

		local spawned: SpawnedVehicle = {
			model = vehicle,
			player = player,
			chassis = chassis,
			seat = seat,
		}
		table.insert(activeVehicles, spawned)
	end

	return activeVehicles
end

function VehicleSpawner.lockAll()
	for _, sv in activeVehicles do
		if sv.chassis and sv.chassis.Parent then
			sv.chassis.Anchored = true
		end
	end
end

local function getChassisFromVehicle(vehicle: Model): BasePart?
	local body = vehicle:FindFirstChild("Body")
	if not body then return vehicle.PrimaryPart end
	local ch = body:FindFirstChild("Chassis") or body:FindFirstChild("CarBody") or body.PrimaryPart
	if ch then return ch end
	for _, child in body:GetChildren() do
		if child:IsA("BasePart") then return child end
	end
	return vehicle.PrimaryPart
end

function VehicleSpawner.unlockAll()
	for _, sv in activeVehicles do
		local vehicle = sv.model
		if not vehicle or not vehicle.Parent then continue end
		-- Resolve chassis from model (same logic as client) so we unanchor the part client uses as root
		local chassis = getChassisFromVehicle(vehicle)
		if not chassis then continue end
		chassis.Anchored = false
		sv.chassis = chassis

		-- Defer SetNetworkOwner so the unanchor is processed first (avoids
		-- "cannot be called on Anchored parts" error).
		if sv.player and sv.player:IsDescendantOf(Players) then
			local player = sv.player
			task.defer(function()
				pcall(function()
					chassis:SetNetworkOwner(player)
				end)
			end)
		end
	end
end

function VehicleSpawner.getVehicleForPlayer(player: Player): SpawnedVehicle?
	for _, sv in activeVehicles do
		if sv.player == player then
			return sv
		end
	end
	return nil
end

function VehicleSpawner.getActiveVehicles(): { SpawnedVehicle }
	return activeVehicles
end

function VehicleSpawner.cleanup()
	for _, sv in activeVehicles do
		if sv.model and sv.model.Parent then
			sv.model:Destroy()
		end
	end
	activeVehicles = {}
end

return VehicleSpawner
