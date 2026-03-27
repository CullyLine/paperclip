--!strict
--[[
	Active playtime: coin bonus every 15 minutes while character is alive.
	Base amount scales with equipped pet multiplier.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))
local Utils = require(DAC:WaitForChild("Utils"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))

local PlaytimeService = {}

function PlaytimeService.init()
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = DataManager.get(player)
				if not data then
					continue
				end
				AchievementService.checkNightOwlSession(player)

				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then
					continue
				end

				data.playtimeSecondsSinceBonus = (data.playtimeSecondsSinceBonus or 0) + 60
				while data.playtimeSecondsSinceBonus >= Constants.PLAYTIME_BONUS_INTERVAL do
					data.playtimeSecondsSinceBonus -= Constants.PLAYTIME_BONUS_INTERVAL
					local equippedPets = {}
					for _, pet in data.pets do
						if pet.equipped then
							table.insert(equippedPets, pet)
						end
					end
					local petMult = PetService.getEffectivePetCoinModifier(player, equippedPets)
					local grant = math.floor(Constants.PLAYTIME_BONUS_BASE_COINS * math.max(1, petMult) + 0.5)
					CurrencyService.add(player, "coins", grant, "playtime")
					NotificationDispatchService.notify(player, {
						type = "success",
						message = `Playtime bonus: +{Utils.formatNumber(grant)} Coins!`,
					})
				end
				Remotes.getEvent("DataUpdate"):FireClient(player, data)
			end
		end
	end)
end

return PlaytimeService
