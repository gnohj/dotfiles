{ config, pkgs, lib, ... }:

let
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
    # KeepAlive = true so colorscheme-set.sh can pkill and it auto-restarts
    borders = {
      serviceConfig = {
        ProgramArguments = [ "${homeDir}/.config/borders/bordersrc" ];
        KeepAlive = true;
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

    # Jira Status Refresh — runs `/sb-agent-refresh` headlessly so every
    # ticket-shaped thread state file at ~/.local/state/threads/ stays in
    # sync with its actual Jira workflow status. That status drives the
    # text line below each agent row in tmux-dash (e.g. "In Dev Review",
    # "Ready to Merge").
    #
    # Cost: $0 on Claude Max — runs against subscription quota, not API
    # billing. Verified Rovo MCP is available in `claude -p` headless
    # context (manual test 2026-06-07).
    sb-agent-refresh = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/sb-agent-refresh
            export PATH="${homeDir}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            export HOME="${homeDir}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] firing /sb-agent-refresh" \
              >> ${homeDir}/.logs/sb-agent-refresh/fires.log
            cd "${homeDir}"
            claude --dangerously-skip-permissions -p '/sb-agent-refresh' \
              >> ${homeDir}/.logs/sb-agent-refresh/fires.log 2>&1
          ''
        ];
        StartInterval = 900;  # every 15 minutes
        StandardOutPath = "${homeDir}/.logs/sb-agent-refresh/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/sb-agent-refresh/launchagent.err.log";
      };
    };

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

    # Claude Usage Limits — refreshes the plan-usage statusline segment (5h +
    # weekly + weekly-fable %) shown under the ccusage line. Calls the undocumented
    # /api/oauth/usage endpoint (rate limited ~1/hr) and writes a pre-rendered
    # segment to ~/.cache/claude-usage/segment; the statusline wrapper only cats
    # that file. The script self-throttles (4-min freshness + retry-after
    # cooldown), so a 5-min interval yields live-feeling numbers with automatic
    # backoff after a 429. Token comes from the claude-oauth-personal keychain
    # item; needs the GUI login keychain, so RunAtLoad + interval (user session).
    claude-usage-limits = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/claude-usage
            ${homeDir}/.local/bin/claude-usage-limits.sh
          ''
        ];
        StartInterval = 300;  # every 5 min; self-throttles + backs off on 429
        RunAtLoad = true;
        EnvironmentVariables = {
          PATH = "${homeDir}/.local/share/mise/shims:${homeDir}/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/.logs/claude-usage/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/claude-usage/launchagent.err.log";
      };
    };

    # herdr focus-tracker — event-driven MRU state for ctrl+space (last tab) and
    # ctrl+enter (last workspace). herdr has no native last_tab/last_workspace and its
    # snapshot carries no focus history, but its socket streams focus events; this
    # daemon subscribes and writes the jump targets the ctrl+space/ctrl+enter wrappers
    # read. It BLOCKS on the socket (no polling) so it must run wherever the herdr
    # SERVER runs — this is the Mac-local counterpart to the Linux systemd unit
    # (dot_config/systemd/user/herdr-focus-tracker.service), so it works when herdr
    # runs locally on the Mac, not only under `herdr --remote` (VPS server). Stdlib-only
    # Python via /usr/bin/python3 → no PATH/mise dependency. KeepAlive revives it if
    # herdr restarts and the socket drops (the daemon also self-reconnects).
    herdr-focus-tracker = {
      serviceConfig = {
        # bash -c + exec: launchd doesn't create StandardOut/ErrPath parent dirs, so
        # mkdir -p first; exec replaces bash with python so KeepAlive supervises the
        # daemon itself, not a bash parent.
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${homeDir}/.logs/herdr-focus-tracker
            exec /usr/bin/python3 ${homeDir}/.local/bin/herdr-scripts/herdr-focus-tracker.py
          ''
        ];
        # Lifecycle-bound to the herdr server via the socket file (launchd's analog of
        # the Linux unit's BindsTo=herdr-server.service): launchd runs the agent only
        # while the socket exists, and stops it when herdr goes away — so it never spins
        # against a dead socket. Same path the daemon itself defaults to; if herdr's
        # socket lives elsewhere on this Mac, update both.
        KeepAlive = {
          PathState = {
            "${homeDir}/.config/herdr/herdr.sock" = true;
          };
        };
        RunAtLoad = true;
        StandardOutPath = "${homeDir}/.logs/herdr-focus-tracker/launchagent.out.log";
        StandardErrorPath = "${homeDir}/.logs/herdr-focus-tracker/launchagent.err.log";
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
}
