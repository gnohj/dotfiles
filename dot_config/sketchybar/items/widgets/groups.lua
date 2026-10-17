local colors = require("config.colors")

local groups <const> = {
	notifications = {
		members = {
			"widgets.github_notification",
			"widgets.pr_review_notification",
			"widgets.package_notification",
			"agent_quota",
		},
		red_only = true,
		priority = {
			"widgets.pr_review_notification",
			"widgets.github_notification",
			"widgets.package_notification",
			"agent_quota",
		},
	},
	system = {
		members = { "widgets.cpu", "widgets.memory", "widgets.disk", "widgets.cpu_temp" },
		idle = { ["widgets.cpu"] = true, ["widgets.memory"] = true },
	},
	vps = {
		members = { "widgets.vps_cpu", "widgets.vps_memory", "widgets.vps_disk", "widgets.vps_temp" },
		idle = { ["widgets.vps_cpu"] = true, ["widgets.vps_memory"] = true },
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
local SWAP_MARGIN <const> = 5
local GLYPH_GAP <const> = 6

for _, group in pairs(groups) do
	group.metrics = { table.unpack(group.members) }
	group.edges = {}
end

local M = {}

local edges = 0
function M.edge(group, width, click_script)
	edges = edges + 1
	local name = "widgets.group_edge." .. edges
	sbar.add("item", name, {
		position = "right",
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

function M.glyph(group, icon, color, y_offset)
	local name = "widgets.group_glyph." .. group
	sbar.add("item", name, {
		position = "right",
		padding_left = 0,
		padding_right = 0,
		icon = { string = icon, color = color, padding_left = 0, padding_right = 0, y_offset = y_offset or 0 },
		label = { drawing = false },
	})
	table.insert(groups[group].members, name)
	groups[group].glyph = name
	groups[group].glyph_color = hex(color)
end

local apply

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
function M.spacer()
	spacers = spacers + 1
	sbar.add("item", "widgets.group_gap." .. spacers, {
		position = "right",
		width = 6,
		icon = { drawing = false },
		label = { drawing = false },
		padding_left = 0,
		padding_right = 0,
	})
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

local function pick(group)
	local best, current
	for _, member in ipairs(group.metrics) do
		local item = sbar.query(member)
		local reading = type(item) == "table" and item.label and value(item)
		local level = reading and rank(item)
		if reading and (level > 0 or group.idle[member]) then
			local candidate = { name = member, level = level, value = reading }
			if not best or level > best.level or (level == best.level and reading > best.value) then
				best = candidate
			end
			if member == group.shown then
				current = candidate
			end
		end
	end
	if current and best and current.level == best.level and best.value - current.value < SWAP_MARGIN then
		return current
	end
	return best
end

local function pending(name, item)
	if name == "agent_quota" then
		return true
	elseif name == "widgets.github_notification" then
		return item.label.value ~= ""
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

local function present(group, member)
	if member ~= "widgets.github_notification" then
		return true
	end
	local item = sbar.query(member)
	return type(item) == "table" and item.label ~= nil and pending(member, item)
end

local function trail(item)
	local inner = item.label.drawing == "on" and item.label.padding_right or item.icon.padding_right
	return inner + item.geometry.padding_right
end

function apply(group)
	local shown = (group.priority and first_pending(group)) or (not group.priority and pick(group))
		or { name = group.shown or group.metrics[1] }
	group.shown = shown.name
	local first, last
	for _, member in ipairs(group.metrics) do
		local on = group.expanded and present(group, member) or member == shown.name
		sbar.set(member, { drawing = on and "on" or "off" })
		if on then
			first, last = first or member, member
		end
	end

	local left = sbar.query(first or shown.name)
	local rightmost = sbar.query(last or shown.name)
	if type(left) ~= "table" or not left.icon or type(rightmost) ~= "table" or not rightmost.label then
		return
	end
	if group.glyph then
		sbar.set(group.glyph, { padding_right = GLYPH_GAP - left.geometry.padding_left - left.icon.padding_left })
		left = sbar.query(group.glyph)
	end
	local edge = group.edges[#group.edges]
	sbar.set(edge.name, {
		width = (group.expanded and not group.glyph) and edge.width
			or math.max(-left.geometry.padding_left, INNER - left.geometry.padding_left - left.icon.padding_left),
	})
	sbar.set(group.edges[1].name, { width = math.max(0, INNER - trail(rightmost)) })
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

	local function refresh()
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
				if member ~= group.glyph and type(item) == "table" and item.geometry then
					local level, color = (group.collapsible and rank or warning)(item)
					if level > worst and (level == 3 or not group.red_only) then
						worst, border = level, color
					end
				end
			end
			brackets[name]:set({ background = { border_color = border or hex(IDLE) } })
			if group.glyph then
				sbar.set(group.glyph, { icon = { color = border or group.glyph_color } })
			end
			::continue::
		end
	end

	local watcher = sbar.add("item", { drawing = false, updates = true, update_freq = 5 })
	watcher:subscribe({ "routine", "forced", "system_woke" }, refresh)
	refresh()
	sbar.exec("$HOME/.config/sketchybar/items/widgets/dnd.sh")
end

return M
