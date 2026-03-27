--!strict
--[[
	Central gate for Remotes.Notification (server → client HUD toasts).
	POLA-492: allowlisted `type`, clamped strings, no priority/critical spoofing, per-player rate limit.
	Only the server can FireClient; this module ensures payloads stay within the HUD contract.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local NotificationDispatchService = {}

-- Keep in sync with server call sites + UIController / HudToastConfig (no streak_* from server).
local ALLOWED_TYPES: { [string]: boolean } = {
	success = true,
	error = true,
	reward_claim = true,
	info = true,
	premium_welcome = true,
}

local MAX_MESSAGE_LEN = 512
local MAX_TITLE_LEN = 96
local MAX_SUBTITLE_LEN = 160
local MAX_CODE_LEN = 48
local MAX_ITEM_ROWS = 32
local MAX_LABEL_LEN = 160
local MAX_KIND_LEN = 48

-- Fixed window: max notifications per player per window (anti-spam / exploit loops).
local RATE_WINDOW_SEC = 10
local RATE_MAX_PER_WINDOW = 96

local windowStart: { [number]: number } = {}
local windowCount: { [number]: number } = {}

local function cleanupRate(uid: number)
	windowStart[uid] = nil
	windowCount[uid] = nil
end

Players.PlayerRemoving:Connect(function(player)
	cleanupRate(player.UserId)
end)

local function allowRate(uid: number): boolean
	local now = os.clock()
	local start = windowStart[uid]
	if start == nil or now - start > RATE_WINDOW_SEC then
		windowStart[uid] = now
		windowCount[uid] = 1
		return true
	end
	local c = (windowCount[uid] or 0) + 1
	windowCount[uid] = c
	return c <= RATE_MAX_PER_WINDOW
end

local function clampStr(s: string, maxLen: number): string
	if #s <= maxLen then
		return s
	end
	return string.sub(s, 1, maxLen)
end

local function strFromUnknown(v: unknown, maxLen: number): string?
	if v == nil then
		return nil
	end
	if type(v) == "string" then
		return clampStr(v, maxLen)
	end
	return clampStr(tostring(v), maxLen)
end

local function sanitizeItems(raw: unknown): { any }?
	if type(raw) ~= "table" then
		return nil
	end
	local out: { any } = {}
	local n = 0
	for _, row in ipairs(raw :: { any }) do
		if n >= MAX_ITEM_ROWS then
			break
		end
		if type(row) == "table" then
			local r = row :: { [string]: any }
			local item: { [string]: any } = {}
			local lab = strFromUnknown(r.label, MAX_LABEL_LEN)
			if lab then
				item.label = lab
			end
			local k = strFromUnknown(r.kind, MAX_KIND_LEN)
			if k then
				item.kind = k
			end
			if type(r.amount) == "number" and r.amount == r.amount then
				item.amount = math.clamp(r.amount, -1e12, 1e12)
			end
			table.insert(out, item)
			n += 1
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

--[[
	Validate and sanitize a server-built notification table, then FireClient.
	Drops invalid types, strips spoofable keys, clamps strings. Returns true if fired.
]]
function NotificationDispatchService.notify(player: Player, raw: any): boolean
	if type(raw) ~= "table" then
		return false
	end
	local t = raw.type
	if type(t) ~= "string" or not ALLOWED_TYPES[t] then
		warn("[DAC] NotificationDispatch: invalid or disallowed type:", tostring(t))
		return false
	end
	if not allowRate(player.UserId) then
		return false
	end

	local out: { [string]: any } = {
		type = t,
	}
	if t == "reward_claim" then
		local title = strFromUnknown(raw.title, MAX_TITLE_LEN)
		if title then
			out.title = title
		end
		local subtitle = strFromUnknown(raw.subtitle, MAX_SUBTITLE_LEN)
		if subtitle then
			out.subtitle = subtitle
		end
		local items = sanitizeItems(raw.items)
		if items then
			out.items = items
		end
	end

	if t == "error" then
		local code = strFromUnknown(raw.code, MAX_CODE_LEN)
		if code then
			out.code = code
		end
	end

	local msg = strFromUnknown(raw.message, MAX_MESSAGE_LEN)
	if msg ~= nil then
		out.message = msg
	elseif t == "reward_claim" then
		out.message = ""
	else
		warn("[DAC] NotificationDispatch: missing message for type", t)
		return false
	end

	Remotes.getEvent("Notification"):FireClient(player, out)
	return true
end

function NotificationDispatchService.init()
	-- Reserved for future hooks; PlayerRemoving is connected at require time.
end

return NotificationDispatchService
