--!strict
--[[
	Client-side training controller.
	When the player enters a Training zone, a ProximityPrompt appears.
	Triggering the prompt locks the player into training (fires StartTraining).
	Jumping (Spacebar / gamepad A) ends training (fires StopTraining).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local TrainingController = {}

local player = Players.LocalPlayer
local isTraining = false
local isInZone = false
local activePrompt: ProximityPrompt? = nil
local promptConn: RBXScriptConnection? = nil
local jumpConn: RBXScriptConnection? = nil
local jumpStateConn: RBXScriptConnection? = nil

local function getTrainingHud(): Frame?
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("DACMain")
	if not gui then return nil end
	return gui:FindFirstChild("TrainingHUD") :: Frame?
end

local function showHud()
	local hud = getTrainingHud()
	if hud then hud.Visible = true end
end

local function hideHud()
	local hud = getTrainingHud()
	if hud then hud.Visible = false end
end

local function stopTraining()
	if not isTraining then return end
	isTraining = false
	hideHud()
	Remotes.getEvent("StopTraining"):FireServer()

	if jumpConn then
		jumpConn:Disconnect()
		jumpConn = nil
	end
	if jumpStateConn then
		jumpStateConn:Disconnect()
		jumpStateConn = nil
	end
end

local function startTraining()
	if isTraining then return end
	isTraining = true
	showHud()
	Remotes.getEvent("StartTraining"):FireServer()

	jumpConn = UserInputService.JumpRequest:Connect(function()
		stopTraining()
	end)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			jumpStateConn = humanoid.StateChanged:Connect(function(_old, new)
				if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
					stopTraining()
				end
			end)
		end
	end
end

local function cleanupPrompt()
	if promptConn then
		promptConn:Disconnect()
		promptConn = nil
	end
	if activePrompt then
		activePrompt:Destroy()
		activePrompt = nil
	end
end

function TrainingController.show(zonePart: BasePart)
	if isInZone then return end
	isInZone = true

	cleanupPrompt()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Training Station"
	prompt.ActionText = "Train"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart
	activePrompt = prompt

	promptConn = prompt.Triggered:Connect(function(triggerPlayer: Player)
		if triggerPlayer == player then
			startTraining()
		end
	end)
end

function TrainingController.hide()
	isInZone = false
	cleanupPrompt()
	stopTraining()
end

function TrainingController.isActive(): boolean
	return isTraining
end

function TrainingController.init()
	Remotes.getEvent("TrainingTick").OnClientEvent:Connect(function(info: any)
		if not isTraining then return end
		local hud = getTrainingHud()
		if not hud then return end

		local powerLabel = hud:FindFirstChild("PowerLabel") :: TextLabel?
		local tickLabel = hud:FindFirstChild("TickLabel") :: TextLabel?
		local petLabel = hud:FindFirstChild("PetModLabel") :: TextLabel?

		if powerLabel and type(info.trainedPower) == "number" then
			powerLabel.Text = `Power: {math.floor(info.trainedPower)}`
		end
		if tickLabel and type(info.powerPerTick) == "number" then
			tickLabel.Text = `+{string.format("%.1f", info.powerPerTick)} / tick`
		end
		if petLabel and type(info.petModifier) == "number" then
			petLabel.Text = `Pet Boost: {string.format("%.0f", (info.petModifier - 1) * 100)}%`
		end
	end)
end

return TrainingController
