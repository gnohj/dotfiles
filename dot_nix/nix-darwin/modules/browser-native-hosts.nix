{ config, lib, pkgs, ... }:

let
  homeDir = if config ? users && config.users ? users && config.users.users ? ${config.system.primaryUser}
            then config.users.users.${config.system.primaryUser}.home
            else "/Users/${config.system.primaryUser}";

  # Chrome's per-user NativeMessagingHosts dir is TCC-protected, so register system-wide instead.
  workSso = pkgs.writeText "com.gnohj.work_sso.json" (builtins.toJSON {
    name = "com.gnohj.work_sso";
    description = "rbw-backed sign-in for the work-sso extension";
    path = "${homeDir}/.local/bin/work-sso-host";
    type = "stdio";
    allowed_origins = [ "chrome-extension://gegiapleohehjdeihffcacffdennkbpn/" ];
  });
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -m 0755 /Library/Google/Chrome/NativeMessagingHosts
    /usr/bin/install -m 0644 ${workSso} /Library/Google/Chrome/NativeMessagingHosts/com.gnohj.work_sso.json
  '';
}
