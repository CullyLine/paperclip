--[[
	VehicleSpawner — Spawns, locks, unlocks, teleports, and cleans up vehicles.

	M1: Spawns the correct vehicle template per player based on their
	PreRound vehicle selection (passed via playerVehicles map).

	API:
	  .spawnVehicles(players, playerVehicles) → { SpawnedVehicle }
	  .lockAll()
	  .unlockAll()
	  .cleanup()
	  .teleportVehicle(vehicle, cframe)
	  .anchorVehicle(vehicle, anchored)
	  .resetVehicle(vehicle)
	  .getVehicleForPlayer(player) → SpawnedVehicle?
	  .getActiveVehicles() → { SpawnedVehicle }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMRep = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local DownhillConfig = require(DMRep:WaitForChild("DownhillConfig"))

local VehicleSpawner = {}

type SpawnedVehicle = {
	model: Model,
	player: Player,
	chassis: BasePart,
	seat: Instance,
	vehicleId: string,
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

local function getTemplate(vehicleId: string): Model?
	local templates = ReplicatedStorage:FindFirstChild("VehicleTemplates")
	if templates then
		return templates:FindFirstChild("Template_" .. vehicleId) :: Model?
	end
	-- Legacy fallback
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
-- Replicated visual wheels (seen by all clients)
----------------------------------------------------------------

local function createReplicatedVisualWheels(vehicle: Model, vehicleId: string)
	local cfg = DownhillConfig.forVehicle(vehicleId)
	local wheelsModel = vehicle:FindFirstChild("Wheels")
	if not wheelsModel then return end

	local folder = Instance.new("Folder")
	folder.Name = "VisualWheels"

	for _, def in cfg.wheels do
		local templatePart = wheelsModel:FindFirstChild(def.name)
		if not templatePart or not templatePart:IsA("BasePart") then continue end

		local vis = templatePart:Clone()
		vis.Name = def.name .. "_Visual"
		vis.Transparency = 0
		vis.Anchored = true
		vis.CanCollide = false
		vis.CanQuery = false
		vis.Massless = true

		for _, child in vis:GetChildren() do
			if child:IsA("WeldConstraint") or child:IsA("Weld") then
				child:Destroy()
			end
		end

		vis.Parent = folder
	end

	folder.Parent = vehicle
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function VehicleSpawner.spawnVehicles(players: { Player }, playerVehicles: { [number]: string }?): { SpawnedVehicle }
	VehicleSpawner.cleanup()

	local spawnPoints = getSpawnPoints()
	if #spawnPoints == 0 then
		warn("[VehicleSpawner] No spawn points found under Map.SpawnPoints")
		return {}
	end

	local defaultVehicleId = "all_rounder"

	for i, plr in players do
		if i > #spawnPoints then break end
		if not plr:IsDescendantOf(Players) then continue end

		local vehicleId = defaultVehicleId
		if playerVehicles and playerVehicles[plr.UserId] then
			vehicleId = playerVehicles[plr.UserId]
		end

		local template = getTemplate(vehicleId)
		if not template then
			warn("[VehicleSpawner] Template not found for vehicle: " .. vehicleId .. ", falling back to default")
			template = getTemplate(defaultVehicleId)
		end
		if not template then
			warn("[VehicleSpawner] No template found at all for " .. plr.Name)
			continue
		end

		local spawnPoint = spawnPoints[i]
		local vehicle = template:Clone()
		vehicle.Name = "Vehicle_" .. plr.Name
		vehicle:SetAttribute("VehicleId", vehicleId)
		vehicle:SetAttribute("OwnerId", plr.UserId)

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

		createReplicatedVisualWheels(vehicle, vehicleId)

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
			vehicleId = vehicleId,
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

function VehicleSpawner.teleportVehicle(vehicle: Model, targetCF: CFrame)
	local chassis = getChassisFromVehicle(vehicle)
	if not chassis then return end

	VehicleSpawner.anchorVehicle(vehicle, true)
	task.wait()

	vehicle:PivotTo(targetCF)

	task.wait()

	VehicleSpawner.resetVehicle(vehicle)
	VehicleSpawner.anchorVehicle(vehicle, false)

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

function VehicleSpawner.anchorVehicle(vehicle: Model, anchored: boolean)
	local chassis = getChassisFromVehicle(vehicle)
	if chassis then
		chassis.Anchored = anchored
	end
end

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
