--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local BattlePassPanel = {}

local function describeReward(r: any): string
	local t = r.type
	if t == "coins" then
		return `Coins x{Utils.formatNumber(r.amount or 0)}`
	elseif t == "gems" then
		return `Gems x{Utils.formatNumber(r.amount or 0)}`
	elseif t == "crystals" then
		return `Crystals x{Utils.formatNumber(r.amount or 0)}`
	elseif t == "skulls" then
		return `Skulls x{Utils.formatNumber(r.amount or 0)}`
	elseif t == "pet_egg" then
		return `Egg: {r.eggId or "?"} x{r.amount or 1}`
	elseif t == "exclusive_car" then
		return `Car: {r.carId or "?"}`
	elseif t == "exclusive_pet" or t == "pet" then
		return `Pet: {r.petId or "?"}`
	elseif t == "car_skin" then
		return `Car skin: {r.carId or "?"}`
	elseif t == "cosmetic" then
		return `Cosmetic: {r.cosmeticId or "?"}`
	elseif t == "speed_boost" then
		return `Speed Boost x{r.amount or 1}`
	elseif t == "luck_boost" then
		return `Luck Boost x{r.amount or 1}`
	elseif t == "bundle" then
		return "Bundle (boosts)"
	elseif t == "title" then
		return `Title: {r.titleId or "?"}`
	elseif t == "none" then
		return "—"
	end
	return tostring(t)
end

function BattlePassPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "BattlePassRoot")
	MenuHub.registerPanel("battlepass", root)
	UIHelpers.titleBar(root, "Battle Pass", function()
		root.Visible = false
	end)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -24, 0, 132)
	header.Position = UDim2.new(0, 12, 0, 48)
	header.BackgroundTransparency = 1
	header.Parent = root

	local seasonLbl = Instance.new("TextLabel")
	seasonLbl.Size = UDim2.new(1, 0, 0, 22)
	seasonLbl.BackgroundTransparency = 1
	seasonLbl.Font = Enum.Font.GothamBold
	seasonLbl.TextSize = 16
	seasonLbl.TextColor3 = Color3.fromRGB(255, 213, 79)
	seasonLbl.TextXAlignment = Enum.TextXAlignment.Left
	seasonLbl.Text = BattlePassConfig.Season.name
	seasonLbl.Parent = header

	local summary = Instance.new("TextLabel")
	summary.Name = "Summary"
	summary.Size = UDim2.new(1, 0, 0, 20)
	summary.Position = UDim2.new(0, 0, 0, 24)
	summary.BackgroundTransparency = 1
	summary.Font = Enum.Font.Gotham
	summary.TextSize = 14
	summary.TextColor3 = Color3.fromRGB(220, 220, 240)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.Text = "Tier —  •  BP XP: —"
	summary.Parent = header

	local barBack = Instance.new("Frame")
	barBack.Name = "XpBarBack"
	barBack.Size = UDim2.new(1, 0, 0, 14)
	barBack.Position = UDim2.new(0, 0, 0, 50)
	barBack.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	barBack.BorderSizePixel = 0
	barBack.Parent = header
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = barBack

	local barFill = Instance.new("Frame")
	barFill.Name = "XpBarFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(100, 200, 120)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 6)
	barFillCorner.Parent = barFill

	local buyPremiumBtn = Instance.new("TextButton")
	buyPremiumBtn.Name = "BuyPremium"
	buyPremiumBtn.Size = UDim2.new(1, 0, 0, 40)
	buyPremiumBtn.Position = UDim2.new(0, 0, 0, 78)
	buyPremiumBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 60)
	buyPremiumBtn.TextColor3 = Color3.new(1, 1, 1)
	buyPremiumBtn.Font = Enum.Font.GothamBold
	buyPremiumBtn.TextSize = 16
	buyPremiumBtn.Text = "BUY PREMIUM"
	buyPremiumBtn.Parent = header
	local premCorner = Instance.new("UICorner")
	premCorner.CornerRadius = UDim.new(0, 10)
	premCorner.Parent = buyPremiumBtn

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TierScroll"
	scroll.Size = UDim2.new(1, -24, 1, -196)
	scroll.Position = UDim2.new(0, 12, 0, 188)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = root

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local tierRows: { [number]: { freeBtn: TextButton, premBtn: TextButton, freeLbl: TextLabel, premLbl: TextLabel } } =
		{}

	local function refresh(data: any)
		if not data or not data.battlePass then
			return
		end
		local bp = data.battlePass
		local xp = bp.xp or 0
		local curTier, prog = BattlePassConfig.tierFromXp(xp)
		summary.Text = `Tier {curTier} / {BattlePassConfig.TIER_COUNT}  •  BP XP: {Utils.formatNumber(xp)}`
		barFill.Size = UDim2.new(math.clamp(prog, 0, 1), 0, 1, 0)

		local premDef = DevProductConfig.Products.battle_pass_premium
		if bp.premium then
			buyPremiumBtn.Visible = false
		else
			buyPremiumBtn.Visible = true
			buyPremiumBtn.Text = `BUY PREMIUM ({premDef and premDef.robuxPrice or "?"} R)`
		end

		for tier = 1, BattlePassConfig.TIER_COUNT do
			local row = tierRows[tier]
			if not row then
				continue
			end
			local def = BattlePassConfig.Tiers[tier]
			if not def then
				continue
			end
			local unlocked = xp >= BattlePassConfig.tierStartXp(tier)
			row.freeLbl.Text = describeReward(def.freeReward)
			row.premLbl.Text = if bp.premium then describeReward(def.premiumReward) else "🔒 Premium"

			local freeClaimed = bp.claimedFree[tier] == true
			local premClaimed = bp.claimedPremium[tier] == true

			row.freeBtn.Text = if freeClaimed then "Claimed" elseif unlocked then "Claim" else "Locked"
			row.freeBtn.AutoButtonColor = not freeClaimed and unlocked
			row.freeBtn.Active = not freeClaimed and unlocked

			row.premBtn.Text = if premClaimed
				then "Claimed"
				elseif not bp.premium then "Premium"
				elseif not unlocked then "Locked"
				else "Claim"
			row.premBtn.AutoButtonColor = bp.premium and unlocked and not premClaimed
			row.premBtn.Active = bp.premium and unlocked and not premClaimed
		end
	end

	for tier = 1, BattlePassConfig.TIER_COUNT do
		local row = Instance.new("Frame")
		row.Name = "Tier" .. tier
		row.Size = UDim2.new(1, -8, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(36, 40, 70)
		row.LayoutOrder = tier
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 10)
		rc.Parent = row

		local tierNum = Instance.new("TextLabel")
		tierNum.Size = UDim2.new(0, 36, 1, 0)
		tierNum.BackgroundTransparency = 1
		tierNum.Font = Enum.Font.GothamBold
		tierNum.TextSize = 16
		tierNum.TextColor3 = Color3.fromRGB(200, 200, 255)
		tierNum.Text = tostring(tier)
		tierNum.Parent = row

		local freeLbl = Instance.new("TextLabel")
		freeLbl.Size = UDim2.new(0.38, -20, 0, 28)
		freeLbl.Position = UDim2.new(0, 40, 0, 6)
		freeLbl.BackgroundTransparency = 1
		freeLbl.Font = Enum.Font.Gotham
		freeLbl.TextSize = 12
		freeLbl.TextColor3 = Color3.new(1, 1, 1)
		freeLbl.TextXAlignment = Enum.TextXAlignment.Left
		freeLbl.TextWrapped = true
		freeLbl.Text = "Free"
		freeLbl.Parent = row

		local premLbl = Instance.new("TextLabel")
		premLbl.Size = UDim2.new(0.38, -20, 0, 28)
		premLbl.Position = UDim2.new(0.52, 0, 0, 6)
		premLbl.BackgroundTransparency = 1
		premLbl.Font = Enum.Font.Gotham
		premLbl.TextSize = 12
		premLbl.TextColor3 = Color3.fromRGB(255, 200, 120)
		premLbl.TextXAlignment = Enum.TextXAlignment.Left
		premLbl.TextWrapped = true
		premLbl.Text = "Premium"
		premLbl.Parent = row

		local freeBtn = Instance.new("TextButton")
		freeBtn.Size = UDim2.new(0.22, 0, 0, 28)
		freeBtn.Position = UDim2.new(0, 40, 0, 38)
		freeBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
		freeBtn.Text = "Claim"
		freeBtn.TextColor3 = Color3.new(1, 1, 1)
		freeBtn.Font = Enum.Font.GothamBold
		freeBtn.TextSize = 12
		freeBtn.Parent = row
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 6)
		fc.Parent = freeBtn

		local premBtn = Instance.new("TextButton")
		premBtn.Size = UDim2.new(0.22, 0, 0, 28)
		premBtn.Position = UDim2.new(0.74, 0, 0, 38)
		premBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 60)
		premBtn.Text = "Claim"
		premBtn.TextColor3 = Color3.new(1, 1, 1)
		premBtn.Font = Enum.Font.GothamBold
		premBtn.TextSize = 12
		premBtn.Parent = row
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 6)
		pc.Parent = premBtn

		freeBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			Remotes.getEvent("ClaimBattlePassTier"):FireServer(tier, "free")
		end)
		premBtn.MouseButton1Click:Connect(function()
			SoundFacade.playOneShot("click")
			Remotes.getEvent("ClaimBattlePassTier"):FireServer(tier, "premium")
		end)

		tierRows[tier] = {
			freeBtn = freeBtn,
			premBtn = premBtn,
			freeLbl = freeLbl,
			premLbl = premLbl,
		}
	end

	buyPremiumBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("purchase")
		Remotes.getEvent("PurchaseDevProduct"):FireServer("battle_pass_premium")
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(refresh)

	task.defer(function()
		local ok, initial = pcall(function()
			return Remotes.getFunction("GetPlayerData"):InvokeServer()
		end)
		if ok and initial then
			refresh(initial)
		end
	end)
end

return BattlePassPanel
