--!strict
--[[
	Fail-soft helpers for RemoteFunction / RemoteEvent handlers (Phase 4 polish — POLA-353).
	Wraps InvokeServer with pcall, surfaces one friendly toast via Microcopy + UIController,
	and logs each remote name at most once per session to avoid spam.

	- `invokeGetPlayerData`: idempotent read — one automatic retry (short backoff), never double-charges.
	- `fireEvent`: pcall around FireServer; mutations are never auto-retried (Robux / coins safety).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local RemoteFailSafe = {}

local warnedOnce: { [string]: boolean } = {}

local RETRY_BACKOFF_SEC = 0.6
local CACHE_TTL = 2.0

local _cachedPlayerData: any? = nil
local _cachedPlayerDataClock: number = 0
local _dataReceivedOnce = false

local function getUIController(): any?
	local lp = Players.LocalPlayer
	if not lp then
		return nil
	end
	local ps = lp:FindFirstChild("PlayerScripts")
	if not ps then
		return nil
	end
	local dac = ps:FindFirstChild("DAC")
	if not dac then
		return nil
	end
	local ctrls = dac:FindFirstChild("Controllers")
	if not ctrls then
		return nil
	end
	local mod = ctrls:FindFirstChild("UIController")
	if not mod then
		return nil
	end
	local ok, r = pcall(require, mod :: ModuleScript)
	if ok then
		return r
	end
	return nil
end

function RemoteFailSafe.invokeFunction(name: string, ...: any): (boolean, any)
	local fn = Remotes.getFunction(name)
	local packed = table.pack(...)
	return pcall(function()
		return fn:InvokeServer(table.unpack(packed, 1, packed.n))
	end)
end

--[[
	Idempotent read of full player snapshot. One retry on throw or non-table (POLA-353).
	Serves a cached snapshot (TTL-gated) when multiple panels request data in the same
	window, preventing rate-limit cascades. Does not retry arbitrary RemoteFunctions —
	use `invokeFunction` for those.
]]
function RemoteFailSafe.invokeGetPlayerData(): (boolean, any?)
	local now = os.clock()
	if _cachedPlayerData and (now - _cachedPlayerDataClock) < CACHE_TTL then
		return true, _cachedPlayerData
	end

	local fn = Remotes.getFunction("GetPlayerData")
	local function once(): (boolean, any)
		return pcall(function()
			return fn:InvokeServer()
		end)
	end
	local ok, res = once()
	if ok and type(res) == "table" then
		_cachedPlayerData = res
		_cachedPlayerDataClock = os.clock()
		return true, res
	end
	task.wait(RETRY_BACKOFF_SEC)
	local lpAfterWait = Players.LocalPlayer
	if not lpAfterWait or not lpAfterWait.Parent then
		return false, nil
	end
	if _cachedPlayerData and (os.clock() - _cachedPlayerDataClock) < CACHE_TTL then
		return true, _cachedPlayerData
	end
	ok, res = once()
	if ok and type(res) == "table" then
		_cachedPlayerData = res
		_cachedPlayerDataClock = os.clock()
		return true, res
	end
	if _dataReceivedOnce then
		RemoteFailSafe.notifyRemoteFailure("GetPlayerData", if ok then "empty_or_invalid" else res, "DATA")
	end
	return false, nil
end

function RemoteFailSafe.setPlayerDataCache(data: any)
	if type(data) == "table" then
		_cachedPlayerData = data
		_cachedPlayerDataClock = os.clock()
		_dataReceivedOnce = true
	else
		_cachedPlayerData = nil
		_cachedPlayerDataClock = 0
	end
end

function RemoteFailSafe.notifyRemoteFailure(remoteLabel: string, err: any?, shortCode: string?)
	if not warnedOnce[remoteLabel] then
		warnedOnce[remoteLabel] = true
		warn(`[DAC] Remote failed ({remoteLabel})`, err)
	end
	local uc = getUIController()
	if uc then
		local msg = MicrocopyConfig.pickVariant(MicrocopyConfig.RemoteLoadError)
		if type(shortCode) == "string" and shortCode ~= "" then
			msg = `{msg} [{shortCode}]`
		end
		if type(uc.showToast) == "function" then
			(uc :: any).showToast({ type = "error", message = msg, priority = "critical" })
		elseif type(uc.showNotification) == "function" then
			uc.showNotification({ type = "error", message = msg })
		end
	end
end

--[[
	RemoteEvent:FireServer from client — pcall only (server errors are not replicated; this catches client throws).
	Returns false on failure (toast shown). Never auto-retries (purchase / mutation safety).
]]
function RemoteFailSafe.fireEvent(remoteLabel: string, eventName: string, ...: any): boolean
	local ev = Remotes.getEvent(eventName)
	local packed = table.pack(...)
	local ok, err = pcall(function()
		ev:FireServer(table.unpack(packed, 1, packed.n))
	end)
	if not ok then
		RemoteFailSafe.notifyRemoteFailure(`{remoteLabel}:{eventName}`, err, remoteLabel)
		return false
	end
	return true
end

function RemoteFailSafe.safeNotifyOnError(remoteLabel: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		RemoteFailSafe.notifyRemoteFailure(remoteLabel, err)
	end
end

return RemoteFailSafe
