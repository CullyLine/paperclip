--!strict
--[[
	Leaderboard surface display.
	Targets SurfaceGui on the MeshPart at
	Workspace.Worlds["1"].Nature.Map.Leaderboard1.Leaderboard["Meshes/Leaderboard_Cube.001"].
	Always visible; auto-refreshes per Constants.LEADERBOARD_CLIENT_AUTO_REFRESH_SEC (default 30s).
	Tab buttons and rank rows are created dynamically.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local MenuInputAccessibility = require(DAC:WaitForChild("MenuInputAccessibility"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local LeaderboardTextConfig = require(DAC:WaitForChild("Config"):WaitForChild("LeaderboardTextConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local LeaderboardPanel = {}

local GOLD = Color3.fromRGB(255, 215, 64)
local SILVER = Color3.fromRGB(210, 210, 220)
local BRONZE = Color3.fromRGB(205, 127, 70)

local STAT_DISTANCE = "totalDistance"
local STAT_REBIRTHS = "totalRebirths"

local REFRESH_INTERVAL = Constants.LEADERBOARD_CLIENT_AUTO_REFRESH_SEC

local previousRanks: { [string]: number? } = {}
-- Last successful fetch (used when server returns rate_limit with no local snapshot yet).
local lastRowsSnapshot: { any }? = nil
local lastSnapshotStat: string? = nil
local lastUpdatedAtUnix: number? = nil
local lastStaleFooter: boolean = false

-- Mirrors HUD: DataUpdate settings; low graphics / particles off = no motion on leaderboard.
local cachedLbSettings: { graphicsQuality: number, particles: boolean, reducedMotion: boolean } = {
	graphicsQuality = 1,
	particles = true,
	reducedMotion = false,
}

local function cacheLbSettingsFromData(data: any)
	if type(data) ~= "table" or type(data.settings) ~= "table" then
		return
	end
	local s = data.settings
	if type(s.graphicsQuality) == "number" then
		cachedLbSettings.graphicsQuality = s.graphicsQuality
	end
	if type(s.particles) == "boolean" then
		cachedLbSettings.particles = s.particles
	end
	if type(s.reducedMotion) == "boolean" then
		cachedLbSettings.reducedMotion = s.reducedMotion
	end
end

local function shouldLeaderboardJuice(): boolean
	if cachedLbSettings.reducedMotion then
		return false
	end
	if cachedLbSettings.graphicsQuality <= 0 then
		return false
	end
	if cachedLbSettings.particles == false then
		return false
	end
	return true
end

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

	local footerLabel = bg:FindFirstChild("LeaderboardFooter") :: TextLabel?
	if not footerLabel then
		local fl = Instance.new("TextLabel")
		fl.Name = "LeaderboardFooter"
		fl.BackgroundTransparency = 1
		fl.Size = UDim2.new(1, -112, 0, 16)
		fl.Position = UDim2.new(0, 8, 1, -10)
		fl.AnchorPoint = Vector2.new(0, 1)
		fl.Font = Enum.Font.Gotham
		fl.TextSize = 11
		fl.TextXAlignment = Enum.TextXAlignment.Left
		fl.TextColor3 = Color3.fromRGB(140, 150, 180)
		fl.Text = ""
		fl.Visible = false
		fl.ZIndex = 3
		fl.Parent = bg
		footerLabel = fl
	end

	local refreshBtn = bg:FindFirstChild("LeaderboardRefreshBtn") :: TextButton?
	if not refreshBtn then
		local rb = Instance.new("TextButton")
		rb.Name = "LeaderboardRefreshBtn"
		rb.Size = UDim2.new(0, 96, 0, 32)
		rb.Position = UDim2.new(1, -8, 0, 8)
		rb.AnchorPoint = Vector2.new(1, 0)
		rb.BackgroundColor3 = Color3.fromRGB(45, 55, 95)
		rb.TextColor3 = Color3.fromRGB(230, 235, 255)
		rb.Font = Enum.Font.GothamBold
		rb.TextSize = 13
		rb.Text = LeaderboardTextConfig.RefreshButtonLabel
		rb.AutoButtonColor = true
		rb.ZIndex = 4
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = rb
		rb.Parent = bg
		refreshBtn = rb
		MenuInputAccessibility.applyPrimaryNavDefaults(rb)
	end

	local tabRow = bg:WaitForChild("Tabs") :: Frame
	local scroll = bg:WaitForChild("Scroll") :: ScrollingFrame
	local statusLabel = scroll:FindFirstChild("StatusLabel") :: TextLabel?
	local motivationLabel = bg:FindFirstChild("MotivationLabel") :: TextLabel?

	local boardTweenBucket: { Tween } = {}
	local function cancelBoardTweens()
		for _, tw in boardTweenBucket do
			pcall(function()
				tw:Cancel()
			end)
		end
		table.clear(boardTweenBucket)
	end

	local function playBoardRefreshPulse()
		if not shouldLeaderboardJuice() then
			return
		end
		cancelBoardTweens()
		local us = bg:FindFirstChildOfClass("UIScale")
		if not us then
			us = Instance.new("UIScale")
			us.Scale = 1
			us.Parent = bg
		end
		local s = us :: UIScale
		s.Scale = 1
		local up = TweenService:Create(s, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.008 })
		local down = TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1 })
		table.insert(boardTweenBucket, up)
		table.insert(boardTweenBucket, down)
		up:Play()
		up.Completed:Once(function()
			down:Play()
		end)
	end

	local rowPulseBuckets: { [Instance]: { Tween } } = {}
	local function cancelRowPulse(row: Instance)
		local b = rowPulseBuckets[row]
		if not b then
			return
		end
		for _, tw in b do
			pcall(function()
				tw:Cancel()
			end)
		end
		table.clear(b)
	end

	local function playRowRankDeltaPulse(
		row: Frame,
		improved: boolean,
		baseBg: Color3,
		baseTrans: number,
		glyphLbl: TextLabel?
	)
		cancelRowPulse(row)
		local bucket = rowPulseBuckets[row]
		if not bucket then
			bucket = {}
			rowPulseBuckets[row] = bucket
		end
		local flash = if improved then Color3.fromRGB(46, 204, 113) else Color3.fromRGB(243, 156, 18)
		if shouldLeaderboardJuice() then
			row.BackgroundColor3 = flash
			row.BackgroundTransparency = math.clamp(baseTrans - 0.08, 0, 0.5)
			local tw = TweenService:Create(
				row,
				TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = baseBg, BackgroundTransparency = baseTrans }
			)
			table.insert(bucket, tw)
			tw:Play()
		else
			row.BackgroundColor3 = flash:Lerp(baseBg, 0.55)
			task.delay(0.22, function()
				if row.Parent then
					row.BackgroundColor3 = baseBg
					row.BackgroundTransparency = baseTrans
				end
			end)
		end

		if glyphLbl then
			glyphLbl.Text = if improved then "▲" else "▼"
			glyphLbl.TextColor3 = flash
			glyphLbl.TextTransparency = 0
			if shouldLeaderboardJuice() then
				local fade = TweenService:Create(
					glyphLbl,
					TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ TextTransparency = 1 }
				)
				table.insert(bucket, fade)
				fade:Play()
				fade.Completed:Once(function()
					if glyphLbl.Parent then
						glyphLbl.Text = ""
					end
				end)
			else
				task.delay(0.35, function()
					if glyphLbl.Parent then
						glyphLbl.TextTransparency = 1
						glyphLbl.Text = ""
					end
				end)
			end
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(cacheLbSettingsFromData)

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
		if stat == STAT_DISTANCE then
			return `{Utils.formatIntegerWithCommas(value)} studs`
		end
		return Utils.formatIntegerWithCommas(value)
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

	type EmptyPair = { title: string, body: string? }

	local function pickRandomEmpty(pool: { EmptyPair }): EmptyPair
		return pool[math.random(1, #pool)]
	end

	local function formatEmptyStatus(pair: EmptyPair): string
		if pair.body and pair.body ~= "" then
			return pair.title .. "\n" .. pair.body
		end
		return pair.title
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

	local footerAgeToken = 0
	local function formatFooterAge(updatedAt: number?, stale: boolean): string
		if not updatedAt then
			return ""
		end
		local drift = workspace:GetServerTimeNow() - updatedAt
		local age = math.max(0, math.floor(drift + 0.5))
		local base = if age < 5 then "Updated just now" else `Updated {age}s ago`
		if stale then
			return base .. " · may be stale"
		end
		return base
	end

	local function scheduleFooterAgeLoop()
		footerAgeToken += 1
		local tok = footerAgeToken
		task.spawn(function()
			while tok == footerAgeToken do
				task.wait(1)
				if tok ~= footerAgeToken then
					break
				end
				if footerLabel and lastUpdatedAtUnix then
					footerLabel.Text = formatFooterAge(lastUpdatedAtUnix, lastStaleFooter)
					footerLabel.Visible = true
				end
			end
		end)
	end

	local function refresh()
		refreshId += 1
		local myRefresh = refreshId
		clearRows(); hideStatus(); hideMotivation()
		setStatus(LeaderboardTextConfig.LoadingStatus, Color3.fromRGB(160, 170, 210))
		if footerLabel then
			footerLabel.Visible = false
		end

		task.defer(function()
			if myRefresh ~= refreshId then return end
			local statForFetch = currentStat
			local ok, res = RemoteFailSafe.invokeFunction("GetLeaderboard", statForFetch)
			if myRefresh ~= refreshId then return end
			clearRows()

			local rows: { any }
			local resolvedUpdatedAt: number? = nil
			local staleFlag = false

			if ok and type(res) == "table" then
				if res.ok == false then
					if res.reason == "rate_limit" and lastRowsSnapshot and lastSnapshotStat == statForFetch then
						rows = lastRowsSnapshot :: { any }
						resolvedUpdatedAt = lastUpdatedAtUnix
						staleFlag = true
						lastStaleFooter = true
					elseif res.reason == "rate_limit" then
						RemoteFailSafe.notifyRemoteFailure("GetLeaderboard")
						setStatus(pickRandom(MicrocopyConfig.LeaderboardRateLimitNoCache), Color3.fromRGB(255, 130, 130))
						return
					else
						RemoteFailSafe.notifyRemoteFailure("GetLeaderboard")
						setStatus(pickRandom(MicrocopyConfig.LeaderboardLoadError), Color3.fromRGB(255, 130, 130))
						return
					end
				elseif res.ok == true and type(res.rows) == "table" then
					rows = res.rows
					resolvedUpdatedAt = if type(res.updatedAt) == "number" then res.updatedAt else nil
					staleFlag = res.stale == true
					lastRowsSnapshot = rows
					lastSnapshotStat = statForFetch
					lastUpdatedAtUnix = resolvedUpdatedAt
					lastStaleFooter = staleFlag
				elseif res.ok == nil and res.rows == nil then
					rows = res :: { any }
					lastRowsSnapshot = rows
					lastSnapshotStat = statForFetch
					lastUpdatedAtUnix = nil
					lastStaleFooter = false
					resolvedUpdatedAt = nil
				else
					rows = {}
				end
			else
				RemoteFailSafe.notifyRemoteFailure("GetLeaderboard")
				setStatus(pickRandom(MicrocopyConfig.LeaderboardLoadError), Color3.fromRGB(255, 130, 130)); return
			end

			if resolvedUpdatedAt and footerLabel then
				lastUpdatedAtUnix = resolvedUpdatedAt
				lastStaleFooter = staleFlag
				footerLabel.Text = formatFooterAge(resolvedUpdatedAt, staleFlag)
				footerLabel.Visible = true
				scheduleFooterAgeLoop()
			elseif footerLabel and lastUpdatedAtUnix then
				footerLabel.Text = formatFooterAge(lastUpdatedAtUnix, lastStaleFooter)
				footerLabel.Visible = true
				scheduleFooterAgeLoop()
			elseif footerLabel then
				footerLabel.Visible = false
			end

			if #rows == 0 then
				local pool = if statForFetch == STAT_DISTANCE
					then LeaderboardTextConfig.EmptyDistance
					else LeaderboardTextConfig.EmptyRebirths
				local pair = pickRandomEmpty(pool)
				if statusLabel then
					statusLabel.TextWrapped = true
				end
				setStatus(formatEmptyStatus(pair), Color3.fromRGB(150, 160, 190)); return
			end
			hideStatus()

			local myId = player.UserId
			local myRank: number? = nil
			local myValue: number? = nil
			local oldRank = previousRanks[statForFetch]
			local rankPulseRow: Frame? = nil
			local rankPulseGlyph: TextLabel? = nil
			local rankPulseBaseBg: Color3? = nil
			local rankPulseBaseTrans: number? = nil
			local rankPulseImproved: boolean? = nil
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

				if rank <= 3 then
					local glow = Instance.new("UIStroke")
					glow.Name = "PodiumGlow"
					glow.Color = rankColor(rank)
					glow.Thickness = 3.2
					glow.Transparency = 0.52
					glow.Parent = row
					local ring = Instance.new("UIStroke")
					ring.Name = "PodiumRing"
					ring.Color = rankColor(rank)
					ring.Thickness = 2
					ring.Transparency = 0.18
					ring.Parent = row
				end

				if isSelf then
					local stroke = Instance.new("UIStroke")
					stroke.Name = "SelfHighlight"
					stroke.Parent = row
					if rank <= 3 then
						stroke.Color = Color3.fromRGB(130, 220, 255)
						stroke.Thickness = 1.6
						stroke.Transparency = 0.12
					elseif rank <= 10 then
						stroke.Color = GOLD
						stroke.Thickness = 2
						stroke.Transparency = 0.2
					else
						stroke.Color = Color3.fromRGB(120, 200, 140)
						stroke.Thickness = 2
						stroke.Transparency = 0.2
					end

					rankPulseRow = row
					rankPulseBaseBg = row.BackgroundColor3
					rankPulseBaseTrans = row.BackgroundTransparency
					if oldRank ~= nil and oldRank ~= rank then
						rankPulseImproved = oldRank > rank
						local g = Instance.new("TextLabel")
						g.Name = "RankDeltaGlyph"
						g.Size = UDim2.new(0, 18, 0, 18)
						g.Position = UDim2.new(0, 50, 0, 2)
						g.BackgroundTransparency = 1
						g.Font = Enum.Font.GothamBold
						g.TextSize = 13
						g.Text = ""
						g.TextTransparency = 1
						g.Parent = row
						rankPulseGlyph = g
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

			if
				rankPulseRow
				and rankPulseImproved ~= nil
				and rankPulseBaseBg ~= nil
				and rankPulseBaseTrans ~= nil
			then
				playRowRankDeltaPulse(
					rankPulseRow,
					rankPulseImproved,
					rankPulseBaseBg,
					rankPulseBaseTrans,
					rankPulseGlyph
				)
				playBoardRefreshPulse()
			end

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

	refreshBtn.MouseButton1Click:Connect(function()
		refresh()
	end)

	-- Server pushes rank changes on leaderboard updates; refresh this tab so juice is not up to 30s stale.
	Remotes.getEvent("RankUpNotification").OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		if data.stat ~= currentStat then
			return
		end
		task.defer(refresh)
	end)

	local function mkTab(id: string, label: string)
		local b = Instance.new("TextButton")
		b.Name = id; b.Size = UDim2.new(0, 140, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(45, 45, 70); b.Text = label
		b.TextColor3 = Color3.fromRGB(180, 180, 200); b.Font = Enum.Font.GothamBold
		b.TextSize = 14; b.AutoButtonColor = true; b.Parent = tabRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		MenuInputAccessibility.applyPrimaryNavDefaults(b)
		tabButtons[id] = b
		b.MouseButton1Click:Connect(function()
			currentStat = id; setTabVisual(id); refresh()
		end)
	end

	mkTab(STAT_DISTANCE, LeaderboardTextConfig.TabDistanceLabel); mkTab(STAT_REBIRTHS, LeaderboardTextConfig.TabRebirthsLabel)
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
