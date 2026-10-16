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
	},
	system = {
		members = { "widgets.cpu", "widgets.memory", "widgets.disk", "widgets.cpu_temp" },
	},
	vps = {
		members = { "widgets.vps_cpu", "widgets.vps_memory", "widgets.vps_disk", "widgets.vps_temp" },
	},
	-- The DND scripts own this border: red while Focus is off, green while it is on.
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

local function warning(item)
	if item.geometry.drawing ~= "on" then
		return 0, nil
	end
	local icon, label = severity[item.icon.color] or 0, severity[item.label.color] or 0
	if icon >= label then
		return icon, item.icon.color
	end
	return label, item.label.color
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

	local function refresh()
		for name, group in pairs(groups) do
			if group.manual then
				goto continue
			end
			local worst, border = 0, nil
			for _, member in ipairs(group.members) do
				local item = sbar.query(member)
				if type(item) == "table" and item.geometry then
					local rank, color = warning(item)
					if rank > worst and (rank == 3 or not group.red_only) then
						worst, border = rank, color
					end
				end
			end
			brackets[name]:set({ background = { border_color = border or hex(IDLE) } })
			::continue::
		end
	end

	local watcher = sbar.add("item", { drawing = false, updates = true, update_freq = 5 })
	watcher:subscribe({ "routine", "forced", "system_woke" }, refresh)
	refresh()
	sbar.exec("$HOME/.config/sketchybar/items/widgets/dnd.sh")
end

return M
