--!strict
--[[
	Run once in Roblox Studio (Command Bar or MCP execute_luau), Edit mode.

	- For each Model under ReplicatedStorage.CarModels["New cars"]:
	  - Clones DriveSeat + Primary from ReplicatedStorage.CarModels.delorean
	  - Places both at the Body mesh CFrame
	  - Strips legacy forces/movers from the cloned Primary subtree
	  - Sets Model.PrimaryPart to the new Primary
	  - Reparents the car to ReplicatedStorage.CarModels

	After success, delete the empty "New cars" container in Studio if you want.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FORCE_CLASS = {
	BodyForce = true,
	BodyGyro = true,
	BodyPosition = true,
	BodyVelocity = true,
	BodyAngularVelocity = true,
	VectorForce = true,
	AlignPosition = true,
	AlignOrientation = true,
	LinearVelocity = true,
	BodyMover = true,
}

local function stripForcesFromInstance(root: Instance)
	local toDestroy: { Instance } = {}
	for _, d in root:GetDescendants() do
		if FORCE_CLASS[d.ClassName] then
			table.insert(toDestroy, d)
		end
	end
	for _, d in toDestroy do
		d:Destroy()
	end
end

local function findIgnoreCase(parent: Instance, name: string): Instance?
	for _, ch in parent:GetChildren() do
		if string.lower(ch.Name) == string.lower(name) then
			return ch
		end
	end
	return nil
end

local function destroyAllNamedParts(model: Model, partName: string)
	local again = true
	while again do
		again = false
		for _, d in model:GetDescendants() do
			if d.Name == partName and (d:IsA("BasePart") or d:IsA("VehicleSeat")) then
				d:Destroy()
				again = true
				break
			end
		end
	end
end

local carModels = ReplicatedStorage:FindFirstChild("CarModels")
if not carModels or (not carModels:IsA("Folder") and not carModels:IsA("Model")) then
	warn("[migrate] ReplicatedStorage.CarModels (Folder or Model) not found")
	return
end

local delorean = carModels:FindFirstChild("delorean")
if not delorean then
	delorean = findIgnoreCase(carModels, "delorean")
end
if not delorean or not delorean:IsA("Model") then
	warn("[migrate] Template delorean (Model) not found under CarModels")
	return
end

local driveSeatSrc = delorean:FindFirstChild("DriveSeat", true)
if not driveSeatSrc then
	driveSeatSrc = delorean:FindFirstChildWhichIsA("VehicleSeat", true)
end
if not driveSeatSrc or not driveSeatSrc:IsA("BasePart") then
	warn("[migrate] delorean: need DriveSeat (BasePart/VehicleSeat)")
	return
end

local primarySrc = delorean:FindFirstChild("Primary", true)
if not primarySrc or not primarySrc:IsA("BasePart") then
	warn("[migrate] delorean: need Primary BasePart")
	return
end

local newCars = carModels:FindFirstChild("New cars")
if not newCars then
	newCars = findIgnoreCase(carModels, "New cars")
end
if not newCars then
	warn("[migrate] CarModels['New cars'] not found")
	return
end

local toMove: { Model } = {}
for _, ch in newCars:GetChildren() do
	if ch:IsA("Model") then
		table.insert(toMove, ch)
	end
end

if #toMove == 0 then
	warn("[migrate] No Model children under New cars")
	return
end

for _, car in toMove do
	local body = car:FindFirstChild("Body", true)
	if not body or not body:IsA("BasePart") then
		warn("[migrate] Skip " .. car.Name .. ": no Body BasePart")
	else
		local targetCF = body.CFrame

		destroyAllNamedParts(car, "DriveSeat")
		destroyAllNamedParts(car, "Primary")

		local newSeat = driveSeatSrc:Clone()
		newSeat.Parent = car
		newSeat.CFrame = targetCF

		local newPrimary = primarySrc:Clone()
		newPrimary.Parent = car
		newPrimary.CFrame = targetCF
		stripForcesFromInstance(newPrimary)

		car.PrimaryPart = newPrimary
		car.Parent = carModels
		print("[migrate] OK:", car.Name)
	end
end

print("[migrate] Done. Reparented", #toMove, "cars. You can delete empty 'New cars' if unused.")
