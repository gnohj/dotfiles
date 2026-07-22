#!/usr/bin/env bash
# Linux VPS bootstrap — one command to take a fresh Ubuntu box to a working dev
# box. The Linux counterpart to mac-setup.sh + user-setup.sh (macOS).
#
# What it does, from a bare Ubuntu 24.04 cloud image:
#   (root phase)  create the target user + copy the SSH key, passwordless sudo,
#                 harden sshd (key-only, no root login), install Tailscale, wait
#                 out cloud-init — then hand off to the user.
#   (user phase)  clone dotfiles → install Nix + first home-manager switch (the bulk
#                 CLI toolchain) → `chezmoi apply` → the Linux bootstrap (apt base,
#                 monitoring, mise runtimes + agent CLIs). Nix-first, mirroring the Mac.
#
# Usage — run as ROOT on a fresh box (over the provider's IP / console):
#   curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
#   # unattended Tailscale:    TS_AUTHKEY=tskey-... ... | bash
#
# Idempotent — safe to re-run. Interactive / secret-touching steps stay manual
# and are printed at the end (`tailscale up`, `gh auth login`, rbw secrets, OAuth).
#
# NOTE: the toolchain bootstrap is long (cargo builds). For a flaky link, run it
# inside tmux/mosh so a dropped SSH connection doesn't kill it mid-build.
set -euo pipefail

# Pinned: the flake output (gnohj-linux-x86_64) and home-manager/home.nix pin this
# username, so a different user would fail `home-manager switch`. Single-user repo.
TARGET_USER="gnohj"
GITHUB_USER="gnohj"          # dotfiles source: github.com/gnohj/dotfiles
# home-manager flake target — arch-encoded, mirroring the Mac's macbook_silicon.
# Override for another arch, e.g. LINUX_FLAKE=gnohj-linux-aarch64 on an ARM VPS.
LINUX_FLAKE="${LINUX_FLAKE:-gnohj-linux-x86_64}"

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

  # 5. Tailscale — install the binary + join the tailnet. `up` is interactive
  #    (browser auth) unless a TS_AUTHKEY is supplied for unattended provisioning.
  if ! command_exists tailscale; then
    print_info "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if [ -n "${TS_AUTHKEY:-}" ]; then
    # The installer starts tailscaled, but on a cold box `up` can beat the daemon's
    # control socket. Ensure it's running and wait for it before `up`, or the key
    # bring-up fails against a not-yet-ready daemon.
    systemctl enable --now tailscaled 2>/dev/null || true
    ts_ready=0
    for _ in $(seq 1 15); do
      tailscale status 2>&1 | grep -qiE 'failed to connect|is tailscaled running' || { ts_ready=1; break; }
      sleep 1
    done
    [ "$ts_ready" = 1 ] || print_warning "tailscaled not responding after 15s — 'up' may fail (check: systemctl status tailscaled)"
    # Do NOT swallow failure: an expired / single-use / invalid key must be LOUD.
    # Silently continuing leaves the box Logged out — defeating the point of TS_AUTHKEY.
    if ts_out="$(tailscale up --ssh --authkey "$TS_AUTHKEY" 2>&1)"; then
      print_success "tailscale up (authkey)"
    else
      print_error "TS_AUTHKEY was set but 'tailscale up' FAILED — this box is NOT on the tailnet:"
      printf '%s\n' "$ts_out" | sed 's/^/    /'
      print_warning "Usual causes: key expired (default 90d), a single-use key already consumed, or an ephemeral key."
      print_warning "Fix: mint a fresh REUSABLE key at login.tailscale.com/admin/settings/keys, then on the box:"
      print_warning "    sudo tailscale up --ssh --authkey tskey-…     (or interactive: sudo tailscale up --ssh)"
    fi
  else
    print_info "No TS_AUTHKEY — join the tailnet later: sudo tailscale up --ssh  (or post-provision.sh tailscale)"
  fi

  # 6. Wait out cloud-init so the toolchain bootstrap doesn't race provisioning.
  if command_exists cloud-init; then
    print_info "Waiting for cloud-init to finish…"
    cloud-init status --wait >/dev/null 2>&1 || true
  fi

  # 7. Hand off to the user for the chezmoi/toolchain phase (re-runs this same
  #    script as $TARGET_USER, which falls through to the user phase below).
  #    Forward GITHUB_TOKEN across the sudo -i env reset so mise's toolchain
  #    install authenticates (5000/hr) instead of hitting the 60/hr anonymous
  #    GitHub API rate limit — the difference between a one-shot install and a
  #    partial one on a busy IP.
  print_info "› Handing off to $TARGET_USER for chezmoi + toolchain…"
  GH_TOKEN_FWD=""
  [ -n "${GITHUB_TOKEN:-}" ] && GH_TOKEN_FWD="export GITHUB_TOKEN='${GITHUB_TOKEN}'; "
  exec sudo -u "$TARGET_USER" -i bash -c \
    "${GH_TOKEN_FWD}curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/dotfiles/main/linux-vps-setup.sh | bash"
fi

# =====================================================================
# USER PHASE — chezmoi install + apply (runs the linux-bootstrap)
# =====================================================================
print_info "› User phase: clone dotfiles → Nix + home-manager → chezmoi apply ($USER)"

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

# Nix-first, mirroring mac-setup.sh (nix-darwin installs the toolchain BEFORE
# dotfiles land). Order: clone source → install Nix → first home-manager switch
# (bulk CLI toolchain into ~/.nix-profile) → chezmoi apply (dotfiles + the trimmed
# mise runtimes/AI + the apt/monitoring remainder). Applying dotfiles first would
# leave the box tool-less in the window before home-manager runs, since the mise
# config no longer carries the bulk CLIs.
CHEZMOI="$HOME/.local/bin/chezmoi"

# 1. Clone the dotfiles source only — no apply yet. The flake must exist on disk
#    before we can build it (mac-setup.sh Phase 2 gets the flake in place first too).
#    BINDIR lands chezmoi on ~/.local/bin (the default ~/bin is never on PATH here).
print_info "Cloning dotfiles source (chezmoi init, no apply yet)…"
BINDIR="$HOME/.local/bin" sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init "$GITHUB_USER"

# `chezmoi init` won't update an existing clone, and the flake build below reads the source as git+file (committed HEAD), so force it to origin/main to keep a re-run from rebuilding a stale tree.
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
if [ -d "$CHEZMOI_SRC/.git" ]; then
  git -C "$CHEZMOI_SRC" fetch --quiet origin && git -C "$CHEZMOI_SRC" reset --hard --quiet origin/main
fi

# 2. Install Nix — same Determinate installer + idempotency guard as mac-setup.sh
#    Phase 1. --no-confirm is unattended; the installer escalates via sudo itself.
if command_exists nix; then
  print_success "Nix already installed"
else
  print_info "Installing Nix (Determinate Systems installer)…"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi
# Put nix on PATH for the rest of THIS piped shell (the profile.d hook isn't sourced here).
# shellcheck disable=SC1091
[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] \
  && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. First home-manager generation — installs the bulk CLI toolchain into
#    ~/.nix-profile, the Linux mirror of mac-setup.sh Phase 3's nix-darwin switch.
#    Points at the chezmoi SOURCE flake (~/.nix doesn't exist until apply), same as
#    mac-setup.sh references $NIX_CONFIG_DIR. After this the `home-manager` CLI is on
#    PATH (programs.home-manager.enable) and `up` drives steady-state rebuilds.
if command_exists home-manager; then
  print_success "home-manager already installed"
else
  print_info "Building the Nix CLI toolchain (first home-manager switch)…"
  nix run github:nix-community/home-manager -- switch -b backup \
    --flake "$HOME/.local/share/chezmoi/dot_nix#$LINUX_FLAKE"
fi

# 4. NOW apply dotfiles — they reference tools Nix just installed; the trimmed mise
#    config adds only runtimes + AI agents; the run_onchange bootstrap does the
#    system-config remainder (apt base, sysstat/atop, chsh, swap).
print_info "Applying dotfiles + Linux toolchain bootstrap (chezmoi apply)…"
"$CHEZMOI" apply

print_success "=========================================="
print_success "Linux bootstrap complete"
print_success "=========================================="
print_warning ""
print_warning "▶ SWITCH TO '$TARGET_USER' FIRST. The toolchain, dotfiles, and shell all"
print_warning "  installed under '$TARGET_USER' — root sees NONE of it, and this shell drops"
print_warning "  back to root when the script exits (a piped bootstrap can't hand you an"
print_warning "  interactive shell as another user). Run every step below AS '$TARGET_USER':"
print_warning "      su - $TARGET_USER            # or reconnect: ssh $TARGET_USER@<box-ip>"
print_warning "  USE THE DASH. 'su - $TARGET_USER' loads the login shell (cd to home, full PATH/env)."
print_warning "  Plain 'su $TARGET_USER' (no dash) strands you in /root with a broken env."
print_warning "  (root SSH login is now disabled, so your next ssh is '$TARGET_USER' anyway.)"
cat <<'EOF'

Remaining MANUAL steps live in a PRIVATE repo (vps-linux-provision) — the
interactive / secret-touching half that can't be piped. Full detail in
MANUAL_VPS_SETUP.md. Run these AS the target user (su - <user> or ssh <user>@<box>):

  [1] gh auth — the ONE thing that can't be automated. Unlocks the private repo
      and registers the SSH key its private clones need:
        unset GITHUB_TOKEN                       # bootstrap forwarded it
        gh auth login -h github.com -p ssh -w

  [2] Clone + run the private post-provision.sh — it scripts everything else
      (ai OAuth · secrets · atuin · tailscale · repos · tmux-dash · agents · tpm),
      idempotent, pausing only where a human is genuinely needed:
        git clone git@github.com:gnohj/vps-linux-provision.git ~/Developer/vps-linux-provision
        ~/Developer/vps-linux-provision/post-provision.sh

  [3] agent-tmux-web — NOT in the script (phone PWA code-exec surface; audit first).
      Needs Tailscale up. Read src/server/{index,tmux}.ts before trusting a SHA:
        install-agent-tmux-web.sh   # prompts for the audited SHA; blank = skip

EOF
