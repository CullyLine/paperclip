--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))

local UIController = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local panels: Frame
local popup: Frame
local actionBar: Frame

local cachedData: any = nil
local registeredPanels: { [string]: Frame } = {}

local PANEL_NAMES = { "Inventory", "Store", "Settings", "Codes", "Rebirth", "EggStore" }
local INV_SUB_PANELS = { "Pets", "Eggs", "Cosmetics", "Stats" }

local RARITY_COLORS: { [string]: Color3 } = {
	common = Color3.fromRGB(200, 200, 200),
	uncommon = Color3.fromRGB(80, 200, 80),
	rare = Color3.fromRGB(60, 120, 255),
	epic = Color3.fromRGB(180, 60, 255),
	legendary = Color3.fromRGB(255, 200, 0),
	mythic = Color3.fromRGB(255, 50, 50),
}

--[[
	Server stores equip state on each pet record (pet.equipped). Inventory slots 1..8 expect
	an ordered list; derive it here instead of duplicating equippedPets on the wire.
]]
local function buildEquippedPetSlots(data: any): { string }
	if type(data) ~= "table" or type(data.pets) ~= "table" then
		return {}
	end
	local equipped: { any } = {}
	for _, pet in pairs(data.pets) do
		if type(pet) == "table" and pet.equipped and type(pet.uid) == "string" then
			table.insert(equipped, pet)
		end
	end
	table.sort(equipped, function(a, b)
		return (a.power or 0) > (b.power or 0)
	end)
	local slots: { string } = {}
	for i = 1, math.min(#equipped, 8) do
		slots[i] = equipped[i].uid
	end
	return slots
end

local function petDefId(petData: any): string?
	if type(petData) ~= "table" then
		return nil
	end
	if type(petData.id) == "string" then
		return petData.id
	end
	local alt = (petData :: any).petId
	if type(alt) == "string" then
		return alt
	end
	return nil
end

local activePanel: string? = nil
local activeInvSub: string? = nil
local activeStoreTab: string? = nil

local selectedEggId: string? = nil
local hoveredPetUid: string? = nil

local toastLabel: TextLabel? = nil
local toastToken = 0

local function setVisible(parent: Instance, childName: string, visible: boolean)
	local ch = parent:FindFirstChild(childName)
	if ch and (ch:IsA("Frame") or ch:IsA("ScrollingFrame") or ch:IsA("ImageLabel")) then
		(ch :: Frame).Visible = visible
	end
end

local function clearChildren(scrollFrame: ScrollingFrame, keepTemplate: string?)
	for _, ch in scrollFrame:GetChildren() do
		if ch:IsA("GuiObject") and ch.Name ~= keepTemplate and not ch:IsA("UIGridLayout") and not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
end

local function findTemplate(scrollFrame: ScrollingFrame, templateName: string): GuiObject?
	local t = scrollFrame:FindFirstChild(templateName)
	if t and t:IsA("GuiObject") then
		t.Visible = false
		return t
	end
	return nil
end

function UIController.registerPanel(id: string, frame: Frame)
	registeredPanels[id] = frame
end

function UIController.closeAll()
	for _, name in PANEL_NAMES do
		setVisible(panels, name, false)
	end
	for _, f in registeredPanels do
		f.Visible = false
	end
	activePanel = nil

	local invPanel = panels:FindFirstChild("Inventory")
	if invPanel then
		for _, sub in INV_SUB_PANELS do
			setVisible(invPanel, sub, false)
		end
		setVisible(invPanel, "EggOpenPrompt", false)
		setVisible(invPanel, "PetHoverFrame", false)
	end

	if popup then
		setVisible(popup, "EggBuy", false)
		setVisible(popup, "Confirm", false)
	end
end

function UIController.openPanel(name: string)
	UIController.closeAll()

	local dacPanel = panels:FindFirstChild(name)
	if dacPanel and (dacPanel:IsA("Frame") or dacPanel:IsA("ScrollingFrame")) then
		(dacPanel :: Frame).Visible = true
	end

	local regPanel = registeredPanels[name]
	if regPanel then
		regPanel.Visible = true
	end

	activePanel = name

	if name == "Inventory" then
		UIController.showInvSub("Pets")
	elseif name == "Store" then
		UIController.showStoreTab("Cars")
	elseif name == "EggStore" then
		UIController.refreshEggStoreOrder()
	end
end

function UIController.togglePanel(name: string)
	if activePanel == name then
		UIController.closeAll()
	else
		UIController.openPanel(name)
	end
end

function UIController.showInvSub(sub: string)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	for _, s in INV_SUB_PANELS do
		setVisible(invPanel, s, s == sub)
	end
	setVisible(invPanel, "EggOpenPrompt", false)
	setVisible(invPanel, "PetHoverFrame", false)
	activeInvSub = sub

	if sub == "Pets" then UIController.populatePets() end
	if sub == "Eggs" then UIController.populateEggs() end
	if sub == "Stats" then UIController.populateStats() end
end

function UIController.showStoreTab(tab: string)
	local storePanel = panels:FindFirstChild("Store")
	if not storePanel then return end
	local content = storePanel:FindFirstChild("Content")
	if not content then return end

	local tabMap: { [string]: string } = {
		Cars = "Cosmetics",
		Exclusives = "Exclusive",
		Gems = "Gems",
	}

	for _, ch in content:GetChildren() do
		if ch:IsA("Frame") or ch:IsA("ScrollingFrame") then
			ch.Visible = false
		end
	end

	local frameName = tabMap[tab]
	if frameName then
		setVisible(content, frameName, true)
	end
	activeStoreTab = tab
end

function UIController.populatePets()
	if not cachedData then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local petsPanel = invPanel:FindFirstChild("Pets")
	if not petsPanel then return end
	local main = petsPanel:FindFirstChild("Main") :: ScrollingFrame
	if not main then return end

	local equipFrame = main:FindFirstChild("Equip") :: ScrollingFrame
	if equipFrame then
		local equippedPets = buildEquippedPetSlots(cachedData)
		for i = 1, 8 do
			local slot = equipFrame:FindFirstChild(tostring(i))
			if slot and slot:IsA("ImageButton") then
				local petUid = equippedPets[i]
				if petUid then
					local petData = UIController.findPetByUid(petUid)
					if petData then
						local pid = petDefId(petData)
						local def = pid and PetConfig.Pets[pid]
						if def then
							slot.Image = ""
							local nameLabel = slot:FindFirstChild("TextLabel")
							if nameLabel and nameLabel:IsA("TextLabel") then
								nameLabel.Text = def.name
							end
							slot.BackgroundColor3 = RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)
						end
					end
				else
					slot.Image = ""
					slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
					local nameLabel = slot:FindFirstChild("TextLabel")
					if nameLabel and nameLabel:IsA("TextLabel") then
						nameLabel.Text = ""
					end
				end
			end
		end
	end

	local invScroll = main:FindFirstChild("Inventory") :: ScrollingFrame
	if invScroll then
		local template = findTemplate(invScroll, "PetTemplate")
		clearChildren(invScroll, "PetTemplate")

		local pets = cachedData.pets or {}
		for _, petData in pets do
			if template then
				local item = template:Clone()
				item.Name = petData.uid or "pet"
				item.Visible = true
				local pid = petDefId(petData)
				local def = pid and PetConfig.Pets[pid]
				if def then
					item.BackgroundColor3 = RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)
					local nameLabel = item:FindFirstChild("TextLabel")
					if nameLabel and nameLabel:IsA("TextLabel") then
						nameLabel.Text = def.name
					end
				end
				if item:IsA("ImageButton") then
					item.MouseButton1Click:Connect(function()
						UIController.showPetHover(petData)
					end)
				end
				item.Parent = invScroll
			end
		end

		local header = main:FindFirstChild("Header")
		if header then
			local total = header:FindFirstChild("Total")
			if total and total:IsA("TextLabel") then
				total.Text = tostring(#pets) .. " Pets"
			end
		end
	end
end

function UIController.findPetByUid(uid: string): any?
	if not cachedData or not cachedData.pets then return nil end
	for _, pet in cachedData.pets do
		if pet.uid == uid then return pet end
	end
	return nil
end

function UIController.showPetHover(petData: any)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local hover = invPanel:FindFirstChild("PetHoverFrame") :: Frame
	if not hover then return end

	local pid = petDefId(petData)
	local def = pid and PetConfig.Pets[pid]
	if not def then return end

	hoveredPetUid = petData.uid
	hover.Visible = true
	hover.BackgroundColor3 = RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)

	local nameLabel = hover:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = def.name
	end
	local rarityLabel = hover:FindFirstChild("Rarity")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = def.rarity:sub(1, 1):upper() .. def.rarity:sub(2)
	end
	local powerLabel = hover:FindFirstChild("Power")
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = tostring(petData.power or def.basePower)
	end
	local gasLabel = hover:FindFirstChild("Gas")
	if gasLabel and gasLabel:IsA("TextLabel") then
		gasLabel.Text = "+0"
	end
	local speedLabel = hover:FindFirstChild("Speed")
	if speedLabel and speedLabel:IsA("TextLabel") then
		speedLabel.Text = "+0"
	end
	local fuseLabel = hover:FindFirstChild("Fuse")
	if fuseLabel and fuseLabel:IsA("TextLabel") then
		fuseLabel.Text = tostring(petData.fuseLevel or 0)
	end
end

function UIController.populateEggs()
	if not cachedData then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local eggsPanel = invPanel:FindFirstChild("Eggs")
	if not eggsPanel then return end
	local main = eggsPanel:FindFirstChild("Main") :: ScrollingFrame
	if not main then return end

	local eggsScroll = main:FindFirstChild("Eggs") :: ScrollingFrame
	if not eggsScroll then return end

	local template = findTemplate(eggsScroll, "EggTemplate")
	clearChildren(eggsScroll, "EggTemplate")

	local playerEggs = cachedData.eggs or {}
	for eggId, eggDef in EggConfig.Eggs do
		local count = playerEggs[eggId] or 0
		if count > 0 and template then
			local item = template:Clone()
			item.Name = eggId
			item.Visible = true

			local nameLabel = item:FindFirstChild("TextLabel")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = eggDef.name .. " x" .. tostring(count)
			end

			if item:IsA("ImageButton") then
				item.MouseButton1Click:Connect(function()
					UIController.showEggPrompt(eggId)
				end)
			end
			item.Parent = eggsScroll
		end
	end
end

function UIController.showEggPrompt(eggId: string)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local prompt = invPanel:FindFirstChild("EggOpenPrompt") :: Frame
	if not prompt then return end

	local def = EggConfig.Eggs[eggId]
	if not def then return end

	selectedEggId = eggId
	prompt.Visible = true

	local nameLabel = prompt:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = def.name
	end
end

function UIController.populateStats()
	if not cachedData then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local statsPanel = invPanel:FindFirstChild("Stats")
	if not statsPanel then return end

	local stats = cachedData.stats or {}

	local fields: { [string]: string } = {
		DiscoveredPets = tostring(stats.discoveredPets or 0),
		EarnedCoins = Utils.formatNumber(stats.earnedCoins or 0),
		TotalEggs = tostring(stats.totalEggs or 0),
		TotalDistance = string.format("%.1f mi", (stats.totalDistance or 0) / 5280),
		["Total Rebirths"] = tostring(cachedData.rebirths or 0),
	}

	for name, text in fields do
		local lbl = statsPanel:FindFirstChild(name)
		if lbl and lbl:IsA("TextLabel") then
			lbl.Text = text
		end
	end
end

function UIController.populateRebirth()
	if not cachedData then return end
	local rebirthPanel = panels:FindFirstChild("Rebirth")
	if not rebirthPanel then return end

	local rebirths = cachedData.rebirths or 0
	local cost = Utils.calculateRebirthCost(rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)

	local costLabel = rebirthPanel:FindFirstChild("Cost")
	if costLabel and costLabel:IsA("TextLabel") then
		costLabel.Text = Utils.formatNumber(cost)
	end

	local crystalsLabel = rebirthPanel:FindFirstChild("Crystals")
	if crystalsLabel and crystalsLabel:IsA("TextLabel") then
		crystalsLabel.Text = "+" .. tostring(RebirthConfig.Rewards.crystals)
	end

	local speedLabel = rebirthPanel:FindFirstChild("Speed")
	if speedLabel and speedLabel:IsA("TextLabel") then
		speedLabel.Text = "+" .. tostring(RebirthConfig.Rewards.speedBoost) .. "%"
	end

	local powerLabel = rebirthPanel:FindFirstChild("Power")
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = "+" .. tostring(RebirthConfig.Rewards.powerBoost) .. "%"
	end

	local gasLabel = rebirthPanel:FindFirstChild("Gas")
	if gasLabel and gasLabel:IsA("TextLabel") then
		gasLabel.Text = "+" .. tostring(RebirthConfig.Rewards.gasBoost) .. "%"
	end
end

function UIController.showEggBuyPopup(eggId: string)
	local eggBuy = popup:FindFirstChild("EggBuy") :: Frame
	if not eggBuy then return end

	local def = EggConfig.Eggs[eggId]
	if not def then return end

	selectedEggId = eggId
	eggBuy.Visible = true

	local title = eggBuy:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = def.name
	end

	local cost1 = eggBuy:FindFirstChild("Cost1")
	if cost1 and cost1:IsA("TextLabel") then
		cost1.Text = Utils.formatNumber(def.price)
	end
	local cost3 = eggBuy:FindFirstChild("Cost3")
	if cost3 and cost3:IsA("TextLabel") then
		cost3.Text = Utils.formatNumber(def.price * 3)
	end
	local cost10 = eggBuy:FindFirstChild("Cost10")
	if cost10 and cost10:IsA("TextLabel") then
		cost10.Text = Utils.formatNumber(def.price * 10)
	end
end

function UIController.showConfirmPopup(title: string, context: string, onYes: () -> ())
	local confirm = popup:FindFirstChild("Confirm") :: Frame
	if not confirm then return end

	confirm.Visible = true

	local tLabel = confirm:FindFirstChild("Title")
	if tLabel and tLabel:IsA("TextLabel") then
		tLabel.Text = title
	end

	local cLabel = confirm:FindFirstChild("Context")
	if cLabel and cLabel:IsA("TextLabel") then
		cLabel.Text = context
	end

	local yesBtn = confirm:FindFirstChild("Yes")
	if yesBtn and yesBtn:IsA("ImageButton") then
		local conn
		conn = yesBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			confirm.Visible = false
			onYes()
		end)
	end

	local noBtn = confirm:FindFirstChild("No")
	if noBtn and noBtn:IsA("ImageButton") then
		local conn
		conn = noBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			confirm.Visible = false
		end)
	end
end

function UIController.onDataUpdate(data: any)
	cachedData = data

	if activePanel == "Inventory" then
		if activeInvSub == "Pets" then UIController.populatePets() end
		if activeInvSub == "Eggs" then UIController.populateEggs() end
		if activeInvSub == "Stats" then UIController.populateStats() end
	end
	if activePanel == "Rebirth" then UIController.populateRebirth() end
end

function UIController.getData(): any?
	return cachedData
end

local function wireCloseButtons()
	for _, name in PANEL_NAMES do
		local panel = panels:FindFirstChild(name)
		if panel then
			local close = panel:FindFirstChild("Close")
			if close and close:IsA("ImageButton") then
				close.MouseButton1Click:Connect(function()
					UIController.closeAll()
				end)
			end
		end
	end

	local invPanel = panels:FindFirstChild("Inventory")
	if invPanel then
		for _, sub in INV_SUB_PANELS do
			local subPanel = invPanel:FindFirstChild(sub)
			if subPanel then
				local close = subPanel:FindFirstChild("Close")
				if close and close:IsA("ImageButton") then
					close.MouseButton1Click:Connect(function()
						UIController.closeAll()
					end)
				end
			end
		end

		local eggPrompt = invPanel:FindFirstChild("EggOpenPrompt")
		if eggPrompt then
			local close = eggPrompt:FindFirstChild("Close")
			if close and close:IsA("ImageButton") then
				close.MouseButton1Click:Connect(function()
					eggPrompt.Visible = false
				end)
			end
		end
	end
end

local TAB_BUTTONS = {
	{ name = "EggShopTab", icon = "rbxassetid://15460672893", panelName = "EggStore", order = 20 },
	{ name = "QuestsTab", icon = "rbxassetid://15473783825", panelName = "quests", order = 30 },
	{ name = "BattlePassTab", icon = "rbxassetid://15475011812", panelName = "battlepass", order = 31 },
	{ name = "CodesTab", icon = "rbxassetid://4871215849", panelName = "Codes", order = 40 },
	{ name = "Stats", icon = "rbxassetid://15473783825", invSub = "Stats", order = 15 },
}

local function wireInventoryTabBar()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local tabBar = invPanel:FindFirstChild("TabBar") :: Frame
	if not tabBar then return end

	local subMap: { [string]: string } = {
		Pets = "Pets",
		Eggs = "Eggs",
		Cosmetics = "Cosmetics",
	}

	local panelMap: { [string]: string } = {
		Shop = "Store",
		Settings = "Settings",
		Rebirth = "Rebirth",
	}

	for _, btn in tabBar:GetChildren() do
		if btn:IsA("ImageButton") then
			local subName = subMap[btn.Name]
			local pName = panelMap[btn.Name]
			if subName then
				btn.MouseButton1Click:Connect(function()
					SoundFacade.playOneShot("click")
					UIController.showInvSub(subName)
				end)
			elseif pName then
				btn.MouseButton1Click:Connect(function()
					SoundFacade.playOneShot("click")
					UIController.openPanel(pName)
				end)
			end
		end
	end

	local DARK_TINT = Color3.fromRGB(0, 0, 0)
	local FULL_COLOR = Color3.new(1, 1, 1)

	for _, def in TAB_BUTTONS do
		if tabBar:FindFirstChild(def.name) then continue end

		local btn = Instance.new("ImageButton")
		btn.Name = def.name
		btn.Size = UDim2.new(0.085, 0, 0.84, 0)
		btn.BackgroundTransparency = 1
		btn.Image = def.icon
		btn.ImageColor3 = DARK_TINT
		btn.AutoButtonColor = true
		btn.LayoutOrder = def.order
		btn.ScaleType = Enum.ScaleType.Fit
		btn.Parent = tabBar

		btn.MouseEnter:Connect(function()
			btn.ImageColor3 = FULL_COLOR
		end)
		btn.MouseLeave:Connect(function()
			btn.ImageColor3 = DARK_TINT
		end)

		if def.invSub then
			local sub = def.invSub
			btn.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("click")
				UIController.showInvSub(sub)
			end)
		elseif def.panelName then
			local pn = def.panelName
			btn.MouseButton1Click:Connect(function()
				SoundFacade.playOneShot("click")
				UIController.openPanel(pn)
			end)
		end
	end
end

local function wireStoreTabBar()
	local storePanel = panels:FindFirstChild("Store")
	if not storePanel then return end
	local tabBar = storePanel:FindFirstChild("TabBar") :: Frame
	if not tabBar then return end

	for _, btn in tabBar:GetChildren() do
		if btn:IsA("ImageButton") and btn.Name ~= "__Placeholder__" then
			btn.MouseButton1Click:Connect(function()
				UIController.showStoreTab(btn.Name)
			end)
		end
	end
end

local function wireEggPromptButtons()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local prompt = invPanel:FindFirstChild("EggOpenPrompt") :: Frame
	if not prompt then return end

	local open1 = prompt:FindFirstChild("Open1")
	if open1 and open1:IsA("ImageButton") then
		open1.MouseButton1Click:Connect(function()
			if selectedEggId then
				Remotes.getEvent("HatchEgg"):FireServer(selectedEggId, 1)
				prompt.Visible = false
			end
		end)
	end

	local open3 = prompt:FindFirstChild("Open3")
	if open3 and open3:IsA("ImageButton") then
		open3.MouseButton1Click:Connect(function()
			if selectedEggId then
				Remotes.getEvent("HatchEgg"):FireServer(selectedEggId, 3)
				prompt.Visible = false
			end
		end)
	end
end

local function wireEggBuyPopup()
	local eggBuy = popup:FindFirstChild("EggBuy") :: Frame
	if not eggBuy then return end

	local amounts = { Buy1 = 1, Buy3 = 3, Buy10 = 10 }
	for btnName, count in amounts do
		local btn = eggBuy:FindFirstChild(btnName)
		if btn and btn:IsA("ImageButton") then
			btn.MouseButton1Click:Connect(function()
				if selectedEggId then
					Remotes.getEvent("BuyEgg"):FireServer(selectedEggId, count)
					eggBuy.Visible = false
				end
			end)
		end
	end

	local noBtn = eggBuy:FindFirstChild("No")
	if noBtn and noBtn:IsA("ImageButton") then
		noBtn.MouseButton1Click:Connect(function()
			eggBuy.Visible = false
		end)
	end
end

local function wirePetActions()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local petsPanel = invPanel:FindFirstChild("Pets")
	if not petsPanel then return end
	local actions = petsPanel:FindFirstChild("ActionButtons") :: Frame
	if not actions then return end

	local best = actions:FindFirstChild("Best")
	if best and best:IsA("ImageButton") then
		best.MouseButton1Click:Connect(function()
			if not cachedData or not cachedData.pets then return end
			local sorted = {}
			for _, p in cachedData.pets do
				table.insert(sorted, p)
			end
			table.sort(sorted, function(a, b)
				return (a.power or 0) > (b.power or 0)
			end)
			for _, eq in ipairs(buildEquippedPetSlots(cachedData)) do
				Remotes.getEvent("UnequipPet"):FireServer(eq)
			end
			for i = 1, math.min(8, #sorted) do
				Remotes.getEvent("EquipPet"):FireServer(sorted[i].uid)
			end
		end)
	end

	local none = actions:FindFirstChild("None")
	if none and none:IsA("ImageButton") then
		none.MouseButton1Click:Connect(function()
			if not cachedData then return end
			for _, eq in ipairs(buildEquippedPetSlots(cachedData)) do
				Remotes.getEvent("UnequipPet"):FireServer(eq)
			end
		end)
	end
end

local function wireEquipSlots()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local petsPanel = invPanel:FindFirstChild("Pets")
	if not petsPanel then return end
	local main = petsPanel:FindFirstChild("Main") :: ScrollingFrame
	if not main then return end
	local equipFrame = main:FindFirstChild("Equip") :: ScrollingFrame
	if not equipFrame then return end

	for i = 1, 8 do
		local slot = equipFrame:FindFirstChild(tostring(i))
		if slot and slot:IsA("ImageButton") then
			slot.MouseButton1Click:Connect(function()
				if not cachedData then return end
				local equippedPets = buildEquippedPetSlots(cachedData)
				local petUid = equippedPets[i]
				if petUid then
					Remotes.getEvent("UnequipPet"):FireServer(petUid)
				end
			end)
		end
	end
end

local function wireCodesPanel()
	local codesPanel = panels:FindFirstChild("Codes")
	if not codesPanel then return end

	local codeFrame = codesPanel:FindFirstChild("Code")
	local claimBtn = codesPanel:FindFirstChild("Claim")
	if not codeFrame or not claimBtn then return end

	local textBox = codeFrame:FindFirstChild("Info")
	if not textBox or not textBox:IsA("TextBox") then return end

	if claimBtn:IsA("ImageButton") then
		claimBtn.MouseButton1Click:Connect(function()
			local code = textBox.Text
			if code and #code > 0 then
				Remotes.getEvent("RedeemCode"):FireServer(code)
				textBox.Text = ""
			end
		end)
	end
end

local SETTINGS_UI_TO_KEY = {
	Driving = "autoCenter",
	OthersPets = "otherPets",
	Trade = "tradeRequests",
	SoundEffects = "sound",
	ParticleEffects = "particles",
}

local function wireSettingsPanel()
	local settingsPanel = panels:FindFirstChild("Settings")
	if not settingsPanel then return end

	for uiName, settingsKey in SETTINGS_UI_TO_KEY do
		local btn = settingsPanel:FindFirstChild(uiName)
		if btn and btn:IsA("ImageButton") then
			btn.MouseButton1Click:Connect(function()
				local settings = cachedData and cachedData.settings or {}
				local newVal = not settings[settingsKey]
				Remotes.getEvent("UpdateSettings"):FireServer({ [settingsKey] = newVal })
			end)
		end
	end
end

local function wireRebirthPanel()
	local rebirthPanel = panels:FindFirstChild("Rebirth")
	if not rebirthPanel then return end

	local rebirthBtn = rebirthPanel:FindFirstChild("Confirm")
	if rebirthBtn and rebirthBtn:IsA("ImageButton") then
		rebirthBtn.MouseButton1Click:Connect(function()
			local rebirths = cachedData and cachedData.rebirths or 0
			local cost = Utils.calculateRebirthCost(rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
			UIController.showConfirmPopup(
				"Rebirth",
				"Are you sure? This costs " .. Utils.formatNumber(cost) .. " coins. Some progress will be reset.",
				function()
					Remotes.getEvent("Rebirth"):FireServer()
				end
			)
		end)
	end
end

local WORLD_DISPLAY: { [string]: string } = {
	grasslands = "Starter World",
	desert = "Desert World",
	frozen = "Frozen World",
	neon = "Neon World",
}

local CURRENCY_PREFIX: { [string]: string } = {
	coins = "$",
	gems = "G ",
	crystals = "C ",
}

local function wireEggStorePanel()
	local eggStorePanel = panels:FindFirstChild("EggStore")
	if not eggStorePanel then return end
	local mainScroll = eggStorePanel:FindFirstChild("Main") :: ScrollingFrame
	if not mainScroll then return end
	local eggsScroll = mainScroll:FindFirstChild("Eggs") :: ScrollingFrame
	if not eggsScroll then return end

	local templateFrame: Frame? = nil
	for _, child in eggsScroll:GetChildren() do
		if child:IsA("Frame") then
			templateFrame = child :: Frame
			break
		end
	end
	if not templateFrame then return end

	local templateContent = templateFrame:FindFirstChild("Content")
	if not templateContent then return end

	local eggBtnTemplate: ImageButton? = nil
	for _, child in templateContent:GetChildren() do
		if child:IsA("ImageButton") then
			eggBtnTemplate = child
			break
		end
	end
	if not eggBtnTemplate then return end

	templateFrame.Visible = false

	local worldGroups: { [string]: { { id: string, def: any } } } = {}
	local worldOrder: { string } = {}
	for eggId, eggDef in EggConfig.Eggs do
		local wid = eggDef.worldId or "unknown"
		if not worldGroups[wid] then
			worldGroups[wid] = {}
			table.insert(worldOrder, wid)
		end
		table.insert(worldGroups[wid], { id = eggId, def = eggDef })
	end

	for idx, wid in worldOrder do
		local section = templateFrame:Clone()
		section.Name = "World_" .. wid
		section.Visible = true
		section.LayoutOrder = idx

		local title = section:FindFirstChild("Title")
		if title then
			local titleLabel = title:FindFirstChild("TextLabel")
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = (WORLD_DISPLAY[wid] or wid) .. " Eggs!"
			end
		end

		local content = section:FindFirstChild("Content")
		if content then
			for _, child in content:GetChildren() do
				if child:IsA("ImageButton") then
					child:Destroy()
				end
			end

			for _, eggInfo in worldGroups[wid] do
				local egg = eggBtnTemplate:Clone()
				egg.Name = eggInfo.id
				egg.Visible = true

				local nameLabel = egg:FindFirstChild("Name")
				if nameLabel and nameLabel:IsA("TextLabel") then
					nameLabel.Text = eggInfo.def.name:upper()
				end

				local costLabel = egg:FindFirstChild("Cost")
				if costLabel and costLabel:IsA("TextLabel") then
					local prefix = CURRENCY_PREFIX[eggInfo.def.currency] or "$"
					costLabel.Text = prefix .. Utils.formatNumber(eggInfo.def.price)
				end

				local eid = eggInfo.id
				egg.MouseButton1Click:Connect(function()
					SoundFacade.playOneShot("click")
					UIController.showEggBuyPopup(eid)
				end)

				egg.Parent = content
			end
		end

		section.Parent = eggsScroll
	end
end

local function createActionBarButtons()
	local origInv = actionBar:FindFirstChild("Inventory")
	if origInv and origInv:IsA("ImageButton") then
		origInv.Size = UDim2.new(0, 64, 0, 64)
		origInv.Position = UDim2.new(0.5, 0, 1, -12)
		origInv.AnchorPoint = Vector2.new(0.5, 1)
		origInv.ZIndex = 10
		origInv.Image = "rbxassetid://15661571191"
		origInv.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
		origInv.BackgroundTransparency = 0.15

		local corner = origInv:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = origInv
		end
		corner.CornerRadius = UDim.new(0, 14)

		local stroke = origInv:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = origInv
		end
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(100, 100, 170)
		stroke.Transparency = 0.2
	end

	local origDrive = actionBar:FindFirstChild("Drive")
	if origDrive then
		origDrive:Destroy()
	end

	local oldBar = actionBar:FindFirstChild("DACButtonBar")
	if oldBar then
		oldBar:Destroy()
	end
end

function UIController.refreshEggStoreOrder()
	local eggStorePanel = panels:FindFirstChild("EggStore")
	if not eggStorePanel then return end
	local mainScroll = eggStorePanel:FindFirstChild("Main") :: ScrollingFrame
	if not mainScroll then return end
	local eggsScroll = mainScroll:FindFirstChild("Eggs") :: ScrollingFrame
	if not eggsScroll then return end

	local currentWorld = cachedData and cachedData.currentWorld or "grasslands"

	for _, child in eggsScroll:GetChildren() do
		if child:IsA("Frame") and child.Name:sub(1, 6) == "World_" then
			local worldId = child.Name:sub(7)
			if worldId == currentWorld then
				child.LayoutOrder = 0
			else
				child.LayoutOrder = child.LayoutOrder < 1 and 1 or child.LayoutOrder
			end
		end
	end
end

function UIController.onCurrencyUpdate(currencies: any)
	if type(currencies) ~= "table" then return end
	if cachedData then
		if currencies.coins ~= nil then cachedData.coins = currencies.coins end
		if currencies.gems ~= nil then cachedData.gems = currencies.gems end
		if currencies.crystals ~= nil then cachedData.crystals = currencies.crystals end
		if currencies.skulls ~= nil then cachedData.skulls = currencies.skulls end
	end
end

function UIController.showNotification(notification: any)
	local msg: string?
	local kind = "info"
	if type(notification) == "table" and notification.message then
		msg = tostring(notification.message)
		if type(notification.type) == "string" then
			kind = notification.type
		end
	elseif type(notification) == "string" then
		msg = notification
	end
	if not msg then
		return
	end
	print("[DAC] " .. msg)

	local sg = screenGui
	if not sg then
		return
	end

	if not toastLabel or not toastLabel.Parent then
		local holder = Instance.new("Frame")
		holder.Name = "DAC_ToastHolder"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(0.9, 0, 0, 56)
		holder.Position = UDim2.new(0.5, 0, 0.88, 0)
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.ZIndex = 500
		holder.Parent = sg

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Toast"
		lbl.BackgroundColor3 = Color3.fromRGB(24, 26, 40)
		lbl.BackgroundTransparency = 0.08
		lbl.BorderSizePixel = 0
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.Size = UDim2.new(1, 0, 0, 0)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.fromScale(0.5, 0.5)
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 16
		lbl.TextWrapped = true
		lbl.Text = ""
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 14)
		padding.PaddingTop = UDim.new(0, 10)
		padding.PaddingBottom = UDim.new(0, 10)
		padding.Parent = lbl
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = lbl
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(80, 90, 140)
		stroke.Transparency = 0.35
		stroke.Parent = lbl
		lbl.Parent = holder
		toastLabel = lbl
	end

	local lbl = toastLabel :: TextLabel
	toastToken += 1
	local token = toastToken
	lbl.Text = msg
	if kind == "success" then
		lbl.TextColor3 = Color3.fromRGB(150, 255, 190)
	elseif kind == "error" then
		lbl.TextColor3 = Color3.fromRGB(255, 160, 160)
	else
		lbl.TextColor3 = Color3.new(1, 1, 1)
	end
	lbl.Visible = true
	lbl.TextTransparency = 1
	TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
	task.delay(3.2, function()
		if token ~= toastToken then
			return
		end
		local tw = TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 1 })
		tw:Play()
		tw.Completed:Connect(function()
			if token == toastToken then
				lbl.Visible = false
			end
		end)
	end)
end

function UIController.showRunResults(_results: any)
	-- PayoutPanel handles run results display
end

function UIController.init()
	screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	panels = screenGui:WaitForChild("Panels") :: Frame
	popup = screenGui:WaitForChild("Popup") :: Frame
	actionBar = screenGui:WaitForChild("ActionBar") :: Frame

	UIController.closeAll()

	wireCloseButtons()
	wireInventoryTabBar()
	wireStoreTabBar()
	wireEggPromptButtons()
	wireEggBuyPopup()
	wirePetActions()
	wireEquipSlots()
	wireCodesPanel()
	wireSettingsPanel()
	wireRebirthPanel()
	wireEggStorePanel()
	createActionBarButtons()

	print("[DAC] UIController initialized")
end

return UIController
