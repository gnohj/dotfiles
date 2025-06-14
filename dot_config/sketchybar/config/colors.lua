-- Function to read colorscheme values
local function load_colors()
	local colors = {}
	local file = io.open(os.getenv("HOME") .. "/.config/colorscheme/active/active-colorscheme.sh", "r")

	if file then
		for line in file:lines() do
			-- Only match lines that start with gnohj_color
			local key, value = line:match("^(gnohj_color%w+)=(.+)")
			if key and value then
				-- Remove quotes and # from hex values
				value = value:gsub('"', ""):gsub("#", "")
				colors[key] = value
			end
		end
		file:close()
	end

	return colors
end

local colorscheme = load_colors()

-- Helper function to convert hex to sketchybar format
local function hex_to_sketchybar(hex, alpha)
	alpha = alpha or "ff"
	return tonumber("0x" .. alpha .. hex)
end

local colors <const> = {
	black = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31"),
	white = hex_to_sketchybar(colorscheme.gnohj_color14 or "c0caf5"),
	red = hex_to_sketchybar(colorscheme.gnohj_color11 or "f16c75"),
	green = hex_to_sketchybar(colorscheme.gnohj_color02 or "37f499"),
	light_green = hex_to_sketchybar(colorscheme.gnohj_color02 or "37f499"),
	blue = hex_to_sketchybar(colorscheme.gnohj_color04 or "987afb"),
	light_blue = hex_to_sketchybar(colorscheme.gnohj_color03 or "04d1f9"),
	yellow = hex_to_sketchybar(colorscheme.gnohj_color05 or "19dfcf"),
	orange = hex_to_sketchybar(colorscheme.gnohj_color06 or "04d1f9"),
	magenta = hex_to_sketchybar(colorscheme.gnohj_color01 or "949ae5"),
	purple = hex_to_sketchybar(colorscheme.gnohj_color01 or "949ae5"),
	other_purple = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
	cyan = hex_to_sketchybar(colorscheme.gnohj_color03 or "04d1f9"),
	grey = hex_to_sketchybar(colorscheme.gnohj_color09 or "6272A4"),
	dirty_white = hex_to_sketchybar(colorscheme.gnohj_color14 or "c0caf5", "c8"),
	dark_grey = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
	transparent = 0x00000000,

	bar = {
		bg = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "f1"),
		border = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
	},

	popup = {
		bg = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "f1"),
		border = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
	},

	slider = {
		bg = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "f1"),
		border = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
	},

	bg1 = hex_to_sketchybar(colorscheme.gnohj_color17 or "2C3A54", "d3"),
	bg2 = hex_to_sketchybar(colorscheme.gnohj_color07 or "1c242f"),

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
	end,
}

return colors
