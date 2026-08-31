local popup = require("lib.popup")
local settings = require("config.settings")

local M = {}

local scriptPath <const> = "~/.config/sketchybar/items/widgets/system-panel.sh"
local popupWidth <const> = settings.dimens.graphics.popup.large_width

-- Shared by cpu/memory/disk: same header and top-consumer list, only the glyph, title and mode differ.
function M.attach(item, opts)
	local header = sbar.add("item", item.name .. ".header", {
		position = "popup." .. item.name,
		icon = {
			align = "left",
			string = opts.icon .. "  " .. opts.title,
			width = popupWidth - 52,
			padding_left = 12,
			padding_right = 0,
			color = settings.colors.blue,
			font = { style = settings.fonts.styles.bold },
		},
		label = popup.close_label(),
		click_script = popup.close_script(item.name),
	})

	local rowCount, generation, removePattern, pending = 0, 0, nil, {}

	local function addRow(options)
		options.name = item.name .. ".r" .. generation .. "." .. rowCount
		pending[#pending + 1] = options
		rowCount = rowCount + 1
	end

	local opening = false

	local function render(result)
		removePattern = rowCount > 0 and ("/" .. item.name .. ".r" .. generation .. "\\.*/") or nil
		rowCount, pending, generation = 0, {}, generation + 1

		addRow({
			position = "popup." .. item.name,
			icon = {
				align = "left",
				string = opts.section,
				width = popupWidth,
				color = settings.colors.grey,
				font = { size = settings.dimens.text.label - 2, style = settings.fonts.styles.bold },
			},
			label = { drawing = false },
		})

		for line in result:gmatch("[^\r\n]+") do
			local kind, name, value = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
			if kind == "row" then
				addRow({
					position = "popup." .. item.name,
					icon = {
						align = "left",
						string = popup.ellipsize(name, 18),
						width = popupWidth * 0.55,
						color = settings.colors.dirty_white,
					},
					label = {
						align = "right",
						string = value,
						width = popupWidth * 0.45,
						color = settings.colors.white,
					},
				})
			end
		end

		popup.build(item.name, removePattern, pending, opening)
		opening = false
	end

	local function refresh(state)
		local value = type(state.label) == "table" and state.label.value or ""
		header:set({ icon = { string = opts.icon .. "  " .. opts.title .. "  " .. value:gsub("%s+$", "") } })
		sbar.exec(scriptPath .. " " .. opts.mode, render)
	end

	item:subscribe("mouse.clicked", function(env)
		if env.BUTTON == "right" then
			return
		end
		popup.toggle(item, function(state)
			opening = true
			popup.close_others(item.name)
			refresh(state)
		end)
	end)
end

return M
