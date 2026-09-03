{ config, pkgs, lib, ... }:

let
  homeDir = if config ? users && config.users ? users && config.users.users ? ${config.system.primaryUser}
            then config.users.users.${config.system.primaryUser}.home
            else "/Users/${config.system.primaryUser}";
  # One declaration per herdr daemon, shared with the Linux generator. Rendered by chezmoi from .chezmoidata/mux-daemons.json, since nix evaluates from ~/.nix and cannot read that.
  muxDaemons = builtins.fromJSON (builtins.readFile ./mux-daemons.json);

  # macOS PATH for daemons that shell out (gh). Deliberately not the Linux string, which leads with ~/.local/bin.
  daemonPath = "${homeDir}/.nix-profile/bin:${homeDir}/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";

  herdrAgents = lib.mapAttrs (name: d:
    let
      interp = if (d ? macos && d.macos ? interp) then d.macos.interp else d.interp;
      cmd = (if interp == "" then "" else interp + " ")
            + "${homeDir}/${muxDaemons.scriptDir}/${d.script}"
            + (if d.args == "" then "" else " " + d.args);
      pathLine = if (d ? needsPath) then "export PATH=\"${daemonPath}\"\n" else "";
    in {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ("mkdir -p ${homeDir}/.logs/" + name + "\n" + pathLine + "exec " + cmd + "\n")
        ];
        KeepAlive = { PathState = { "${homeDir}/${muxDaemons.socket}" = true; }; };
        RunAtLoad = true;
        StandardOutPath = "${homeDir}/.logs/" + name + "/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/" + name + "/launchagent.err.log";
      } // (lib.optionalAttrs (d ? macos && d.macos ? throttle) {
        ThrottleInterval = d.macos.throttle;
      });
    }) muxDaemons.list;
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

    gh-auto-review = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/gh-auto-review
            exec ${pkgs.bash}/bin/bash ${homeDir}/.config/gh-dash/auto-review.sh
          ''
        ];
        StartInterval = 3600;
        RunAtLoad = true;
        EnvironmentVariables = {
          PATH = daemonPath;
          LANG = "en_US.UTF-8";
        };
        StandardOutPath = "${homeDir}/.logs/gh-auto-review/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/gh-auto-review/launchagent.err.log";
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
    # KeepAlive = true so colorscheme-set.sh can restart it and launchd brings it back
    borders = {
      serviceConfig = {
        ProgramArguments = [ "${homeDir}/.config/borders/bordersrc" ];
        KeepAlive = true;
        RunAtLoad = true;
        # Default respawn throttle is 10s, which stalls back-to-back `theme` runs
        ThrottleInterval = 1;
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

    # Dev-context reset on login: RunAtLoad + no KeepAlive fires once per session load (safety net for abnormal exits; the vps atuin script's trap EXIT handles normal in-session reverts).
    dev-context-reset = {
      serviceConfig = {
        # bash -c wrapper: launchd doesn't auto-create StandardOut/ErrPath parent dirs, so `mkdir -p` keeps the service from failing silently.
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/dev-context
            ${homeDir}/.local/bin/dev-context set local
          ''
        ];
        RunAtLoad = true;
        StandardOutPath = "${homeDir}/.logs/dev-context/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/dev-context/launchagent.err.log";
      };
    };

    # embed-watch: logs what spawns `nvim --embed`. Must run continuously - once the process reparents to pid 1 the spawner is unrecoverable, so there is nothing to inspect after the fact.
    embed-watch = {
      serviceConfig = {
        # bash -c wrapper: launchd doesn't auto-create StandardOut/ErrPath parent dirs, so `mkdir -p` keeps the service from failing silently.
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/embed-watch
            exec ${pkgs.bash}/bin/bash ${homeDir}/.local/bin/embed-watch
          ''
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 10;
        StandardOutPath = "${homeDir}/.logs/embed-watch/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/embed-watch/launchagent.err.log";
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

    # Bridges MediaRemote's push stream into the spotify widget; launchd-owned so a sketchybar restart can't orphan it.
    media-control-bridge = {
      serviceConfig = {
        # bash -c wrapper: launchd doesn't auto-create StandardOut/ErrPath parent dirs, so `mkdir -p` keeps the service from failing silently.
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/media-control
            exec ${pkgs.bash}/bin/bash ${homeDir}/.local/bin/media-control-bridge
          ''
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 10;
        EnvironmentVariables = {
          PATH = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/.logs/media-control/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/media-control/launchagent.err.log";
      };
    };

    # Fitness Workout Sync — moved to Claude Desktop Cowork scheduled task
    # (runs on Max subscription instead of API credits)

    # Health Check — handled by sketchybar widget (health_check_notification)

    # Weekly /sb-audit nudge — fires a banner, doesn't run claude
    # headless (no API spend).
    sb-audit-reminder = {
      serviceConfig = {
        # bash -c wrapper: launchd doesn't auto-create StandardOut/
        # ErrPath parent dirs, so `mkdir -p` here keeps the service
        # from failing silently on first fire.
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/sb-audit
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] sb-audit reminder fired" \
              >> ${homeDir}/.logs/sb-audit/fires.log
            ${homeDir}/.local/bin/mac-notify \
              -t "Vault audit due" \
              -m "Run /sb-audit when convenient" \
              -T 20 \
              -s Pop
          ''
        ];
        StartCalendarInterval = [{
          Weekday = 0;
          Hour = 9;
          Minute = 7;
        }];
        StandardOutPath = "${homeDir}/.logs/sb-audit/reminder.out.log";
        StandardErrorPath = "${homeDir}/.logs/sb-audit/reminder.err.log";
      };
    };

    # Jira status refresh belongs to herdr-jira-status; a launchd job here gets the personal claude config, which has no Atlassian MCP.

    # Usage Sampler — records CPU/mem/swap/pressure every 5 min to
    # ~/.local/state/usage/YYYY-MM.csv, building the historical trend behind the
    # "can I downgrade the MacBook once dev work lives on the dev-box" decision.
    # View with `usage-report.sh`. Cheap (vm_stat + sysctl, no `top`). The CSV
    # persists (under state, NOT ~/.logs) so it survives the log-cleanup sweep.
    usage-sampler = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/usage
            ${homeDir}/.local/bin/usage-sample.sh
          ''
        ];
        StartInterval = 300;  # every 5 minutes
        RunAtLoad = true;
        EnvironmentVariables = {
          PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/.logs/usage/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/usage/launchagent.err.log";
      };
    };

    # Claude cost totals out of band so the ccstatusline `mocost` widget stays cat-only; runs the script rather than ccusage directly so ccusage keeps a live parent and never trips the orphan monitor as a ppid-1 CPU hog.
    claude-cost-refresh = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/claude-cost
            ${homeDir}/.local/bin/claude-cost-summary --refresh
          ''
        ];
        StartInterval = 300;  # every 5 minutes; cost totals are never time-critical
        RunAtLoad = true;
        EnvironmentVariables = {
          PATH = "/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/.logs/claude-cost/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/claude-cost/launchagent.err.log";
      };
    };

    # The herdr daemons are generated by `herdrAgents` above from mux-daemons.json; herdr-server stays hand-written below.

    # `zsh -l -c` reads ~/.zshenv but not ~/.zshrc, so a stale mise PATH snapshot can't poison the server (as the Linux unit does).
    herdr-server = {
      serviceConfig = {
        # Probe first: a hand-started server already holds the socket, and racing it would exit non-zero and retry forever.
        ProgramArguments = [
          "/bin/zsh"
          "-l"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/herdr-server
            herdr workspace list >/dev/null 2>&1 && exit 0
            exec herdr server
          ''
        ];
        # Not plain `true`: a deliberate `herdr server stop` / `update --handoff` must stick. Mirrors Restart=on-failure.
        KeepAlive = {
          SuccessfulExit = false;
        };
        RunAtLoad = true;
        # Give a crash-loop room to breathe rather than hammering the socket.
        ThrottleInterval = 10;
        # herdr hands panes the launchd locale; empty means zsh miscounts glyph width (herdr#1373).
        EnvironmentVariables = {
          LANG = "en_US.UTF-8";
        };
        StandardOutPath = "${homeDir}/.logs/herdr-server/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/herdr-server/launchagent.err.log";
      };
    };

    # Screenshot Cleanup - 04:00 daily; the script name-matches because that folder is also the real downloads folder.
    screenshot-cleanup = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${homeDir}/.local/bin/screenshot-cleanup.sh"
        ];
        StartCalendarInterval = [{
          Hour = 4;
          Minute = 0;
        }];
        StandardOutPath = "${homeDir}/.logs/screenshot-cleanup/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/screenshot-cleanup/launchagent.err.log";
      };
    };

    # Log Cleanup
    # Cleans up old log files from ~/.logs every 72 hours
    # Keeps logs from current month and previous month only
    log-cleanup = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "${homeDir}/.local/bin/cleanup-logs.sh"
        ];
        StartInterval = 259200;  # Run every 72 hours (259200 seconds)
        StandardOutPath = "${homeDir}/.logs/cleanup/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/cleanup/launchagent.err.log";
      };
    };
  } // herdrAgents;

  # System LaunchDaemons (run as root)
  launchd.daemons = {
    # Karabiner VirtualHIDDevice daemon - kanata's output-driver bridge.
    # kanata (below) sends its remapped keys through this daemon's socket; without
    # it kanata logs `connect_failed asio.system:2` and the keyboard goes dead.
    # Karabiner-Elements used to run this, but KE ships a VirtualHIDDevice version
    # incompatible with kanata (needs v6.2.0), so KE is removed (see homebrew.nix)
    # and we run the standalone daemon ourselves. The pinned v6.2.0 driver .pkg is
    # installed by run_onchange_after_karabiner-driverkit.sh.tmpl, which also
    # removes any hand-made /Library/LaunchDaemons plist superseded by this one.
    karabiner-vhid-daemon = {
      serviceConfig = {
        ProgramArguments = [
          "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/karabiner-vhid-daemon.out.log";
        StandardErrorPath = "/var/log/karabiner-vhid-daemon.err.log";
      };
    };

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

  # Vendor jobs disabled here stay disabled even when their applications recreate the plist.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    primaryUid=$(id -u ${lib.escapeShellArg config.system.primaryUser})

    echo "🚫 Disabling Google and Microsoft update schedulers..." >&2
    for label in com.google.GoogleUpdater.wake com.microsoft.update.agent; do
      launchctl disable "gui/$primaryUid/$label" || true
      launchctl bootout "gui/$primaryUid/$label" 2>/dev/null || true
    done
  '';
}
