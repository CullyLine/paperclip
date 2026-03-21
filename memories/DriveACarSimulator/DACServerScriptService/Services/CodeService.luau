--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local Constants = require(DAC:WaitForChild("Constants"))

local CodeService = {}

-- Add new codes here. Expired codes stay in the table with active = false.
local CODES: { [string]: { active: boolean, rewards: { { currency: string, amount: number } } } } = {
	LAUNCH = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 5_000 },
			{ currency = "gems", amount = 100 },
		},
	},
	STYLXUS90K = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 10_000 },
			{ currency = "crystals", amount = 50 },
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
			{ currency = "coins", amount = 3_000 },
			{ currency = "gems", amount = 50 },
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
			{ currency = "crystals", amount = 200 },
		},
	},
	DESERT2X = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 5_000 },
			{ currency = "gems", amount = 100 },
		},
	},
	THANKYOU = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 7_500 },
			{ currency = "gems", amount = 75 },
			{ currency = "crystals", amount = 25 },
		},
	},
	UPDATE1 = {
		active = true,
		rewards = {
			{ currency = "coins", amount = 8_000 },
			{ currency = "gems", amount = 150 },
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

	local messages = {}
	for _, reward in codeDef.rewards do
		CurrencyService.add(player, reward.currency, reward.amount, "code_redemption")
		table.insert(messages, `+{reward.amount} {reward.currency}`)
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	Remotes.getEvent("Notification"):FireClient(player, {
		type = "success",
		message = "Code redeemed! " .. table.concat(messages, ", "),
	})

	return true, nil
end

function CodeService.init()
	Remotes.getEvent("RedeemCode").OnServerEvent:Connect(function(player, code)
		if type(code) ~= "string" then return end
		if not ValidationService.checkRemoteRate(player, "RedeemCode") then
			return
		end
		if not RemoteCooldown.allow(player, "RedeemCode", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = CodeService.redeem(player, code)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Code redemption failed",
			})
		end
	end)
end

return CodeService
