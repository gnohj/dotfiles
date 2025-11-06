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
        StandardOutPath = "${homeDir}/.logs/git_autopush/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/git_autopush/launchagent.err.log";
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
        StandardOutPath = "${homeDir}/.logs/skhd/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/skhd/launchagent.err.log";
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
        StandardOutPath = "${homeDir}/.logs/borders/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/borders/launchagent.err.log";
      };
    };

    # SketchyBar - macOS menu bar replacement
    # Auto-restarts if crashed or frozen
    sketchybar = {
      serviceConfig = {
        ProgramArguments = [ "/opt/homebrew/bin/sketchybar" ];
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        RunAtLoad = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/.logs/sketchybar/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/sketchybar/launchagent.err.log";
      };
    };

    # SketchyBar Watchdog
    # Monitors sketchybar health and kills it if frozen (LaunchAgent will restart)
    sketchybar-watchdog = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${homeDir}/.config/sketchybar/watchdog.sh"
        ];
        StartInterval = 300;  # Check every 5 minutes
        StandardOutPath = "${homeDir}/.logs/sketchybar/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/sketchybar/launchagent.err.log";
      };
    };

    # Log Cleanup
    # Cleans up old log files from ~/.logs every 72 hours
    # Keeps logs from current month and previous month only
    log-cleanup = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${homeDir}/Scripts/cleanup-logs.sh"
        ];
        StartInterval = 259200;  # Run every 72 hours (259200 seconds)
        StandardOutPath = "${homeDir}/.logs/cleanup/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/cleanup/launchagent.err.log";
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
