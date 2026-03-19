--[[
	TidePoolInteraction.lua — StarterPlayerScripts (LocalScript)
	Connects ProximityPrompts on tide pools to the server discovery system
	and plays client-side reveal animations.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game.Workspace

local player = Players.LocalPlayer

local discoverEvent = ReplicatedStorage:WaitForChild("TidePoolDiscover", 30)
local resultEvent = ReplicatedStorage:WaitForChild("TidePoolResult", 30)

if not discoverEvent or not resultEvent then
	warn("[TidePoolInteraction] RemoteEvents not found — is TidePoolServer.lua in ServerScriptService?")
	return
end

----------------------------------------------------------------------
-- FIND ALL TIDE POOL INTERACTION POINTS
----------------------------------------------------------------------
local boundPools = {}

local function bindTidePool(interactionPart)
	if boundPools[interactionPart] then return end

	local prompt = interactionPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	local poolId = interactionPart:GetAttribute("TidePoolId")
	if not poolId then return end

	boundPools[interactionPart] = true
	prompt.Triggered:Connect(function()
		discoverEvent:FireServer(poolId)
	end)
end

local function tryBindModel(model)
	if not model:IsA("Model") then return end
	local ip = model:FindFirstChild("InteractionPoint")
	if ip then
		bindTidePool(ip)
	end
end

local sunnyShore = Workspace:WaitForChild("SunnyShore", 30)
if not sunnyShore then
	warn("[TidePoolInteraction] SunnyShore model not found in Workspace")
	return
end

for _, model in ipairs(sunnyShore:GetChildren()) do
	tryBindModel(model)
end

sunnyShore.ChildAdded:Connect(tryBindModel)

----------------------------------------------------------------------
-- RARITY COLORS for the reveal card
----------------------------------------------------------------------
local RARITY_COLORS = {
	Common   = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(80, 200, 80),
	Rare     = Color3.fromRGB(60, 140, 255),
	Epic     = Color3.fromRGB(180, 60, 255),
	Legendary = Color3.fromRGB(255, 180, 30),
	Mythical  = Color3.fromRGB(255, 60, 60),
	Seasonal  = Color3.fromRGB(255, 140, 200),
}

----------------------------------------------------------------------
-- SPLASH EFFECT at tide pool location
----------------------------------------------------------------------
local function playSplash(poolId)
	local model = sunnyShore:FindFirstChild(poolId)
	if not model then return end
	local basin = model:FindFirstChild("Basin")
	if not basin then return end

	local pos = basin.Position + Vector3.new(0, 1, 0)

	for i = 1, 8 do
		local drop = Instance.new("Part")
		drop.Shape = Enum.PartType.Ball
		drop.Size = Vector3.new(0.8, 0.8, 0.8)
		drop.Color = Color3.fromRGB(180, 220, 255)
		drop.Material = Enum.Material.Neon
		drop.Anchored = true
		drop.CanCollide = false
		drop.CastShadow = false
		drop.Position = pos
		drop.Parent = Workspace

		local angle = (i / 8) * math.pi * 2
		local target = pos + Vector3.new(math.cos(angle) * 4, 3, math.sin(angle) * 4)

		local tween = TweenService:Create(drop, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
		})
		tween:Play()
		tween.Completed:Connect(function()
			drop:Destroy()
		end)
	end
end

----------------------------------------------------------------------
-- CREATURE REVEAL CARD (simple BillboardGui)
----------------------------------------------------------------------
local function showRevealCard(creatureData, poolId)
	local model = sunnyShore:FindFirstChild(poolId)
	if not model then return end
	local basin = model:FindFirstChild("Basin")
	if not basin then return end

	-- Creature preview sphere
	local preview = Instance.new("Part")
	preview.Shape = Enum.PartType.Ball
	preview.Size = Vector3.new(3, 3, 3)
	preview.Color = Color3.fromRGB(unpack(creatureData.color))
	preview.Material = Enum.Material.SmoothPlastic
	preview.Anchored = true
	preview.CanCollide = false
	preview.CastShadow = false
	preview.Position = basin.Position + Vector3.new(0, 1, 0)
	preview.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = preview

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = creatureData.name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.6, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = creatureData.rarity
	rarityLabel.TextColor3 = RARITY_COLORS[creatureData.rarity] or Color3.new(1, 1, 1)
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = billboard

	-- Animate: float up then fade out
	local floatTween = TweenService:Create(preview, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = preview.Position + Vector3.new(0, 4, 0),
	})
	floatTween:Play()

	task.delay(2.5, function()
		local fadeTween = TweenService:Create(preview, TweenInfo.new(0.5), {
			Transparency = 1,
		})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			preview:Destroy()
		end)
	end)
end

----------------------------------------------------------------------
-- HANDLE SERVER RESULT
----------------------------------------------------------------------
resultEvent.OnClientEvent:Connect(function(data)
	if data.success then
		playSplash(data.poolId)
		task.delay(0.3, function()
			showRevealCard(data.creature, data.poolId)
		end)
	else
		if data.reason == "cooldown" then
			-- Could show a small UI notification; for prototype just print
			warn(string.format("Tide pool on cooldown — %.0fs remaining", data.remaining))
		end
	end
end)
