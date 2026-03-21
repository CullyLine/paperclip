--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local InventoryPanel = {}

local function refresh(scroll: ScrollingFrame, data: any)
	for _, c in scroll:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not data or not data.cars then
		return
	end
	local equipped = data.equippedCar
	for carId, owned in data.cars do
		local def = CarConfig.Cars[carId]
		if not def then
			continue
		end
		local unlocked = data.unlockedWorlds[def.worldId]
		local card = Instance.new("Frame")
		card.Name = carId
		card.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		card.BorderSizePixel = 0
		card.Parent = scroll
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Color = UIHelpers.rarityStroke(def.worldId == "neon" and "legendary" or "rare")
		stroke.Thickness = equipped == carId and 4 or 2
		stroke.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -8, 0, 40)
		title.Position = UDim2.new(0, 4, 0, 4)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.fromRGB(30, 30, 30)
		title.TextWrapped = true
		title.Text = def.name
		title.Parent = card

		local stats = Instance.new("TextLabel")
		stats.Size = UDim2.new(1, -8, 0, 60)
		stats.Position = UDim2.new(0, 4, 0, 44)
		stats.BackgroundTransparency = 1
		stats.Font = Enum.Font.Gotham
		stats.TextSize = 12
		stats.TextColor3 = Color3.fromRGB(60, 60, 60)
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.TextWrapped = true
		stats.Parent = card

		if unlocked then
			local o = owned
			stats.Text = `Lv {o.gasLevel}/{o.powerLevel}/{o.speedLevel}\nBase {def.baseStats.gas}/{def.baseStats.power}/{def.baseStats.speed}`
		else
			stats.Text = `Locked — unlock {def.worldId}`
			card.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end

		local equip = Instance.new("TextButton")
		equip.Size = UDim2.new(1, -8, 0, 28)
		equip.Position = UDim2.new(0, 4, 1, -32)
		equip.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
		equip.Text = equipped == carId and "Equipped" or "Equip"
		equip.TextColor3 = Color3.new(1, 1, 1)
		equip.Font = Enum.Font.GothamBold
		equip.AutoButtonColor = unlocked == true
		equip.Parent = card
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0, 6)
		ec.Parent = equip
		if unlocked then
			equip.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("click")
				Remotes.getEvent("EquipCar"):FireServer(carId)
			end)
		else
			equip.AutoButtonColor = false
		end
	end

	for carId, def in CarConfig.Cars do
		if data.cars[carId] then
			continue
		end
		local unlocked = data.unlockedWorlds[def.worldId]
		local card = Instance.new("Frame")
		card.Name = "locked_" .. carId
		card.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		card.BorderSizePixel = 0
		card.Parent = scroll
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = card

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -6, 0, 80)
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.fromRGB(200, 200, 200)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 13
		t.TextWrapped = true
		t.Text = def.name .. "\n???"
		t.Parent = card

		local price = Instance.new("TextLabel")
		price.Size = UDim2.new(1, -6, 0, 40)
		price.Position = UDim2.new(0, 0, 0, 80)
		price.BackgroundTransparency = 1
		price.Text = if def.price <= 0 then "Free" else `{Utils.formatNumber(def.price)} {def.currency}`
		price.TextColor3 = Color3.fromRGB(255, 213, 79)
		price.Parent = card

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(1, -8, 0, 26)
		buy.Position = UDim2.new(0, 4, 1, -30)
		buy.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
		buy.Text = "Buy"
		buy.TextColor3 = Color3.fromRGB(40, 40, 40)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = card
		buy.MouseButton1Click:Connect(function()
			if unlocked then
				SoundFacade.playOneShot("purchase")
				Remotes.getEvent("BuyCar"):FireServer(carId)
			end
		end)
	end

	if data.pets then
		local petsList: { { uid: string, pet: any } } = {}
		for uid, pet in data.pets do
			table.insert(petsList, { uid = uid, pet = pet })
		end
		table.sort(petsList, function(a, b)
			return a.uid < b.uid
		end)

		local markedTutorial = false
		local po = 5000
		for _, entry in petsList do
			po += 1
			local uid = entry.uid
			local pet = entry.pet
			local def = PetConfig.Pets[pet.id]
			local card = Instance.new("Frame")
			card.LayoutOrder = po
			card.Size = UDim2.new(0, 130, 0, 120)
			card.BackgroundColor3 = Color3.fromRGB(230, 230, 250)
			card.Parent = scroll
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 8)
			cc.Parent = card

			local t = Instance.new("TextLabel")
			t.Size = UDim2.new(1, -6, 0, 56)
			t.Position = UDim2.new(0, 3, 0, 4)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 12
			t.TextColor3 = Color3.fromRGB(30, 30, 30)
			t.TextWrapped = true
			t.Text = def and `{def.name}\nPow {pet.power}` or pet.id
			t.Parent = card

			local equip = Instance.new("TextButton")
			equip.Size = UDim2.new(1, -8, 0, 28)
			equip.Position = UDim2.new(0, 4, 1, -32)
			equip.BackgroundColor3 = Color3.fromRGB(63, 81, 181)
			equip.Text = pet.equipped and "Equipped" or "Equip"
			equip.TextColor3 = Color3.new(1, 1, 1)
			equip.Font = Enum.Font.GothamBold
			equip.Parent = card
			local ec = Instance.new("UICorner")
			ec.CornerRadius = UDim.new(0, 6)
			ec.Parent = equip

			if not pet.equipped and not markedTutorial then
				equip.Name = "TutorialPetEquipFirst"
				markedTutorial = true
			end

			equip.MouseButton1Click:Connect(function()
				if pet.equipped then
					return
				end
				SoundFacade.playOneShot("click")
				Remotes.getEvent("EquipPet"):FireServer(uid)
			end)
		end
	end
end

function InventoryPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "InventoryRoot")
	MenuHub.registerPanel("inventory", root)
	UIHelpers.titleBar(root, "Garage", function()
		root.Visible = false
	end)
	local scroll = UIHelpers.scrollingGrid(root)

	local function redraw()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		refresh(scroll, data)
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		refresh(scroll, data)
	end)

	redraw()
end

return InventoryPanel
