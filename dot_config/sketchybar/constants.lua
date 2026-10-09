local events <const> = {
	RIFT_WORKSPACE_CHANGED = "rift_workspace_changed",
	SWAP_MENU_AND_SPACES = "swap_menu_and_spaces",
	FRONT_APP_SWITCHED = "front_app_switched",
	UPDATE_WINDOWS = "update_windows",
	SEND_MESSAGE = "send_message",
	HIDE_MESSAGE = "hide_message",
	SCHEDULES_TOGGLE = "schedules_toggle",
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
	BLUETOOTH = "widgets.bluetooth",
	VPN = "widgets.vpn",
	TAILSCALE = "widgets.tailscale",
	MEMORY = "widgets.memory",
	DISK = "widgets.disk",
	UPTIME = "widgets.uptime",
	CPU = "widgets.cpu",
	GITHUB_NOTIFICATION = "widgets.github_notification",
	PR_REVIEW_NOTIFICATION = "widgets.pr_review_notification",
	BREW_NOTIFICATION = "widgets.brew_notification",
	MISE_NOTIFICATION = "widgets.mise_notification",
	MAS_NOTIFICATION = "widgets.mas_notification",
	BATTERY = "widgets.battery",
	CALENDAR = "widgets.calendar",
	SCHEDULES = "widgets.schedules",
}

-- Window manager queries go through lib/rift.lua (rift-cli)

return {
	items = items,
	events = events,
}
