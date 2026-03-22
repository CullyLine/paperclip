--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local RunResultsBridge = require(DAC:WaitForChild("RunResultsBridge"))
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

local rewardChestModuleCache: any = nil
local function getRewardChestAnimation(): any?
	if rewardChestModuleCache then
		return rewardChestModuleCache
	end
	local dac = playerGui:FindFirstChild("DAC")
	if not dac then
		return nil
	end
	local m = dac:FindFirstChild("RewardChestAnimation")
	if not m or not m:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and mod then
		rewardChestModuleCache = mod
		return mod
	end
	return nil
end

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

local OPEN_PANEL_DURATION = 0.2
local CLOSE_PANEL_DURATION = 0.15
local OPEN_START_SCALE = 0.9
local backdrop: Frame? = nil

local function ensureUIScale(gui: GuiObject): UIScale
	local u = gui:FindFirstChildOfClass("UIScale")
	if not u then
		u = Instance.new("UIScale")
		u.Parent = gui
	end
	return u
end

local function getOrigBackgroundTransparency(frame: Frame): number
	if frame:GetAttribute("DACOrigBg") == nil then
		frame:SetAttribute("DACOrigBg", frame.BackgroundTransparency)
	end
	return frame:GetAttribute("DACOrigBg") :: number
end

local function resetPanelTransform(frame: Frame)
	local u = frame:FindFirstChildOfClass("UIScale")
	if u then
		u.Scale = 1
	end
	local orig = frame:GetAttribute("DACOrigBg")
	if orig ~= nil then
		frame.BackgroundTransparency = orig :: number
	end
end

local function ensureBackdrop()
	if backdrop or not screenGui then
		return
	end
	local f = Instance.new("Frame")
	f.Name = "PanelBackdrop"
	f.Size = UDim2.fromScale(1, 1)
	f.Position = UDim2.new()
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 1
	f.Visible = false
	f.Parent = screenGui
	backdrop = f
	local pf = screenGui:FindFirstChild("Panels")
	if pf and pf:IsA("GuiObject") then
		pf.ZIndex = 10
	end
end

local function collectVisibleMainPanels(): { Frame }
	local out: { Frame } = {}
	for _, name in PANEL_NAMES do
		local p = panels:FindFirstChild(name)
		if p and p:IsA("Frame") and p.Visible then
			table.insert(out, p)
		end
	end
	for _, f in registeredPanels do
		if f.Visible then
			table.insert(out, f)
		end
	end
	if popup then
		for _, n in { "EggBuy", "Confirm" } do
			local p = popup:FindFirstChild(n)
			if p and p:IsA("Frame") and p.Visible then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function animatePanelOpen(frame: Frame)
	local scale = ensureUIScale(frame)
	local orig = getOrigBackgroundTransparency(frame)
	frame.BackgroundTransparency = 1
	scale.Scale = OPEN_START_SCALE
	TweenService:Create(
		scale,
		TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	TweenService:Create(
		frame,
		TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = orig }
	):Play()
end

local selectedEggId: string? = nil
local hoveredPetUid: string? = nil

local activeToasts: { any } = {}
local toastIdCounter = 0
local MAX_TOASTS = 3
local TOAST_LIFETIME = 3.5
local TOAST_WIDTH = 320
local TOAST_GAP = 8

local TOAST_ICONS: { [string]: { text: string, color: Color3 } } = {
	success = { text = "\xe2\x9c\x93", color = Color3.fromRGB(80, 220, 120) },
	error = { text = "\xe2\x9c\x97", color = Color3.fromRGB(255, 90, 90) },
	info = { text = "\xe2\x84\xb9", color = Color3.fromRGB(100, 160, 255) },
	-- Daily streak nudges (RetentionController)
	streak_nudge = { text = "\xe2\x9a\xa0", color = Color3.fromRGB(255, 190, 90) },
	streak_urgent = { text = "\xe2\x9a\xa1", color = Color3.fromRGB(255, 120, 60) },
	streak_critical = { text = "\xe2\x9c\x97", color = Color3.fromRGB(255, 60, 80) },
	streak_celebrate = { text = "\xe2\x98\x85", color = Color3.fromRGB(255, 210, 120) },
}

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

local function clearInventoryOverlayState()
	local invPanel = panels:FindFirstChild("Inventory")
	if invPanel then
		for _, sub in INV_SUB_PANELS do
			setVisible(invPanel, sub, false)
		end
		setVisible(invPanel, "EggOpenPrompt", false)
		setVisible(invPanel, "PetHoverFrame", false)
	end
end

function UIController.closeAllInstant()
	for _, name in PANEL_NAMES do
		setVisible(panels, name, false)
	end
	for _, f in registeredPanels do
		f.Visible = false
		resetPanelTransform(f)
	end
	activePanel = nil
	activeInvSub = nil
	activeStoreTab = nil
	clearInventoryOverlayState()

	if popup then
		setVisible(popup, "EggBuy", false)
		setVisible(popup, "Confirm", false)
	end
	if backdrop then
		backdrop.Visible = false
		backdrop.BackgroundTransparency = 1
	end
end

function UIController.closeAll(onComplete: (() -> ())?)
	local toClose = collectVisibleMainPanels()

	local function finishState()
		activePanel = nil
		activeInvSub = nil
		activeStoreTab = nil
		clearInventoryOverlayState()
		if popup then
			setVisible(popup, "EggBuy", false)
			setVisible(popup, "Confirm", false)
		end
		if onComplete then
			onComplete()
		end
	end

	if #toClose == 0 then
		if backdrop then
			backdrop.Visible = false
			backdrop.BackgroundTransparency = 1
		end
		finishState()
		return
	end

	SoundFacade.playOneShot("panel_close")
	for _, f in toClose do
		local scale = ensureUIScale(f)
		TweenService:Create(
			scale,
			TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.87 }
		):Play()
		TweenService:Create(
			f,
			TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
	end
	if backdrop and backdrop.Visible then
		TweenService:Create(
			backdrop,
			TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
	end
	task.delay(CLOSE_PANEL_DURATION, function()
		for _, f in toClose do
			f.Visible = false
			resetPanelTransform(f)
		end
		if backdrop then
			backdrop.Visible = false
			backdrop.BackgroundTransparency = 1
		end
		finishState()
	end)
end

function UIController.openPanel(name: string)
	UIController.closeAll(function()
		SoundFacade.playOneShot("panel_open")
		activePanel = name

		local dacPanel = panels:FindFirstChild(name)
		if dacPanel and (dacPanel:IsA("Frame") or dacPanel:IsA("ScrollingFrame")) then
			local fr = dacPanel :: Frame
			fr.Visible = true
			animatePanelOpen(fr)
		end

		local regPanel = registeredPanels[name]
		if regPanel then
			regPanel.Visible = true
			animatePanelOpen(regPanel)
		end

		if backdrop then
			backdrop.Visible = true
			backdrop.BackgroundTransparency = 1
			TweenService:Create(
				backdrop,
				TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 0.52 }
			):Play()
		end

		if name == "Inventory" then
			UIController.showInvSub("Pets")
		elseif name == "Store" then
			UIController.showStoreTab("Cars")
		elseif name == "EggStore" then
			UIController.refreshEggStoreOrder()
		elseif name == "Rebirth" then
			UIController.populateRebirth()
		end
	end)
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

local function getPetModelsFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild("PetModels")
	if f and f:IsA("Folder") then return f end
	return nil
end

local function renderPetModelInSlot(slot: GuiObject, modelName: string)
	local petFolder = getPetModelsFolder()
	if not petFolder then return end
	local tpl = petFolder:FindFirstChild(modelName)
	if not tpl or not tpl:IsA("Model") then return end

	local vf = slot:FindFirstChildOfClass("ViewportFrame")
	if not vf then
		vf = Instance.new("ViewportFrame")
		vf.Name = "PetViewport"
		vf.Size = UDim2.fromScale(1, 0.75)
		vf.Position = UDim2.fromScale(0.5, 0.35)
		vf.AnchorPoint = Vector2.new(0.5, 0.5)
		vf.BackgroundTransparency = 1
		vf.Parent = slot
	end
	for _, ch in vf:GetChildren() do
		ch:Destroy()
	end

	local model = tpl:Clone()
	model.Parent = vf
	if not model.PrimaryPart then
		local p = model:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then model.PrimaryPart = p end
	end

	local cam = Instance.new("Camera")
	cam.Parent = vf
	vf.CurrentCamera = cam

	if model.PrimaryPart then
		local cf = model:GetBoundingBox()
		local _, size = model:GetBoundingBox()
		local dist = math.max(size.X, size.Y, size.Z) * 1.8 + 2
		cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.6, dist * 0.35, dist), cf.Position)
	end
end

local function clearSlotVisuals(slot: GuiObject)
	if slot:IsA("ImageButton") or slot:IsA("ImageLabel") then
		(slot :: any).Image = ""
	end
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	for _, child in slot:GetChildren() do
		if child:IsA("TextLabel") then
			child.Text = ""
		end
		if child:IsA("ViewportFrame") then
			for _, ch in child:GetChildren() do
				ch:Destroy()
			end
		end
	end
end

local function updateSlotPowerLabel(slot: GuiObject, power: number)
	local powerStr = Utils.formatNumber(power)
	for _, child in slot:GetDescendants() do
		if child:IsA("TextLabel") then
			local n = string.lower(child.Name)
			if n == "power" or n == "powerlabel" or n == "powertext" then
				child.Text = powerStr
				return
			end
		end
	end
	-- Fall back to a TextLabel that looks like it shows a number (template default like "1.08k").
	for _, child in slot:GetChildren() do
		if child:IsA("TextLabel") and child.Name ~= "TextLabel" then
			local txt = child.Text:gsub("[%s,]", "")
			if tonumber(txt) or txt:match("^[%d%.]+[kKmM]?$") then
				child.Text = powerStr
				return
			end
		end
	end
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
							slot.Visible = true
							slot.Image = ""
							slot.BackgroundColor3 = RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)
							local nameLabel = slot:FindFirstChild("TextLabel")
							if nameLabel and nameLabel:IsA("TextLabel") then
								nameLabel.Text = def.name
							end
							renderPetModelInSlot(slot, def.modelName)
							updateSlotPowerLabel(slot, petData.power or def.basePower)
						end
					end
				else
					clearSlotVisuals(slot)
					slot.Visible = false
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
					renderPetModelInSlot(item, def.modelName)
					updateSlotPowerLabel(item, petData.power or def.basePower)
				end

				if item:IsA("GuiButton") then
					local petRef = petData
					item.MouseButton1Click:Connect(function()
						UIController.showPetHover(petRef)
					end)
				else
					local overlay = item:FindFirstChild("_PetClickTarget")
					if not overlay then
						overlay = Instance.new("TextButton")
						overlay.Name = "_PetClickTarget"
						overlay.Size = UDim2.fromScale(1, 1)
						overlay.BackgroundTransparency = 1
						overlay.Text = ""
						overlay.ZIndex = 50
						overlay.Parent = item
					end
					if overlay:IsA("GuiButton") then
						local petRef = petData
						overlay.MouseButton1Click:Connect(function()
							UIController.showPetHover(petRef)
						end)
					end
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

local hoverEquipConn: RBXScriptConnection? = nil

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
	local nicknameLabel = hover:FindFirstChild("Nickname")
	if nicknameLabel and nicknameLabel:IsA("TextLabel") then
		nicknameLabel.Text = petData.nickname and ('"' .. petData.nickname .. '"') or ""
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

	-- Equip / Unequip button inside the hover panel.
	local equipBtn = hover:FindFirstChild("Equip") or hover:FindFirstChild("EquipButton")
	if not equipBtn then
		equipBtn = Instance.new("TextButton")
		equipBtn.Name = "EquipButton"
		equipBtn.Size = UDim2.new(0.9, 0, 0, 32)
		equipBtn.Position = UDim2.new(0.5, 0, 1, -40)
		equipBtn.AnchorPoint = Vector2.new(0.5, 0)
		equipBtn.Font = Enum.Font.GothamBold
		equipBtn.TextSize = 14
		equipBtn.TextColor3 = Color3.new(1, 1, 1)
		equipBtn.AutoButtonColor = true
		equipBtn.Parent = hover
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0, 8)
		ec.Parent = equipBtn
	end

	local isEquipped = petData.equipped == true
	if equipBtn:IsA("TextButton") or equipBtn:IsA("ImageButton") then
		local tb = equipBtn :: TextButton
		tb.Text = isEquipped and "Unequip" or "Equip"
		tb.BackgroundColor3 = isEquipped and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(80, 180, 80)

		if hoverEquipConn then
			hoverEquipConn:Disconnect()
		end
		hoverEquipConn = tb.MouseButton1Click:Connect(function()
			local uid = hoveredPetUid
			if not uid then return end
			SoundFacade.playOneShot("click")
			if isEquipped then
				Remotes.getEvent("UnequipPet"):FireServer(uid)
			else
				Remotes.getEvent("EquipPet"):FireServer(uid)
			end
			hover.Visible = false
		end)
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
	local eggBuy = popup:FindFirstChild("EggBuy") :: Frame?
	if not eggBuy then
		warn("[DAC] DACMain.Popup.EggBuy is missing — egg clicks cannot show the buy dialog")
		return
	end

	local def = EggConfig.Eggs[eggId]
	if not def then
		warn("[DAC] Unknown egg id:", eggId)
		return
	end

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

local function resolveTrophyIcon(): string
	local images = ReplicatedStorage:FindFirstChild("Images")
	if not images then
		return ""
	end
	local KEYWORDS = { "trophy", "award", "achievement", "medal", "cup", "star" }
	for _, child in images:GetChildren() do
		local n = string.lower(child.Name)
		for _, kw in KEYWORDS do
			if string.find(n, kw, 1, true) then
				if child:IsA("Decal") then return child.Texture end
				if child:IsA("ImageLabel") or child:IsA("ImageButton") then return child.Image end
			end
		end
	end
	for _, child in images:GetChildren() do
		if child:IsA("Decal") and child.Texture ~= "" then return child.Texture end
		if (child:IsA("ImageLabel") or child:IsA("ImageButton")) and child.Image ~= "" then return child.Image end
	end
	return ""
end

local TAB_BUTTONS = {
	{ name = "EggShopTab", icon = "rbxassetid://15460672893", panelName = "EggStore", order = 20 },
	{ name = "QuestsTab", icon = "rbxassetid://15473783825", panelName = "quests", order = 30 },
	{ name = "BattlePassTab", icon = "rbxassetid://15475011812", panelName = "battlepass", order = 31 },
	{ name = "CodesTab", icon = "rbxassetid://4871215849", panelName = "Codes", order = 40 },
	{ name = "Stats", icon = "rbxassetid://15473783825", invSub = "Stats", order = 15 },
	{ name = "TrophyTab", icon = "", panelName = "trophyCase", order = 25 },
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
					SoundFacade.playOneShot("tab_switch")
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

	local trophyIcon = resolveTrophyIcon()

	for _, def in TAB_BUTTONS do
		if tabBar:FindFirstChild(def.name) then continue end

		local icon = def.icon
		if def.name == "TrophyTab" and trophyIcon ~= "" then
			icon = trophyIcon
		end

		local btn = Instance.new("ImageButton")
		btn.Name = def.name
		btn.Size = UDim2.new(0.085, 0, 0.84, 0)
		btn.BackgroundTransparency = 1
		btn.Image = icon
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
				SoundFacade.playOneShot("tab_switch")
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
				SoundFacade.playOneShot("tab_switch")
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

	local function wirePopupButton(btn: Instance?, onClick: () -> ())
		if btn and btn:IsA("GuiButton") then
			local last = 0.0
			local function fire()
				local now = os.clock()
				if now - last < 0.06 then
					return
				end
				last = now
				onClick()
			end
			btn.MouseButton1Click:Connect(fire)
			btn.Activated:Connect(fire)
		end
	end

	local amounts = { Buy1 = 1, Buy3 = 3, Buy10 = 10 }
	for btnName, count in amounts do
		wirePopupButton(eggBuy:FindFirstChild(btnName), function()
			if selectedEggId then
				Remotes.getEvent("BuyEgg"):FireServer(selectedEggId, count)
				eggBuy.Visible = false
			end
		end)
	end

	wirePopupButton(eggBuy:FindFirstChild("No"), function()
		eggBuy.Visible = false
	end)
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

local function findRebirthActionButton(parent: Instance): GuiButton?
	for _, child in parent:GetChildren() do
		if child.Name == "Close" then continue end
		if child:IsA("ImageButton") or child:IsA("TextButton") then
			return child :: GuiButton
		end
	end
	return nil
end

local function wireRebirthPanel()
	local rebirthPanel = panels:FindFirstChild("Rebirth")
	if not rebirthPanel then return end

	local rebirthBtn = rebirthPanel:FindFirstChild("Confirm")
		or findRebirthActionButton(rebirthPanel)

	if rebirthBtn and (rebirthBtn:IsA("ImageButton") or rebirthBtn:IsA("TextButton")) then
		rebirthBtn.Activated:Connect(function()
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

local LAYOUT_CLASSES: { [string]: boolean } = {
	UIListLayout = true,
	UIGridLayout = true,
	UIPadding = true,
	UIAspectRatioConstraint = true,
	UICorner = true,
	UIStroke = true,
	UIScale = true,
	UIPageLayout = true,
	UITableLayout = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
}

local function isLayoutObject(inst: Instance): boolean
	return LAYOUT_CLASSES[inst.ClassName] ~= nil
end

-- Log the EggStore hierarchy so we can see what the Studio template actually contains.
local function dumpHierarchy(inst: Instance, depth: number, maxDepth: number)
	local indent = string.rep("  ", depth)
	local extra = ""
	if inst:IsA("GuiObject") then
		extra = " Visible=" .. tostring((inst :: GuiObject).Visible)
	end
	print(indent .. inst.ClassName .. ' "' .. inst.Name .. '"' .. extra)
	if depth < maxDepth then
		for _, child in inst:GetChildren() do
			dumpHierarchy(child, depth + 1, maxDepth)
		end
	end
end

-- Find the first non-layout GuiObject child (the egg slot template).
local function findSlotTemplate(container: Instance): GuiObject?
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") and not isLayoutObject(child) and child.Name ~= "Title" then
			return child :: GuiObject
		end
	end
	return nil
end

-- Add a full-size transparent TextButton over a non-button slot so it receives clicks.
local function ensureClickTarget(slot: GuiObject): GuiButton
	if slot:IsA("GuiButton") then
		slot.Active = true
		return slot :: GuiButton
	end
	local existing = slot:FindFirstChild("_EggClickTarget")
	if existing and existing:IsA("GuiButton") then
		return existing :: GuiButton
	end
	local overlay = Instance.new("TextButton")
	overlay.Name = "_EggClickTarget"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.new()
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.ZIndex = 100
	overlay.Active = true
	overlay.Parent = slot
	return overlay
end

-- Ensure all children of a slot don't steal input from the click target.
local function passthroughChildren(slot: GuiObject)
	for _, d in slot:GetDescendants() do
		if d.Name == "_EggClickTarget" then
			continue
		end
		if d:IsA("GuiObject") then
			d.Active = false
		end
	end
end

local function wireEggStorePanel()
	local eggStorePanel = panels:FindFirstChild("EggStore")
	if not eggStorePanel then
		warn("[DAC] EggStore: Panels.EggStore not found")
		return
	end

	-- Find Main → Eggs (required structure)
	local mainFrame = eggStorePanel:FindFirstChild("Main")
	if not mainFrame then
		warn("[DAC] EggStore: no 'Main' child — dumping hierarchy:")
		dumpHierarchy(eggStorePanel, 0, 3)
		return
	end
	local eggsContainer = mainFrame:FindFirstChild("Eggs")
	if not eggsContainer then
		warn("[DAC] EggStore: no 'Eggs' under Main — dumping hierarchy:")
		dumpHierarchy(mainFrame, 0, 3)
		return
	end

	-- Dump the eggs container so we can see exactly what's there.
	print("[DAC] EggStore wiring — Eggs hierarchy:")
	dumpHierarchy(eggsContainer, 0, 4)

	-- Strategy A: section-based (Frame with Title + Content or direct egg children)
	-- Strategy B: flat (egg slots are direct children of Eggs)
	-- Detect which we have.

	local sectionTemplate: Frame? = nil
	for _, child in eggsContainer:GetChildren() do
		if child:IsA("Frame") and not isLayoutObject(child) then
			sectionTemplate = child :: Frame
			break
		end
	end

	-- Determine where the egg slot template lives.
	local slotContainer: Instance
	local slotTemplate: GuiObject?

	if sectionTemplate then
		local content = sectionTemplate:FindFirstChild("Content")
		slotContainer = content or sectionTemplate
		slotTemplate = findSlotTemplate(slotContainer)
	else
		slotContainer = eggsContainer
		slotTemplate = findSlotTemplate(slotContainer)
	end

	if not slotTemplate then
		warn("[DAC] EggStore: no egg slot template found (need a Frame/ImageButton/etc under the egg grid). Hierarchy was dumped above.")
		return
	end

	print("[DAC] EggStore: slot template found — " .. slotTemplate.ClassName .. ' "' .. slotTemplate.Name .. '" (isButton=' .. tostring(slotTemplate:IsA("GuiButton")) .. ")")

	-- Hide the template(s).
	slotTemplate.Visible = false
	if sectionTemplate then
		sectionTemplate.Visible = false
	end

	-- Group eggs by world.
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

	local totalWired = 0

	if sectionTemplate then
		-- Clone section per world, populate with egg slots.
		for idx, wid in worldOrder do
			local section = sectionTemplate:Clone()
			section.Name = "World_" .. wid
			section.Visible = true
			section.LayoutOrder = idx

			local title = section:FindFirstChild("Title")
			if title then
				for _, d in title:GetDescendants() do
					if d:IsA("GuiObject") then
						d.Active = false
					end
				end
				if title:IsA("TextLabel") then
					title.Text = (WORLD_DISPLAY[wid] or wid) .. " Eggs!"
				else
					local titleLabel = title:FindFirstChild("TextLabel")
					if titleLabel and titleLabel:IsA("TextLabel") then
						titleLabel.Text = (WORLD_DISPLAY[wid] or wid) .. " Eggs!"
					end
				end
			end

			local contentRoot = section:FindFirstChild("Content") or section

			-- Remove existing slot copies (leave layouts + title).
			local toRemove: { Instance } = {}
			for _, child in contentRoot:GetChildren() do
				if child:IsA("GuiObject") and not isLayoutObject(child) and child.Name ~= "Title" then
					table.insert(toRemove, child)
				end
			end
			for _, r in toRemove do
				r:Destroy()
			end

			for _, eggInfo in worldGroups[wid] do
				local slot = slotTemplate:Clone()
				slot.Name = eggInfo.id
				slot.Visible = true

				local nameLabel = slot:FindFirstChild("Name")
				if nameLabel and nameLabel:IsA("TextLabel") then
					nameLabel.Text = eggInfo.def.name:upper()
				end
				local costLabel = slot:FindFirstChild("Cost")
				if costLabel and costLabel:IsA("TextLabel") then
					local prefix = CURRENCY_PREFIX[eggInfo.def.currency] or "$"
					costLabel.Text = prefix .. Utils.formatNumber(eggInfo.def.price)
				end

				passthroughChildren(slot)
				local clickBtn = ensureClickTarget(slot)
				local eid = eggInfo.id
				local lastFire = 0.0
				local function onEggClick()
					local now = os.clock()
					if now - lastFire < 0.08 then return end
					lastFire = now
					SoundFacade.playOneShot("click")
					UIController.showEggBuyPopup(eid)
				end
				clickBtn.Activated:Connect(onEggClick)
				clickBtn.MouseButton1Click:Connect(onEggClick)

				slot.Parent = contentRoot
				totalWired += 1
			end

			section.Parent = eggsContainer
		end
	else
		-- Flat layout: slots are direct children of Eggs. Clone per egg.
		local toRemove: { Instance } = {}
		for _, child in eggsContainer:GetChildren() do
			if child:IsA("GuiObject") and not isLayoutObject(child) and child ~= slotTemplate then
				table.insert(toRemove, child)
			end
		end
		for _, r in toRemove do
			r:Destroy()
		end

		for _, eggId in ipairs(EggConfig.listEggIds()) do
			local eggDef = EggConfig.Eggs[eggId]
			local slot = slotTemplate:Clone()
			slot.Name = eggId
			slot.Visible = true

			local nameLabel = slot:FindFirstChild("Name")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = eggDef.name:upper()
			end
			local costLabel = slot:FindFirstChild("Cost")
			if costLabel and costLabel:IsA("TextLabel") then
				local prefix = CURRENCY_PREFIX[eggDef.currency] or "$"
				costLabel.Text = prefix .. Utils.formatNumber(eggDef.price)
			end

			passthroughChildren(slot)
			local clickBtn = ensureClickTarget(slot)
			local eid = eggId
			local lastFire = 0.0
			local function onEggClick()
				local now = os.clock()
				if now - lastFire < 0.08 then return end
				lastFire = now
				SoundFacade.playOneShot("click")
				UIController.showEggBuyPopup(eid)
			end
			clickBtn.Activated:Connect(onEggClick)
			clickBtn.MouseButton1Click:Connect(onEggClick)

			slot.Parent = eggsContainer
			totalWired += 1
		end
	end

	if totalWired > 0 then
		print("[DAC] EggStore: wired", totalWired, "egg slots successfully")
	else
		warn("[DAC] EggStore: 0 egg slots wired — check EggConfig.Eggs entries")
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

	local oldTrophy = actionBar:FindFirstChild("TrophyButton")
	if oldTrophy then
		oldTrophy:Destroy()
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

local function repositionToasts()
	for i, entry in activeToasts do
		local targetY = 10 + (i - 1) * (64 + TOAST_GAP)
		TweenService:Create(
			entry.frame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -10, 0, targetY) }
		):Play()
	end
end

local function dismissToast(id: number)
	for i, entry in activeToasts do
		if entry.id == id then
			local frame = entry.frame
			TweenService:Create(
				frame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(1, TOAST_WIDTH + 10, 0, frame.Position.Y.Offset) }
			):Play()
			task.delay(0.35, function()
				if frame.Parent then
					frame:Destroy()
				end
			end)
			table.remove(activeToasts, i)
			repositionToasts()
			break
		end
	end
end

function UIController.showNotification(notification: any)
	local msg: string?
	local kind = "info"
	if type(notification) == "table" then
		if type(notification.type) == "string" then
			kind = notification.type
		end
		if notification.message ~= nil then
			msg = tostring(notification.message)
		end
	elseif type(notification) == "string" then
		msg = notification
	end
	if kind == "reward_claim" and msg == nil then
		msg = ""
	end
	if msg == nil then
		return
	end
	if kind == "reward_claim" then
		local chest = getRewardChestAnimation()
		if chest and chest.play then
			local ok = pcall(function()
				chest.play(notification)
			end)
			if ok then
				print("[DAC] reward_claim")
				return
			end
		end
	end
	print("[DAC] " .. msg)

	local sg = screenGui
	if not sg then
		return
	end

	while #activeToasts >= MAX_TOASTS do
		dismissToast(activeToasts[1].id)
	end

	toastIdCounter += 1
	local id = toastIdCounter
	local slotIndex = #activeToasts
	local startY = 10 + slotIndex * (64 + TOAST_GAP)

	local iconDef = TOAST_ICONS[kind] or TOAST_ICONS.info

	local toast = Instance.new("Frame")
	toast.Name = "Toast_" .. id
	toast.Size = UDim2.new(0, TOAST_WIDTH, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = Color3.fromRGB(24, 26, 40)
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.AnchorPoint = Vector2.new(1, 0)
	toast.Position = UDim2.new(1, TOAST_WIDTH + 10, 0, startY)
	toast.ZIndex = 500
	toast.ClipsDescendants = true
	toast.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if kind == "streak_critical" or kind == "streak_urgent" then 2 else 1
	stroke.Color = iconDef.color
	stroke.Transparency = if kind == "streak_critical" then 0.25 else 0.5
	stroke.Parent = toast

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = iconDef.color
	accent.BorderSizePixel = 0
	accent.ZIndex = 502
	accent.Parent = toast

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 14, 0, 10)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 20
	icon.Text = iconDef.text
	icon.TextColor3 = iconDef.color
	icon.ZIndex = 502
	icon.Parent = toast

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -56, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Position = UDim2.new(0, 48, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 15
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.ZIndex = 502
	lbl.Text = msg
	lbl.Parent = toast

	if kind == "streak_celebrate" then
		toast.BackgroundColor3 = Color3.fromRGB(38, 34, 52)
	end

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = lbl

	if string.find(msg, "+", 1, true) then
		local shimmer = Instance.new("Frame")
		shimmer.Size = UDim2.fromScale(1, 1)
		shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
		shimmer.BackgroundTransparency = 0.92
		shimmer.ZIndex = 501
		shimmer.Parent = toast

		local shimCorner = Instance.new("UICorner")
		shimCorner.CornerRadius = UDim.new(0, 12)
		shimCorner.Parent = shimmer

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 120)),
			ColorSequenceKeypoint.new(0.65, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(0.65, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Rotation = 25
		grad.Offset = Vector2.new(-1, 0)
		grad.Parent = shimmer

		TweenService:Create(
			grad,
			TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 1),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	end

	table.insert(activeToasts, { frame = toast, id = id })

	local toastScale = Instance.new("UIScale")
	toastScale.Scale = 1
	toastScale.Parent = toast

	TweenService:Create(
		toast,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -10, 0, startY) }
	):Play()

	if kind == "streak_urgent" or kind == "streak_critical" then
		local pulses = if kind == "streak_critical" then 2 else 1
		for p = 1, pulses do
			task.delay(0.38 + (p - 1) * 0.28, function()
				if not toastScale.Parent then
					return
				end
				TweenService:Create(
					toastScale,
					TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1.06 }
				):Play()
				task.delay(0.12, function()
					if toastScale.Parent then
						TweenService:Create(
							toastScale,
							TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Scale = 1 }
						):Play()
					end
				end)
			end)
		end
	end

	if kind == "error" then
		SoundFacade.playOneShot("purchase_fail")
	elseif kind == "streak_critical" then
		SoundFacade.playOneShot("alert")
	elseif kind == "streak_nudge" or kind == "streak_urgent" or kind == "streak_celebrate" then
		SoundFacade.playOneShot("notification")
	else
		SoundFacade.playOneShot("notification")
	end

	task.delay(TOAST_LIFETIME, function()
		dismissToast(id)
	end)
end

function UIController.showRunResults(results: any)
	RunResultsBridge.show(results)
end

local function ensurePopupOnTop()
	popup.ZIndex = 1000
	for _, child in popup:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = 1001
			for _, d in child:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 1002
				end
			end
		end
	end
end

function UIController.init()
	screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	panels = screenGui:WaitForChild("Panels") :: Frame
	popup = screenGui:WaitForChild("Popup") :: Frame
	actionBar = screenGui:WaitForChild("ActionBar") :: Frame

	ensurePopupOnTop()
	ensureBackdrop()
	UIController.closeAllInstant()

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

	local okT, errT = pcall(function()
		local dacGui = playerGui:WaitForChild("DAC", 20)
		local tp = dacGui:WaitForChild("TrophyCasePanel", 20)
		if not tp:IsA("ModuleScript") then
			return
		end
		local TrophyCasePanel = require(tp :: ModuleScript)
		TrophyCasePanel.mount(screenGui, UIController)
	end)
	if not okT then
		warn("[DAC] TrophyCasePanel mount failed:", errT)
	end

	print("[DAC] UIController initialized")
end

return UIController
