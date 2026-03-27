--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local EconomyLogService = require(script.Parent:WaitForChild("EconomyLogService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local Constants = require(DAC:WaitForChild("Constants"))

local CodeService = {}

--[[
	Sliding-window attempt log per player (monotonic time) — hard cap per minute.
	Independent of RemoteCooldown / checkRemoteRate (defense in depth).
]]
local redeemAttemptTimes: { [number]: { number } } = {}

local function trimWhitespace(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function pruneAttemptWindow(uid: number, now: number)
	local list = redeemAttemptTimes[uid]
	if not list then
		return
	end
	local window = Constants.CODE_REDEEM_WINDOW_SEC
	local i = 1
	while i <= #list do
		if now - list[i] > window then
			table.remove(list, i)
		else
			i += 1
		end
	end
end

local function allowRedeemAttempt(player: Player): boolean
	local uid = player.UserId
	local now = os.clock()
	local list = redeemAttemptTimes[uid]
	if not list then
		list = {}
		redeemAttemptTimes[uid] = list
	end
	pruneAttemptWindow(uid, now)
	if #list >= Constants.CODE_REDEEM_MAX_ATTEMPTS_PER_MINUTE then
		return false
	end
	table.insert(list, now)
	return true
end

local function isValidCodeShape(trimmed: string): boolean
	local n = #trimmed
	if n < Constants.CODE_REDEEM_MIN_LEN or n > Constants.CODE_REDEEM_MAX_LEN then
		return false
	end
	return string.match(trimmed, "^[%a%d]+$") ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	redeemAttemptTimes[player.UserId] = nil
end)

-- Add new codes here. Expired codes stay in the table with active = false.
local CODES: { [string]: { active: boolean, rewards: { { currency: string, amount: number } } } } = {
	LAUNCH = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 10_000 },
		},
	},
	STYLXUS90K = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 15_000 },
		},
	},
	SPEED = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 2_500 },
		},
	},
	DRIVEFAST = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 5_000 },
		},
	},
	PETPOWER = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 5_000 },
		},
	},
	REBIRTH1 = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 10_000 },
		},
	},
	NEONHYPE = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 20_000 },
		},
	},
	DESERT2X = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 10_000 },
		},
	},
	THANKYOU = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 15_000 },
		},
	},
	UPDATE1 = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 12_000 },
		},
	},
}

function CodeService.redeem(player: Player, code: string): (boolean, string?)
	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local upperCode = string.upper(code)
	local codeDef = CODES[upperCode]

	if not codeDef then
		return false, "Invalid code"
	end

	if not codeDef.active then
		return false, "This code has expired"
	end

	if data.redeemedCodes[upperCode] then
		return false, "Already redeemed"
	end

	data.redeemedCodes[upperCode] = true

	EconomyLogService.logCodeRedeem(player, upperCode)

	local messages = {}
	for _, reward in codeDef.rewards do
		CurrencyService.add(player, reward.currency, reward.amount, "code_redemption")
		table.insert(messages, `+{reward.amount} {reward.currency}`)
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	NotificationDispatchService.notify(player, {
		type = "success",
		message = "Code redeemed! " .. table.concat(messages, ", "),
	})

	return true, nil
end

function CodeService.init()
	Remotes.getEvent("RedeemCode").OnServerEvent:Connect(function(player, code)
		if type(code) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "redeem_code_bad_type", "")
			return
		end
		if not allowRedeemAttempt(player) then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = "Too many code attempts. Wait before trying again.",
			})
			return
		end

		local trimmed = trimWhitespace(code)
		if trimmed == "" or not isValidCodeShape(trimmed) then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = "Invalid code format.",
			})
			return
		end

		if not ValidationService.checkRemoteRate(player, "RedeemCode") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "RedeemCode", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end

		local success, err = CodeService.redeem(player, trimmed)
		if not success then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err or "Code redemption failed",
			})
		end
	end)
end

return CodeService
