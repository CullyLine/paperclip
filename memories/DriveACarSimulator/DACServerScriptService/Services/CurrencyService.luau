--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local EventService = require(script.Parent:WaitForChild("EventService"))

local CurrencyService = {}

function CurrencyService.add(player: Player, currency: string, amount: number, source: string): number
	if amount <= 0 then
		return 0
	end
	local grant = amount
	if currency == "coins" then
		local m = EventService.getFounderCoinMultiplier()
		grant = math.floor(amount * m + 0.5)
	end
	if DataManager.addCurrency(player, currency, grant, source) then
		CurrencyService.sync(player)
	end
	return grant
end

function CurrencyService.spend(player: Player, currency: string, amount: number): boolean
	local success = DataManager.spendCurrency(player, currency, amount)
	if success then
		CurrencyService.sync(player)
	end
	return success
end

function CurrencyService.get(player: Player, currency: string): number
	return DataManager.getCurrency(player, currency)
end

function CurrencyService.sync(player: Player)
	local data = DataManager.get(player)
	if not data then return end
	Remotes.getEvent("CurrencyUpdate"):FireClient(player, {
		coins = data.coins,
		gems = data.gems,
		crystals = data.crystals,
		skulls = data.skulls,
	})
end

function CurrencyService.init()
	-- Currency updates are driven by other services (RunService, EggService, etc.)
end

return CurrencyService
