{ config, pkgs, lib, ... }:

# Disabled by default: launchd cannot spawn this dnsmasq successfully on
# macOS Sequoia (exits EX_CONFIG=78 with empty stderr; manual `sudo
# dnsmasq <same args>` runs fine). Suspected cause is launchd's sandbox
# profile blocking unsigned binaries from binding port 53 — fixable
# only by code-signing or switching to Homebrew dnsmasq.
#
# While in this state, leaving the /etc/resolver entries active drags
# every login by ~30s per `local.inferno.*` query against the dead
# 127.0.0.1 listener. Flip `enable = true` only after the spawn issue
# is resolved.

let
  cfg = config.local-dev-auth;

  # Wildcard-resolve `.local.*` subtrees to localhost so local Inferno
  # dev (Caddy on 127.0.0.1) can serve under real-shaped hostnames.
  dnsmasqConf = pkgs.writeText "dnsmasq.conf" ''
    address=/local.inferno.iheart.com/127.0.0.1
    address=/local.inferno.ihrint.com/127.0.0.1

    listen-address=127.0.0.1
    bind-interfaces

    # Return NXDOMAIN for anything outside the address= rules — macOS
    # only routes the configured subtrees here, so unknown queries are
    # a misroute, not something to forward.
    no-resolv
    no-hosts

    log-facility=/var/log/dnsmasq.log
  '';
in
{
  options.local-dev-auth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the dnsmasq + /etc/resolver stack for local Inferno
        dev. Off by default — see module header for the known launchd
        spawn issue.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.dnsmasq ];

    # These resolver entries are only useful while the dnsmasq daemon
    # below is actually running. Without it, lookups hang on the
    # 127.0.0.1 timeout — hence the enable gate.
    environment.etc."resolver/local.inferno.iheart.com".text = ''
      nameserver 127.0.0.1
    '';
    environment.etc."resolver/local.inferno.ihrint.com".text = ''
      nameserver 127.0.0.1
    '';

    # Runs as root because dnsmasq binds port 53.
    launchd.daemons.dnsmasq = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.dnsmasq}/bin/dnsmasq"
          "--keep-in-foreground"
          "--conf-file=${dnsmasqConf}"
        ];
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        RunAtLoad = true;
        StandardOutPath = "/var/log/dnsmasq.out.log";
        StandardErrorPath = "/var/log/dnsmasq.err.log";
      };
    };
  };
}
