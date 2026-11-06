on open location theURL
	set urlPrefix to my plistValue("PWAURLPrefix")
	set theURL to my stripScheme(theURL)
	set pwaBundle to my pwaBundleId(urlPrefix)
	if pwaBundle is "" then
		display notification "No Helium app installed for " & urlPrefix with title "PWA link"
		return
	end if
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
	try
		return do shell script "/usr/libexec/PlistBuddy -c " & quoted form of ("Print :" & theKey) & " " & quoted form of plistPath
	on error
		return ""
	end try
end plistValue

-- A browser extension wraps links as <scheme>:<https url>, so unwrap before loading.
on stripScheme(theURL)
	set schemeName to my plistValue("PWAScheme")
	if schemeName is not "" and theURL starts with (schemeName & ":") then
		return text ((length of schemeName) + 2) thru -1 of theURL
	end if
	return theURL
end stripScheme

-- Reinstalling a PWA mints a new bundle id, so find the shim by its start URL each time.
on pwaBundleId(urlPrefix)
	set script_ to "for a in \"$HOME/Applications/Chromium Apps.localized\"/*.app; do p=\"$a/Contents/Info.plist\"; case \"$(/usr/libexec/PlistBuddy -c 'Print :CrAppModeShortcutURL' \"$p\" 2>/dev/null)\" in \"$1\"*) /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$p\"; exit 0;; esac; done"
	return do shell script "/bin/sh -c " & quoted form of script_ & " sh " & quoted form of urlPrefix
end pwaBundleId

on pwaWindow(urlPrefix)
	tell application "Helium"
		repeat with w in windows
			if URL of active tab of w starts with urlPrefix then return w
		end repeat
	end tell
	return missing value
end pwaWindow
