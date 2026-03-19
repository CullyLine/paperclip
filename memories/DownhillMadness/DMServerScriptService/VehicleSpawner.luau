--[[
	VehicleSpawner — Spawns, locks, unlocks, teleports, and cleans up vehicles.

	ModuleScript required by RoundController.

	API:
	  .spawnVehicles(players) → { SpawnedVehicle }
	  .lockAll()              — anchor all vehicles
	  .unlockAll()            — unanchor + set network ownership
	  .cleanup()              — destroy all vehicles
	  .teleportVehicle(vehicle, cframe) — safe teleport with physics reset
	  .anchorVehicle(vehicle, anchored) — anchor/unanchor entire vehicle
	  .resetVehicle(vehicle)  — zero all velocity
	  .getVehicleForPlayer(player) → SpawnedVehicle?
	  .getActiveVehicles() → { SpawnedVehicle }
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

----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------

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

local function getChassisFromVehicle(vehicle: Model): BasePart?
	local body = vehicle:FindFirstChild("Body")
	if body then
		local ch = body:FindFirstChild("Chassis") or body.PrimaryPart
		if ch then return ch end
		for _, child in body:GetChildren() do
			if child:IsA("BasePart") then return child end
		end
	end
	return vehicle.PrimaryPart
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
	local seat = vehicle:FindFirstChild("DriverSeat")
		or vehicle:FindFirstChild("VehicleSeat")
	if seat then return seat end
	for _, desc in vehicle:GetDescendants() do
		if desc:IsA("Seat") or desc:IsA("VehicleSeat") then
			return desc
		end
	end
	return nil
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

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

	for i, plr in players do
		if i > #spawnPoints then break end
		if not plr:IsDescendantOf(Players) then continue end

		local spawnPoint = spawnPoints[i]
		local vehicle = template:Clone()
		vehicle.Name = "Vehicle_" .. plr.Name

		local bodyModel = vehicle:FindFirstChild("Body") :: Model?
		local chassis = bodyModel and getChassisFromVehicle(vehicle) :: BasePart?
		local seat = findSeat(vehicle)

		if not chassis or not seat then
			warn("[VehicleSpawner] Vehicle missing Chassis or seat for " .. plr.Name)
			vehicle:Destroy()
			continue
		end

		if bodyModel then
			bodyModel.PrimaryPart = chassis
			weldBodyParts(bodyModel)
		end
		vehicle.PrimaryPart = chassis

		local spawnCF = spawnPoint.CFrame * CFrame.new(0, 2, 0)
		vehicle:PivotTo(spawnCF)

		chassis.Anchored = true
		vehicle.Parent = workspace

		if not plr.Character or not plr.Character:FindFirstChildOfClass("Humanoid") then
			plr:LoadCharacter()
			task.wait(0.5)
		end

		local character = plr.Character
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

		table.insert(activeVehicles, {
			model = vehicle,
			player = plr,
			chassis = chassis,
			seat = seat,
		})
	end

	return activeVehicles
end

function VehicleSpawner.lockAll()
	for _, sv in activeVehicles do
		if sv.chassis and sv.chassis.Parent then
			VehicleSpawner.anchorVehicle(sv.model, true)
		end
	end
end

function VehicleSpawner.unlockAll()
	for _, sv in activeVehicles do
		local vehicle = sv.model
		if not vehicle or not vehicle.Parent then continue end

		local chassis = getChassisFromVehicle(vehicle)
		if not chassis then continue end
		sv.chassis = chassis

		VehicleSpawner.anchorVehicle(vehicle, false)
		VehicleSpawner.resetVehicle(vehicle)

		if sv.player and sv.player:IsDescendantOf(Players) then
			local plr = sv.player
			task.defer(function()
				pcall(function()
					chassis:SetNetworkOwner(plr)
				end)
			end)
		end
	end
end

--- Teleport a vehicle safely: anchor → move → reset velocity → unanchor.
function VehicleSpawner.teleportVehicle(vehicle: Model, targetCF: CFrame)
	local chassis = getChassisFromVehicle(vehicle)
	if not chassis then return end

	VehicleSpawner.anchorVehicle(vehicle, true)
	task.wait() -- let anchor propagate

	vehicle:PivotTo(targetCF)

	task.wait() -- let position propagate

	VehicleSpawner.resetVehicle(vehicle)
	VehicleSpawner.anchorVehicle(vehicle, false)

	-- Restore network ownership to the player who owns this vehicle
	for _, sv in activeVehicles do
		if sv.model == vehicle and sv.player and sv.player:IsDescendantOf(Players) then
			task.defer(function()
				pcall(function()
					chassis:SetNetworkOwner(sv.player)
				end)
			end)
			break
		end
	end
end

--- Anchor or unanchor the entire vehicle assembly.
function VehicleSpawner.anchorVehicle(vehicle: Model, anchored: boolean)
	local chassis = getChassisFromVehicle(vehicle)
	if chassis then
		chassis.Anchored = anchored
	end
end

--- Zero out all linear and angular velocity on the vehicle.
function VehicleSpawner.resetVehicle(vehicle: Model)
	local chassis = getChassisFromVehicle(vehicle)
	if not chassis then return end
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

function VehicleSpawner.getVehicleForPlayer(plr: Player): SpawnedVehicle?
	for _, sv in activeVehicles do
		if sv.player == plr then return sv end
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
