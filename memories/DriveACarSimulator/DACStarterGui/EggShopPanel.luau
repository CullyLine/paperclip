--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local EggShopPanel = {}

local function dropPreview(drops: { any }): string
	local total = 0
	for _, d in drops do
		total += d.weight
	end
	local lines = {}
	for _, d in drops do
		local pet = PetConfig.Pets[d.petId]
		local pct = total > 0 and (d.weight / total * 100) or 0
		table.insert(lines, `{pet and pet.name or d.petId} ({d.rarity}): {string.format("%.1f", pct)}%`)
	end
	return table.concat(lines, "\n")
end

function EggShopPanel.init()
	Remotes.getEvent("HatchEgg").OnClientEvent:Connect(function(result)
		VFXFacade.hatchReveal(result)
	end)

	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "EggShopRoot")
	MenuHub.registerPanel("eggs", root)
	UIHelpers.titleBar(root, "Egg Shop", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)

	for eid, egg in EggConfig.Eggs do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 120)
		row.BackgroundColor3 = Color3.fromRGB(44, 40, 70)
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = row

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0.45, 0, 0, 24)
		t.Position = UDim2.new(0, 10, 0, 6)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 16
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = egg.name
		t.Parent = row

		local p = Instance.new("TextLabel")
		p.Size = UDim2.new(0.45, 0, 0, 22)
		p.Position = UDim2.new(0, 10, 0, 30)
		p.BackgroundTransparency = 1
		p.Font = Enum.Font.Gotham
		p.TextSize = 14
		p.TextColor3 = Color3.fromRGB(255, 213, 79)
		p.TextXAlignment = Enum.TextXAlignment.Left
		p.Text = `{Utils.formatNumber(egg.price)} {egg.currency} • {egg.worldId}`
		p.Parent = row

		local rates = Instance.new("TextLabel")
		rates.Size = UDim2.new(0.55, -8, 1, -44)
		rates.Position = UDim2.new(0.42, 0, 0, 4)
		rates.BackgroundTransparency = 1
		rates.Font = Enum.Font.Code
		rates.TextSize = 11
		rates.TextColor3 = Color3.fromRGB(200, 200, 220)
		rates.TextXAlignment = Enum.TextXAlignment.Left
		rates.TextYAlignment = Enum.TextYAlignment.Top
		rates.TextWrapped = true
		rates.Text = dropPreview(egg.drops)
		rates.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.2, 0, 0, 32)
		buy.Position = UDim2.new(0.1, 0, 1, -38)
		buy.BackgroundColor3 = Color3.fromRGB(129, 199, 132)
		buy.Text = "Buy Egg"
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("BuyEgg"):FireServer(eid)
		end)

		local hatch = Instance.new("TextButton")
		hatch.Size = UDim2.new(0.2, 0, 0, 32)
		hatch.Position = UDim2.new(0.35, 0, 1, -38)
		hatch.BackgroundColor3 = Color3.fromRGB(171, 71, 188)
		hatch.Text = "Hatch 1"
		hatch.Font = Enum.Font.GothamBold
		hatch.Parent = row
		if eid == "basic_egg" then
			hatch.Name = "TutorialEggHatchBasic"
		end
		hatch.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("hatch")
			Remotes.getEvent("HatchEgg"):FireServer(eid)
		end)
	end
end

return EggShopPanel
