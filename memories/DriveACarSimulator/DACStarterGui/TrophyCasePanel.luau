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
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local AchievementPopupConfig = require(DAC:WaitForChild("Config"):WaitForChild("AchievementPopupConfig"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local MenuInputAccessibility = require(DAC:WaitForChild("MenuInputAccessibility"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

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
	local teardownConns: { RBXScriptConnection } = {}
	local localPlayer = Players.LocalPlayer

	local _title = panel:WaitForChild("Title") :: TextLabel
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

	UIHelpers.ensureSingleLineTruncate(_title)
	UIHelpers.ensureSingleLineTruncate(progressLabel)
	UIHelpers.ensureSingleLineTruncate(pctLabel)
	UIHelpers.ensureSingleLineTruncate(ttTitle)
	UIHelpers.ensureFittedWrappedText(ttDesc, 14, 9)

	local currentFilter = "all"
	local snapshot: any = {}
	local gridEntranceGen = 0
	local tabButtons: { [string]: TextButton } = {}
	local tabUnderlines: { [string]: Frame } = {}

	local TAB_BG_IDLE = Color3.fromRGB(30, 22, 55)
	local TAB_BG_SEL = Color3.fromRGB(72, 52, 115)
	local TAB_STROKE_IDLE = Color3.fromRGB(45, 38, 72)
	local TAB_STROKE_SEL = Color3.fromRGB(46, 204, 113)
	local INDICATOR_FILL = Color3.fromRGB(46, 204, 113)

	local function rarityForId(id: string): string
		local map: { [string]: string } = {
			first_drive = "bronze",
			first_hatch = "bronze",
			rebirth_one = "bronze",
			speed_demon = "bronze",
			runs_10 = "bronze",
			hatch_100 = "silver",
			big_spender = "silver",
			daily_streak_7 = "silver",
			top_ten = "silver",
			quest_veteran = "silver",
			world_tourer = "gold",
			number_one = "gold",
			runs_100 = "gold",
			combo_inferno = "gold",
			legendary_hatch = "gold",
			coin_tycoon = "gold",
			daily_streak_30 = "gold",
			world_elite = "gold",
			full_index = "diamond",
			garage_full = "diamond",
			egg_hunter = "diamond",
			night_owl = "silver",
			secret_speed_demon = "gold",
			egg_straordinary = "gold",
			lap_legend = "diamond",
			rebirth_royalty = "gold",
		}
		return map[id] or "bronze"
	end

	local function runGridEntrance()
		if ClientPerformanceProfile.isReducedMotion() or not panel.Visible then
			return
		end
		gridEntranceGen += 1
		local gen = gridEntranceGen
		local cells: { GuiObject } = {}
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") and ch.Name:sub(1, 5) == "Cell_" then
				table.insert(cells, ch)
			end
		end
		table.sort(cells, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local n = #cells
		if n == 0 then
			return
		end
		local per = 0.035
		local maxTotal = 0.62
		if n * per > maxTotal then
			per = maxTotal / n
		end
		local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for i, cell in cells do
			local delayT = (i - 1) * per
			local btn = cell :: TextButton
			local titleLb = cell:FindFirstChildOfClass("TextLabel") :: TextLabel?
			local stroke = cell:FindFirstChild("RarityStroke") :: UIStroke?
			local endStrokeT = if stroke then stroke.Transparency else 0
			local veil = cell:FindFirstChild("LockVeil") :: Frame?
			local lockLb = if veil then veil:FindFirstChildOfClass("TextLabel") :: TextLabel? else nil

			btn.BackgroundTransparency = 1
			if titleLb then
				titleLb.TextTransparency = 1
			end
			if stroke then
				stroke.Transparency = 1
			end
			if veil then
				veil.BackgroundTransparency = 1
				if lockLb then
					lockLb.TextTransparency = 1
				end
			end
			task.delay(delayT, function()
				if gen ~= gridEntranceGen or not cell.Parent or not panel.Visible then
					return
				end
				TweenService:Create(btn, ti, { BackgroundTransparency = 0 }):Play()
				if titleLb then
					TweenService:Create(titleLb, ti, { TextTransparency = 0 }):Play()
				end
				if stroke then
					TweenService:Create(stroke, ti, { Transparency = endStrokeT }):Play()
				end
				if veil and lockLb then
					TweenService:Create(veil, ti, { BackgroundTransparency = 0.55 }):Play()
					TweenService:Create(lockLb, ti, { TextTransparency = 0 }):Play()
				end
			end)
		end
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
			stroke.Name = "RarityStroke"
			stroke.Thickness = if isOn then 2 else 1.2
			stroke.Color = if isOn then RARITY_STROKE[r] or RARITY_STROKE.bronze else Color3.fromRGB(60, 50, 80)
			stroke.Transparency = if isOn then 0.2 else 0.5
			stroke.Parent = cell
			local t = Instance.new("TextLabel")
			t.Size = UDim2.new(1, -10, 1, -10)
			t.Position = UDim2.new(0, 5, 0, 5)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextColor3 = if isOn then Color3.new(1, 1, 1) else Color3.fromRGB(120, 110, 150)
			t.Text = ach.title
			t.ZIndex = 717
			t.Parent = cell
			UIHelpers.ensureFittedWrappedText(t, 12, 7)
			if not isOn then
				local veil = Instance.new("Frame")
				veil.Name = "LockVeil"
				veil.Size = UDim2.fromScale(1, 1)
				veil.BackgroundColor3 = Color3.new(0, 0, 0)
				veil.BackgroundTransparency = 0.55
				veil.BorderSizePixel = 0
				veil.ZIndex = 718
				veil.Active = false
				veil.Parent = cell
				local vc = Instance.new("UICorner")
				vc.CornerRadius = UDim.new(0, 10)
				vc.Parent = veil
				local lockIcon = Instance.new("TextLabel")
				lockIcon.Size = UDim2.fromScale(1, 0.42)
				lockIcon.Position = UDim2.new(0.5, 0, 0.12, 0)
				lockIcon.AnchorPoint = Vector2.new(0.5, 0)
				lockIcon.BackgroundTransparency = 1
				lockIcon.Font = Enum.Font.GothamBlack
				lockIcon.TextSize = 26
				lockIcon.Text = "🔒"
				lockIcon.TextColor3 = Color3.fromRGB(210, 205, 235)
				lockIcon.ZIndex = 719
				lockIcon.Active = false
				lockIcon.Parent = veil
			end
			cell.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("click")
				tooltip.Visible = true
				if isOn then
					ttTitle.Text = ach.title
					ttDesc.Text = ach.description
				else
					ttTitle.Text = "Locked — " .. ach.title
					ttDesc.Text = ach.description
				end
			end)
			MenuInputAccessibility.ensureMinTouchConstraint(cell, HudLayoutConfig.minTouchPx)
			MenuInputAccessibility.wireSelectableFocusRing(cell)
		end
		task.defer(runGridEntrance)
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
		if not localPlayer.Parent then
			return
		end
		local ok, snap = RemoteFailSafe.invokeFunction("GetAchievementData")
		if ok and type(snap) == "table" then
			snapshot = snap; buildGrid(); refreshProgressHeader()
		else
			RemoteFailSafe.notifyRemoteFailure("GetAchievementData")
			snapshot = { unlocked = {} }
			buildGrid(); refreshProgressHeader()
		end
	end

	local notifDot: Frame? = nil; local notifLabel: TextLabel? = nil

	local function updateTrophyBadge(data: any)
		if not notifDot or not notifLabel then return end
		local n = countUnseen(data); notifDot.Visible = n > 0; notifLabel.Text = tostring(math.min(n, 99))
	end

	local function refreshTabVisuals(initial: boolean?)
		local tiOn = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tiOff = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for key, b in pairs(tabButtons) do
			local sel = key == currentFilter
			b.BackgroundColor3 = if sel then TAB_BG_SEL else TAB_BG_IDLE
			local s = b:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = if sel then TAB_STROKE_SEL else TAB_STROKE_IDLE
				s.Thickness = if sel then 2 else 1
			end
			local uLine = tabUnderlines[key]
			if uLine then
				if sel then
					uLine.Visible = true
					if initial == true then
						uLine.Size = UDim2.new(1, -10, 0, 4)
					else
						uLine.Size = UDim2.new(0, 0, 0, 4)
						TweenService:Create(uLine, tiOn, { Size = UDim2.new(1, -10, 0, 4) }):Play()
					end
				elseif initial == true then
					uLine.Size = UDim2.new(0, 0, 0, 4)
					uLine.Visible = false
				else
					TweenService:Create(uLine, tiOff, { Size = UDim2.new(0, 0, 0, 4) }):Play()
				end
			end
		end
	end

	local function wireTabs()
		for _, child in tabRow:GetChildren() do
			if child:IsA("GuiObject") and child.Name:sub(1, 4) == "Tab_" then
				child:Destroy()
			end
		end
		table.clear(tabButtons)
		table.clear(tabUnderlines)

		local tabH = HudLayoutConfig.minTouchPx
		for _, key in FILTER_ORDER do
			local tabW = if key == "all" then tabH else math.max(72, tabH)
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. key
			b.Size = UDim2.fromOffset(tabW, tabH)
			b.BackgroundColor3 = TAB_BG_IDLE
			b.Font = Enum.Font.GothamBold
			b.TextSize = 11
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = string.upper(key)
			b.ZIndex = 715
			b.AutoButtonColor = false
			b.Parent = tabRow
			UIHelpers.ensureSingleLineTruncate(b)
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 8)
			bc.Parent = b
			local bs = Instance.new("UIStroke")
			bs.Color = TAB_STROKE_IDLE
			bs.Thickness = 1
			bs.Transparency = 0.35
			bs.Parent = b
			local uLine = Instance.new("Frame")
			uLine.Name = "TabUnderline"
			uLine.AnchorPoint = Vector2.new(0.5, 1)
			uLine.Position = UDim2.new(0.5, 0, 1, -3)
			uLine.Size = UDim2.new(0, 0, 0, 4)
			uLine.BackgroundColor3 = INDICATOR_FILL
			uLine.BorderSizePixel = 0
			uLine.ZIndex = 716
			uLine.Visible = false
			uLine.Parent = b
			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(0, 2)
			uc.Parent = uLine
			tabButtons[key] = b
			tabUnderlines[key] = uLine
			b.MouseButton1Click:Connect(function()
				if currentFilter == key then
					return
				end
				SoundFacade.playOneShot("tab_switch")
				if not ClientPerformanceProfile.isReducedMotion() then
					SoundFacade.playOneShot("trophy_tab_swipe")
				end
				currentFilter = key
				refreshTabVisuals(false)
				buildGrid()
			end)
			MenuInputAccessibility.wireSelectableFocusRing(b)
		end
		refreshTabVisuals(true)
	end

	wireTabs()

	MenuInputAccessibility.applyPrimaryNavDefaults(closeBtn)
	closeBtn.MouseButton1Click:Connect(function() SoundFacade.playOneShot("panel_close"); uiController.closeAll() end)

	uiController.registerPanel("trophyCase", panel)

	table.insert(teardownConns, panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			tooltip.Visible = false; refreshSnapshotFromServer()
			Remotes.getEvent("MarkAchievementsSeen"):FireServer()
			local ok, data = RemoteFailSafe.invokeGetPlayerData()
			if ok and type(data) == "table" then updateTrophyBadge(data) end
			task.defer(function()
				if not localPlayer.Parent or not panel.Visible then
					return
				end
				local unlockedN = 0
				if type(snapshot) == "table" and type(snapshot.unlocked) == "table" then
					for _, ach in AchievementPopupConfig.Achievements do
						if snapshot.unlocked[ach.id] == true then
							unlockedN += 1
						end
					end
				end
				if unlockedN > 0 then
					local h0 = panel:FindFirstChild("_FirstSessionEmptyHint")
					if h0 and h0:IsA("TextLabel") then
						h0.Visible = false
					end
					return
				end
				if not localPlayer.Parent then
					return
				end
				local okR, r = pcall(function()
					return Remotes.getFunction("FirstSessionOnboarding"):InvokeServer({ kind = "prepareEmptyTrophy" })
				end)
				if okR and type(r) == "table" and r.applied == true and localPlayer.Parent then
					local hint = panel:FindFirstChild("_FirstSessionEmptyHint") :: TextLabel?
					if not hint then
						hint = Instance.new("TextLabel")
						hint.Name = "_FirstSessionEmptyHint"
						hint.BackgroundTransparency = 1
						hint.Font = Enum.Font.Gotham
						hint.TextSize = 14
						hint.TextWrapped = true
						hint.TextColor3 = Color3.fromRGB(45, 40, 65)
						hint.TextXAlignment = Enum.TextXAlignment.Center
						hint.Size = UDim2.new(1, -40, 0, 52)
						hint.AnchorPoint = Vector2.new(0.5, 0)
						hint.Position = UDim2.new(0.5, 0, 0, 92)
						hint.ZIndex = 714
						hint.Parent = panel
					end
					local txt = r.mainLine
					if type(r.hookLine) == "string" and r.hookLine ~= "" then
						txt = txt .. "\n" .. r.hookLine
					end
					hint.Text = txt
					UIHelpers.ensureFittedWrappedText(hint, 14, 9)
					hint.Visible = true
				end
			end)
		else
			local h1 = panel:FindFirstChild("_FirstSessionEmptyHint")
			if h1 and h1:IsA("TextLabel") then
				h1.Visible = false
			end
		end
	end))

	task.defer(function()
		local pg = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
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

	table.insert(teardownConns, Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data: any) updateTrophyBadge(data) end))
	table.insert(teardownConns, Remotes.getEvent("AchievementUnlocked").OnClientEvent:Connect(function() task.defer(refreshSnapshotFromServer) end))

	task.defer(function()
		if not localPlayer.Parent then
			return
		end
		local ok, data = RemoteFailSafe.invokeGetPlayerData()
		if ok and type(data) == "table" and localPlayer.Parent then
			updateTrophyBadge(data)
		end
	end)

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer ~= localPlayer then return end
		for _, c in teardownConns do
			if c.Connected then
				c:Disconnect()
			end
		end
		table.clear(teardownConns)
	end)
end

return TrophyCasePanel
