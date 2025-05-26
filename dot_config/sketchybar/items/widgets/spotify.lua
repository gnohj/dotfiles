local constants = require("constants")
local settings = require("config.settings")

local isPlaying = false
local currentTrack = ""

local spotifyConfig = {
	app = "Spotify", -- Use this for actual Spotify app icon
	-- icon = "", -- Use this for nerd font icon (comment out app line above)
}

local spotify = sbar.add("item", constants.items.SPOTIFY, {
	position = "right",
	update_freq = 5, -- Update every 5 seconds
	scroll_texts = true, -- Enable marquee scrolling
})

-- Spotify icon widget (create second, will appear to the left)
local spotifyIcon = sbar.add("item", constants.items.SPOTIFY .. ".icon", {
	position = "right",
	updates = "when_shown",
	padding_left = 3,
	padding_right = 3,
})

-- Configure the icon based on spotifyConfig
if spotifyConfig.app then
	-- Use app icon
	spotifyIcon:set({
		icon = { drawing = false },
		background = {
			height = 26,
			corner_radius = 9,
			border_width = 2,
			color = settings.colors.bg1,
			image = "app." .. spotifyConfig.app,
		},
	})
else
	-- Use nerd font icon
	spotifyIcon:set({
		icon = { color = settings.colors.bg1 },
		label = { color = settings.colors.bg1 },
		background = {
			height = 26,
			corner_radius = 9,
			border_width = 2,
			color = settings.colors.light_blue,
		},
	})
end

local spotifyPopup = sbar.add("item", {
	position = "popup." .. spotify.name,
	width = "dynamic",
	label = {
		padding_right = settings.dimens.padding.label,
		padding_left = settings.dimens.padding.label,
		max_chars = 50,
	},
	icon = {
		padding_left = 0,
		padding_right = 0,
	},
})

local function updateSpotifyInfo()
	-- AppleScript to get Spotify info
	local spotifyScript = [[
		tell application "System Events"
			if exists (processes where name is "Spotify") then
				tell application "Spotify"
					if player state is playing then
						set trackName to name of current track
						set artistName to artist of current track
						return "playing|" & trackName & "|" & artistName
					else if player state is paused then
						set trackName to name of current track
						set artistName to artist of current track
						return "paused|" & trackName & "|" & artistName
					else
						return "stopped"
					end if
				end tell
			else
				return "not_running"
			end if
		end tell
	]]

	sbar.exec("osascript -e '" .. spotifyScript .. "'", function(result)
		local status = result:match("^[^\n]*") -- Get first line, remove newlines

		if status == "not_running" or status == "stopped" or status == "" then
			-- Hide both Spotify widgets when not running or stopped
			spotify:set({ drawing = false })
			spotifyIcon:set({ drawing = false })
			return
		end

		local parts = {}
		for part in status:gmatch("[^|]+") do
			table.insert(parts, part)
		end

		local playerState = parts[1]
		local trackName = parts[2] or "Unknown Track"
		local artistName = parts[3] or "Unknown Artist"

		isPlaying = playerState == "playing"
		currentTrack = trackName .. " - " .. artistName

		-- Use full track name for scrolling (don't truncate)
		local displayText = trackName .. " - " .. artistName

		local playIcon = isPlaying and "⏸" or "▶" -- Pause icon when playing, play icon when paused

		local color = isPlaying and settings.colors.green or settings.colors.dirty_white

		-- Show Spotify icon
		spotifyIcon:set({ drawing = true })

		-- Update main widget
		spotify:set({
			drawing = true,
			icon = {
				string = playIcon,
				color = color,
			},
			label = {
				string = displayText,
				color = isPlaying and settings.colors.light_blue or settings.colors.dirty_white,
				padding_left = 5,
				max_chars = 20, -- Set a max width to trigger scrolling
			},
		})
	end)
end

-- Subscribe to routine updates
spotify:subscribe("routine", updateSpotifyInfo)

-- Click handlers for both items
spotify:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "left" then
		local drawing = spotify:query().popup.drawing
		spotify:set({ popup = { drawing = "toggle" } })

		if drawing == "off" then
			spotifyPopup:set({
				label = { string = currentTrack },
				icon = { string = "🎵" },
			})
		end
	elseif env.BUTTON == "right" then
		sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'", function()
			updateSpotifyInfo()
		end)
	end
end)

spotifyIcon:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'", function()
			updateSpotifyInfo()
		end)
	end
end)

-- Update immediately when script loads
updateSpotifyInfo()
