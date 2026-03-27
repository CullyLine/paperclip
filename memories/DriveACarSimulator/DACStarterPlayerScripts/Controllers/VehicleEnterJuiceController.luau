--!strict
--[[
	POLA-447: "Vehicle enter" lobby juice — there is no VehicleSeat / ProximityPrompt
	pipeline in this codebase (see Audio/MANIFEST.md). While the player is near
	Workspace.Worlds.*.Start parts (same regions the server uses for Touched start),
	we show a soft ring pulse + play `vehicle_enter_prompt`. Run start feedback
	(`vehicle_enter_success` + checkmark) lives in DrivingController + VFXController.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local DrivingRunGate = require(DAC:WaitForChild("DrivingRunGate"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))

local VehicleEnterJuiceController = {}

-- Idempotent init: hot reload must not stack Heartbeat / AncestryChanged loops.
local vehicleEnterJuiceInitDone = false

local player = Players.LocalPlayer

local NEAR_XZ_STUDS = 22
local Y_BAND_ABOVE = 14
local Y_BAND_BELOW = 8
local GATHER_INTERVAL = 4.0
local HEARTBEAT_INTERVAL = 0.14

local startParts: { BasePart } = {}
local lastGatherClock = 0.0
local lastHbClock = 0.0
local wasInRange = false

local ringGui: ScreenGui? = nil
local ringFrame: Frame? = nil
local ringScale: UIScale? = nil
local ringTween: Tween? = nil

local function destroyRingGui()
	if ringTween then
		ringTween:Cancel()
		ringTween = nil
	end
	if ringGui then
		ringGui:Destroy()
		ringGui = nil
	end
	ringFrame = nil
	ringScale = nil
end

local function gatherStartParts()
	table.clear(startParts)
	local worlds = workspace:FindFirstChild("Worlds")
	if not worlds then
		return
	end
	for _, world in worlds:GetChildren() do
		local startModel = world:FindFirstChild("Start")
		if startModel then
			for _, ch in startModel:GetChildren() do
				if ch:IsA("BasePart") then
					table.insert(startParts, ch)
				end
			end
		end
	end
end

local function xzDist(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function horizontalDistToPart(hrpPos: Vector3, part: BasePart): number
	local cf = part.CFrame
	local localPos = cf:PointToObjectSpace(hrpPos)
	local half = part.Size * 0.5
	local lx = math.clamp(localPos.X, -half.X, half.X)
	local ly = math.clamp(localPos.Y, -half.Y, half.Y)
	local lz = math.clamp(localPos.Z, -half.Z, half.Z)
	local closest = cf:PointToWorldSpace(Vector3.new(lx, ly, lz))
	return xzDist(hrpPos, closest)
end

local function yInBand(hrpPos: Vector3, part: BasePart): boolean
	local halfY = part.Size.Y * 0.5
	local bottom = part.Position.Y - halfY - Y_BAND_BELOW
	local top = part.Position.Y + halfY + Y_BAND_ABOVE
	return hrpPos.Y >= bottom and hrpPos.Y <= top
end

local function isNearAnyStart(hrpPos: Vector3): boolean
	for _, part in startParts do
		if part.Parent and yInBand(hrpPos, part) and horizontalDistToPart(hrpPos, part) <= NEAR_XZ_STUDS then
			return true
		end
	end
	return false
end

local function ensureRingGui()
	if ringGui and ringGui.Parent then
		return
	end
	destroyRingGui()

	local sg = Instance.new("ScreenGui")
	sg.Name = "DACVehicleEnterJuice"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = UILayerStack.screenGui.hudPlaytimeGem - 2
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = player:WaitForChild("PlayerGui")

	local f = Instance.new("Frame")
	f.Name = "InviteRing"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, -108)
	f.Size = UDim2.fromOffset(56, 56)
	f.BackgroundColor3 = Color3.fromRGB(255, 214, 240)
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(42, 42, 64)
	stroke.Thickness = 2.5
	stroke.Transparency = 0.15
	stroke.Parent = f

	local icon = Instance.new("TextLabel")
	icon.Name = "Glyph"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBlack
	icon.Text = "\u{1F697}"
	icon.TextSize = 26
	icon.TextColor3 = Color3.fromRGB(30, 30, 45)
	icon.Parent = f

	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = f

	ringGui = sg
	ringFrame = f
	ringScale = sc
end

local function stopPulseLoop()
	if ringTween then
		ringTween:Cancel()
		ringTween = nil
	end
	if ringScale then
		ringScale.Scale = 1
	end
end

local function startPulseLoop()
	if not ringScale or ClientPerformanceProfile.isReducedMotion() then
		return
	end
	stopPulseLoop()
	ringTween = TweenService:Create(
		ringScale,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.09 }
	)
	ringTween:Play()
end

local function setRingVisible(vis: boolean)
	if not vis then
		stopPulseLoop()
		if ringFrame then
			ringFrame.Visible = false
		end
		return
	end
	ensureRingGui()
	if not ringFrame or not ringScale then
		return
	end
	if not ringFrame.Visible then
		ringFrame.Visible = true
		startPulseLoop()
	else
		ringFrame.Visible = true
	end
end

function VehicleEnterJuiceController.tearDownForLifecycle()
	destroyRingGui()
	wasInRange = false
end

function VehicleEnterJuiceController.init()
	if vehicleEnterJuiceInitDone then
		return
	end
	vehicleEnterJuiceInitDone = true

	gatherStartParts()
	lastGatherClock = os.clock()

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastGatherClock >= GATHER_INTERVAL then
			lastGatherClock = now
			gatherStartParts()
		end
		if now - lastHbClock < HEARTBEAT_INTERVAL then
			return
		end
		lastHbClock = now

		if DrivingRunGate.isInRun() then
			if wasInRange then
				wasInRange = false
				setRingVisible(false)
			end
			return
		end

		local char = player.Character
		local hrp = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if not hrp then
			if wasInRange then
				wasInRange = false
				setRingVisible(false)
			end
			return
		end

		if #startParts == 0 then
			if wasInRange then
				wasInRange = false
				setRingVisible(false)
			end
			return
		end

		local near = isNearAnyStart(hrp.Position)
		if near and not wasInRange then
			SoundFacade.playOneShot("vehicle_enter_prompt")
		end
		wasInRange = near

		if ClientPerformanceProfile.isReducedMotion() then
			if near then
				ensureRingGui()
				if ringFrame then
					ringFrame.Visible = true
				end
				stopPulseLoop()
			else
				setRingVisible(false)
			end
			return
		end

		if near then
			setRingVisible(true)
		else
			setRingVisible(false)
		end
	end)

	player.AncestryChanged:Connect(function()
		if not player.Parent then
			destroyRingGui()
		end
	end)
end

return VehicleEnterJuiceController
