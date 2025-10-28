local events <const> = {
	AEROSPACE_WORKSPACE_CHANGED = "aerospace_workspace_changed",
	AEROSPACE_SWITCH = "aerospace_switch",
	SWAP_MENU_AND_SPACES = "swap_menu_and_spaces",
	FRONT_APP_SWITCHED = "front_app_switched",
	UPDATE_WINDOWS = "update_windows",
	SEND_MESSAGE = "send_message",
	HIDE_MESSAGE = "hide_message",
}

local items <const> = {
	SPACES = "workspaces",
	MENU = "menu",
	SPOTIFY = "spotify",
	MENU_TOGGLE = "menu_toggle",
	FRONT_APPS = "front_apps",
	MESSAGE = "message",
	VOLUME = "widgets.volume",
	WIFI = "widgets.wifi",
	MEMORY = "widgets.memory",
	CPU = "widgets.cpu",
	GITHUB_NOTIFICATION = "widgets.github_notification",
	BREW_NOTIFICATION = "widgets.brew_notification",
	MISE_NOTIFICATION = "widgets.mise_notification",
	MAS_NOTIFICATION = "widgets.mas_notification",
	BATTERY = "widgets.battery",
	CALENDAR = "widgets.calendar",
}

-- aerospace CLI commands removed - now using AeroSpaceLua socket connection
-- See lib/aerospace.lua for socket-based implementation

return {
	items = items,
	events = events,
}
