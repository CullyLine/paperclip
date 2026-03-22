--!strict
--[[
	Full-screen trophy case: grid, category filters, detail popover.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local AchievementPopupConfig = require(DAC:WaitForChild("Config"):WaitForChild("AchievementPopupConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local TrophyCasePanel = {}

local RARITY_STROKE: { [string]: Color3 } = {
	bronze = Color3.fromRGB(180, 120, 60),
	silver = Color3.fromRGB(180, 195, 210),
	gold = Color3.fromRGB(255, 213, 79),
	diamond = Color3.fromRGB(160, 220, 255),
}

local FILTER_ORDER = { "all", "driving", "collection", "economy", "social", "secret" }

local function countUnseen(data: any): number
	if type(data) ~= "table" then
		return 0
	end
	local u = data.achievementsUnlocked
	local s = data.achievementsSeen
	if type(u) ~= "table" then
		return 0
	end
	local n = 0
	for id, v in u do
		if v == true and (type(s) ~= "table" or s[id] ~= true) then
			n += 1
		end
	end
	return n
end

function TrophyCasePanel.mount(screenGui: ScreenGui, uiController: any)
	local panel = Instance.new("Frame")
	panel.Name = "TrophyCasePanel"
	panel.Size = UDim2.fromOffset(520, 480)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(16, 12, 32)
	panel.BackgroundTransparency = 0.02
	panel.ZIndex = 710
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screenGui
	panel:SetAttribute("DACOrigBg", 0.02)

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 16)
	pCorner.Parent = panel

	local pStroke = Instance.new("UIStroke")
	pStroke.Thickness = 2
	pStroke.Color = Color3.fromRGB(255, 213, 79)
	pStroke.Transparency = 0.15
	pStroke.Parent = panel

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 18, 48)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 12, 32)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 15, 40)),
	})
	gradient.Rotation = 90
	gradient.Parent = panel

	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.Size = UDim2.new(1, -80, 0, 28)
	header.Position = UDim2.new(0, 12, 0, 12)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 22
	header.TextColor3 = Color3.fromRGB(255, 213, 79)
	header.Text = "🏆 TROPHY CASE"
	header.ZIndex = 715
	header.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.ZIndex = 715
	closeBtn.Parent = panel
	local cb = Instance.new("UICorner")
	cb.CornerRadius = UDim.new(0, 8)
	cb.Parent = closeBtn

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(1, -24, 0, 20)
	progressLabel.Position = UDim2.new(0, 12, 0, 44)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextSize = 13
	progressLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	progressLabel.Text = "0/0 Achievements"
	progressLabel.ZIndex = 715
	progressLabel.Parent = panel

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBarBg"
	barBg.Size = UDim2.new(0.8, 0, 0, 10)
	barBg.Position = UDim2.new(0.5, 0, 0, 68)
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 24, 55)
	barBg.ZIndex = 715
	barBg.Parent = panel
	local barBgC = Instance.new("UICorner")
	barBgC.CornerRadius = UDim.new(0.5, 0)
	barBgC.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 213, 79)
	barFill.ZIndex = 716
	barFill.Parent = barBg
	local barFillC = Instance.new("UICorner")
	barFillC.CornerRadius = UDim.new(0.5, 0)
	barFillC.Parent = barFill

	local pctLabel = Instance.new("TextLabel")
	pctLabel.Name = "PctLabel"
	pctLabel.Size = UDim2.fromOffset(48, 14)
	pctLabel.Position = UDim2.new(0.92, 0, 0, 66)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Font = Enum.Font.GothamBlack
	pctLabel.TextSize = 12
	pctLabel.TextColor3 = Color3.fromRGB(255, 213, 79)
	pctLabel.Text = "0%"
	pctLabel.ZIndex = 715
	pctLabel.Parent = panel

	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.Size = UDim2.new(1, -24, 0, 28)
	tabRow.Position = UDim2.new(0, 12, 0, 88)
	tabRow.BackgroundTransparency = 1
	tabRow.ZIndex = 715
	tabRow.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "GridScroll"
	scroll.Size = UDim2.new(1, -24, 1, -130)
	scroll.Position = UDim2.new(0, 12, 0, 124)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 715
	scroll.Parent = panel
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(148, 72)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local tooltip = Instance.new("Frame")
	tooltip.Name = "DetailTooltip"
	tooltip.Size = UDim2.fromOffset(280, 120)
	tooltip.Position = UDim2.new(0.5, 0, 0.5, 0)
	tooltip.AnchorPoint = Vector2.new(0.5, 0.5)
	tooltip.BackgroundColor3 = Color3.fromRGB(12, 10, 28)
	tooltip.ZIndex = 720
	tooltip.Visible = false
	tooltip.Parent = panel
	local ttC = Instance.new("UICorner")
	ttC.CornerRadius = UDim.new(0, 12)
	ttC.Parent = tooltip
	local ttStroke = Instance.new("UIStroke")
	ttStroke.Thickness = 1.5
	ttStroke.Color = Color3.fromRGB(255, 213, 79)
	ttStroke.Parent = tooltip

	local ttTitle = Instance.new("TextLabel")
	ttTitle.Size = UDim2.new(1, -16, 0, 22)
	ttTitle.Position = UDim2.new(0, 8, 0, 8)
	ttTitle.BackgroundTransparency = 1
	ttTitle.Font = Enum.Font.GothamBlack
	ttTitle.TextSize = 16
	ttTitle.TextColor3 = Color3.fromRGB(255, 213, 79)
	ttTitle.TextXAlignment = Enum.TextXAlignment.Left
	ttTitle.ZIndex = 721
	ttTitle.Parent = tooltip

	local ttDesc = Instance.new("TextLabel")
	ttDesc.Size = UDim2.new(1, -16, 1, -36)
	ttDesc.Position = UDim2.new(0, 8, 0, 32)
	ttDesc.BackgroundTransparency = 1
	ttDesc.Font = Enum.Font.Gotham
	ttDesc.TextSize = 13
	ttDesc.TextColor3 = Color3.fromRGB(220, 220, 235)
	ttDesc.TextWrapped = true
	ttDesc.TextXAlignment = Enum.TextXAlignment.Left
	ttDesc.TextYAlignment = Enum.TextYAlignment.Top
	ttDesc.ZIndex = 721
	ttDesc.Parent = tooltip

	local currentFilter = "all"
	local snapshot: any = {}

	local function rarityForId(id: string): string
		local map: { [string]: string } = {
			first_drive = "bronze",
			first_hatch = "bronze",
			rebirth_one = "bronze",
			speed_demon = "bronze",
			hatch_100 = "silver",
			big_spender = "silver",
			daily_streak_7 = "silver",
			world_tourer = "gold",
			number_one = "gold",
			full_index = "diamond",
		}
		return map[id] or "bronze"
	end

	local function buildGrid()
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") and ch.Name ~= "UIGridLayout" then
				ch:Destroy()
			end
		end

		local unlocked = if type(snapshot) == "table" and type(snapshot.unlocked) == "table" then snapshot.unlocked else {}

		local totalList = AchievementPopupConfig.Achievements
		local idx = 0
		for _, ach in totalList do
			local cat = string.lower(ach.category)
			if currentFilter ~= "all" and cat ~= currentFilter then
				continue
			end
			idx += 1
			local cell = Instance.new("TextButton")
			cell.Name = "Cell_" .. ach.id
			cell.LayoutOrder = idx
			cell.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
			cell.AutoButtonColor = false
			cell.Text = ""
			cell.ZIndex = 716
			cell.Parent = scroll

			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 10)
			cc.Parent = cell

			local isOn = unlocked[ach.id] == true
			local r = rarityForId(ach.id)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = if isOn then 2 else 1.2
			stroke.Color = if isOn then RARITY_STROKE[r] or RARITY_STROKE.bronze else Color3.fromRGB(60, 50, 80)
			stroke.Transparency = if isOn then 0.2 else 0.5
			stroke.Parent = cell

			local t = Instance.new("TextLabel")
			t.Size = UDim2.new(1, -10, 1, -10)
			t.Position = UDim2.new(0, 5, 0, 5)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 12
			t.TextColor3 = if isOn then Color3.new(1, 1, 1) else Color3.fromRGB(120, 110, 150)
			t.TextWrapped = true
			t.Text = ach.title
			t.ZIndex = 717
			t.Parent = cell

			cell.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("click")
				tooltip.Visible = true
				ttTitle.Text = ach.title
				ttDesc.Text = ach.description
			end)
		end
	end

	local function refreshProgressHeader()
		local total = #AchievementPopupConfig.Achievements
		local unlockedN = 0
		if type(snapshot) == "table" and type(snapshot.unlocked) == "table" then
			for _, ach in AchievementPopupConfig.Achievements do
				if snapshot.unlocked[ach.id] == true then
					unlockedN += 1
				end
			end
		end
		progressLabel.Text = `{unlockedN}/{total} Achievements Unlocked`
		local pct = if total > 0 then math.floor((unlockedN / total) * 100 + 0.5) else 0
		pctLabel.Text = `{pct}%`
		TweenService:Create(barFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(if total > 0 then unlockedN / total else 0, 0, 1, 0),
		}):Play()
	end

	local function refreshSnapshotFromServer()
		local ok, snap = pcall(function()
			return Remotes.getFunction("GetAchievementData"):InvokeServer()
		end)
		if ok and type(snap) == "table" then
			snapshot = snap
			buildGrid()
			refreshProgressHeader()
		end
	end

	local notifDot: Frame? = nil
	local notifLabel: TextLabel? = nil

	local function updateTrophyBadge(data: any)
		if not notifDot or not notifLabel then
			return
		end
		local n = countUnseen(data)
		notifDot.Visible = n > 0
		notifLabel.Text = tostring(math.min(n, 99))
	end

	local function wireTabs()
		for _, child in tabRow:GetChildren() do
			if child:IsA("GuiObject") and child.Name:sub(1, 4) == "Tab_" then
				child:Destroy()
			end
		end
		for _, key in FILTER_ORDER do
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. key
			b.Size = UDim2.fromOffset(key == "all" and 44 or 72, 26)
			b.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 11
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = string.upper(key)
			b.ZIndex = 715
			b.Parent = tabRow
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 8)
			bc.Parent = b
			b.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("tab_switch")
				currentFilter = key
				buildGrid()
			end)
		end
	end

	wireTabs()

	closeBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("panel_close")
		uiController.closeAll()
	end)

	uiController.registerPanel("trophyCase", panel)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			tooltip.Visible = false
			refreshSnapshotFromServer()
			Remotes.getEvent("MarkAchievementsSeen"):FireServer()
			local ok, data = pcall(function()
				return Remotes.getFunction("GetPlayerData"):InvokeServer()
			end)
			if ok and type(data) == "table" then
				updateTrophyBadge(data)
			end
		end
	end)

	local player = Players.LocalPlayer
	task.defer(function()
		local pg = player:WaitForChild("PlayerGui") :: PlayerGui
		local dacMain = pg:WaitForChild("DACMain")

		-- TrophyTab lives in the Inventory TabBar (created by UIController).
		local invPanel = dacMain:WaitForChild("Panels"):FindFirstChild("Inventory")
		local tabBar = invPanel and invPanel:FindFirstChild("TabBar")
		local tbtn = tabBar and tabBar:FindFirstChild("TrophyTab")

		if tbtn and tbtn:IsA("ImageButton") then
			local dot = Instance.new("Frame")
			dot.Name = "TrophyNotifDot"
			dot.Size = UDim2.fromOffset(14, 14)
			dot.Position = UDim2.new(1, -2, 0, -2)
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			dot.Visible = false
			dot.ZIndex = 52
			dot.Parent = tbtn
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(0.5, 0)
			dc.Parent = dot
			local cnt = Instance.new("TextLabel")
			cnt.Name = "Count"
			cnt.Size = UDim2.fromScale(1, 1)
			cnt.BackgroundTransparency = 1
			cnt.Font = Enum.Font.GothamBlack
			cnt.TextSize = 9
			cnt.TextColor3 = Color3.new(1, 1, 1)
			cnt.Text = "0"
			cnt.ZIndex = 53
			cnt.Parent = dot

			notifDot = dot
			notifLabel = cnt
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data: any)
		updateTrophyBadge(data)
	end)

	Remotes.getEvent("AchievementUnlocked").OnClientEvent:Connect(function()
		task.defer(refreshSnapshotFromServer)
	end)

	task.defer(function()
		local ok, data = pcall(function()
			return Remotes.getFunction("GetPlayerData"):InvokeServer()
		end)
		if ok and type(data) == "table" then
			updateTrophyBadge(data)
		end
	end)
end

return TrophyCasePanel
