local constants = require("constants")
local settings = { colors = require("config.colors") }

local isPlaying = false
local isSpotifyRunning = false
local lastTrackInfo = ""
local lastClickTime = 0
local currentPosition = "center" -- Track current position to avoid redundant updates

-- Setup logging
local LOG_DIR = os.getenv("HOME") .. "/.logs/sketchybar"
local LOG_FILE = LOG_DIR .. "/spotify_" .. os.date("%Y%m") .. ".log"

local function log_message(level, message)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("[%s] [%s] [SPOTIFY] %s\n", timestamp, level, message)
	-- Write directly to file
	local file = io.open(LOG_FILE, "a")
	if file then
		file:write(log_entry)
		file:close()
	end
end

-- Function to detect external monitors
-- Reads status file written by check-external-monitor.sh
local function hasExternalMonitor()
	-- Read status from file (sbar.exec doesn't work reliably)
	local status_file = "/tmp/sketchybar_external_monitor"
	local file = io.open(status_file, "r")

	if not file then
		-- File doesn't exist yet, run detection script
		local config_dir = os.getenv("HOME") .. "/.config/sketchybar"
		os.execute("bash " .. config_dir .. "/check-external-monitor.sh &")
		log_message("DEBUG", "Status file missing, running detection script")
		return false
	end

	local result = file:read("*line")
	file:close()

	local hasExternal = tonumber(result) or 0
	log_message("DEBUG", "External monitor detection from file: '" .. tostring(result) .. "' hasExternal: " .. tostring(hasExternal))

	if hasExternal > 0 then
		log_message("INFO", "External monitor detected")
		return true
	end

	log_message("INFO", "No external monitor detected (built-in display only)")
	return false
end

-- Function to update widget positions based on monitor setup
local function updateWidgetPosition()
	local hasExternal = hasExternalMonitor()
	local newPosition = hasExternal and "center" or "left"

	log_message("INFO", "updateWidgetPosition called - hasExternal: " .. tostring(hasExternal) .. ", newPosition: " .. newPosition .. ", currentPosition: " .. currentPosition)

	-- Only update if position actually changed
	if newPosition ~= currentPosition then
		local oldPosition = currentPosition
		currentPosition = newPosition
		log_message("WARN", "Display configuration changed - moving Spotify from " .. oldPosition .. " to " .. newPosition)

		-- Update individual item positions AND the bracket using sketchybar commands
		-- (Lua API doesn't reliably update positions at runtime)
		log_message("DEBUG", "Executing sketchybar CLI commands to update positions")
		sbar.exec("sketchybar --set " .. constants.items.SPOTIFY .. ".icon position=" .. newPosition)
		sbar.exec("sketchybar --set " .. constants.items.SPOTIFY .. " position=" .. newPosition)
		sbar.exec("sketchybar --set " .. constants.items.SPOTIFY .. ".play position=" .. newPosition)
		sbar.exec("sketchybar --set " .. constants.items.SPOTIFY .. ".bracket position=" .. newPosition)

		log_message("INFO", "Successfully updated position to " .. newPosition)
	else
		log_message("DEBUG", "Position unchanged, staying at: " .. currentPosition)
	end
end

-- Register the Spotify playback state changed event
-- Delay event registration to avoid deadlock during init
sbar.exec("sleep 0.1 && sketchybar --add event spotify_change com.spotify.client.PlaybackStateChanged")

-- Register display change event
-- Delay event registration to avoid deadlock during init
sbar.exec("sleep 0.1 && sketchybar --add event display_change")

-- Determine initial position based on current display setup
log_message("INFO", "Initializing Spotify widget")
local initialPosition = hasExternalMonitor() and "center" or "left"
currentPosition = initialPosition
log_message("INFO", "Initial position set to: " .. initialPosition)

-- Album artwork widget (appears on left)
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
			scale = 0.05,
			drawing = false,
		},
		drawing = true,
	},
})

-- Main text widget (without play/pause icon)
local spotify = sbar.add("item", constants.items.SPOTIFY, {
	position = initialPosition,
	scroll_texts = true,
	padding_right = 0,
	padding_left = 0,
	updates = true,
	update_freq = 3,  -- Poll every 3 seconds
})

-- Separate play/pause icon widget (can be positioned independently)
local playIcon = sbar.add("item", constants.items.SPOTIFY .. ".play", {
	position = initialPosition,
	y_offset = -1.75,
	padding_left = -18,
	padding_right = 0,
	drawing = false,
})

local function updateSpotifyInfo()
	-- Quick check first - avoid AppleScript if Spotify isn't running
	sbar.exec("pgrep -x Spotify", function(result)
		if result == "" then
			if isSpotifyRunning then -- Only update if state changed
				spotify:set({ drawing = false })
				spotifyIcon:set({ drawing = false })
				playIcon:set({ drawing = false })
				isSpotifyRunning = false
				lastTrackInfo = "" -- Reset cache
			end
			return
		end

		isSpotifyRunning = true

		-- Only run AppleScript if Spotify is actually running
		local spotifyScript = [[
			tell application "System Events"
				if exists (processes where name is "Spotify") then
					tell application "Spotify"
						if player state is playing then
							set trackName to name of current track
							set artistName to artist of current track
							set albumName to album of current track
							set artworkUrl to artwork url of current track
							return "playing|" & trackName & "|" & artistName & "|" & albumName & "|" & artworkUrl
						else if player state is paused then
							set trackName to name of current track
							set artistName to artist of current track
							set albumName to album of current track
							set artworkUrl to artwork url of current track
							return "paused|" & trackName & "|" & artistName & "|" & albumName & "|" & artworkUrl
						else
							return "stopped"
						end if
					end tell
				else
					return "not_running"
				end if
			end tell
		]]

		-- Wrap osascript in a timeout to prevent hanging (5 second timeout)
		local timeoutCmd = [[
			(
				osascript -e ']] .. spotifyScript .. [[' &
				pid=$!
				( sleep 5; kill -9 $pid 2>/dev/null ) &
				wait $pid 2>/dev/null
			)
		]]

		sbar.exec(timeoutCmd, function(_result)
			local status = _result:match("^[^\n]*") -- Get first line, remove newlines

			-- Handle timeout or errors gracefully
			if status == "not_running" or status == "stopped" or status == "" or status == nil then
				if status == nil or status == "" then
					log_message("WARN", "AppleScript timed out or returned empty result")
				end
				if isSpotifyRunning then -- Only update if state changed
					spotify:set({ drawing = false })
					spotifyIcon:set({ drawing = false })
					playIcon:set({ drawing = false })
					isSpotifyRunning = false
					lastTrackInfo = "" -- Reset cache
				end
				return
			end

			-- Split by | while preserving empty fields
			local parts = {}
			local start = 1
			while true do
				local pipePos = status:find("|", start, true)
				if not pipePos then
					table.insert(parts, status:sub(start))
					break
				end
				table.insert(parts, status:sub(start, pipePos - 1))
				start = pipePos + 1
			end

			local playerState = parts[1] or ""
			local trackName = parts[2] or "Unknown Track"
			local artistName = parts[3] or "" -- Empty for podcasts
			local albumName = parts[4] or ""
			local artworkUrl = parts[5] or ""

			-- Create unique identifier for current state
			local currentTrackInfo = trackName
				.. "|"
				.. artistName
				.. "|"
				.. albumName
				.. "|"
				.. playerState
				.. "|"
				.. artworkUrl

			-- Only update UI if something actually changed
			if currentTrackInfo ~= lastTrackInfo then
				lastTrackInfo = currentTrackInfo

				isPlaying = playerState == "playing"

				-- Handle podcast vs music display logic
				-- Podcasts have empty artist name
				local displayText
				local isPodcast = (artistName == "" or artistName == nil)

				if isPodcast then
					-- Podcast: show album (podcast title) - track (episode title)
					displayText = albumName .. " - " .. trackName
					local artworkStatus = (artworkUrl ~= "" and artworkUrl ~= "none" and "available" or "none")
					log_message("INFO", "Podcast detected: " .. displayText .. " | Artwork: " .. artworkStatus)
					print("Podcast detected: " .. displayText .. " | Artwork: " .. artworkStatus)
				else
					-- Music: show artist - track
					displayText = artistName .. " - " .. trackName
					local artworkStatus = (artworkUrl ~= "" and artworkUrl ~= "none" and "available" or "none")
					log_message("INFO", "Music detected: " .. displayText .. " | Artwork: " .. artworkStatus)
					print("Music detected: " .. displayText .. " | Artwork: " .. artworkStatus)
				end
				local playIconString = isPlaying and "⏸" or "▶"
				local playIconSize = isPlaying and "20.0" or "18.0" -- Larger pause icon
				local color = isPlaying and settings.colors.orange or settings.colors.dirty_white

				-- Show icon based on content type (podcast or music)
				-- Will be updated with artwork if available, otherwise fallback icon
				local hasArtwork = artworkUrl ~= "" and artworkUrl ~= "none" and not artworkUrl:match("missing")
				local iconString = (isPodcast and not hasArtwork) and "🎙" or "􀑬"
				spotifyIcon:set({
					drawing = true,
					icon = {
						string = iconString,
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

				-- Update icon with album cover if available
				-- Check for valid URL (not empty and not "none" or "missing value")
				if artworkUrl ~= "" and artworkUrl ~= "none" and not artworkUrl:match("missing") then
					-- Create a unique file path for the artwork based on URL hash
					local urlHash = string.gsub(artworkUrl, "[^%w]", "")
					local artworkPath = "/tmp/spotify_" .. urlHash .. ".jpg"

					-- Download the artwork
					sbar.exec("curl -s -L -o '" .. artworkPath .. "' '" .. artworkUrl .. "'", function()
						-- Check if file exists and has content
						sbar.exec("ls -la '" .. artworkPath .. "'", function(lsResult)
							if lsResult ~= "" and not lsResult:match("No such file") then
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
											scale = 0.05,
											drawing = true,
										},
									},
								})
							end
						end)
					end)
				end

				-- Update main widget (now shows only text)
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
						string = "", -- No label on main widget
					},
				})

				-- Update separate play icon widget
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
			end
		end)
	end)
end

-- Subscribe to Spotify playback state change event (event-driven, no polling)
spotify:subscribe("spotify_change", function(env)
	log_message("INFO", "Event triggered: spotify_change - Spotify playback state changed")
	updateSpotifyInfo()
end)

-- Subscribe to polling event
spotify:subscribe("spotify_poll", function()
	log_message("DEBUG", "Event triggered: spotify_poll - Manual poll requested")
	updateSpotifyInfo()
end)

-- Also subscribe to system wake event to refresh state and position
spotify:subscribe("system_woke", function()
	log_message("INFO", "Event triggered: system_woke - Refreshing state and position")
	updateSpotifyInfo()
	updateWidgetPosition()
end)

spotify:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		log_message("DEBUG", "Event triggered: mouse.clicked on spotify (debounced)")
		return
	end
	lastClickTime = currentTime

	log_message("INFO", "Event triggered: mouse.clicked on spotify - toggling play/pause")
	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

spotifyIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		log_message("DEBUG", "Event triggered: mouse.clicked on spotify.icon (debounced)")
		return
	end
	lastClickTime = currentTime

	log_message("INFO", "Event triggered: mouse.clicked on spotify.icon - toggling play/pause")
	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

playIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		log_message("DEBUG", "Event triggered: mouse.clicked on spotify.play (debounced)")
		return
	end
	lastClickTime = currentTime

	log_message("INFO", "Event triggered: mouse.clicked on spotify.play - toggling play/pause")
	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

-- Group Spotify widgets together using a bracket
sbar.add("bracket", constants.items.SPOTIFY .. ".bracket", {
	constants.items.SPOTIFY .. ".icon",
	constants.items.SPOTIFY,
	constants.items.SPOTIFY .. ".play",
}, {
	position = initialPosition,
})

-- Start display monitor in background
local config_dir = os.getenv("HOME") .. "/.config/sketchybar"
log_message("INFO", "Starting display monitor background process")
sbar.exec("pkill -f display-monitor.sh; " .. config_dir .. "/display-monitor.sh &")

-- Initial update on load
log_message("INFO", "Running initial widget updates")
updateSpotifyInfo()
updateWidgetPosition()
log_message("INFO", "Spotify widget initialization complete")

-- Subscribe to display change events
spotify:subscribe("display_change", function()
	log_message("WARN", "Event triggered: display_change - Display configuration changed")
	updateWidgetPosition()
end)

-- Polling fallback: update on the regular update_freq interval
spotify:subscribe("front_app_switched", function()
	log_message("DEBUG", "Event triggered: front_app_switched - Updating Spotify info")
	updateSpotifyInfo()
end)
