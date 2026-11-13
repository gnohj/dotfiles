local function load_colors()
	local colors = {}
	local file = io.open(os.getenv("HOME") .. "/.config/colorscheme/active/active-colorscheme.sh", "r")

	if file then
		for line in file:lines() do
			local key, value = line:match("^(gnohj_%w+)=(.+)")
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

local function hex_to_sketchybar(hex, alpha)
	alpha = alpha or "ff"
	return tonumber("0x" .. alpha .. hex)
end

local function build(colorscheme)
	return {
		black = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31"),
		white = hex_to_sketchybar(colorscheme.gnohj_color14 or "c0caf5"),
		red = hex_to_sketchybar(colorscheme.gnohj_color11 or "f16c75"),
		green = hex_to_sketchybar(colorscheme.gnohj_color02 or "37f499"),
		light_green = hex_to_sketchybar(colorscheme.gnohj_color02 or "37f499"),
		blue = hex_to_sketchybar(colorscheme.gnohj_color04 or "987afb"),
		light_blue = hex_to_sketchybar(colorscheme.gnohj_color03 or "04d1f9"),
		yellow = hex_to_sketchybar(colorscheme.gnohj_color05 or "19dfcf"),
		-- colors.sh calls this one YELLOW, so shell-driven widgets warn in it.
		shell_yellow = hex_to_sketchybar(colorscheme.gnohj_color12 or "ccd19d"),
		orange = hex_to_sketchybar(colorscheme.gnohj_color06 or "04d1f9"),
		magenta = hex_to_sketchybar(colorscheme.gnohj_color01 or "949ae5"),
		purple = hex_to_sketchybar(colorscheme.gnohj_color01 or "949ae5"),
		other_purple = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
		cyan = hex_to_sketchybar(colorscheme.gnohj_color03 or "04d1f9"),
		grey = hex_to_sketchybar(colorscheme.gnohj_color09 or "6272A4"),
		-- Roles: values wear text, icons and active markers the accent, secondary and inactive labels muted.
		text = hex_to_sketchybar(colorscheme.gnohj_text or colorscheme.gnohj_color14 or "c0caf5"),
		muted = hex_to_sketchybar(colorscheme.gnohj_color09 or "6272A4"),
		accent = hex_to_sketchybar(colorscheme.gnohj_color03 or "04d1f9"),
		dirty_white = hex_to_sketchybar(colorscheme.gnohj_color14 or "c0caf5", "c8"),
		transparent = 0x00000000,

		bar = {
			bg = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "f1"),
			border = hex_to_sketchybar(colorscheme.gnohj_color13 or "4A5F7A"),
		},

		glass = {
			bar = 0x00000000,
			-- The theme background at 70%, so bar text keeps the contrast it was checked for whatever the wallpaper.
			pill = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "b3"),
			rim = 0x33ffffff,
			shadow = 0x59000000,
		},

		popup = {
			bg = hex_to_sketchybar(colorscheme.gnohj_color10 or "021c31", "f1"),
			-- color04 is the same blue the bar icons use, so a popup reads as belonging to its widget.
			border = hex_to_sketchybar(colorscheme.gnohj_color04 or "987afb"),
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
end

local colors <const> = build(load_colors())

-- Re-read the palette into this same table (every module holds a reference to it) and return old rgb -> new rgb for what changed, and whether one old rgb now needs two new ones.
function colors.reload()
	local map, target, ambiguous = {}, {}, false
	local function merge(old, new)
		local keys = {}
		for k in pairs(new) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = new[k]
			if type(v) == "table" then
				merge(old[k], v)
			elseif type(v) == "number" then
				local from, to = old[k] & 0xffffff, v & 0xffffff
				-- Two names sharing an rgb (gnohj: cyan and orange) cannot be told apart on a painted item once they part ways.
				if target[from] == nil then
					target[from] = to
					if from ~= to then
						map[from] = to
					end
				elseif target[from] ~= to then
					ambiguous = true
				end
				old[k] = v
			end
		end
	end
	merge(colors, build(load_colors()))
	return map, ambiguous
end

return colors
