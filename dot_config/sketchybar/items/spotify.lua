local constants = require("constants")
local settings = { colors = require("config.colors") }
local cjson = require("cjson")

local MEDIA_CONTROL = "/opt/homebrew/bin/media-control"
local JQ = "/run/current-system/sw/bin/jq"
-- The PWA feed gives a 150px thumbnail (native gave 640px), so fix the size and render 1:1.
local ARTWORK_PX = 32

local isPlaying = false
local isSpotifyRunning = false
local lastTrackInfo = ""
local lastClickTime = 0
local spotifyBundleIds = { ["com.spotify.client"] = true }

local LOG_DIR = os.getenv("HOME") .. "/.logs/sketchybar"
local LOG_FILE = LOG_DIR .. "/spotify_" .. os.date("%Y%m") .. ".log"

local function log_message(level, message)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("[%s] [%s] [SPOTIFY] %s\n", timestamp, level, message)
	local file = io.open(LOG_FILE, "a")
	if file then
		file:write(log_entry)
		file:close()
	end
end

-- Now Playing is a global feed and PWA bundle ids are generated at install time, so discover them.
local function refreshSpotifyBundleIds()
	local discover = [[
		for app in "$HOME/Applications/"*"Apps.localized/"*.app; do
			case "$(basename "$app")" in
				*[Ss]potify*)
					/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null
					;;
			esac
		done
	]]

	sbar.exec(discover, function(result)
		local ids = { ["com.spotify.client"] = true }
		for id in (result or ""):gmatch("[^\r\n]+") do
			local trimmed = id:match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				ids[trimmed] = true
			end
		end
		spotifyBundleIds = ids
	end)
end

log_message("INFO", "Initializing Spotify widget")
local initialPosition = "left"

sbar.exec("sleep 0.1 && sketchybar --add event spotify_poll")

local spotifyIcon = sbar.add("item", constants.items.SPOTIFY .. ".icon", {
	position = initialPosition,
	padding_left = 1,
	padding_right = 5,
	drawing = false,
	icon = {
		string = "􀑬",
		color = settings.colors.blue,
		padding_right = 0,
		drawing = true,
	},
	background = {
		image = {
			corner_radius = 2,
			scale = 1.0,
			drawing = false,
		},
		drawing = true,
	},
})

local spotify = sbar.add("item", constants.items.SPOTIFY, {
	position = initialPosition,
	scroll_texts = true,
	padding_right = 0,
	padding_left = 0,
	drawing = false, -- start hidden like .icon/.play so no empty slot is reserved before the first update
	updates = true,
	-- spotify_poll from media-control-bridge is the real refresh; this is the dead-bridge safety net.
	update_freq = 30,
})

local playIcon = sbar.add("item", constants.items.SPOTIFY .. ".play", {
	position = initialPosition,
	y_offset = -1.75,
	padding_left = -18,
	padding_right = 0,
	drawing = false,
})

local function hideWidget()
	if isSpotifyRunning then
		spotify:set({ drawing = false })
		spotifyIcon:set({ drawing = false })
		playIcon:set({ drawing = false })
		isSpotifyRunning = false
		lastTrackInfo = ""
	end
end

local function applyArtwork(trackKey)
	local artworkPath = "/tmp/spotify_" .. trackKey .. ".jpg"
	local extract = MEDIA_CONTROL
		.. " get 2>/dev/null | "
		.. JQ
		.. " -r '.artworkData // empty' | /usr/bin/base64 -d > '"
		.. artworkPath
		.. ".part' 2>/dev/null; if [ -s '"
		.. artworkPath
		.. ".part' ]; then /usr/bin/sips -z "
		.. ARTWORK_PX
		.. " "
		.. ARTWORK_PX
		.. " '"
		.. artworkPath
		.. ".part' >/dev/null 2>&1; /bin/mv '"
		.. artworkPath
		.. ".part' '"
		.. artworkPath
		.. "'; echo ok; else /bin/rm -f '"
		.. artworkPath
		.. ".part'; fi"

	sbar.exec(extract, function(result)
		if not result or not result:match("ok") then
			return
		end
		spotifyIcon:set({
			drawing = true,
			icon = {
				drawing = false,
			},
			background = {
				height = 16,
				image = {
					string = artworkPath,
					corner_radius = 2,
					scale = 1.0,
					drawing = true,
				},
			},
		})
	end)
end

local function updateSpotifyInfo()
	sbar.exec(MEDIA_CONTROL .. " get --no-artwork 2>/dev/null", function(result)
		-- SbarLua already decodes JSON stdout into a table; a string only arrives if that failed.
		local data = result
		if type(data) == "string" then
			local ok, decoded = pcall(cjson.decode, data)
			data = ok and decoded or nil
		end

		if type(data) ~= "table" then
			hideWidget()
			return
		end

		if not spotifyBundleIds[data.bundleIdentifier or ""] then
			hideWidget()
			return
		end

		local trackName = data.title or ""
		if trackName == "" then
			hideWidget()
			return
		end

		isSpotifyRunning = true

		local artistName = data.artist or "" -- Empty for podcasts
		local albumName = data.album or ""
		local playerState = data.playing and "playing" or "paused"

		local currentTrackInfo = trackName .. "|" .. artistName .. "|" .. albumName .. "|" .. playerState

		if currentTrackInfo == lastTrackInfo then
			return
		end
		lastTrackInfo = currentTrackInfo

		isPlaying = data.playing == true

		-- Podcasts have empty artist name
		local displayText
		local isPodcast = artistName == ""

		if isPodcast then
			-- Ads carry neither artist nor album, so the separator would lead with a bare dash.
			displayText = albumName == "" and trackName or (albumName .. " - " .. trackName)
			log_message("INFO", "Podcast detected: " .. displayText)
		else
			-- Music: show artist - track
			displayText = artistName .. " - " .. trackName
			log_message("INFO", "Music detected: " .. displayText)
		end

		local playIconString = isPlaying and "⏸" or "▶"
		local playIconSize = isPlaying and "20.0" or "18.0"
		local color = isPlaying and settings.colors.orange or settings.colors.dirty_white

		spotifyIcon:set({
			drawing = true,
			icon = {
				string = isPodcast and "🎙" or "􀑬",
				color = settings.colors.blue,
				padding_right = 0,
				drawing = true,
			},
			background = {
				image = {
					drawing = false,
				},
			},
		})

		applyArtwork((currentTrackInfo:gsub("[^%w]", "")))

		spotify:set({
			drawing = true,
			icon = {
				string = displayText,
				color = isPlaying and settings.colors.light_blue or settings.colors.dirty_white,
				padding_left = 5,
				padding_right = 5,
				max_chars = 20,
			},
			label = {
				string = "",
			},
		})

		playIcon:set({
			drawing = true,
			icon = {
				string = playIconString,
				color = color,
				font = "SF Pro:Regular:" .. playIconSize,
				padding_left = 8,
				padding_right = 0,
			},
		})
	end)
end

spotify:subscribe({ "routine", "forced", "spotify_poll", "front_app_switched" }, function()
	updateSpotifyInfo()
end)

spotify:subscribe("system_woke", function()
	log_message("INFO", "Event triggered: system_woke - Refreshing state")
	refreshSpotifyBundleIds()
	updateSpotifyInfo()
end)

local function togglePlayback(source)
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		log_message("DEBUG", "Event triggered: mouse.clicked on " .. source .. " (debounced)")
		return
	end
	lastClickTime = currentTime

	log_message("INFO", "Event triggered: mouse.clicked on " .. source .. " - toggling play/pause")
	sbar.exec(MEDIA_CONTROL .. " toggle-play-pause")
	lastTrackInfo = ""
	-- Wait a bit for the player to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end

spotify:subscribe("mouse.clicked", function()
	togglePlayback("spotify")
end)

spotifyIcon:subscribe("mouse.clicked", function()
	togglePlayback("spotify.icon")
end)

playIcon:subscribe("mouse.clicked", function()
	togglePlayback("spotify.play")
end)

sbar.add("bracket", constants.items.SPOTIFY .. ".bracket", {
	constants.items.SPOTIFY .. ".icon",
	constants.items.SPOTIFY,
	constants.items.SPOTIFY .. ".play",
}, {
	position = initialPosition,
})

-- The widget no longer handles monitor changes, so a leftover display-monitor.sh has no consumer.
sbar.exec("pkill -f display-monitor.sh 2>/dev/null")

sbar.exec("/usr/bin/find /tmp -maxdepth 1 -name 'spotify_*.jpg' -mtime +1 -delete 2>/dev/null")

log_message("INFO", "Running initial widget update")
refreshSpotifyBundleIds()
updateSpotifyInfo()
log_message("INFO", "Spotify widget initialization complete")
