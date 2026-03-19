--[[
	AquariumCreaturePlacement.lua — StarterPlayerScripts (LocalScript)
	Handles creature placement UI and drag-drop into tank slots.
	Listens for state updates from AquariumServer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game.Workspace

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

local placeCreatureEvent = ReplicatedStorage:WaitForChild("AquariumPlaceCreature")
local removeCreatureEvent = ReplicatedStorage:WaitForChild("AquariumRemoveCreature")
local aquariumStateEvent = ReplicatedStorage:WaitForChild("AquariumStateUpdate")

----------------------------------------------------------------------
-- RARITY VISUALS
----------------------------------------------------------------------
local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80, 200, 80),
	Rare      = Color3.fromRGB(60, 140, 255),
	Epic      = Color3.fromRGB(180, 60, 255),
	Legendary = Color3.fromRGB(255, 180, 30),
	Mythical  = Color3.fromRGB(255, 60, 60),
	Seasonal  = Color3.fromRGB(255, 140, 200),
}

local GROWTH_SCALE = {
	baby = 0.5,
	juvenile = 0.75,
	adult = 1.0,
}

----------------------------------------------------------------------
-- FIND AQUARIUM TEMPLATE IN WORKSPACE
----------------------------------------------------------------------
local function findAquarium()
	return Workspace:FindFirstChild("AquariumTemplate_Preview")
		or Workspace:FindFirstChild("AquariumTemplate")
end

local function findSlots()
	local aquarium = findAquarium()
	if not aquarium then return {} end

	local tank = aquarium:FindFirstChild("StarterTank")
	if not tank then return {} end

	local slotsFolder = tank:FindFirstChild("CreatureSlots")
	if not slotsFolder then return {} end

	local slots = {}
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		local idx = slot:GetAttribute("SlotIndex")
		if idx then
			slots[idx] = slot
		end
	end
	return slots
end

----------------------------------------------------------------------
-- CREATURE VISUAL (placeholder sphere + billboard)
----------------------------------------------------------------------
local creatureVisuals = {} -- [slotIndex] = { model, billboard }

local function createCreatureVisual(slotPart, creatureData, growthStage)
	local scale = GROWTH_SCALE[growthStage] or 0.5
	local baseSize = 2.5

	local visual = Instance.new("Part")
	visual.Name = "Creature_" .. (creatureData.name or "Unknown")
	visual.Shape = Enum.PartType.Ball
	visual.Size = Vector3.new(baseSize * scale, baseSize * scale, baseSize * scale)
	visual.Position = slotPart.Position
	visual.Color = Color3.fromRGB(unpack(creatureData.color or {180, 180, 180}))
	visual.Material = Enum.Material.SmoothPlastic
	visual.Anchored = true
	visual.CanCollide = false
	visual.CastShadow = false
	visual.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 50)
	billboard.StudsOffset = Vector3.new(0, baseSize * scale + 1, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = visual

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = creatureData.name or "Unknown"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0.35, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.55, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = (growthStage or "baby") .. " • " .. (creatureData.rarity or "Common")
	rarityLabel.TextColor3 = RARITY_COLORS[creatureData.rarity] or Color3.new(1, 1, 1)
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Parent = billboard

	-- Idle bob animation
	local startY = slotPart.Position.Y
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not visual.Parent then
			conn:Disconnect()
			return
		end
		local t = tick()
		visual.Position = Vector3.new(
			slotPart.Position.X + math.sin(t * 0.8) * 0.3,
			startY + math.sin(t * 1.2) * 0.5,
			slotPart.Position.Z + math.cos(t * 0.6) * 0.3
		)
	end)

	return { model = visual, billboard = billboard, connection = conn }
end

local function removeCreatureVisual(slotIndex)
	local vis = creatureVisuals[slotIndex]
	if vis then
		if vis.connection then vis.connection:Disconnect() end
		if vis.model then vis.model:Destroy() end
		creatureVisuals[slotIndex] = nil
	end
end

----------------------------------------------------------------------
-- SLOT HIGHLIGHT (shows available slots during placement mode)
----------------------------------------------------------------------
local slotHighlights = {}
local placementMode = false

local function showSlotHighlights()
	hideSlotHighlights()
	local slots = findSlots()
	for idx, slot in pairs(slots) do
		if not slot:GetAttribute("Occupied") then
			local highlight = Instance.new("Part")
			highlight.Name = "SlotHighlight"
			highlight.Shape = Enum.PartType.Ball
			highlight.Size = Vector3.new(3, 3, 3)
			highlight.Position = slot.Position
			highlight.Color = Color3.fromRGB(100, 255, 150)
			highlight.Material = Enum.Material.Neon
			highlight.Transparency = 0.5
			highlight.Anchored = true
			highlight.CanCollide = false
			highlight.CastShadow = false
			highlight.Parent = Workspace

			local pulse = TweenService:Create(highlight,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.8, Size = Vector3.new(3.5, 3.5, 3.5) }
			)
			pulse:Play()

			slotHighlights[idx] = highlight
		end
	end
end

function hideSlotHighlights()
	for _, h in pairs(slotHighlights) do
		h:Destroy()
	end
	slotHighlights = {}
end

----------------------------------------------------------------------
-- PLACEMENT INTERACTION
-- In a full game, the player would select from inventory.
-- For this prototype, we fire placement directly from the tide pool
-- discovery result via TidePoolResult remote.
----------------------------------------------------------------------
local pendingCreature = nil

local function startPlacement(creatureData)
	pendingCreature = creatureData
	placementMode = true
	showSlotHighlights()
end

local function cancelPlacement()
	pendingCreature = nil
	placementMode = false
	hideSlotHighlights()
end

mouse.Button1Down:Connect(function()
	if not placementMode or not pendingCreature then return end

	local target = mouse.Target
	if not target then return end

	-- Check if clicked on a slot highlight or near a slot
	local slots = findSlots()
	local closestSlot, closestDist = nil, 8

	for idx, slot in pairs(slots) do
		if not slot:GetAttribute("Occupied") then
			local dist = (mouse.Hit.Position - slot.Position).Magnitude
			if dist < closestDist then
				closestSlot = idx
				closestDist = dist
			end
		end
	end

	if closestSlot then
		placeCreatureEvent:FireServer({
			slotIndex = closestSlot,
			creatureId = pendingCreature.id,
			name = pendingCreature.name,
			species = pendingCreature.species,
			rarity = pendingCreature.rarity,
			color = pendingCreature.color,
		})
		cancelPlacement()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.X and placementMode then
		cancelPlacement()
	end
end)

----------------------------------------------------------------------
-- HANDLE SERVER STATE UPDATES
----------------------------------------------------------------------
aquariumStateEvent.OnClientEvent:Connect(function(data)
	if data.action == "placed" then
		local slots = findSlots()
		local slot = slots[data.slotIndex]
		if slot then
			slot:SetAttribute("Occupied", true)
			slot:SetAttribute("CreatureId", data.creature.id)
			removeCreatureVisual(data.slotIndex)
			creatureVisuals[data.slotIndex] = createCreatureVisual(
				slot, data.creature, data.growthStage
			)
		end

	elseif data.action == "removed" then
		local slots = findSlots()
		local slot = slots[data.slotIndex]
		if slot then
			slot:SetAttribute("Occupied", false)
			slot:SetAttribute("CreatureId", "")
		end
		removeCreatureVisual(data.slotIndex)

	elseif data.action == "sync" then
		local slots = findSlots()
		for slotIndex, info in pairs(data.creatures or {}) do
			local slot = slots[slotIndex]
			if slot then
				slot:SetAttribute("Occupied", true)
				slot:SetAttribute("CreatureId", info.creature.id)
				removeCreatureVisual(slotIndex)
				creatureVisuals[slotIndex] = createCreatureVisual(
					slot, info.creature, info.growthStage
				)
			end
		end
	end
end)

----------------------------------------------------------------------
-- EXPOSE PLACEMENT API (other scripts can call to start placement)
----------------------------------------------------------------------
local module = {}
module.StartPlacement = startPlacement
module.CancelPlacement = cancelPlacement

-- Store on player for cross-script access
local bindable = Instance.new("BindableEvent")
bindable.Name = "AquariumPlacementTrigger"
bindable.Parent = ReplicatedStorage

bindable.Event:Connect(function(creatureData)
	startPlacement(creatureData)
end)

print("[AquariumCreaturePlacement] Initialized — click slot highlights to place creatures")
