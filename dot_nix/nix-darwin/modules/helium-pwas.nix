{ lib, pkgs, ... }:

let
  heliumPolicy = (pkgs.formats.plist { }).generate "net.imput.helium.plist" {
    WebAppInstallForceList = [
      {
        url = "https://discord.com/app";
        default_launch_container = "window";
        install_as_shortcut = true;
        custom_name = "Discord";
      }
      {
        url = "https://teams.microsoft.com/v2/";
        default_launch_container = "window";
        custom_name = "Microsoft Teams";
      }
      {
        url = "https://outlook.office.com/mail/";
        default_launch_container = "window";
        custom_name = "Outlook";
      }
      {
        url = "https://www.reddit.com/";
        default_launch_container = "window";
        custom_name = "Reddit";
      }
      {
        url = "https://app.slack.com/client";
        default_launch_container = "window";
        custom_name = "Slack";
      }
      {
        url = "https://www.twitch.tv/";
        default_launch_container = "window";
        custom_name = "Twitch";
      }
      {
        url = "https://x.com/?utm_source=homescreen&utm_medium=shortcut";
        default_launch_container = "window";
        custom_name = "X";
      }
      {
        url = "https://www.youtube.com/?feature=ytca";
        default_launch_container = "window";
        custom_name = "YouTube";
      }
      {
        url = "https://app.zoom.us/wc";
        default_launch_container = "window";
        custom_name = "Zoom";
      }
    ];
  };
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -m 0755 "/Library/Managed Preferences"
    /usr/bin/install -m 0644 ${heliumPolicy} "/Library/Managed Preferences/net.imput.helium.plist"
    # Direct plist replacement bypasses cfprefsd's cache, so refresh it before Helium reads policy.
    /usr/bin/killall cfprefsd 2>/dev/null || true
  '';
}
