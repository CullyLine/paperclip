--!strict
--[[
	Full-screen trophy case: grid, category filters, detail popover.
	Shell UI pre-built in DACMain.Panels.TrophyCase; this script wires behavior.
	Grid cells and filter tabs are created dynamically.
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
	if type(data) ~= "table" then return 0 end
	local u = data.achievementsUnlocked; local s = data.achievementsSeen
	if type(u) ~= "table" then return 0 end
	local n = 0
	for id, v in u do if v == true and (type(s) ~= "table" or s[id] ~= true) then n += 1 end end
	return n
end

function TrophyCasePanel.mount(screenGui: ScreenGui, uiController: any)
	local panel = screenGui:WaitForChild("Panels"):WaitForChild("TrophyCase") :: Frame

	local header = panel:WaitForChild("Title") :: TextLabel
	local closeBtn = panel:WaitForChild("Close") :: TextButton
	local progressLabel = panel:WaitForChild("ProgressLabel") :: TextLabel
	local barBg = panel:WaitForChild("ProgressBarBg") :: Frame
	local barFill = barBg:WaitForChild("Fill") :: Frame
	local pctLabel = panel:WaitForChild("PctLabel") :: TextLabel
	local tabRow = panel:WaitForChild("Tabs") :: Frame
	local scroll = panel:WaitForChild("GridScroll") :: ScrollingFrame
	local tooltip = panel:WaitForChild("DetailTooltip") :: Frame
	local ttTitle = tooltip:WaitForChild("TooltipTitle") :: TextLabel
	local ttDesc = tooltip:WaitForChild("TooltipDesc") :: TextLabel

	local currentFilter = "all"
	local snapshot: any = {}

	local function rarityForId(id: string): string
		local map: { [string]: string } = {
			first_drive = "bronze", first_hatch = "bronze", rebirth_one = "bronze", speed_demon = "bronze",
			hatch_100 = "silver", big_spender = "silver", daily_streak_7 = "silver",
			world_tourer = "gold", number_one = "gold", full_index = "diamond",
		}
		return map[id] or "bronze"
	end

	local function buildGrid()
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") and ch.Name ~= "UIGridLayout" then ch:Destroy() end
		end
		local unlocked = if type(snapshot) == "table" and type(snapshot.unlocked) == "table" then snapshot.unlocked else {}
		local totalList = AchievementPopupConfig.Achievements
		local idx = 0
		for _, ach in totalList do
			local cat = string.lower(ach.category)
			if currentFilter ~= "all" and cat ~= currentFilter then continue end
			idx += 1
			local cell = Instance.new("TextButton"); cell.Name="Cell_"..ach.id; cell.LayoutOrder=idx; cell.BackgroundColor3=Color3.fromRGB(30,22,55); cell.AutoButtonColor=false; cell.Text=""; cell.ZIndex=716; cell.Parent=scroll
			local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,10); cc.Parent=cell
			local isOn = unlocked[ach.id] == true; local r = rarityForId(ach.id)
			local stroke = Instance.new("UIStroke"); stroke.Thickness=if isOn then 2 else 1.2; stroke.Color=if isOn then RARITY_STROKE[r] or RARITY_STROKE.bronze else Color3.fromRGB(60,50,80); stroke.Transparency=if isOn then 0.2 else 0.5; stroke.Parent=cell
			local t = Instance.new("TextLabel"); t.Size=UDim2.new(1,-10,1,-10); t.Position=UDim2.new(0,5,0,5); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=12; t.TextColor3=if isOn then Color3.new(1,1,1) else Color3.fromRGB(120,110,150); t.TextWrapped=true; t.Text=ach.title; t.ZIndex=717; t.Parent=cell
			cell.MouseButton1Click:Connect(function() SoundFacade.playOneShot("click"); tooltip.Visible=true; ttTitle.Text=ach.title; ttDesc.Text=ach.description end)
		end
	end

	local function refreshProgressHeader()
		local total = #AchievementPopupConfig.Achievements; local unlockedN = 0
		if type(snapshot) == "table" and type(snapshot.unlocked) == "table" then
			for _, ach in AchievementPopupConfig.Achievements do if snapshot.unlocked[ach.id] == true then unlockedN += 1 end end
		end
		progressLabel.Text = `{unlockedN}/{total} Achievements Unlocked`
		local pct = if total > 0 then math.floor((unlockedN / total) * 100 + 0.5) else 0
		pctLabel.Text = `{pct}%`
		TweenService:Create(barFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(if total > 0 then unlockedN / total else 0, 0, 1, 0) }):Play()
	end

	local function refreshSnapshotFromServer()
		local ok, snap = pcall(function() return Remotes.getFunction("GetAchievementData"):InvokeServer() end)
		if ok and type(snap) == "table" then snapshot = snap; buildGrid(); refreshProgressHeader() end
	end

	local notifDot: Frame? = nil; local notifLabel: TextLabel? = nil

	local function updateTrophyBadge(data: any)
		if not notifDot or not notifLabel then return end
		local n = countUnseen(data); notifDot.Visible = n > 0; notifLabel.Text = tostring(math.min(n, 99))
	end

	local function wireTabs()
		for _, child in tabRow:GetChildren() do
			if child:IsA("GuiObject") and child.Name:sub(1, 4) == "Tab_" then child:Destroy() end
		end
		for _, key in FILTER_ORDER do
			local b = Instance.new("TextButton"); b.Name="Tab_"..key; b.Size=UDim2.fromOffset(key=="all" and 44 or 72, 26); b.BackgroundColor3=Color3.fromRGB(30,22,55); b.Font=Enum.Font.GothamBold; b.TextSize=11; b.TextColor3=Color3.new(1,1,1); b.Text=string.upper(key); b.ZIndex=715; b.Parent=tabRow
			local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,8); bc.Parent=b
			b.MouseButton1Click:Connect(function() SoundFacade.playOneShot("tab_switch"); currentFilter=key; buildGrid() end)
		end
	end

	wireTabs()

	closeBtn.MouseButton1Click:Connect(function() SoundFacade.playOneShot("panel_close"); uiController.closeAll() end)

	uiController.registerPanel("trophyCase", panel)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			tooltip.Visible = false; refreshSnapshotFromServer()
			Remotes.getEvent("MarkAchievementsSeen"):FireServer()
			local ok, data = pcall(function() return Remotes.getFunction("GetPlayerData"):InvokeServer() end)
			if ok and type(data) == "table" then updateTrophyBadge(data) end
		end
	end)

	local player = Players.LocalPlayer
	task.defer(function()
		local pg = player:WaitForChild("PlayerGui") :: PlayerGui
		local dacMain = pg:WaitForChild("DACMain")
		local invPanel = dacMain:WaitForChild("Panels"):FindFirstChild("Inventory")
		local tabBar = invPanel and invPanel:FindFirstChild("TabBar")
		local tbtn = tabBar and tabBar:FindFirstChild("TrophyTab")
		if tbtn and tbtn:IsA("ImageButton") then
			local dot = Instance.new("Frame"); dot.Name="TrophyNotifDot"; dot.Size=UDim2.fromOffset(14,14); dot.Position=UDim2.new(1,-2,0,-2); dot.AnchorPoint=Vector2.new(1,0); dot.BackgroundColor3=Color3.fromRGB(255,60,60); dot.Visible=false; dot.ZIndex=52; dot.Parent=tbtn
			local dc = Instance.new("UICorner"); dc.CornerRadius=UDim.new(0.5,0); dc.Parent=dot
			local cnt = Instance.new("TextLabel"); cnt.Name="Count"; cnt.Size=UDim2.fromScale(1,1); cnt.BackgroundTransparency=1; cnt.Font=Enum.Font.GothamBlack; cnt.TextSize=9; cnt.TextColor3=Color3.new(1,1,1); cnt.Text="0"; cnt.ZIndex=53; cnt.Parent=dot
			notifDot = dot; notifLabel = cnt
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data: any) updateTrophyBadge(data) end)
	Remotes.getEvent("AchievementUnlocked").OnClientEvent:Connect(function() task.defer(refreshSnapshotFromServer) end)

	task.defer(function()
		local ok, data = pcall(function() return Remotes.getFunction("GetPlayerData"):InvokeServer() end)
		if ok and type(data) == "table" then updateTrophyBadge(data) end
	end)
end

return TrophyCasePanel
