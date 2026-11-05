{ lib, pkgs, ... }:

let
  heliumPolicy = (pkgs.formats.plist { }).generate "net.imput.helium.plist" {
    # The teams-links extension hands /l/ links to msteams:, so skip the "Open msteams-handler?" prompt.
    AutoLaunchProtocolsFromOrigins = [
      {
        protocol = "msteams";
        allowed_origins = [ "*" ];
      }
    ];
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
        install_as_shortcut = true;
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
  # A macOS update can wipe Managed Preferences, and Helium then uninstalls its policy PWAs.
  installHeliumPolicy = pkgs.writeShellScript "install-helium-policy" ''
    helium_policy="/Library/Managed Preferences/net.imput.helium.plist"
    if ! /usr/bin/cmp -s ${heliumPolicy} "$helium_policy"; then
      /usr/bin/install -d -m 0755 "/Library/Managed Preferences"
      /usr/bin/install -m 0644 ${heliumPolicy} "$helium_policy"
      # Direct plist replacement bypasses cfprefsd's cache, so refresh it before Helium reads policy.
      /usr/bin/killall cfprefsd 2>/dev/null || true
      echo "$(/bin/date '+%F %T') Helium policy restored: restart Helium if it is running so it reinstalls dropped PWAs." >&2
    fi
  '';
in
{
  # Rewriting this under a running Helium can drop its PWAs, so the script only writes on change.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${installHeliumPolicy}
  '';

  # Runs at boot, before login, so Helium never starts without its policy.
  launchd.daemons.helium-policy = {
    serviceConfig = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${installHeliumPolicy}"
      ];
      RunAtLoad = true;
      StandardErrorPath = "/var/log/helium-policy.log";
    };
  };
}
