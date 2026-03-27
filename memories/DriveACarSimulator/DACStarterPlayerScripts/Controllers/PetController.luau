--!strict
--[[
	Client-side pet following visuals.
	Local pets follow in V-formation with procedural bone animation.
	Remote players' pets are replicated via PetEquipSync and respect visibility/animation settings.
	Pets ride on the car roof during driving runs.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local PetAnimator = require(DAC:WaitForChild("PetAnimator"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local Controllers = script.Parent
local DrivingController = require(Controllers:WaitForChild("DrivingController"))

local PetController = {}

local petClientInitDone = false

local player = Players.LocalPlayer

type PetEntry = {
	model: Model,
	petId: string,
	rarity: string,
}

local localPets: { [string]: PetEntry } = {}
local localPetOrder: { string } = {}

local remotePets: { [number]: { [string]: PetEntry } } = {}
local remotePetOrder: { [number]: { string } } = {}

local settingOtherPets = true
local settingOtherPetAnimations = true

local wasInRun = false
local petsMoving = false
local idleSinceClock: number = os.clock()
local petsAreSitting = false

local FACE_MOVE_THRESHOLD = 0.12
local SIT_IDLE_SECONDS = 15

-- Wider V: more lateral + deeper rows; base offset = first pet behind the player.
local FORM_BASE_BACK = 4
local V_LATERAL_SPACING = 4.5
local V_BACK_SPACING = 3
local FLYING_PET_HEIGHT = 4
local PET_LERP_SPEED = 8
local BOB_AMPLITUDE = 0.5
local BOB_SPEED = 2

local HOP_HEIGHT = 1.8
local HOP_FREQ = 3.5
local GROUND_IDLE_BOB = 0.08

local RAYCAST_DOWN_ORIGIN_OFFSET = 10
local RAYCAST_DOWN_DISTANCE = 60
local raycastParams: RaycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {}

local ROOF_Y_OFFSET = 2
local ROOF_LATERAL_SPACING = 2

local function getPetTemplatesFolder(): Folder?
	local inRS = ReplicatedStorage:FindFirstChild("PetModels")
	if inRS and inRS:IsA("Folder") then
		return inRS
	end
	local inWS = workspace:FindFirstChild("PetModels")
	if inWS and inWS:IsA("Folder") then
		return inWS
	end
	return nil
end

local function getActivePetsFolder(): Instance
	local folder = workspace:FindFirstChild("ActivePets")
	if folder then
		return folder
	end
	return workspace
end

local function getPetLocomotion(petId: string): string
	local def = PetConfig.Pets[petId]
	if def and def.locomotion then
		return def.locomotion
	end
	return "ground"
end

local function updateRaycastFilter()
	local ignore: { Instance } = {}
	local activePets = workspace:FindFirstChild("ActivePets")
	if activePets then
		table.insert(ignore, activePets)
	end
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	raycastParams.FilterDescendantsInstances = ignore
end

local function getGroundY(worldPos: Vector3): number?
	local origin = worldPos + Vector3.new(0, RAYCAST_DOWN_ORIGIN_OFFSET, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0), raycastParams)
	if result then
		return result.Position.Y
	end
	return nil
end

local function getFormationOffset(index: number, petCount: number): (number, number)
	if index == 0 then
		return 0, 0
	end
	local row = math.ceil(index / 2)
	local side = if index % 2 == 1 then -1 else 1
	return side * row * V_LATERAL_SPACING, row * V_BACK_SPACING
end

local function clonePetModel(templateName: string, instanceName: string): Model?
	local petFolder = getPetTemplatesFolder()
	if not petFolder then
		return nil
	end
	local template = petFolder:FindFirstChild(templateName)
	if not template then
		return nil
	end
	local petInstance = template:Clone()
	petInstance.Name = instanceName
	-- Anchor every part: unanchored assemblies fall with gravity and fight PivotTo each frame.
	for _, desc in petInstance:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
		end
	end
	petInstance.Parent = getActivePetsFolder()
	return petInstance
end

local function destroyPetEntry(uid: string, entry: PetEntry)
	VFXFacade.petOrbitGlow(uid, nil, nil, "unequip")
	PetAnimator.stop(entry.model)
	entry.model:Destroy()
end

local function chooseAnimForState(isMoving: boolean, isRoofRiding: boolean, isSitting: boolean, locomotion: string): string
	if isRoofRiding then
		return "float"
	end
	if isMoving then
		return if locomotion == "ground" then "hop" else "walk"
	end
	return if isSitting then "sit" else "idle"
end

local function updateLocalPetPositions(dt: number)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local petCount = 0
	for _ in localPets do
		petCount += 1
	end
	if petCount == 0 then
		return
	end

	local inRun = DrivingController.isInRun()
	local justEnteredRun = inRun and not wasInRun
	local justExitedRun = not inRun and wasInRun
	wasInRun = inRun

	local isRoofRiding = false
	local carPrimary: BasePart? = nil
	if inRun then
		local carModel = character:FindFirstChild("Car") :: Model?
		if carModel and carModel:IsA("Model") and carModel.PrimaryPart then
			carPrimary = carModel.PrimaryPart
			isRoofRiding = true
		end
	end

	local currentPos = root.Position
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local horizontalVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local velocityMoving = horizontalVel.Magnitude > 0.35
	local inputMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.06
	petsMoving = velocityMoving or inputMoving
	if justEnteredRun or justExitedRun then
		petsMoving = true
	end

	if petsMoving then
		idleSinceClock = os.clock()
		petsAreSitting = false
	elseif not petsAreSitting and (os.clock() - idleSinceClock >= SIT_IDLE_SECONDS) then
		petsAreSitting = true
	end

	updateRaycastFilter()
	local time = os.clock()
	local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatLook.Magnitude > 1e-3 then
		flatLook = flatLook.Unit
	else
		flatLook = root.CFrame.LookVector
	end

	local index = 0
	for _, uid in localPetOrder do
		local entry = localPets[uid]
		if not entry then
			continue
		end

		local model = entry.model
		if not model.PrimaryPart then
			index += 1
			continue
		end

		local locomotion = getPetLocomotion(entry.petId)
		local isGround = locomotion == "ground"
		local desiredAnim = chooseAnimForState(petsMoving, isRoofRiding, petsAreSitting, locomotion)

		local targetPos: Vector3
		if isRoofRiding and carPrimary then
			local lateralOff, _ = getFormationOffset(index, petCount)
			lateralOff *= (ROOF_LATERAL_SPACING / V_LATERAL_SPACING)
			targetPos = carPrimary.Position + Vector3.new(lateralOff, ROOF_Y_OFFSET, 0)
		else
			local lateralOff, backOff = getFormationOffset(index, petCount)
			local behind = root.CFrame.LookVector * -1
			local right = root.CFrame.RightVector
			local flatTarget = currentPos
				+ behind * (FORM_BASE_BACK + backOff)
				+ right * lateralOff

			if isGround then
				local groundY = getGroundY(flatTarget) or currentPos.Y
				local _, petSize = model:GetBoundingBox()
				targetPos = Vector3.new(flatTarget.X, groundY + petSize.Y * 0.5, flatTarget.Z)
			else
				targetPos = flatTarget + Vector3.new(0, FLYING_PET_HEIGHT, 0)
			end
		end

		local verticalOffset: number
		if isRoofRiding then
			verticalOffset = 0
		elseif isGround then
			if petsMoving then
				local hopCycle = (time * HOP_FREQ + index * 1.3) % (2 * math.pi)
				verticalOffset = math.abs(math.sin(hopCycle)) * HOP_HEIGHT
			elseif petsAreSitting then
				verticalOffset = math.sin(time * BOB_SPEED * 0.4 + index) * GROUND_IDLE_BOB - 0.3
			else
				verticalOffset = math.sin(time * BOB_SPEED * 0.6 + index) * GROUND_IDLE_BOB
			end
		else
			local bobAmp = if petsAreSitting then BOB_AMPLITUDE * 0.15 else BOB_AMPLITUDE
			local bobSpd = if petsAreSitting then BOB_SPEED * 0.4 else BOB_SPEED
			verticalOffset = math.sin(time * bobSpd + index) * bobAmp
		end
		local targetPosWithBob = targetPos + Vector3.new(0, verticalOffset, 0)

		local currentCF = model:GetPivot()
		local lerpedPos = currentCF.Position:Lerp(targetPosWithBob, math.min(1, PET_LERP_SPEED * dt))

		local moveFlat = Vector3.new(lerpedPos.X - currentCF.Position.X, 0, lerpedPos.Z - currentCF.Position.Z)
		local lookTarget: Vector3
		if moveFlat.Magnitude > FACE_MOVE_THRESHOLD then
			lookTarget = lerpedPos + moveFlat.Unit * 5
		else
			lookTarget = lerpedPos + flatLook * 5
		end
		local lookCF = CFrame.lookAt(lerpedPos, lookTarget)

		model:PivotTo(lookCF)

		if PetAnimator.getAnimName(model) ~= desiredAnim then
			PetAnimator.setAnim(model, desiredAnim)
		end

		index += 1
	end
end

local function getOwnerRoot(userId: number): BasePart?
	local ownerPlayer = Players:GetPlayerByUserId(userId)
	if not ownerPlayer then
		return nil
	end
	local character = ownerPlayer.Character
	if not character or not character.Parent then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function updateRemotePetPositions(dt: number)
	if not settingOtherPets then
		return
	end

	local camera = workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero

	local time = os.clock()

	for userId, pets in remotePets do
		local ownerRoot = getOwnerRoot(userId)
		if not ownerRoot then
			continue
		end

		local order = remotePetOrder[userId]
		if not order then
			continue
		end

		local ownerPos = ownerRoot.Position
		local distToCamera = (ownerPos - cameraPos).Magnitude
		local beyondLOD = distToCamera > PetAnimator.LOD_DISTANCE

		local petCount = 0
		for _ in pets do
			petCount += 1
		end

		local index = 0
		for _, uid in order do
			local entry = pets[uid]
			if not entry then
				continue
			end
			local model = entry.model
			if not model.PrimaryPart then
				index += 1
				continue
			end

			local locomotion = getPetLocomotion(entry.petId)
			local isGround = locomotion == "ground"

			local lateralOff, backOff = getFormationOffset(index, petCount)
			local behind = ownerRoot.CFrame.LookVector * -1
			local right = ownerRoot.CFrame.RightVector
			local flatTarget = ownerPos
				+ behind * (FORM_BASE_BACK + backOff)
				+ right * lateralOff

			local targetPos: Vector3
			if isGround then
				local groundY = getGroundY(flatTarget) or ownerPos.Y
				local _, petSize = model:GetBoundingBox()
				targetPos = Vector3.new(flatTarget.X, groundY + petSize.Y * 0.5, flatTarget.Z)
			else
				targetPos = flatTarget + Vector3.new(0, FLYING_PET_HEIGHT, 0)
			end

			local remoteVel = ownerRoot.AssemblyLinearVelocity
			local remoteMoving = Vector3.new(remoteVel.X, 0, remoteVel.Z).Magnitude > 0.35
			local vertY: number
			if isGround then
				if remoteMoving then
					local hopCycle = (time * HOP_FREQ + index * 1.3 + userId * 0.7) % (2 * math.pi)
					vertY = math.abs(math.sin(hopCycle)) * HOP_HEIGHT
				else
					vertY = math.sin(time * BOB_SPEED * 0.6 + index) * GROUND_IDLE_BOB
				end
			else
				vertY = math.sin(time * BOB_SPEED + index + userId * 0.1) * BOB_AMPLITUDE
			end
			local targetWithBob = targetPos + Vector3.new(0, vertY, 0)

			local currentCF = model:GetPivot()
			local lerpedPos = currentCF.Position:Lerp(targetWithBob, math.min(1, PET_LERP_SPEED * dt))

			local rFlat = ownerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
			if rFlat.Magnitude > 1e-3 then
				rFlat = rFlat.Unit
			else
				rFlat = ownerRoot.CFrame.LookVector
			end
			local moveFlat = Vector3.new(lerpedPos.X - currentCF.Position.X, 0, lerpedPos.Z - currentCF.Position.Z)
			local lookTarget
			if moveFlat.Magnitude > FACE_MOVE_THRESHOLD then
				lookTarget = lerpedPos + moveFlat.Unit * 5
			else
				lookTarget = lerpedPos + rFlat * 5
			end
			model:PivotTo(CFrame.lookAt(lerpedPos, lookTarget))

			local shouldFullAnim = settingOtherPetAnimations and not beyondLOD
			if PetAnimator.isActive(model) then
				PetAnimator.setFullAnimation(model, shouldFullAnim)
			end

			index += 1
		end
	end
end

local function onRenderStep(dt: number)
	updateLocalPetPositions(dt)
	updateRemotePetPositions(dt)
end

function PetController.spawnPet(petUid: string, petId: string, rarity: string?)
	if localPets[petUid] then
		return
	end

	local templateName = PetConfig.getPetTemplateName(petId)
	if not templateName then
		return
	end

	local petInstance = clonePetModel(templateName, petUid)
	if not petInstance then
		return
	end

	local r = if type(rarity) == "string" then rarity else "common"
	localPets[petUid] = {
		model = petInstance,
		petId = petId,
		rarity = r,
	}
	table.insert(localPetOrder, petUid)
	VFXFacade.petOrbitGlow(petUid, petInstance, r, "equip")
	PetAnimator.start(petInstance, "idle", true)
end

function PetController.despawnPet(petUid: string)
	local entry = localPets[petUid]
	if entry then
		destroyPetEntry(petUid, entry)
		localPets[petUid] = nil
		for i, uid in localPetOrder do
			if uid == petUid then
				table.remove(localPetOrder, i)
				break
			end
		end
	end
end

function PetController.clearAll()
	for uid, entry in localPets do
		destroyPetEntry(uid, entry)
	end
	table.clear(localPets)
	table.clear(localPetOrder)
end

local function clearRemotePlayerPets(userId: number)
	local pets = remotePets[userId]
	if pets then
		for uid, entry in pets do
			destroyPetEntry(uid, entry)
		end
	end
	remotePets[userId] = nil
	remotePetOrder[userId] = nil
end

local function onPetEquipSync(ownerUserId: number, equippedList: { any })
	if ownerUserId == player.UserId then
		return
	end

	clearRemotePlayerPets(ownerUserId)

	if not settingOtherPets then
		return
	end

	if type(equippedList) ~= "table" or #equippedList == 0 then
		return
	end

	local newPets: { [string]: PetEntry } = {}
	local newOrder: { string } = {}
	local count = 0

	for _, info in equippedList do
		if count >= PetConfig.MAX_FOLLOWING then
			break
		end
		if type(info) ~= "table" then
			continue
		end
		local uid = info.uid
		local petId = info.id
		local rarity = info.rarity or "common"
		if type(uid) ~= "string" or type(petId) ~= "string" then
			continue
		end

		local templateName = PetConfig.getPetTemplateName(petId)
		if not templateName then
			continue
		end

		local instanceName = `remote_{ownerUserId}_{uid}`
		local petInstance = clonePetModel(templateName, instanceName)
		if not petInstance then
			continue
		end

		newPets[uid] = {
			model = petInstance,
			petId = petId,
			rarity = rarity,
		}
		table.insert(newOrder, uid)
		count += 1

		VFXFacade.petOrbitGlow(instanceName, petInstance, rarity, "equip")
		PetAnimator.start(petInstance, "idle", settingOtherPetAnimations)
	end

	if count > 0 then
		remotePets[ownerUserId] = newPets
		remotePetOrder[ownerUserId] = newOrder
	end
end

function PetController.applySettings(settings: { [string]: any })
	if type(settings) ~= "table" then
		return
	end

	local newOtherPets = if type(settings.otherPets) == "boolean" then settings.otherPets else true
	local newOtherPetAnims = if type(settings.otherPetAnimations) == "boolean" then settings.otherPetAnimations else true

	if not newOtherPets and settingOtherPets then
		for userId in remotePets do
			clearRemotePlayerPets(userId)
		end
	end

	settingOtherPets = newOtherPets
	settingOtherPetAnimations = newOtherPetAnims

	if settingOtherPets then
		for _, pets in remotePets do
			for _, entry in pets do
				PetAnimator.setFullAnimation(entry.model, settingOtherPetAnimations)
			end
		end
	end
end

function PetController.init()
	if petClientInitDone then
		return
	end
	petClientInitDone = true

	RunService.RenderStepped:Connect(onRenderStep)
	Remotes.getEvent("PetEquipSync").OnClientEvent:Connect(onPetEquipSync)

	Players.PlayerRemoving:Connect(function(leaving)
		clearRemotePlayerPets(leaving.UserId)
	end)
end

return PetController
