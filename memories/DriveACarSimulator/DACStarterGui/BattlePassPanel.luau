--!strict
--[[
	Battle pass panel.
	Shell UI pre-built in DACMain.Panels.BattlePass; this script wires behavior.
	Tier rows are created dynamically from BattlePassConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local IapPromptGuard = require(DAC:WaitForChild("IapPromptGuard"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local MenuHub = require(script.Parent:WaitForChild("MenuHub"))
local ClientRemoteDebounce = require(DAC:WaitForChild("ClientRemoteDebounce"))

local BattlePassPanel = {}

local lastBpTierClaimFire = { 0 }
local lastBpPremiumPurchaseFire = { 0 }
local lastBpXpTick = { 0 }

local bpClaimSeeded = false
local prevClaimedFree: { [number]: boolean } = {}
local prevClaimedPremium: { [number]: boolean } = {}

local lastBpData: any = nil
local claimPending = false
local claimPendingToken = 0

local function describeReward(r: any): string
	local t = r.type
	if t == "coins" then return `Coins x{Utils.formatNumber(r.amount or 0)}`
	elseif t == "pet_egg" then return `Egg: {r.eggId or "?"} x{r.amount or 1}`
	elseif t == "exclusive_car" then return `Car: {r.carId or "?"}`
	elseif t == "exclusive_pet" or t == "pet" then return `Pet: {r.petId or "?"}`
	elseif t == "car_skin" then return `Car skin: {r.carId or "?"}`
	elseif t == "cosmetic" then return `Cosmetic: {r.cosmeticId or "?"}`
	elseif t == "speed_boost" then return `Speed Boost x{r.amount or 1}`
	elseif t == "luck_boost" then return `Luck Boost x{r.amount or 1}`
	elseif t == "bundle" then return "Bundle (boosts)"
	elseif t == "title" then return `Title: {r.titleId or "?"}`
	elseif t == "none" then return "\u{2014}" end
	return tostring(t)
end

function BattlePassPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("BattlePass") :: Frame
	MenuHub.registerPanel("battlepass", root)

	local titleBar = root:WaitForChild("TitleBar") :: Frame
	titleBar:WaitForChild("Close").MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); root.Visible = false
	end)

	local header = root:WaitForChild("Header") :: Frame
	local seasonLbl = header:WaitForChild("SeasonLabel") :: TextLabel
	seasonLbl.Text = BattlePassConfig.Season.name
	local summary = header:WaitForChild("Summary") :: TextLabel
	local barBack = header:WaitForChild("XpBarBack") :: Frame
	local barFill = barBack:WaitForChild("XpBarFill") :: Frame
	local barGlowStroke = barFill:WaitForChild("XpBarGlow") :: UIStroke
	local buyPremiumBtn = header:WaitForChild("BuyPremium") :: TextButton
	local buyPremiumDefaultBg = buyPremiumBtn.BackgroundColor3
	local bpPremiumDef = DevProductConfig.Products["battle_pass_premium"]
	local bpPremiumPlaceholder = bpPremiumDef ~= nil and bpPremiumDef.productId == 0
	local scroll = root:WaitForChild("TierScroll") :: ScrollingFrame

	local xpBarTween: Tween? = nil
	local xpBarTweenPhase1: Tween? = nil
	local barGlowTween: Tween? = nil
	local prevBpXp: number? = nil

	local tierRows: { [number]: { freeBtn: TextButton, premBtn: TextButton, freeLbl: TextLabel, premLbl: TextLabel } } = {}

	local function punchTierRow(tier: number)
		local refs = tierRows[tier]
		if not refs then
			return
		end
		local row = refs.freeBtn.Parent
		if not row or not row:IsA("Frame") then
			return
		end
		local sc = row:FindFirstChildOfClass("UIScale") :: UIScale?
		if not sc then
			sc = Instance.new("UIScale")
			sc.Parent = row
		end
		sc.Scale = 1
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.07 }):Play()
		task.delay(0.16, function()
			if sc.Parent then
				TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
	end

	local function refresh(data: any)
		if not data or not data.battlePass then return end
		lastBpData = data
		local bp = data.battlePass

		if bpClaimSeeded then
			for tier = 1, BattlePassConfig.TIER_COUNT do
				local freeClaimed = bp.claimedFree[tier] == true
				local premClaimed = bp.claimedPremium[tier] == true
				if freeClaimed and not prevClaimedFree[tier] then
					punchTierRow(tier)
					local def = BattlePassConfig.Tiers[tier]
					VFXFacade.battlePassTierUp(tier, false, def and describeReward(def.freeReward) or nil)
				end
				if premClaimed and not prevClaimedPremium[tier] then
					punchTierRow(tier)
					local def = BattlePassConfig.Tiers[tier]
					VFXFacade.battlePassTierUp(tier, true, def and describeReward(def.premiumReward) or nil)
				end
			end
		end
		for tier = 1, BattlePassConfig.TIER_COUNT do
			prevClaimedFree[tier] = bp.claimedFree[tier] == true
			prevClaimedPremium[tier] = bp.claimedPremium[tier] == true
		end
		bpClaimSeeded = true

		local xp = bp.xp or 0
		if root.Visible and type(prevBpXp) == "number" and xp > prevBpXp then
			if ClientRemoteDebounce.allow(lastBpXpTick, 0.14) then
				SoundFacade.playOneShot("bp_xp_tick")
			end
		end
		prevBpXp = xp

		local curTier, prog = BattlePassConfig.tierFromXp(xp)
		local summaryLine = MicrocopyConfig.BattlePassSummaryProgress
			:gsub("{TIER}", tostring(curTier))
			:gsub("{TIER_MAX}", tostring(BattlePassConfig.TIER_COUNT))
			:gsub("{XP}", Utils.formatNumber(xp))
		local hint = if bp.premium then MicrocopyConfig.BattlePassHintOwned else MicrocopyConfig.BattlePassHintFree
		if bpPremiumPlaceholder and RunService:IsStudio() then
			summary.Text = summaryLine .. "\n" .. hint .. "\n[DEV] Premium productId is 0 — link in Creator Dashboard"
		else
			summary.Text = summaryLine .. "\n" .. hint
		end
		local targetSize = UDim2.new(math.clamp(prog, 0, 1), 0, 1, 0)
		if xpBarTween then xpBarTween:Cancel() end
		if xpBarTweenPhase1 then xpBarTweenPhase1:Cancel() end
		if prog >= 0.02 then
			local over = math.clamp(prog * 1.07, 0, 1)
			local overSize = UDim2.new(over, 0, 1, 0)
			local t1 = TweenService:Create(barFill, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = overSize })
			xpBarTweenPhase1 = t1
			t1:Play()
			t1.Completed:Once(function()
				xpBarTweenPhase1 = nil
				xpBarTween = TweenService:Create(
					barFill,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = targetSize }
				)
				xpBarTween:Play()
			end)
		else
			xpBarTween = TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = targetSize })
			xpBarTween:Play()
		end

		if barGlowTween then barGlowTween:Cancel() end
		if prog >= 0.9 and curTier < BattlePassConfig.TIER_COUNT then
			barGlowStroke.Transparency = 0.35
			barGlowTween = TweenService:Create(barGlowStroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.92 })
			barGlowTween:Play()
		else barGlowStroke.Transparency = 1 end

		local premDef = DevProductConfig.Products.battle_pass_premium
		if bp.premium then
			buyPremiumBtn.Visible = false
		else
			buyPremiumBtn.Visible = true
			if bpPremiumPlaceholder then
				buyPremiumBtn.Text = MicrocopyConfig.IapBuyNotLinked
				buyPremiumBtn.Active = false
				buyPremiumBtn.AutoButtonColor = false
				buyPremiumBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 100)
			else
				buyPremiumBtn.Text = MicrocopyConfig.BattlePassBuyPremiumFormat:gsub(
					"{PRICE}",
					tostring(premDef and premDef.robuxPrice or "?")
				)
				buyPremiumBtn.Active = not IapPromptGuard.isPending()
				buyPremiumBtn.AutoButtonColor = true
				buyPremiumBtn.BackgroundColor3 = buyPremiumDefaultBg
			end
		end

		for tier = 1, BattlePassConfig.TIER_COUNT do
			local row = tierRows[tier]; if not row then continue end
			local def = BattlePassConfig.Tiers[tier]; if not def then continue end
			local unlocked = xp >= BattlePassConfig.tierStartXp(tier)
			row.freeLbl.Text = describeReward(def.freeReward)
			row.premLbl.Text = if bp.premium then describeReward(def.premiumReward) else MicrocopyConfig.BattlePassPremiumLockedReward
			local freeClaimed = bp.claimedFree[tier] == true
			local premClaimed = bp.claimedPremium[tier] == true
			if claimPending then
				row.freeBtn.Text = if freeClaimed then MicrocopyConfig.BattlePassClaimedState elseif unlocked then MicrocopyConfig.BattlePassClaimWorking else MicrocopyConfig.BattlePassLockedState
				row.premBtn.Text = if premClaimed
					then MicrocopyConfig.BattlePassClaimedState
					elseif not bp.premium then MicrocopyConfig.BattlePassPremiumColumnLocked
					elseif not unlocked then MicrocopyConfig.BattlePassLockedState
					else MicrocopyConfig.BattlePassClaimWorking
				row.freeBtn.AutoButtonColor = false
				row.freeBtn.Active = false
				row.premBtn.AutoButtonColor = false
				row.premBtn.Active = false
			else
				row.freeBtn.Text = if freeClaimed then MicrocopyConfig.BattlePassClaimedState elseif unlocked then MicrocopyConfig.BattlePassClaimCta else MicrocopyConfig.BattlePassLockedState
				row.freeBtn.AutoButtonColor = not freeClaimed and unlocked; row.freeBtn.Active = not freeClaimed and unlocked
				row.premBtn.Text = if premClaimed
					then MicrocopyConfig.BattlePassClaimedState
					elseif not bp.premium then MicrocopyConfig.BattlePassPremiumColumnLocked
					elseif not unlocked then MicrocopyConfig.BattlePassLockedState
					else MicrocopyConfig.BattlePassClaimCta
				row.premBtn.AutoButtonColor = bp.premium and unlocked and not premClaimed; row.premBtn.Active = bp.premium and unlocked and not premClaimed
			end
		end
	end

	for tier = 1, BattlePassConfig.TIER_COUNT do
		local row = Instance.new("Frame"); row.Name = "Tier" .. tier; row.Size = UDim2.new(1, -8, 0, 72); row.BackgroundColor3 = Color3.fromRGB(36, 40, 70); row.LayoutOrder = tier; row.Parent = scroll
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 10); rc.Parent = row
		local tierNum = Instance.new("TextLabel"); tierNum.Size=UDim2.new(0,36,1,0); tierNum.BackgroundTransparency=1; tierNum.Font=Enum.Font.GothamBold; tierNum.TextSize=16; tierNum.TextColor3=Color3.fromRGB(200,200,255); tierNum.Text=tostring(tier); tierNum.Parent=row
		local freeLbl = Instance.new("TextLabel"); freeLbl.Size=UDim2.new(0.38,-20,0,28); freeLbl.Position=UDim2.new(0,40,0,6); freeLbl.BackgroundTransparency=1; freeLbl.Font=Enum.Font.Gotham; freeLbl.TextSize=12; freeLbl.TextColor3=Color3.new(1,1,1); freeLbl.TextXAlignment=Enum.TextXAlignment.Left; freeLbl.TextWrapped=true; freeLbl.Text=MicrocopyConfig.BattlePassTrackLabelFree; freeLbl.Parent=row
		local premLbl = Instance.new("TextLabel"); premLbl.Size=UDim2.new(0.38,-20,0,28); premLbl.Position=UDim2.new(0.52,0,0,6); premLbl.BackgroundTransparency=1; premLbl.Font=Enum.Font.Gotham; premLbl.TextSize=12; premLbl.TextColor3=Color3.fromRGB(255,200,120); premLbl.TextXAlignment=Enum.TextXAlignment.Left; premLbl.TextWrapped=true; premLbl.Text=MicrocopyConfig.BattlePassTrackLabelPremium; premLbl.Parent=row
		local freeBtn = Instance.new("TextButton"); freeBtn.Size=UDim2.new(0.22,0,0,28); freeBtn.Position=UDim2.new(0,40,0,38); freeBtn.BackgroundColor3=Color3.fromRGB(80,140,255); freeBtn.Text=MicrocopyConfig.BattlePassClaimCta; freeBtn.TextColor3=Color3.new(1,1,1); freeBtn.Font=Enum.Font.GothamBold; freeBtn.TextSize=12; freeBtn.Parent=row
		local fc = Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,8); fc.Parent=freeBtn
		local premBtn = Instance.new("TextButton"); premBtn.Size=UDim2.new(0.22,0,0,28); premBtn.Position=UDim2.new(0.74,0,0,38); premBtn.BackgroundColor3=Color3.fromRGB(255,140,60); premBtn.Text=MicrocopyConfig.BattlePassClaimCta; premBtn.TextColor3=Color3.new(1,1,1); premBtn.Font=Enum.Font.GothamBold; premBtn.TextSize=12; premBtn.Parent=row
		local pc = Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,8); pc.Parent=premBtn
		freeBtn.MouseButton1Click:Connect(function()
			if claimPending or not ClientRemoteDebounce.allow(lastBpTierClaimFire) then
				return
			end
			SoundFacade.playOneShot("click")
			claimPending = true
			claimPendingToken += 1
			local tok = claimPendingToken
			if lastBpData then
				refresh(lastBpData)
			end
			task.delay(5, function()
				if tok == claimPendingToken and claimPending then
					claimPending = false
					if lastBpData then
						refresh(lastBpData)
					end
				end
			end)
			local rev = 0
			if lastBpData and lastBpData.battlePass and type(lastBpData.battlePass.claimRevision) == "number" then
				rev = lastBpData.battlePass.claimRevision
			end
			Remotes.getEvent("ClaimBattlePassTier"):FireServer(tier, "free", rev)
		end)
		premBtn.MouseButton1Click:Connect(function()
			if claimPending or not ClientRemoteDebounce.allow(lastBpTierClaimFire) then
				return
			end
			SoundFacade.playOneShot("click")
			claimPending = true
			claimPendingToken += 1
			local tok = claimPendingToken
			if lastBpData then
				refresh(lastBpData)
			end
			task.delay(5, function()
				if tok == claimPendingToken and claimPending then
					claimPending = false
					if lastBpData then
						refresh(lastBpData)
					end
				end
			end)
			local rev = 0
			if lastBpData and lastBpData.battlePass and type(lastBpData.battlePass.claimRevision) == "number" then
				rev = lastBpData.battlePass.claimRevision
			end
			Remotes.getEvent("ClaimBattlePassTier"):FireServer(tier, "premium", rev)
		end)
		tierRows[tier] = { freeBtn = freeBtn, premBtn = premBtn, freeLbl = freeLbl, premLbl = premLbl }
	end

	local function onBuyPremium()
		if bpPremiumPlaceholder or IapPromptGuard.isPending() then
			return
		end
		if not ClientRemoteDebounce.allow(lastBpPremiumPurchaseFire, ClientRemoteDebounce.IAP_PROMPT_COOLDOWN_SEC) then
			local uc = MenuHub.getUIController()
			if uc and uc.showNotification then
				uc.showNotification({
					type = "info",
					message = MicrocopyConfig.pickVariant(MicrocopyConfig.IapPurchasePromptBusy),
				})
			end
			return
		end
		SoundFacade.playOneShot("purchase")
		Remotes.getEvent("PurchaseDevProduct"):FireServer("battle_pass_premium")
	end
	buyPremiumBtn.MouseButton1Click:Connect(onBuyPremium)
	buyPremiumBtn.Activated:Connect(onBuyPremium)

	local bpPremiumUnsub = IapPromptGuard.subscribe(function()
		if bpPremiumPlaceholder or not buyPremiumBtn.Visible then
			return
		end
		buyPremiumBtn.Active = not IapPromptGuard.isPending()
	end)

	Remotes.getEvent("BattlePassClaimResult").OnClientEvent:Connect(function()
		claimPending = false
		if lastBpData then
			refresh(lastBpData)
		end
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(refresh)
	task.defer(function()
		local lp = Players.LocalPlayer
		if not lp or not lp.Parent then
			return
		end
		local ok, initial = pcall(function() return Remotes.getFunction("GetPlayerData"):InvokeServer() end)
		if ok and initial and lp.Parent then
			refresh(initial)
		end
	end)

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer ~= Players.LocalPlayer then return end
		bpPremiumUnsub()
	end)
end

return BattlePassPanel
