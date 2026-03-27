--!strict
--[[
	End-of-run payout screen.
	UI is pre-built in StarterGui.DACPayout; this script only wires behavior.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local Z = UILayerStack.z
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local RunResultsBridge = require(DAC:WaitForChild("RunResultsBridge"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))

local PayoutPanel = {}

local function computeStackedMultiplier(results: any): number
	local bd = results.breakdown
	if type(bd) ~= "table" then return 1 end
	local m = 1.0
	local function mul(k: string): number
		local v = (bd :: any)[k]
		if type(v) == "number" and v > 0 then return v end
		return 1
	end
	m *= mul("worldMultiplier")
	m *= mul("petModifier")
	m *= mul("powerMultiplier")
	m *= mul("passMultiplier")
	m *= mul("premiumMultiplier")
	m *= mul("runOfDayMultiplier")
	m *= mul("groupMultiplier")
	m *= mul("friendMultiplier")
	m *= mul("coinBoostMultiplier")
	m *= mul("founderMultiplier")
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
	local rankStr = if type(results.leaderboardRank) == "number" then tostring(results.leaderboardRank) else "\u{2014}"
	local function sub(s: string): string
		return (s:gsub("{COINS}", coinsStr)):gsub("{DISTANCE}", distStr):gsub("{LAPS}", tostring(laps)):gsub("{MULTIPLIER}", multStr):gsub("{RANK}", rankStr)
	end
	if coins <= 0 then
		return sub(pick(MicrocopyConfig.PayoutFlexZeroCoins))
	end
	if coins > 100_000 then
		return sub(pick(MicrocopyConfig.PayoutFlexMega))
	elseif coins > 10000 then
		return sub(pick(MicrocopyConfig.PayoutFlexBig, MicrocopyConfig.PayoutFlexBigOptional))
	elseif isPb then
		return sub(pick(MicrocopyConfig.PayoutFlexPersonalBest))
	elseif m > 3 then
		return sub(pick(MicrocopyConfig.PayoutFlexMultiplier))
	elseif results.runOfDayCelebration == true then
		return sub(pick(MicrocopyConfig.PayoutFlexRunOfDay))
	else
		return sub(pick(MicrocopyConfig.PayoutFlexModest))
	end
end

local function coinsFloor(results: any): number
	return math.floor(results.coinsEarned or 0)
end

-- Second line under main brag: streak > near-miss > soft upsell (at most one).
local function pickPayoutSecondaryLine(results: any): string
	local streak = results.dailyLoginStreak
	if type(streak) == "number" and streak >= 2 then
		return MicrocopyConfig.pickVariant(MicrocopyConfig.PayoutStreakContinuation):gsub("{STREAK}", tostring(streak))
	end
	local chain = results.nearMissBestChain
	if type(chain) == "number" and chain >= 3 then
		local bonusN = 0
		if type(results.nearMissBonusCoins) == "number" then
			bonusN = math.floor(results.nearMissBonusCoins)
		end
		local tpl = MicrocopyConfig.pickVariant(MicrocopyConfig.PayoutNearMissTease)
		return (tpl:gsub("{CHAIN}", tostring(chain))):gsub("{BONUS}", Utils.formatNumber(bonusN))
	end
	local bd = results.breakdown
	if type(bd) == "table" then
		local prem = bd.premiumMultiplier
		if type(prem) == "number" and prem <= 1.001 and coinsFloor(results) >= 5000 then
			return MicrocopyConfig.pickVariant(MicrocopyConfig.PayoutSoftUpsellNoPremium)
		end
		local passM = bd.passMultiplier
		if type(passM) == "number" and passM < 1.5 and coinsFloor(results) >= 5000 then
			return MicrocopyConfig.pickVariant(MicrocopyConfig.PayoutSoftUpsellNoPass)
		end
	end
	return ""
end

local animToken = 0
local uiRefs: any = nil
local pbPulseConn: RBXScriptConnection? = nil
local btnConns: { RBXScriptConnection } = {}

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

local function runScreenFlash(parent: Instance, isRecord: boolean, isRunOfDay: boolean?)
	local rot = isRunOfDay == true
	local f = Instance.new("Frame")
	f.Name = "RunEndFlash"
	local flashCol: Color3
	if isRecord and rot then
		flashCol = Color3.fromRGB(255, 250, 220)
	elseif isRecord then
		flashCol = Color3.new(1, 1, 1)
	elseif rot then
		flashCol = Color3.fromRGB(255, 228, 130)
	else
		flashCol = Color3.fromRGB(255, 200, 70)
	end
	f.BackgroundColor3 = flashCol
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = Z.payoutFlash
	f.Parent = parent
	f.BackgroundTransparency = 0.42
	TweenService:Create(f, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(0.35, function() f:Destroy() end)
end

local function battlePassTierBeat(xpBarBg: Frame, xpTierLabel: TextLabel)
	local j = ClientPerformanceProfile.uiJuiceStrength()
	if j <= 0 then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "TierUpFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 245, 180)
	flash.Size = UDim2.new(1, 8, 1, 8)
	flash.Position = UDim2.new(0.5, 0, 0.5, 0)
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.ZIndex = Z.payoutTierFlash
	flash.BorderSizePixel = 0
	flash.Parent = xpBarBg
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 9); corner.Parent = flash
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(0.45, function() if flash.Parent then flash:Destroy() end end)
	local barScale = xpBarBg:FindFirstChildOfClass("UIScale")
	if not barScale then barScale = Instance.new("UIScale"); barScale.Parent = xpBarBg end
	barScale.Scale = 1
	local barPeak = 1 + 0.06 * j
	TweenService:Create(barScale, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = barPeak }):Play()
	task.delay(0.2, function() TweenService:Create(barScale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play() end)
	local tierScale = xpTierLabel:FindFirstChildOfClass("UIScale")
	if not tierScale then tierScale = Instance.new("UIScale"); tierScale.Parent = xpTierLabel end
	tierScale.Scale = 1
	local tierPeak = 1 + 0.12 * j
	TweenService:Create(tierScale, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = tierPeak }):Play()
	task.delay(0.25, function() TweenService:Create(tierScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play() end)
end

local function spawnCoinRain(parent: Instance, intensityMul: number?, runOfDayTint: boolean?, isRecord: boolean?)
	local m = if type(intensityMul) == "number" and intensityMul > 0 then intensityMul else 1
	local j = ClientPerformanceProfile.uiJuiceStrength()
	local count = math.max(0, math.floor(14 * j * m + 0.5))
	local dotCol: Color3
	if runOfDayTint == true then
		dotCol = Color3.fromRGB(255, 198, 55)
	elseif isRecord == true then
		dotCol = Color3.fromRGB(255, 235, 115)
	else
		dotCol = Color3.fromRGB(255, 215, 60)
	end
	for i = 1, count do
		local c = Instance.new("TextLabel")
		c.Name = "CoinRain"
		c.BackgroundTransparency = 1
		c.Size = UDim2.fromOffset(18, 22)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.new(math.random() * 0.85 + 0.075, 0, -0.05, 0)
		c.ZIndex = Z.payoutCoinRain
		c.Font = Enum.Font.GothamBold
		c.TextSize = 20
		c.TextColor3 = dotCol
		c.Text = "\u{25CF}"
		c.TextTransparency = 0.2
		c.Parent = parent
		local delay = (i - 1) * 0.03
		task.delay(delay, function()
			if not c.Parent then return end
			TweenService:Create(c, TweenInfo.new(1.1 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(c.Position.X.Scale, 0, 1.08, 0), TextTransparency = 1, Rotation = math.random(-25, 25)
			}):Play()
		end)
		task.delay(1.35 + delay, function() c:Destroy() end)
	end
end

local function clearBadges(container: Frame)
	for _, ch in container:GetChildren() do
		if ch:IsA("Frame") and ch.Name == "MultBadge" then ch:Destroy() end
	end
end

local function addBadge(container: Frame, text: string, color: Color3, layoutOrder: number)
	local b = Instance.new("Frame")
	b.Name = "MultBadge"; b.LayoutOrder = layoutOrder
	b.AutomaticSize = Enum.AutomaticSize.X; b.Size = UDim2.fromOffset(0, 26)
	b.BackgroundColor3 = color
	local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 8); cr.Parent = b
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = b
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
	lbl.TextColor3 = Color3.new(0.1, 0.1, 0.12); lbl.Text = text
	lbl.AutomaticSize = Enum.AutomaticSize.X; lbl.Parent = b
	local us = Instance.new("UIScale"); us.Scale = 0; us.Parent = b
	b.Parent = container
end

local function buildMultiplierBadges(container: Frame, results: any)
	clearBadges(container)
	local badgeOrder = 0
	local function nextOrder(): number badgeOrder += 1; return badgeOrder end
	local bd = results.breakdown
	if type(bd) ~= "table" then return end
	local founderM = bd.founderMultiplier or results.founderMultiplier or 1
	if type(founderM) == "number" and founderM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgeFounderFormat:gsub("{MULT}", string.format("%.2f", founderM)),
			Color3.fromRGB(255, 200, 120),
			nextOrder()
		)
	end
	local petM = bd.petModifier
	if type(petM) == "number" and petM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgePetsFormat:gsub("{MULT}", string.format("%.2f", petM)),
			Color3.fromRGB(160, 220, 255),
			nextOrder()
		)
	end
	local premM = bd.premiumMultiplier
	if type(premM) == "number" and premM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgePremiumFormat:gsub("{MULT}", string.format("%.2f", premM)),
			Color3.fromRGB(200, 160, 255),
			nextOrder()
		)
	end
	local passM = bd.passMultiplier
	if type(passM) == "number" and passM >= 1.5 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgePassFormat:gsub("{MULT}", string.format("%.1f", passM)),
			Color3.fromRGB(120, 255, 180),
			nextOrder()
		)
	end
	local coinBoostM = bd.coinBoostMultiplier
	if type(coinBoostM) == "number" and coinBoostM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgeCoinBoostFormat:gsub("{MULT}", string.format("%.1f", coinBoostM)),
			Color3.fromRGB(255, 190, 90),
			nextOrder()
		)
	end
	local rotM = bd.runOfDayMultiplier or results.runOfDayMultiplier
	if type(rotM) == "number" and rotM >= 2 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgeRunOfDayFormat:gsub("{MULT}", tostring(rotM)),
			Color3.fromRGB(255, 230, 100),
			nextOrder()
		)
	end
	local grpM = bd.groupMultiplier
	if type(grpM) == "number" and grpM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgeGroupFormat:gsub("{MULT}", string.format("%.2f", grpM)),
			Color3.fromRGB(180, 200, 255),
			nextOrder()
		)
	end
	local frM = bd.friendMultiplier
	if type(frM) == "number" and frM > 1.001 then
		addBadge(
			container,
			MicrocopyConfig.PayoutBadgeFriendsFormat:gsub("{MULT}", string.format("%.2f", frM)),
			Color3.fromRGB(120, 255, 200),
			nextOrder()
		)
	end
end

local function ensureButtonConns()
	local needsRewire = #btnConns == 0
	if not needsRewire then
		for _, c in btnConns do
			if not c.Connected then
				needsRewire = true
				break
			end
		end
	end
	if not needsRewire then return end
	for _, c in btnConns do if c.Connected then c:Disconnect() end end
	table.clear(btnConns)
	local refs = uiRefs
	if not refs then return end
	local gui = refs.gui
	local card = refs.card :: Frame
	local btnRow = card:FindFirstChild("Buttons") :: Frame
	if not btnRow then return end
	local again = btnRow:FindFirstChild("PlayAgain") :: TextButton?
	local lobby = btnRow:FindFirstChild("BackToLobby") :: TextButton?
	local close = card:FindFirstChild("Close") :: TextButton?
	if close then
		table.insert(btnConns, close.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			SoundFacade.setPayoutModalOpen(false)
			gui.Enabled = false
		end))
	end
	if again then
		table.insert(btnConns, again.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			SoundFacade.setPayoutModalOpen(false)
			gui.Enabled = false
			Remotes.getEvent("StartRun"):FireServer()
		end))
	end
	if lobby then
		table.insert(btnConns, lobby.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			SoundFacade.setPayoutModalOpen(false)
			gui.Enabled = false
			Remotes.getEvent("ReturnToLobby"):FireServer()
		end))
	end
end

function PayoutPanel.show(results: any)
	local refs = uiRefs
	if not refs then return end
	ensureButtonConns()
	animToken += 1
	local token = animToken
	if pbPulseConn then pbPulseConn:Disconnect(); pbPulseConn = nil end
	local pbExisting = refs.pbBadge:FindFirstChildOfClass("UIScale")
	if pbExisting then pbExisting.Scale = 1 end
	local isRecord = results.isPersonalBest == true
	local isRunOfDay = results.runOfDayCelebration == true
	local cardUIScale = refs.cardUIScale :: UIScale
	local cardFrame = refs.card :: Frame
	cardUIScale.Scale = 0.7
	cardFrame.BackgroundTransparency = 1
	-- ScreenGui must be enabled before runScreenFlash so the tween is visible; runEndFanfare SFX must
	-- play before setPayoutModalOpen(true) so duckBus is still at full gain (POLA-606 / RunEndFanfareDesignSpec §B).
	refs.gui.Enabled = true
	VFXFacade.runEndFanfare(isRecord, isRunOfDay)
	runScreenFlash(refs.gui, isRecord, isRunOfDay)
	SoundFacade.setPayoutModalOpen(true)
	local dim = Instance.new("Frame")
	dim.Name = "PayoutAnticipationDim"
	dim.BackgroundColor3 = if isRunOfDay
		then Color3.fromRGB(52, 24, 10)
		elseif isRecord then Color3.fromRGB(6, 10, 28)
		else Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.75
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = Z.payoutAnticipationDim
	dim.Parent = refs.gui
	TweenService:Create(dim, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0.25 }):Play()
	local glow = Instance.new("Frame")
	glow.Name = "PayoutAnticipationGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(60, 60)
	glow.BackgroundColor3 = if isRunOfDay
		then Color3.fromRGB(255, 190, 95)
		elseif isRecord then Color3.fromRGB(255, 245, 180)
		else Color3.fromRGB(130, 140, 220)
	glow.BackgroundTransparency = 0.7
	glow.ZIndex = Z.payoutAnticipationGlow
	glow.BorderSizePixel = 0
	local glowCr = Instance.new("UICorner")
	glowCr.CornerRadius = UDim.new(0.5, 0)
	glowCr.Parent = glow
	glow.Parent = refs.gui
	local glowPulse = TweenService:Create(glow, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Size = UDim2.fromOffset(90, 90),
		BackgroundTransparency = 0.5,
	})
	glowPulse:Play()
	task.delay(0.35, function()
		if token ~= animToken then
			if dim.Parent then
				dim:Destroy()
			end
			if glow.Parent then
				glow:Destroy()
			end
			return
		end
		glowPulse:Cancel()
		if dim.Parent then
			dim:Destroy()
		end
		if glow.Parent then
			glow:Destroy()
		end
		SoundFacade.playOneShot("payout_card_pop")
		TweenService:Create(cardUIScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.25 }):Play()
		TweenService:Create(cardFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.8 }):Play()
		task.delay(0.18, function()
			if token ~= animToken then
				return
			end
			TweenService:Create(cardUIScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(cardFrame, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
			local rainMul = 1.0
			if isRunOfDay then
				rainMul *= 1.45
			end
			if isRecord then
				rainMul *= 1.28
			end
			rainMul = math.clamp(rainMul, 1.0, 2.0)
			spawnCoinRain(refs.card, rainMul, isRunOfDay, isRecord)
		end)
	end)
	if isRunOfDay then
		refs.title.Text = MicrocopyConfig.PayoutTitleRunOfDay
		if isRecord then
			refs.title.TextColor3 = Color3.fromRGB(255, 235, 200)
		else
			refs.title.TextColor3 = Color3.fromRGB(255, 215, 95)
		end
		refs.title.TextStrokeTransparency = 0.4
		refs.title.TextStrokeColor3 = Color3.fromRGB(40, 18, 6)
		SoundFacade.playOneShot("payout_run_of_day")
	else
		refs.title.Text = MicrocopyConfig.PayoutTitleRunComplete
		if isRecord then
			refs.title.TextColor3 = Color3.fromRGB(235, 245, 255)
			refs.title.TextStrokeTransparency = 0.5
			refs.title.TextStrokeColor3 = Color3.fromRGB(15, 35, 55)
		else
			refs.title.TextColor3 = refs.defaultPayoutTitleColor
			refs.title.TextStrokeTransparency = refs.defaultPayoutTitleStrokeTransparency
			refs.title.TextStrokeColor3 = refs.defaultPayoutTitleStrokeColor
		end
	end
	refs.pbBadge.Visible = isRecord
	if isRecord then
		refs.pbBadge.TextColor3 = Color3.fromRGB(255, 220, 100)
		refs.pbBadge.TextStrokeTransparency = 0.35
		refs.pbBadge.TextStrokeColor3 = Color3.fromRGB(55, 28, 0)
	else
		refs.pbBadge.TextColor3 = refs.defaultPbBadgeTextColor
		refs.pbBadge.TextStrokeTransparency = refs.defaultPbBadgeStrokeTransparency
		refs.pbBadge.TextStrokeColor3 = refs.defaultPbBadgeStrokeColor
	end
	if refs.coinsRowNameLabel and type(results.currencyName) == "string" then
		refs.coinsRowNameLabel.Text = results.currencyName .. " earned"
	end
	refs.distanceLabel.Text = "0 m"
	refs.lapsLabel.Text = "0"
	refs.coinsLabel.Text = "0"
	if isRunOfDay then
		refs.distanceLabel.TextColor3 = Color3.fromRGB(255, 235, 210)
		refs.lapsLabel.TextColor3 = Color3.fromRGB(255, 235, 210)
		refs.coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 95)
	elseif isRecord then
		refs.distanceLabel.TextColor3 = Color3.fromRGB(225, 240, 255)
		refs.lapsLabel.TextColor3 = Color3.fromRGB(225, 240, 255)
		refs.coinsLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	else
		refs.distanceLabel.TextColor3 = refs.defaultDistValueColor
		refs.lapsLabel.TextColor3 = refs.defaultLapsValueColor
		refs.coinsLabel.TextColor3 = refs.defaultCoinsValueColor
	end
	refs.bragLabel.Visible = false
	refs.bragLabel.Text = ""
	refs.bragLabel.TextColor3 = refs.defaultBragTextColor
	refs.bragLabel.TextStrokeTransparency = refs.defaultBragStrokeTransparency
	refs.bragLabel.TextStrokeColor3 = refs.defaultBragStrokeColor
	local bragSc = refs.bragScale :: UIScale
	bragSc.Scale = 1
	local xpEarned = math.max(0, results.battlePassXpEarned or 0)
	local xpAfter = math.max(0, results.battlePassXpAfter or xpEarned)
	local xpBefore = math.max(0, xpAfter - xpEarned)
	local tierBefore = select(1, BattlePassConfig.tierFromXp(xpBefore))
	local tierAfter = select(1, BattlePassConfig.tierFromXp(xpAfter))
	local tierIncreased = tierAfter > tierBefore
	refs.xpGainLabel.Text = MicrocopyConfig.PayoutSeasonXpFormat:gsub("{XP}", Utils.formatNumber(xpEarned))
	if isRunOfDay then
		refs.xpTierLabel.TextColor3 = Color3.fromRGB(255, 235, 215)
		refs.xpGainLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		refs.xpFill.BackgroundColor3 = Color3.fromRGB(255, 190, 85)
	elseif isRecord then
		refs.xpTierLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
		refs.xpGainLabel.TextColor3 = Color3.fromRGB(255, 235, 130)
		refs.xpFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	else
		refs.xpTierLabel.TextColor3 = refs.defaultXpTierTextColor
		refs.xpGainLabel.TextColor3 = refs.defaultXpGainTextColor
		refs.xpFill.BackgroundColor3 = refs.defaultXpFillColor
	end
	local distTarget = results.totalDistance or 0
	local lapsTarget = results.laps or 0
	local coinsTarget = results.coinsEarned or 0
	-- Staggered slot-machine reveals: distance → laps → coins+XP (POLA-367).
	local STAGGER_AFTER_CARD = 0.53
	local LINE_DUR = 0.32
	local GAP = 0.07
	local reduced = ClientPerformanceProfile.isReducedMotion()
	local staggerT0 = if reduced then 0 else STAGGER_AFTER_CARD
	local lineDur = if reduced then 0.02 else LINE_DUR
	local gap = if reduced then 0 else GAP
	local tStat0 = os.clock() + staggerT0
	local d1e = tStat0 + lineDur
	local l0 = d1e + gap
	local l1e = l0 + lineDur
	local c0 = l1e + gap
	local c1e = c0 + lineDur
	local totalStatSec = math.max(0, c1e - os.clock())
	local function scheduleStaggerSounds()
		if reduced then
			task.defer(function()
				if token ~= animToken then return end
				if coinsTarget > 0 then
					SoundFacade.playOneShot("payout_big")
					VFXFacade.payoutStaggerBigLine()
				else
					SoundFacade.playOneShot("payout_tick", 1.05)
				end
			end)
			return
		end
		task.delay(staggerT0, function()
			if token ~= animToken then return end
			SoundFacade.playOneShot("payout_tick", 1.0)
		end)
		task.delay(l0, function()
			if token ~= animToken then return end
			SoundFacade.playOneShot("payout_tick", 1.06)
		end)
		task.delay(c0, function()
			if token ~= animToken then return end
			if coinsTarget > 0 then
				SoundFacade.playOneShot("payout_big")
				VFXFacade.payoutStaggerBigLine()
			else
				SoundFacade.playOneShot("payout_tick", 1.12)
			end
		end)
	end
	scheduleStaggerSounds()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if token ~= animToken then if conn then conn:Disconnect() end; return end
		local now = os.clock()
		if now < tStat0 then
			refs.distanceLabel.Text = "0 m"
			refs.lapsLabel.Text = "0"
			refs.coinsLabel.Text = "0"
			local tb0, pb0 = BattlePassConfig.tierFromXp(xpBefore)
			refs.xpTierLabel.Text = MicrocopyConfig.PayoutBattlePassTierFormat
				:gsub("{TIER}", tostring(tb0))
				:gsub("{TIER_MAX}", tostring(BattlePassConfig.TIER_COUNT))
			refs.xpFill.Size = UDim2.new(pb0, 0, 1, 0)
			return
		end
		local function segEase(tStart: number, tEnd: number): number
			if now <= tStart then return 0 end
			if now >= tEnd then return 1 end
			return smoothstep((now - tStart) / math.max(1e-4, tEnd - tStart))
		end
		local eD = segEase(tStat0, d1e)
		local eL = segEase(l0, l1e)
		local eC = segEase(c0, c1e)
		refs.distanceLabel.Text = `{Utils.formatNumber(math.floor(distTarget * eD))} m`
		refs.lapsLabel.Text = tostring(math.floor(lapsTarget * eL + 0.5))
		refs.coinsLabel.Text = Utils.formatNumber(math.floor(coinsTarget * eC))
		local xp = xpBefore + (xpAfter - xpBefore) * eC
		local tier, prog = BattlePassConfig.tierFromXp(xp)
		refs.xpTierLabel.Text = MicrocopyConfig.PayoutBattlePassTierFormat
			:gsub("{TIER}", tostring(tier))
			:gsub("{TIER_MAX}", tostring(BattlePassConfig.TIER_COUNT))
		refs.xpFill.Size = UDim2.new(prog, 0, 1, 0)
		if now >= c1e - 1e-4 then
			refs.distanceLabel.Text = `{Utils.formatNumber(distTarget)} m`
			refs.lapsLabel.Text = tostring(lapsTarget)
			refs.coinsLabel.Text = Utils.formatNumber(coinsTarget)
			local tEnd, pEnd = BattlePassConfig.tierFromXp(xpAfter)
			refs.xpTierLabel.Text = MicrocopyConfig.PayoutBattlePassTierFormat
				:gsub("{TIER}", tostring(tEnd))
				:gsub("{TIER_MAX}", tostring(BattlePassConfig.TIER_COUNT))
			refs.xpFill.Size = UDim2.new(pEnd, 0, 1, 0)
			if conn then conn:Disconnect() end
		end
	end)
	buildMultiplierBadges(refs.multContainer, results)
	local badgeList: { Frame } = {}
	for _, ch in refs.multContainer:GetChildren() do
		if ch:IsA("Frame") and ch.Name == "MultBadge" then table.insert(badgeList, ch) end
	end
	table.sort(badgeList, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	local badgeBaseDelay = totalStatSec + 0.04
	for i, badge in ipairs(badgeList) do
		local us = badge:FindFirstChildOfClass("UIScale")
		if us then
			local d = badgeBaseDelay + (i - 1) * 0.12
			task.delay(d, function()
				if token ~= animToken then return end
				SoundFacade.playOneShot("payout_badge_tick")
				TweenService:Create(us, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		end
	end
	local pbScale = refs.pbBadge:FindFirstChildOfClass("UIScale")
	if not pbScale then pbScale = Instance.new("UIScale"); pbScale.Parent = refs.pbBadge end
	pbScale.Scale = 1
	if isRecord then
		local t0pb = os.clock()
		pbPulseConn = RunService.RenderStepped:Connect(function()
			if token ~= animToken then if pbPulseConn then pbPulseConn:Disconnect(); pbPulseConn = nil end; return end
			if not refs.pbBadge.Visible then return end
			local w = 0.5 + 0.5 * math.sin((os.clock() - t0pb) * (math.pi * 2) / 1.5)
			pbScale.Scale = 1 + 0.15 * w
		end)
	end
	
	if tierIncreased then
		task.delay(totalStatSec + 0.02, function()
			if token ~= animToken then return end
			SoundFacade.playOneShot("payout_tier_up")
			battlePassTierBeat(refs.xpBarBg :: Frame, refs.xpTierLabel :: TextLabel)
		end)
	end
	task.delay(totalStatSec + 0.02, function()
		if token ~= animToken then return end
		local line = pickPayoutFlexLine(results)
		local fs = results.firstSessionOnboarding
		if type(fs) == "table" and fs.offerFirstPayoutCopy == true then
			local ok, r = pcall(function()
				return Remotes.getFunction("FirstSessionOnboarding"):InvokeServer({ kind = "prepareFirstPayout" })
			end)
			if ok and type(r) == "table" and r.applied == true then
				line = r.mainLine
				if type(r.hookLine) == "string" and r.hookLine ~= "" then
					line = line .. "\n" .. r.hookLine
				end
			end
		end
		if not (type(fs) == "table" and fs.offerFirstPayoutCopy == true) then
			local sec = pickPayoutSecondaryLine(results)
			if sec ~= "" then
				line = line .. "\n" .. sec
			end
		end
		if line == "" then return end
		if isRunOfDay then
			refs.bragLabel.TextColor3 = Color3.fromRGB(255, 235, 200)
			refs.bragLabel.TextStrokeTransparency = 0.42
			refs.bragLabel.TextStrokeColor3 = Color3.fromRGB(38, 20, 5)
		elseif isRecord then
			refs.bragLabel.TextColor3 = Color3.fromRGB(230, 245, 255)
			refs.bragLabel.TextStrokeTransparency = 0.48
			refs.bragLabel.TextStrokeColor3 = Color3.fromRGB(12, 32, 52)
		else
			refs.bragLabel.TextColor3 = refs.defaultBragTextColor
			refs.bragLabel.TextStrokeTransparency = refs.defaultBragStrokeTransparency
			refs.bragLabel.TextStrokeColor3 = refs.defaultBragStrokeColor
		end
		refs.bragLabel.Text = line
		refs.bragLabel.Visible = true
		local sc = refs.bragScale :: UIScale
		sc.Scale = 1
		TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
		task.delay(0.15, function()
			if token ~= animToken then return end
			TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end)
end

--[[
	POLA-618: Invalidate run-end animation, strip ephemeral payout children, close modal + audio duck.
	Safe if the panel has not finished init yet (no-op).
]]
function PayoutPanel.forceTeardown()
	local refs = uiRefs
	if not refs then
		return
	end
	animToken += 1
	if pbPulseConn then
		pbPulseConn:Disconnect()
		pbPulseConn = nil
	end
	local gui = refs.gui
	if not gui then
		return
	end
	for _, n in { "PayoutAnticipationDim", "PayoutAnticipationGlow", "RunEndFlash" } do
		local ch = gui:FindFirstChild(n)
		if ch then
			ch:Destroy()
		end
	end
	local card = refs.card
	for _, c in card:GetChildren() do
		if c.Name == "CoinRain" then
			c:Destroy()
		end
	end
	clearBadges(refs.multContainer)
	local cardUIScale = refs.cardUIScale :: UIScale
	local cardFrame = refs.card :: Frame
	cardUIScale.Scale = 1
	if cardFrame.BackgroundTransparency > 0.85 then
		cardFrame.BackgroundTransparency = 0
	end
	local pbScale = refs.pbBadge:FindFirstChildOfClass("UIScale")
	if pbScale then
		pbScale.Scale = 1
	end
	gui.Enabled = false
	SoundFacade.setPayoutModalOpen(false)
end

function PayoutPanel.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("DACPayout") :: ScreenGui
	gui.DisplayOrder = UILayerStack.screenGui.runResults
	local card = gui:WaitForChild("Card") :: Frame
	local cardUIScale = card:WaitForChild("UIScale") :: UIScale
	local titleBar = card:WaitForChild("TitleBar") :: Frame
	local title = titleBar:WaitForChild("Title") :: TextLabel
	local pbBadge = titleBar:WaitForChild("PersonalBest") :: TextLabel
	local distRow = card:WaitForChild("Stat_Distance_traveled") :: Frame
	local lapsRow = card:WaitForChild("Stat_Laps_completed") :: Frame
	local coinsRow = card:WaitForChild("Stat_Coins_earned") :: Frame
	local coinsRowNameLabel = coinsRow:FindFirstChild("Label") :: TextLabel?
	local distLabel = distRow:WaitForChild("Value") :: TextLabel
	local lapsLabel = lapsRow:WaitForChild("Value") :: TextLabel
	local coinsLabel = coinsRow:WaitForChild("Value") :: TextLabel
	local bragRow = card:WaitForChild("BragRow") :: Frame
	local bragLabel = bragRow:WaitForChild("PayoutBrag") :: TextLabel
	local bragScale = bragLabel:WaitForChild("UIScale") :: UIScale
	local xpTierLabel = card:WaitForChild("XpTier") :: TextLabel
	local xpGainLabel = card:WaitForChild("XpGain") :: TextLabel
	local xpBarBg = card:WaitForChild("XpBarBg") :: Frame
	local xpFill = xpBarBg:WaitForChild("Fill") :: Frame
	local multWrap = card:WaitForChild("MultWrap") :: Frame
	local multContainer = multWrap:WaitForChild("MultContainer") :: Frame
	local btnRow = card:WaitForChild("Buttons") :: Frame
	local again = btnRow:WaitForChild("PlayAgain") :: TextButton
	local lobby = btnRow:WaitForChild("BackToLobby") :: TextButton
	local close = card:WaitForChild("Close") :: TextButton

	local function applyPayoutSafeInsets()
		local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(gui)
		local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
		local pad = gui:FindFirstChild("DACPayoutSafePad") :: UIPadding?
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "DACPayoutSafePad"
			pad.Parent = gui
		end
		pad.PaddingLeft = UDim.new(0, math.floor(l + em + 0.5))
		pad.PaddingTop = UDim.new(0, math.floor(t + em + 0.5))
		pad.PaddingRight = UDim.new(0, math.floor(r + em + 0.5))
		pad.PaddingBottom = UDim.new(0, math.floor(b + em + 0.5))
	end
	applyPayoutSafeInsets()
	local payoutLayoutDisconnect = HudSafeArea.onLayoutChanged(applyPayoutSafeInsets)

	uiRefs = {
		gui = gui, card = card, cardUIScale = cardUIScale,
		title = title,
		defaultPayoutTitleColor = title.TextColor3,
		defaultPayoutTitleStrokeTransparency = title.TextStrokeTransparency,
		defaultPayoutTitleStrokeColor = title.TextStrokeColor3,
		pbBadge = pbBadge,
		defaultPbBadgeTextColor = pbBadge.TextColor3,
		defaultPbBadgeStrokeTransparency = pbBadge.TextStrokeTransparency,
		defaultPbBadgeStrokeColor = pbBadge.TextStrokeColor3,
		distanceLabel = distLabel,
		defaultDistValueColor = distLabel.TextColor3,
		defaultLapsValueColor = lapsLabel.TextColor3,
		defaultCoinsValueColor = coinsLabel.TextColor3,
		lapsLabel = lapsLabel, coinsLabel = coinsLabel, coinsRowNameLabel = coinsRowNameLabel,
		bragLabel = bragLabel,
		defaultBragTextColor = bragLabel.TextColor3,
		defaultBragStrokeTransparency = bragLabel.TextStrokeTransparency,
		defaultBragStrokeColor = bragLabel.TextStrokeColor3,
		bragScale = bragScale,
		xpTierLabel = xpTierLabel,
		defaultXpTierTextColor = xpTierLabel.TextColor3,
		defaultXpGainTextColor = xpGainLabel.TextColor3,
		xpGainLabel = xpGainLabel,
		xpFill = xpFill,
		defaultXpFillColor = xpFill.BackgroundColor3,
		xpBarBg = xpBarBg,
		multContainer = multContainer,
	}

	table.insert(btnConns, close.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		SoundFacade.setPayoutModalOpen(false)
		gui.Enabled = false
	end))

	table.insert(btnConns, again.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		SoundFacade.setPayoutModalOpen(false)
		gui.Enabled = false
		Remotes.getEvent("StartRun"):FireServer()
	end))

	table.insert(btnConns, lobby.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		SoundFacade.setPayoutModalOpen(false)
		gui.Enabled = false
		Remotes.getEvent("ReturnToLobby"):FireServer()
	end))

	RunResultsBridge.setHandler(function(results: any)
		PayoutPanel.show(results)
	end)

	-- POLA-550: Resume from rotate/background can strand anticipation overlays or mid-tween card state.
	UserInputService.WindowFocused:Connect(function(focused: boolean)
		if not focused then
			return
		end
		task.defer(function()
			if not gui.Enabled then
				return
			end
			for _, n in { "PayoutAnticipationDim", "PayoutAnticipationGlow" } do
				local ch = gui:FindFirstChild(n)
				if ch then
					ch:Destroy()
				end
			end
			cardUIScale.Scale = 1
			if card.BackgroundTransparency > 0.85 then
				card.BackgroundTransparency = 0
			end
			if pbPulseConn then
				pbPulseConn:Disconnect()
				pbPulseConn = nil
			end
			local pbScale = uiRefs.pbBadge:FindFirstChildOfClass("UIScale")
			if pbScale then
				pbScale.Scale = 1
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(p)
		if p == player then
			if payoutLayoutDisconnect then
				payoutLayoutDisconnect()
			end
		end
	end)
end

return PayoutPanel
