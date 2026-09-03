local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local popupWidth <const> = 360
local scriptPath <const> = "~/.config/sketchybar/items/widgets/schedules-panel.py"

sbar.add("event", constants.events.SCHEDULES_TOGGLE)

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
		width = popupWidth - 52,
		padding_left = 12,
		padding_right = 0,
		color = settings.colors.blue,
		font = { style = settings.fonts.styles.bold },
	},
	label = popup.close_label(),
	click_script = popup.close_script(schedules.name),
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

-- Split every tab: a fixed pattern drops the job row's trailing fields, the AI flag included.
local function fields(line)
	local out = {}
	for field in (line .. "\t"):gmatch("([^\t]*)\t") do
		out[#out + 1] = field
	end
	return out
end

local function parse(result)
	local state = { active = 0, problems = 0, total = 0, ai = 0, rows = {} }
	for line in result:gmatch("[^\r\n]+") do
		local row = fields(line)
		local kind = row[1]
		if kind == "summary" then
			state.active = tonumber(row[2]) or 0
			state.problems = tonumber(row[3]) or 0
			state.total = tonumber(row[4]) or 0
			state.ai = tonumber(row[5]) or 0
		elseif kind == "section" then
			table.insert(state.rows, { kind = kind, title = row[2], count = row[3] })
		elseif kind == "job" then
			table.insert(state.rows, {
				kind = kind,
				name = row[2],
				remaining = row[3],
				status = row[4],
				ai = row[11] == "true",
			})
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
		icon = {
			string = settings.icons.text.clock
				.. "  Schedules  "
				.. state.active
				.. "/"
				.. state.total
				.. " active · "
				.. state.ai
				.. " AI",
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
			-- The AI suffix eats name width, so trim the name by the same amount to keep one line.
			local name = popup.ellipsize(row.name, row.ai and 22 or 27) .. (row.ai and "  · AI" or "")
			addRow({
				position = "popup." .. schedules.name,
				icon = {
					align = "left",
					string = "●  " .. name,
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
			return
		end
		popup.query(schedules, function(isOpen)
			if isOpen then
				render(state)
			end
		end)
	end)
end

local function toggleDetails(env)
	if env.BUTTON == "right" then
		return
	end
	popup.toggle(schedules, function()
		opening = true
		popup.close_others(schedules.name)
		refresh()
	end)
end

schedules:subscribe({ "forced", "routine", "system_woke" }, refresh)
schedules:subscribe("mouse.clicked", toggleDetails)
schedules:subscribe(constants.events.SCHEDULES_TOGGLE, toggleDetails)
