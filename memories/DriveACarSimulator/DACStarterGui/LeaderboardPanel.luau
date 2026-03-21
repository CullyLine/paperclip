--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local LeaderboardPanel = {}

local GOLD = Color3.fromRGB(255, 215, 64)
local SILVER = Color3.fromRGB(210, 210, 220)
local BRONZE = Color3.fromRGB(205, 127, 70)

local STAT_DISTANCE = "totalDistance"
local STAT_REBIRTHS = "totalRebirths"

function LeaderboardPanel.init()
	local player = Players.LocalPlayer
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "LeaderboardRoot")
	MenuHub.registerPanel("leaderboard", root)
	UIHelpers.titleBar(root, "Leaderboard", function()
		root.Visible = false
	end)

	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.Size = UDim2.new(1, -24, 0, 36)
	tabRow.Position = UDim2.new(0, 12, 0, 48)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = root

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabList.Padding = UDim.new(0, 10)
	tabList.Parent = tabRow

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.new(1, -24, 1, -100)
	scroll.Position = UDim2.new(0, 12, 0, 92)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = root

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = scroll

	local currentStat = STAT_DISTANCE
	local tabButtons: { [string]: TextButton } = {}

	local function rankColor(rank: number): Color3
		if rank == 1 then
			return GOLD
		elseif rank == 2 then
			return SILVER
		elseif rank == 3 then
			return BRONZE
		end
		return Color3.fromRGB(230, 230, 245)
	end

	local function formatScore(stat: string, value: number): string
		if stat == STAT_DISTANCE then
			return `{Utils.formatNumber(value)} studs`
		end
		return tostring(math.floor(value))
	end

	local function clearRows()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") and child.Name == "Row" then
				child:Destroy()
			end
		end
	end

	local function setTabVisual(active: string)
		for id, btn in tabButtons do
			local on = id == active
			btn.BackgroundColor3 = if on then Color3.fromRGB(70, 120, 220) else Color3.fromRGB(45, 45, 70)
			btn.TextColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(180, 180, 200)
		end
	end

	local function refresh()
		clearRows()
		local ok, rows = pcall(function()
			return Remotes.getFunction("GetLeaderboard"):InvokeServer(currentStat)
		end)
		if not ok or type(rows) ~= "table" then
			return
		end

		local myId = player.UserId
		for i, entry in ipairs(rows) do
			if type(entry) ~= "table" then
				continue
			end
			local userId = tonumber(entry.userId) or 0
			local value = tonumber(entry.value) or 0
			local nameStr = if type(entry.name) == "string" and entry.name ~= "" then entry.name else "Unknown"
			local rank = i
			local isSelf = userId == myId and userId ~= 0

			local row = Instance.new("Frame")
			row.Name = "Row"
			row.Size = UDim2.new(1, -8, 0, 34)
			row.BackgroundColor3 = if isSelf then Color3.fromRGB(40, 55, 90) else Color3.fromRGB(28, 28, 52)
			row.BackgroundTransparency = if isSelf then 0.1 else 0.25
			row.BorderSizePixel = 0
			row.LayoutOrder = rank
			row.Parent = scroll

			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 8)
			rc.Parent = row

			if isSelf then
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(120, 200, 140)
				stroke.Thickness = 2
				stroke.Transparency = 0.2
				stroke.Parent = row
			end

			local rankLbl = Instance.new("TextLabel")
			rankLbl.Size = UDim2.new(0, 40, 1, 0)
			rankLbl.Position = UDim2.new(0, 8, 0, 0)
			rankLbl.BackgroundTransparency = 1
			rankLbl.Font = Enum.Font.GothamBold
			rankLbl.TextSize = 16
			rankLbl.TextXAlignment = Enum.TextXAlignment.Left
			rankLbl.Text = `#${rank}`
			rankLbl.TextColor3 = rankColor(rank)
			rankLbl.Parent = row

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -160, 1, 0)
			nameLbl.Position = UDim2.new(0, 52, 0, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.Gotham
			nameLbl.TextSize = 14
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.Text = nameStr
			nameLbl.TextColor3 = if isSelf then Color3.fromRGB(200, 255, 210) else Color3.fromRGB(235, 235, 245)
			nameLbl.Parent = row

			local scoreLbl = Instance.new("TextLabel")
			scoreLbl.Size = UDim2.new(0, 120, 1, 0)
			scoreLbl.Position = UDim2.new(1, -128, 0, 0)
			scoreLbl.BackgroundTransparency = 1
			scoreLbl.Font = Enum.Font.GothamBold
			scoreLbl.TextSize = 14
			scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
			scoreLbl.Text = formatScore(currentStat, value)
			scoreLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
			scoreLbl.Parent = row
		end
	end

	local function mkTab(id: string, label: string)
		local b = Instance.new("TextButton")
		b.Name = id
		b.Size = UDim2.new(0, 140, 0, 32)
		b.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
		b.Text = label
		b.TextColor3 = Color3.fromRGB(180, 180, 200)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.AutoButtonColor = true
		b.Parent = tabRow
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		tabButtons[id] = b
		b.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			currentStat = id
			setTabVisual(id)
			refresh()
		end)
	end

	mkTab(STAT_DISTANCE, "Distance")
	mkTab(STAT_REBIRTHS, "Rebirths")
	setTabVisual(STAT_DISTANCE)

	local loopId = 0
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			loopId += 1
			local myLoop = loopId
			refresh()
			task.spawn(function()
				while myLoop == loopId and root.Visible do
					task.wait(30)
					if myLoop ~= loopId or not root.Visible then
						break
					end
					refresh()
				end
			end)
		else
			loopId += 1
		end
	end)
end

return LeaderboardPanel
