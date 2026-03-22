--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local HUD = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local actionBar: Frame
local inventoryButton: ImageButton
local currencyFrame: Frame
local coinLabel: TextLabel
local gemLabel: TextLabel
local crystalLabel: TextLabel
local skullLabel: TextLabel
local petMultLabel: TextLabel

local POPUP_INTERVAL = 2
local FLAVOR_ROLL = 0.48
local lastPopupAt: { [string]: number } = {}
local popupBuffer: { [string]: number } = {}
local popupDelayScheduled: { [string]: boolean } = {}
local prevCurrency: { coins: number, gems: number, crystals: number, skulls: number }? = nil
local prevPetMult: number? = nil

local CURRENCY_KEYS = { "coins", "gems", "crystals", "skulls" } :: { string }

local function snapshotCurrencies(t: any): { coins: number, gems: number, crystals: number, skulls: number }
	return {
		coins = math.floor(tonumber(t.coins) or 0),
		gems = math.floor(tonumber(t.gems) or 0),
		crystals = math.floor(tonumber(t.crystals) or 0),
		skulls = math.floor(tonumber(t.skulls) or 0),
	}
end

local function coinFlavorForAmount(amount: number): string
	local pool =
		if amount < 500 then MicrocopyConfig.CoinGainSmall
		elseif amount < 8000 then MicrocopyConfig.CoinGainMedium
		else MicrocopyConfig.CoinGainLarge
	local template = pool[math.random(1, #pool)]
	return template:gsub("{AMOUNT}", Utils.formatNumber(amount))
end

local function gemFlavorForAmount(amount: number): string
	local template = MicrocopyConfig.GemGain[math.random(1, #MicrocopyConfig.GemGain)]
	return template:gsub("{AMOUNT}", Utils.formatNumber(amount))
end

local function flushCurrencyPopup(key: string)
	local amt = popupBuffer[key]
	if not amt or amt <= 0 then
		return
	end
	popupBuffer[key] = 0
	popupDelayScheduled[key] = nil
	lastPopupAt[key] = tick()
	local flavor: string? = nil
	if math.random() < FLAVOR_ROLL then
		if key == "coins" then
			flavor = coinFlavorForAmount(amt)
		elseif key == "gems" then
			flavor = gemFlavorForAmount(amt)
		end
	end
	VFXFacade.currencyPopup(key, amt, flavor)
end

local function queueCurrencyPopup(key: string, delta: number)
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
	local wait = math.max(0, POPUP_INTERVAL - (tick() - last))
	if wait <= 0 then
		flushCurrencyPopup(key)
	else
		popupDelayScheduled[key] = true
		task.delay(wait, function()
			popupDelayScheduled[key] = nil
			flushCurrencyPopup(key)
		end)
	end
end

local PULSE_COLORS: { [string]: Color3 } = {
	coins = Color3.fromRGB(255, 220, 80),
	gems = Color3.fromRGB(120, 255, 140),
	crystals = Color3.fromRGB(140, 220, 255),
	skulls = Color3.fromRGB(240, 240, 200),
}

local function labelForCurrency(key: string): TextLabel?
	if key == "coins" then
		return coinLabel
	elseif key == "gems" then
		return gemLabel
	elseif key == "crystals" then
		return crystalLabel
	elseif key == "skulls" then
		return skullLabel
	end
	return nil
end

local function spendDrainOnLabel(lbl: TextLabel)
	SoundFacade.playOneShot("click")
	local orig = lbl.TextColor3
	TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextColor3 = Color3.fromRGB(255, 90, 90),
	}):Play()
	task.delay(0.2, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			}):Play()
		end
	end)
	local us = lbl:FindFirstChildOfClass("UIScale")
	if not us then
		us = Instance.new("UIScale")
		us.Scale = 1
		us.Parent = lbl
	end
	TweenService:Create(us, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
	task.delay(0.15, function()
		if us.Parent then
			TweenService:Create(us, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
end

local function goldPulsePetMultiplierLabel()
	if not petMultLabel then
		return
	end
	SoundFacade.playOneShot("level_up")
	local lbl = petMultLabel
	local orig = lbl.TextColor3
	local gold = Color3.fromRGB(255, 213, 90)
	TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextColor3 = gold,
	}):Play()
	task.delay(0.14, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			}):Play()
		end
	end)
end

function HUD.pulseCurrencyLabel(key: string)
	local lbl = labelForCurrency(key)
	if not lbl then
		return
	end
	local pulse = PULSE_COLORS[key] or Color3.fromRGB(255, 255, 255)
	local orig = lbl.TextColor3
	TweenService:Create(lbl, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextColor3 = pulse,
	}):Play()
	task.delay(0.12, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = orig,
			}):Play()
		end
	end)
end

local function ingestCurrencySnapshot(currencies: any)
	local cur = snapshotCurrencies(currencies)
	if prevCurrency then
		for _, key in CURRENCY_KEYS do
			local d = cur[key] - prevCurrency[key]
			if d > 0 then
				queueCurrencyPopup(key, d)
				HUD.pulseCurrencyLabel(key)
			elseif d < 0 then
				local lbl = labelForCurrency(key)
				if lbl then
					spendDrainOnLabel(lbl)
				end
			end
		end
	end
	prevCurrency = cur
	HUD.updateCurrencies({
		coins = cur.coins,
		gems = cur.gems,
		crystals = cur.crystals,
		skulls = cur.skulls,
	})
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

function HUD.updateCurrencies(currencies: { [string]: number })
	if coinLabel then
		coinLabel.Text = Utils.formatNumber(currencies.coins or 0)
	end
	if gemLabel then
		gemLabel.Text = Utils.formatNumber(currencies.gems or 0)
	end
	if crystalLabel then
		crystalLabel.Text = Utils.formatNumber(currencies.crystals or 0)
	end
	if skullLabel then
		skullLabel.Text = Utils.formatNumber(currencies.skulls or 0)
	end
end

function HUD.updatePetMultiplier(mult: number)
	if petMultLabel then
		petMultLabel.Text = string.format("x%.1f", mult)
	end
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

function HUD.init()
	screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui

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
	local gems = currencyFrame:FindFirstChild("Gems")
	if gems then gemLabel = findLabel(gems) end
	local crystals = currencyFrame:FindFirstChild("Crystals")
	if crystals then crystalLabel = findLabel(crystals) end
	local skulls = currencyFrame:FindFirstChild("Skulls")
	if skulls then skullLabel = findLabel(skulls) end
	local petMult = currencyFrame:FindFirstChild("PetMultiplier")
	if petMult then petMultLabel = findLabel(petMult) end

	inventoryButton.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		local uc = getUIController()
		if uc and uc.togglePanel then
			uc.togglePanel("Inventory")
		end
	end)

	Remotes.getEvent("CurrencyUpdate").OnClientEvent:Connect(function(currencies)
		ingestCurrencySnapshot(currencies)
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		ingestCurrencySnapshot(data)
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
		if ok and data then
			ingestCurrencySnapshot(data)
			local mult = petMultiplierFromData(data)
			prevPetMult = mult
			HUD.updatePetMultiplier(mult)
		end
	end)

	print("[DAC] HUD initialized (using DACMain)")
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
