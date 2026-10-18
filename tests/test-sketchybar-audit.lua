local root = "dot_config/sketchybar/"
local failures = 0
local colors = {
	blue = 1,
	cyan = 2,
	red = 3,
	yellow = 4,
	orange = 5,
	grey = 6,
	dark_grey = 7,
	transparent = 0,
	green = 8,
	magenta = 9,
	with_alpha = function(color)
		return color
	end,
}
local items = {
	CALENDAR = "calendar",
	CPU = "cpu",
	MEMORY = "memory",
	DISK = "disk",
	CPU_TEMP = "temp",
	BLUETOOTH = "bluetooth",
	VOLUME = "volume",
	SPOTIFY = "spotify",
	RIFT_LAYOUT = "layout",
}

local function merge(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = target[key] or {}
			merge(target[key], value)
		else
			target[key] = value
		end
	end
end

local function mock()
	local m = { states = {}, sets = {}, commands = {}, jobs = {}, handlers = {}, groupChanges = 0 }
	local serial = 0
	local api = {}
	function api.add(kind, name, options, extra)
		if kind == "event" then
			return
		end
		if type(name) == "table" then
			options, name = name, nil
		end
		serial = serial + 1
		name = name or "anonymous" .. serial
		m.states[name] = extra or options or {}
		local item = { name = name }
		function item:set(values)
			m.sets[#m.sets + 1] = { name = name, values = values }
			merge(m.states[name], values)
		end
		function item:subscribe(events, callback)
			if type(events) == "string" then
				events = { events }
			end
			for _, event in ipairs(events) do
				m.handlers[event] = m.handlers[event] or {}
				m.handlers[event][name] = callback
			end
		end
		return item
	end
	function api.exec(command, callback)
		m.commands[#m.commands + 1] = command
		if callback then
			m.jobs[#m.jobs + 1] = { command = command, callback = callback }
		end
	end
	function m.emit(event, name, env)
		for owner, callback in pairs(m.handlers[event] or {}) do
			if not name or owner == name then
				callback(env or {})
			end
		end
	end
	function m.finish(fragment, output)
		for i, job in ipairs(m.jobs) do
			if job.command:find(fragment, 1, true) then
				table.remove(m.jobs, i)
				job.callback(output, 0)
				return
			end
		end
		error("Missing callback: " .. fragment)
	end
	function m.count(fragment)
		local count = 0
		for _, command in ipairs(m.commands) do
			if command:find(fragment, 1, true) then
				count = count + 1
			end
		end
		return count
	end
	sbar = api
	package.loaded["constants"] = {
		items = items,
		events = {
			RIFT_LAYOUT_CHANGED = "layout_changed",
			RIFT_WORKSPACE_CHANGED = "workspace_changed",
			SWAP_MENU_AND_SPACES = "swap_menu",
		},
	}
	package.loaded["cjson"] = {
		decode = function()
			error("Invalid JSON")
		end,
	}
	package.loaded["config.colors"] = colors
	package.loaded["config.dimens"] = { padding = { gap = 6 } }
	package.loaded["config.settings"] = {
		colors = colors,
		dimens = { padding = { gap = 6 }, graphics = { popup = { width = 200, large_width = 320 } } },
		fonts = { styles = { bold = "Bold" } },
		icons = {
			text = {
				volume = { _100 = "loud", _66 = "medium", _33 = "low", _10 = "quiet", _0 = "mute" },
				switch = { on = "on", off = "off" },
				bluetooth = { on = "bt", off = "off", connected = "connected" },
			},
		},
	}
	package.loaded["items.widgets.groups"] = {
		changed = function()
			m.groupChanges = m.groupChanges + 1
		end,
	}
	package.loaded["lib.tiers"] = dofile(root .. "lib/tiers.lua")
	package.loaded["lib.popup"] = {
		close_label = function()
			return {}
		end,
		close_script = function()
			return "close"
		end,
	}
	return m
end

local function test(name, fn)
	local date, open = os.date, io.open
	local ok, err = pcall(fn)
	os.date, io.open = date, open
	if not ok then
		failures = failures + 1
	end
	print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end

test("clock keeps second-level checks without redundant writes", function()
	local m = mock()
	local label = "Sun 18, 15:00"
	os.date = function()
		return label
	end
	dofile(root .. "items/widgets/calendar.lua")
	m.emit("routine")
	local before = #m.sets
	for _ = 1, 59 do
		m.emit("routine")
	end
	print("Clock writes for 59 unchanged ticks: " .. (#m.sets - before))
	assert(#m.sets == before)
	assert(m.states.calendar.update_freq == 1)
	label = "Sun 18, 15:01"
	m.emit("routine")
	assert(#m.sets == before + 1 and m.states.calendar.label.string == label)
	label = "Mon 19, 09:00"
	m.emit("system_woke")
	assert(m.states.calendar.label.string == label)
end)

test("Focus reads its existing cache without shell launches", function()
	local m = mock()
	local content, closes = "on\n", 0
	io.open = function(path, mode)
		assert(path:match("/sketchybar/dnd_state$") and mode == "r")
		if content == nil then
			return nil
		end
		return {
			read = function()
				return content
			end,
			close = function()
				closes = closes + 1
			end,
		}
	end
	dofile(root .. "items/widgets/dnd.lua")
	assert(m.states["widgets.dnd"].script == nil, "Focus still invokes its shell script")
	assert(m.states["widgets.dnd"].update_freq == 5)
	m.emit("routine")
	assert(m.states["widgets.dnd"].icon.color == colors.blue)
	local before = #m.sets
	for _ = 1, 12 do
		m.emit("routine")
	end
	assert(#m.sets == before and #m.commands == 0)
	content = "off\n"
	m.emit("dnd_changed")
	assert(m.states["widgets.dnd"].icon.color == colors.red)
	content = "on\n"
	m.emit("system_woke")
	assert(m.states["widgets.dnd"].icon.color == colors.blue)
	content = nil
	m.emit("routine")
	assert(m.states["widgets.dnd"].icon.color == colors.red)
	assert(closes >= 15)
end)

for _, metric in ipairs({
	{ file = "cpu", fragment = "iostat", initial = "30", high = "95", expected = "95%  " },
	{ file = "memory", fragment = "vm_stat", initial = "45", high = "95", expected = "95%  " },
	{ file = "disk", fragment = "df -k", initial = "38", high = "80", expected = "80%  " },
	{ file = "cpu_temp", name = "temp", fragment = "cpu-temp", initial = "55", high = "95", expected = "95°" },
}) do
	test(metric.file .. " keeps sampling but paints only changed values", function()
		local m = mock()
		local name = metric.name or metric.file
		dofile(root .. "items/widgets/" .. metric.file .. ".lua")
		m.finish(metric.fragment, metric.initial)
		local before, refreshed = #m.sets, m.groupChanges
		for _ = 1, 6 do
			m.emit("routine", name)
			m.finish(metric.fragment, metric.initial)
		end
		print(metric.file .. " writes for six unchanged samples: " .. (#m.sets - before))
		assert(#m.sets == before and m.groupChanges == refreshed)
		assert(m.count(metric.fragment) == 7)
		m.emit("routine", name)
		m.finish(metric.fragment, metric.high)
		assert(m.states[name].label.string == metric.expected)
		assert(m.states[name].label.color == colors.red and m.groupChanges == refreshed + 1)
		m.emit("routine", name)
		m.finish(metric.fragment, "")
		assert(m.states[name].label.color == colors.cyan)
		m.emit("routine", name)
		m.finish(metric.fragment, metric.initial)
		assert(m.states[name].label.color == colors.cyan)
	end)
end

test("Bluetooth avoids repainting an unchanged connection", function()
	local m = mock()
	dofile(root .. "items/widgets/bluetooth.lua")
	local connected = "power\ton\nconnected\tHeadphones\taa:bb:cc:dd:ee:ff\tHeadphones\t80%\n"
	m.emit("routine", "bluetooth")
	m.finish(" list", connected)
	local before = #m.sets
	m.emit("routine", "bluetooth")
	m.finish(" list", connected)
	assert(#m.sets == before)
	m.emit("routine", "bluetooth")
	m.finish(" list", "power\toff\n")
	assert(m.states.bluetooth.icon.string == "off" and m.states.bluetooth.icon.color == colors.red)
end)

test("sound popup updates its local slider with one audio query", function()
	local m = mock()
	dofile(root .. "items/widgets/volume.lua")
	m.emit("sound_refresh", "volume.value")
	assert(m.count("osascript") == 1)
	if m.commands[#m.commands]:find("output muted of", 1, true) then
		m.finish("osascript", "false\n")
		m.finish("osascript", "42\n")
	else
		m.finish("osascript", "output volume:42, input volume:60, alert volume:100, output muted:false\n")
	end
	assert(m.count("osascript") == 1, "Popup still makes two AppleScript queries")
	assert(m.states["volume.slider"].slider.highlight_color == colors.green)
	m.emit("sound_refresh", "volume.value")
	m.finish("osascript", "output volume:42, input volume:60, alert volume:100, output muted:true\n")
	assert(m.states["volume.slider"].slider.highlight_color == colors.red)
	assert(m.states["volume.toggle"].label.string == "off")
	m.emit("sound_refresh", "volume.value")
	m.finish("osascript", "output volume:missing value, input volume:60, alert volume:100, output muted:false\n")
	assert(m.states["volume.slider"].slider.highlight_color == colors.red)
	assert(m.states["volume.toggle"].label.string == "on")
	local before = #m.sets
	m.emit("sound_refresh", "volume.value")
	m.finish("osascript", "")
	assert(#m.sets == before, "Failed audio queries must leave the last known state intact")
end)

test("Spotify reuses artwork on pause and ignores outdated artwork callbacks", function()
	local m = mock()
	io.open = function()
		return nil
	end
	dofile(root .. "items/spotify.lua")
	local function track(title, playing)
		return {
			bundleIdentifier = "com.spotify.client",
			title = title,
			artist = "Artist",
			album = "Album",
			playing = playing,
		}
	end
	m.finish("get --no-artwork", track("Track One", true))
	assert(m.count("artworkData") == 1)
	m.finish("artworkData", "ok\n")
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track One", false))
	assert(m.count("artworkData") == 1, "Pause must not decode and resize artwork again")
	assert(m.states.spotify.label.color == colors.dark_grey)
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track One", true))
	assert(m.count("artworkData") == 1)
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track Two", true))
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track Three", true))
	local before = #m.sets
	m.finish("TrackTwo", "ok\n")
	assert(#m.sets == before, "Old artwork must not replace the current track")
	m.finish("TrackThree", "ok\n")
	assert(m.states["spotify.icon"].icon.background.image.string:find("TrackThree", 1, true))
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track Four", true))
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", {})
	m.finish("sleep 2", {})
	before = #m.sets
	m.finish("TrackFour", "ok\n")
	assert(#m.sets == before and m.states["spotify.icon"].drawing == false)
	m.emit("spotify_poll", "spotify")
	m.finish("get --no-artwork", track("Track Four", true))
	assert(m.count("artworkData") == 5, "Returning from a hidden widget must reload its artwork")
end)

test("layout pills keep controls while skipping identical paints", function()
	local m = mock()
	dofile(root .. "items/rift_layout.lua")
	local function layout(kind, fullscreen)
		return {
			mode = "bsp",
			container_tree = {
				layout_kind = kind,
				children = {
					{ node_type = "window", is_selected = true, is_fullscreen = fullscreen },
				},
			},
		}
	end
	m.finish("query layout", layout("horizontal", false))
	local before = #m.sets
	for _ = 1, 10 do
		m.emit("workspace_changed")
		m.finish("query layout", layout("horizontal", false))
	end
	print("Layout writes for 10 unchanged snapshots: " .. (#m.sets - before))
	assert(#m.sets == before)
	m.emit("layout_changed")
	m.finish("query layout", layout("vertical", false))
	assert(m.states["layout.bsp"].label.string:find(utf8.char(0x2195), 1, true))
	m.emit("layout_changed")
	m.finish("query layout", layout("vertical", true))
	assert(m.states["layout.bsp"].label.string:find(utf8.char(0xF0293), 1, true))
	m.emit("rift_layout_toggle")
	m.finish("query layout", layout("vertical", true))
	assert(m.states["layout.stack"].drawing == true)
	m.emit("swap_menu", nil, { isShowingMenu = "on" })
	m.finish("query layout", layout("vertical", true))
	assert(m.states["layout.bsp"].drawing == false)
	m.emit("swap_menu", nil, { isShowingMenu = "off" })
	m.finish("query layout", layout("vertical", true))
	assert(m.states["layout.bsp"].drawing == true)
	m.emit("rift_layout_toggle")
	m.finish("query layout", layout("vertical", true))
	assert(m.states["layout.stack"].drawing == false)
end)

assert(failures == 0, failures .. " audit regressions failed")
