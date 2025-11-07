local constants = require("constants")
local settings = { colors = require("config.colors") }

local isPlaying = false
local isSpotifyRunning = false
local lastTrackInfo = ""
local lastClickTime = 0

-- Setup logging
local LOG_DIR = os.getenv("HOME") .. "/.logs/sketchybar"
local LOG_FILE = LOG_DIR .. "/spotify_" .. os.date("%Y%m") .. ".log"

local function log_message(level, message)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("[%s] [%s] [SPOTIFY] %s", timestamp, level, message)
	-- Use async to avoid blocking the event loop
	sbar.exec("mkdir -p " .. LOG_DIR)
	sbar.exec("echo '" .. log_entry:gsub("'", "'\\''") .. "' >> " .. LOG_FILE)
end

-- Register the Spotify playback state changed event
sbar.exec("sketchybar --add event spotify_change com.spotify.client.PlaybackStateChanged")

-- Album artwork widget (appears on left)
local spotifyIcon = sbar.add("item", constants.items.SPOTIFY .. ".icon", {
	position = "center",
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
	position = "center",
	scroll_texts = true,
	padding_right = 0,
	padding_left = 0,
	updates = true,
	update_freq = 3,  -- Poll every 3 seconds
})

-- Separate play/pause icon widget (can be positioned independently)
local playIcon = sbar.add("item", constants.items.SPOTIFY .. ".play", {
	position = "center",
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
	log_message("INFO", "Spotify playback state changed event received")
	updateSpotifyInfo()
end)

-- Subscribe to polling event
spotify:subscribe("spotify_poll", function()
	updateSpotifyInfo()
end)

-- Also subscribe to system wake event to refresh state
spotify:subscribe("system_woke", function()
	log_message("INFO", "System woke - refreshing Spotify state")
	updateSpotifyInfo()
end)

spotify:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

spotifyIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

playIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'")
	lastTrackInfo = ""
	-- Wait a bit for Spotify to update, then poll
	sbar.exec("sleep 0.3 && sketchybar --trigger spotify_poll")
end)

-- Initial update on load
updateSpotifyInfo()

-- Polling fallback: update on the regular update_freq interval
spotify:subscribe("front_app_switched", function()
	updateSpotifyInfo()
end)
