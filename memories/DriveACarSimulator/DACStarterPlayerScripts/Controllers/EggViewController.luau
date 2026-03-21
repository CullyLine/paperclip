--!strict
--[[
	Client visuals for eggs: clones from ReplicatedStorage.EggModels using EggConfig template names.
	Used on hatch to briefly show the egg + hatched pet model above the player.

	init() wires `HatchEgg` -> onHatchResult only (ephemeral world models; no camera or ScreenGui refs).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))

local EggViewController = {}

local player = Players.LocalPlayer

local function getEggTemplatesFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("EggModels")
	if f and f:IsA("Folder") then
		return f
	end
	return nil
end

local function getPetTemplatesFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("PetModels")
	if f and f:IsA("Folder") then
		return f
	end
	return nil
end

local function previewPosition(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.Position + Vector3.new(0, 6, 0)
	end
	return Vector3.new(0, 12, 0)
end

function EggViewController.onHatchResult(result: any)
	if type(result) ~= "table" then
		return
	end
	local pos = previewPosition()

	local eggId = result.eggId
	if type(eggId) == "string" then
		local eggFolder = getEggTemplatesFolder()
		if eggFolder then
			local eggName = EggConfig.getEggTemplateName(eggId)
			if eggName then
				local eggTpl = eggFolder:FindFirstChild(eggName)
				if eggTpl and eggTpl:IsA("Model") then
					local eggModel = eggTpl:Clone()
					eggModel.Name = "_HatchEggPreview"
					eggModel.Parent = workspace
					if not eggModel.PrimaryPart then
						local p = eggModel:FindFirstChildWhichIsA("BasePart", true)
						if p and p:IsA("BasePart") then
							eggModel.PrimaryPart = p
						end
					end
					if eggModel.PrimaryPart then
						eggModel:PivotTo(CFrame.new(pos))
					end
					task.delay(0.55, function()
						eggModel:Destroy()
					end)
				end
			end
		end
	end

	local petId = result.petId
	if type(petId) == "string" then
		local petFolder = getPetTemplatesFolder()
		if petFolder then
			local petName = PetConfig.getPetTemplateName(petId)
			if petName then
				local petTpl = petFolder:FindFirstChild(petName)
				if petTpl and petTpl:IsA("Model") then
					local petModel = petTpl:Clone()
					petModel.Name = "_HatchPetPreview"
					petModel.Parent = workspace
					if not petModel.PrimaryPart then
						local p = petModel:FindFirstChildWhichIsA("BasePart", true)
						if p and p:IsA("BasePart") then
							petModel.PrimaryPart = p
						end
					end
					if petModel.PrimaryPart then
						petModel:PivotTo(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
					end
					task.delay(2.8, function()
						petModel:Destroy()
					end)
				end
			end
		end
	end
end

--[[
	Wire hatch preview here; models are spawned ephemerally in onHatchResult (no persistent UI/camera refs).
]]
function EggViewController.init()
	Remotes.getEvent("HatchEgg").OnClientEvent:Connect(function(result)
		EggViewController.onHatchResult(result)
	end)
end

return EggViewController
