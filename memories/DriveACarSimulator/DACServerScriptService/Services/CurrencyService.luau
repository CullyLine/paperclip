--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local Constants = require(DAC:WaitForChild("Constants"))
local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))

local CurrencyService = {}

function CurrencyService.add(player: Player, currency: string, amount: number, source: string): number
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return 0
	end
	if amount <= 0 then
		return 0
	end
	local grant = amount
	local m = EventService.getFounderCoinMultiplier()
	if m > 1 then
		grant = math.floor(amount * m + 0.5)
	end
	if DataManager.addCurrency(player, currency, grant, source) then
		if currency == "coins" and grant > 0 then
			local data = DataManager.get(player)
			if data then
				if type(data.stats) ~= "table" then
					data.stats = {}
				end
				if type(data.stats.totalCoinsEarned) ~= "number" then
					data.stats.totalCoinsEarned = 0
				end
				data.stats.totalCoinsEarned += grant
				AchievementService.onTotalCoinsEarned(player, data)
			end
		end
		CurrencyService.sync(player)
	end
	return grant
end

function CurrencyService.spend(player: Player, currency: string, amount: number): boolean
	local success = DataManager.spendCurrency(player, currency, amount)
	if success then
		if currency == "coins" and amount > 0 then
			local data = DataManager.get(player)
			if data then
				data.coinsSpentTotal = (data.coinsSpentTotal or 0) + math.floor(amount)
				AchievementService.onCoinsSpent(player, data)
			end
		end
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
	local payload = {}
	for _, key in Constants.ALL_CURRENCY_KEYS do
		payload[key] = data[key] or 0
	end
	Remotes.getEvent("CurrencyUpdate"):FireClient(player, payload)
end

function CurrencyService.init()
	-- Currency updates are driven by other services (RunService, EggService, etc.)
end

return CurrencyService
