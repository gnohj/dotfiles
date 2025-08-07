--
-- ██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗
-- ██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║
-- ██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║
-- ██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║
-- ╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║
--  ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝
-- A GPU-accelerated cross-platform terminal emulator
-- https://wezfurlong.org/wezterm/
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- NOTE: When inside neovim, run a `checkhealth` and under `tmux` you will see that
-- the term is set to `xterm-kitty`. If the term is set to something else:
-- - Reload your tmux configuration,
-- - Then close all your tmux sessions, one at a time and quit wezterm
-- - re-open wezterm
-- Then you'll be able to set your terminal to `xterm-kitty` as seen below
config.term = "xterm-kitty"

-- Colors - load from external theme file
local theme = require("colors")
config.colors = theme.colors

-- Performance
config.max_fps = 120
config.enable_kitty_graphics = true

-- Font - match Ghostty exactly
config.font = wezterm.font("RobotoMono Nerd Font")
config.font_size = 15

-- Cursor - match Ghostty style
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 0 -- false = no blinking

-- Window - match Ghostty settings
config.window_padding = {
	left = 4,
	right = 2,
	top = 8,
	bottom = 0,
}
config.enable_tab_bar = false
config.window_decorations = "RESIZE" -- Similar to window-decoration = true
config.window_close_confirmation = "NeverPrompt" -- Match confirm-close-surface = false

-- macOS specific - match Ghostty
config.use_dead_keys = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Hide mouse while typing
config.hide_mouse_cursor_when_typing = true

-- Keybindings - updated to match Ghostty
config.keys = {
	-- WezTerm specific keybinds (match Ghostty inspector/reload)
	{
		key = "i",
		mods = "CMD",
		action = wezterm.action.ShowDebugOverlay,
	},

	-- Tmux keybinds (match Ghostty exactly)
	-- cmd + k to tmux - sesh (prefix + K)
	{
		key = "k",
		mods = "CMD",
		action = wezterm.action({ SendString = "\x01\x4b" }),
	},
	-- cmd + g to tmux - lazygit (prefix + g)
	{
		key = "g",
		mods = "CMD",
		action = wezterm.action({ SendString = "\x01\x67" }),
	},
	-- cmd + l to tmux - last session (prefix + L)
	{
		key = "l",
		mods = "CMD",
		action = wezterm.action({ SendString = "\x01\x4c" }),
	},
	-- cmd + shift + z to tmux - quit session (prefix + Z)
	{
		key = "Z",
		mods = "CMD|SHIFT",
		action = wezterm.action({ SendString = "\x01\x5a" }),
	},
}

-- Clipboard settings (match Ghostty)
-- WezTerm handles clipboard automatically, no explicit config needed

-- Quit behavior (match Ghostty)
config.quit_when_all_windows_are_closed = true

-- Background - match Ghostty
-- config.macos_window_background_blur = 80

config.window_background_opacity = 1.0
-- config.window_background_opacity = 0.875
return config
