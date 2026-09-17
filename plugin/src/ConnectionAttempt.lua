--[[
	The outcome of one attempt to connect to a Rojo server, handed to whoever
	asked for the session so they can wait for it and read why it ended.
]]

local strict = require(script.Parent.strict)

local Status = strict("ConnectionAttempt.Status", {
	Connecting = "Connecting",
	Connected = "Connected",
	Refused = "Refused",
	Failed = "Failed",
})

local Reason = strict("ConnectionAttempt.Reason", {
	SessionAlreadyRunning = "SessionAlreadyRunning",
	SyncLockHeld = "SyncLockHeld",
	SessionEnded = "SessionEnded",
	ServerError = "ServerError",
	RateLimited = "RateLimited",
})

local ConnectionAttempt = {}
ConnectionAttempt.__index = ConnectionAttempt

ConnectionAttempt.Status = Status
ConnectionAttempt.Reason = Reason

function ConnectionAttempt.new()
	return setmetatable({
		_status = Status.Connecting,
		_reason = nil,
		_message = nil,
		_address = nil,
		_projectName = nil,
		_threads = {},
	}, ConnectionAttempt)
end

function ConnectionAttempt:getStatus(): string
	return self._status
end

--[[
	Why the attempt did not connect, from ConnectionAttempt.Reason, and the
	message Rojo would have shown the user. Both nil while connecting or once
	connected.
]]
function ConnectionAttempt:getReason(): (string?, string?)
	return self._reason, self._message
end

--[[
	The host:port and project name of the session, once there is one.
]]
function ConnectionAttempt:getSession(): (string?, string?)
	return self._address, self._projectName
end

--[[
	Yields until the attempt is no longer connecting, then reports whether it
	connected. Returns immediately for an attempt that already settled.
]]
function ConnectionAttempt:await(): (boolean, string?)
	if self._status == Status.Connecting then
		table.insert(self._threads, coroutine.running())
		coroutine.yield()
	end

	return self._status == Status.Connected, self._message
end

function ConnectionAttempt:_settle(status: string, reason: string?, message: string?)
	if self._status ~= Status.Connecting then
		return
	end

	self._status = status
	self._reason = reason
	self._message = message

	local threads = self._threads
	self._threads = {}
	for _, thread in threads do
		task.spawn(thread)
	end
end

function ConnectionAttempt:_setSession(address: string, projectName: string)
	self._address = address
	self._projectName = projectName
end

export type ConnectionAttempt = typeof(ConnectionAttempt.new())

return ConnectionAttempt
