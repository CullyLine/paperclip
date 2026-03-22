--!strict
--[[
	VIP pass presentation: TextChat [VIP] prefix for senders who own the pass.
	Player attribute DAC_VipPass is set in GamePassService for nametag replication.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GamePassService = require(script.Parent:WaitForChild("GamePassService"))

local VipEffectsService = {}

function VipEffectsService.init()
	local ok = pcall(function()
		TextChatService.OnIncomingMessage = function(message: any)
			local src = message.TextSource
			if not src then
				return nil
			end
			local userId = src.UserId
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return nil
			end
			if not GamePassService.hasPass(player, "vip") then
				return nil
			end
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = "[VIP] "
			return props
		end
	end)
	-- In many Studio sessions TextChat hooks are unavailable; avoid noisy output (still safe in live).
	if not ok and not RunService:IsStudio() then
		warn("[VipEffectsService] TextChatService.OnIncomingMessage not available")
	end
end

return VipEffectsService
