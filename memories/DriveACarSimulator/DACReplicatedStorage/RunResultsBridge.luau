--!strict
--[[
	Connects StarterPlayer UIController.showRunResults to StarterGui PayoutPanel.
	Either side may load first; the last result is replayed if the handler registers late.
]]

local handler: ((any) -> ())? = nil
local pending: any = nil

local RunResultsBridge = {}

function RunResultsBridge.setHandler(fn: (any) -> ())
	handler = fn
	if pending ~= nil then
		local p = pending
		pending = nil
		fn(p)
	end
end

function RunResultsBridge.show(results: any)
	if handler then
		handler(results)
	else
		pending = results
	end
end

return RunResultsBridge
