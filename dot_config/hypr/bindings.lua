-- Keep personal overrides here and unbind defaults before replacing them.

-- Print current bindings with `omarchy menu keybindings --print`.

-- Set `omarchy_default_bindings = false` before loading Omarchy to disable its defaults.

-- Set `omarchy_preinstalled_bindings = false` to disable preinstalled app bindings.

-- Add bindings with `o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")`.

-- Replace a binding by calling `hl.unbind` before `o.bind` for the same key.

-- Disable a default without replacing it by calling `hl.unbind`.

-- Logitech MX Keys can invoke screenshots, Voxtype, or the emoji picker through `o.bind`.

-- Use the same lettered workspaces as Aerospace instead of numbered workspaces.
local workspace_names =
	{ "A", "B", "C", "D", "E", "F", "G", "M", "N", "O", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
for _, workspace in ipairs(workspace_names) do
	local selector = "name:" .. workspace
	o.bind("ALT + " .. workspace, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = selector }))

	if workspace ~= "F" then
		o.bind(
			"ALT + SHIFT + " .. workspace,
			"Move window to workspace " .. workspace,
			hl.dsp.window.move({ workspace = selector })
		)
	end
end

-- ALT plus vim keys focuses windows, while ALT+SHIFT moves them and SUPER+arrows retain their defaults.
for key, direction in pairs({ H = "l", J = "d", K = "u", L = "r" }) do
	o.bind("ALT + " .. key, "Focus " .. direction .. " window", hl.dsp.focus({ direction = direction }))
	o.bind("ALT + SHIFT + " .. key, "Swap window " .. direction, hl.dsp.window.swap({ direction = direction }))
end

-- ALT+TAB switches to the former workspace, while ALT+GRAVE retains window cycling.
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
o.bind("ALT + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))
o.bind("ALT + GRAVE", "Focus on next window", hl.dsp.window.cycle_next())
o.bind("ALT + SHIFT + GRAVE", "Focus on previous window", hl.dsp.window.cycle_next({ next = false }))

-- Map SUPER+A to CTRL+A with split down/up events to avoid stuck synthetic key state.
local function send_shortcut_once(mods, key)
	return function()
		hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

		hl.timer(function()
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
		end, { timeout = 50, type = "oneshot" })
	end
end

o.bind("SUPER + A", "Universal select all", send_shortcut_once("CTRL", "A"))

local function active_window_has_tag(expected_tag)
	local window = hl.get_active_window()
	if not window then
		return false
	end

	for _, tag in ipairs(window.tags or {}) do
		if tag:gsub("%*$", "") == expected_tag then
			return true
		end
	end

	return false
end

local function active_window_is_browser()
	return active_window_has_tag("chromium-based-browser") or active_window_has_tag("firefox-based-browser")
end

hl.unbind("SUPER + V")
o.bind("SUPER + V", "Universal smart paste", function()
	if active_window_has_tag("terminal") then
		hl.dispatch(hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/terminal-smart-paste"))
	else
		send_shortcut_once("CTRL", "V")()
	end
end)

local function browser_shortcut_or(mods, key, fallback)
	return function()
		if active_window_is_browser() then
			send_shortcut_once(mods, key)()
		else
			fallback()
		end
	end
end

local function browser_shortcut(mods, key)
	return function()
		if active_window_is_browser() then
			send_shortcut_once(mods, key)()
		end
	end
end

hl.unbind("SUPER + T")
hl.unbind("SUPER + W")
hl.unbind("SUPER + L")
hl.unbind("SUPER + ALT + LEFT")
hl.unbind("SUPER + ALT + RIGHT")
o.bind(
	"SUPER + T",
	"New browser tab or toggle floating",
	browser_shortcut_or("CTRL", "T", function()
		hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	end)
)
o.bind(
	"SUPER + W",
	"Close browser tab or window",
	browser_shortcut_or("CTRL", "W", function()
		hl.dispatch(hl.dsp.window.close())
	end)
)
o.bind(
	"SUPER + L",
	"Focus browser address bar or toggle layout",
	browser_shortcut_or("CTRL", "L", function()
		hl.dispatch(hl.dsp.exec_cmd("omarchy-hyprland-workspace-layout-toggle"))
	end)
)
o.bind(
	"SUPER + ALT + LEFT",
	"Previous browser tab or move into left group",
	browser_shortcut_or("CTRL + SHIFT", "TAB", function()
		hl.dispatch(hl.dsp.window.move({ into_group = "l" }))
	end)
)
o.bind(
	"SUPER + ALT + RIGHT",
	"Next browser tab or move into right group",
	browser_shortcut_or("CTRL", "TAB", function()
		hl.dispatch(hl.dsp.window.move({ into_group = "r" }))
	end)
)
o.bind("SUPER + CTRL + SHIFT + ALT + Y", "Previous browser tab", browser_shortcut("CTRL + SHIFT", "TAB"))
o.bind("SUPER + CTRL + SHIFT + ALT + O", "Next browser tab", browser_shortcut("CTRL", "TAB"))

-- SUPER+N resolves the focused class to a web URL, desktop entry, or executable and launches another instance.
o.bind("SUPER + N", "New instance of focused app", os.getenv("HOME") .. "/.local/bin/hypr-new-instance")

local launch_or_focus_browser = "omarchy-launch-or-focus 'google-chrome' 'omarchy-launch-browser'"
hl.unbind("SUPER + SHIFT + RETURN")
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + RETURN", "Focus or launch browser", launch_or_focus_browser)
o.bind("SUPER + SHIFT + B", "Focus or launch browser", launch_or_focus_browser)

-- Hyper+X matches the macOS screenshot binding, with SUPER standing in for Cmd.
o.bind("SUPER + CTRL + SHIFT + ALT + X", "Screenshot", "omarchy-capture-screenshot")

-- SUPER+/ runs Voxtype after replacing Omarchy's monitor-scaling binding.
hl.unbind("SUPER + SLASH")
o.bind("SUPER + SLASH", "Voxtype dictation", "voxtype record toggle")
