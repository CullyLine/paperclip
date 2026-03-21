--!strict
--[[
	Client-side pet following visuals. Equipped pets orbit around the player in the lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local PetController = {}

local player = Players.LocalPlayer
local petModels: { [string]: Model } = {}
local petRarity: { [string]: string } = {}
local ORBIT_RADIUS = 6
local ORBIT_HEIGHT = 3
local ORBIT_SPEED = 1.5

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

local function updatePetPositions(_dt: number)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local center = root.Position + Vector3.new(0, ORBIT_HEIGHT, 0)
	local petCount = 0
	for _ in petModels do
		petCount += 1
	end

	if petCount == 0 then return end

	local angleStep = (2 * math.pi) / petCount
	local time = os.clock() * ORBIT_SPEED
	local index = 0

	for _, model in petModels do
		local angle = time + (index * angleStep)
		local x = math.cos(angle) * ORBIT_RADIUS
		local z = math.sin(angle) * ORBIT_RADIUS
		local bobY = math.sin(time * 2 + index) * 0.5

		local targetPos = center + Vector3.new(x, bobY, z)

		if model.PrimaryPart then
			local lookDir = (center - targetPos).Unit
			model:PivotTo(CFrame.lookAt(targetPos, targetPos + lookDir))
		end

		index += 1
	end
end

function PetController.spawnPet(petUid: string, petId: string, rarity: string?)
	if petModels[petUid] then return end

	local petFolder = getPetTemplatesFolder()
	if not petFolder then return end

	local templateName = PetConfig.getPetTemplateName(petId)
	if not templateName then return end

	local template = petFolder:FindFirstChild(templateName)
	if not template then return end

	local petInstance = template:Clone()
	petInstance.Name = petUid
	petInstance.Parent = workspace:FindFirstChild("ActivePets") or workspace
	petModels[petUid] = petInstance
	local r = if type(rarity) == "string" then rarity else "common"
	petRarity[petUid] = r
	VFXFacade.petOrbitGlow(petUid, petInstance, r, "equip")
end

function PetController.despawnPet(petUid: string)
	local model = petModels[petUid]
	if model then
		VFXFacade.petOrbitGlow(petUid, nil, nil, "unequip")
		model:Destroy()
		petModels[petUid] = nil
		petRarity[petUid] = nil
	end
end

function PetController.clearAll()
	for uid, model in petModels do
		VFXFacade.petOrbitGlow(uid, nil, nil, "unequip")
		model:Destroy()
		petModels[uid] = nil
		petRarity[uid] = nil
	end
end

function PetController.init()
	RunService.RenderStepped:Connect(updatePetPositions)
end

return PetController
