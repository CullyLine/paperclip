local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local conn = { _fn = fn, Connected = true }
	function conn:Disconnect()
		conn.Connected = false
	end
	table.insert(self._listeners, conn)
	return conn
end

function Signal:Fire(...)
	for i = #self._listeners, 1, -1 do
		local c = self._listeners[i]
		if c.Connected then
			task.spawn(c._fn, ...)
		else
			table.remove(self._listeners, i)
		end
	end
end

function Signal:Once(fn: (...any) -> ())
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:DisconnectAll()
	for _, c in self._listeners do
		c.Connected = false
	end
	table.clear(self._listeners)
end

return Signal
