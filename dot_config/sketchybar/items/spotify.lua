local constants = require("constants")
local settings = { colors = require("config.colors") }

local isPlaying = false
local isSpotifyRunning = false
local lastTrackInfo = ""
local lastClickTime = 0

-- Detect if we have ONLY the built-in display (no external monitors)
local function isOnlyBuiltInDisplay()
	-- Count total displays - if only 1, then no external monitor connected
	local handle = io.popen("system_profiler SPDisplaysDataType 2>/dev/null | grep 'Display Type:' | wc -l")
	local result = handle:read("*a")
	handle:close()
	local displayCount = tonumber(result) or 0
	return displayCount == 1
end

-- Determine position based on display configuration
-- If only built-in (no external): use "left" position to avoid camera notch
-- If external monitor connected: use "center" (original behavior)
local isOnlyBuiltIn = isOnlyBuiltInDisplay()
local position = isOnlyBuiltIn and "left" or "center"
print("Spotify widget - Only built-in display: " .. tostring(isOnlyBuiltIn) .. ", position: " .. position)

-- Album artwork widget (appears on left)
local spotifyIcon = sbar.add("item", constants.items.SPOTIFY .. ".icon", {
	position = position,
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
	position = position,
	update_freq = 15,
	scroll_texts = true,
	padding_right = 0,
	padding_left = 0,
})

-- Separate play/pause icon widget (can be positioned independently)
local playIcon = sbar.add("item", constants.items.SPOTIFY .. ".play", {
	position = position,
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

		sbar.exec("osascript -e '" .. spotifyScript .. "'", function(_result)
			local status = _result:match("^[^\n]*") -- Get first line, remove newlines

			if status == "not_running" or status == "stopped" or status == "" then
				if isSpotifyRunning then -- Only update if state changed
					spotify:set({ drawing = false })
					spotifyIcon:set({ drawing = false })
					playIcon:set({ drawing = false })
					isSpotifyRunning = false
					lastTrackInfo = "" -- Reset cache
				end
				return
			end

			local parts = {}
			for part in status:gmatch("[^|]+") do
				table.insert(parts, part)
			end

			local playerState = parts[1]
			local trackName = parts[2] or "Unknown Track"
			local artistName = parts[3] or "Unknown Artist"
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
				local displayText
				if trackName == "0" and albumName ~= "" then
					-- Podcast: show album (podcast title) - artist (episode title)
					displayText = albumName .. " - " .. artistName
					print(
						"Podcast detected: "
							.. displayText
							.. " | Artwork: "
							.. (artworkUrl ~= "" and "available" or "none")
					)
				else
					-- Music: show artist - track
					displayText = artistName .. " - " .. trackName
					print(
						"Music detected: "
							.. displayText
							.. " | Artwork: "
							.. (artworkUrl ~= "" and "available" or "none")
					)
				end
				local playIconString = isPlaying and "⏸" or "▶"
				local playIconSize = isPlaying and "20.0" or "18.0" -- Larger pause icon
				local color = isPlaying and settings.colors.orange or settings.colors.dirty_white

				-- Always show Spotify icon first
				spotifyIcon:set({
					drawing = true,
					icon = {
						string = "􀑬",
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
				if artworkUrl ~= "" then
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

spotify:subscribe("routine", updateSpotifyInfo)

spotify:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'", function()
		lastTrackInfo = ""
		updateSpotifyInfo()
	end)
end)

spotifyIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'", function()
		lastTrackInfo = ""
		updateSpotifyInfo()
	end)
end)

playIcon:subscribe("mouse.clicked", function()
	local currentTime = os.time()
	if currentTime - lastClickTime < 1 then
		return
	end
	lastClickTime = currentTime

	sbar.exec("osascript -e 'tell application \"Spotify\" to playpause'", function()
		lastTrackInfo = ""
		updateSpotifyInfo()
	end)
end)

updateSpotifyInfo()
