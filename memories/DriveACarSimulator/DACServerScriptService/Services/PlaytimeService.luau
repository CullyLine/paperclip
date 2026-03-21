--!strict
--[[
	Active playtime: 1 gem per 15 minutes while character is alive in the world.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))

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
				if not player.Character or not player.Character:FindFirstChild("Humanoid") then
					continue
				end
				local hum = player.Character.Humanoid :: Humanoid
				if hum.Health <= 0 then
					continue
				end

				data.playtimeSecondsSinceGem = (data.playtimeSecondsSinceGem or 0) + 60
				while data.playtimeSecondsSinceGem >= Constants.PLAYTIME_GEM_INTERVAL do
					data.playtimeSecondsSinceGem -= Constants.PLAYTIME_GEM_INTERVAL
					CurrencyService.add(player, "gems", 1, "playtime")
					Remotes.getEvent("Notification"):FireClient(player, {
						type = "success",
						message = "Playtime bonus: +1 gem!",
					})
				end
				Remotes.getEvent("DataUpdate"):FireClient(player, data)
			end
		end
	end)
end

return PlaytimeService
