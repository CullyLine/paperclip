--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

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
		HUD.updateCurrencies(currencies)
	end)

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(data)
		HUD.updateCurrencies({
			coins = data.coins,
			gems = data.gems,
			crystals = data.crystals,
			skulls = data.skulls,
		})
		HUD.updatePetMultiplier(petMultiplierFromData(data))
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
			HUD.updateCurrencies({
				coins = data.coins,
				gems = data.gems,
				crystals = data.crystals,
				skulls = data.skulls,
			})
			HUD.updatePetMultiplier(petMultiplierFromData(data))
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
