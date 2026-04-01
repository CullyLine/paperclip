--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local Constants = require(DAC:WaitForChild("Constants"))
local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
local PremiumService = require(script.Parent:WaitForChild("PremiumService"))

local CurrencyService = {}

--[[
	Sources that count as “earned on the road” for game pass + Premium coin multipliers.
	Excludes codes, dev products, admin, daily streak grants, etc.
]]
local GAMEPLAY_COIN_SOURCES: { [string]: boolean } = {
	checkpoint = true,
	near_miss = true,
	playtime = true,
}

local function gameplayCoinMultiplier(player: Player, source: string): number
	if not GAMEPLAY_COIN_SOURCES[source] then
		return 1
	end
	local mult = 1
	if GamePassService.hasPass(player, "double_coins") then
		mult *= 2
	end
	if GamePassService.hasPass(player, "coin_boost") then
		mult *= 1.1
	end
	if PremiumService.isPremium(player) then
		mult *= 1 + Constants.PREMIUM_COIN_BONUS
	end
	return mult
end

function CurrencyService.add(player: Player, currency: string, amount: number, source: string): number
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return 0
	end
	if amount <= 0 then
		return 0
	end
	local grant = amount
	if currency == "coins" then
		grant = math.floor(amount * gameplayCoinMultiplier(player, source) + 0.5)
	end
	local m = EventService.getFounderCoinMultiplier()
	if m > 1 then
		grant = math.floor(grant * m + 0.5)
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
