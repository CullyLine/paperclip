--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local WorldPanel = {}

local ACCENT: { [string]: Color3 } = {
	grasslands = Color3.fromRGB(56, 170, 80),
	desert = Color3.fromRGB(255, 152, 0),
	frozen = Color3.fromRGB(90, 160, 240),
	neon = Color3.fromRGB(210, 60, 255),
}

local function coinMultLabel(mult: number): string
	if math.abs(mult - math.floor(mult)) < 1e-6 then
		return `{math.floor(mult)}x Coins`
	end
	return `{string.format("%.1f", mult)}x Coins`
end

local function highwayLabel(studs: number): string
	return `{Utils.formatNumber(studs)} studs highway`
end

function WorldPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "WorldRoot")
	MenuHub.registerPanel("worlds", root)
	UIHelpers.titleBar(root, "Worlds", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)

	type RowRefs = {
		stroke: UIStroke,
		currentBadge: TextLabel,
		action: TextButton,
		status: TextLabel,
	}

	local rows: { [string]: RowRefs } = {}

	local function refresh()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if type(data) ~= "table" then
			return
		end
		local unlockedWorlds = data.unlockedWorlds
		local currentWorld = data.currentWorld

		for worldId, refs in rows do
			local world = WorldConfig.Worlds[worldId]
			if not world then
				continue
			end
			local unlocked = type(unlockedWorlds) == "table" and unlockedWorlds[worldId] == true
			local here = type(currentWorld) == "string" and currentWorld == worldId
			local accent = ACCENT[worldId] or Color3.fromRGB(120, 160, 255)

			refs.stroke.Color = accent
			refs.currentBadge.Visible = here

			if unlocked then
				if here then
					refs.action.Text = "You are here"
					refs.action.AutoButtonColor = false
					refs.action.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
					refs.action.Active = false
					refs.action.Selectable = false
				else
					refs.action.Text = "Travel"
					refs.action.AutoButtonColor = true
					refs.action.BackgroundColor3 = Color3.fromRGB(70, 120, 220)
					refs.action.Active = true
					refs.action.Selectable = true
				end
				if world.unlockCost > 0 then
					refs.status.Text = "Unlocked"
				else
					refs.status.Text = "Starter world"
				end
				refs.status.TextColor3 = Color3.fromRGB(140, 220, 140)
			else
				refs.action.Text = "Unlock"
				refs.action.AutoButtonColor = true
				refs.action.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
				refs.action.Active = true
				refs.action.Selectable = true
				if world.unlockCost <= 0 then
					refs.status.Text = "Free"
				else
					local cur = world.unlockCurrency
					local curColor = UIHelpers.currencyColor(cur)
					refs.status.Text = `Locked • {Utils.formatNumber(world.unlockCost)} {cur}`
					refs.status.TextColor3 = curColor
				end
			end
		end
	end

	local layoutOrder = 0
	for _, w in WorldConfig.getWorldsSorted() do
		local world = WorldConfig.Worlds[w.id]
		if not world then
			continue
		end
		layoutOrder += 1
		local worldId = world.id
		local accent = ACCENT[worldId] or Color3.fromRGB(120, 160, 255)

		local row = Instance.new("Frame")
		row.Name = "World_" .. worldId
		row.Size = UDim2.new(1, -12, 0, 132)
		row.BackgroundColor3 = Color3.fromRGB(26, 28, 46)
		row.LayoutOrder = layoutOrder
		row.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 2
		stroke.Transparency = 0.35
		stroke.Parent = row

		local badge = Instance.new("TextLabel")
		badge.Name = "CurrentBadge"
		badge.Size = UDim2.new(0, 120, 0, 22)
		badge.Position = UDim2.new(1, -128, 0, 8)
		badge.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
		badge.BackgroundTransparency = 0.2
		badge.Font = Enum.Font.GothamBold
		badge.TextSize = 12
		badge.TextColor3 = Color3.fromRGB(200, 255, 210)
		badge.Text = "CURRENT WORLD"
		badge.Visible = false
		badge.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = badge

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -140, 0, 24)
		title.Position = UDim2.new(0, 12, 0, 8)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = accent
		title.Text = world.name
		title.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -24, 0, 36)
		desc.Position = UDim2.new(0, 12, 0, 34)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 13
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.TextColor3 = Color3.fromRGB(220, 220, 235)
		desc.Text = world.description
		desc.Parent = row

		local stats = Instance.new("TextLabel")
		stats.Size = UDim2.new(1, -24, 0, 18)
		stats.Position = UDim2.new(0, 12, 0, 74)
		stats.BackgroundTransparency = 1
		stats.Font = Enum.Font.Gotham
		stats.TextSize = 13
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextColor3 = Color3.fromRGB(180, 190, 220)
		stats.Text = `{coinMultLabel(world.coinMultiplier)}  •  {highwayLabel(world.highwayLength)}`
		stats.Parent = row

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Size = UDim2.new(0.55, -16, 0, 22)
		status.Position = UDim2.new(0, 12, 1, -30)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.Gotham
		status.TextSize = 13
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextColor3 = Color3.fromRGB(200, 200, 210)
		status.Text = ""
		status.Parent = row

		local action = Instance.new("TextButton")
		action.Name = "Action"
		action.Size = UDim2.new(0.38, -8, 0, 36)
		action.Position = UDim2.new(0.58, 0, 1, -32)
		action.Font = Enum.Font.GothamBold
		action.TextSize = 15
		action.TextColor3 = Color3.new(1, 1, 1)
		action.Parent = row
		local ac = Instance.new("UICorner")
		ac.CornerRadius = UDim.new(0, 8)
		ac.Parent = action

		action.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
			if type(data) ~= "table" or type(data.unlockedWorlds) ~= "table" then
				return
			end
			local unlocked = data.unlockedWorlds[worldId] == true
			local here = type(data.currentWorld) == "string" and data.currentWorld == worldId
			if here then
				return
			end
			if unlocked then
				Remotes.getEvent("ChangeWorld"):FireServer(worldId)
			else
				Remotes.getEvent("UnlockWorld"):FireServer(worldId)
			end
		end)

		rows[worldId] = {
			stroke = stroke,
			currentBadge = badge,
			action = action,
			status = status,
		}
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refresh()
		end
	end)

	refresh()
	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if root.Visible then
			refresh()
		end
	end)
end

return WorldPanel
