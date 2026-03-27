--!strict
--[[
	Client-side throttle for UI that fires RemoteEvents. Cuts accidental double-fires
	when players mash buttons; server RemoteCooldown remains authoritative.
]]

local ClientRemoteDebounce = {}

-- 350ms — within 250–500ms polish window; matches Constants.REMOTE_COOLDOWN_DEFAULT
ClientRemoteDebounce.DEFAULT_SEC = 0.35

-- Real-money Marketplace prompts (Game Pass / Dev Products): mobile double-tap guard (850ms).
-- Softer than server RemoteCooldown (2s); UX-only — server remains authoritative.
ClientRemoteDebounce.IAP_PROMPT_COOLDOWN_SEC = 0.85

function ClientRemoteDebounce.allow(lastFireRef: { number }, cooldownSec: number?): boolean
	local cd = cooldownSec or ClientRemoteDebounce.DEFAULT_SEC
	local now = os.clock()
	if now - lastFireRef[1] < cd then
		return false
	end
	lastFireRef[1] = now
	return true
end

return ClientRemoteDebounce
