local colors = require("config.colors")
local dimens = require("config.dimens")

local dnd = sbar.add("item", "widgets.dnd", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "􀆺", -- SF Symbol moon.fill (matches Apple's Focus icon)
		color = colors.red,
		font = { size = 13.0 },
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	update_freq = 5,
	click_script = "~/.config/sketchybar/items/widgets/dnd-click.sh",
})

local statePath = os.getenv("HOME") .. "/.cache/sketchybar/dnd_state"
local displayedColor

local function update()
	local file = io.open(statePath, "r")
	local state = file and file:read("*a") or ""
	if file then
		file:close()
	end
	local color = state:gsub("\n+$", "") == "on" and colors.blue or colors.red
	if color ~= displayedColor then
		dnd:set({ icon = { color = color } })
		displayedColor = color
	end
end

dnd:subscribe({ "forced", "routine", "system_woke", "dnd_changed" }, update)
update()
