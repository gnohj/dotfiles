{ config, ... }:

# Only root can read the plist mapping the interface's private MAC to the connected SSID; one read-only command.

{
  security.sudo.extraConfig = ''
    ${config.system.primaryUser} ALL=(root) NOPASSWD: /usr/bin/plutil -p /Library/Preferences/com.apple.wifi.known-networks.plist
  '';
}
