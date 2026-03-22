--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RunResultsBridge = require(DAC:WaitForChild("RunResultsBridge"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local PayoutPanel = {}

local function computeStackedMultiplier(results: any): number
	local bd = results.breakdown
	if type(bd) ~= "table" then
		return 1
	end
	local m = 1.0
	local function mul(k: string): number
		local v = (bd :: any)[k]
		if type(v) == "number" and v > 0 then
			return v
		end
		return 1
	end
	m *= mul("founderMultiplier")
	m *= mul("worldMultiplier")
	m *= mul("petModifier")
	m *= mul("powerMultiplier")
	m *= mul("passMultiplier")
	m *= mul("premiumMultiplier")
	m *= mul("runOfDayMultiplier")
	return m
end

local function pickPayoutFlexLine(results: any): string
	local coins = math.floor(results.coinsEarned or 0)
	local dist = results.totalDistance or 0
	local laps = results.laps or 0
	local m = computeStackedMultiplier(results)
	local isPb = results.isPersonalBest == true
	local pick = MicrocopyConfig.pickVariant
	local coinsStr = Utils.formatNumber(coins)
	local distStr = Utils.formatNumber(dist)
	local multStr = string.format("%.1f", m)
	local rankStr = if type(results.leaderboardRank) == "number" then tostring(results.leaderboardRank) else "—"

	local function sub(s: string): string
		return (s:gsub("{COINS}", coinsStr))
			:gsub("{DISTANCE}", distStr)
			:gsub("{LAPS}", tostring(laps))
			:gsub("{MULTIPLIER}", multStr)
			:gsub("{RANK}", rankStr)
	end

	if coins > 10000 then
		return sub(pick(MicrocopyConfig.PayoutFlexBig))
	elseif isPb then
		return sub(pick(MicrocopyConfig.PayoutFlexPersonalBest))
	elseif m > 3 then
		return sub(pick(MicrocopyConfig.PayoutFlexMultiplier))
	else
		return sub(pick(MicrocopyConfig.PayoutFlexRunOfDay))
	end
end

local animToken = 0
local uiRefs: any = nil
local pbPulseConn: RBXScriptConnection? = nil

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

local function runScreenFlash(parent: Instance, isRecord: boolean)
	local f = Instance.new("Frame")
	f.Name = "RunEndFlash"
	f.BackgroundColor3 = if isRecord then Color3.new(1, 1, 1) else Color3.fromRGB(255, 200, 70)
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 2000
	f.Parent = parent
	f.BackgroundTransparency = 0.42
	TweenService:Create(f, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.35, function()
		f:Destroy()
	end)
end

local function battlePassTierBeat(xpBarBg: Frame, xpTierLabel: TextLabel)
	local flash = Instance.new("Frame")
	flash.Name = "TierUpFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 245, 180)
	flash.Size = UDim2.new(1, 8, 1, 8)
	flash.Position = UDim2.new(0.5, 0, 0.5, 0)
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.ZIndex = 12
	flash.BorderSizePixel = 0
	flash.Parent = xpBarBg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = flash
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.45, function()
		if flash.Parent then
			flash:Destroy()
		end
	end)

	local barScale = xpBarBg:FindFirstChildOfClass("UIScale")
	if not barScale then
		barScale = Instance.new("UIScale")
		barScale.Parent = xpBarBg
	end
	barScale.Scale = 1
	TweenService:Create(barScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	task.delay(0.2, function()
		TweenService:Create(barScale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	local tierScale = xpTierLabel:FindFirstChildOfClass("UIScale")
	if not tierScale then
		tierScale = Instance.new("UIScale")
		tierScale.Parent = xpTierLabel
	end
	tierScale.Scale = 1
	TweenService:Create(tierScale, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
	task.delay(0.25, function()
		TweenService:Create(tierScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

local function spawnCoinRain(parent: Instance)
	for i = 1, 14 do
		local c = Instance.new("TextLabel")
		c.Name = "CoinRain"
		c.BackgroundTransparency = 1
		c.Size = UDim2.fromOffset(18, 22)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.new(math.random() * 0.85 + 0.075, 0, -0.05, 0)
		c.ZIndex = 5
		c.Font = Enum.Font.GothamBold
		c.TextSize = 20
		c.TextColor3 = Color3.fromRGB(255, 215, 60)
		c.Text = "●"
		c.TextTransparency = 0.2
		c.Parent = parent
		local delay = (i - 1) * 0.03
		task.delay(delay, function()
			if not c.Parent then
				return
			end
			TweenService:Create(
				c,
				TweenInfo.new(1.1 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(c.Position.X.Scale, 0, 1.08, 0), TextTransparency = 1, Rotation = math.random(-25, 25) }
			):Play()
		end)
		task.delay(1.35 + delay, function()
			c:Destroy()
		end)
	end
end

local function clearBadges(container: Frame)
	for _, ch in container:GetChildren() do
		if ch:IsA("Frame") and ch.Name == "MultBadge" then
			ch:Destroy()
		end
	end
end

local function addBadge(container: Frame, text: string, color: Color3, layoutOrder: number)
	local b = Instance.new("Frame")
	b.Name = "MultBadge"
	b.LayoutOrder = layoutOrder
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 26)
	b.BackgroundColor3 = color
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 8)
	cr.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.new(0.1, 0.1, 0.12)
	lbl.Text = text
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Parent = b
	local us = Instance.new("UIScale")
	us.Scale = 0
	us.Parent = b
	b.Parent = container
end

local function buildMultiplierBadges(container: Frame, results: any)
	clearBadges(container)
	local badgeOrder = 0
	local function nextOrder(): number
		badgeOrder += 1
		return badgeOrder
	end
	local bd = results.breakdown
	if type(bd) ~= "table" then
		return
	end
	local founderM = bd.founderMultiplier or results.founderMultiplier or 1
	if type(founderM) == "number" and founderM > 1.001 then
		addBadge(container, `Founder x{string.format("%.2f", founderM)}`, Color3.fromRGB(255, 200, 120), nextOrder())
	end
	local petM = bd.petModifier
	if type(petM) == "number" and petM > 1.001 then
		addBadge(container, `Pets x{string.format("%.2f", petM)}`, Color3.fromRGB(160, 220, 255), nextOrder())
	end
	local premM = bd.premiumMultiplier
	if type(premM) == "number" and premM > 1.001 then
		addBadge(container, `Premium x{string.format("%.2f", premM)}`, Color3.fromRGB(200, 160, 255), nextOrder())
	end
	local passM = bd.passMultiplier
	if type(passM) == "number" and passM >= 1.5 then
		addBadge(container, `Pass x{string.format("%.1f", passM)}`, Color3.fromRGB(120, 255, 180), nextOrder())
	end
	local rotM = bd.runOfDayMultiplier or results.runOfDayMultiplier
	if type(rotM) == "number" and rotM >= 2 then
		addBadge(container, `Run of Day x{rotM}`, Color3.fromRGB(255, 230, 100), nextOrder())
	end
end

function PayoutPanel.show(results: any)
	local refs = uiRefs
	if not refs then
		return
	end
	animToken += 1
	local token = animToken

	if pbPulseConn then
		pbPulseConn:Disconnect()
		pbPulseConn = nil
	end

	local pbExisting = refs.pbBadge:FindFirstChildOfClass("UIScale")
	if pbExisting then
		pbExisting.Scale = 1
	end

	local isRecord = results.isPersonalBest == true
	VFXFacade.runEndFanfare(isRecord)
	runScreenFlash(refs.gui, isRecord)

	local cardUIScale = refs.cardUIScale :: UIScale
	local cardFrame = refs.card :: Frame
	cardUIScale.Scale = 0.7
	cardFrame.BackgroundTransparency = 1

	refs.gui.Enabled = true
	SoundFacade.playOneShot("payout_card_pop")
	TweenService:Create(
		cardUIScale,
		TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	TweenService:Create(
		cardFrame,
		TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	):Play()

	spawnCoinRain(refs.card)

	local celebration = results.runOfDayCelebration == true
	if celebration then
		refs.title.Text = "RUN OF THE DAY!"
		SoundFacade.playOneShot("payout_run_of_day")
	else
		refs.title.Text = "Run complete!"
	end

	refs.pbBadge.Visible = isRecord
	refs.distanceLabel.Text = "0 m"
	refs.lapsLabel.Text = "0"
	refs.coinsLabel.Text = "0"
	refs.bragLabel.Visible = false
	refs.bragLabel.Text = ""
	local bragSc = refs.bragScale :: UIScale
	bragSc.Scale = 1
	local xpEarned = math.max(0, results.battlePassXpEarned or 0)
	local xpAfter = math.max(0, results.battlePassXpAfter or xpEarned)
	local xpBefore = math.max(0, xpAfter - xpEarned)
	local tierBefore = select(1, BattlePassConfig.tierFromXp(xpBefore))
	local tierAfter = select(1, BattlePassConfig.tierFromXp(xpAfter))
	local tierIncreased = tierAfter > tierBefore
	refs.xpGainLabel.Text = `+{Utils.formatNumber(xpEarned)} Season XP`

	local distTarget = results.totalDistance or 0
	local lapsTarget = results.laps or 0
	local coinsTarget = results.coinsEarned or 0

	local dur = 0.85
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if token ~= animToken then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = smoothstep(u)
		refs.distanceLabel.Text = `{Utils.formatNumber(math.floor(distTarget * e))} m`
		refs.lapsLabel.Text = tostring(math.floor(lapsTarget * e + 0.5))
		refs.coinsLabel.Text = Utils.formatNumber(math.floor(coinsTarget * e))

		local xp = xpBefore + (xpAfter - xpBefore) * e
		local tier, prog = BattlePassConfig.tierFromXp(xp)
		refs.xpTierLabel.Text = `Battle Pass • Tier {tier} / {BattlePassConfig.TIER_COUNT}`
		refs.xpFill.Size = UDim2.new(prog, 0, 1, 0)

		if u >= 1 then
			refs.distanceLabel.Text = `{Utils.formatNumber(distTarget)} m`
			refs.lapsLabel.Text = tostring(lapsTarget)
			refs.coinsLabel.Text = Utils.formatNumber(coinsTarget)
			local tEnd, pEnd = BattlePassConfig.tierFromXp(xpAfter)
			refs.xpTierLabel.Text = `Battle Pass • Tier {tEnd} / {BattlePassConfig.TIER_COUNT}`
			refs.xpFill.Size = UDim2.new(pEnd, 0, 1, 0)
			if conn then
				conn:Disconnect()
			end
		end
	end)

	buildMultiplierBadges(refs.multContainer, results)

	local badgeList: { Frame } = {}
	for _, ch in refs.multContainer:GetChildren() do
		if ch:IsA("Frame") and ch.Name == "MultBadge" then
			table.insert(badgeList, ch)
		end
	end
	table.sort(badgeList, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, badge in ipairs(badgeList) do
		local us = badge:FindFirstChildOfClass("UIScale")
		if us then
			local delay = (i - 1) * 0.08
			task.delay(delay, function()
				if token ~= animToken then
					return
				end
				SoundFacade.playOneShot("payout_badge_tick")
				TweenService:Create(us, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		end
	end

	local pbScale = refs.pbBadge:FindFirstChildOfClass("UIScale")
	if not pbScale then
		pbScale = Instance.new("UIScale")
		pbScale.Parent = refs.pbBadge
	end
	pbScale.Scale = 1
	if isRecord then
		local t0 = os.clock()
		pbPulseConn = RunService.RenderStepped:Connect(function()
			if token ~= animToken then
				if pbPulseConn then
					pbPulseConn:Disconnect()
					pbPulseConn = nil
				end
				return
			end
			if not refs.pbBadge.Visible then
				return
			end
			local ph = 1.5
			local w = 0.5 + 0.5 * math.sin((os.clock() - t0) * (math.pi * 2) / ph)
			pbScale.Scale = 1 + 0.15 * w
		end)
	end

	local skulls = results.skullsEarned or 0
	if skulls > 0 then
		VFXFacade.skullDrop(skulls)
	end

	if tierIncreased then
		task.delay(dur, function()
			if token ~= animToken then
				return
			end
			SoundFacade.playOneShot("payout_tier_up")
			battlePassTierBeat(refs.xpBarBg :: Frame, refs.xpTierLabel :: TextLabel)
		end)
	end

	task.delay(dur, function()
		if token ~= animToken then
			return
		end
		local line = pickPayoutFlexLine(results)
		if line == "" then
			return
		end
		refs.bragLabel.Text = line
		refs.bragLabel.Visible = true
		local sc = refs.bragScale :: UIScale
		sc.Scale = 1
		TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
		task.delay(0.15, function()
			if token ~= animToken then
				return
			end
			TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end)
end

function PayoutPanel.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DACPayout"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 88
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.92, 0, 0.88, 0)
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 36)
	card.BorderSizePixel = 0
	card.ZIndex = 10
	card.Parent = gui
	local cardUIScale = Instance.new("UIScale")
	cardUIScale.Scale = 1
	cardUIScale.Parent = card
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(90, 100, 180)
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.35
	cardStroke.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.Parent = card

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.LayoutOrder = 1
	titleBar.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -120, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 213, 79)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Run complete!"
	title.Parent = titleBar

	local pbBadge = Instance.new("TextLabel")
	pbBadge.Name = "PersonalBest"
	pbBadge.Visible = false
	pbBadge.AnchorPoint = Vector2.new(1, 0.5)
	pbBadge.Position = UDim2.new(1, 0, 0.5, 0)
	pbBadge.Size = UDim2.fromOffset(160, 32)
	pbBadge.BackgroundTransparency = 0
	pbBadge.BackgroundColor3 = Color3.fromRGB(255, 60, 120)
	pbBadge.Font = Enum.Font.GothamBold
	pbBadge.TextSize = 15
	pbBadge.TextColor3 = Color3.new(1, 1, 1)
	pbBadge.Text = "NEW RECORD!"
	local pbc = Instance.new("UICorner")
	pbc.CornerRadius = UDim.new(0, 8)
	pbc.Parent = pbBadge
	pbBadge.Parent = titleBar
	local pbUIScale = Instance.new("UIScale")
	pbUIScale.Scale = 1
	pbUIScale.Parent = pbBadge

	local function statRow(labelText: string, order: number): TextLabel
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 36)
		row.LayoutOrder = order
		row.Parent = card

		local left = Instance.new("TextLabel")
		left.Size = UDim2.new(0.45, 0, 1, 0)
		left.BackgroundTransparency = 1
		left.Font = Enum.Font.GothamMedium
		left.TextSize = 18
		left.TextColor3 = Color3.fromRGB(200, 200, 220)
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.Text = labelText
		left.Parent = row

		local right = Instance.new("TextLabel")
		right.Name = "Value"
		right.Size = UDim2.new(0.55, 0, 1, 0)
		right.Position = UDim2.new(0.45, 0, 0, 0)
		right.BackgroundTransparency = 1
		right.Font = Enum.Font.GothamBold
		right.TextSize = 22
		right.TextColor3 = Color3.new(1, 1, 1)
		right.TextXAlignment = Enum.TextXAlignment.Right
		right.Text = "0"
		right.Parent = row
		return right
	end

	local distLabel = statRow("Distance traveled", 2)
	local lapsLabel = statRow("Laps completed", 3)
	local coinsLabel = statRow("Coins earned", 4)

	local bragRow = Instance.new("Frame")
	bragRow.Name = "BragRow"
	bragRow.BackgroundTransparency = 1
	bragRow.Size = UDim2.new(1, 0, 0, 0)
	bragRow.AutomaticSize = Enum.AutomaticSize.Y
	bragRow.LayoutOrder = 5
	bragRow.Parent = card

	local bragLabel = Instance.new("TextLabel")
	bragLabel.Name = "PayoutBrag"
	bragLabel.BackgroundTransparency = 1
	bragLabel.Size = UDim2.new(1, 0, 0, 0)
	bragLabel.AutomaticSize = Enum.AutomaticSize.Y
	bragLabel.Font = Enum.Font.GothamBold
	bragLabel.TextSize = 15
	bragLabel.TextColor3 = Color3.fromRGB(255, 220, 140)
	bragLabel.TextWrapped = true
	bragLabel.TextXAlignment = Enum.TextXAlignment.Center
	bragLabel.Text = ""
	bragLabel.Visible = false
	bragLabel.Parent = bragRow
	local bragScale = Instance.new("UIScale")
	bragScale.Scale = 1
	bragScale.Parent = bragLabel

	local xpHeader = Instance.new("TextLabel")
	xpHeader.BackgroundTransparency = 1
	xpHeader.Size = UDim2.new(1, 0, 0, 22)
	xpHeader.Font = Enum.Font.GothamMedium
	xpHeader.TextSize = 15
	xpHeader.TextColor3 = Color3.fromRGB(180, 190, 255)
	xpHeader.TextXAlignment = Enum.TextXAlignment.Left
	xpHeader.LayoutOrder = 6
	xpHeader.Name = "XpHeader"
	xpHeader.Parent = card

	local xpTierLabel = Instance.new("TextLabel")
	xpTierLabel.Name = "XpTier"
	xpTierLabel.BackgroundTransparency = 1
	xpTierLabel.Size = UDim2.new(1, 0, 0, 24)
	xpTierLabel.Font = Enum.Font.GothamBold
	xpTierLabel.TextSize = 17
	xpTierLabel.TextColor3 = Color3.new(1, 1, 1)
	xpTierLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpTierLabel.Text = "Battle Pass"
	xpTierLabel.LayoutOrder = 7
	xpTierLabel.Parent = card

	local xpGainLabel = Instance.new("TextLabel")
	xpGainLabel.Name = "XpGain"
	xpGainLabel.BackgroundTransparency = 1
	xpGainLabel.Size = UDim2.new(1, 0, 0, 20)
	xpGainLabel.Font = Enum.Font.Gotham
	xpGainLabel.TextSize = 15
	xpGainLabel.TextColor3 = Color3.fromRGB(160, 255, 200)
	xpGainLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpGainLabel.Text = "+0 Season XP"
	xpGainLabel.LayoutOrder = 8
	xpGainLabel.Parent = card

	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XpBarBg"
	xpBarBg.Size = UDim2.new(1, 0, 0, 18)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 32, 55)
	xpBarBg.BorderSizePixel = 0
	xpBarBg.LayoutOrder = 9
	xpBarBg.Parent = card
	local xpBgCorner = Instance.new("UICorner")
	xpBgCorner.CornerRadius = UDim.new(0, 9)
	xpBgCorner.Parent = xpBarBg

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(120, 90, 255)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBarBg
	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 9)
	xpFillCorner.Parent = xpFill
	local xpGrad = Instance.new("UIGradient")
	xpGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 220, 255)),
	})
	xpGrad.Parent = xpFill

	local multWrap = Instance.new("Frame")
	multWrap.Name = "MultWrap"
	multWrap.BackgroundTransparency = 1
	multWrap.Size = UDim2.new(1, 0, 0, 0)
	multWrap.AutomaticSize = Enum.AutomaticSize.Y
	multWrap.LayoutOrder = 10
	multWrap.Parent = card

	local multContainer = Instance.new("Frame")
	multContainer.Name = "MultContainer"
	multContainer.BackgroundTransparency = 1
	multContainer.AutomaticSize = Enum.AutomaticSize.Y
	multContainer.Size = UDim2.new(1, 0, 0, 0)
	multContainer.Parent = multWrap

	local multLayout = Instance.new("UIListLayout")
	multLayout.FillDirection = Enum.FillDirection.Horizontal
	multLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	multLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	multLayout.Padding = UDim.new(0, 8)
	multLayout.Wraps = true
	multLayout.Parent = multContainer

	local btnRow = Instance.new("Frame")
	btnRow.Name = "Buttons"
	btnRow.BackgroundTransparency = 1
	btnRow.Size = UDim2.new(1, 0, 0, 48)
	btnRow.LayoutOrder = 20
	btnRow.Parent = card

	local again = Instance.new("TextButton")
	again.Size = UDim2.new(0.48, -6, 1, 0)
	again.Position = UDim2.new(0, 0, 0, 0)
	again.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	again.Text = "Play Again"
	again.TextColor3 = Color3.new(1, 1, 1)
	again.Font = Enum.Font.GothamBold
	again.TextSize = 18
	again.Parent = btnRow
	local agc = Instance.new("UICorner")
	agc.CornerRadius = UDim.new(0, 10)
	agc.Parent = again

	local lobby = Instance.new("TextButton")
	lobby.Size = UDim2.new(0.48, -6, 1, 0)
	lobby.Position = UDim2.new(0.52, 6, 0, 0)
	lobby.BackgroundColor3 = Color3.fromRGB(70, 110, 220)
	lobby.Text = "Back to Lobby"
	lobby.TextColor3 = Color3.new(1, 1, 1)
	lobby.Font = Enum.Font.GothamBold
	lobby.TextSize = 18
	lobby.Parent = btnRow
	local lbc = Instance.new("UICorner")
	lbc.CornerRadius = UDim.new(0, 10)
	lbc.Parent = lobby

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.ZIndex = 20
	close.Parent = card
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close

	uiRefs = {
		gui = gui,
		card = card,
		cardUIScale = cardUIScale,
		title = title,
		pbBadge = pbBadge,
		distanceLabel = distLabel,
		lapsLabel = lapsLabel,
		coinsLabel = coinsLabel,
		bragLabel = bragLabel,
		bragScale = bragScale,
		xpTierLabel = xpTierLabel,
		xpGainLabel = xpGainLabel,
		xpFill = xpFill,
		xpBarBg = xpBarBg,
		multContainer = multContainer,
	}

	xpHeader.Text = "Season progress"

	close.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
	end)

	again.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
		Remotes.getEvent("StartRun"):FireServer()
	end)

	lobby.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		gui.Enabled = false
	end)

	RunResultsBridge.setHandler(function(results: any)
		PayoutPanel.show(results)
	end)
end

return PayoutPanel
