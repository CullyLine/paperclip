--!strict
--[[
	Peer-to-peer pet trading (planned M5).

	STUB / NO-OP (POLA-525): Trading is not implemented. These remotes never:
	- transfer pets, eggs, currency, or any inventory between players
	- grant anything based on client-supplied payloads

	TradeRequest: validation + rate limit + optional "coming soon" info when allowed.
	TradeRespond: server handler is wired and explicitly no-ops (audit log only); prevents
	a future client from assuming an unsecured remote grants items without server code here.

	When real trading ships: validate both parties server-side, item ownership, session state,
	and cooldowns; never trust the client for transfers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local TradeService = {}

local function tradeRequestsEnabled(player: Player): boolean
	local data = DataManager.get(player)
	if not data or type(data.settings) ~= "table" then
		return true
	end
	local tr = data.settings.tradeRequests
	if type(tr) == "boolean" then
		return tr
	end
	return true
end

local function validateTargetUserId(player: Player, targetUserId: unknown): boolean
	if targetUserId == nil then
		ValidationService.logAnomalyOncePerSession(player, "trade_request_nil_target", "")
		return false
	end
	if type(targetUserId) ~= "number" then
		ValidationService.logAnomalyOncePerSession(player, "trade_bad_target_type", "")
		return false
	end
	local n = targetUserId :: number
	if n ~= math.floor(n) or n < 1 then
		ValidationService.logAnomalyOncePerSession(player, "trade_bad_target_range", "")
		return false
	end
	if n == player.UserId then
		ValidationService.logAnomalyOncePerSession(player, "trade_self_target", "")
		return false
	end
	return true
end

function TradeService.init()
	Remotes.getEvent("TradeRequest").OnServerEvent:Connect(function(player, targetUserId)
		if not ValidationService.checkRemoteRate(player, "TradeRequest") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not tradeRequestsEnabled(player) then
			return
		end
		if not validateTargetUserId(player, targetUserId) then
			return
		end
		NotificationDispatchService.notify(player, {
			type = "info",
			message = "Trading coming soon!",
		})
	end)

	-- Stub: acknowledge remote exists; do not interpret payloads as authoritative for any grant.
	Remotes.getEvent("TradeRespond").OnServerEvent:Connect(function(player, _payload: unknown)
		if not ValidationService.checkRemoteRate(player, "TradeRespond") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not tradeRequestsEnabled(player) then
			return
		end
		ValidationService.logAnomalyOncePerSession(player, "trade_respond_stub_noop", "")
	end)
end

return TradeService
