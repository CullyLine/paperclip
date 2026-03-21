--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local GamePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("GamePassConfig"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local StorePanel = {}

function StorePanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "StoreRoot")
	MenuHub.registerPanel("store", root)
	UIHelpers.titleBar(root, "Store & Robux", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)

	local function addHeader(text: string, layoutOrder: number?)
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 28)
		h.BackgroundTransparency = 1
		h.Font = Enum.Font.GothamBold
		h.TextSize = 18
		h.TextColor3 = Color3.fromRGB(255, 213, 79)
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Text = text
		h.LayoutOrder = layoutOrder or -100
		h.Parent = scroll
	end

	addHeader("Car upgrades (equipped car)", -220)

	local upgradeLabels: { [string]: TextLabel } = {}
	local function refreshUpgrades()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if type(data) ~= "table" or not data.equippedCar then
			return
		end
		local carId = data.equippedCar
		local owned = data.cars and data.cars[carId]
		if not owned then
			return
		end
		for _, stat in { "gas", "power", "speed" } do
			local statConfig = UpgradeConfig.Stats[stat]
			local levelKey = stat .. "Level"
			local lvl = owned[levelKey] or 0
			local cost = Utils.getUpgradeCost(statConfig.baseCost, statConfig.costMultiplier, lvl)
			local lbl = upgradeLabels[stat]
			if lbl then
				lbl.Text = `{string.upper(string.sub(stat, 1, 1))}{string.sub(stat, 2)} Lv {lvl} → {Utils.formatNumber(cost)} coins`
			end
		end
	end

	local upLayout = -219
	for _, stat in { "gas", "power", "speed" } do
		upLayout += 1
		local statConfig = UpgradeConfig.Stats[stat]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(34, 40, 72)
		row.LayoutOrder = upLayout
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.62, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = statConfig.currency .. " upgrade"
		lbl.Parent = row
		upgradeLabels[stat] = lbl

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.32, 0, 0, 34)
		btn.Position = UDim2.new(0.65, 0, 0.5, -17)
		btn.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
		btn.TextColor3 = Color3.fromRGB(30, 30, 30)
		btn.Font = Enum.Font.GothamBold
		btn.Text = "Upgrade"
		btn.Parent = row
		if stat == "speed" then
			btn.Name = "TutorialUpgradeSpeed"
		end
		btn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
			if type(data) == "table" and type(data.equippedCar) == "string" then
				Remotes.getEvent("UpgradeStat"):FireServer(data.equippedCar, stat)
			end
		end)
	end

	refreshUpgrades()
	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if root.Visible then
			refreshUpgrades()
		end
	end)

	local order = 0
	addHeader("Cars (soft currency)")
	for carId, def in CarConfig.Cars do
		if def.price <= 0 then
			continue
		end
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.65, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 14
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = `{def.name}  •  {Utils.formatNumber(def.price)} {def.currency}  ({def.worldId})`
		lbl.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.28, 0, 0, 36)
		buy.Position = UDim2.new(0.7, 0, 0.5, -18)
		buy.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
		buy.Text = "Buy"
		buy.TextColor3 = Color3.fromRGB(30, 30, 30)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("BuyCar"):FireServer(carId)
		end)
	end

	addHeader("Game Passes")
	for passId, def in GamePassConfig.Passes do
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(36, 50, 80)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextWrapped = true
		lbl.Text = `{def.name} — {def.robuxPrice}R\n{def.description}`
		lbl.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.22, 0, 0, 32)
		buy.Position = UDim2.new(0.76, 0, 0.5, -16)
		buy.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		buy.Text = "Robux"
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("PurchaseGamePass"):FireServer(passId)
		end)
	end

	addHeader("Developer Products")
	for pid, def in DevProductConfig.Products do
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(50, 36, 70)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextWrapped = true
		lbl.Text = `{def.name} — {def.robuxPrice}R`
		lbl.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.22, 0, 0, 32)
		buy.Position = UDim2.new(0.76, 0, 0.5, -16)
		buy.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
		buy.Text = "Buy"
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("PurchaseDevProduct"):FireServer(pid)
		end)
	end
end

return StorePanel
