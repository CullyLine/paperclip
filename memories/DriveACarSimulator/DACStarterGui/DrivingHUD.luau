--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local DrivingHUD = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local drivingUI: Frame
local gasBar: ImageLabel
local gasBackground: ImageLabel
local gasText: TextLabel
local speedText: TextLabel
local powerText: TextLabel
local travelFrame: ImageLabel
local travelLabel: TextLabel
local lapsLabel: TextLabel
local recordFrame: Instance?

local isVisible = false
local maxGas = 0
local currentGas = 0
local currentDistance = 0
local currentLaps = 0
local currentSpeed = 0
local currentPower = 0
local bestDistance = 0

local DrivingController: any = nil

local function tryGetDrivingController()
	if DrivingController then return end
	local ok, mod = pcall(function()
		local sps = player:WaitForChild("PlayerScripts", 2)
		if not sps then return nil end
		local dac = sps:FindFirstChild("DAC")
		if not dac then return nil end
		local ctrls = dac:FindFirstChild("Controllers")
		if not ctrls then return nil end
		local dc = ctrls:FindFirstChild("DrivingController")
		if not dc then return nil end
		return require(dc)
	end)
	if ok and mod then
		DrivingController = mod
	end
end

function DrivingHUD.show(stats: { gas: number, speed: number, power: number })
	maxGas = stats.gas
	currentGas = stats.gas
	currentDistance = 0
	currentLaps = 0
	currentSpeed = stats.speed
	currentPower = stats.power
	isVisible = true
	if drivingUI then
		drivingUI.Visible = true
	end
	if travelFrame then
		travelFrame.Visible = true
	end
end

function DrivingHUD.hide()
	isVisible = false
	if drivingUI then
		drivingUI.Visible = false
	end
	if travelFrame then
		travelFrame.Visible = false
	end
end

local function render()
	if not isVisible then return end

	if DrivingController then
		local state = DrivingController.getRunState()
		if state then
			currentDistance = state.distance
			currentGas = state.gas
			currentSpeed = state.speed
			currentLaps = state.laps
		end
	end

	local gasPercent = if maxGas > 0 then math.clamp(currentGas / maxGas, 0, 1) else 0
	if gasBar then
		gasBar.Size = UDim2.new(gasPercent * 0.5, 0, gasBar.Size.Y.Scale, 0)
	end

	if gasText then
		gasText.Text = tostring(math.floor(currentGas))
	end

	if speedText then
		speedText.Text = tostring(math.floor(currentSpeed))
	end

	if powerText then
		powerText.Text = tostring(math.floor(currentPower))
	end

	if travelLabel then
		local miles = currentDistance / 5280
		travelLabel.Text = string.format("%.1f Miles Driven", miles)
	end
	if lapsLabel then
		lapsLabel.Text = tostring(currentLaps) .. " Laps Driven"
	end

	if recordFrame and currentDistance > bestDistance then
		recordFrame.Visible = true
	end
end

function DrivingHUD.init()
	local screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	local pInfo = screenGui:WaitForChild("PlayerInfo") :: Frame
	drivingUI = pInfo:WaitForChild("DrivingUI") :: Frame
	drivingUI.Visible = false

	local gasFrame = drivingUI:FindFirstChild("Gas")
	if gasFrame then
		gasBar = gasFrame:FindFirstChild("Bar") :: ImageLabel
		gasBackground = gasFrame:FindFirstChild("Background") :: ImageLabel
		local textFrame = gasFrame:FindFirstChild("Text")
		if textFrame then
			gasText = textFrame:FindFirstChild("TextLabel") :: TextLabel
		end
	end

	local speedFrame = drivingUI:FindFirstChild("Speed")
	if speedFrame then
		speedText = speedFrame:FindFirstChild("TextLabel") :: TextLabel
	end

	local powerFrame = drivingUI:FindFirstChild("Power")
	if powerFrame then
		local pt = powerFrame:FindFirstChild("Text")
		if pt then
			powerText = pt:FindFirstChild("TextLabel") :: TextLabel
		end
	end

	travelFrame = drivingUI:FindFirstChild("Travel") :: ImageLabel
	if travelFrame then
		travelFrame.Visible = false
		travelLabel = travelFrame:FindFirstChild("Travel") :: TextLabel
		lapsLabel = travelFrame:FindFirstChild("Laps") :: TextLabel
		local rec = travelFrame:FindFirstChild("Record")
		if rec then
			recordFrame = rec
			rec.Visible = false
		end
	end

	tryGetDrivingController()

	RunService.RenderStepped:Connect(render)

	Remotes.getEvent("StartRun").OnClientEvent:Connect(function(runInfo)
		tryGetDrivingController()
		DrivingHUD.show(runInfo.stats)
	end)

	Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
		if currentDistance > bestDistance then
			bestDistance = currentDistance
		end
		DrivingHUD.hide()
	end)

	print("[DAC] DrivingHUD initialized (using DACMain.DrivingUI)")
end

return DrivingHUD
