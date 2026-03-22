--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local GamePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("GamePassConfig"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local FailureFeedback = require(DAC:WaitForChild("FailureFeedback"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local localPlayer = Players.LocalPlayer

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local FomoBadgeLabelConfig = require(DAC:WaitForChild("Config"):WaitForChild("FomoBadgeLabelConfig"))

local StorePanel = {}

type FomoKind = "hot" | "low_stock" | "best_value" | "premium" | "event_expiring"

local function socialProofHotLine(): string
	local n = math.random(8, 55)
	local line = SocialFeedConfig.pickLine("SocialProofStore")
	return line:gsub("{n}", tostring(n))
end

local function limitedStockLine(): string
	return SocialFeedConfig.pickLine("LimitedStock")
end

local function truncate(s: string, maxLen: number): string
	if #s <= maxLen then
		return s
	end
	return string.sub(s, 1, maxLen - 1) .. "…"
end

local function formatTimeLeft(sec: number): string
	sec = math.max(0, math.floor(sec))
	local d = math.floor(sec / 86400)
	local h = math.floor((sec % 86400) / 3600)
	local m = math.floor((sec % 3600) / 60)
	if d > 0 then
		return `{d}d {h}h`
	elseif h > 0 then
		return `{h}h {m}m`
	else
		return `{math.max(1, m)}m`
	end
end

local function randomPermanentBadgeLabel(): string
	local keys: { string } = {}
	for k in FomoBadgeLabelConfig.PermanentBadges do
		table.insert(keys, k)
	end
	if #keys == 0 then
		return "BEST VALUE"
	end
	local def = FomoBadgeLabelConfig.PermanentBadges[keys[math.random(1, #keys)]]
	return if def then def.label else "BEST VALUE"
end

local function randomEventBadgeLabel(): string
	local keys: { string } = {}
	for k in FomoBadgeLabelConfig.EventBadgeLabels do
		table.insert(keys, k)
	end
	if #keys == 0 then
		return "VIP"
	end
	local def = FomoBadgeLabelConfig.EventBadgeLabels[keys[math.random(1, #keys)]]
	return if def then def.label else "VIP"
end

local function almostEarnedBadgeLine(): string
	local line = FomoBadgeLabelConfig.pickVariant(FomoBadgeLabelConfig.AlmostEarned)
	return line
		:gsub("{BADGE}", "BONUS")
		:gsub("{PERCENT}", tostring(math.random(82, 97)))
end

local function socialProofBadgeLine(): string
	local line = FomoBadgeLabelConfig.pickVariant(FomoBadgeLabelConfig.SocialProofInspect)
	return line
		:gsub("{PLAYER}", localPlayer.DisplayName)
		:gsub("{BADGE}", "ELITE")
end

local function bestGemsProductId(): string?
	local bestId: string? = nil
	local bestRatio = 0.0
	for pid, def in DevProductConfig.Products do
		local r = def.reward
		if type(r) == "table" and r.currency == "gems" and type(r.amount) == "number" and def.robuxPrice > 0 then
			local ratio = (r.amount :: number) / def.robuxPrice
			if ratio > bestRatio then
				bestRatio = ratio
				bestId = pid
			end
		end
	end
	return bestId
end

local function clearFomoBadge(row: Frame)
	local b = row:FindFirstChild("FomoBadge")
	if b then
		b:Destroy()
	end
end

local function createFomoBadge(row: Frame, kind: FomoKind, copy: string)
	clearFomoBadge(row)

	local badge = Instance.new("Frame")
	badge.Name = "FomoBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -6)
	badge.BackgroundTransparency = 0.05
	badge.ZIndex = row.ZIndex + 10
	badge.Size = UDim2.fromOffset(0, 22)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge:SetAttribute("Kind", kind)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 2)
	pad.Parent = badge

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = badge

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = badge

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(18, 22)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 12
	icon.LayoutOrder = 1
	icon.Parent = badge

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 9
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.RichText = false
	label.LayoutOrder = 2
	label.Parent = badge

	local maxW = 132
	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MaxSize = Vector2.new(maxW, 48)
	sizeC.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	stroke.Parent = badge

	local grad = Instance.new("UIGradient")
	grad.Parent = badge

	if kind == "hot" then
		badge.BackgroundColor3 = Color3.fromRGB(200, 40, 30)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 50, 20)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 50, 20)),
		})
		stroke.Color = Color3.fromRGB(255, 120, 40)
		icon.Text = "🔥"
		icon.TextSize = 13
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = truncate(copy, 48)
	elseif kind == "low_stock" then
		badge.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 120, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 15)),
		})
		stroke.Color = Color3.fromRGB(240, 160, 40)
		icon.Text = "⚠️"
		label.TextColor3 = Color3.fromRGB(255, 240, 200)
		label.Text = truncate(copy, 36)
	elseif kind == "best_value" then
		badge.BackgroundColor3 = Color3.fromRGB(30, 150, 60)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 170, 70)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 130, 50)),
		})
		stroke.Color = Color3.fromRGB(80, 220, 110)
		icon.Text = "⭐"
		icon.TextSize = 12
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = truncate(copy, 48)
	elseif kind == "premium" then
		badge.BackgroundColor3 = Color3.fromRGB(160, 120, 20)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 140, 30)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 180, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 30)),
		})
		stroke.Color = Color3.fromRGB(255, 220, 100)
		icon.Text = "💎"
		label.TextColor3 = Color3.fromRGB(255, 240, 200)
		label.Text = truncate(copy, 40)
	elseif kind == "event_expiring" then
		badge.BackgroundColor3 = Color3.fromRGB(210, 45, 25)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 85, 35)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 170, 55)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 20)),
		})
		stroke.Color = Color3.fromRGB(255, 150, 70)
		icon.Text = "⏳"
		icon.TextSize = 13
		label.TextColor3 = Color3.fromRGB(255, 240, 220)
		label.Text = truncate(copy, 56)
	end

	badge.Parent = row
end

local function pulseButtonError(btn: GuiButton)
	FailureFeedback.fire("purchase_fail", { button = btn })
end

local STAT_BAR_MAX = 50

local function flashRowGreen(row: Frame)
	local orig = row.BackgroundColor3
	TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.fromRGB(50, 180, 80),
	}):Play()
	task.delay(0.3, function()
		if row.Parent then
			TweenService:Create(row, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = orig,
			}):Play()
		end
	end)
end

local function showOwnedBadge(row: Frame)
	local existing = row:FindFirstChild("OwnedBadge")
	if existing then existing:Destroy() end
	local badge = Instance.new("TextLabel")
	badge.Name = "OwnedBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(0.68, 0, 0.5, 0)
	badge.Size = UDim2.new(0, 70, 0, 22)
	badge.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
	badge.BackgroundTransparency = 0.1
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 12
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = "OWNED!"
	badge.ZIndex = 5
	badge.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge
	local s = Instance.new("UIScale")
	s.Scale = 0
	s.Parent = badge
	TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function transitionBuyButton(btn: TextButton)
	btn.Text = "YOURS!"
	local s = btn:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = btn
	end
	s.Scale = 1
	TweenService:Create(s, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	task.delay(0.1, function()
		if btn.Parent then
			TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	task.delay(0.5, function()
		if btn.Parent then
			btn.Text = "Owned"
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		end
	end)
end

function StorePanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "StoreRoot")
	MenuHub.registerPanel("store", root)
	UIHelpers.titleBar(root, "Store & Robux", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)

	local rowByKey: { [string]: Frame } = {}
	local fomoAnimConn: RBXScriptConnection? = nil
	local fomoBadgeRows: { Frame } = {}
	local refreshBadgeWall: (() -> ())? = nil

	local function disconnectFomoAnim()
		if fomoAnimConn then
			fomoAnimConn:Disconnect()
			fomoAnimConn = nil
		end
	end

	local function connectFomoAnim()
		disconnectFomoAnim()
		fomoAnimConn = RunService.RenderStepped:Connect(function()
			if not root.Visible then
				return
			end
			local t = os.clock()
			for _, row in fomoBadgeRows do
				if not row.Parent then
					continue
				end
				local badge = row:FindFirstChild("FomoBadge")
				if not badge or not badge:IsA("Frame") then
					continue
				end
				local kind = badge:GetAttribute("Kind") :: string?
				local scale = badge:FindFirstChildOfClass("UIScale")
				local grad = badge:FindFirstChildOfClass("UIGradient")
				if kind == "hot" and scale then
					scale.Scale = 1 + 0.06 * (math.sin(t * 4) + 1) / 2
					if grad then
						local x = (math.sin(t * math.pi) + 1) / 2 * 0.6 - 0.3
						grad.Offset = Vector2.new(x, 0)
					end
				elseif kind == "low_stock" then
					local tr = 0.05 + 0.13 * (math.sin(t * 7.5) + 1) / 2
					badge.BackgroundTransparency = tr
					local s = badge:FindFirstChildOfClass("UIStroke")
					if s then
						s.Transparency = 0.2 + 0.25 * (math.sin(t * 7.5) + 1) / 2
					end
				elseif kind == "best_value" then
					local yOff = -6 + math.sin(t * 2.5) * -1.5
					badge.Position = UDim2.new(1, 4, 0, yOff)
				elseif kind == "premium" and grad then
					local x = (t * 0.35) % 2 - 1
					grad.Offset = Vector2.new(x, 0)
				elseif kind == "event_expiring" and scale then
					scale.Scale = 1 + 0.08 * (math.sin(t * 5.2) + 1) / 2
					if grad then
						local x = (math.sin(t * math.pi * 1.4) + 1) / 2 * 0.55 - 0.275
						grad.Offset = Vector2.new(x, 0)
					end
					badge.BackgroundTransparency = 0.02 + 0.1 * (math.sin(t * 6) + 1) / 2
				end
			end
		end)
	end

	local function assignFomoBadges()
		for _, r in rowByKey do
			clearFomoBadge(r)
		end
		table.clear(fomoBadgeRows)

		local nowClock = os.time()
		local bestGems = bestGemsProductId()
		local assignment: { [string]: { kind: FomoKind, text: string } } = {}

		for pid, def in DevProductConfig.Products do
			local expAt = (def :: any).eventBadgeExpiresAt
			local badgeName = (def :: any).eventBadgeLabel
			if type(expAt) == "number" and nowClock < expAt then
				local k = "dev:" .. pid
				if rowByKey[k] then
					local nameStr = if type(badgeName) == "string" and badgeName ~= "" then badgeName else "EVENT"
					local line = FomoBadgeLabelConfig.pickVariant(FomoBadgeLabelConfig.EventExpiring)
					line = line:gsub("{BADGE}", nameStr):gsub("{TIME}", formatTimeLeft(expAt - nowClock))
					assignment[k] = { kind = "event_expiring", text = line }
				end
			end
		end

		if bestGems then
			local k = "dev:" .. bestGems
			if rowByKey[k] and not assignment[k] then
				assignment[k] = { kind = "best_value", text = randomPermanentBadgeLabel() }
			end
		end

		local vipKey = "pass:vip"
		if rowByKey[vipKey] and not assignment[vipKey] then
			assignment[vipKey] = { kind = "premium", text = randomEventBadgeLabel() }
		end

		local lowKeys = { "dev:crystals_pack_l", "dev:battle_pass_premium" }
		for _, lk in lowKeys do
			if rowByKey[lk] and not assignment[lk] then
				assignment[lk] = { kind = "low_stock", text = almostEarnedBadgeLine() }
			end
		end

		local pool: { string } = {}
		for k in rowByKey do
			if not assignment[k] then
				table.insert(pool, k)
			end
		end
		for i = #pool, 2, -1 do
			local j = math.random(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local hotCount = math.min(math.random(2, 3), #pool)
		for i = 1, hotCount do
			local k = pool[i]
			if rowByKey[k] then
				assignment[k] = { kind = "hot", text = socialProofBadgeLine() }
			end
		end

		for k, row in rowByKey do
			local a = assignment[k]
			if a then
				createFomoBadge(row, a.kind, a.text)
				table.insert(fomoBadgeRows, row)
			end
		end

		if root.Visible then
			connectFomoAnim()
		else
			disconnectFomoAnim()
		end
	end

	local function addHeader(text: string, layoutOrder: number?)
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 28)
		h.BackgroundTransparency = 1
		h.Font = Enum.Font.GothamBold
		h.TextSize = 18
		h.TextColor3 = Color3.fromRGB(255, 213, 79)
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Text = text
		h.LayoutOrder = layoutOrder or -100
		h.Parent = scroll
	end

	addHeader("Car upgrades (equipped car)", -220)

	local upgradeLabels: { [string]: TextLabel } = {}
	local upgradeBars: { [string]: Frame } = {}
	local upgradeStatsTable = UpgradeConfig.Stats

	local function refreshUpgrades()
		local statsTable = upgradeStatsTable
		if type(statsTable) ~= "table" then
			return
		end
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		if type(data) ~= "table" or not data.equippedCar then
			return
		end
		local carId = data.equippedCar
		local owned = data.cars and data.cars[carId]
		if not owned then
			return
		end
		for _, stat in { "gas", "power", "speed" } do
			local statConfig = statsTable[stat]
			if not statConfig then
				continue
			end
			local levelKey = stat .. "Level"
			local lvl = owned[levelKey] or 0
			local cost = Utils.getUpgradeCost(statConfig.baseCost, statConfig.costMultiplier, lvl)
			local lbl = upgradeLabels[stat]
			if lbl then
				lbl.Text = `{string.upper(string.sub(stat, 1, 1))}{string.sub(stat, 2)} Lv {lvl} → {Utils.formatNumber(cost)} coins`
			end
			local bar = upgradeBars[stat]
			if bar then
				bar.Size = UDim2.new(math.clamp(lvl / STAT_BAR_MAX, 0, 1), 0, 1, 0)
			end
		end
	end

	local pendingUpgradeStat: string? = nil
	local pendingLevelBefore: number? = nil
	local pendingCarBuyId: string? = nil
	local lastActionButton: TextButton? = nil
	local lastActionAt = 0.0

	local carBuyRows: { [string]: Frame } = {}
	local carBuyButtons: { [string]: TextButton } = {}
	local gamePassRows: { [string]: Frame } = {}
	local devProductRows: { [string]: Frame } = {}

	local upLayout = -219
	for _, stat in { "gas", "power", "speed" } do
		upLayout += 1
		local statConfig = upgradeStatsTable and upgradeStatsTable[stat]
		if not statConfig then
			continue
		end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(34, 40, 72)
		row.LayoutOrder = upLayout
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.62, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = statConfig.currency .. " upgrade"
		lbl.Parent = row
		upgradeLabels[stat] = lbl

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0.58, 0, 0, 4)
		barBg.Position = UDim2.new(0.02, 0, 1, -8)
		barBg.BackgroundColor3 = Color3.fromRGB(20, 24, 50)
		barBg.BorderSizePixel = 0
		barBg.ZIndex = 2
		barBg.Parent = row
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0.5, 0)
		barCorner.Parent = barBg
		local barFill = Instance.new("Frame")
		barFill.Name = "Fill"
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
		barFill.BorderSizePixel = 0
		barFill.ZIndex = 3
		barFill.Parent = barBg
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = barFill
		upgradeBars[stat] = barFill

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.32, 0, 0, 34)
		btn.Position = UDim2.new(0.65, 0, 0.5, -17)
		btn.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
		btn.TextColor3 = Color3.fromRGB(30, 30, 30)
		btn.Font = Enum.Font.GothamBold
		btn.Text = "Upgrade"
		btn.Parent = row
		if stat == "speed" then
			btn.Name = "TutorialUpgradeSpeed"
		end
		btn.MouseButton1Click:Connect(function()
			lastActionButton = btn
			lastActionAt = tick()
			SoundFacade.playOneShot("click")
			local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
			if type(data) == "table" and type(data.equippedCar) == "string" then
				local carId = data.equippedCar
				local owned = data.cars and data.cars[carId]
				local lvlKey = stat .. "Level"
				local lvlBefore = if type(owned) == "table" then (owned[lvlKey] :: any) or 0 else 0
				if type(lvlBefore) ~= "number" then
					lvlBefore = 0
				end
				pendingUpgradeStat = stat
				pendingLevelBefore = lvlBefore
				Remotes.getEvent("UpgradeStat"):FireServer(carId, stat)
				task.delay(3, function()
					if pendingUpgradeStat == stat then
						pulseButtonError(btn)
						pendingUpgradeStat = nil
						pendingLevelBefore = nil
					end
				end)
			end
		end)
	end

	refreshUpgrades()
	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function()
		if pendingUpgradeStat and pendingLevelBefore ~= nil then
			local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
			if type(data) == "table" and type(data.equippedCar) == "string" then
				local owned = data.cars and data.cars[data.equippedCar]
				if type(owned) == "table" then
					local lvlKey = pendingUpgradeStat .. "Level"
					local lvl = (owned[lvlKey] :: any) or 0
					if type(lvl) == "number" and lvl > pendingLevelBefore then
						SoundFacade.playOneShot("purchase")
						VFXFacade.upgradeFlash()
						local statKey = pendingUpgradeStat
						local fromLvl = pendingLevelBefore
						local bar2 = statKey and upgradeBars[statKey]
						if bar2 then
							local frac = math.clamp(lvl / STAT_BAR_MAX, 0, 1)
							TweenService:Create(bar2, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(frac, 0, 1, 0) }):Play()
						end
						local lbl2 = statKey and upgradeLabels[statKey]
						if lbl2 and fromLvl and statKey then
							task.spawn(function()
								for step = 1, 6 do
									local t = step / 6
									local displayLvl = math.floor(fromLvl + (lvl - fromLvl) * t)
									local sc = UpgradeConfig.Stats[statKey]
									local c2 = Utils.getUpgradeCost(sc.baseCost, sc.costMultiplier, displayLvl)
									lbl2.Text = `{string.upper(string.sub(statKey, 1, 1))}{string.sub(statKey, 2)} Lv {displayLvl} → {Utils.formatNumber(c2)} coins`
									task.wait(0.05)
								end
							end)
						end
						pendingUpgradeStat = nil
						pendingLevelBefore = nil
					end
				end
			end
		end
		if pendingCarBuyId then
			local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
			if type(data) == "table" and type(data.cars) == "table" then
				local owned = data.cars[pendingCarBuyId]
				if type(owned) == "table" then
					VFXFacade.purchaseCelebration("car", nil, pendingCarBuyId)
					local row = carBuyRows[pendingCarBuyId]
					if row then
						flashRowGreen(row)
					end
					local buyBtn = carBuyButtons[pendingCarBuyId]
					if buyBtn and buyBtn.Parent then
						transitionBuyButton(buyBtn)
					end
					pendingCarBuyId = nil
				end
			end
		end
		if root.Visible then
			refreshUpgrades()
		end
		if refreshBadgeWall then
			refreshBadgeWall()
		end
	end)

	local order = 0
	addHeader("Cars (soft currency)")
	for carId, def in CarConfig.Cars do
		if def.price <= 0 then
			continue
		end
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.65, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 14
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = `{def.name}  •  {Utils.formatNumber(def.price)} {def.currency}  ({def.worldId})`
		lbl.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.28, 0, 0, 36)
		buy.Position = UDim2.new(0.7, 0, 0.5, -18)
		buy.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
		buy.Text = "Buy"
		buy.TextColor3 = Color3.fromRGB(30, 30, 30)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		carBuyRows[carId] = row
		carBuyButtons[carId] = buy
		rowByKey["car:" .. carId] = row
		buy.MouseButton1Click:Connect(function()
			lastActionButton = buy
			lastActionAt = tick()
			SoundFacade.playOneShot("click")
			pendingCarBuyId = carId
			Remotes.getEvent("BuyCar"):FireServer(carId)
			task.delay(3, function()
				if pendingCarBuyId == carId then
					pulseButtonError(buy)
					pendingCarBuyId = nil
				end
			end)
		end)
	end

	addHeader("Game Passes")
	for passId, def in GamePassConfig.Passes do
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 78)
		row.BackgroundColor3 = Color3.fromRGB(36, 50, 80)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 0.48, 0)
		lbl.Position = UDim2.new(0, 8, 0, 6)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextWrapped = true
		lbl.Text = `{def.name} — {def.robuxPrice}R\n{def.description}`
		lbl.Parent = row
		local upsell = Instance.new("TextLabel")
		upsell.Name = "PremiumUpsell"
		upsell.Size = UDim2.new(0.68, 0, 0.42, 0)
		upsell.Position = UDim2.new(0, 8, 0.52, 0)
		upsell.BackgroundTransparency = 1
		upsell.Font = Enum.Font.Gotham
		upsell.TextSize = 11
		upsell.TextXAlignment = Enum.TextXAlignment.Left
		upsell.TextYAlignment = Enum.TextYAlignment.Top
		upsell.TextColor3 = Color3.fromRGB(190, 210, 255)
		upsell.TextWrapped = true
		upsell.TextTransparency = 0.08
		upsell.Text = SocialFeedConfig.pickLine("PremiumUpsell")
		upsell.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.22, 0, 0, 32)
		buy.Position = UDim2.new(0.76, 0, 0.5, -16)
		buy.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		buy.Text = "Robux"
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		gamePassRows[passId] = row
		rowByKey["pass:" .. passId] = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("PurchaseGamePass"):FireServer(passId)
		end)
	end

	addHeader("Developer Products")
	for pid, def in DevProductConfig.Products do
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(50, 36, 70)
		row.LayoutOrder = order
		row.Parent = scroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextWrapped = true
		lbl.Text = `{def.name} — {def.robuxPrice}R`
		lbl.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0.22, 0, 0, 32)
		buy.Position = UDim2.new(0.76, 0, 0.5, -16)
		buy.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
		buy.Text = "Buy"
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		devProductRows[pid] = row
		rowByKey["dev:" .. pid] = row
		buy.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("purchase")
			Remotes.getEvent("PurchaseDevProduct"):FireServer(pid)
		end)
	end

	order += 1
	addHeader("Badge profile", order)
	order += 1
	local badgeWallFrame = Instance.new("Frame")
	badgeWallFrame.Name = "BadgeProfileWall"
	badgeWallFrame.Size = UDim2.new(1, -12, 0, 108)
	badgeWallFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 62)
	badgeWallFrame.LayoutOrder = order
	badgeWallFrame.Parent = scroll
	local badgeWallCorner = Instance.new("UICorner")
	badgeWallCorner.CornerRadius = UDim.new(0, 10)
	badgeWallCorner.Parent = badgeWallFrame

	local badgeSlotLabels: { TextLabel } = {}
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	slotLayout.Padding = UDim.new(0, 8)
	slotLayout.Parent = badgeWallFrame

	for i = 1, 4 do
		local slot = Instance.new("TextLabel")
		slot.Name = "BadgeSlot" .. tostring(i)
		slot.Size = UDim2.fromOffset(112, 52)
		slot.BackgroundColor3 = Color3.fromRGB(40, 44, 78)
		slot.BackgroundTransparency = 0.2
		slot.Font = Enum.Font.Gotham
		slot.TextSize = 11
		slot.TextColor3 = Color3.fromRGB(210, 215, 245)
		slot.TextWrapped = true
		slot.TextXAlignment = Enum.TextXAlignment.Center
		slot.TextYAlignment = Enum.TextYAlignment.Center
		slot.Parent = badgeWallFrame
		local slotPad = Instance.new("UIPadding")
		slotPad.PaddingLeft = UDim.new(0, 8)
		slotPad.PaddingRight = UDim.new(0, 8)
		slotPad.PaddingTop = UDim.new(0, 6)
		slotPad.PaddingBottom = UDim.new(0, 6)
		slotPad.Parent = slot
		local slotC = Instance.new("UICorner")
		slotC.CornerRadius = UDim.new(0, 8)
		slotC.Parent = slot
		local sc = Instance.new("UISizeConstraint")
		sc.MaxSize = Vector2.new(150, 120)
		sc.Parent = slot
		table.insert(badgeSlotLabels, slot)
	end

	order += 1
	local fullCollectionBadge = Instance.new("TextLabel")
	fullCollectionBadge.Name = "FullBadgeCollection"
	fullCollectionBadge.Size = UDim2.new(1, -12, 0, 44)
	fullCollectionBadge.BackgroundTransparency = 1
	fullCollectionBadge.Font = Enum.Font.GothamBold
	fullCollectionBadge.TextSize = 13
	fullCollectionBadge.TextColor3 = Color3.fromRGB(255, 220, 120)
	fullCollectionBadge.TextWrapped = true
	fullCollectionBadge.TextXAlignment = Enum.TextXAlignment.Center
	fullCollectionBadge.Visible = false
	fullCollectionBadge.LayoutOrder = order
	fullCollectionBadge.Parent = scroll

	refreshBadgeWall = function()
		local ok, data = pcall(function()
			return Remotes.getFunction("GetPlayerData"):InvokeServer()
		end)
		if not ok or type(data) ~= "table" then
			return
		end
		local totalSpecies = PetConfig.getTotalSpeciesCount()
		local found = 0
		if type(data.discoveredPets) == "table" then
			for _, v in pairs(data.discoveredPets) do
				if v == true then
					found += 1
				end
			end
		end
		local indexComplete = totalSpecies > 0 and found >= totalSpecies
		fullCollectionBadge.Visible = indexComplete
		badgeWallFrame.Visible = not indexComplete
		if indexComplete then
			fullCollectionBadge.Text = FomoBadgeLabelConfig.pickVariant(FomoBadgeLabelConfig.FullCollectionCopy)
		else
			for _, slot in badgeSlotLabels do
				slot.Text = FomoBadgeLabelConfig.pickVariant(FomoBadgeLabelConfig.EmptySlotCopy)
			end
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if player ~= localPlayer or not wasPurchased then
			return
		end
		local tier: string? = nil
		for passId, def in GamePassConfig.Passes do
			if def.gamePassId == gamePassId then
				if passId == "vip" then
					tier = "vip"
				end
				VFXFacade.purchaseCelebration("gamepass", tier)
				local gpRow = gamePassRows[passId]
				if gpRow then
					flashRowGreen(gpRow)
					showOwnedBadge(gpRow)
				end
				return
			end
		end
	end)

	Remotes.getEvent("Notification").OnClientEvent:Connect(function(n: any)
		if type(n) ~= "table" or n.type ~= "error" or not root.Visible then
			return
		end
		if tick() - lastActionAt > 2.5 then
			return
		end
		if lastActionButton and lastActionButton.Parent then
			pulseButtonError(lastActionButton)
		end
		pendingUpgradeStat = nil
		pendingLevelBefore = nil
		pendingCarBuyId = nil
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player: Player, productId: number, isPurchased: boolean)
		if player ~= localPlayer or not isPurchased then
			return
		end
		local tier: string? = nil
		for productKey, def in DevProductConfig.Products do
			if def.productId == productId then
				if productKey == "battle_pass_premium" then
					tier = "vip"
				end
				VFXFacade.purchaseCelebration("devproduct", tier)
				local dpRow = devProductRows[productKey]
				if dpRow then
					flashRowGreen(dpRow)
					showOwnedBadge(dpRow)
				end
				return
			end
		end
	end)

	assignFomoBadges()
	if refreshBadgeWall then
		refreshBadgeWall()
	end

	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			connectFomoAnim()
		else
			disconnectFomoAnim()
		end
	end)

	task.spawn(function()
		while root.Parent do
			task.wait(300)
			assignFomoBadges()
		end
	end)
end

return StorePanel
