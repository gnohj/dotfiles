--- aerospace module for sending commands to the AeroSpace window manager server
-- @module Aerospace
-- @copyright 2025
-- @license MIT
-- Modified from https://github.com/acsandmann/AeroSpaceLua
-- Changes: Removed simdjson dependency, using cjson only
-- Updated for AeroSpace 0.21.0-Beta: version handshake + 4-byte length-prefixed framing

local socket               = require("posix.sys.socket")
local unistd               = require("posix.unistd")
local poll                 = require("posix.poll")
local cjson                = require("cjson")

local DEFAULT              = {
	SOCK_FMT         = "/tmp/bobko.aerospace-%s.sock",
	TIMEOUT          = 500,  -- milliseconds per poll call
	PROTOCOL_VERSION = 1,
}
local ERR                  = {
	SOCKET   = "socket error",
	NOT_INIT = "socket not connected",
	JSON     = "failed to decode JSON",
	TIMEOUT  = "socket read timeout",
	PROTO    = "protocol version mismatch",
}

local AF_UNIX, SOCK_STREAM = socket.AF_UNIX, socket.SOCK_STREAM
local write, read, close   = unistd.write, unistd.read, unistd.close
local encode               = cjson.encode
local decode               = cjson.decode

local function pack_uint32_le(n)
	return string.char(n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF)
end

local function unpack_uint32_le(s)
	local b1, b2, b3, b4 = string.byte(s, 1, 4)
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

-- Read exactly n bytes, polling before each chunk to avoid blocking.
local function read_exactly(fd, n)
	local parts = {}
	local got = 0
	while got < n do
		local fds = { [fd] = { events = { IN = true } } }
		local ready = poll.poll(fds, DEFAULT.TIMEOUT)
		if ready == 0 then error(ERR.TIMEOUT) end
		local chunk = read(fd, n - got)
		if not chunk or chunk == "" then error("disconnected") end
		parts[#parts + 1] = chunk
		got = got + #chunk
	end
	return table.concat(parts)
end

local function connect(path)
	local fd, err = socket.socket(AF_UNIX, SOCK_STREAM, 0)
	if not fd then error(ERR.SOCKET .. ": " .. tostring(err)) end
	if socket.connect(fd, { family = AF_UNIX, path = path }) ~= 0 then
		close(fd); error("cannot connect to " .. path)
	end
	-- Version handshake: send client version, read server version
	write(fd, pack_uint32_le(DEFAULT.PROTOCOL_VERSION))
	local server_ver = unpack_uint32_le(read_exactly(fd, 4))
	if server_ver ~= DEFAULT.PROTOCOL_VERSION then
		close(fd)
		error(ERR.PROTO .. ": client=" .. DEFAULT.PROTOCOL_VERSION .. " server=" .. server_ver)
	end
	return fd
end

local function stdout(raw)
	local ok, doc = pcall(decode, raw)
	if not ok then error(ERR.JSON .. ": " .. tostring(doc)) end
	return doc.stdout or ""
end

local Aerospace = {}; Aerospace.__index = Aerospace

function Aerospace.new(path)
	if not path then
		local username = os.getenv("USER")
		path = DEFAULT.SOCK_FMT:format(username)
	end

	return setmetatable({ sockPath = path, fd = connect(path) }, Aerospace)
end

function Aerospace:close()
	if self.fd then
		close(self.fd); self.fd = nil
	end
end

Aerospace.__gc = Aerospace.close

function Aerospace:reconnect()
	self:close(); self.fd = connect(self.sockPath)
end

function Aerospace:is_initialized() return self.fd ~= nil end

function Aerospace:_query(args, want_json)
	if not self:is_initialized() then error(ERR.NOT_INIT) end
	local payload = encode({ command = "", args = args, stdin = "" })

	local function attempt()
		-- Send 4-byte little-endian length prefix followed by JSON payload
		write(self.fd, pack_uint32_le(#payload) .. payload)
		-- Read 4-byte length prefix, then the response body
		local resp_len = unpack_uint32_le(read_exactly(self.fd, 4))
		local raw = read_exactly(self.fd, resp_len)
		local out = stdout(raw)
		return want_json and decode(out) or out
	end

	local ok, result = pcall(attempt)
	if ok then return result end
	-- attempt failed; reconnect and retry once
	local rk = pcall(function() self:reconnect() end)
	if rk and self:is_initialized() then
		return attempt()
	end
	error(result)
end

local function passthrough(self, argtbl, json, cb)
	local res = self:_query(argtbl, json)
	return cb and cb(res) or res
end

function Aerospace:list_apps(cb)
	return passthrough(self, { "list-apps", "--json" }, true, cb)
end

function Aerospace:query_workspaces(cb)
	return passthrough(self, {
		"list-workspaces", "--all",
		"--format", "%{workspace-is-focused}%{workspace-is-visible}%{workspace}%{monitor-appkit-nsscreen-screens-id}",
		"--json" }, true, cb)
end

function Aerospace:list_current(cb)
	return passthrough(self, { "list-workspaces", "--focused" }, false, cb)
end

function Aerospace:list_windows(space, cb)
	return passthrough(self, { "list-windows", "--workspace", space, "--json" }, false, cb)
end

function Aerospace:focused_window(cb)
	return passthrough(self, { "list-windows", "--focused", "--json" }, false, cb)
end

function Aerospace:workspace(ws)
	return self:_query({ "workspace", ws }, false)
end

function Aerospace:list_all_windows(cb)
	return passthrough(self, {
		"list-windows", "--all", "--json",
		"--format", "%{window-id}%{app-name}%{window-title}%{workspace}" }, true, cb)
end

return Aerospace
