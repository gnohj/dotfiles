local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local popupWidth <const> = 360
local scriptPath <const> = "~/.config/sketchybar/items/widgets/schedules-panel.py"

local schedules = sbar.add("item", constants.items.SCHEDULES, {
	position = "right",
	display = "active",
	padding_left = 0,
	padding_right = settings.dimens.padding.gap,
	update_freq = 30,
	label = { drawing = false },
	icon = {
		string = settings.icons.text.clock,
		color = settings.colors.blue,
		padding_left = 0,
		padding_right = 0,
	},
	popup = { align = "center" },
})

local header = sbar.add("item", constants.items.SCHEDULES .. ".header", {
	position = "popup." .. schedules.name,
	icon = {
		align = "left",
		string = settings.icons.text.clock .. "  Schedules",
		width = popupWidth * 0.62,
		color = settings.colors.blue,
		font = { style = settings.fonts.styles.bold },
	},
	label = {
		align = "right",
		string = "",
		width = popupWidth * 0.38,
		color = settings.colors.green,
		font = { style = settings.fonts.styles.bold },
	},
})

local statusColors <const> = {
	scheduled = settings.colors.green,
	running = settings.colors.blue,
	failed = settings.colors.red,
	unloaded = settings.colors.yellow,
	disabled = settings.colors.grey,
	complete = settings.colors.grey,
}

local opening = false
local removePattern = nil
local generation = 0
local rowCount = 0
local pending = {}

local function addRow(options)
	options.name = constants.items.SCHEDULES .. ".r" .. generation .. "." .. rowCount
	pending[#pending + 1] = options
	rowCount = rowCount + 1
end

local function clearRows()
	removePattern = rowCount > 0 and ("/" .. constants.items.SCHEDULES .. ".r" .. generation .. "\\.*/") or nil
	rowCount = 0
	pending = {}
	generation = generation + 1
end

local function parse(result)
	local state = { active = 0, problems = 0, total = 0, rows = {} }
	for line in result:gmatch("[^\r\n]+") do
		local kind, first, second, third = line:match("^([^\t]*)\t([^\t]*)\t?([^\t]*)\t?(.*)$")
		if kind == "summary" then
			state.active = tonumber(first) or 0
			state.problems = tonumber(second) or 0
			state.total = tonumber(third) or 0
		elseif kind == "section" then
			table.insert(state.rows, { kind = kind, title = first, count = second })
		elseif kind == "job" then
			table.insert(state.rows, { kind = kind, name = first, remaining = second, status = third })
		end
	end
	return state
end

local function updateIcon(state)
	local color = settings.colors.blue
	for _, row in ipairs(state.rows) do
		if row.kind == "job" and row.status == "failed" then
			color = settings.colors.red
			break
		end
	end
	schedules:set({ icon = { color = color } })
end

local function render(state)
	clearRows()
	header:set({
		label = {
			string = state.active .. "/" .. state.total .. " active",
			color = state.problems > 0 and settings.colors.yellow or settings.colors.green,
		},
	})

	for _, row in ipairs(state.rows) do
		if row.kind == "section" then
			addRow({
				position = "popup." .. schedules.name,
				icon = {
					align = "left",
					string = row.title,
					width = popupWidth * 0.8,
					color = settings.colors.grey,
					font = { size = settings.dimens.text.label - 2, style = settings.fonts.styles.bold },
				},
				label = {
					align = "right",
					string = row.count,
					width = popupWidth * 0.2,
					color = settings.colors.grey,
				},
			})
		else
			local color = statusColors[row.status] or settings.colors.grey
			addRow({
				position = "popup." .. schedules.name,
				icon = {
					align = "left",
					string = "●  " .. popup.ellipsize(row.name, 27),
					width = popupWidth * 0.68,
					color = color,
				},
				label = {
					align = "right",
					string = row.remaining,
					width = popupWidth * 0.32,
					color = color,
				},
			})
		end
	end

	popup.build(schedules.name, removePattern, pending, opening)
	opening = false
end

local function refresh()
	sbar.exec(scriptPath, function(result)
		local state = parse(result)
		updateIcon(state)
		if opening then
			render(state)
		end
	end)
end

local function toggleDetails(env)
	if env.BUTTON == "right" then
		return
	end
	if schedules:query().popup.drawing == "off" then
		opening = true
		popup.close_others(schedules.name)
		refresh()
	else
		schedules:set({ popup = { drawing = false } })
	end
end

schedules:subscribe({ "forced", "routine", "system_woke" }, refresh)
schedules:subscribe("mouse.clicked", toggleDetails)
