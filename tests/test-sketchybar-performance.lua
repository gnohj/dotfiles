local root = "dot_config/sketchybar/"
local colors = {
	red = 0xffff0000,
	orange = 0xffff8800,
	yellow = 0xffffff00,
	shell_yellow = 0xffeeee00,
	blue = 0xff0000ff,
	cyan = 0xff00ffff,
	green = 0xff00ff00,
	magenta = 0xffff00ff,
	grey = 0xff888888,
	dark_grey = 0xff444444,
	black = 0xff000000,
	white = 0xffffffff,
	dirty_white = 0xffdddddd,
	transparent = 0,
	with_alpha = function(color)
		return color
	end,
}

local function hex(color)
	return string.format("0x%08x", color)
end

local function mock()
	local states, handlers, sets, commands, jobs = {}, {}, {}, {}, {}
	local serial = 0
	local function state(name)
		if not states[name] then
			states[name] = {
				geometry = { drawing = "on", padding_left = 0, padding_right = 0 },
				icon = { color = hex(colors.blue), padding_left = 8, padding_right = 2 },
				label = { color = hex(colors.cyan), value = "20%", drawing = "on", padding_right = 10 },
				popup = { drawing = "off" },
			}
		end
		return states[name]
	end
	local function merge(target, values)
		for key, value in pairs(values) do
			local parent, child = key:match("^([^.]+)%.(.+)$")
			if parent then
				target[parent] = target[parent] or {}
				merge(target[parent], { [child] = value })
			elseif type(value) == "table" then
				target[key] = target[key] or {}
				merge(target[key], value)
			else
				target[key] = type(value) == "boolean" and (value and "on" or "off") or value
			end
		end
	end
	local api = {}
	function api.set(name, values)
		sets[#sets + 1] = { name = name, values = values }
		local item = state(name)
		merge(item, values)
		if values.drawing then
			item.geometry.drawing = values.drawing
		end
	end
	function api.query(name)
		return state(name)
	end
	function api.add(kind, name, options)
		if kind == "event" then
			return
		end
		if type(name) == "table" then
			options, name = name, nil
		end
		serial = serial + 1
		name = name or "item_" .. serial
		if kind ~= "bracket" then
			merge(state(name), options or {})
		end
		local item = { name = name }
		function item:set(values)
			api.set(self.name, values)
		end
		function item:subscribe(events, callback)
			if type(events) == "string" then
				events = { events }
			end
			for _, event in ipairs(events) do
				handlers[event] = handlers[event] or {}
				handlers[event][self.name] = callback
			end
		end
		return item
	end
	function api.exec(command, callback)
		commands[#commands + 1] = command
		if callback then
			jobs[#jobs + 1] = { command = command, callback = callback }
		end
	end
	local m = { api = api, sets = sets, commands = commands, states = states, state = state }
	function m.emit(event, name, env)
		for owner, callback in pairs(handlers[event] or {}) do
			if not name or name == owner then
				callback(env or {})
			end
		end
	end
	function m.finish(suffix, value)
		for i, job in ipairs(jobs) do
			if job.command:sub(-#suffix) == suffix then
				table.remove(jobs, i)
				job.callback(value or "")
				return
			end
		end
		error("Missing pending command: " .. suffix)
	end
	function m.count(suffix)
		local count = 0
		for _, command in ipairs(commands) do
			if command:sub(-#suffix) == suffix then
				count = count + 1
			end
		end
		return count
	end
	return m
end

package.loaded["config.colors"] = colors
local m = mock()
sbar = m.api
local groups = dofile(root .. "items/widgets/groups.lua")
for _, name in ipairs({ "system", "vps" }) do
	groups.edge(name, 0)
	groups.toggle(name)
	groups.uptime(name, "widgets." .. name .. "_uptime")
	groups.glyph(name, "os", colors.blue)
	groups.edge(name, 12)
end
groups.build()
local before = #m.sets
groups.changed()
print("Unchanged group refresh writes: " .. (#m.sets - before))
assert(#m.sets == before, "Unchanged refresh must not write properties")
m.emit("routine")
assert(#m.sets == before, "Unchanged timer must not write properties")
m.state("widgets.memory").label.value = "21%"
groups.changed()
assert(#m.sets == before, "Metric value changes alone must not rewrite group layout")

m.state("widgets.disk").label.color = hex(colors.red)
groups.changed()
assert(m.state("widgets.disk").geometry.drawing == "on", "Hidden alert must become visible")
assert(m.state("widgets.cpu").geometry.drawing == "off", "Idle CPU must make room for disk")
assert(m.state("widgets.group.system").background.border_color == hex(colors.red), "Border must show hidden alert")
before = #m.sets
groups.changed()
assert(#m.sets == before, "Stable alert must not write properties")

m.state("widgets.disk").label.color = hex(colors.cyan)
groups.changed()
assert(m.state("widgets.disk").geometry.drawing == "off", "Cleared disk must hide")
assert(m.state("widgets.cpu").geometry.drawing == "on", "CPU must return after alert clears")
m.emit("group_toggle_system")
assert(m.state("widgets.disk").geometry.drawing == "on", "Expand must show disk")
m.emit("group_toggle_system")
assert(m.state("widgets.disk").geometry.drawing == "off", "Collapse must hide idle disk")

m.state("widgets.memory").label.padding_right = 22
groups.changed()
assert(m.state("widgets.system_uptime").padding_left == -14, "Metric spacing changes must reach uptime")
m.state("widgets.system_uptime").label.padding_right = 4
groups.changed()
assert(m.state("widgets.group_edge.1").width == 6, "Trailing spacing changes must reach closing edge")
groups.show("system", false)
groups.changed()
assert(m.state("widgets.memory").geometry.drawing == "on", "Show and collapse must share drawing state")
before = #m.sets
groups.changed()
assert(#m.sets == before, "Restored layout must stop writing")
print("Group redraw tests passed")

m = mock()
sbar = m.api
package.loaded["constants"] = { items = { WIFI = "widgets.wifi" } }
package.loaded["config.settings"] = {
	dimens = { padding = { icon = 8, gap = 6 }, text = { label = 14 } },
	colors = colors,
	fonts = { styles = { bold = "Bold" } },
	icons = {
		text = {
			wifi = { connected = "wifi", disconnected = "off", router = "router", vpn = "vpn", hotspot = "hotspot" },
			switch = { on = "on", off = "off" },
		},
	},
}
local builds = 0
package.loaded["lib.popup"] = {
	close_label = function()
		return {}
	end,
	close_script = function()
		return "close"
	end,
	ellipsize = function(text)
		return text
	end,
	close_others = function() end,
	query = function(item, callback)
		callback(m.state(item.name).popup.drawing == "on")
	end,
	toggle = function(item, onOpen)
		if m.state(item.name).popup.drawing == "on" then
			item:set({ popup = { drawing = false } })
		else
			onOpen()
		end
	end,
	build = function(parent, _, _, open)
		builds = builds + 1
		if open then
			m.api.set(parent, { popup = { drawing = true } })
		end
	end,
}
dofile(root .. "items/widgets/wifi.lua")
for _, event in ipairs({ "routine", "forced", "system_woke", "wifi_change" }) do
	m.emit(event, "widgets.wifi")
end
assert(m.count(" sample") == 0, "Hidden popup must never sample diagnostics")
m.emit("wifi_refresh", "widgets.wifi")
assert(m.count(" list") == 0, "Hidden popup must not rebuild on action notifications")

m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "left" })
assert(m.count(" sample") == 1, "Opening popup must request one cached sample")
m.finish(" list", "power\ton\tHome\nstat\tPing\told\n")
assert(m.state("widgets.wifi").popup.drawing == "on", "Cached popup must open before diagnostics finish")
m.finish(" sample")
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
assert(builds == 2, "Finished sample must update the visible popup")
m.emit("routine", "widgets.wifi")
assert(m.count(" sample") == 1, "Routine refresh must not sample diagnostics")

m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "left" })
m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "left" })
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "left" })
local listed = m.count(" list")
m.finish(" sample")
assert(m.count(" list") == listed, "Sample finishing after close must not rebuild or reopen popup")
assert(m.state("widgets.wifi").popup.drawing == "off", "Late sample must leave popup closed")

local sampled = m.count(" sample")
m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "right" })
assert(m.count(" sample") == sampled, "Opening system settings must not sample diagnostics")
m.emit("mouse.clicked", "widgets.wifi", { BUTTON = "left" })
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
m.finish(" sample")
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
local previousBuilds = builds
m.emit("wifi_refresh", "widgets.wifi")
assert(m.count(" sample") == sampled + 2, "Visible action notifications must request cached diagnostics")
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
m.finish(" sample")
m.finish(" list", "power\ton\tHome\nstat\tPing\tfresh\n")
assert(builds == previousBuilds, "Byte-identical popup rows must not rebuild")
print("Wi-Fi demand-driven tests passed")

m = mock()
sbar = m.api
dofile(root .. "items/widgets/wifi.lua")
local vpnCommand = [[sleep 2; scutil --nwi | grep -m1 'utun' | awk '{ print $1 }']]
local function finishIcon(ip, vpn)
	m.finish("ipconfig getifaddr en0", ip)
	m.finish(vpnCommand, vpn)
end
m.emit("routine", "widgets.wifi")
finishIcon("192.168.1.10\n", "utun4\n")
assert(m.state("widgets.wifi").icon.string == "vpn", "VPN must keep priority over Wi-Fi")
before = #m.sets
for _ = 1, 10 do
	m.emit("routine", "widgets.wifi")
	finishIcon("192.168.1.10\n", "utun4\n")
end
print("Unchanged Wi-Fi refresh writes (10 polls): " .. (#m.sets - before))
assert(#m.sets == before, "Unchanged Wi-Fi state must not rewrite the icon")

for _, case in ipairs({
	{ ip = "192.168.1.10\n", vpn = "", icon = "wifi", color = colors.blue },
	{ ip = "172.20.10.2\n", vpn = "", icon = "hotspot", color = colors.yellow },
	{ ip = "", vpn = "", icon = "off", color = colors.red },
	{ ip = "", vpn = "utun4\n", icon = "vpn", color = colors.blue },
}) do
	before = #m.sets
	m.emit("wifi_change", "widgets.wifi")
	assert(#m.sets == before, "Refresh must not flash a disconnected icon")
	m.finish("ipconfig getifaddr en0", case.ip)
	assert(#m.sets == before, "Refresh must wait for the VPN result before painting")
	m.finish(vpnCommand, case.vpn)
	assert(#m.sets == before + 1, "A changed network state must paint once")
	assert(m.state("widgets.wifi").icon.string == case.icon, "Wrong network icon")
	assert(m.state("widgets.wifi").icon.color == case.color, "Wrong network colour")
end

local probes = m.count("ipconfig getifaddr en0")
before = #m.sets
for _, event in ipairs({ "routine", "wifi_change", "system_woke", "forced" }) do
	m.emit(event, "widgets.wifi")
end
assert(m.count("ipconfig getifaddr en0") == probes + 1, "Overlapping refreshes must share the active probe")
finishIcon("", "")
assert(#m.sets == before, "A superseded sample must not paint")
assert(m.count("ipconfig getifaddr en0") == probes + 2, "A burst must request one follow-up sample")
finishIcon("192.168.1.10\n", "")
assert(m.state("widgets.wifi").icon.string == "wifi", "Follow-up sample must show the latest state")
assert(#m.sets == before + 1, "A refresh burst must paint once")
m.emit("routine", "widgets.wifi")
finishIcon("192.168.1.10\n", "")
assert(#m.sets == before + 1, "Sampling must recover after a refresh burst")
print("Wi-Fi icon redraw and overlapping refresh tests passed")

local function workspaceMock(debugLogging, reachable)
	local wm = mock()
	sbar = wm.api
	package.loaded["constants"] = {
		items = { FRONT_APPS = "front_apps", SPACES = "spaces" },
		events = {
			RIFT_WORKSPACE_CHANGED = "workspace_changed",
			FRONT_APP_SWITCHED = "front_app_switched",
			UPDATE_WINDOWS = "update_windows",
			SWAP_MENU_AND_SPACES = "swap_menu",
		},
	}
	package.loaded["items.rift_layout"] = true
	package.loaded["cjson"] = {
		decode = function()
			return { { ["app-name"] = "Ghostty" } }
		end,
	}
	package.loaded["lib.rift"] = {
		new = function()
			assert(reachable, "Rift unavailable")
			return {
				is_initialized = function()
					return true
				end,
				list_current = function()
					return "T"
				end,
				list_all_windows = function()
					return { { workspace = "T", ["window-id"] = 1, ["app-name"] = "Ghostty" } }
				end,
				focused_window = function()
					return "focused"
				end,
			}
		end,
		focus_command = function()
			return "focus"
		end,
	}
	local getenv = os.getenv
	os.getenv = function(name)
		if name == "SKETCHYBAR_WORKSPACE_DEBUG" then
			return debugLogging and "1" or nil
		end
		return getenv(name)
	end
	local ok, err = pcall(dofile, root .. "items/workspace.lua")
	os.getenv = getenv
	assert(ok, err)
	return wm
end

local wm = workspaceMock(false, true)
before = #wm.commands
for _ = 1, 10 do
	wm.emit("workspace_changed", nil, { FOCUSED_WORKSPACE = "T" })
	wm.emit("front_app_switched", nil, { INFO = "Ghostty" })
end
print("Routine workspace logging commands (20 events): " .. (#wm.commands - before))
assert(#wm.commands == before, "Routine workspace events must not launch logging shells")
assert(wm.state("spaces").label.string == "T", "Workspace rendering must remain intact")
assert(wm.state("front_apps.1").label.string == "Ghostty", "App rendering must remain intact")

wm = workspaceMock(true, true)
before = #wm.commands
wm.emit("workspace_changed", nil, { FOCUSED_WORKSPACE = "T" })
assert(#wm.commands > before, "Opt-in workspace diagnostics must retain detailed logs")

wm = workspaceMock(false, false)
local warning, failure = false, false
for _, command in ipairs(wm.commands) do
	warning = warning or command:find("[WARN]", 1, true)
	failure = failure or command:find("[ERROR]", 1, true)
end
assert(warning and failure, "Workspace warnings and errors must remain enabled")
assert(wm.count("sleep 5 && sketchybar --trigger workspace_retry_init") == 1, "Rift retry must remain enabled")
print("Workspace logging tests passed")
