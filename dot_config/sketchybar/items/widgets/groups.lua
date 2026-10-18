local colors = require("config.colors")

local groups <const> = {
	notifications = {
		members = {
			"widgets.pr_review_notification",
			"widgets.package_notification",
			"agent_quota",
		},
		red_only = true,
		side = "left",
		priority = {
			"widgets.pr_review_notification",
			"widgets.package_notification",
			"agent_quota",
		},
	},
	system = {
		members = { "widgets.cpu", "widgets.memory", "widgets.disk", "widgets.cpu_temp" },
		-- Collapsed slots; an alerting hidden metric bumps an idle one, first listed goes first.
		core = { "widgets.cpu", "widgets.memory" },
	},
	vps = {
		members = { "widgets.vps_cpu", "widgets.vps_memory", "widgets.vps_disk", "widgets.vps_temp" },
		core = { "widgets.vps_cpu", "widgets.vps_memory" },
	},
	push = {
		members = { "widgets.github_notification" },
		manual = true,
	},
	status = {
		members = {
			"mic",
			"widgets.volume.value",
			"widgets.volume.toggle",
			"widgets.bluetooth",
			"widgets.wifi",
			"widgets.vpn",
			"widgets.tailscale",
			"widgets.dnd",
			"widgets.battery",
			"widgets.calendar",
		},
		manual = true,
	},
}

local IDLE = colors.with_alpha(colors.dark_grey, 0.5)
local function hex(color)
	return string.format("0x%08x", color)
end

-- Ranked so a badge wears its most severe member's colour.
local severity <const> = {
	[hex(colors.red)] = 3,
	[hex(colors.orange)] = 2,
	[hex(colors.yellow)] = 1,
	[hex(colors.shell_yellow)] = 1,
}

local INNER <const> = 10
local GLYPH_GAP <const> = 6
local GLYPH_PAD <const> = 6
local UPTIME_GAP <const> = 8

for _, group in pairs(groups) do
	group.metrics = { table.unpack(group.members) }
	group.edges = {}
end

local M = {}
local applied = {}

local function set_changed(name, property, value)
	local previous = applied[name] or {}
	if previous[property] == value then
		return
	end
	sbar.set(name, { [property] = value })
	previous[property] = value
	applied[name] = previous
end

local function side(group)
	return group and groups[group].side or "right"
end

local edges = 0
function M.edge(group, width, click_script)
	edges = edges + 1
	local name = "widgets.group_edge." .. edges
	sbar.add("item", name, {
		position = side(group),
		width = width or 8,
		icon = { drawing = false },
		label = { drawing = false },
		padding_left = 0,
		padding_right = 0,
		click_script = click_script,
	})
	table.insert(groups[group].members, name)
	table.insert(groups[group].edges, { name = name, width = width or 8 })
end

function M.glyph(group, icon, background, y_offset)
	local name = "widgets.group_glyph." .. group
	sbar.add("item", name, {
		position = "right",
		padding_left = 0,
		padding_right = 0,
		background = { drawing = true, color = background, height = 18, corner_radius = 9 },
		icon = {
			string = icon,
			color = colors.black,
			padding_left = GLYPH_PAD,
			padding_right = GLYPH_PAD,
			y_offset = y_offset or 0,
		},
		label = { drawing = false },
	})
	table.insert(groups[group].members, name)
	groups[group].glyph = name
end

function M.uptime(group, name)
	sbar.add("item", name, {
		position = "right",
		padding_left = 0,
		padding_right = 0,
		icon = { string = "󰁝", color = colors.blue, padding_left = 0, padding_right = 0, font = { size = 14.0 } },
		label = { string = "--", color = colors.cyan, padding_left = 0, padding_right = 10 },
	})
	table.insert(groups[group].members, name)
	groups[group].uptime = name
end

function M.days(seconds)
	return string.format("%02dd", math.min(math.floor(seconds / 86400), 999))
end

local apply, refresh

function M.changed()
	if refresh then
		refresh()
	end
end

function M.toggle(group)
	groups[group].collapsible = true
	local event = "group_toggle_" .. group
	sbar.add("event", event)
	local listener = sbar.add("item", { drawing = false, updates = true })
	listener:subscribe(event, function()
		groups[group].expanded = not groups[group].expanded
		apply(groups[group])
	end)
end

local spacers = 0
function M.spacer(group)
	spacers = spacers + 1
	local name = "widgets.group_gap." .. spacers
	if group then
		groups[group].gap = name
	end
	sbar.add("item", name, {
		position = side(group),
		width = 6,
		icon = { drawing = false },
		label = { drawing = false },
		padding_left = 0,
		padding_right = 0,
	})
end

function M.show(group, on)
	local drawing = on and "on" or "off"
	for _, member in ipairs(groups[group].members) do
		set_changed(member, "drawing", drawing)
	end
	if groups[group].gap then
		set_changed(groups[group].gap, "drawing", drawing)
	end
end

local function rank(item)
	local icon, label = severity[item.icon.color] or 0, severity[item.label.color] or 0
	if icon >= label then
		return icon, item.icon.color
	end
	return label, item.label.color
end

local function warning(item)
	if item.geometry.drawing ~= "on" then
		return 0, nil
	end
	return rank(item)
end

local function value(item)
	return tonumber((item.label.value or ""):match("^%d+"))
end

local function level(member)
	local item = sbar.query(member)
	if type(item) ~= "table" or not item.icon or not item.label then
		return 0
	end
	return (rank(item))
end

local function slots(group)
	local shown, free, core, levels = {}, #group.core, {}, {}
	for _, member in ipairs(group.metrics) do
		levels[member] = level(member)
	end
	for _, member in ipairs(group.core) do
		core[member] = true
		if levels[member] > 0 then
			shown[member], free = true, free - 1
		end
	end
	local alerts = {}
	for _, member in ipairs(group.metrics) do
		if not core[member] and levels[member] > 0 then
			table.insert(alerts, member)
		end
	end
	table.sort(alerts, function(a, b)
		return levels[a] > levels[b]
	end)
	for _, member in ipairs(alerts) do
		if free > 0 then
			shown[member], free = true, free - 1
		end
	end
	for i = #group.core, 1, -1 do
		local member = group.core[i]
		if free > 0 and not shown[member] then
			shown[member], free = true, free - 1
		end
	end
	return shown
end

local function pending(name, item)
	if name == "agent_quota" then
		return true
	end
	return value(item) ~= nil
end

local function first_pending(group)
	for _, member in ipairs(group.priority) do
		local item = sbar.query(member)
		if type(item) == "table" and item.label and pending(member, item) then
			return { name = member }
		end
	end
end

local function trail(item)
	local inner = item.label.drawing == "on" and item.label.padding_right or item.icon.padding_right
	return inner + item.geometry.padding_right
end

function apply(group)
	local shown = group.core and slots(group) or { [(first_pending(group) or { name = group.metrics[1] }).name] = true }
	local first, last
	for _, member in ipairs(group.metrics) do
		local on = group.expanded or shown[member] or false
		set_changed(member, "drawing", on and "on" or "off")
		if on then
			first, last = first or member, member
		end
	end

	local left = sbar.query(first or group.metrics[1])
	local rightmost = sbar.query(last or group.metrics[1])
	if type(left) ~= "table" or not left.icon or type(rightmost) ~= "table" or not rightmost.label then
		return
	end
	if group.uptime then
		set_changed(group.uptime, "padding_left", UPTIME_GAP - trail(rightmost))
		rightmost = sbar.query(group.uptime)
	end
	if group.glyph then
		set_changed(group.glyph, "padding_right", GLYPH_GAP - left.geometry.padding_left - left.icon.padding_left)
		left = sbar.query(group.glyph)
	end
	local edge, closing = group.edges[#group.edges], group.edges[1]
	if group.side == "left" then
		edge, closing = closing, edge
	end
	set_changed(
		edge.name,
		"width",
		(group.expanded and not group.glyph) and edge.width
			or math.max(-left.geometry.padding_left, INNER - left.geometry.padding_left - left.icon.padding_left)
	)
	set_changed(closing.name, "width", math.max(0, INNER - trail(rightmost)))
end

function M.build()
	local brackets = {}
	for name, group in pairs(groups) do
		brackets[name] = sbar.add("bracket", "widgets.group." .. name, group.members, {
			background = {
				height = 24,
				corner_radius = 12,
				border_width = 1,
				color = colors.transparent,
				border_color = IDLE,
				padding_left = 8,
				padding_right = 8,
			},
		})
	end

	for name, group in pairs(groups) do
		if group.collapsible then
			for _, member in ipairs(group.members) do
				sbar.set(member, { click_script = "sketchybar --trigger group_toggle_" .. name })
			end
			-- Hidden members must keep sampling or a collapsed badge never sees their alarms.
			for _, member in ipairs(group.metrics) do
				sbar.set(member, { updates = "on" })
			end
		end
	end

	function refresh()
		for _, group in pairs(groups) do
			if group.collapsible then
				apply(group)
			end
		end
		for name, group in pairs(groups) do
			if group.manual then
				goto continue
			end
			local worst, border = 0, nil
			for _, member in ipairs(group.members) do
				local item = sbar.query(member)
				if member ~= group.glyph and member ~= group.uptime and type(item) == "table" and item.geometry then
					local level, color = (group.collapsible and rank or warning)(item)
					if level > worst and (level == 3 or not group.red_only) then
						worst, border = level, color
					end
				end
			end
			set_changed(brackets[name].name, "background.border_color", border or hex(IDLE))
			::continue::
		end
	end

	local watcher = sbar.add("item", { drawing = false, updates = true, update_freq = 5 })
	sbar.add("event", "group_refresh")
	watcher:subscribe({ "routine", "forced", "system_woke", "group_refresh" }, refresh)
	refresh()
	sbar.exec("$HOME/.config/sketchybar/items/widgets/dnd.sh")
end

return M
