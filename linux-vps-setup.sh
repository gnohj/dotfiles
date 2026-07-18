#!/usr/bin/env bash
# Linux VPS bootstrap — one command to take a fresh Ubuntu box to a working dev
# box. The Linux counterpart to mac-setup.sh + user-setup.sh (macOS).
#
# What it does, from a bare Ubuntu 24.04 cloud image:
#   (root phase)  create the target user + copy the SSH key, passwordless sudo,
#                 harden sshd (key-only, no root login), install Tailscale, wait
#                 out cloud-init — then hand off to the user.
#   (user phase)  install chezmoi + `chezmoi init --apply` → runs the Linux
#                 toolchain bootstrap (mise, apt pkgs, monitoring, agent CLIs, …).
#
# Usage — run as ROOT on a fresh box (over the provider's IP / console):
#   curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
#   # custom username:        ... | bash -s -- myuser
#   # unattended Tailscale:    TS_AUTHKEY=tskey-... ... | bash
#
# Idempotent — safe to re-run. Interactive / secret-touching steps stay manual
# and are printed at the end (`tailscale up`, `gh auth login`, rbw secrets, OAuth).
#
# NOTE: the toolchain bootstrap is long (cargo builds). For a flaky link, run it
# inside tmux/mosh so a dropped SSH connection doesn't kill it mid-build.
set -euo pipefail

TARGET_USER="${1:-gnohj}"
GITHUB_USER="gnohj"          # dotfiles source: github.com/gnohj/dotfiles

# --- shared helpers (print_*, require_linux, detect_platform, command_exists) ---
UTILS="$(mktemp)"
trap 'rm -f "$UTILS"' EXIT
if ! curl -fsSL -o "$UTILS" "https://raw.githubusercontent.com/${GITHUB_USER}/dotfiles/main/system-utils.sh"; then
  echo "Failed to download system-utils.sh" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$UTILS"

require_linux
detect_platform

# =====================================================================
# ROOT PHASE — user + hardening + Tailscale (skipped when already non-root)
# =====================================================================
if [ "$(id -u)" -eq 0 ]; then
  print_info "› Root phase: user, SSH hardening, Tailscale (target user: $TARGET_USER)"

  # 1. Create the user. Locked password on purpose — login is SSH-key-only and
  #    sudo is NOPASSWD, so no password is needed anywhere. Set one later with
  #    `sudo passwd $TARGET_USER` if you ever want web-console access.
  if id "$TARGET_USER" >/dev/null 2>&1; then
    print_success "User $TARGET_USER already exists"
  else
    print_info "Creating user $TARGET_USER (key-only, no password)"
    adduser --disabled-password --gecos "" "$TARGET_USER"
  fi
  usermod -aG sudo "$TARGET_USER"

  # 2. Give the user root's authorized_keys so the same SSH key logs them in.
  if [ -f /root/.ssh/authorized_keys ]; then
    install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "/home/$TARGET_USER/.ssh"
    install -m 600 -o "$TARGET_USER" -g "$TARGET_USER" \
      /root/.ssh/authorized_keys "/home/$TARGET_USER/.ssh/authorized_keys"
    print_success "Copied authorized_keys to $TARGET_USER"
  else
    print_warning "/root/.ssh/authorized_keys not found — attach an SSH key at provision time"
  fi

  # 3. Passwordless sudo — lets the chezmoi bootstrap apt-install + set linger.
  echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$TARGET_USER"
  chmod 440 "/etc/sudoers.d/$TARGET_USER"

  # 4. Harden sshd. Validate before restart so a bad config can't lock you out.
  SSHD_BIN="$(command -v sshd || echo /usr/sbin/sshd)"
  printf 'PasswordAuthentication no\nPermitRootLogin no\n' > /etc/ssh/sshd_config.d/hardening.conf
  if "$SSHD_BIN" -t; then
    # Ubuntu 24.04 may socket-activate ssh; restart the socket when it's the active unit.
    systemctl restart ssh.socket 2>/dev/null || true
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    print_success "sshd hardened (key-only, no root login)"
    print_warning "Verify '$TARGET_USER' login in a SECOND terminal before you disconnect root."
  else
    rm -f /etc/ssh/sshd_config.d/hardening.conf
    print_error "sshd config invalid — hardening skipped (removed hardening.conf)"
  fi

  # 5. Tailscale — install the binary. `up` is interactive (browser auth) unless
  #    a TS_AUTHKEY is supplied for unattended provisioning.
  if ! command_exists tailscale; then
    print_info "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if [ -n "${TS_AUTHKEY:-}" ]; then
    tailscale up --ssh --authkey "$TS_AUTHKEY" && print_success "tailscale up (authkey)"
  fi

  # 6. Wait out cloud-init so the toolchain bootstrap doesn't race provisioning.
  if command_exists cloud-init; then
    print_info "Waiting for cloud-init to finish…"
    cloud-init status --wait >/dev/null 2>&1 || true
  fi

  # 7. Hand off to the user for the chezmoi/toolchain phase (re-runs this same
  #    script as $TARGET_USER, which falls through to the user phase below).
  print_info "› Handing off to $TARGET_USER for chezmoi + toolchain…"
  exec sudo -u "$TARGET_USER" -i bash -c \
    "curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/dotfiles/main/linux-vps-setup.sh | bash"
fi

# =====================================================================
# USER PHASE — chezmoi install + apply (runs the linux-bootstrap)
# =====================================================================
print_info "› User phase: chezmoi init --apply ($USER)"

# Preflight: github.com is IPv4-only, and the whole toolchain (chezmoi clone, mise
# tool downloads) pulls from it. A Vultr box on a CGNAT/shared IPv4 (100.64.0.0/10)
# has no outbound IPv4 and every github fetch dies with a 1ms "couldn't connect".
# Fail loudly HERE with the real cause instead of a cryptic clone error 50 lines down.
if ! curl -4 -fsS --connect-timeout 8 -o /dev/null https://github.com 2>/dev/null; then
  print_error "No outbound IPv4 to github.com — this box can't provision."
  print_warning "github.com is IPv4-only. This usually means the instance got a CGNAT/shared"
  print_warning "IPv4 (100.64.0.0/10) with no outbound route (common when a datacenter is"
  print_warning "IPv4-exhausted). Check the assigned IP: a real public IPv4 is NOT 100.64-127.x."
  print_warning "Fix: redeploy with a real Public IPv4 (try another datacenter if it recurs),"
  print_warning "or as a stopgap point DNS at a NAT64 resolver. Full detail: MANUAL_VPS_SETUP.md."
  exit 1
fi

# BINDIR so chezmoi lands on PATH (~/.local/bin), not the default ~/bin which the
# zsh config never adds — otherwise `chezmoi` isn't runnable after bootstrap.
print_info "Installing chezmoi and applying dotfiles (this runs the Linux toolchain bootstrap)…"
BINDIR="$HOME/.local/bin" sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init --apply "$GITHUB_USER"

print_success "=========================================="
print_success "Linux bootstrap complete"
print_success "=========================================="
print_warning ""
print_warning "▶ SWITCH TO '$TARGET_USER' FIRST. The toolchain, dotfiles, and shell all"
print_warning "  installed under '$TARGET_USER' — root sees NONE of it, and this shell drops"
print_warning "  back to root when the script exits (a piped bootstrap can't hand you an"
print_warning "  interactive shell as another user). Run every step below AS '$TARGET_USER':"
print_warning "      su - $TARGET_USER            # or reconnect: ssh $TARGET_USER@<box-ip>"
print_warning "  (root SSH login is now disabled, so your next ssh is '$TARGET_USER' anyway.)"
cat <<'EOF'

Remaining MANUAL steps (interactive / secret-touching — can't be piped).
Run these AS the target user (su - <user> or ssh <user>@<box>).
Full detail in MANUAL_VPS_SETUP.md:

  [1] Tailscale onto the tailnet (skip if you passed TS_AUTHKEY):
        sudo tailscale up --ssh
      Then enable MagicDNS + HTTPS Certificates in the admin console.

  [2] GitHub + agents:
        gh auth login
        claude   |   codex   |   gemini      # once each for OAuth

  [3] Secrets — put ONLY the tokens THIS box needs into ~/.zsh_gnohj_env.local
      (gitignored, auto-sourced; var names listed in ~/.config/bitwarden/vars.txt).
      Your Bitwarden master password never touches the VPS (MANUAL_VPS_SETUP.md
      §Security-4). A full `rbw unlock` is reserved for your trusted Mac.

  [4] tmux-dash (private repo — build from source once GitHub auth is set):
        git clone git@github.com:gnohj/tmux-dash && cd tmux-dash && cargo install --path .

  [5] agents monorepo (CLAUDE.md / skills / prompts — so on-box agents read your real config):
        git clone git@github.com:gnohj/agents ~/Developer/agents
        python3 ~/Developer/agents/setup_symlinks.py

  [6] agent-tmux-web (security-sensitive — audit the pinned SHA first):
        see MANUAL_VPS_SETUP.md §7

EOF
