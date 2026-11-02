on open location theURL
	set pwaBundle to my plistValue("PWABundleIdentifier")
	set urlPrefix to my plistValue("PWAURLPrefix")
	set w to my pwaWindow(urlPrefix)
	if w is missing value then
		do shell script "open -b " & quoted form of pwaBundle
		repeat 80 times
			delay 0.25
			set w to my pwaWindow(urlPrefix)
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
	do shell script "open -b " & quoted form of pwaBundle
end open location

on plistValue(theKey)
	set plistPath to POSIX path of (path to me) & "Contents/Info.plist"
	return do shell script "/usr/libexec/PlistBuddy -c " & quoted form of ("Print :" & theKey) & " " & quoted form of plistPath
end plistValue

on pwaWindow(urlPrefix)
	tell application "Helium"
		repeat with w in windows
			if URL of active tab of w starts with urlPrefix then return w
		end repeat
	end tell
	return missing value
end pwaWindow
