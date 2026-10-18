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
local artworkTrack
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

local GLYPH_SPOTIFY = utf8.char(0xF04C7)
local GLYPH_PODCAST = utf8.char(0xF0994)
local fallbackGlyph = GLYPH_SPOTIFY

local spotifyIcon = sbar.add("item", constants.items.SPOTIFY .. ".icon", {
	position = initialPosition,
	padding_left = 0,
	padding_right = 0,
	drawing = false,
	icon = {
		string = GLYPH_SPOTIFY,
		color = settings.colors.cyan,
		font = { size = 14.0 },
		width = 34,
		padding_left = 0,
		padding_right = 0,
		background = { drawing = false, image = { corner_radius = 3, scale = 0.56, padding_left = 10 } },
	},
	label = { drawing = false },
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
	icon = { drawing = false },
	label = { font = { size = 14.0 }, max_chars = 22, padding_left = 0, padding_right = 6 },
})

local playIcon = sbar.add("item", constants.items.SPOTIFY .. ".play", {
	position = initialPosition,
	padding_left = 0,
	padding_right = 0,
	drawing = false,
	icon = { font = { size = 13.0 }, padding_left = 0, padding_right = 11 },
	label = { drawing = false },
})

local gap = sbar.add("item", constants.items.SPOTIFY .. ".gap", {
	position = initialPosition,
	drawing = false,
	width = 6,
	icon = { drawing = false },
	label = { drawing = false },
	padding_left = 0,
	padding_right = 0,
})

local bracket = sbar.add("bracket", constants.items.SPOTIFY .. ".bracket", {
	constants.items.SPOTIFY .. ".icon",
	constants.items.SPOTIFY,
	constants.items.SPOTIFY .. ".play",
}, {
	position = initialPosition,
	background = {
		height = 24,
		corner_radius = 12,
		border_width = 1,
		color = settings.colors.transparent,
		border_color = settings.colors.with_alpha(settings.colors.dark_grey, 0.5),
	},
})

local function hideWidget()
	if isSpotifyRunning then
		spotify:set({ drawing = false })
		spotifyIcon:set({ drawing = false })
		playIcon:set({ drawing = false })
		gap:set({ drawing = false })
		isSpotifyRunning = false
		lastTrackInfo = ""
		artworkTrack = nil
	end
end

local function applyArtwork(trackKey, trackInfo)
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
		if artworkTrack ~= trackInfo or not isSpotifyRunning then
			return
		end
		if not result or not result:match("ok") then
			artworkTrack = nil
			spotifyIcon:set({ icon = { string = fallbackGlyph, background = { drawing = false } } })
			return
		end
		spotifyIcon:set({
			drawing = true,
			icon = { string = "", background = { drawing = true, image = { string = artworkPath } } },
		})
	end)
end

-- SbarLua already decodes JSON stdout into a table; a string only arrives if that failed.
local function spotifyTrack(result)
	local data = result
	if type(data) == "string" then
		local ok, decoded = pcall(cjson.decode, data)
		data = ok and decoded or nil
	end
	if type(data) ~= "table" or not spotifyBundleIds[data.bundleIdentifier or ""] or (data.title or "") == "" then
		return nil
	end
	return data
end

-- Now Playing goes blank for a moment between tracks, so only hide once it stays blank.
local hidePending = false
local function requestHide()
	if not isSpotifyRunning or hidePending then
		return
	end
	hidePending = true
	sbar.exec("sleep 2; " .. MEDIA_CONTROL .. " get --no-artwork 2>/dev/null", function(result)
		hidePending = false
		if not spotifyTrack(result) then
			hideWidget()
		end
	end)
end

local function updateSpotifyInfo()
	sbar.exec(MEDIA_CONTROL .. " get --no-artwork 2>/dev/null", function(result)
		local data = spotifyTrack(result)
		if not data then
			requestHide()
			return
		end

		local trackName = data.title

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

		local color = isPlaying and settings.colors.cyan or settings.colors.dark_grey

		fallbackGlyph = isPodcast and GLYPH_PODCAST or GLYPH_SPOTIFY
		spotifyIcon:set({ drawing = true, icon = { color = color } })

		local trackInfo = trackName .. "|" .. artistName .. "|" .. albumName
		if artworkTrack ~= trackInfo then
			artworkTrack = trackInfo
			applyArtwork((trackInfo:gsub("[^%w]", "")), trackInfo)
		end

		spotify:set({
			drawing = true,
			label = { string = displayText, color = color },
		})

		gap:set({ drawing = true })

		playIcon:set({
			drawing = true,
			icon = { string = utf8.char(isPlaying and 0xF03E4 or 0xF040A), color = color },
		})

		bracket:set({
			background = {
				border_color = settings.colors.with_alpha(settings.colors.dark_grey, 0.5),
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

-- The widget no longer handles monitor changes, so a leftover display-monitor.sh has no consumer.
sbar.exec("pkill -f display-monitor.sh 2>/dev/null")

sbar.exec("/usr/bin/find /tmp -maxdepth 1 -name 'spotify_*.jpg' -mtime +1 -delete 2>/dev/null")

log_message("INFO", "Running initial widget update")
refreshSpotifyBundleIds()
updateSpotifyInfo()
log_message("INFO", "Spotify widget initialization complete")
