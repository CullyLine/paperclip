--!strict
--[[
	Peer-to-peer pet trading between players.
	Placeholder for M5 — will be expanded with full trade UI and validation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local TradeService = {}

function TradeService.init()
	-- TODO: Implement trade request/response flow in M5
	Remotes.getEvent("TradeRequest").OnServerEvent:Connect(function(player, _targetUserId)
		Remotes.getEvent("Notification"):FireClient(player, {
			type = "info",
			message = "Trading coming soon!",
		})
	end)
end

return TradeService
