--!strict
--[[
	Inventory / Garage panel.
	Shell UI pre-built in DACMain.Panels.Inventory; this script wires behavior.
	Car cards, pet cards, and fuse-pick overlays are created dynamically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local SpeedTierCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedTierCopyConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local InventoryPanel = {}

local lastDataSnapshot: any = nil

local fuseMode = false
local fusePick: { string } = {}

local function rarityIndex(r: string): number
	local o: { [string]: number } = { common=1, uncommon=2, rare=3, epic=4, legendary=5, mythic=6 }
	return o[r] or 1
end

local function fuseCoinCostForRarity(r: string): number
	local idx = rarityIndex(r)
	return math.floor(PetConfig.FuseCost.coinCost * (PetConfig.FuseCost.coinCostMultiplier ^ (idx - 1)))
end

local function fuseSelectionValid(data: any): boolean
	if #fusePick ~= PetConfig.FuseCost.petsRequired then return false end
	if not data or type(data.pets) ~= "table" then return false end
	local r0: string? = nil
	for _, uid in fusePick do
		local pet = data.pets[uid]; if not pet then return false end
		local def = PetConfig.Pets[pet.id]; if not def then return false end
		if not r0 then r0 = def.rarity end
		if def.rarity ~= r0 then return false end
	end
	return true
end

local function fuseCanAfford(data: any): boolean
	if not fuseSelectionValid(data) then return false end
	local uid0 = fusePick[1]; local pet = data.pets[uid0]; if not pet then return false end
	local def = PetConfig.Pets[pet.id]; if not def then return false end
	local cost = fuseCoinCostForRarity(def.rarity)
	local coins = if type(data.coins) == "number" then data.coins else 0
	return coins >= cost
end

local function pruneFusePick(data: any)
	if not data or type(data.pets) ~= "table" then return end
	local i = 1
	while i <= #fusePick do
		local uid = fusePick[i]
		if not data.pets[uid] then table.remove(fusePick, i) else i += 1 end
	end
end

local redraw: () -> ()

local function countDiscoveredSpecies(disc: any): number
	if type(disc) ~= "table" then return 0 end
	local n = 0; for _, v in pairs(disc) do if v == true then n += 1 end end; return n
end

local function collectionSubtitleForData(data: any): (string, boolean)
	if type(data) ~= "table" or type(data.pets) ~= "table" then return "", false end
	local petCount = 0; for _ in pairs(data.pets) do petCount += 1 end
	if petCount <= 0 then return "", false end
	local total = PetConfig.getTotalSpeciesCount(); if total <= 0 then return "", false end
	local found = countDiscoveredSpecies(data.discoveredPets)
	local pct = math.floor((found * 100) / total)
	local pool = if pct >= 100 then MicrocopyConfig.CollectionComplete
		elseif pct >= 75 then MicrocopyConfig.CollectionFinal
		elseif pct >= 50 then MicrocopyConfig.CollectionLate
		elseif pct >= 25 then MicrocopyConfig.CollectionMid
		else MicrocopyConfig.CollectionEarly
	local tpl = MicrocopyConfig.pickVariant(pool)
	tpl = tpl:gsub("{FOUND}", tostring(found)):gsub("{TOTAL}", tostring(total)):gsub("{PERCENT}", tostring(pct))
	return tpl, true
end

local function ensureUIScale(gui: GuiObject): UIScale
	local u = gui:FindFirstChildOfClass("UIScale")
	if not u then u = Instance.new("UIScale"); u.Parent = gui end
	return u
end

local function scalePunch(gui: GuiObject)
	local s = ensureUIScale(gui); s.Scale = 1
	TweenService:Create(s, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
	task.delay(0.08, function() TweenService:Create(s, TweenInfo.new(0.16, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play() end)
end

local RARITY_UI_GLOW: { [string]: Color3 } = {
	common = Color3.fromRGB(200, 200, 200), uncommon = Color3.fromRGB(80, 220, 120),
	rare = Color3.fromRGB(100, 180, 255), epic = Color3.fromRGB(200, 120, 255),
	legendary = Color3.fromRGB(255, 200, 80), mythic = Color3.fromRGB(255, 120, 200),
}

local WORLD_TIER: { [string]: string } = {
	grasslands = "common", desert = "rare", frozen = "rare", neon = "premium", volcano = "premium",
}

local WORLD_THEME_COLORS: { [string]: Color3 } = {
	grasslands = Color3.fromRGB(100, 200, 100), desert = Color3.fromRGB(255, 180, 60),
	frozen = Color3.fromRGB(120, 200, 255), neon = Color3.fromRGB(200, 120, 255), volcano = Color3.fromRGB(255, 100, 50),
}

local function rarityPulseStroke(card: Frame, rarity: string)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not stroke then stroke = Instance.new("UIStroke"); stroke.Parent = card end
	local c = RARITY_UI_GLOW[rarity] or RARITY_UI_GLOW.common
	stroke.Color = c; stroke.Thickness = 1; stroke.Transparency = 0.4
	TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 4, Transparency = 0 }):Play()
	task.delay(0.25, function() TweenService:Create(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 2, Transparency = 0.35 }):Play() end)
end

local function worldGlowPulse(card: Frame, worldId: string)
	local stroke = card:FindFirstChildOfClass("UIStroke"); if not stroke then return end
	local themeColor = WORLD_THEME_COLORS[worldId] or Color3.fromRGB(200, 200, 200)
	local origColor = stroke.Color; local origThickness = stroke.Thickness
	stroke.Color = themeColor; stroke.Transparency = 0
	TweenService:Create(stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 6 }):Play()
	task.delay(0.15, function()
		TweenService:Create(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { Thickness = 3, Transparency = 0.3 }):Play()
		task.delay(0.7, function() stroke.Color = origColor; stroke.Thickness = origThickness; stroke.Transparency = 0.35 end)
	end)
end

local function unequipPetJuice(card: Frame)
	SoundFacade.playOneShot("click")
	local farewellPool = SpeedTierCopyConfig.PetUnequipFarewell
	local farewell = if #farewellPool > 0 then farewellPool[math.random(1, #farewellPool)] else "See ya!"
	local bye = Instance.new("TextLabel"); bye.Name="PetUnequipFarewell"; bye.AnchorPoint=Vector2.new(0.5,1); bye.Position=UDim2.new(0.5,0,1,-6); bye.Size=UDim2.new(1,-8,0,22); bye.BackgroundTransparency=1; bye.Font=Enum.Font.GothamBold; bye.TextSize=13; bye.TextColor3=Color3.fromRGB(120,160,255); bye.TextStrokeTransparency=0.45; bye.TextStrokeColor3=Color3.fromRGB(0,0,0); bye.Text=farewell; bye.ZIndex=9; bye.Parent=card
	task.delay(0.05, function() if bye.Parent then TweenService:Create(bye, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency=1, TextStrokeTransparency=1 }):Play() end end)
	task.delay(0.45, function() if bye.Parent then bye:Destroy() end end)
	local s = ensureUIScale(card); s.Scale=1
	TweenService:Create(s, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale=0.85 }):Play()
	task.delay(0.1, function() TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale=1 }):Play() end)
	local dim = Instance.new("Frame"); dim.Name="PetUnequipDim"; dim.BackgroundColor3=Color3.fromRGB(115,115,125); dim.BackgroundTransparency=0.42; dim.BorderSizePixel=0; dim.Size=UDim2.new(1,0,1,0); dim.ZIndex=8; dim.Parent=card
	local corner = Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=dim
	TweenService:Create(dim, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency=1 }):Play()
	task.delay(0.18, function() if dim.Parent then dim:Destroy() end end)
end

local function flashEquippedText(card: Frame)
	local existing = card:FindFirstChild("EquipFlashText"); if existing then existing:Destroy() end
	local lbl = Instance.new("TextLabel"); lbl.Name="EquipFlashText"; lbl.AnchorPoint=Vector2.new(0.5,1); lbl.Position=UDim2.new(0.5,0,0,-4); lbl.Size=UDim2.new(0,120,0,28); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=16; lbl.TextColor3=Color3.fromRGB(40,200,100); lbl.TextStrokeTransparency=0.5; lbl.TextStrokeColor3=Color3.fromRGB(0,0,0); lbl.Text="EQUIPPED!"; lbl.ZIndex=5; lbl.Parent=card
	local s = ensureUIScale(lbl); s.Scale=0; TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale=1 }):Play()
	task.delay(0.75, function() if lbl.Parent then TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency=1, TextStrokeTransparency=1 }):Play(); task.delay(0.2, function() if lbl.Parent then lbl:Destroy() end end) end end)
end

local function premiumShimmer(card: Frame)
	for i = 1, 6 do
		local sparkle = Instance.new("TextLabel"); sparkle.Name="PremiumSparkle"; sparkle.BackgroundTransparency=1; sparkle.Text=string.char(226,156,166); sparkle.TextSize=14; sparkle.TextColor3=Color3.fromRGB(255,220,100); sparkle.Size=UDim2.fromOffset(16,16); sparkle.AnchorPoint=Vector2.new(0.5,0.5); sparkle.Position=UDim2.new(math.random()*0.8+0.1,0,math.random()*0.6+0.2,0); sparkle.ZIndex=6; sparkle.Parent=card
		local s = ensureUIScale(sparkle); s.Scale=0
		task.delay(i*0.04, function() TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale=1.3 }):Play(); task.delay(0.2, function() TweenService:Create(sparkle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency=1 }):Play(); TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale=0 }):Play(); task.delay(0.2, function() if sparkle.Parent then sparkle:Destroy() end end) end) end)
	end
end

local function premiumRideBadge(card: Frame)
	local existing = card:FindFirstChild("PremiumRideBadge"); if existing then existing:Destroy() end
	local badge = Instance.new("TextLabel"); badge.Name="PremiumRideBadge"; badge.AnchorPoint=Vector2.new(0.5,0.5); badge.Position=UDim2.new(0.5,0,0.5,0); badge.Size=UDim2.new(0,130,0,26); badge.BackgroundColor3=Color3.fromRGB(255,200,50); badge.BackgroundTransparency=0.1; badge.Font=Enum.Font.GothamBold; badge.TextSize=14; badge.TextColor3=Color3.fromRGB(40,20,0); badge.Text="PREMIUM RIDE!"; badge.ZIndex=7; badge.Parent=card
	local corner = Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,6); corner.Parent=badge
	local s = ensureUIScale(badge); s.Scale=0; TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale=1 }):Play()
	task.delay(0.8, function() if badge.Parent then TweenService:Create(badge, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency=1, TextTransparency=1 }):Play(); task.delay(0.25, function() if badge.Parent then badge:Destroy() end end) end end)
end

local function animateEquippedBadge(badge: GuiObject)
	badge.Visible = true; local endPos = UDim2.new(1,-4,0,4); badge.Position = UDim2.new(1,72,0,4)
	local s = ensureUIScale(badge); s.Scale=0.5
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale=1 }):Play()
	TweenService:Create(badge, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position=endPos }):Play()
end

local function createEquippedBadge(parent: Frame): TextLabel
	local existing = parent:FindFirstChild("EquippedBadge")
	if existing and existing:IsA("TextLabel") then return existing end
	local b = Instance.new("TextLabel"); b.Name="EquippedBadge"; b.AnchorPoint=Vector2.new(1,0); b.Size=UDim2.new(0,88,0,22); b.Position=UDim2.new(1,-4,0,4); b.BackgroundColor3=Color3.fromRGB(40,160,90); b.BackgroundTransparency=0.15; b.Font=Enum.Font.GothamBold; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text="EQUIPPED"; b.Visible=true; b.ZIndex=3
	local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
	b.Parent = parent; return b
end

local function refresh(scroll: ScrollingFrame, data: any)
	for _, c in scroll:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	if not data or not data.cars then return end
	local equipped = data.equippedCar
	for carId, owned in data.cars do
		local def = CarConfig.Cars[carId]; if not def then continue end
		local unlocked = data.unlockedWorlds[def.worldId]
		local card = Instance.new("Frame"); card.Name=carId; card.BackgroundColor3=Color3.fromRGB(245,245,245); card.BorderSizePixel=0; card.Parent=scroll
		local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=card
		local stroke = Instance.new("UIStroke"); stroke.Color=UIHelpers.rarityStroke(def.worldId=="neon" and "legendary" or "rare"); stroke.Thickness=equipped==carId and 4 or 2; stroke.Parent=card
		local title = Instance.new("TextLabel"); title.Size=UDim2.new(1,-8,0,40); title.Position=UDim2.new(0,4,0,4); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=14; title.TextColor3=Color3.fromRGB(30,30,30); title.TextWrapped=true; title.Text=def.name; title.Parent=card
		local stats = Instance.new("TextLabel"); stats.Size=UDim2.new(1,-8,0,60); stats.Position=UDim2.new(0,4,0,44); stats.BackgroundTransparency=1; stats.Font=Enum.Font.Gotham; stats.TextSize=12; stats.TextColor3=Color3.fromRGB(60,60,60); stats.TextXAlignment=Enum.TextXAlignment.Left; stats.TextYAlignment=Enum.TextYAlignment.Top; stats.TextWrapped=true; stats.Parent=card
		if unlocked then
			local o = owned; stats.Text = "Lv " .. tostring(o.gasLevel) .. "/" .. tostring(o.powerLevel) .. "/" .. tostring(o.speedLevel) .. "\nBase " .. tostring(def.baseStats.gas) .. "/" .. tostring(def.baseStats.power) .. "/" .. tostring(def.baseStats.speed)
			local icon = Instance.new("TextLabel"); icon.Name="CarIconSpin"; icon.Size=UDim2.new(0,30,0,30); icon.Position=UDim2.new(0,6,0,6); icon.BackgroundTransparency=1; icon.Text="\u{1F697}"; icon.TextSize=22; icon.Parent=card
		else stats.Text=`Locked — unlock {def.worldId}`; card.BackgroundColor3=Color3.fromRGB(80,80,80) end
		if equipped == carId then createEquippedBadge(card) end
		local equip = Instance.new("TextButton"); equip.Size=UDim2.new(1,-8,0,28); equip.Position=UDim2.new(0,4,1,-32); equip.BackgroundColor3=Color3.fromRGB(76,175,80); equip.Text=equipped==carId and "Equipped" or "Equip"; equip.TextColor3=Color3.new(1,1,1); equip.Font=Enum.Font.GothamBold; equip.AutoButtonColor=unlocked==true; equip.Parent=card
		local ec = Instance.new("UICorner"); ec.CornerRadius=UDim.new(0,6); ec.Parent=equip
		if unlocked then equip.MouseButton1Click:Connect(function() if equipped~=carId then SoundFacade.playOneShot("equip_item") else SoundFacade.playOneShot("click") end; Remotes.getEvent("EquipCar"):FireServer(carId) end) end
	end

	for carId, def in CarConfig.Cars do
		if data.cars[carId] then continue end
		local unlocked = data.unlockedWorlds[def.worldId]
		local card = Instance.new("Frame"); card.Name="locked_"..carId; card.BackgroundColor3=Color3.fromRGB(50,50,60); card.BorderSizePixel=0; card.Parent=scroll
		local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=card
		local t = Instance.new("TextLabel"); t.Size=UDim2.new(1,-6,0,80); t.BackgroundTransparency=1; t.TextColor3=Color3.fromRGB(200,200,200); t.Font=Enum.Font.GothamBold; t.TextSize=13; t.TextWrapped=true; t.Text=def.name.."\n???"; t.Parent=card
		local price = Instance.new("TextLabel"); price.Size=UDim2.new(1,-6,0,40); price.Position=UDim2.new(0,0,0,80); price.BackgroundTransparency=1; price.Text=if def.price<=0 then "Free" else `{Utils.formatNumber(def.price)} {def.currency}`; price.TextColor3=Color3.fromRGB(255,213,79); price.Parent=card
		local buy = Instance.new("TextButton"); buy.Size=UDim2.new(1,-8,0,26); buy.Position=UDim2.new(0,4,1,-30); buy.BackgroundColor3=Color3.fromRGB(255,193,7); buy.Text="Buy"; buy.TextColor3=Color3.fromRGB(40,40,40); buy.Font=Enum.Font.GothamBold; buy.Parent=card
		buy.MouseButton1Click:Connect(function() if unlocked then SoundFacade.playOneShot("purchase"); Remotes.getEvent("BuyCar"):FireServer(carId) end end)
	end

	if data.pets then
		local petsList: { { uid: string, pet: any } } = {}
		for uid, pet in data.pets do table.insert(petsList, { uid=uid, pet=pet }) end
		table.sort(petsList, function(a, b) return a.uid < b.uid end)
		local markedTutorial = false; local po = 5000
		for _, entry in petsList do
			po += 1; local uid = entry.uid; local pet = entry.pet; local def = PetConfig.Pets[pet.id]
			local card = Instance.new("Frame"); card.Name=uid; card.LayoutOrder=po; card.Size=UDim2.new(0,130,0,120); card.BackgroundColor3=Color3.fromRGB(230,230,250); card.Parent=scroll
			local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=card
			local t = Instance.new("TextLabel"); t.Size=UDim2.new(1,-6,0,56); t.Position=UDim2.new(0,3,0,4); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=12; t.TextColor3=Color3.fromRGB(30,30,30); t.TextWrapped=true; t.Text=def and (def.name .. "\nPow " .. tostring(pet.power)) or pet.id; t.Parent=card
			local equip = Instance.new("TextButton"); equip.Size=UDim2.new(1,-8,0,28); equip.Position=UDim2.new(0,4,1,-32); equip.BackgroundColor3=Color3.fromRGB(63,81,181); equip.Text=pet.equipped and "Equipped" or "Equip"; equip.TextColor3=Color3.new(1,1,1); equip.Font=Enum.Font.GothamBold; equip.Parent=card
			local ec = Instance.new("UICorner"); ec.CornerRadius=UDim.new(0,6); ec.Parent=equip
			if not pet.equipped and not markedTutorial then equip.Name="TutorialPetEquipFirst"; markedTutorial=true end
			if pet.equipped then createEquippedBadge(card) end
			if fuseMode and def ~= nil then
				equip.Visible = false
				local picked = table.find(fusePick, uid) ~= nil
				local pickBtn = Instance.new("TextButton"); pickBtn.Name="FusePick"; pickBtn.Size=UDim2.new(0,44,0,24); pickBtn.Position=UDim2.new(0,4,0,4); pickBtn.BackgroundColor3=if picked then Color3.fromRGB(50,140,90) else Color3.fromRGB(70,70,95); pickBtn.Text=if picked then "\u{2713}" else "+"; pickBtn.TextColor3=Color3.new(1,1,1); pickBtn.Font=Enum.Font.GothamBold; pickBtn.TextSize=16; pickBtn.ZIndex=5; pickBtn.AutoButtonColor=true; pickBtn.Parent=card
				local pc = Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,6); pc.Parent=pickBtn
				pickBtn.MouseButton1Click:Connect(function() SoundFacade.playOneShot("click"); local idx = table.find(fusePick, uid); if idx then table.remove(fusePick, idx) elseif #fusePick < PetConfig.FuseCost.petsRequired then table.insert(fusePick, uid) end; redraw() end)
			else
				equip.Visible = true
				equip.MouseButton1Click:Connect(function() if pet.equipped then return end; SoundFacade.playOneShot("click"); Remotes.getEvent("EquipPet"):FireServer(uid) end)
			end
		end
	end
end

function InventoryPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Inventory") :: Frame

	local collectionSubtitle = root:WaitForChild("CollectionSubtitle") :: TextLabel
	local fuseBar = root:WaitForChild("FusionBar") :: Frame
	local fuseToggleBtn = fuseBar:WaitForChild("FuseToggle") :: TextButton
	local fuseStatusLabel = fuseBar:WaitForChild("FuseStatus") :: TextLabel
	local fuseGoBtn = fuseBar:WaitForChild("FuseGo") :: TextButton
	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame

	local function applyInventoryLayout()
		local showSub = collectionSubtitle.Visible; local showFuse = fuseMode
		fuseBar.Visible = showFuse
		local fuseTop = if showSub then 80 else 48; fuseBar.Position = UDim2.new(0,12,0,fuseTop)
		local top = 52
		if showSub then top = 84 end
		if showFuse then top += 36 end
		scroll.Position = UDim2.new(0,12,0,top); scroll.Size = UDim2.new(1,-24,1,-(top+12))
	end
	applyInventoryLayout()

	local function updateFuseChrome(data: any)
		if not fuseMode or not data then return end
		if #fusePick < PetConfig.FuseCost.petsRequired then fuseStatusLabel.Text = `{#fusePick}/{PetConfig.FuseCost.petsRequired} — tap + on pets`; fuseGoBtn.Enabled = false; return end
		if not fuseSelectionValid(data) then fuseStatusLabel.Text = "All 3 pets must share one rarity"; fuseGoBtn.Enabled = false; return end
		if not fuseCanAfford(data) then
			local pet = data.pets[fusePick[1]]; local def = pet and PetConfig.Pets[pet.id]; local r = def and def.rarity or "common"
			local cost = fuseCoinCostForRarity(r); fuseStatusLabel.Text = `Need {Utils.formatNumber(cost)} coins`; fuseGoBtn.Enabled = false; return
		end
		local pet = data.pets[fusePick[1]]; local def = pet and PetConfig.Pets[pet.id]; local r = def and def.rarity or "common"
		local cost = fuseCoinCostForRarity(r); fuseStatusLabel.Text = `Ready — {Utils.formatNumber(cost)} coins`; fuseGoBtn.Enabled = true
	end

	local function applyCollectionSubtitle(data: any)
		local text, show = collectionSubtitleForData(data); collectionSubtitle.Text = text; collectionSubtitle.Visible = show; applyInventoryLayout()
	end

	local function applyEquipJuice(prev: any, data: any)
		local newCar = data and data.equippedCar; local oldCar = prev and prev.equippedCar
		local carJustEquipped = prev ~= nil and (newCar ~= oldCar) and type(newCar) == "string" and newCar ~= ""
		local newPetUid: string? = nil; local unequipPetUid: string? = nil
		if prev and data and type(data.pets) == "table" then
			for uid, pet in data.pets do
				local oldPet = prev.pets and prev.pets[uid]
				local wasEq = oldPet and oldPet.equipped; local nowEq = pet.equipped
				if nowEq and not wasEq then newPetUid = uid end
				if not unequipPetUid and oldPet and oldPet.equipped and not pet.equipped then unequipPetUid = uid end
			end
		end
		task.defer(function()
			if carJustEquipped then
				local card = scroll:FindFirstChild(newCar)
				if card and card:IsA("Frame") then
					SoundFacade.playOneShot("equip_item"); scalePunch(card)
					local def = CarConfig.Cars[newCar]; local tier = def and WORLD_TIER[def.worldId] or "common"
					VFXFacade.purchaseCelebration("car", tier, newCar)
					local icon = card:FindFirstChild("CarIconSpin")
					if icon and icon:IsA("GuiObject") then icon.Rotation=0; TweenService:Create(icon, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation=360 }):Play() end
					if tier=="rare" and def then worldGlowPulse(card, def.worldId)
					elseif tier=="premium" and def then worldGlowPulse(card, def.worldId); premiumShimmer(card); premiumRideBadge(card) end
					flashEquippedText(card)
					local badge = card:FindFirstChild("EquippedBadge")
					if badge and badge:IsA("GuiObject") then animateEquippedBadge(badge) end
				end
			end
			if newPetUid then
				local card = scroll:FindFirstChild(newPetUid)
				if card and card:IsA("Frame") then
					SoundFacade.playOneShot("equip_item")
					local pet = data.pets[newPetUid]; local def = pet and PetConfig.Pets[pet.id]; local r = def and def.rarity or "common"
					VFXFacade.petEquipEntrance(newPetUid, nil, r); scalePunch(card); rarityPulseStroke(card, r)
					local badge = card:FindFirstChild("EquippedBadge")
					if badge and badge:IsA("GuiObject") then animateEquippedBadge(badge) end
				end
			end
			if unequipPetUid then local ucard = scroll:FindFirstChild(unequipPetUid); if ucard and ucard:IsA("Frame") then unequipPetJuice(ucard) end end
		end)
	end

	redraw = function()
		local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
		local prev = lastDataSnapshot; pruneFusePick(data); applyCollectionSubtitle(data); updateFuseChrome(data); refresh(scroll, data); lastDataSnapshot = data; applyEquipJuice(prev, data)
	end

	fuseToggleBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); fuseMode = not fuseMode
		if not fuseMode then table.clear(fusePick) end
		fuseToggleBtn.Text = if fuseMode then "Fusion: On" else "Fusion: Off"; redraw()
	end)

	fuseGoBtn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		local data = lastDataSnapshot
		if not fuseSelectionValid(data) or not fuseCanAfford(data) then SoundFacade.playOneShot("error"); return end
		Remotes.getEvent("FusePets"):FireServer(fusePick)
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		local prev = lastDataSnapshot; pruneFusePick(data); applyCollectionSubtitle(data); updateFuseChrome(data); refresh(scroll, data); lastDataSnapshot = data; applyEquipJuice(prev, data)
	end)

	redraw()
end

return InventoryPanel
