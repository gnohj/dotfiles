local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.colors = {
	foreground = "#CBE0F0",
	background = "#021c31",
	cursor_bg = "#47FF9C",
	cursor_border = "#47FF9C",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
	brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
}

config.max_fps = 120

config.keys = {

	-- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
	{
		key = "LeftArrow",
		mods = "OPT",
		action = wezterm.action({ SendString = "\x1bb" }),
	},
	-- Make Option-Right equivalent to Alt-f; forward-word
	{
		key = "RightArrow",
		mods = "OPT",
		action = wezterm.action({ SendString = "\x1bf" }),
	},
	-- Select next tab with cmd-opt-left/right arrow
	{
		key = "LeftArrow",
		mods = "CMD|OPT",
		action = wezterm.action.ActivateTabRelative(-1),
	},
	{
		key = "RightArrow",
		mods = "CMD|OPT",
		action = wezterm.action.ActivateTabRelative(1),
	},
	-- Select next pane with cmd-left/right arrow
	{
		key = "LeftArrow",
		mods = "CMD",
		action = wezterm.action({ ActivatePaneDirection = "Prev" }),
	},
	{
		key = "RightArrow",
		mods = "CMD",
		action = wezterm.action({ ActivatePaneDirection = "Next" }),
	},
	-- on cmd-s, send esc, then ':w<enter>'. This makes cmd-s trigger a save action in neovim
	{
		key = "s",
		mods = "CMD",
		action = wezterm.action({ SendString = "\x1b:w\n" }),
	},
}

config.font = wezterm.font("RobotoMono Nerd Font")
config.font_size = 13.5

config.window_padding = {
	left = 2,
	right = 2,
	top = 4,
	bottom = 0,
}

config.enable_tab_bar = false

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.905
config.macos_window_background_blur = 2
config.window_close_confirmation = "NeverPrompt"

return config
