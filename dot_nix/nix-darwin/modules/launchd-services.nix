{ config, pkgs, lib, ... }:

let
  # Get the primary user's home directory
  # Falls back to /Users/gnohj if not defined
  homeDir = if config ? users && config.users ? users && config.users.users ? ${config.system.primaryUser}
            then config.users.users.${config.system.primaryUser}.home
            else "/Users/${config.system.primaryUser}";
in
{
  # LaunchAgents and LaunchDaemons
  # Migrated from: run_onchange_before_mac_system.sh.tmpl
  #
  # User Agents: Run as logged-in user (~/Library/LaunchAgents/)
  # System Daemons: Run as root (/Library/LaunchDaemons/)

  # User LaunchAgents
  launchd.user.agents = {
    # GitHub Auto Push Service
    # Automatically commits and pushes dotfiles changes
    github-auto-push = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${homeDir}/.config/zshrc/github-auto-push.sh"
        ];
        StartInterval = 180;  # Run every 3 minutes
        StandardOutPath = "/tmp/github-auto-push.out";
        StandardErrorPath = "/tmp/github-auto-push.err";
      };
    };

    # SKHD - Hotkey daemon for window management (used with AeroSpace)
    # Uses wrapper script that waits for secure keyboard entry to clear
    skhd = {
      serviceConfig = {
        ProgramArguments = [ "${homeDir}/.config/skhd/start-skhd.sh" ];
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        RunAtLoad = true;
        ProcessType = "Interactive";
        Nice = -20;
        StandardOutPath = "/tmp/skhd_${config.system.primaryUser}.out.log";
        StandardErrorPath = "/tmp/skhd_${config.system.primaryUser}.err.log";
      };
    };

    # Borders - Window border visualization
    # Auto-restarts if crashed
    borders = {
      serviceConfig = {
        ProgramArguments = [ "${homeDir}/.config/borders/bordersrc" ];
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/borders_${config.system.primaryUser}.out.log";
        StandardErrorPath = "/tmp/borders_${config.system.primaryUser}.err.log";
      };
    };
  };

  # System LaunchDaemons (run as root)
  launchd.daemons = {
    # Kanata - Keyboard remapping daemon
    # Must run as root for low-level keyboard access
    kanata = {
      serviceConfig = {
        ProgramArguments = [
          "/opt/homebrew/bin/kanata"
          "-c"
          "${homeDir}/.config/kanata/macos.kbd"
        ];
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        RunAtLoad = true;
        StandardOutPath = "/var/log/kanata.out.log";
        StandardErrorPath = "/var/log/kanata.err.log";
      };
    };
  };
}
