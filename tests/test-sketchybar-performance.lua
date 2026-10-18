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
