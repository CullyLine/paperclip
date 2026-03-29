--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local Z = UILayerStack.z
local RunResultsBridge = require(DAC:WaitForChild("RunResultsBridge"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local EggConfig = require(DAC:WaitForChild("Config"):WaitForChild("EggConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local RebirthConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local NewPlayerCalmWindow = require(DAC:WaitForChild("NewPlayerCalmWindow"))
local DrivingRunGate = require(DAC:WaitForChild("DrivingRunGate"))
local SceneTransitionGate = require(DAC:WaitForChild("SceneTransitionGate"))
local HudToastConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudToastConfig"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local MenuInputAccessibility = require(DAC:WaitForChild("MenuInputAccessibility"))
local RemoteFailSafe = require(DAC:WaitForChild("RemoteFailSafe"))
local ClientRemoteDebounce = require(DAC:WaitForChild("ClientRemoteDebounce"))
local RebirthClientState = require(DAC:WaitForChild("RebirthClientState"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local InventoryTabBarIconConfig = require(DAC:WaitForChild("Config"):WaitForChild("InventoryTabBarIconConfig"))
local RebirthUpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthUpgradeConfig"))

local UIController = {}

local lastEggBuyPopupFire = { 0 }

local UIHelpersCache: any = nil
local function uiHelpers(): any
	if UIHelpersCache then
		return UIHelpersCache
	end
	local ok, mod = pcall(function()
		return require(playerGui:WaitForChild("DAC"):WaitForChild("UIHelpers"))
	end)
	if ok and mod then
		UIHelpersCache = mod
	end
	return UIHelpersCache
end

-- Idempotent init: hot reload must not stack wire* / HudSafeArea / PlayerRemoving.
local uiControllerInitDone = false

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function clientSessionActive(): boolean
	return player.Parent ~= nil
end

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

local PANEL_NAMES = { "Inventory", "Store", "Settings", "Codes", "Rebirth", "EggStore", "RebirthUpgrades", "Daily", "World", "Potions", "Items" }
local INV_SUB_PANELS = { "Pets", "Eggs", "Cars", "Stats" }

-- Single source: Constants.RARITY_COLORS (POLA-629 token sheet)
local RARITY_COLORS: { [string]: Color3 } = Constants.RARITY_COLORS

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
-- Must match openPanel backdrop tween target (POLA-550 mobile resume / rotate repair).
local BACKDROP_DIM_TRANSPARENCY = 0.52
local backdrop: Frame? = nil
local pendingMenuReconcile: thread? = nil
local windowFocusedConn: RBXScriptConnection? = nil
local cosmeticLodHeartbeatConn: RBXScriptConnection? = nil

-- Destructive confirm modal (POLA-410): restore stroke / button tint / animations when closing or re-opening.
local destructiveConfirmCleanup: (() -> ())? = nil
local destructiveShakeKey: {}? = nil

-- Panel / backdrop / toast tweens: cancel on close, rapid toggle, or PlayerRemoving to avoid runaway tweens.
local tweenBuckets: { [Instance]: { Tween } } = {}

local function cancelTweensFor(inst: Instance)
	local bucket = tweenBuckets[inst]
	if not bucket then
		return
	end
	for _, tw in bucket do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(bucket)
end

local function registerTween(inst: Instance, tw: Tween)
	local bucket = tweenBuckets[inst]
	if not bucket then
		bucket = {}
		tweenBuckets[inst] = bucket
	end
	table.insert(bucket, tw)
end

local function playTween(inst: Instance, tw: Tween)
	registerTween(inst, tw)
	tw:Play()
	return tw
end

local function cancelAllTrackedTweens()
	for _, bucket in pairs(tweenBuckets) do
		for _, tw in bucket do
			pcall(function()
				tw:Cancel()
			end)
		end
	end
	tweenBuckets = {}
end

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
	f.ZIndex = Z.panelBackdrop
	f.Visible = false
	f.Active = true
	f.Parent = screenGui
	backdrop = f
	local pf = screenGui:FindFirstChild("Panels")
	if pf and pf:IsA("GuiObject") then
		pf.ZIndex = Z.panelStack
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
	cancelTweensFor(frame)
	local scale = ensureUIScale(frame)
	local orig = getOrigBackgroundTransparency(frame)
	frame.BackgroundTransparency = 1
	scale.Scale = OPEN_START_SCALE
	playTween(
		frame,
		TweenService:Create(
			scale,
			TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
	)
	playTween(
		frame,
		TweenService:Create(
			frame,
			TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = orig }
		)
	)
end

local selectedEggId: string? = nil
local hoveredPetUid: string? = nil
local petHoverPinned = false
local petHoverTargetPos: Vector2 = Vector2.new(0, 0)
local petHoverConn: RBXScriptConnection? = nil
local HOVER_LERP_SPEED = 12
local HOVER_OFFSET_X = 20
local HOVER_OFFSET_Y = -30

local petHoverClickConn: RBXScriptConnection? = nil

local function stopHoverTracking()
	if petHoverConn then
		petHoverConn:Disconnect()
		petHoverConn = nil
	end
	if petHoverClickConn then
		petHoverClickConn:Disconnect()
		petHoverClickConn = nil
	end
end

local hoverEquipConn: RBXScriptConnection? = nil

local function getOrCreateEquipButton(hover: Frame): TextButton
	local existing = hover:FindFirstChild("Equip") or hover:FindFirstChild("EquipButton")
	if existing and (existing:IsA("TextButton") or existing:IsA("ImageButton")) then
		return existing :: TextButton
	end
	local btn = Instance.new("TextButton")
	btn.Name = "EquipButton"
	btn.Size = UDim2.new(0.9, 0, 0, 32)
	btn.Position = UDim2.new(0.5, 0, 1, -40)
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = true
	btn.Parent = hover
	local ec = Instance.new("UICorner")
	ec.CornerRadius = UDim.new(0, 8)
	ec.Parent = btn
	return btn
end

local function fillHoverData(hover: Frame, petData: any)
	local pid = petDefId(petData)
	local def = pid and PetConfig.Pets[pid]
	if not def then return end

	hoveredPetUid = petData.uid
	hover.BackgroundColor3 = RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)

	local nameLabel = hover:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = def.name
	end
	local nicknameLabel = hover:FindFirstChild("Nickname")
	if nicknameLabel and nicknameLabel:IsA("TextLabel") then
		nicknameLabel.Visible = false
	end
	local rarityLabel = hover:FindFirstChild("Rarity")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = def.rarity:sub(1, 1):upper() .. def.rarity:sub(2)
	end
	local gasLabel = hover:FindFirstChild("Gas") or hover:FindFirstChild("Power")
	if gasLabel and gasLabel:IsA("TextLabel") then
		gasLabel.Text = "Gas: +" .. tostring(petData.power or def.basePower)
	end
	local speedLabel = hover:FindFirstChild("Speed")
	if speedLabel and speedLabel:IsA("TextLabel") then
		speedLabel.Visible = false
	end
	local fuseLabel = hover:FindFirstChild("Fuse")
	if fuseLabel and fuseLabel:IsA("TextLabel") then
		fuseLabel.Visible = false
	end

	local equipBtn = getOrCreateEquipButton(hover)
	local isEquipped = petData.equipped == true
	equipBtn.Text = isEquipped and "Unequip" or "Equip"
	equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(80, 180, 80)

	if hoverEquipConn then
		hoverEquipConn:Disconnect()
	end
	hoverEquipConn = equipBtn.MouseButton1Click:Connect(function()
		local uid = hoveredPetUid
		if not uid then return end
		if cachedData and cachedData.settings and cachedData.settings.petLock then
			return
		end
		SoundFacade.playOneShot("click")
		if isEquipped then
			RemoteFailSafe.fireEvent("PET", "UnequipPet", uid)
		else
			RemoteFailSafe.fireEvent("PET", "EquipPet", uid)
		end
		petHoverPinned = false
	end)
end

local function isMouseOverGui(gui: GuiObject): boolean
	local mousePos = UserInputService:GetMouseLocation()
	local guiInset = game:GetService("GuiService"):GetGuiInset()
	local adjusted = mousePos - guiInset
	local absPos = gui.AbsolutePosition
	local absSize = gui.AbsoluteSize
	return adjusted.X >= absPos.X and adjusted.X <= absPos.X + absSize.X
		and adjusted.Y >= absPos.Y and adjusted.Y <= absPos.Y + absSize.Y
end

local function startHoverTracking()
	if petHoverConn then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local hover = invPanel:FindFirstChild("PetHoverFrame") :: Frame
	if not hover then return end

	local parent = hover.Parent :: GuiObject
	if not parent then return end
	local guiInset = game:GetService("GuiService"):GetGuiInset()

	if not petHoverClickConn then
		petHoverClickConn = UserInputService.InputBegan:Connect(function(input, processed)
			if not petHoverPinned then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not hover.Visible then return end
			task.defer(function()
				if not petHoverPinned then return end
				if not isMouseOverGui(hover) then
					petHoverPinned = false
				end
			end)
		end)
	end

	petHoverConn = RunService.RenderStepped:Connect(function(dt: number)
		if not hover.Visible then return end
		if petHoverPinned then return end

		local mousePos = UserInputService:GetMouseLocation() - guiInset
		local parentAbsPos = parent.AbsolutePosition
		local targetX = mousePos.X - parentAbsPos.X + HOVER_OFFSET_X
		local targetY = mousePos.Y - parentAbsPos.Y + HOVER_OFFSET_Y

		local currentX = hover.AbsolutePosition.X - parentAbsPos.X
		local currentY = hover.AbsolutePosition.Y - parentAbsPos.Y
		local lerpFactor = math.min(1, HOVER_LERP_SPEED * dt)
		local newX = currentX + (targetX - currentX) * lerpFactor
		local newY = currentY + (targetY - currentY) * lerpFactor

		local parentSize = parent.AbsoluteSize
		local hoverSize = hover.AbsoluteSize
		newX = math.clamp(newX, 0, parentSize.X - hoverSize.X)
		newY = math.clamp(newY, 0, parentSize.Y - hoverSize.Y)

		hover.Position = UDim2.fromOffset(newX, newY)
	end)
end

local function showPetHoverOnHover(petData: any)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local hover = invPanel:FindFirstChild("PetHoverFrame") :: Frame
	if not hover then return end
	if petHoverPinned then return end

	fillHoverData(hover, petData)
	hover.Visible = true
	startHoverTracking()
end

local function hidePetHoverOnLeave()
	if petHoverPinned then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local hover = invPanel:FindFirstChild("PetHoverFrame") :: Frame
	if hover then
		hover.Visible = false
	end
end

local function pinPetHover(petData: any)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local hover = invPanel:FindFirstChild("PetHoverFrame") :: Frame
	if not hover then return end

	fillHoverData(hover, petData)
	hover.Visible = true
	petHoverPinned = true
end

-- Egg Shop / Egg Buy micro-juice (tween-based; no Heartbeat). Gated by settings like HUD.
local cachedUiSettings: { graphicsQuality: number, particles: boolean } = {
	graphicsQuality = 1,
	particles = true,
}
local eggStoreSlotByEggId: { [string]: GuiObject } = {}
local eggStoreJuiceToken = 0
local eggJuiceFeaturedSlot: GuiObject? = nil

local THEME_GREEN = Color3.fromRGB(46, 204, 113)
local THEME_DISABLED = Color3.fromRGB(140, 140, 155)
local THEME_DISABLED_TEXT = Color3.fromRGB(200, 200, 210)

local function syncUiSettingsFromData(data: any)
	if type(data) ~= "table" or type(data.settings) ~= "table" then
		return
	end
	local s = data.settings
	ClientPerformanceProfile.syncFromSettings(s)
	if type(s.graphicsQuality) == "number" then
		cachedUiSettings.graphicsQuality = s.graphicsQuality
	end
	if type(s.particles) == "boolean" then
		cachedUiSettings.particles = s.particles
	end
end

local function shouldEggUiJuice(): boolean
	if ClientPerformanceProfile.isCosmeticUiMotionThrottled() then
		return false
	end
	return ClientPerformanceProfile.uiJuiceStrength() > 0
end

local function shouldEggContinuousJuice(): boolean
	if ClientPerformanceProfile.isCosmeticUiMotionThrottled() then
		return false
	end
	return ClientPerformanceProfile.allowsContinuousScreenMotion()
end

local function currencyBalance(data: any, currency: string): number
	if type(data) ~= "table" then
		return 0
	end
	local val = data[currency]
	if type(val) == "number" then
		return math.floor(val)
	end
	return 0
end

local function resolveSpotlightEggId(currentWorld: string): string?
	local sid = EggConfig.SpotlightEggId
	if type(sid) == "string" and EggConfig.Eggs[sid] then
		local w = EggConfig.Eggs[sid].worldId or "forest"
		if w == currentWorld then
			return sid
		end
	end
	for _, eggId in EggConfig.listEggIds() do
		local def = EggConfig.Eggs[eggId]
		if def and (def.worldId or "forest") == currentWorld then
			return eggId
		end
	end
	return nil
end

local function ensureEggJuiceUIScale(gui: GuiObject): UIScale
	local us = gui:FindFirstChild("_EggJuiceUIScale")
	if us and us:IsA("UIScale") then
		return us
	end
	local s = Instance.new("UIScale")
	s.Name = "_EggJuiceUIScale"
	s.Scale = 1
	s.Parent = gui
	return s
end

local function playEggSlotPressJuice(slot: GuiObject)
	if ClientPerformanceProfile.isCosmeticUiMotionThrottled() then
		return
	end
	local sc = slot:FindFirstChild("_EggPressUIScale")
	if not sc or not sc:IsA("UIScale") then
		sc = Instance.new("UIScale")
		sc.Name = "_EggPressUIScale"
		sc.Scale = 1
		sc.Parent = slot
	end
	cancelTweensFor(sc)
	local s = sc :: UIScale
	s.Scale = 1
	local twDown = TweenService:Create(s, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.93 })
	playTween(s, twDown)
	task.delay(0.07, function()
		if not s.Parent then
			return
		end
		cancelTweensFor(s)
		local twUp = TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		playTween(s, twUp)
	end)
end

local function removeSpotlightBadge(slot: GuiObject)
	local b = slot:FindFirstChild("_SpotlightBadge")
	if b then
		b:Destroy()
	end
end

local function ensureSpotlightBadge(slot: GuiObject)
	local existing = slot:FindFirstChild("_SpotlightBadge")
	if existing then
		existing.Visible = true
		return
	end
	local badge = Instance.new("Frame")
	badge.Name = "_SpotlightBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.new(0, 52, 0, 22)
	badge.BackgroundColor3 = Color3.fromRGB(255, 214, 96)
	badge.BorderSizePixel = 0
	badge.ZIndex = slot.ZIndex + 2
	badge.Parent = slot
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = badge
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.Text = MicrocopyConfig.UiEggStoreSpotlightBadge
	t.TextColor3 = Color3.fromRGB(30, 30, 40)
	t.TextSize = 14
	t.Parent = badge
	local uh = uiHelpers()
	if uh and uh.ensureSingleLineTruncate then
		uh.ensureSingleLineTruncate(t)
	end
end

local function stopEggStoreJuice()
	eggStoreJuiceToken += 1
	if eggJuiceFeaturedSlot then
		cancelTweensFor(eggJuiceFeaturedSlot)
		local sc = eggJuiceFeaturedSlot:FindFirstChild("_EggJuiceUIScale")
		if sc and sc:IsA("UIScale") then
			cancelTweensFor(sc)
			sc.Scale = 1
		end
		local stroke = eggJuiceFeaturedSlot:FindFirstChild("_SpotlightStroke")
		if stroke then
			cancelTweensFor(stroke)
			stroke:Destroy()
		end
		removeSpotlightBadge(eggJuiceFeaturedSlot)
		eggJuiceFeaturedSlot = nil
	end
end

local function stopEggBuyJuice()
	local eggBuy = popup and popup:FindFirstChild("EggBuy")
	if eggBuy and eggBuy:IsA("GuiObject") then
		cancelTweensFor(eggBuy)
		for _, name in { "Buy1", "Buy3", "Buy10" } do
			local b = eggBuy:FindFirstChild(name)
			if b and b:IsA("GuiObject") then
				cancelTweensFor(b)
				local sc = b:FindFirstChild("_EggJuiceUIScale")
				if sc and sc:IsA("UIScale") then
					cancelTweensFor(sc)
					sc.Scale = 1
				end
				local st = b:FindFirstChildOfClass("UIStroke")
				if st then
					cancelTweensFor(st)
				end
			end
		end
	end
end

local function startEggBuyPrimaryJuice(eggBuy: Frame)
	if not shouldEggContinuousJuice() then
		return
	end
	if not selectedEggId or not cachedData then
		return
	end
	local def = EggConfig.Eggs[selectedEggId]
	if not def then
		return
	end
	local bal = currencyBalance(cachedData, def.currency)
	if bal < def.price then
		return
	end
	local buy1 = eggBuy:FindFirstChild("Buy1")
	if not buy1 or not buy1:IsA("GuiObject") then
		return
	end
	local scale = ensureEggJuiceUIScale(buy1)
	scale.Scale = 1
	local tw = TweenService:Create(
		scale,
		TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 }
	)
	playTween(scale, tw)
end

local function startEggStoreJuice()
	stopEggStoreJuice()
	local eggStorePanel = panels:FindFirstChild("EggStore")
	if not eggStorePanel or not eggStorePanel:IsA("GuiObject") then
		return
	end
	if not eggStorePanel.Visible then
		return
	end

	local currentWorld = (cachedData and cachedData.currentWorld) or "forest"
	local spotlightId = resolveSpotlightEggId(currentWorld)
	if not spotlightId then
		return
	end
	local slot = eggStoreSlotByEggId[spotlightId]
	if not slot then
		return
	end

	eggJuiceFeaturedSlot = slot
	ensureSpotlightBadge(slot)

	local token = eggStoreJuiceToken

	if shouldEggContinuousJuice() then
		local sc = ensureEggJuiceUIScale(slot)
		sc.Scale = 1
		local breathe = TweenService:Create(
			sc,
			TweenInfo.new(2.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.028 }
		)
		playTween(sc, breathe)
	end

	task.spawn(function()
		while token == eggStoreJuiceToken do
			local waitSec = 8 + math.random() * 4
			task.wait(waitSec)
			if token ~= eggStoreJuiceToken then
				break
			end
			local p = panels:FindFirstChild("EggStore")
			if not p or not p.Visible then
				break
			end
			if not shouldEggUiJuice() then
				continue
			end
			local s = eggStoreSlotByEggId[spotlightId]
			if not s or not s.Parent then
				break
			end
			local stroke = s:FindFirstChild("_SpotlightStroke")
			if not stroke or not stroke:IsA("UIStroke") then
				stroke = Instance.new("UIStroke")
				stroke.Name = "_SpotlightStroke"
				stroke.Thickness = 3
				stroke.Color = Color3.fromRGB(255, 220, 120)
				stroke.Transparency = 0.65
				stroke.Parent = s
			end
			cancelTweensFor(stroke)
			stroke.Transparency = 0.65
			local pulseOut = TweenService:Create(
				stroke,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 0.1 }
			)
			local pulseIn = TweenService:Create(
				stroke,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 0.75 }
			)
			playTween(stroke, pulseOut)
			task.delay(0.22, function()
				if token ~= eggStoreJuiceToken or not stroke.Parent then
					return
				end
				playTween(stroke, pulseIn)
			end)
		end
	end)
end

local function styleEggBuyButton(btn: GuiButton, canAfford: boolean, isPrimary: boolean)
	cancelTweensFor(btn)
	local existingStroke = btn:FindFirstChildOfClass("UIStroke")
	if existingStroke then
		cancelTweensFor(existingStroke)
	end

	if canAfford then
		btn.AutoButtonColor = true
		btn.Active = true
		if btn:IsA("TextButton") then
			btn.BackgroundColor3 = THEME_GREEN
			btn.TextColor3 = Color3.new(1, 1, 1)
		elseif btn:IsA("ImageButton") then
			btn.ImageColor3 = Color3.new(1, 1, 1)
		end
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.15
		end
	else
		btn.AutoButtonColor = false
		btn.Active = false
		if btn:IsA("TextButton") then
			btn.BackgroundColor3 = THEME_DISABLED
			btn.TextColor3 = THEME_DISABLED_TEXT
		elseif btn:IsA("ImageButton") then
			btn.ImageColor3 = THEME_DISABLED
		end
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.55
		end
	end
	if isPrimary and canAfford and shouldEggContinuousJuice() then
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "_EggJuiceAffordStroke"
			stroke.Thickness = 2.5
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Parent = btn
		end
		stroke.Transparency = 0.12
		local tw = TweenService:Create(
			stroke,
			TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.55 }
		)
		playTween(stroke, tw)
	elseif isPrimary and canAfford and shouldEggUiJuice() then
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "_EggJuiceAffordStroke"
			stroke.Thickness = 2.5
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Parent = btn
		end
		stroke.Transparency = 0.22
	end
end

local function refreshEggBuyAffordState()
	local eggBuy = popup:FindFirstChild("EggBuy") :: Frame?
	if not eggBuy or not eggBuy.Visible then
		return
	end
	if not selectedEggId or not cachedData then
		return
	end
	local def = EggConfig.Eggs[selectedEggId]
	if not def then
		return
	end
	stopEggBuyJuice()
	local bal = currencyBalance(cachedData, def.currency)
	local price = def.price
	for btnName, mult in { Buy1 = 1, Buy3 = 3, Buy10 = 10 } do
		local btn = eggBuy:FindFirstChild(btnName)
		if btn and btn:IsA("GuiButton") then
			local can = bal >= price * mult
			styleEggBuyButton(btn, can, btnName == "Buy1")
		end
	end
	startEggBuyPrimaryJuice(eggBuy)
end

local function getPlayerMaxHatchCount(): number
	if not cachedData then return Constants.BASE_HATCH_COUNT end
	local upgradePoints = 0
	if cachedData.rebirthUpgrades and type(cachedData.rebirthUpgrades.moreEggsAtOnce) == "number" then
		upgradePoints = cachedData.rebirthUpgrades.moreEggsAtOnce
	end
	return math.min(Constants.BASE_HATCH_COUNT + upgradePoints, Constants.MAX_HATCH_COUNT)
end

local function refreshEggOpenPromptAffordState()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then
		return
	end
	local prompt = invPanel:FindFirstChild("EggOpenPrompt") :: Frame?
	if not prompt or not prompt.Visible or not selectedEggId or not cachedData then
		return
	end
	local eggs = cachedData.eggs
	local owned = 0
	if type(eggs) == "table" and type(eggs[selectedEggId]) == "number" then
		owned = eggs[selectedEggId]
	end

	local maxHatch = getPlayerMaxHatchCount()
	local maxAvailable = math.min(owned, maxHatch)

	local open1 = prompt:FindFirstChild("Open1")
	if open1 and open1:IsA("GuiButton") then
		styleEggBuyButton(open1, owned >= 1, true)
	end
	local open3 = prompt:FindFirstChild("Open3")
	if open3 and open3:IsA("GuiButton") then
		styleEggBuyButton(open3, owned >= 3, false)
	end
	local open10 = prompt:FindFirstChild("Open10")
	if open10 and open10:IsA("GuiButton") then
		styleEggBuyButton(open10, owned >= 10, false)
	end
	local openMax = prompt:FindFirstChild("OpenMax")
	if openMax and openMax:IsA("GuiButton") then
		styleEggBuyButton(openMax, maxAvailable >= 1, false)
		if openMax:IsA("TextButton") then
			openMax.Text = "Open " .. tostring(maxAvailable)
		else
			local lbl = openMax:FindFirstChild("TextLabel")
			if lbl and lbl:IsA("TextLabel") then
				lbl.Text = "Open " .. tostring(maxAvailable)
			end
		end
	end
end

local activeToasts: { { frame: Frame, id: number, priority: number, seq: number } } = {}
local toastIdCounter = 0
local toastSeqCounter = 0
local MAX_TOASTS = HudToastConfig.MAX_VISIBLE_TOASTS
local TOAST_LIFETIME = 3.5
local TOAST_WIDTH = 320
local TOAST_GAP = 8
local lastCoalesceAt: { [string]: number } = {}

local hudToastLayoutDisconnect: (() -> ())? = nil

local function dacMainToastInsets(): (number, number, number, number)
	if not screenGui then
		return 0, 0, 0, 0
	end
	return HudSafeArea.getManualInsetsForScreenGui(screenGui)
end

local function toastStackTopPx(): number
	local _, t, _, _ = dacMainToastInsets()
	return t + HudLayoutConfig.hudNotificationToastStackBasePx
end

local function toastRightInnerOffset(): number
	local _, _, r, _ = dacMainToastInsets()
	return -(HudLayoutConfig.hudNotificationToastRightClearancePx + r)
end

local function toastRightOffscreenOffset(): number
	local _, _, r, _ = dacMainToastInsets()
	return TOAST_WIDTH + HudLayoutConfig.hudNotificationToastRightClearancePx + r
end
local deferredDuringRun: { any } = {}

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

local applyHubPanelNarrowFit -- forward-declared; defined after helper block

function UIController.registerPanel(id: string, frame: Frame)
	registeredPanels[id] = frame
	if screenGui and panels then
		task.defer(applyHubPanelNarrowFit)
	end
end

local function clearInventoryOverlayState()
	petHoverPinned = false
	stopHoverTracking()
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
	cancelAllTrackedTweens()
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

	stopEggStoreJuice()
	stopEggBuyJuice()

	if popup then
		setVisible(popup, "EggBuy", false)
		setVisible(popup, "Confirm", false)
	end
	if backdrop then
		backdrop.Visible = false
		backdrop.BackgroundTransparency = 1
	end
	pcall(function()
		GuiService.SelectedObject = nil
	end)
	SoundFacade.setMenuModalOpen(false)
end

--[[
	POLA-550: After rotate or app background, tweens can leave orphan backdrops, invisible
	panels with stale activePanel, or wrong UIScale. Reconcile without nuking unrelated HUD tweens.
]]
local function applyPanelsSafeInsets()
	if not screenGui or not panels then
		return
	end
	local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(screenGui)
	local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
	local pad = panels:FindFirstChild("DACPanelsSafePad")
	if not pad or not pad:IsA("UIPadding") then
		pad = Instance.new("UIPadding")
		pad.Name = "DACPanelsSafePad"
		pad.Parent = panels
	end
	pad.PaddingLeft = UDim.new(0, math.floor(l + em + 0.5))
	pad.PaddingTop = UDim.new(0, math.floor(t + em + 0.5))
	pad.PaddingRight = UDim.new(0, math.floor(r + em + 0.5))
	pad.PaddingBottom = UDim.new(0, math.floor(b + em + 0.5))
end

local function applyPopupSafeInsets()
	if not screenGui or not popup then
		return
	end
	local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(screenGui)
	local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
	local pad = popup:FindFirstChild("DACPopupSafePad")
	if not pad or not pad:IsA("UIPadding") then
		pad = Instance.new("UIPadding")
		pad.Name = "DACPopupSafePad"
		pad.Parent = popup
	end
	pad.PaddingLeft = UDim.new(0, math.floor(l + em + 0.5))
	pad.PaddingTop = UDim.new(0, math.floor(t + em + 0.5))
	pad.PaddingRight = UDim.new(0, math.floor(r + em + 0.5))
	pad.PaddingBottom = UDim.new(0, math.floor(b + em + 0.5))
end

--[[
	Scale each panel `Main` down on very narrow viewports so fixed-width Studio shells
	still fit inside safe horizontal bounds (POLA-610). UIScale lives on `Main`, not on
	the panel root, so open/close tweens on the root are unaffected.
]]
applyHubPanelNarrowFit = function()
	if not screenGui or not panels then
		return
	end
	local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(screenGui)
	local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
	local contentW = HudSafeArea.getContentWidthAfterScreenInsets(screenGui, em)
	local ref = HudLayoutConfig.hubPanelFitReferenceWidthPx
	if ref <= 0 then
		return
	end
	local scale = math.min(1, contentW / ref)

	local function applyToMainUnder(frame: Frame?)
		if not frame then
			return
		end
		local main = frame:FindFirstChild("Main") :: GuiObject?
		if not main then
			return
		end
		local us = main:FindFirstChild("DACNarrowFit") :: UIScale?
		if not us then
			us = Instance.new("UIScale")
			us.Name = "DACNarrowFit"
			us.Parent = main
		end
		us.Scale = scale
	end

	for _, name in PANEL_NAMES do
		local fr = panels:FindFirstChild(name)
		if fr and fr:IsA("Frame") then
			applyToMainUnder(fr)
		end
	end

	local inv = panels:FindFirstChild("Inventory") :: Frame?
	if inv then
		for _, sub in INV_SUB_PANELS do
			local subFr = inv:FindFirstChild(sub)
			if subFr and subFr:IsA("Frame") then
				applyToMainUnder(subFr)
			end
		end
	end

	for _, f in registeredPanels do
		applyToMainUnder(f)
	end

	if popup then
		local eggBuy = popup:FindFirstChild("EggBuy")
		if eggBuy and eggBuy:IsA("Frame") then
			applyToMainUnder(eggBuy)
		end
		local confirm = popup:FindFirstChild("Confirm")
		if confirm and confirm:IsA("Frame") then
			applyToMainUnder(confirm)
		end
	end
end

local function applyMenuHubResponsiveLayout()
	applyPanelsSafeInsets()
	applyPopupSafeInsets()
	applyHubPanelNarrowFit()
end

local function reconcileMenuStackAfterInterrupt()
	if not clientSessionActive() or not panels then
		return
	end
	local visibleList = collectVisibleMainPanels()
	local hasUi = #visibleList > 0
	local bdOn = backdrop ~= nil and backdrop.Visible

	if bdOn and not hasUi then
		cancelAllTrackedTweens()
		UIController.closeAllInstant()
		pcall(function()
			GuiService.SelectedObject = nil
		end)
		return
	end
	if activePanel ~= nil and not hasUi then
		cancelAllTrackedTweens()
		UIController.closeAllInstant()
		pcall(function()
			GuiService.SelectedObject = nil
		end)
		return
	end
	if hasUi then
		for _, fr in visibleList do
			cancelTweensFor(fr)
		end
		if bdOn and backdrop then
			cancelTweensFor(backdrop)
		end
		for _, fr in visibleList do
			resetPanelTransform(fr)
		end
		if bdOn and backdrop then
			backdrop.BackgroundTransparency = BACKDROP_DIM_TRANSPARENCY
		end
		SoundFacade.setMenuModalOpen(true)
		if activePanel == nil then
			for _, name in PANEL_NAMES do
				local p = panels:FindFirstChild(name)
				if p and p:IsA("GuiObject") and p.Visible then
					activePanel = name
					break
				end
			end
			if activePanel == nil then
				for id, f in registeredPanels do
					if f.Visible then
						activePanel = id
						break
					end
				end
			end
		end
	end
end

local function scheduleMenuStackReconcile()
	if pendingMenuReconcile then
		task.cancel(pendingMenuReconcile)
		pendingMenuReconcile = nil
	end
	pendingMenuReconcile = task.delay(0.06, function()
		pendingMenuReconcile = nil
		if not clientSessionActive() then
			return
		end
		reconcileMenuStackAfterInterrupt()
	end)
end

function UIController.closeAll(onComplete: (() -> ())?)
	local toClose = collectVisibleMainPanels()

	local function finishState()
		activePanel = nil
		activeInvSub = nil
		activeStoreTab = nil
		clearInventoryOverlayState()
		stopEggStoreJuice()
		stopEggBuyJuice()
		if popup then
			setVisible(popup, "EggBuy", false)
			setVisible(popup, "Confirm", false)
		end
		pcall(function()
			GuiService.SelectedObject = nil
		end)
		if onComplete then
			onComplete()
		else
			SoundFacade.setMenuModalOpen(false)
		end
	end

	if #toClose == 0 then
		if backdrop then
			cancelTweensFor(backdrop)
			backdrop.Visible = false
			backdrop.BackgroundTransparency = 1
		end
		finishState()
		return
	end

	SoundFacade.playOneShot("panel_close")
	for _, f in toClose do
		cancelTweensFor(f)
		local scale = ensureUIScale(f)
		playTween(
			f,
			TweenService:Create(
				scale,
				TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.87 }
			)
		)
		playTween(
			f,
			TweenService:Create(
				f,
				TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
		)
	end
	if backdrop and backdrop.Visible then
		cancelTweensFor(backdrop)
		playTween(
			backdrop,
			TweenService:Create(
				backdrop,
				TweenInfo.new(CLOSE_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
		)
	end
	task.delay(CLOSE_PANEL_DURATION, function()
		if not clientSessionActive() then
			return
		end
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
		SoundFacade.setMenuModalOpen(true)
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
			cancelTweensFor(backdrop)
			backdrop.Visible = true
			backdrop.BackgroundTransparency = 1
			playTween(
				backdrop,
				TweenService:Create(
					backdrop,
					TweenInfo.new(OPEN_PANEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = BACKDROP_DIM_TRANSPARENCY }
				)
			)
		end

		if name == "Inventory" then
			UIController.showInvSub("Pets")
		elseif name == "Store" then
			UIController.showStoreTab("Exclusives")
		elseif name == "EggStore" then
			UIController.refreshEggStoreOrder()
			task.defer(function()
				if not clientSessionActive() then
					return
				end
				startEggStoreJuice()
			end)
		elseif name == "Rebirth" then
			UIController.populateRebirth()
		end
	end)
end

local lastToggleTime = 0
function UIController.togglePanel(name: string)
	local now = os.clock()
	if now - lastToggleTime < 0.25 then
		return
	end
	lastToggleTime = now
	if activePanel == name then
		UIController.closeAll()
	else
		UIController.openPanel(name)
	end
end

function UIController.showPanel(name: string)
	if activePanel ~= name then
		UIController.openPanel(name)
	end
end

function UIController.hidePanel(name: string)
	if activePanel == name then
		UIController.closeAll()
	end
end

function UIController.isMenuOpen(): boolean
	return activePanel ~= nil
end

--[[
	True while a full-screen or blocking panel/popup is up — driving / gameplay binds should not apply.
]]
function UIController.isBlockingGameplayInput(): boolean
	if SceneTransitionGate.isActive() then
		return true
	end
	if activePanel ~= nil then
		return true
	end
	-- POLA-554: Hub panels (quests, worlds, …) live in registeredPanels; must block driving + accept Back.
	for _, f in registeredPanels do
		if f.Visible then
			return true
		end
	end
	if popup then
		local eggBuy = popup:FindFirstChild("EggBuy")
		if eggBuy and eggBuy:IsA("GuiObject") and eggBuy.Visible then
			return true
		end
		local confirm = popup:FindFirstChild("Confirm")
		if confirm and confirm:IsA("GuiObject") and confirm.Visible then
			return true
		end
	end
	return false
end

function UIController.showInvSub(sub: string)
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	for _, s in INV_SUB_PANELS do
		setVisible(invPanel, s, s == sub)
	end
	setVisible(invPanel, "EggOpenPrompt", false)
	setVisible(invPanel, "PetHoverFrame", false)
	petHoverPinned = false
	stopHoverTracking()
	activeInvSub = sub

	if sub == "Pets" then UIController.populatePets() end
	if sub == "Eggs" then UIController.populateEggs() end
	if sub == "Stats" then UIController.populateStats() end
	if sub == "Cars" then UIController.populateCars() end
end

function UIController.showStoreTab(tab: string)
	local storePanel = panels:FindFirstChild("Store")
	if not storePanel then return end
	local content = storePanel:FindFirstChild("Content")
	local scroll = storePanel:FindFirstChild("Scroll")

	local tabMap: { [string]: string } = {
		Cars = "Cosmetics",
		Exclusives = "Exclusives",
		Gems = "Gems",
	}

	if content then
		for _, ch in content:GetChildren() do
			if ch:IsA("Frame") or ch:IsA("ScrollingFrame") then
				ch.Visible = false
			end
		end
	end

	if scroll then
		scroll.Visible = (tab == "Other")
	end

	if tab ~= "Other" then
		local frameName = tabMap[tab]
		if frameName and content then
			setVisible(content, frameName, true)
		end
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
		local cf, size = model:GetBoundingBox()
		local maxDim = math.max(size.X, size.Y, size.Z)
		local dist = maxDim * 0.7 + 0.3
		local center = cf.Position + Vector3.new(0, size.Y * 0.12, 0)
		local camPos = center + cf.LookVector * dist + Vector3.new(0, dist * 0.1, 0)
		cam.CFrame = CFrame.new(camPos, center)
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

				local function wireHoverAndClick(btn: GuiObject, ref: any)
					btn.MouseEnter:Connect(function()
						showPetHoverOnHover(ref)
					end)
					btn.MouseLeave:Connect(function()
						hidePetHoverOnLeave()
					end)
					if btn:IsA("GuiButton") then
						btn.MouseButton1Click:Connect(function()
							pinPetHover(ref)
						end)
					end
				end

				if item:IsA("GuiButton") then
					wireHoverAndClick(item, petData)
				else
					local overlay = item:FindFirstChild("_PetClickTarget")
					if not overlay then
						overlay = Instance.new("TextButton")
						overlay.Name = "_PetClickTarget"
						overlay.Size = UDim2.fromScale(1, 1)
						overlay.BackgroundTransparency = 1
						overlay.Text = ""
						overlay.ZIndex = Z.panelInsetClick
						overlay.Parent = item
					end
					wireHoverAndClick(overlay, petData)
				end

				item.Parent = invScroll
			end
		end

		local petCount = 0
		for _ in pets do
			petCount += 1
		end
		local equippedCount = 0
		for _, p in pets do
			if p.equipped then
				equippedCount += 1
			end
		end
		local maxSlots = cachedData.maxPetSlots or 8

		local header = main:FindFirstChild("Header")
		if header then
			local total = header:FindFirstChild("Total")
			if total and total:IsA("TextLabel") then
				total.Text = tostring(petCount) .. " Pets"
			end
			local slotCounter = header:FindFirstChild("SlotCounter")
			if slotCounter and slotCounter:IsA("TextLabel") then
				slotCounter.Text = tostring(equippedCount) .. "/" .. tostring(maxSlots) .. " Equipped"
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
	if not pid then return end

	fillHoverData(hover, petData)
	hover.Visible = true
	petHoverPinned = true
	startHoverTracking()
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

	local prompt = invPanel:FindFirstChild("EggOpenPrompt") :: Frame?
	if prompt and prompt.Visible and selectedEggId then
		refreshEggOpenPromptAffordState()
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

	refreshEggOpenPromptAffordState()
end

function UIController.populateStats()
	if not cachedData then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local statsPanel = invPanel:FindFirstChild("Stats")
	if not statsPanel then return end

	local stats = cachedData.stats or {}

	local equippedPets = {}
	if type(cachedData.pets) == "table" then
		for _, pet in cachedData.pets do
			if pet.equipped then
				table.insert(equippedPets, pet)
			end
		end
	end
	local petMod = Utils.calculatePetModifier(equippedPets)
	local petModStr = string.format("%.0f%%", (petMod - 1) * 100)

	local totalPlaytime = stats.totalPlaytimeSeconds or 0
	local hours = math.floor(totalPlaytime / 3600)
	local minutes = math.floor((totalPlaytime % 3600) / 60)
	local playtimeStr = hours > 0 and (tostring(hours) .. "h " .. tostring(minutes) .. "m") or (tostring(minutes) .. "m")

	local fields: { [string]: string } = {
		PetMultiplier = petModStr,
		TotalRebirths = tostring(cachedData.rebirths or 0),
		TotalCoinsEarned = Utils.formatNumber(stats.totalCoinsEarned or 0),
		TotalTimePlayed = playtimeStr,
		TotalRobuxSpent = Utils.formatNumber(cachedData.totalRobuxSpent or 0),
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

	local powerLabel = rebirthPanel:FindFirstChild("Power")
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = "+" .. tostring(RebirthConfig.Rewards.trainingBonusPerRebirth) .. "% Power/tick"
	end

	local gemsLabel = rebirthPanel:FindFirstChild("Gems") or rebirthPanel:FindFirstChild("GemsReward")
	if gemsLabel and gemsLabel:IsA("TextLabel") then
		gemsLabel.Text = "+" .. tostring(RebirthConfig.Rewards.gemsGranted) .. " Gems"
	end

	local trainedPowerLabel = rebirthPanel:FindFirstChild("TrainedPower")
	if trainedPowerLabel and trainedPowerLabel:IsA("TextLabel") then
		trainedPowerLabel.Text = "Trained Power: " .. Utils.formatNumber(cachedData.trainedPower or 0) .. " (will reset)"
	end

	local currentGemsLabel = rebirthPanel:FindFirstChild("CurrentGems")
	if currentGemsLabel and currentGemsLabel:IsA("TextLabel") then
		currentGemsLabel.Text = "Gems: " .. Utils.formatNumber(cachedData.gems or 0)
	end

	local speedLabel = rebirthPanel:FindFirstChild("Speed")
	if speedLabel and speedLabel:IsA("TextLabel") then
		speedLabel.Visible = false
	end
	local gasLabel = rebirthPanel:FindFirstChild("Gas")
	if gasLabel and gasLabel:IsA("TextLabel") then
		gasLabel.Visible = false
	end
end

function UIController.populateCars()
	if not cachedData then return end
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local carsPanel = invPanel:FindFirstChild("Cars")
	if not carsPanel then return end
	local main = carsPanel:FindFirstChild("Main") :: ScrollingFrame
	if not main then return end

	local carScroll = main:FindFirstChild("Inventory") or main:FindFirstChild("Cars") :: ScrollingFrame
	if not carScroll then
		carScroll = main
	end

	local template = findTemplate(carScroll, "CarTemplate")
	clearChildren(carScroll, "CarTemplate")

	local ownedCars = cachedData.cars or {}
	local equippedCar = cachedData.equippedCar

	for carId, ownedCar in ownedCars do
		local carDef = CarConfig.Cars[carId]
		if not carDef then continue end
		if not template then continue end

		local item = template:Clone()
		item.Name = carId
		item.Visible = true

		local nameLabel = item:FindFirstChild("Name") or item:FindFirstChild("TextLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = carDef.name
		end

		local gasLabel = item:FindFirstChild("Gas")
		if gasLabel and gasLabel:IsA("TextLabel") then
			gasLabel.Text = tostring(carDef.baseStats.gas) .. " GAL"
		end
		local powerLabel = item:FindFirstChild("Power")
		if powerLabel and powerLabel:IsA("TextLabel") then
			local effectivePower = carDef.baseStats.power + (cachedData.trainedPower or 0)
			powerLabel.Text = tostring(carDef.baseStats.power) .. " +" .. tostring(cachedData.trainedPower or 0)
		end
		local accelLabel = item:FindFirstChild("Acceleration")
		if accelLabel and accelLabel:IsA("TextLabel") then
			accelLabel.Text = tostring(carDef.baseStats.acceleration) .. "s"
		end

		local isEquipped = equippedCar == carId
		local equipBtn = item:FindFirstChild("EquipButton") or item:FindFirstChild("Equip")
		if equipBtn and equipBtn:IsA("TextButton") then
			equipBtn.Text = isEquipped and "Equipped" or "Equip"
			equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(80, 80, 100) or Color3.fromRGB(80, 180, 80)
			if not isEquipped then
				local eid = carId
				equipBtn.MouseButton1Click:Connect(function()
					SoundFacade.playOneShot("click")
					RemoteFailSafe.fireEvent("CAR", "EquipCar", eid)
				end)
			end
		end

		item.Parent = carScroll
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

	refreshEggBuyAffordState()
end

export type ConfirmPopupOptions = {
	destructive: boolean?,
}

local function clearDestructiveConfirmChrome()
	if destructiveConfirmCleanup then
		destructiveConfirmCleanup()
		destructiveConfirmCleanup = nil
	end
	destructiveShakeKey = nil
end

local function reducedMotionNow(): boolean
	local s = cachedData and cachedData.settings
	if type(s) ~= "table" then
		return false
	end
	return s.reducedMotion == true
end

local function getButtonSurfaceColor(btn: GuiButton): Color3
	if btn:IsA("ImageButton") then
		return (btn :: ImageButton).ImageColor3
	end
	return (btn :: TextButton).BackgroundColor3
end

local function setButtonSurfaceColor(btn: GuiButton, c: Color3)
	if btn:IsA("ImageButton") then
		(btn :: ImageButton).ImageColor3 = c
	else
		(btn :: TextButton).BackgroundColor3 = c
	end
end

local function captureButtonSurface(btn: GuiButton)
	if btn:GetAttribute("DACOrigSurfR") ~= nil then
		return
	end
	local c = getButtonSurfaceColor(btn)
	btn:SetAttribute("DACOrigSurfR", c.R)
	btn:SetAttribute("DACOrigSurfG", c.G)
	btn:SetAttribute("DACOrigSurfB", c.B)
end

local function restoreButtonSurface(btn: GuiButton)
	local r = btn:GetAttribute("DACOrigSurfR")
	if r == nil then
		return
	end
	local g = btn:GetAttribute("DACOrigSurfG") :: number
	local b = btn:GetAttribute("DACOrigSurfB") :: number
	setButtonSurfaceColor(btn, Color3.new(r :: number, g, b))
end

function UIController.showConfirmPopup(title: string, context: string, onYes: () -> (), options: ConfirmPopupOptions?)
	clearDestructiveConfirmChrome()

	local confirm = popup:FindFirstChild("Confirm") :: Frame
	if not confirm then return end

	local destructive = options ~= nil and options.destructive == true
	local DESTRUCTIVE_CONFIRM = Color3.fromRGB(220, 48, 52)
	local SAFE_CANCEL = Color3.fromRGB(190, 198, 220)

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
	local noBtn = confirm:FindFirstChild("No")

	local stroke: UIStroke? = nil
	local warnPulseTween: Tween? = nil

	if destructive then
		SoundFacade.playOneShot("ui_destructive_warn")

		stroke = confirm:FindFirstChild("DACDestructiveStroke") :: UIStroke?
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "DACDestructiveStroke"
			stroke.Parent = confirm
		end
		stroke.Enabled = true
		stroke.Color = Color3.fromRGB(255, 55, 70)
		stroke.Thickness = 4
		stroke.Transparency = 0.05
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		if yesBtn and yesBtn:IsA("GuiButton") then
			captureButtonSurface(yesBtn :: GuiButton)
			setButtonSurfaceColor(yesBtn :: GuiButton, DESTRUCTIVE_CONFIRM)
		end
		if noBtn and noBtn:IsA("GuiButton") then
			captureButtonSurface(noBtn :: GuiButton)
			setButtonSurfaceColor(noBtn :: GuiButton, SAFE_CANCEL)
		end

		if not reducedMotionNow() then
			local basePos = confirm.Position
			destructiveShakeKey = {}
			local key = destructiveShakeKey
			local amp = 8
			task.spawn(function()
				for i = 1, 6 do
					if destructiveShakeKey ~= key then
						return
					end
					local sign = if i % 2 == 0 then 1 else -1
					confirm.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + sign * amp, basePos.Y.Scale, basePos.Y.Offset)
					amp *= 0.68
					task.wait(0.036)
				end
				if destructiveShakeKey == key then
					confirm.Position = basePos
				end
			end)

			local warnIcon = confirm:FindFirstChild("WarningIcon")
			if warnIcon and warnIcon:IsA("GuiObject") then
				local sc = warnIcon:FindFirstChildOfClass("UIScale")
				if not sc then
					sc = Instance.new("UIScale")
					sc.Parent = warnIcon
				end
				sc.Scale = 1
				warnPulseTween = TweenService:Create(
					sc,
					TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.12 }
				)
				warnPulseTween:Play()
			end
		end

		destructiveConfirmCleanup = function()
			if warnPulseTween then
				pcall(function()
					warnPulseTween:Cancel()
				end)
				warnPulseTween = nil
			end
			local w = confirm:FindFirstChild("WarningIcon")
			if w then
				local sc = w:FindFirstChildOfClass("UIScale")
				if sc then
					sc.Scale = 1
				end
			end
			if stroke and stroke.Parent then
				stroke.Enabled = false
			end
			if yesBtn and yesBtn:IsA("GuiButton") then
				restoreButtonSurface(yesBtn :: GuiButton)
			end
			if noBtn and noBtn:IsA("GuiButton") then
				restoreButtonSurface(noBtn :: GuiButton)
			end
		end
	end

	local function closePopup()
		confirm.Visible = false
		clearDestructiveConfirmChrome()
	end

	if yesBtn and yesBtn:IsA("GuiButton") then
		local conn
		conn = yesBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			if destructive then
				SoundFacade.playOneShot("ui_destructive_confirm")
			end
			closePopup()
			onYes()
		end)
	end

	if noBtn and noBtn:IsA("GuiButton") then
		local conn
		conn = noBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			closePopup()
		end)
	end
end

-- POLA-554: Escape + gamepad ButtonB dismiss modal/menu stack (ContextAction priority > default GUI).
local DAC_UI_BACK_ACTION = "DAC_UiBackCancel"
local DAC_UI_BACK_PRIORITY = 4000

local function tryDismissUiBackStack(): boolean
	if not popup or not panels then
		return false
	end
	local confirm = popup:FindFirstChild("Confirm")
	if confirm and confirm:IsA("GuiObject") and confirm.Visible then
		confirm.Visible = false
		clearDestructiveConfirmChrome()
		SoundFacade.playOneShot("panel_close")
		return true
	end
	local eggBuy = popup:FindFirstChild("EggBuy")
	if eggBuy and eggBuy:IsA("GuiObject") and eggBuy.Visible then
		eggBuy.Visible = false
		stopEggBuyJuice()
		SoundFacade.playOneShot("panel_close")
		return true
	end
	local invPanel = panels:FindFirstChild("Inventory")
	if invPanel then
		local eggPrompt = invPanel:FindFirstChild("EggOpenPrompt")
		if eggPrompt and eggPrompt:IsA("GuiObject") and eggPrompt.Visible then
			eggPrompt.Visible = false
			SoundFacade.playOneShot("panel_close")
			return true
		end
		local petHover = invPanel:FindFirstChild("PetHoverFrame")
		if petHover and petHover:IsA("GuiObject") and petHover.Visible and petHoverPinned then
			petHoverPinned = false
			petHover.Visible = false
			refreshEggOpenPromptAffordState()
			return true
		end
	end
	if #collectVisibleMainPanels() > 0 then
		UIController.closeAll()
		return true
	end
	return false
end

local function onUiBackCancelAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject?)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if SceneTransitionGate.isActive() then
		return Enum.ContextActionResult.Pass
	end
	if inputObject and inputObject.KeyCode == Enum.KeyCode.Escape then
		local tb = GuiService:GetFocusedTextBox()
		if tb and screenGui and tb:IsDescendantOf(screenGui) then
			tb:ReleaseFocus()
			return Enum.ContextActionResult.Sink
		end
	end
	if not UIController.isBlockingGameplayInput() then
		return Enum.ContextActionResult.Pass
	end
	if tryDismissUiBackStack() then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function UIController.onDataUpdate(data: any)
	cachedData = data
	if type(data) == "table" and type(data.rebirths) == "number" then
		RebirthClientState.clearIfRebirthAdvanced(data.rebirths)
	end
	syncUiSettingsFromData(data)

	if activePanel == "Inventory" then
		if activeInvSub == "Pets" then UIController.populatePets() end
		if activeInvSub == "Eggs" then UIController.populateEggs() end
		if activeInvSub == "Stats" then UIController.populateStats() end
		if activeInvSub == "Cars" then UIController.populateCars() end
	end
	if activePanel == "Rebirth" then UIController.populateRebirth() end

	local eggBuy = popup and popup:FindFirstChild("EggBuy")
	if eggBuy and eggBuy:IsA("GuiObject") and eggBuy.Visible then
		refreshEggBuyAffordState()
	end
	if panels then
		local invPanel = panels:FindFirstChild("Inventory")
		local prompt = invPanel and invPanel:FindFirstChild("EggOpenPrompt")
		if prompt and prompt:IsA("GuiObject") and prompt.Visible then
			refreshEggOpenPromptAffordState()
		end
	end
end

function UIController.getData(): any?
	return cachedData
end

local function wireCloseButtons()
	local function hookClose(close: Instance)
		if close:IsA("GuiButton") then
			MenuInputAccessibility.applyPrimaryNavDefaults(close :: GuiObject)
		end
	end

	for _, name in PANEL_NAMES do
		local panel = panels:FindFirstChild(name)
		if panel then
			local close = panel:FindFirstChild("Close")
			if close and close:IsA("ImageButton") then
				hookClose(close)
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
					hookClose(close)
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
				hookClose(close)
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
	{ name = "CodesTab", icon = InventoryTabBarIconConfig.codes, panelName = "Codes", order = 40 },
	{ name = "Stats", icon = InventoryTabBarIconConfig.quests, invSub = "Stats", order = 15 },
	{ name = "TrophyTab", icon = "", panelName = "trophyCase", order = 25 },
	{ name = "PotionsTab", icon = "rbxassetid://0", panelName = "Potions", order = 30 },
	{ name = "ItemsTab", icon = "rbxassetid://0", panelName = "Items", order = 35 },
}

local function wireInventoryTabBar()
	local invPanel = panels:FindFirstChild("Inventory")
	if not invPanel then return end
	local tabBar = invPanel:FindFirstChild("TabBar") :: Frame
	if not tabBar then return end

	local subMap: { [string]: string } = {
		Pets = "Pets",
		Eggs = "Eggs",
		Cars = "Cars",
	}

	local panelMap: { [string]: string } = {
		Shop = "Store",
		Settings = "Settings",
		Rebirth = "Rebirth",
	}

	for _, btn in tabBar:GetChildren() do
		if btn:IsA("ImageButton") then
			MenuInputAccessibility.applyPrimaryNavDefaults(btn)
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
		MenuInputAccessibility.applyPrimaryNavDefaults(btn)

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
			MenuInputAccessibility.applyPrimaryNavDefaults(btn)
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

	local function fireHatchAndClose(count: number)
		if not selectedEggId then return end
		if RemoteFailSafe.fireEvent("HATCH", "HatchEgg", selectedEggId, count) then
			prompt.Visible = false
			UIController.closeAllInstant()
		end
	end

	local open1 = prompt:FindFirstChild("Open1")
	if open1 and open1:IsA("GuiButton") then
		open1.MouseButton1Click:Connect(function() fireHatchAndClose(1) end)
	end

	local open3 = prompt:FindFirstChild("Open3")
	if open3 and open3:IsA("GuiButton") then
		open3.MouseButton1Click:Connect(function() fireHatchAndClose(3) end)
	end

	local open10 = prompt:FindFirstChild("Open10")
	if open10 and open10:IsA("GuiButton") then
		open10.MouseButton1Click:Connect(function() fireHatchAndClose(10) end)
	end

	local openMax = prompt:FindFirstChild("OpenMax")
	if openMax and openMax:IsA("GuiButton") then
		openMax.MouseButton1Click:Connect(function()
			local maxHatch = getPlayerMaxHatchCount()
			local owned = 0
			if cachedData and cachedData.eggs and type(cachedData.eggs[selectedEggId]) == "number" then
				owned = cachedData.eggs[selectedEggId]
			end
			local count = math.min(owned, maxHatch)
			if count >= 1 then
				fireHatchAndClose(count)
			end
		end)
	end
end

local function wireEggBuyPopup()
	local eggBuy = popup:FindFirstChild("EggBuy") :: Frame
	if not eggBuy then return end

	local function wireDismiss(btn: Instance?)
		if btn and btn:IsA("GuiButton") then
			MenuInputAccessibility.applyPrimaryNavDefaults(btn :: GuiObject)
			local function dismiss()
				eggBuy.Visible = false
			end
			btn.MouseButton1Click:Connect(dismiss)
			btn.Activated:Connect(dismiss)
		end
	end

	local amounts = { Buy1 = 1, Buy3 = 3, Buy10 = 10 }
	for btnName, count in amounts do
		local btn = eggBuy:FindFirstChild(btnName)
		if btn and btn:IsA("GuiButton") then
			MenuInputAccessibility.applyPrimaryNavDefaults(btn)
			local function buyEggs()
				if not ClientRemoteDebounce.allow(lastEggBuyPopupFire, ClientRemoteDebounce.IAP_PROMPT_COOLDOWN_SEC) then
					return
				end
				if selectedEggId then
					if RemoteFailSafe.fireEvent("BUYEGG", "BuyEgg", selectedEggId, count) then
						eggBuy.Visible = false
					end
				end
			end
			btn.MouseButton1Click:Connect(buyEggs)
			btn.Activated:Connect(buyEggs)
		end
	end

	wireDismiss(eggBuy:FindFirstChild("No"))
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
			SoundFacade.playOneShot("click")
			RemoteFailSafe.fireEvent("PET", "EquipPet", "__BEST__")
		end)
	end

	local none = actions:FindFirstChild("None")
	if none and none:IsA("ImageButton") then
		none.MouseButton1Click:Connect(function()
			if not cachedData then return end
			SoundFacade.playOneShot("click")
			RemoteFailSafe.fireEvent("PET", "UnequipAllPets")
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
			local slotIndex = i
			slot.MouseEnter:Connect(function()
				if not cachedData then return end
				local equippedPets = buildEquippedPetSlots(cachedData)
				local petUid = equippedPets[slotIndex]
				if petUid then
					local petData = UIController.findPetByUid(petUid)
					if petData then
						showPetHoverOnHover(petData)
					end
				end
			end)
			slot.MouseLeave:Connect(function()
				hidePetHoverOnLeave()
			end)
			slot.MouseButton1Click:Connect(function()
				if not cachedData then return end
				local equippedPets = buildEquippedPetSlots(cachedData)
				local petUid = equippedPets[slotIndex]
				if petUid then
					local petData = UIController.findPetByUid(petUid)
					if petData then
						pinPetHover(petData)
					end
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
				if RemoteFailSafe.fireEvent("CODE", "RedeemCode", code) then
					textBox.Text = ""
				end
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

local SETTINGS_BOOL_DEFAULT: { [string]: boolean } = {
	autoCenter = true,
	otherPets = true,
	tradeRequests = true,
	sound = true,
	particles = true,
}

local function wireSettingsPanel()
	local settingsPanel = panels:FindFirstChild("Settings")
	if not settingsPanel then return end

	for uiName, settingsKey in SETTINGS_UI_TO_KEY do
		local btn = settingsPanel:FindFirstChild(uiName)
		if btn and btn:IsA("ImageButton") then
			btn.MouseButton1Click:Connect(function()
				local settings = cachedData and cachedData.settings or {}
				local cur = settings[settingsKey]
				local base = if type(cur) == "boolean" then cur else (SETTINGS_BOOL_DEFAULT[settingsKey] or true)
				local newVal = not base
				if settingsKey == "sound" then
					SoundFacade.applyGameSoundMasterToggle(newVal)
				end
				RemoteFailSafe.fireEvent("SETTINGS", "UpdateSettings", { [settingsKey] = newVal })
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
	if not rebirthPanel then
		return
	end
	-- RebirthPanel.luau wires RebirthBtn + idempotency; avoid double-firing the same button.
	if not rebirthPanel:FindFirstChild("Confirm") then
		return
	end

	local rebirthBtn = rebirthPanel:FindFirstChild("Confirm")
	if rebirthBtn and (rebirthBtn:IsA("ImageButton") or rebirthBtn:IsA("TextButton")) then
		rebirthBtn.Activated:Connect(function()
			local rebirths = cachedData and cachedData.rebirths or 0
			local cost = Utils.calculateRebirthCost(rebirths, RebirthConfig.BaseCost, RebirthConfig.CostMultiplier)
			UIController.showConfirmPopup(
				"Rebirth",
				"Are you sure? This costs " .. Utils.formatNumber(cost) .. " coins. Some progress will be reset.",
				function()
					local exp = math.floor((cachedData and cachedData.rebirths) or 0)
					if not RebirthClientState.begin(exp) then
						return
					end
					if not RemoteFailSafe.fireEvent("REBIRTH", "Rebirth", exp) then
						RebirthClientState.forceRelease()
					end
				end,
				{ destructive = true }
			)
		end)
	end
end

local WORLD_DISPLAY: { [string]: string } = {
	forest = "Forest",
	desert = "Desert",
	ice = "Ice World",
	volcano = "Volcano",
	space = "Space",
}

local CURRENCY_PREFIX: { [string]: string } = {
	coins = "$",
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
	Constants.bootLog(indent .. inst.ClassName .. ' "' .. inst.Name .. '"' .. extra)
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
	overlay.ZIndex = Z.eggSlotClickOverlay
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
	local uh = uiHelpers()
	local function trunc(lbl: TextLabel?)
		if lbl and uh and uh.ensureSingleLineTruncate then
			uh.ensureSingleLineTruncate(lbl)
		end
	end

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
	Constants.bootLog("[DAC] EggStore wiring — Eggs hierarchy:")
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

	Constants.bootLog("[DAC] EggStore: slot template found — " .. slotTemplate.ClassName .. ' "' .. slotTemplate.Name .. '" (isButton=' .. tostring(slotTemplate:IsA("GuiButton")) .. ")")

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

	table.clear(eggStoreSlotByEggId)

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
					trunc(title)
				else
					local titleLabel = title:FindFirstChild("TextLabel")
					if titleLabel and titleLabel:IsA("TextLabel") then
						titleLabel.Text = (WORLD_DISPLAY[wid] or wid) .. " Eggs!"
						trunc(titleLabel)
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
					trunc(nameLabel)
				end
				local costLabel = slot:FindFirstChild("Cost")
				if costLabel and costLabel:IsA("TextLabel") then
					local prefix = CURRENCY_PREFIX[eggInfo.def.currency] or "$"
					costLabel.Text = prefix .. Utils.formatNumber(eggInfo.def.price)
					trunc(costLabel)
				end

				passthroughChildren(slot)
				local clickBtn = ensureClickTarget(slot)
				MenuInputAccessibility.applyPrimaryNavDefaults(clickBtn)
				local eid = eggInfo.id
				local lastFire = 0.0
				local function onEggClick()
					local now = os.clock()
					if now - lastFire < 0.08 then return end
					lastFire = now
					playEggSlotPressJuice(slot)
					SoundFacade.playOneShot("click")
					UIController.showEggBuyPopup(eid)
				end
				clickBtn.Activated:Connect(onEggClick)
				clickBtn.MouseButton1Click:Connect(onEggClick)

				slot.Parent = contentRoot
				eggStoreSlotByEggId[eid] = slot
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
				trunc(nameLabel)
			end
			local costLabel = slot:FindFirstChild("Cost")
			if costLabel and costLabel:IsA("TextLabel") then
				local prefix = CURRENCY_PREFIX[eggDef.currency] or "$"
				costLabel.Text = prefix .. Utils.formatNumber(eggDef.price)
				trunc(costLabel)
			end

			passthroughChildren(slot)
			local clickBtn = ensureClickTarget(slot)
			MenuInputAccessibility.applyPrimaryNavDefaults(clickBtn)
			local eid = eggId
			local lastFire = 0.0
			local function onEggClick()
				local now = os.clock()
				if now - lastFire < 0.08 then return end
				lastFire = now
				playEggSlotPressJuice(slot)
				SoundFacade.playOneShot("click")
				UIController.showEggBuyPopup(eid)
			end
			clickBtn.Activated:Connect(onEggClick)
			clickBtn.MouseButton1Click:Connect(onEggClick)

			slot.Parent = eggsContainer
			eggStoreSlotByEggId[eid] = slot
			totalWired += 1
		end
	end

	if totalWired > 0 then
		Constants.bootLog("[DAC] EggStore: wired", totalWired, "egg slots successfully")
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
		origInv.ZIndex = Z.panelStack
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
		MenuInputAccessibility.applyPrimaryNavDefaults(origInv)
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

	local UIHelpers = require(playerGui:WaitForChild("DAC"):WaitForChild("UIHelpers"))
	UIHelpers.wireHubIconButtonsUnder(actionBar)
end

function UIController.refreshEggStoreOrder()
	local eggStorePanel = panels:FindFirstChild("EggStore")
	if not eggStorePanel then return end
	local mainScroll = eggStorePanel:FindFirstChild("Main") :: ScrollingFrame
	if not mainScroll then return end
	local eggsScroll = mainScroll:FindFirstChild("Eggs") :: ScrollingFrame
	if not eggsScroll then return end

	local currentWorld = cachedData and cachedData.currentWorld or "forest"

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
		for _, key in (Constants.ALL_CURRENCY_KEYS or {}) do
			if currencies[key] ~= nil then cachedData[key] = currencies[key] end
		end
	end
	refreshEggBuyAffordState()
end

local function toastMotionReduced(): boolean
	if ClientPerformanceProfile.isReducedMotion() then
		return true
	end
	return cachedUiSettings.graphicsQuality <= 0
end

local function getToastDurations()
	local reduced = toastMotionReduced()
	return {
		enter = if reduced then 0.22 else 0.35,
		exit = if reduced then 0.22 else 0.30,
		reposition = if reduced then 0.18 else 0.25,
		lifetime = if reduced then 2.6 else TOAST_LIFETIME,
	}
end

local dismissToast

local function evictSlotIfNeeded(newPriority: number, newSeq: number)
	if #activeToasts < MAX_TOASTS then
		return
	end
	local minIdx = 1
	local minP = activeToasts[1].priority
	local minSeq = activeToasts[1].seq
	for i = 2, #activeToasts do
		local e = activeToasts[i]
		if e.priority < minP or (e.priority == minP and e.seq < minSeq) then
			minP = e.priority
			minSeq = e.seq
			minIdx = i
		end
	end
	if newPriority > minP then
		dismissToast(activeToasts[minIdx].id)
	else
		dismissToast(activeToasts[1].id)
	end
end

local function repositionToasts()
	local dur = getToastDurations().reposition
	for i, entry in activeToasts do
		cancelTweensFor(entry.frame)
		local targetY = toastStackTopPx() + (i - 1) * (64 + TOAST_GAP)
		playTween(
			entry.frame,
			TweenService:Create(
				entry.frame,
				TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, toastRightInnerOffset(), 0, targetY) }
			)
		)
	end
end

dismissToast = function(id: number)
	for i, entry in activeToasts do
		if entry.id == id then
			local frame = entry.frame
			cancelTweensFor(frame)
			local dur = getToastDurations().exit
			playTween(
				frame,
				TweenService:Create(
					frame,
					TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Position = UDim2.new(1, toastRightOffscreenOffset(), 0, frame.Position.Y.Offset),
						GroupTransparency = 1,
					}
				)
			)
			task.delay(dur + 0.05, function()
				if not clientSessionActive() then
					return
				end
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

local function showNotificationInternal(kind: string, msg: string, notification: any, skipRunGate: boolean)
	local sg = screenGui
	if not sg then
		return
	end

	local key = HudToastConfig.coalesceKey(kind, msg)
	local now = os.clock()
	local last = lastCoalesceAt[key]
	if last and (now - last) < HudToastConfig.COALESCE_WINDOW_SEC then
		return
	end
	lastCoalesceAt[key] = now

	local priority = HudToastConfig.resolvePriority(kind, notification)
	if not skipRunGate and DrivingRunGate.isInRun() and priority < HudToastConfig.MIN_PRIORITY_DURING_RUN then
		local toStore: any
		if type(notification) == "table" then
			toStore = notification
		else
			toStore = { type = kind, message = msg }
		end
		table.insert(deferredDuringRun, toStore)
		return
	end

	toastSeqCounter += 1
	local seq = toastSeqCounter
	evictSlotIfNeeded(priority, seq)

	toastIdCounter += 1
	local id = toastIdCounter
	local slotIndex = #activeToasts
	local startY = toastStackTopPx() + slotIndex * (64 + TOAST_GAP)
	local durs = getToastDurations()
	local reduced = toastMotionReduced()

	local iconDef = TOAST_ICONS[kind] or TOAST_ICONS.info

	local toast = Instance.new("CanvasGroup")
	toast.Name = "Toast_" .. id
	toast.Size = UDim2.new(0, TOAST_WIDTH, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = Color3.fromRGB(24, 26, 40)
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.AnchorPoint = Vector2.new(1, 0)
	toast.Position = UDim2.new(1, toastRightOffscreenOffset(), 0, startY)
	toast.ZIndex = Z.hudNotificationToast
	toast.ClipsDescendants = true
	toast.GroupTransparency = 1
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
	accent.ZIndex = Z.hudNotificationToastAccent
	accent.Parent = toast

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 14, 0, 10)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 20
	icon.Text = iconDef.text
	icon.TextColor3 = iconDef.color
	icon.ZIndex = Z.hudNotificationToastAccent
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
	lbl.ZIndex = Z.hudNotificationToastAccent
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

	if string.find(msg, "+", 1, true) and not reduced then
		local shimmer = Instance.new("Frame")
		shimmer.Size = UDim2.fromScale(1, 1)
		shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
		shimmer.BackgroundTransparency = 0.92
		shimmer.ZIndex = Z.hudNotificationToastShimmer
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

		playTween(
			toast,
			TweenService:Create(
				grad,
				TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 1),
				{ Offset = Vector2.new(1, 0) }
			)
		)
	end

	table.insert(activeToasts, { frame = toast, id = id, priority = priority, seq = seq })

	local toastScale = Instance.new("UIScale")
	toastScale.Scale = 1
	toastScale.Parent = toast

	task.delay(0.06, function()
		if not clientSessionActive() or not toast.Parent then
			return
		end
		playTween(
			toast,
			TweenService:Create(
				toast,
				TweenInfo.new(durs.enter, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, toastRightInnerOffset(), 0, startY), GroupTransparency = 0 }
			)
		)
	end)

	if not reduced and (kind == "streak_urgent" or kind == "streak_critical") then
		local pulses = if kind == "streak_critical" then 2 else 1
		for p = 1, pulses do
			task.delay(0.38 + (p - 1) * 0.28, function()
				if not clientSessionActive() or not toastScale.Parent then
					return
				end
				playTween(
					toast,
					TweenService:Create(
						toastScale,
						TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Scale = 1.06 }
					)
				)
				task.delay(0.12, function()
					if not clientSessionActive() or not toastScale.Parent then
						return
					end
					playTween(
						toast,
						TweenService:Create(
							toastScale,
							TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Scale = 1 }
						)
					)
				end)
			end)
		end
	end

	if kind == "error" then
		SoundFacade.playOneShot("purchase_fail")
	elseif kind == "streak_critical" then
		SoundFacade.playOneShot("alert")
	else
		SoundFacade.playOneShot("notification")
	end

	task.delay(durs.lifetime, function()
		if not clientSessionActive() then
			return
		end
		dismissToast(id)
	end)
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
	if type(notification) == "table" and NewPlayerCalmWindow.shouldDeferHudToast(kind, notification) then
		NewPlayerCalmWindow.enqueueNotification(notification)
		return
	end
	if kind == "reward_claim" then
		local chest = getRewardChestAnimation()
		if chest and chest.play then
			local ok = pcall(function()
				chest.play(notification)
			end)
			if ok then
				return
			end
		end
	end

	showNotificationInternal(kind, msg, notification, false)
end

--[[
	Normalized HUD toast API (POLA-332). Prefer this for new call sites.
	`text` or `message`, optional `type` / `tier`, optional `priority` string or number, `critical` flag.
]]
function UIController.showToast(opts: any)
	if type(opts) ~= "table" then
		return
	end
	local o = opts :: any
	local text = o.text or o.message
	if text == nil then
		return
	end
	local kind = "info"
	if type(o.type) == "string" then
		kind = o.type
	elseif type(o.tier) == "string" then
		kind = o.tier
	end
	local n: any = {
		type = kind,
		message = tostring(text),
	}
	if o.critical == true then
		n.critical = true
	end
	if o.priority ~= nil then
		n.priority = o.priority
	end
	UIController.showNotification(n)
end

function UIController.flushDeferredRunToasts()
	local q = deferredDuringRun
	table.clear(deferredDuringRun)
	for _, n in q do
		local kind = "info"
		local msg: string?
		if type(n) == "table" then
			if type((n :: any).type) == "string" then
				kind = (n :: any).type
			end
			if (n :: any).message ~= nil then
				msg = tostring((n :: any).message)
			end
		elseif type(n) == "string" then
			msg = n
		end
		if msg ~= nil then
			showNotificationInternal(kind, msg, n, true)
		end
	end
end

function UIController.showRunResults(results: any)
	RunResultsBridge.show(results)
end

local function ensurePopupOnTop()
	popup.ZIndex = Z.popupStack
	for _, child in popup:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = Z.popupChild
			for _, d in child:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = Z.popupDeep
				end
			end
		end
	end
end

function UIController.init()
	if uiControllerInitDone then
		return
	end
	uiControllerInitDone = true

	screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	screenGui.DisplayOrder = UILayerStack.screenGui.hudBase
	panels = screenGui:WaitForChild("Panels") :: Frame
	popup = screenGui:WaitForChild("Popup") :: Frame
	actionBar = screenGui:WaitForChild("ActionBar") :: Frame

	ensurePopupOnTop()
	ensureBackdrop()
	UIController.closeAllInstant()
	applyMenuHubResponsiveLayout()

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

	ContextActionService:BindActionAtPriority(
		DAC_UI_BACK_ACTION,
		onUiBackCancelAction,
		false,
		DAC_UI_BACK_PRIORITY,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)

	-- POLA-501: When FPS recovers from a dip, restart idle egg-shop / egg-buy cosmetic tweens.
	local lastCosmeticThrottle: boolean? = nil
	if cosmeticLodHeartbeatConn then
		cosmeticLodHeartbeatConn:Disconnect()
		cosmeticLodHeartbeatConn = nil
	end
	cosmeticLodHeartbeatConn = RunService.Heartbeat:Connect(function()
		local t = ClientPerformanceProfile.isCosmeticUiMotionThrottled()
		if lastCosmeticThrottle == nil then
			lastCosmeticThrottle = t
			return
		end
		if lastCosmeticThrottle == t then
			return
		end
		lastCosmeticThrottle = t
		local es = panels:FindFirstChild("EggStore")
		if es and es:IsA("GuiObject") and es.Visible then
			stopEggStoreJuice()
			startEggStoreJuice()
		end
		local eb = popup:FindFirstChild("EggBuy")
		if eb and eb:IsA("GuiObject") and eb.Visible then
			refreshEggBuyAffordState()
		end
		local inv = panels:FindFirstChild("Inventory")
		if inv and inv:IsA("GuiObject") and inv.Visible then
			refreshEggOpenPromptAffordState()
		end
	end)

	if hudToastLayoutDisconnect then
		hudToastLayoutDisconnect()
		hudToastLayoutDisconnect = nil
	end
	hudToastLayoutDisconnect = HudSafeArea.onLayoutChanged(function()
		repositionToasts()
		applyMenuHubResponsiveLayout()
		scheduleMenuStackReconcile()
	end)

	if windowFocusedConn then
		windowFocusedConn:Disconnect()
		windowFocusedConn = nil
	end
	windowFocusedConn = UserInputService.WindowFocused:Connect(function()
		if not clientSessionActive() then
			return
		end
		task.defer(reconcileMenuStackAfterInterrupt)
	end)

	Players.PlayerRemoving:Connect(function(p)
		if p == player then
			ContextActionService:UnbindAction(DAC_UI_BACK_ACTION)
			if cosmeticLodHeartbeatConn then
				cosmeticLodHeartbeatConn:Disconnect()
				cosmeticLodHeartbeatConn = nil
			end
			if windowFocusedConn then
				windowFocusedConn:Disconnect()
				windowFocusedConn = nil
			end
			if pendingMenuReconcile then
				task.cancel(pendingMenuReconcile)
				pendingMenuReconcile = nil
			end
			if hudToastLayoutDisconnect then
				hudToastLayoutDisconnect()
				hudToastLayoutDisconnect = nil
			end
			cancelAllTrackedTweens()
			for _, entry in activeToasts do
				local fr = entry.frame
				if fr and fr.Parent then
					fr:Destroy()
				end
			end
			table.clear(activeToasts)
			table.clear(deferredDuringRun)
			table.clear(lastCoalesceAt)
		end
	end)

	-- TrophyCasePanel.mount deferred to GuiBootstrap (POLA-513) after first spawn/input
	-- so the achievement grid does not run during join spike.

	Constants.bootLog("[DAC] UIController initialized")
end

return UIController
