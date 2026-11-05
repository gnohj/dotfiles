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
  };
  # A macOS update can wipe Managed Preferences, so restore the policy whenever it drifts.
  installHeliumPolicy = pkgs.writeShellScript "install-helium-policy" ''
    helium_policy="/Library/Managed Preferences/net.imput.helium.plist"
    if ! /usr/bin/cmp -s ${heliumPolicy} "$helium_policy"; then
      /usr/bin/install -d -m 0755 "/Library/Managed Preferences"
      /usr/bin/install -m 0644 ${heliumPolicy} "$helium_policy"
      # Direct plist replacement bypasses cfprefsd's cache, so refresh it before Helium reads policy.
      /usr/bin/killall cfprefsd 2>/dev/null || true
      echo "$(/bin/date '+%F %T') Helium policy restored: restart Helium if it is running." >&2
    fi
  '';
in
{
  # The script only writes on change, so a running Helium never sees a needless policy reload.
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
