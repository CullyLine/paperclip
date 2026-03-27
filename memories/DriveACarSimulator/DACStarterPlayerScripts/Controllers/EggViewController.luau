--!strict
--[[
	3D world-space egg hatch cinematic.
	Spawns a real egg model in front of the player, deforms it with EditableMesh
	(twist effect), wobbles/cracks based on HatchCrackVisualSpec rarity config,
	then reveals the pet with a cinematic camera and result UI overlay.

	Flow: HatchEgg FireClient -> onHatchResult -> hide panels -> spawn egg ->
	      camera swing -> EditableMesh twist + wobble -> burst -> pet reveal ->
	      result overlay with "Back to Inventory" -> cleanup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local HatchCrackVisualSpec = require(DAC:WaitForChild("Config"):WaitForChild("HatchCrackVisualSpec"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local EggViewController = {}

local eggViewClientInitDone = false
local player = Players.LocalPlayer
local hatchToken = 0

local function getEggTemplatesFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("EggModels")
	if f and f:IsA("Folder") then return f end
	return nil
end

local function getPetTemplatesFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("PetModels")
	if f and f:IsA("Folder") then return f end
	return nil
end

local function getCharacterRoot(): BasePart?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function groundRaycast(origin: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = player.Character
	if char then params.FilterDescendantsInstances = { char } end
	local result = workspace:Raycast(origin + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), params)
	if result then return result.Position end
	return origin
end

local RARITY_LABEL_COLORS: { [string]: Color3 } = {
	common = Color3.fromRGB(200, 200, 200),
	uncommon = Color3.fromRGB(80, 220, 80),
	rare = Color3.fromRGB(60, 130, 255),
	epic = Color3.fromRGB(180, 60, 255),
	legendary = Color3.fromRGB(255, 200, 50),
	mythic = Color3.fromRGB(255, 50, 80),
}

local RARITY_DISPLAY: { [string]: string } = {
	common = "COMMON",
	uncommon = "UNCOMMON",
	rare = "RARE",
	epic = "EPIC",
	legendary = "LEGENDARY",
	mythic = "MYTHIC",
}

local function prepareModelForHatch(model: Model)
	if not model.PrimaryPart then
		local p = model:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then model.PrimaryPart = p end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
end

local function getUIController(): any?
	local ps = player:FindFirstChild("PlayerScripts")
	if not ps then return nil end
	local dac = ps:FindFirstChild("DAC")
	if not dac then return nil end
	local controllers = dac:FindFirstChild("Controllers")
	if not controllers then return nil end
	local uiMod = controllers:FindFirstChild("UIController")
	if uiMod and uiMod:IsA("ModuleScript") then
		local ok, uc = pcall(require, uiMod)
		if ok then return uc end
	end
	return nil
end

--[[
	EditableMesh twist deformation.
	Applies a progressive twist around the Y axis: vertices higher up
	rotate more, creating a wringing/candy-wrapper effect.
]]
local function applyTwistDeformation(
	editMesh: EditableMesh,
	vertexIds: { number },
	originalPositions: { [number]: Vector3 },
	twistAngleRad: number,
	meshCenter: Vector3,
	meshHeight: number
)
	for _, vId in vertexIds do
		local orig = originalPositions[vId]
		if not orig then continue end
		local relY = (orig.Y - meshCenter.Y) / math.max(meshHeight * 0.5, 0.01)
		local angle = twistAngleRad * relY
		local cosA = math.cos(angle)
		local sinA = math.sin(angle)
		local dx = orig.X - meshCenter.X
		local dz = orig.Z - meshCenter.Z
		local newX = meshCenter.X + dx * cosA - dz * sinA
		local newZ = meshCenter.Z + dx * sinA + dz * cosA
		editMesh:SetPosition(vId, Vector3.new(newX, orig.Y, newZ))
	end
end

--[[
	Try to create an EditableMesh from an egg model's SpecialMesh.
	Returns (editableMesh, meshPart, vertexIds, originalPositions, center, height) or nil.
]]
local function tryCreateEditableEgg(eggModel: Model): (EditableMesh?, MeshPart?, { number }?, { [number]: Vector3 }?, Vector3?, number?)
	local primary = eggModel.PrimaryPart
	if not primary then return nil end
	local specialMesh = primary:FindFirstChildOfClass("SpecialMesh")
	if not specialMesh or specialMesh.MeshId == "" then return nil end

	local meshId = specialMesh.MeshId
	local ok, editMesh = pcall(function()
		return AssetService:CreateEditableMeshAsync(meshId)
	end)
	if not ok or not editMesh then
		warn("[DAC] EditableMesh creation failed:", editMesh)
		return nil
	end

	local em = editMesh :: EditableMesh
	local vertexIds = em:GetVertices()
	if #vertexIds == 0 then
		em:Destroy()
		return nil
	end

	local originalPositions: { [number]: Vector3 } = {}
	local minY, maxY = math.huge, -math.huge
	local sumX, sumY, sumZ = 0, 0, 0
	for _, vId in vertexIds do
		local pos = em:GetPosition(vId)
		originalPositions[vId] = pos
		sumX += pos.X; sumY += pos.Y; sumZ += pos.Z
		if pos.Y < minY then minY = pos.Y end
		if pos.Y > maxY then maxY = pos.Y end
	end
	local n = #vertexIds
	local center = Vector3.new(sumX / n, sumY / n, sumZ / n)
	local height = maxY - minY

	local meshPartOk, meshPart = pcall(function()
		return em:CreateMeshPartAsync(primary.Size)
	end)
	if not meshPartOk or not meshPart then
		warn("[DAC] CreateMeshPartAsync failed:", meshPart)
		em:Destroy()
		return nil
	end

	local mp = meshPart :: MeshPart
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.Color = primary.Color
	mp.Material = primary.Material
	if specialMesh.TextureId ~= "" then
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = specialMesh.TextureId
		sa.Parent = mp
	end

	return em, mp, vertexIds, originalPositions, center, height
end

--[[
	Build the result overlay ScreenGui shown after the pet is revealed.
	Contains pet name, rarity badge, power label, and a "Back to Inventory" button.
	Returns (screenGui, dismissCallback).
]]
local function createResultOverlay(
	petName: string,
	rarity: string,
	power: number?,
	onDismiss: () -> ()
): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACHatchResult"
	gui.DisplayOrder = 90
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.ZIndex = 1
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 0.92, 0)
	card.Size = UDim2.new(0.55, 0, 0, 160)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.ZIndex = 10
	card.Parent = gui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = RARITY_LABEL_COLORS[rarity] or Color3.new(1, 1, 1)
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.3
	cardStroke.Parent = card

	local youGot = Instance.new("TextLabel")
	youGot.Name = "YouGot"
	youGot.Size = UDim2.new(1, 0, 0, 24)
	youGot.Position = UDim2.new(0, 0, 0, 12)
	youGot.BackgroundTransparency = 1
	youGot.Font = Enum.Font.Gotham
	youGot.TextSize = 14
	youGot.TextColor3 = Color3.fromRGB(180, 185, 210)
	youGot.Text = "YOU HATCHED"
	youGot.ZIndex = 11
	youGot.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "PetName"
	nameLbl.Size = UDim2.new(1, 0, 0, 36)
	nameLbl.Position = UDim2.new(0, 0, 0, 36)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 28
	nameLbl.TextColor3 = RARITY_LABEL_COLORS[rarity] or Color3.new(1, 1, 1)
	nameLbl.TextStrokeTransparency = 0.4
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.Text = petName
	nameLbl.ZIndex = 11
	nameLbl.Parent = card

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Name = "Rarity"
	rarityLbl.Size = UDim2.new(1, 0, 0, 22)
	rarityLbl.Position = UDim2.new(0, 0, 0, 72)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Font = Enum.Font.GothamBold
	rarityLbl.TextSize = 16
	rarityLbl.TextColor3 = RARITY_LABEL_COLORS[rarity] or Color3.new(1, 1, 1)
	rarityLbl.Text = RARITY_DISPLAY[rarity] or string.upper(rarity)
	if type(power) == "number" and power > 0 then
		rarityLbl.Text = rarityLbl.Text .. "  \u{2022}  " .. tostring(power) .. " Power"
	end
	rarityLbl.ZIndex = 11
	rarityLbl.Parent = card

	local btn = Instance.new("TextButton")
	btn.Name = "BackBtn"
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Position = UDim2.new(0.5, 0, 0, 108)
	btn.Size = UDim2.new(0.5, 0, 0, 38)
	btn.BackgroundColor3 = RARITY_LABEL_COLORS[rarity] or Color3.fromRGB(80, 120, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(20, 20, 30)
	btn.Text = "Back to Inventory"
	btn.AutoButtonColor = true
	btn.ZIndex = 12
	btn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = btn

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0
	cardScale.Parent = card

	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	btn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		TweenService:Create(cardScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0,
		}):Play()
		task.delay(0.18, function()
			gui:Destroy()
			onDismiss()
		end)
	end)

	return gui
end

function EggViewController.onHatchResult(result: any)
	if type(result) ~= "table" then return end

	hatchToken += 1
	local token = hatchToken

	local eggId = result.eggId
	local petId = result.petId
	local rarity = if type(result.rarity) == "string" then string.lower(result.rarity) else "common"
	local petName = if type(result.petName) == "string" then result.petName else "Pet"
	local petPower = if type(result.power) == "number" then result.power else nil

	local spec = HatchCrackVisualSpec.getForRarity(rarity)
	if not spec then spec = HatchCrackVisualSpec.getForRarity("common") end
	if not spec then return end

	local hrp = getCharacterRoot()
	if not hrp then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Hide inventory/egg UI panels
	local uc = getUIController()
	if uc and uc.closeAllInstant then
		uc.closeAllInstant()
	end

	-- Spawn egg in front of player
	local spawnDir = hrp.CFrame.LookVector
	local spawnOrigin = hrp.Position + spawnDir * 10
	local groundPos = groundRaycast(spawnOrigin)

	local eggModel: Model? = nil
	if type(eggId) == "string" then
		local eggFolder = getEggTemplatesFolder()
		if eggFolder then
			local eggName = EggConfig.getEggTemplateName(eggId)
			if eggName then
				local tpl = eggFolder:FindFirstChild(eggName)
				if tpl and tpl:IsA("Model") then
					eggModel = tpl:Clone()
				end
			end
		end
	end
	if not eggModel then return end

	local egg = eggModel :: Model
	egg.Name = "_HatchEgg3D"
	prepareModelForHatch(egg)
	local eggPrimary = egg.PrimaryPart
	if not eggPrimary then egg:Destroy(); return end

	local eggCF = CFrame.new(groundPos + Vector3.new(0, eggPrimary.Size.Y * 0.5, 0))
	egg:PivotTo(eggCF)

	-- EditableMesh twist setup
	local editMesh: EditableMesh? = nil
	local twistPart: MeshPart? = nil
	local vertexIds: { number }? = nil
	local originalPositions: { [number]: Vector3 }? = nil
	local meshCenter: Vector3? = nil
	local meshHeight: number? = nil
	local useEditableMesh = false

	local em, mp, vIds, origPos, center, height = tryCreateEditableEgg(egg)
	if em and mp and vIds and origPos and center and height then
		editMesh = em
		twistPart = mp
		vertexIds = vIds
		originalPositions = origPos
		meshCenter = center
		meshHeight = height

		mp.CFrame = eggPrimary.CFrame
		mp.Parent = workspace

		for _, desc in egg:GetDescendants() do
			if desc:IsA("BasePart") then desc.Transparency = 1 end
		end

		local existingEmitters = {}
		for _, desc in egg:GetDescendants() do
			if desc:IsA("ParticleEmitter") or desc:IsA("PointLight") then
				local clone = desc:Clone()
				clone.Parent = mp
				table.insert(existingEmitters, clone)
			end
		end

		useEditableMesh = true
	end

	egg.Parent = workspace

	local glowParent = if useEditableMesh and twistPart then twistPart else eggPrimary
	local glow = Instance.new("PointLight")
	glow.Name = "HatchGlow"
	glow.Brightness = 1
	glow.Range = 16
	glow.Color = spec.glowColor
	glow.Parent = glowParent

	-- Camera: save state, swing to cinematic angle (zoomed out more)
	local savedCamType = camera.CameraType
	local savedFOV = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	local camOffset = Vector3.new(5, 4, 10)
	local camTarget = eggCF.Position + Vector3.new(0, 1.5, 0)
	local camPos = camTarget + camOffset
	local cinematicCF = CFrame.lookAt(camPos, camTarget)

	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = cinematicCF,
	}):Play()

	-- SFX timing
	for _, sfx in spec.sfxTiming do
		task.delay(sfx.atSec, function()
			if hatchToken ~= token then return end
			SoundFacade.playOneShot(sfx.soundId)
		end)
	end

	-- Wobble + twist phase
	local wobbleDur = spec.wobblePhases.durationSec
	local wobbleStart = os.clock()
	local wobbleConn: RBXScriptConnection? = nil

	wobbleConn = RunService.RenderStepped:Connect(function()
		if hatchToken ~= token then
			if wobbleConn then wobbleConn:Disconnect() end
			return
		end
		local t = os.clock() - wobbleStart
		if t > wobbleDur then
			if wobbleConn then wobbleConn:Disconnect(); wobbleConn = nil end
			return
		end

		local angleDeg = HatchCrackVisualSpec.wobbleAt(spec, t)
		local progress = math.clamp(t / wobbleDur, 0, 1)

		-- Wobble rotation on the egg/meshpart
		local wobbleCF = eggCF * CFrame.Angles(0, 0, math.rad(angleDeg))
		if useEditableMesh and twistPart then
			twistPart.CFrame = wobbleCF
		end
		if egg.Parent and eggPrimary and eggPrimary.Parent then
			egg:PivotTo(wobbleCF)
		end

		-- EditableMesh twist deformation
		if useEditableMesh and editMesh and vertexIds and originalPositions and meshCenter and meshHeight then
			local maxTwistRad = math.rad(45) * progress * progress
			applyTwistDeformation(editMesh, vertexIds, originalPositions, maxTwistRad, meshCenter, meshHeight)
			if twistPart then
				pcall(function()
					twistPart:ApplyMesh(editMesh)
				end)
			end
		end

		-- Glow pulse
		local glowPulse = spec.crackStyle.glowPulseHz
		if glowPulse and glowPulse > 0 then
			glow.Brightness = 1.5 + 1.5 * math.sin(t * glowPulse * math.pi * 2) * progress
		else
			glow.Brightness = 1 + 2 * progress
		end
		glow.Range = 16 + 12 * progress

		-- Egg scale growth
		if spec.eggSizeGrowth > 0 and eggPrimary and eggPrimary.Parent then
			local growFactor = 1 + spec.eggSizeGrowth * progress
			egg:ScaleTo(growFactor)
			if useEditableMesh and twistPart then
				twistPart.Size = eggPrimary.Size
			end
		end

		-- Jitter for high-rarity
		local jitterAfter = spec.wobblePhases.jitterAfterSec
		local jitterPx = spec.wobblePhases.jitterPx
		if jitterAfter and jitterPx and t > jitterAfter then
			local jx = (math.random() - 0.5) * jitterPx * 0.1
			local jy = (math.random() - 0.5) * jitterPx * 0.1
			local jitterCF = wobbleCF * CFrame.new(jx, jy, 0)
			if useEditableMesh and twistPart then
				twistPart.CFrame = jitterCF
			end
			if egg.Parent then egg:PivotTo(jitterCF) end
		end
	end)

	-- Camera shake near end of wobble
	if spec.cameraShakeIntensity and spec.cameraShakeDurationSec then
		task.delay(wobbleDur * 0.7, function()
			if hatchToken ~= token then return end
			local shakeEnd = os.clock() + (spec.cameraShakeDurationSec :: number)
			local intensity = spec.cameraShakeIntensity :: number
			local shakeConn: RBXScriptConnection? = nil
			shakeConn = RunService.RenderStepped:Connect(function()
				if hatchToken ~= token or os.clock() > shakeEnd then
					if shakeConn then shakeConn:Disconnect() end
					return
				end
				local ox = (math.random() - 0.5) * intensity
				local oy = (math.random() - 0.5) * intensity
				camera.CFrame = cinematicCF * CFrame.new(ox, oy, 0)
			end)
		end)
	end

	-- FOV punch
	if spec.fovPunch and spec.fovReturnSec then
		task.delay(wobbleDur, function()
			if hatchToken ~= token then return end
			local targetFov = savedFOV + (spec.fovPunch :: number)
			TweenService:Create(camera, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = targetFov,
			}):Play()
			task.delay(0.08, function()
				if hatchToken ~= token then return end
				TweenService:Create(camera, TweenInfo.new(spec.fovReturnSec :: number, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					FieldOfView = savedFOV,
				}):Play()
			end)
		end)
	end

	-- Lighting emphasis
	local savedBrightness = Lighting.Brightness
	if spec.lightingBrightnessDelta and spec.lightingRestoreSec then
		task.delay(wobbleDur, function()
			if hatchToken ~= token then return end
			Lighting.Brightness = savedBrightness + (spec.lightingBrightnessDelta :: number)
			task.delay(spec.lightingRestoreSec :: number, function()
				if hatchToken ~= token then return end
				TweenService:Create(Lighting, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Brightness = savedBrightness,
				}):Play()
			end)
		end)
	end

	-- BURST at end of wobble -> destroy egg -> reveal pet -> show result overlay
	local burstTime = wobbleDur + 0.05
	task.delay(burstTime, function()
		if hatchToken ~= token then return end

		local hitstop = spec.hitstopSec or 0
		if hitstop > 0 then
			task.wait(hitstop)
			if hatchToken ~= token then return end
		end

		glow.Brightness = 12
		glow.Range = 40

		if spec.breakScaleMultiplier > 1 and egg.Parent then
			egg:ScaleTo(spec.breakScaleMultiplier)
		end

		task.delay(spec.breakDurationSec, function()
			if egg.Parent then egg:Destroy() end
			if useEditableMesh then
				if twistPart and twistPart.Parent then twistPart:Destroy() end
				if editMesh then pcall(function() editMesh:Destroy() end) end
			end
		end)

		-- Pet reveal
		local petModel: Model? = nil
		if type(petId) == "string" then
			local petFolder = getPetTemplatesFolder()
			if petFolder then
				local petTplName = PetConfig.getPetTemplateName(petId)
				if petTplName then
					local petTpl = petFolder:FindFirstChild(petTplName)
					if petTpl and petTpl:IsA("Model") then
						petModel = petTpl:Clone()
					end
				end
			end
		end

		if not petModel then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = savedFOV
			return
		end

		local pet = petModel :: Model
		pet.Name = "_HatchPetReveal"
		prepareModelForHatch(pet)
		local petPrimary = pet.PrimaryPart

		if not petPrimary then
			pet:Destroy()
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = savedFOV
			return
		end

		local petPos = eggCF.Position
		local lookDir = (camPos - petPos) * Vector3.new(1, 0, 1)
		local petCFrame: CFrame
		if lookDir.Magnitude > 0.01 then
			petCFrame = CFrame.lookAt(petPos, petPos + lookDir)
		else
			petCFrame = CFrame.new(petPos)
		end
		pet:PivotTo(petCFrame)
		pet:ScaleTo(0.01)
		pet.Parent = workspace

		-- Scale-up with back-ease-out bounce
		local revealDur = 0.45
		local revealStart = os.clock()
		local revealConn: RBXScriptConnection? = nil
		revealConn = RunService.RenderStepped:Connect(function()
			if hatchToken ~= token then
				if revealConn then revealConn:Disconnect() end
				return
			end
			local elapsed = os.clock() - revealStart
			local progress = math.clamp(elapsed / revealDur, 0, 1)
			local c1 = 1.70158
			local c3 = c1 + 1
			local eased = 1 + c3 * (progress - 1) ^ 3 + c1 * (progress - 1) ^ 2
			pet:ScaleTo(math.max(0.01, eased))
			if progress >= 1 then
				if revealConn then revealConn:Disconnect(); revealConn = nil end
			end
		end)

		-- Pet glow
		local petGlow = Instance.new("PointLight")
		petGlow.Name = "PetRevealGlow"
		petGlow.Brightness = 3
		petGlow.Range = 20
		petGlow.Color = spec.glowColor
		petGlow.Parent = petPrimary
		TweenService:Create(petGlow, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 0.5,
			Range = 8,
		}):Play()

		-- Slow spin
		local spinConn: RBXScriptConnection? = nil
		local spinStart = os.clock()
		spinConn = RunService.RenderStepped:Connect(function()
			if hatchToken ~= token or not pet.Parent then
				if spinConn then spinConn:Disconnect() end
				return
			end
			local elapsed = os.clock() - spinStart
			pet:PivotTo(petCFrame * CFrame.Angles(0, elapsed * 0.8, 0))
		end)

		SoundFacade.playOneShot("payout_card_pop")

		-- Show result overlay after pet finishes scaling in
		task.delay(revealDur + 0.3, function()
			if hatchToken ~= token then return end

			local playerGui = player:FindFirstChild("PlayerGui") :: PlayerGui?
			if not playerGui then return end

			local resultGui = createResultOverlay(petName, rarity, petPower, function()
				-- Dismiss callback: clean up pet, restore camera, reopen inventory
				if spinConn then spinConn:Disconnect(); spinConn = nil end
				if pet.Parent then pet:Destroy() end

				camera.CameraType = Enum.CameraType.Custom
				camera.FieldOfView = savedFOV

				local uic = getUIController()
				if uic and uic.openPanel then
					task.defer(function()
						uic.openPanel("Inventory")
					end)
				end
			end)
			resultGui.Parent = playerGui
		end)
	end)
end

function EggViewController.init()
	if eggViewClientInitDone then return end
	eggViewClientInitDone = true

	Remotes.getEvent("HatchEgg").OnClientEvent:Connect(function(result)
		EggViewController.onHatchResult(result)
	end)
end

return EggViewController
