property discordApp : "net.imput.helium.app.pliiebkcmokkgndfalahlmimanmbjlab"

on open location theURL
	set w to my discordWindow()
	if w is missing value then
		do shell script "open -b " & discordApp
		repeat 80 times
			delay 0.25
			set w to my discordWindow()
			if w is not missing value then
				tell application "Helium" to set stillLoading to loading of active tab of w
				if not stillLoading then exit repeat
			end if
		end repeat
		if w is missing value then return
		delay 1
	end if
	tell application "Helium"
		set URL of active tab of w to theURL
		set index of w to 1
	end tell
	do shell script "open -b " & discordApp
end open location

on discordWindow()
	tell application "Helium"
		repeat with w in windows
			if URL of active tab of w starts with "https://discord.com/" then return w
		end repeat
	end tell
	return missing value
end discordWindow
