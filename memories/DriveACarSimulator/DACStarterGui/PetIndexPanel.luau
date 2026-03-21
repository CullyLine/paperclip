--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local PetIndexPanel = {}

function PetIndexPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "PetIndexRoot")
	MenuHub.registerPanel("pets", root)
	UIHelpers.titleBar(root, "Pet Index", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrollingGrid(root)

	local function redraw()
		for _, c in scroll:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		local disc = if data and data.discoveredPets then data.discoveredPets else {}
		for pid, def in PetConfig.Pets do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0, 130, 0, 150)
			card.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
			card.Parent = scroll
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 8)
			cc.Parent = card
			local stroke = Instance.new("UIStroke")
			stroke.Color = UIHelpers.rarityStroke(def.rarity)
			stroke.Thickness = 3
			stroke.Parent = card

			local known = disc[pid] == true
			local t = Instance.new("TextLabel")
			t.Size = UDim2.new(1, -6, 1, -6)
			t.Position = UDim2.new(0, 3, 0, 3)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 13
			t.TextColor3 = Color3.fromRGB(40, 40, 40)
			t.TextWrapped = true
			t.Text = known and `{def.name}\n{def.rarity}\nPow {def.basePower}` or "???"
			t.Parent = card
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if root.Visible then
			redraw()
		end
	end)

	redraw()
end

return PetIndexPanel
