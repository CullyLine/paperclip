--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local LeaderboardTextConfig = require(DAC:WaitForChild("Config"):WaitForChild("LeaderboardTextConfig"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local LeaderboardPanel = {}

local GOLD = Color3.fromRGB(255, 215, 64)
local MOTIVATION_WHITE = Color3.fromRGB(245, 245, 255)
local SILVER = Color3.fromRGB(210, 210, 220)
local BRONZE = Color3.fromRGB(205, 127, 70)

local STAT_DISTANCE = "totalDistance"
local STAT_REBIRTHS = "totalRebirths"

local previousRanks: { [string]: number? } = {}

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

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -8, 0, 40)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	statusLabel.Text = ""
	statusLabel.Visible = false
	statusLabel.LayoutOrder = 0
	statusLabel.Parent = scroll

	local motivationLabel = Instance.new("TextLabel")
	motivationLabel.Name = "MotivationLabel"
	motivationLabel.Size = UDim2.new(1, -8, 0, 0)
	motivationLabel.AutomaticSize = Enum.AutomaticSize.Y
	motivationLabel.BackgroundTransparency = 1
	motivationLabel.Font = Enum.Font.Gotham
	motivationLabel.TextSize = 12
	motivationLabel.TextWrapped = true
	motivationLabel.TextXAlignment = Enum.TextXAlignment.Center
	motivationLabel.Text = ""
	motivationLabel.Visible = false
	motivationLabel.LayoutOrder = 100000
	motivationLabel.Parent = scroll

	local currentStat = STAT_DISTANCE
	local refreshId = 0
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

	local function setStatus(text: string, color: Color3?)
		statusLabel.Visible = true
		statusLabel.Text = text
		statusLabel.TextColor3 = color or Color3.fromRGB(180, 180, 200)
	end

	local function hideStatus()
		statusLabel.Visible = false
		statusLabel.Text = ""
	end

	local function hideMotivation()
		motivationLabel.Visible = false
		motivationLabel.Text = ""
	end

	local function pickRandom(lines: { string }): string
		if #lines == 0 then
			return ""
		end
		return lines[math.random(1, #lines)]
	end

	local function applyCloseTemplate(template: string, gapStr: string, nextRankNum: number): string
		local s = template
		s = s:gsub("{GAP}", gapStr)
		s = s:gsub("{NEXT_RANK}", tostring(nextRankNum))
		return s
	end

	local function applyRankUpTemplate(template: string, oldRank: number, newRank: number): string
		local s = template
		s = s:gsub("#{OLD_RANK}", "#" .. tostring(oldRank))
		s = s:gsub("#{NEW_RANK}", "#" .. tostring(newRank))
		return s
	end

	local function applyRivalTemplate(template: string, rivalName: string, rivalRank: number): string
		local s = template
		s = s:gsub("{RIVAL_NAME}", rivalName)
		s = s:gsub("#{RIVAL_RANK}", "#" .. tostring(rivalRank))
		return s
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
		clearRows()
		hideStatus()
		hideMotivation()
		setStatus("Loading leaderboard…", Color3.fromRGB(160, 170, 210))

		task.defer(function()
			if myRefresh ~= refreshId then
				return
			end
			local statForFetch = currentStat
			local ok, rows = pcall(function()
				return Remotes.getFunction("GetLeaderboard"):InvokeServer(statForFetch)
			end)
			if myRefresh ~= refreshId then
				return
			end
			clearRows()
			if not ok or type(rows) ~= "table" then
				setStatus("Couldn't load leaderboard. Close and reopen, or try again in a moment.", Color3.fromRGB(255, 130, 130))
				return
			end
			if #rows == 0 then
				local hint = if statForFetch == STAT_DISTANCE
					then "No distance rankings yet. Drive to appear on the board."
					else "No rebirth rankings yet. Rebirth to appear on the board."
				setStatus(hint, Color3.fromRGB(150, 160, 190))
				return
			end

			hideStatus()

			local myId = player.UserId
			local myRank: number? = nil
			local myValue: number? = nil
			local oldRank = previousRanks[statForFetch]
			for i, entry in ipairs(rows) do
				if type(entry) ~= "table" then
					continue
				end
				local userId = tonumber(entry.userId) or 0
				local value = tonumber(entry.value) or 0
				local nameStr = if type(entry.name) == "string" and entry.name ~= "" then entry.name else "Unknown"
				local titleStr = if type(entry.title) == "string" and entry.title ~= "" then entry.title else ""
				local rank = i
				local isSelf = userId == myId and userId ~= 0
				if isSelf then
					myRank = rank
					myValue = value
				end

				local rowH = if titleStr ~= "" then 44 else 34

				local row = Instance.new("Frame")
				row.Name = "Row"
				row.Size = UDim2.new(1, -8, 0, rowH)
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
					stroke.Parent = row

					if rank == 1 then
						stroke.Color = GOLD
						stroke.Thickness = 2.5
						stroke.Transparency = 0

						local crown = Instance.new("TextLabel")
						crown.Name = "Crown"
						crown.Size = UDim2.fromOffset(22, 22)
						crown.AnchorPoint = Vector2.new(0, 1)
						crown.Position = UDim2.new(0, 30, 0, 2)
						crown.BackgroundTransparency = 1
						crown.Font = Enum.Font.GothamBold
						crown.TextSize = 16
						crown.TextColor3 = GOLD
						crown.Text = "♛"
						crown.ZIndex = 6
						crown.Parent = row

						task.spawn(function()
							while stroke.Parent do
								TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Color = Color3.fromRGB(255, 240, 150),
									Thickness = 3,
								}):Play()
								task.wait(1.2)
								if not stroke.Parent then break end
								TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Color = GOLD,
									Thickness = 2.5,
								}):Play()
								task.wait(1.2)
							end
						end)
					elseif rank <= 10 then
						stroke.Color = GOLD
						stroke.Thickness = 2
						stroke.Transparency = 0

						task.spawn(function()
							while stroke.Parent do
								TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Transparency = 0.3,
								}):Play()
								task.wait(1.5)
								if not stroke.Parent then break end
								TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Transparency = 0,
								}):Play()
								task.wait(1.5)
							end
						end)
					else
						stroke.Color = Color3.fromRGB(120, 200, 140)
						stroke.Thickness = 2
						stroke.Transparency = 0.2
					end

					if oldRank and oldRank ~= rank then
						local delta = oldRank - rank
						local isUp = delta > 0
						local deltaLbl = Instance.new("TextLabel")
						deltaLbl.Name = "RankDelta"
						deltaLbl.AnchorPoint = Vector2.new(0, 1)
						deltaLbl.Size = UDim2.fromOffset(40, 14)
						deltaLbl.BackgroundTransparency = 1
						deltaLbl.Font = Enum.Font.GothamBold
						deltaLbl.TextSize = 11
						deltaLbl.TextXAlignment = Enum.TextXAlignment.Left
						deltaLbl.ZIndex = 6
						deltaLbl.TextTransparency = 1
						deltaLbl.Parent = row

						if isUp then
							deltaLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
							deltaLbl.Text = `▲{delta}`
						else
							deltaLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
							deltaLbl.Text = `▼{math.abs(delta)}`
						end

						local finalPos = UDim2.new(0, 8, 1, -2)
						deltaLbl.Position = UDim2.new(0, 8, if isUp then 1.3 else 0.2, -2)
						TweenService:Create(deltaLbl, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Position = finalPos,
							TextTransparency = 0,
						}):Play()
					end
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

				local nameCol = Instance.new("Frame")
				nameCol.Size = UDim2.new(1, -160, 1, -4)
				nameCol.Position = UDim2.new(0, 52, 0, 2)
				nameCol.BackgroundTransparency = 1
				nameCol.Parent = row

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = if titleStr ~= ""
					then UDim2.new(1, 0, 0, 18)
					else UDim2.new(1, 0, 1, 0)
				nameLbl.Position = UDim2.new(0, 0, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = Enum.Font.Gotham
				nameLbl.TextSize = 14
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Text = nameStr
				nameLbl.TextColor3 = if isSelf then Color3.fromRGB(200, 255, 210) else Color3.fromRGB(235, 235, 245)
				nameLbl.Parent = nameCol

				if titleStr ~= "" then
					local titleLbl = Instance.new("TextLabel")
					titleLbl.Size = UDim2.new(1, 0, 0, 16)
					titleLbl.Position = UDim2.new(0, 0, 0, 20)
					titleLbl.BackgroundTransparency = 1
					titleLbl.Font = Enum.Font.Gotham
					titleLbl.TextSize = 11
					titleLbl.TextXAlignment = Enum.TextXAlignment.Left
					titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
					titleLbl.Text = titleStr
					titleLbl.TextColor3 = Color3.fromRGB(160, 175, 210)
					titleLbl.Parent = nameCol
				end

				local scoreLbl = Instance.new("TextLabel")
				scoreLbl.Size = UDim2.new(0, 120, 1, 0)
				scoreLbl.Position = UDim2.new(1, -128, 0, 0)
				scoreLbl.BackgroundTransparency = 1
				scoreLbl.Font = Enum.Font.GothamBold
				scoreLbl.TextSize = 14
				scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
				scoreLbl.Text = formatScore(statForFetch, value)
				scoreLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
				scoreLbl.Parent = row
			end

			if myRank then
				previousRanks[statForFetch] = myRank
			end

			if myRank == nil or myValue == nil then
				hideMotivation()
			elseif myRank == 1 then
				motivationLabel.Text = pickRandom(LeaderboardTextConfig.Number1Flex)
				motivationLabel.TextColor3 = GOLD
				motivationLabel.Visible = true
			elseif oldRank ~= nil and myRank ~= nil and oldRank > myRank then
				motivationLabel.Text = applyRankUpTemplate(pickRandom(LeaderboardTextConfig.RankUpMessages), oldRank, myRank)
				motivationLabel.TextColor3 = MOTIVATION_WHITE
				motivationLabel.Visible = true
			elseif (oldRank == nil or oldRank > 10) and myRank <= 10 and myRank > 1 then
				motivationLabel.Text = pickRandom(LeaderboardTextConfig.TopTenMessages)
				motivationLabel.TextColor3 = GOLD
				motivationLabel.Visible = true
			elseif myRank > 1 then
				local prevEntry = rows[myRank - 1]
				if type(prevEntry) == "table" then
					local prevVal = tonumber(prevEntry.value) or 0
					local gap = math.max(0, prevVal - myValue)
					if prevVal > 0 and gap / prevVal <= 0.05 then
						local rivalName = if type(prevEntry.name) == "string" and prevEntry.name ~= "" then prevEntry.name else "Rival"
						local template = pickRandom(LeaderboardTextConfig.RivalApproaching)
						motivationLabel.Text = applyRivalTemplate(template, rivalName, myRank - 1)
						motivationLabel.TextColor3 = Color3.fromRGB(255, 200, 140)
						motivationLabel.Visible = true
					else
						local topPct = math.max(1, math.ceil(#rows * 0.1))
						if myRank <= topPct then
							local gap2 = math.max(0, prevVal - myValue)
							local gapStr = formatScore(statForFetch, gap2)
							local template = pickRandom(LeaderboardTextConfig.CloseToNextRank)
							motivationLabel.Text = applyCloseTemplate(template, gapStr, myRank - 1)
							motivationLabel.TextColor3 = MOTIVATION_WHITE
							motivationLabel.Visible = true
						else
							hideMotivation()
						end
					end
				else
					hideMotivation()
				end
			else
				hideMotivation()
			end
		end)
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
			SoundFacade.playOneShot("tab_switch")
			currentStat = id
			setTabVisual(id)
			refresh()
		end)
	end

	mkTab(STAT_DISTANCE, "Distance")
	mkTab(STAT_REBIRTHS, "Rebirths")
	setTabVisual(STAT_DISTANCE)

	local toast = Instance.new("TextLabel")
	toast.Name = "RankToast"
	toast.Size = UDim2.new(1, -24, 0, 36)
	toast.Position = UDim2.new(0, 12, 0, 52)
	toast.BackgroundColor3 = Color3.fromRGB(35, 40, 70)
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 5
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 15
	toast.TextColor3 = Color3.fromRGB(255, 230, 140)
	toast.Text = ""
	toast.Parent = root
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

	local toastScale = Instance.new("UIScale")
	toastScale.Scale = 1
	toastScale.Parent = toast

	Remotes.getEvent("RankUpNotification").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local newR = tonumber(payload.newRank)
		if newR == nil then
			return
		end
		local st = if type(payload.stat) == "string" then payload.stat else STAT_DISTANCE
		local stLabel = if st == STAT_REBIRTHS then "Rebirths" else "Distance"
		if payload.isFirstPlacement == true then
			toast.Text = `On the board! ${stLabel}  #${newR}`
		else
			local oldR = tonumber(payload.oldRank)
			if oldR == nil then
				return
			end
			toast.Text = `Rank up! ${stLabel}  #${oldR} → #${newR}`
		end
		VFXFacade.leaderboardRankFanfare(payload)
		toast.Visible = true
		toast.TextTransparency = 1
		toast.TextStrokeTransparency = 1
		toastScale.Scale = 0.8
		local fadeIn = TweenService:Create(
			toast,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0, TextStrokeTransparency = 0.45 }
		)
		local scaleIn = TweenService:Create(
			toastScale,
			TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		fadeIn:Play()
		scaleIn:Play()
		task.delay(2.5, function()
			if not toast.Parent then
				return
			end
			TweenService:Create(
				toast,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
		end)
		task.delay(3.2, function()
			if toast.Parent then
				toast.Visible = false
				toastScale.Scale = 1
			end
		end)
	end)

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
			toast.Visible = false
		end
	end)
end

return LeaderboardPanel
