{ lib, pkgs, ... }:

let
  # Spotify's web player needs Widevine, which Helium (ungoogled-chromium) does not ship.
  chromePolicy = (pkgs.formats.plist { }).generate "com.google.Chrome.plist" {
    WebAppInstallForceList = [
      {
        url = "https://open.spotify.com/";
        default_launch_container = "window";
        custom_name = "Spotify";
      }
    ];
  };
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -m 0755 "/Library/Managed Preferences"
    /usr/bin/install -m 0644 ${chromePolicy} "/Library/Managed Preferences/com.google.Chrome.plist"
    # Direct plist replacement bypasses cfprefsd's cache, so refresh it before Chrome reads policy.
    /usr/bin/killall cfprefsd 2>/dev/null || true
  '';
}
