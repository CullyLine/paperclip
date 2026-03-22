--!strict
--[[
	Leaderboard surface display.
	Targets SurfaceGui on the MeshPart at
	Workspace.Worlds["1"].Nature.Map.Leaderboard1.Leaderboard["Meshes/Leaderboard_Cube.001"].
	Always visible, auto-refreshes every 30 seconds.
	Tab buttons and rank rows are created dynamically.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local LeaderboardTextConfig = require(DAC:WaitForChild("Config"):WaitForChild("LeaderboardTextConfig"))

local LeaderboardPanel = {}

local GOLD = Color3.fromRGB(255, 215, 64)
local SILVER = Color3.fromRGB(210, 210, 220)
local BRONZE = Color3.fromRGB(205, 127, 70)

local STAT_DISTANCE = "totalDistance"
local STAT_REBIRTHS = "totalRebirths"

local REFRESH_INTERVAL = 30

local previousRanks: { [string]: number? } = {}

function LeaderboardPanel.init()
	local player = Players.LocalPlayer

	local worlds = game.Workspace:WaitForChild("Worlds", 20)
	if not worlds then warn("[DAC] LeaderboardPanel: Worlds not found"); return end
	local w1 = worlds:WaitForChild("1", 10)
	if not w1 then warn("[DAC] LeaderboardPanel: World 1 not found"); return end
	local meshPart = w1:WaitForChild("Nature", 10)
		and w1.Nature:WaitForChild("Map", 10)
		and w1.Nature.Map:WaitForChild("Leaderboard1", 10)
		and w1.Nature.Map.Leaderboard1:WaitForChild("Leaderboard", 10)

	if not meshPart then warn("[DAC] LeaderboardPanel: Leaderboard model not found"); return end

	local cube: MeshPart? = nil
	for _, ch in meshPart:GetDescendants() do
		if ch.Name == "Meshes/Leaderboard_Cube.001" and ch:IsA("MeshPart") then
			cube = ch :: MeshPart
			break
		end
	end
	if not cube then
		cube = meshPart:FindFirstChild("Meshes/Leaderboard_Cube.001") :: MeshPart?
	end
	if not cube then warn("[DAC] LeaderboardPanel: MeshPart cube not found"); return end

	local surfaceGui = cube:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then warn("[DAC] LeaderboardPanel: SurfaceGui not found on cube"); return end

	local bg = surfaceGui:WaitForChild("Background") :: Frame
	local tabRow = bg:WaitForChild("Tabs") :: Frame
	local scroll = bg:WaitForChild("Scroll") :: ScrollingFrame
	local statusLabel = scroll:FindFirstChild("StatusLabel") :: TextLabel?
	local motivationLabel = bg:FindFirstChild("MotivationLabel") :: TextLabel?

	local currentStat = STAT_DISTANCE
	local refreshId = 0
	local tabButtons: { [string]: TextButton } = {}

	local function rankColor(rank: number): Color3
		if rank == 1 then return GOLD
		elseif rank == 2 then return SILVER
		elseif rank == 3 then return BRONZE end
		return Color3.fromRGB(230, 230, 245)
	end

	local function formatScore(stat: string, value: number): string
		if stat == STAT_DISTANCE then return `{Utils.formatNumber(value)} studs` end
		return tostring(math.floor(value))
	end

	local function clearRows()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") and child.Name == "Row" then child:Destroy() end
		end
	end

	local function setStatus(text: string, color: Color3?)
		if statusLabel then
			statusLabel.Visible = true; statusLabel.Text = text
			statusLabel.TextColor3 = color or Color3.fromRGB(180, 180, 200)
		end
	end

	local function hideStatus()
		if statusLabel then statusLabel.Visible = false; statusLabel.Text = "" end
	end
	local function hideMotivation()
		if motivationLabel then motivationLabel.Visible = false; motivationLabel.Text = "" end
	end

	local function pickRandom(lines: { string }): string
		if #lines == 0 then return "" end
		return lines[math.random(1, #lines)]
	end

	local function applyCloseTemplate(template: string, gapStr: string, nextRankNum: number): string
		return template:gsub("{GAP}", gapStr):gsub("{NEXT_RANK}", tostring(nextRankNum))
	end
	local function applyRankUpTemplate(template: string, oldRank: number, newRank: number): string
		return template:gsub("#{OLD_RANK}", "#" .. tostring(oldRank)):gsub("#{NEW_RANK}", "#" .. tostring(newRank))
	end
	local function applyRivalTemplate(template: string, rivalName: string, rivalRank: number): string
		return template:gsub("{RIVAL_NAME}", rivalName):gsub("#{RIVAL_RANK}", "#" .. tostring(rivalRank))
	end

	local function setTabVisual(active: string)
		for id, btn in tabButtons do
			local on = id == active
			btn.BackgroundColor3 = if on then Color3.fromRGB(70, 120, 220) else Color3.fromRGB(45, 45, 70)
			btn.TextColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(180, 180, 200)
		end
	end

	local function refresh()
		refreshId += 1
		local myRefresh = refreshId
		clearRows(); hideStatus(); hideMotivation()
		setStatus("Loading\u{2026}", Color3.fromRGB(160, 170, 210))

		task.defer(function()
			if myRefresh ~= refreshId then return end
			local statForFetch = currentStat
			local ok, rows = pcall(function() return Remotes.getFunction("GetLeaderboard"):InvokeServer(statForFetch) end)
			if myRefresh ~= refreshId then return end
			clearRows()
			if not ok or type(rows) ~= "table" then
				setStatus("Couldn't load.", Color3.fromRGB(255, 130, 130)); return
			end
			if #rows == 0 then
				local hint = if statForFetch == STAT_DISTANCE then "No rankings yet." else "No rebirth rankings yet."
				setStatus(hint, Color3.fromRGB(150, 160, 190)); return
			end
			hideStatus()

			local myId = player.UserId
			local myRank: number? = nil
			local myValue: number? = nil
			local oldRank = previousRanks[statForFetch]
			for i, entry in ipairs(rows) do
				if type(entry) ~= "table" then continue end
				local userId = tonumber(entry.userId) or 0
				local value = tonumber(entry.value) or 0
				local nameStr = if type(entry.name) == "string" and entry.name ~= "" then entry.name else "Unknown"
				local titleStr = if type(entry.title) == "string" and entry.title ~= "" then entry.title else ""
				local rank = i
				local isSelf = userId == myId and userId ~= 0
				if isSelf then myRank = rank; myValue = value end

				local rowH = if titleStr ~= "" then 44 else 34
				local row = Instance.new("Frame")
				row.Name = "Row"; row.Size = UDim2.new(1, -8, 0, rowH)
				row.BackgroundColor3 = if isSelf then Color3.fromRGB(40, 55, 90) else Color3.fromRGB(28, 28, 52)
				row.BackgroundTransparency = if isSelf then 0.1 else 0.25
				row.BorderSizePixel = 0; row.LayoutOrder = rank; row.Parent = scroll
				local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row

				if isSelf then
					local stroke = Instance.new("UIStroke"); stroke.Parent = row
					if rank == 1 then
						stroke.Color = GOLD; stroke.Thickness = 2.5; stroke.Transparency = 0
					elseif rank <= 10 then
						stroke.Color = GOLD; stroke.Thickness = 2; stroke.Transparency = 0.2
					else
						stroke.Color = Color3.fromRGB(120, 200, 140); stroke.Thickness = 2; stroke.Transparency = 0.2
					end
				end

				local rankLbl = Instance.new("TextLabel")
				rankLbl.Size = UDim2.new(0, 40, 1, 0); rankLbl.Position = UDim2.new(0, 8, 0, 0)
				rankLbl.BackgroundTransparency = 1; rankLbl.Font = Enum.Font.GothamBold
				rankLbl.TextSize = 16; rankLbl.TextXAlignment = Enum.TextXAlignment.Left
				rankLbl.Text = `#{rank}`; rankLbl.TextColor3 = rankColor(rank); rankLbl.Parent = row

				local nameCol = Instance.new("Frame")
				nameCol.Size = UDim2.new(1, -160, 1, -4); nameCol.Position = UDim2.new(0, 52, 0, 2)
				nameCol.BackgroundTransparency = 1; nameCol.Parent = row

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = if titleStr ~= "" then UDim2.new(1, 0, 0, 18) else UDim2.new(1, 0, 1, 0)
				nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.Gotham; nameLbl.TextSize = 14
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Text = nameStr
				nameLbl.TextColor3 = if isSelf then Color3.fromRGB(200, 255, 210) else Color3.fromRGB(235, 235, 245)
				nameLbl.Parent = nameCol

				if titleStr ~= "" then
					local tLbl = Instance.new("TextLabel")
					tLbl.Size = UDim2.new(1, 0, 0, 16); tLbl.Position = UDim2.new(0, 0, 0, 20)
					tLbl.BackgroundTransparency = 1; tLbl.Font = Enum.Font.Gotham; tLbl.TextSize = 11
					tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.TextTruncate = Enum.TextTruncate.AtEnd
					tLbl.Text = titleStr; tLbl.TextColor3 = Color3.fromRGB(160, 175, 210); tLbl.Parent = nameCol
				end

				local scoreLbl = Instance.new("TextLabel")
				scoreLbl.Size = UDim2.new(0, 120, 1, 0); scoreLbl.Position = UDim2.new(1, -128, 0, 0)
				scoreLbl.BackgroundTransparency = 1; scoreLbl.Font = Enum.Font.GothamBold; scoreLbl.TextSize = 14
				scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
				scoreLbl.Text = formatScore(statForFetch, value)
				scoreLbl.TextColor3 = Color3.fromRGB(220, 220, 240); scoreLbl.Parent = row
			end

			if myRank then previousRanks[statForFetch] = myRank end

			if not motivationLabel then return end
			if myRank == nil or myValue == nil then hideMotivation()
			elseif myRank == 1 then
				motivationLabel.Text = pickRandom(LeaderboardTextConfig.Number1Flex); motivationLabel.TextColor3 = GOLD; motivationLabel.Visible = true
			elseif oldRank ~= nil and myRank ~= nil and oldRank > myRank then
				motivationLabel.Text = applyRankUpTemplate(pickRandom(LeaderboardTextConfig.RankUpMessages), oldRank, myRank); motivationLabel.TextColor3 = Color3.fromRGB(245, 245, 255); motivationLabel.Visible = true
			elseif (oldRank == nil or oldRank > 10) and myRank <= 10 and myRank > 1 then
				motivationLabel.Text = pickRandom(LeaderboardTextConfig.TopTenMessages); motivationLabel.TextColor3 = GOLD; motivationLabel.Visible = true
			elseif myRank > 1 then
				local prevEntry = rows[myRank - 1]
				if type(prevEntry) == "table" then
					local prevVal = tonumber(prevEntry.value) or 0
					local gap = math.max(0, prevVal - (myValue :: number))
					if prevVal > 0 and gap / prevVal <= 0.05 then
						local rivalName = if type(prevEntry.name) == "string" and prevEntry.name ~= "" then prevEntry.name else "Rival"
						motivationLabel.Text = applyRivalTemplate(pickRandom(LeaderboardTextConfig.RivalApproaching), rivalName, myRank - 1); motivationLabel.TextColor3 = Color3.fromRGB(255, 200, 140); motivationLabel.Visible = true
					else
						local topPct = math.max(1, math.ceil(#rows * 0.1))
						if myRank <= topPct then
							local gap2 = math.max(0, prevVal - (myValue :: number))
							motivationLabel.Text = applyCloseTemplate(pickRandom(LeaderboardTextConfig.CloseToNextRank), formatScore(statForFetch, gap2), myRank - 1); motivationLabel.TextColor3 = Color3.fromRGB(245, 245, 255); motivationLabel.Visible = true
						else hideMotivation() end
					end
				else hideMotivation() end
			else hideMotivation() end
		end)
	end

	local function mkTab(id: string, label: string)
		local b = Instance.new("TextButton")
		b.Name = id; b.Size = UDim2.new(0, 140, 0, 28)
		b.BackgroundColor3 = Color3.fromRGB(45, 45, 70); b.Text = label
		b.TextColor3 = Color3.fromRGB(180, 180, 200); b.Font = Enum.Font.GothamBold
		b.TextSize = 14; b.AutoButtonColor = true; b.Parent = tabRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		tabButtons[id] = b
		b.MouseButton1Click:Connect(function()
			currentStat = id; setTabVisual(id); refresh()
		end)
	end

	mkTab(STAT_DISTANCE, "Distance"); mkTab(STAT_REBIRTHS, "Rebirths")
	setTabVisual(STAT_DISTANCE)

	refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			refresh()
		end
	end)
end

return LeaderboardPanel
