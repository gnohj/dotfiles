tell application "System Events"
    if (name of processes) contains "Ghostty" then
        tell process "Ghostty"
            keystroke "," using {command down, shift down} -- cmd+shift+,
        end tell
    end if
end tell
