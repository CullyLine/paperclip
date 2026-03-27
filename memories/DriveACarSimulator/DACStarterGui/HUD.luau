--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local HUD = {}

-- Idempotent init: GuiBootstrap guard + defense against duplicate RemoteEvent / RenderStepped wiring.
local hudInitDone = false

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- False after PlayerRemoving; prevents stale task.delay / task.spawn callbacks from touching HUD/UI.
local hudModuleAlive = true

local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local screenGui: ScreenGui
local actionBar: Frame
local inventoryButton: ImageButton
local currencyFrame: Frame
local coinLabel: TextLabel
local petMultLabel: TextLabel
local passiveIncomeLabel: TextLabel? = nil
local prevPassiveIncomeText: string? = nil
local currentWorldId: string = "forest"

local fpsLabel: TextLabel? = nil
local fpsFrameAccum = 0
local fpsClock = 0.0

local POPUP_INTERVAL = 2
local FLAVOR_ROLL = 0.48
local lastPopupAt: { [string]: number } = {}
local popupBuffer: { [string]: number } = {}
local popupDelayScheduled: { [string]: boolean } = {}
local prevCurrency: { [string]: number }? = nil
local prevPetMult: number? = nil

-- Throttle rapid CurrencyUpdate / DataUpdate so mobile does not stack tweens every frame.
local ECONOMY_JUICE_MIN_INTERVAL = 0.14
local economyGainAccum: { [string]: number } = {}
local economyGainLastCur: { [string]: number } = {}
local economyGainFlushScheduled: { [string]: boolean } = {}
local lastEconomyJuiceAt: { [string]: number } = {}

local PET_MULT_JUICE_INTERVAL = 0.16
local lastPetMultJuiceAt = 0.0

local SPEND_DRAIN_MIN_INTERVAL = 0.09
local lastSpendDrainAt: { [string]: number } = {}

local CURRENCY_KEYS = Constants.ALL_CURRENCY_KEYS or { "coins", "sandGranules", "icycles", "magmaCores", "infinitium" }

local hudTweenBuckets: { [Instance]: { Tween } } = {}
local hudLayoutDisconnect: (() -> ())? = nil

local function cancelHudTweensFor(inst: Instance)
	local bucket = hudTweenBuckets[inst]
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

local function hudPlayTween(inst: Instance, tw: Tween)
	local bucket = hudTweenBuckets[inst]
	if not bucket then
		bucket = {}
		hudTweenBuckets[inst] = bucket
	end
	table.insert(bucket, tw)
	tw:Play()
	return tw
end

local function snapshotCurrencies(t: any): { [string]: number }
	local snap = {}
	for _, key in CURRENCY_KEYS do
		snap[key] = math.floor(tonumber(t[key]) or 0)
	end
	return snap
end

local function coinFlavorForAmount(amount: number): string
	local template: string
	if amount < 500 then
		template = MicrocopyConfig.pickVariant(MicrocopyConfig.CoinGainSmall)
	elseif amount < 8000 then
		template = MicrocopyConfig.pickVariant(MicrocopyConfig.CoinGainMedium)
	else
		template = MicrocopyConfig.pickVariant(MicrocopyConfig.CoinGainLarge, MicrocopyConfig.CoinGainLargeOptional)
	end
	return template:gsub("{AMOUNT}", Utils.formatNumber(amount))
end


local function flushCurrencyPopup(key: string)
	if not hudModuleAlive then
		return
	end
	local amt = popupBuffer[key]
	if not amt or amt <= 0 then
		return
	end
	popupBuffer[key] = 0
	popupDelayScheduled[key] = nil
	lastPopupAt[key] = os.clock()
	local flavor: string? = nil
	if math.random() < FLAVOR_ROLL and key == "coins" then
		flavor = coinFlavorForAmount(amt)
	end
	VFXFacade.currencyPopup(key, amt, flavor)
end

local function queueCurrencyPopup(key: string, delta: number)
	if not hudModuleAlive then
		return
	end
	if delta <= 0 then
		return
	end
	popupBuffer[key] = (popupBuffer[key] or 0) + delta
	if popupDelayScheduled[key] then
		return
	end
	local last = lastPopupAt[key]
	if last == nil then
		flushCurrencyPopup(key)
		return
	end
	local wait = math.max(0, POPUP_INTERVAL - (os.clock() - last))
	if wait <= 0 then
		flushCurrencyPopup(key)
	else
		popupDelayScheduled[key] = true
		task.delay(wait, function()
			if not hudModuleAlive then
				popupDelayScheduled[key] = nil
				return
			end
			popupDelayScheduled[key] = nil
			flushCurrencyPopup(key)
		end)
	end
end

local PULSE_COLORS: { [string]: Color3 } = {
	coins = Color3.fromRGB(255, 220, 80),
	sandGranules = Color3.fromRGB(220, 200, 120),
	icycles = Color3.fromRGB(140, 220, 255),
	magmaCores = Color3.fromRGB(255, 120, 60),
	infinitium = Color3.fromRGB(180, 150, 255),
}

local POSITIVE_FLASH: { [string]: Color3 } = {
	coins = Color3.fromRGB(255, 214, 96),
	sandGranules = Color3.fromRGB(240, 220, 140),
	icycles = Color3.fromRGB(150, 230, 255),
	magmaCores = Color3.fromRGB(255, 140, 80),
	infinitium = Color3.fromRGB(200, 170, 255),
}

local function shouldHudEconomyJuice(): boolean
	return ClientPerformanceProfile.uiJuiceStrength() > 0
end

local function cacheSettingsFromData(data: any)
	if type(data) ~= "table" or type(data.settings) ~= "table" then
		return
	end
	local s = data.settings
	ClientPerformanceProfile.syncFromSettings(s)
end

local function ensureUIScale(lbl: GuiObject): UIScale
	local us = lbl:FindFirstChildOfClass("UIScale")
	if not us then
		us = Instance.new("UIScale")
		us.Scale = 1
		us.Parent = lbl
	end
	return us :: UIScale
end

local labelForCurrency -- forward-declared; defined below

local function playEconomyJuiceCurrency(key: string, totalD: number, curVal: number)
	local lbl = labelForCurrency(key)
	if not lbl then
		return
	end
	if not shouldHudEconomyJuice() then
		return
	end
	cancelHudTweensFor(lbl)
	local tinyThreshold = math.max(3, math.floor(math.max(0, curVal) * 0.002))
	local tiny = totalD < tinyThreshold
	local pulse = PULSE_COLORS[key] or Color3.fromRGB(255, 255, 255)
	local flash = POSITIVE_FLASH[key] or pulse
	local orig = lbl.TextColor3
	local us = ensureUIScale(lbl)
	cancelHudTweensFor(us)
	local str = ClientPerformanceProfile.uiJuiceStrength()
	local pop = if tiny then 1 + (1.04 - 1) * str else 1 + (1.09 - 1) * str
	local up = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local down = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	hudPlayTween(us, TweenService:Create(us, up, { Scale = pop }))
	task.delay(0.1, function()
		if not hudModuleAlive or not us.Parent then
			return
		end
		hudPlayTween(us, TweenService:Create(us, down, { Scale = 1 }))
	end)
	if tiny then
		hudPlayTween(
			lbl,
			TweenService:Create(lbl, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig:Lerp(flash, 0.35),
			})
		)
		task.delay(0.1, function()
			if not hudModuleAlive or not lbl.Parent then
				return
			end
			hudPlayTween(
				lbl,
				TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = orig,
				})
			)
		end)
	else
		hudPlayTween(
			lbl,
			TweenService:Create(lbl, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = flash,
			})
		)
		task.delay(0.12, function()
			if not hudModuleAlive or not lbl.Parent then
				return
			end
			hudPlayTween(
				lbl,
				TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = orig,
				})
			)
		end)
	end
end

local function flushEconomyGainJuice(key: string)
	local totalD = economyGainAccum[key]
	if not totalD or totalD <= 0 then
		return
	end
	economyGainAccum[key] = nil
	economyGainFlushScheduled[key] = nil
	local curVal = economyGainLastCur[key] or 0
	lastEconomyJuiceAt[key] = os.clock()
	playEconomyJuiceCurrency(key, totalD, curVal)
end

local function scheduleEconomyGainJuice(key: string, delta: number, curVal: number)
	if delta <= 0 then
		return
	end
	economyGainAccum[key] = (economyGainAccum[key] or 0) + delta
	economyGainLastCur[key] = curVal
	if economyGainFlushScheduled[key] then
		return
	end
	economyGainFlushScheduled[key] = true
	local last = lastEconomyJuiceAt[key] or 0
	local wait = math.max(0, ECONOMY_JUICE_MIN_INTERVAL - (os.clock() - last))
	task.delay(wait, function()
		if not hudModuleAlive then
			economyGainFlushScheduled[key] = nil
			return
		end
		economyGainFlushScheduled[key] = nil
		flushEconomyGainJuice(key)
	end)
end

labelForCurrency = function(_key: string): TextLabel?
	return coinLabel
end

local function spendDrainForCurrencyKey(key: string, lbl: TextLabel)
	local now = os.clock()
	local last = lastSpendDrainAt[key] or 0
	if now - last < SPEND_DRAIN_MIN_INTERVAL then
		return
	end
	lastSpendDrainAt[key] = now
	SoundFacade.playOneShot("click")
	if not shouldHudEconomyJuice() then
		return
	end
	cancelHudTweensFor(lbl)
	local orig = lbl.TextColor3
	hudPlayTween(
		lbl,
		TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = Color3.fromRGB(255, 90, 90),
		})
	)
	task.delay(0.2, function()
		if not hudModuleAlive or not lbl.Parent then
			return
		end
		hudPlayTween(
			lbl,
			TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			})
		)
	end)
	local us = ensureUIScale(lbl)
	cancelHudTweensFor(us)
	local sd = ClientPerformanceProfile.uiJuiceStrength()
	local dip = 1 - 0.1 * sd
	hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = dip }))
	task.delay(0.15, function()
		if not hudModuleAlive or not us.Parent then
			return
		end
		hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }))
	end)
end

local function goldPulsePetMultiplierLabel()
	if not petMultLabel then
		return
	end
	local now = os.clock()
	if now - lastPetMultJuiceAt < PET_MULT_JUICE_INTERVAL then
		return
	end
	lastPetMultJuiceAt = now
	SoundFacade.playOneShot("level_up")
	local lbl = petMultLabel
	if not shouldHudEconomyJuice() then
		return
	end
	cancelHudTweensFor(lbl)
	local orig = lbl.TextColor3
	local gold = Color3.fromRGB(255, 213, 90)
	local us = ensureUIScale(lbl)
	cancelHudTweensFor(us)
	local str = ClientPerformanceProfile.uiJuiceStrength()
	hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 + 0.1 * str }))
	task.delay(0.1, function()
		if not hudModuleAlive or not us.Parent then
			return
		end
		hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }))
	end)
	hudPlayTween(
		lbl,
		TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = gold,
		})
	)
	task.delay(0.14, function()
		if not hudModuleAlive or not lbl.Parent then
			return
		end
		hudPlayTween(
			lbl,
			TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			})
		)
	end)
end

function HUD.pulseCurrencyLabel(key: string)
	local lbl = labelForCurrency(key)
	if not lbl then
		return
	end
	local cur = 0
	if prevCurrency then
		cur = prevCurrency[key] or 0
	end
	playEconomyJuiceCurrency(key, math.max(50, math.floor(cur * 0.05 + 1)), cur)
end

local function ingestCurrencySnapshot(currencies: any)
	if not hudModuleAlive then
		return
	end
	cacheSettingsFromData(currencies)
	if type(currencies) == "table" and type(currencies.currentWorld) == "string" then
		currentWorldId = currencies.currentWorld
	end
	local cur = snapshotCurrencies(currencies)
	if prevCurrency then
		for _, key in CURRENCY_KEYS do
			local d = (cur[key] or 0) - (prevCurrency[key] or 0)
			if d > 0 then
				queueCurrencyPopup(key, d)
				scheduleEconomyGainJuice(key, d, cur[key] or 0)
			elseif d < 0 then
				local lbl = labelForCurrency(key)
				if lbl then
					spendDrainForCurrencyKey(key, lbl)
				end
			end
		end
	end
	prevCurrency = cur
	local activeKey = WorldConfig.getCurrencyKey(currentWorldId)
	HUD.updateCurrencies(cur, activeKey)
end

local function findLabel(currencyRow: Instance): TextLabel?
	local tf = currencyRow:FindFirstChild("TextFrame")
	if tf then
		local lbl = tf:FindFirstChild("TextLabel")
		if lbl and lbl:IsA("TextLabel") then
			return lbl
		end
	end
	return nil
end

function HUD.updateCurrencies(currencies: { [string]: number }, activeKey: string?)
	local key = activeKey or WorldConfig.getCurrencyKey(currentWorldId)
	local name = WorldConfig.getCurrencyName(currentWorldId)
	local display = Constants.CURRENCY_DISPLAY[key]
	if coinLabel then
		coinLabel.Text = Utils.formatNumber(currencies[key] or 0) .. " " .. name
		if display and display.color then
			coinLabel.TextColor3 = display.color
		end
	end
end

function HUD.updatePetMultiplier(mult: number)
	if petMultLabel then
		petMultLabel.Text = string.format("x%.1f", mult)
	end
end

-- Optional Currency row (pre-built in Studio): passive coins/sec or similar. Call when that value changes.
function HUD.setPassiveIncomeDisplay(text: string)
	if not passiveIncomeLabel then
		return
	end
	if text == prevPassiveIncomeText then
		return
	end
	prevPassiveIncomeText = text
	passiveIncomeLabel.Text = text
	if not shouldHudEconomyJuice() then
		return
	end
	local lbl = passiveIncomeLabel
	cancelHudTweensFor(lbl)
	local orig = lbl.TextColor3
	local us = ensureUIScale(lbl)
	cancelHudTweensFor(us)
	hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 }))
	task.delay(0.1, function()
		if not hudModuleAlive or not us.Parent then
			return
		end
		hudPlayTween(us, TweenService:Create(us, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }))
	end)
	local green = Color3.fromRGB(130, 255, 170)
	hudPlayTween(
		lbl,
		TweenService:Create(lbl, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = orig:Lerp(green, 0.5),
		})
	)
	task.delay(0.12, function()
		if not hudModuleAlive or not lbl.Parent then
			return
		end
		hudPlayTween(
			lbl,
			TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			})
		)
	end)
end

local function petMultiplierFromData(data: any): number
	if type(data) ~= "table" or type(data.pets) ~= "table" then
		return 1
	end
	local equipped: { { power: number } } = {}
	for _, pet in data.pets do
		if type(pet) == "table" and pet.equipped then
			table.insert(equipped, { power = pet.power or 0 })
		end
	end
	return Utils.calculatePetModifier(equipped)
end

local function setLobbyVisible(visible: boolean)
	if actionBar then
		actionBar.Visible = visible
	end
end

local UIController: any = nil

local function getUIController()
	if UIController then return UIController end
	local ok, mod = pcall(function()
		local sps = player:WaitForChild("PlayerScripts", 5)
		if not sps then warn("[DAC-HUD] PlayerScripts not found") return nil end
		local dacFolder = sps:FindFirstChild("DAC")
		if not dacFolder then warn("[DAC-HUD] DAC folder not found in PlayerScripts") return nil end
		local ctrls = dacFolder:FindFirstChild("Controllers")
		if not ctrls then warn("[DAC-HUD] Controllers not found") return nil end
		local uc = ctrls:FindFirstChild("UIController")
		if not uc then warn("[DAC-HUD] UIController module not found") return nil end
		return require(uc)
	end)
	if ok and mod then
		UIController = mod
	else
		warn("[DAC-HUD] Failed to get UIController:", mod)
	end
	return UIController
end

local function applyDacMainHudSafeInsets(host: ScreenGui)
	local l, t, r, b = HudSafeArea.getManualInsetsForScreenGui(host)
	-- Only add edgeMargin when we are compensating for IgnoreGuiInset (non-zero engine insets).
	local em = if (l + t + r + b) > 0 then HudLayoutConfig.edgeMarginPx else 0
	local topPad = math.floor(t + em + HudLayoutConfig.hudPlayerInfoExtraTopPx + 0.5)
	local bottomPad = math.floor(b + em + HudLayoutConfig.hudActionBarExtraBottomPx + 0.5)
	local leftPad = math.floor(l + em + 0.5)
	local rightPad = math.floor(r + em + 0.5)

	local function ensureSafePad(frame: Frame): UIPadding
		local p = frame:FindFirstChild("DACSafeAreaPad")
		if p and p:IsA("UIPadding") then
			return p
		end
		local pad = Instance.new("UIPadding")
		pad.Name = "DACSafeAreaPad"
		pad.Parent = frame
		return pad
	end

	local pInfo = host:WaitForChild("PlayerInfo") :: Frame
	local padPI = ensureSafePad(pInfo)
	padPI.PaddingTop = UDim.new(0, topPad)
	padPI.PaddingLeft = UDim.new(0, leftPad)
	padPI.PaddingRight = UDim.new(0, rightPad)

	local ab = host:WaitForChild("ActionBar") :: Frame
	local padAB = ensureSafePad(ab)
	padAB.PaddingBottom = UDim.new(0, bottomPad)
	padAB.PaddingLeft = UDim.new(0, leftPad)
	padAB.PaddingRight = UDim.new(0, rightPad)
end

local function fpsCornerOffset(host: ScreenGui): (number, number)
	local l, t, _, _ = HudSafeArea.getManualInsetsForScreenGui(host)
	local em = if (l + t) > 0 then HudLayoutConfig.edgeMarginPx else 0
	return l + em + 10, t + em + 10
end

function HUD.init()
	if hudInitDone then
		return
	end
	hudInitDone = true

	screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	applyDacMainHudSafeInsets(screenGui)

	actionBar = screenGui:WaitForChild("ActionBar") :: Frame
	inventoryButton = actionBar:WaitForChild("Inventory") :: ImageButton

	local driveBtn = actionBar:FindFirstChild("Drive")
	if driveBtn then
		(driveBtn :: GuiObject).Visible = false
	end

	local pInfo = screenGui:WaitForChild("PlayerInfo") :: Frame
	currencyFrame = pInfo:WaitForChild("Currency") :: Frame

	local coins = currencyFrame:FindFirstChild("Coins")
	if coins then coinLabel = findLabel(coins) end
	for _, oldName in { "Gems", "Crystals", "Skulls" } do
		local row = currencyFrame:FindFirstChild(oldName)
		if row then
			(row :: GuiObject).Visible = false
		end
	end
	local petMult = currencyFrame:FindFirstChild("PetMultiplier")
	if petMult then petMultLabel = findLabel(petMult) end
	local passiveRow = currencyFrame:FindFirstChild("PassiveIncome") or currencyFrame:FindFirstChild("CoinsPerSec")
	if passiveRow then
		passiveIncomeLabel = findLabel(passiveRow)
		if passiveIncomeLabel then
			prevPassiveIncomeText = passiveIncomeLabel.Text
		end
	end

	for _, lbl in { coinLabel, petMultLabel, passiveIncomeLabel } do
		if lbl then
			UIHelpers.ensureSingleLineTruncate(lbl)
		end
	end

	-- Press/hover juice + ui_quickbar_* SFX: UIController.createActionBarButtons → UIHelpers.wireHubIconButtonsUnder(ActionBar).
	-- Debounce Activated + MouseButton1Click so touch + mouse do not double-fire (POLA-395).
	local lastInvFire = 0.0
	local function onInventoryActivate()
		local now = os.clock()
		if now - lastInvFire < 0.08 then
			return
		end
		lastInvFire = now
		local uc = getUIController()
		if uc and uc.togglePanel then
			uc.togglePanel("Inventory")
		end
	end
	inventoryButton.Activated:Connect(onInventoryActivate)
	inventoryButton.MouseButton1Click:Connect(onInventoryActivate)

	Remotes.getEvent("CurrencyUpdate").OnClientEvent:Connect(function(currencies)
		ingestCurrencySnapshot(currencies)
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		ingestCurrencySnapshot(data)
		if type(data) == "table" and type((data :: any).passiveIncomePerSec) == "number" then
			HUD.setPassiveIncomeDisplay(Utils.formatNumber(math.max(0, math.floor((data :: any).passiveIncomePerSec))) .. "/s")
		end
		local mult = petMultiplierFromData(data)
		if prevPetMult ~= nil and mult > prevPetMult + 0.001 then
			goldPulsePetMultiplierLabel()
		end
		prevPetMult = mult
		HUD.updatePetMultiplier(mult)
	end)

	Remotes.getEvent("StartRun").OnClientEvent:Connect(function()
		setLobbyVisible(false)
	end)

	Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
		setLobbyVisible(true)
	end)

	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.getFunction("GetPlayerData"):InvokeServer()
		end)
		if not hudModuleAlive or not player.Parent then
			return
		end
		if ok and data then
			ingestCurrencySnapshot(data)
			if type(data) == "table" and type((data :: any).passiveIncomePerSec) == "number" then
				HUD.setPassiveIncomeDisplay(Utils.formatNumber(math.max(0, math.floor((data :: any).passiveIncomePerSec))) .. "/s")
			end
			local mult = petMultiplierFromData(data)
			prevPetMult = mult
			HUD.updatePetMultiplier(mult)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		if p == player then
			if hudLayoutDisconnect then
				hudLayoutDisconnect()
				hudLayoutDisconnect = nil
			end
			hudModuleAlive = false
			table.clear(popupBuffer)
			table.clear(popupDelayScheduled)
			table.clear(lastPopupAt)
			table.clear(economyGainAccum)
			table.clear(economyGainLastCur)
			table.clear(economyGainFlushScheduled)
			table.clear(lastEconomyJuiceAt)
			table.clear(lastSpendDrainAt)
			for _, bucket in pairs(hudTweenBuckets) do
				for _, tw in bucket do
					pcall(function()
						tw:Cancel()
					end)
				end
			end
			hudTweenBuckets = {}
		end
	end)

	local fps = Instance.new("TextLabel")
	fps.Name = "FpsCounter"
	fps.BackgroundTransparency = 1
	fps.Size = UDim2.fromOffset(80, 22)
	do
		local ox, oy = fpsCornerOffset(screenGui)
		fps.Position = UDim2.new(0, ox, 0, oy)
	end
	fps.Font = Enum.Font.GothamBold
	fps.TextSize = 15
	fps.TextColor3 = Color3.fromRGB(245, 245, 255)
	fps.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	fps.TextStrokeTransparency = 0.45
	fps.Text = ""
	fps.Visible = false
	fps.ZIndex = 80
	fps.Parent = screenGui
	fpsLabel = fps
	UIHelpers.ensureSingleLineTruncate(fps)
	fpsClock = os.clock()
	if hudLayoutDisconnect then
		hudLayoutDisconnect()
		hudLayoutDisconnect = nil
	end
	hudLayoutDisconnect = HudSafeArea.onLayoutChanged(function()
		if not hudModuleAlive or not screenGui then
			return
		end
		applyDacMainHudSafeInsets(screenGui)
		local lbl = fpsLabel
		if lbl and lbl.Parent then
			local ox, oy = fpsCornerOffset(screenGui)
			lbl.Position = UDim2.new(0, ox, 0, oy)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not hudModuleAlive then
			return
		end
		local lbl = fpsLabel
		if not lbl or not lbl.Parent then
			return
		end
		fpsFrameAccum += 1
		local now = os.clock()
		if now - fpsClock < 0.4 then
			return
		end
		local dt = now - fpsClock
		fpsClock = now
		local instFps = fpsFrameAccum / math.max(dt, 1e-4)
		fpsFrameAccum = 0
		if ClientPerformanceProfile.shouldShowFps() then
			lbl.Visible = true
			lbl.Text = string.format("%d FPS", math.floor(instFps + 0.5))
		else
			lbl.Visible = false
		end
	end)

	Constants.bootLog("[DAC] HUD initialized (using DACMain)")
end

function HUD.getMenuButton(name: string): ImageButton?
	if actionBar then
		local btn = actionBar:FindFirstChild(name)
		if btn and btn:IsA("ImageButton") then
			return btn
		end
	end
	return nil
end

function HUD.getScreenGui(): ScreenGui?
	return screenGui
end

return HUD
