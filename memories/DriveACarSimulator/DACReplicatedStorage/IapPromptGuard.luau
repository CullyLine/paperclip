--!strict
--[[
	Single-flight guard for MarketplaceService purchase prompts (Game Pass + Dev Products).
	Prevents overlapping prompts and double-taps while a Roblox purchase dialog is open.
]]

local IapPromptGuard = {}

local pending = false
local timeoutThread: thread? = nil

-- Roblox purchase UI can hang; unblock UI after this if Finished never fires.
local PROMPT_TIMEOUT_SEC = 120

local subscribers: { (boolean) -> () } = {}

local function notify()
	for _, fn in subscribers do
		task.spawn(fn, pending)
	end
end

function IapPromptGuard.subscribe(cb: (boolean) -> ()): () -> ()
	table.insert(subscribers, cb)
	task.defer(cb, pending)
	return function()
		for i = #subscribers, 1, -1 do
			if subscribers[i] == cb then
				table.remove(subscribers, i)
				break
			end
		end
	end
end

function IapPromptGuard.tryBegin(): boolean
	if pending then
		return false
	end
	pending = true
	notify()
	if timeoutThread then
		task.cancel(timeoutThread)
	end
	timeoutThread = task.delay(PROMPT_TIMEOUT_SEC, function()
		timeoutThread = nil
		if pending then
			pending = false
			notify()
		end
	end)
	return true
end

function IapPromptGuard.endPrompt()
	if timeoutThread then
		task.cancel(timeoutThread)
		timeoutThread = nil
	end
	if pending then
		pending = false
		notify()
	end
end

function IapPromptGuard.isPending(): boolean
	return pending
end

return IapPromptGuard
