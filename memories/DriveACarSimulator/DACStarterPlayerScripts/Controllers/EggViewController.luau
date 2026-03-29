--!strict
--[[
	PS99-style batch egg hatch cinematic.
	Eggs spawn in a golden ratio spiral around the player, wobble/crack/burst,
	then the hatched pet flies toward the camera and joins the HatchGridOverlay.
	No camera lock — the player keeps full control throughout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local HatchCrackVisualSpec = require(DAC:WaitForChild("Config"):WaitForChild("HatchCrackVisualSpec"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local HatchGridOverlay = require(script.Parent:WaitForChild("HatchGridOverlay"))

local EggViewController = {}

local eggViewClientInitDone = false
local player = Players.LocalPlayer
local batchToken = 0

local GOLDEN_ANGLE = 137.508 * math.pi / 180
local SPIRAL_SCALE = 4
local EGG_WORLD_SCALE = 0.5
local PET_WORLD_SCALE = 3
local EGG_STAGGER_SEC = 0.08
local PET_FLY_DURATION = 0.7
local PET_HOVER_AFTER_BURST = 0.25

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

local function computeSpiralPositions(center: Vector3, lookDir: Vector3, count: number): { Vector3 }
	local positions: { Vector3 } = {}
	local forwardAngle = math.atan2(lookDir.Z, lookDir.X)

	for i = 1, count do
		local angle = forwardAngle + i * GOLDEN_ANGLE
		local radius = SPIRAL_SCALE * math.sqrt(i)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local worldPos = center + Vector3.new(x, 0, z)
		local ground = groundRaycast(worldPos)
		table.insert(positions, ground)
	end

	return positions
end

local function spawnAndHatchEgg(
	result: any,
	spawnPos: Vector3,
	token: number,
	delayOffset: number,
	isBatch: boolean
)
	local eggId = result.eggId
	local petId = result.petId
	local rarity = if type(result.rarity) == "string" then string.lower(result.rarity) else "common"
	local petName = if type(result.petName) == "string" then result.petName else "Pet"
	local petPower = if type(result.power) == "number" then result.power else 0

	local spec = HatchCrackVisualSpec.getForRarity(rarity)
	if not spec then spec = HatchCrackVisualSpec.getForRarity("common") end
	if not spec then return end

	local eggModel: Model? = nil
	local eggFolder = getEggTemplatesFolder()
	if eggFolder then
		if type(eggId) == "string" then
			local eggName = EggConfig.getEggTemplateName(eggId)
			if eggName then
				local tpl = eggFolder:FindFirstChild(eggName)
				if tpl and tpl:IsA("Model") then
					eggModel = tpl:Clone()
				end
			end
		end
		if not eggModel then
			local fallback = eggFolder:FindFirstChild("Basic") or eggFolder:FindFirstChildWhichIsA("Model")
			if fallback and fallback:IsA("Model") then
				eggModel = fallback:Clone()
			end
		end
	end
	if not eggModel then return end

	local egg = eggModel :: Model
	egg.Name = "_HatchEgg3D"
	prepareModelForHatch(egg)
	local eggPrimary = egg.PrimaryPart
	if not eggPrimary then egg:Destroy(); return end

	local eggCF = CFrame.new(spawnPos + Vector3.new(0, eggPrimary.Size.Y * 0.5, 0))
	egg:ScaleTo(0.01)
	egg:PivotTo(eggCF)
	egg.Parent = workspace

	local glow = Instance.new("PointLight")
	glow.Name = "HatchGlow"
	glow.Brightness = 1
	glow.Range = 12
	glow.Color = spec.glowColor
	glow.Parent = eggPrimary

	-- Pop-in animation
	task.delay(delayOffset, function()
		if batchToken ~= token then
			if egg.Parent then egg:Destroy() end
			return
		end

		-- Scale egg in with a bounce
		local popDur = 0.25
		local popStart = os.clock()
		local popConn: RBXScriptConnection? = nil
		popConn = RunService.RenderStepped:Connect(function()
			if batchToken ~= token then
				if popConn then popConn:Disconnect() end
				return
			end
			local t = math.clamp((os.clock() - popStart) / popDur, 0, 1)
			local c1 = 1.70158
			local c3 = c1 + 1
			local scale = 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
			egg:ScaleTo(math.max(0.01, scale * EGG_WORLD_SCALE))
			if t >= 1 then
				if popConn then popConn:Disconnect(); popConn = nil end
			end
		end)

		-- Wobble phase (simplified for batch — shorter duration)
		local wobbleDur = isBatch and math.min(spec.wobblePhases.durationSec, 2.0) or spec.wobblePhases.durationSec

		task.delay(popDur, function()
			if batchToken ~= token then
				if egg.Parent then egg:Destroy() end
				return
			end

			-- Play one hatch SFX per egg (the final burst sound only)
			local lastSfx = spec.sfxTiming[#spec.sfxTiming]
			if lastSfx and not isBatch then
				task.delay(wobbleDur, function()
					if batchToken ~= token then return end
					SoundFacade.playOneShot(lastSfx.soundId)
				end)
			end

			local wobbleStart = os.clock()
			local wobbleConn: RBXScriptConnection? = nil
			wobbleConn = RunService.RenderStepped:Connect(function()
				if batchToken ~= token then
					if wobbleConn then wobbleConn:Disconnect() end
					return
				end
				local t = os.clock() - wobbleStart
				if t > wobbleDur then
					if wobbleConn then wobbleConn:Disconnect(); wobbleConn = nil end
					return
				end

				local angleDeg = HatchCrackVisualSpec.wobbleAt(spec, t * (spec.wobblePhases.durationSec / wobbleDur))
				local progress = math.clamp(t / wobbleDur, 0, 1)

				local wobbleCF = eggCF * CFrame.Angles(0, 0, math.rad(angleDeg))
				if egg.Parent and eggPrimary and eggPrimary.Parent then
					egg:PivotTo(wobbleCF)
				end

				local glowPulse = spec.crackStyle.glowPulseHz
				if glowPulse and glowPulse > 0 then
					glow.Brightness = 1.5 + 1.5 * math.sin(t * glowPulse * math.pi * 2) * progress
				else
					glow.Brightness = 1 + 2 * progress
				end
				glow.Range = 12 + 10 * progress

				if spec.eggSizeGrowth > 0 and eggPrimary and eggPrimary.Parent then
					local growFactor = (1 + spec.eggSizeGrowth * progress) * EGG_WORLD_SCALE
					egg:ScaleTo(growFactor)
				end

				local jitterAfter = spec.wobblePhases.jitterAfterSec
				local jitterPx = spec.wobblePhases.jitterPx
				if jitterAfter and jitterPx then
					local scaledJitterAfter = jitterAfter * (wobbleDur / spec.wobblePhases.durationSec)
					if t > scaledJitterAfter then
						local jx = (math.random() - 0.5) * jitterPx * 0.1
						local jy = (math.random() - 0.5) * jitterPx * 0.1
						local jitterCF = wobbleCF * CFrame.new(jx, jy, 0)
						if egg.Parent then egg:PivotTo(jitterCF) end
					end
				end
			end)

			-- Burst → pet reveal → fly to camera → grid
			task.delay(wobbleDur + 0.05, function()
				if batchToken ~= token then
					if egg.Parent then egg:Destroy() end
					return
				end

				SoundFacade.playOneShot("payout_card_pop")

				glow.Brightness = 10
				glow.Range = 30

				if spec.breakScaleMultiplier > 1 and egg.Parent then
					egg:ScaleTo(spec.breakScaleMultiplier * EGG_WORLD_SCALE)
				end

				task.delay(spec.breakDurationSec, function()
					if egg.Parent then egg:Destroy() end
				end)

				-- Spawn pet at egg position
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

				if not petModel then return end

				local pet = petModel :: Model
				pet.Name = "_HatchPetFly"
				prepareModelForHatch(pet)
				local petPrimary = pet.PrimaryPart
				if not petPrimary then
					pet:Destroy()
					return
				end

				local petStartPos = eggCF.Position
				pet:PivotTo(CFrame.new(petStartPos))
				pet:ScaleTo(0.01)
				pet.Parent = workspace

				-- Scale pet in quickly
				local revealDur = 0.3
				local revealStart = os.clock()
				local revealConn: RBXScriptConnection? = nil
				revealConn = RunService.RenderStepped:Connect(function()
					if batchToken ~= token then
						if revealConn then revealConn:Disconnect() end
						return
					end
					local elapsed = os.clock() - revealStart
					local p = math.clamp(elapsed / revealDur, 0, 1)
					local c1 = 1.70158
					local c3 = c1 + 1
					local eased = 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
				pet:ScaleTo(math.max(0.01, eased * PET_WORLD_SCALE))
				if p >= 1 then
					if revealConn then revealConn:Disconnect(); revealConn = nil end
				end
				end)

				-- After brief hover, fly toward camera
				task.delay(revealDur + PET_HOVER_AFTER_BURST, function()
					if batchToken ~= token then
						if pet.Parent then pet:Destroy() end
						return
					end

					local camera = workspace.CurrentCamera
					if not camera then
						if pet.Parent then pet:Destroy() end
						return
					end

					local flyStart = os.clock()
					local startCF = pet:GetPivot()
					local flyConn: RBXScriptConnection? = nil

					flyConn = RunService.RenderStepped:Connect(function()
						if batchToken ~= token then
							if flyConn then flyConn:Disconnect() end
							if pet.Parent then pet:Destroy() end
							return
						end

						local elapsed = os.clock() - flyStart
						local progress = math.clamp(elapsed / PET_FLY_DURATION, 0, 1)
						local eased = progress * progress * (3 - 2 * progress)

						local targetPos = camera.CFrame.Position + camera.CFrame.LookVector * 2
						local lerpPos = startCF.Position:Lerp(targetPos, eased)
					local scale = (1 - eased * 0.6) * PET_WORLD_SCALE
					pet:PivotTo(CFrame.new(lerpPos))
					pet:ScaleTo(math.max(0.01, scale))

						if progress >= 1 then
							if flyConn then flyConn:Disconnect(); flyConn = nil end

							local screenPos = camera:WorldToViewportPoint(lerpPos)
							local viewportSize = camera.ViewportSize
							local screenX = screenPos.X / viewportSize.X
							local screenY = screenPos.Y / viewportSize.Y

							if pet.Parent then pet:Destroy() end

							HatchGridOverlay.addPet(
								petId,
								petName,
								rarity,
								petPower,
								screenX,
								screenY
							)
						end
					end)
				end)
			end)
		end)
	end)
end

function EggViewController.onBatchHatchResult(results: { any })
	if #results == 0 then return end

	batchToken += 1
	local token = batchToken

	local hrp = getCharacterRoot()
	if not hrp then return end

	local positions = computeSpiralPositions(hrp.Position, hrp.CFrame.LookVector, #results)

	local isBatch = #results > 1

	-- Play a batch start SFX for multi-egg hatches
	if isBatch then
		SoundFacade.playOneShot("click")
	end

	for i, result in results do
		if type(result) ~= "table" then continue end

		local pos = positions[i]
		if not pos then continue end

		local delay = (i - 1) * EGG_STAGGER_SEC
		spawnAndHatchEgg(result, pos, token, delay, isBatch)
	end
end

function EggViewController.init()
	if eggViewClientInitDone then return end
	eggViewClientInitDone = true

	Remotes.getEvent("HatchEgg").OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			if result[1] ~= nil then
				EggViewController.onBatchHatchResult(result :: { any })
			else
				EggViewController.onBatchHatchResult({ result })
			end
		end
	end)
end

return EggViewController
