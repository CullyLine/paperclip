--!strict
--[[
	Per-player remote throttle to reduce spam/exploit attempts.
]]

local Players = game:GetService("Players")

local RemoteCooldown = {}

local lastAt: { [number]: { [string]: number } } = {}

function RemoteCooldown.allow(player: Player, key: string, cooldownSeconds: number): boolean
	local uid = player.UserId
	local now = os.clock()
	local bucket = lastAt[uid]
	if not bucket then
		bucket = {}
		lastAt[uid] = bucket
	end
	local prev = bucket[key]
	if prev and now - prev < cooldownSeconds then
		return false
	end
	bucket[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastAt[player.UserId] = nil
end)

return RemoteCooldown
