#!/usr/bin/env bash
# User setup script - Configures user-level dotfiles and development tools

# Prerequisites:
#   - Nix and nix-darwin should be installed (run mac-setup.sh first)
#   - This script handles: chezmoi dotfiles, mise (languages only), SSH keys

set -euo pipefail

# Determine script directory (handles both direct execution and piped execution)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  # Script is being executed directly
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Script is being piped (curl | bash) - use temp directory
  SCRIPT_DIR="$(mktemp -d)"
  trap 'rm -rf "$SCRIPT_DIR"' EXIT
  echo "Running from pipe, using temp directory: $SCRIPT_DIR"
fi

if [ ! -f "${SCRIPT_DIR}/system-utils.sh" ]; then
  echo "📦 Downloading system-utils.sh..."
  if curl -fsSL -o "${SCRIPT_DIR}/system-utils.sh" \
    "https://raw.githubusercontent.com/gnohj/dotfiles/main/system-utils.sh"; then
    echo "✅ system-utils.sh downloaded"
  else
    echo "❌ Error: Failed to download system-utils.sh" >&2
    exit 1
  fi
fi

source "${SCRIPT_DIR}/system-utils.sh"

ZZH_ZEY_ZECRET_NAME="GITHUB_ZZH_PRIVATE_ZEY"
BW_EMAIL="${1:-}"
DOTFILES_REPO="https://github.com/gnohj/dotfiles.git"

detect_platform

print_info "User Setup for $OS"
echo "This script will configure:"
echo "  • SSH keys from Bitwarden (optional)"
echo "  • mise (language runtimes)"
echo "  • chezmoi (dotfiles)"
echo ""

# --- PHASE 1: VERIFY PREREQUISITES ---
print_info "› Phase 1: Verifying prerequisites..."

if ! command -v nix &>/dev/null; then
  print_warning "Nix is not installed!"
  print_info "Please run mac-setup.sh first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/mac-setup.sh | bash"
  exit 1
fi

print_success "Nix is installed"

# Source nix profile if not already in PATH
if [ "$OS" = "Darwin" ] && [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

if [ "$OS" = "Darwin" ]; then
  if command -v darwin-rebuild &>/dev/null; then
    print_success "nix-darwin is installed"
  else
    print_warning "nix-darwin not found. System packages may not be available."
  fi
fi

# Pre-create log directories so launchd services don't fail silently on first fire.
mkdir -p "$HOME/.logs/"{skhd,borders,sketchybar,github-auto-push,sb-audit,sb-agent-refresh,cleanup,kanata,watchdog}
print_success "Log directories ready at ~/.logs/"

# --- PHASE 2: SSH KEY AND SECRETS SETUP FROM BITWARDEN ---
print_info "› Phase 2: Setting up SSH keys and secrets from Bitwarden..."

NEED_BITWARDEN_UNLOCK=false
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  NEED_BITWARDEN_UNLOCK=true
fi

if [ "$NEED_BITWARDEN_UNLOCK" = "true" ]; then
  if [ -z "$BW_EMAIL" ]; then
    print_warning "Skipping Bitwarden setup (no email provided)"
    print_info "To set up SSH keys and secrets from Bitwarden, run:"
    print_info "  ./user-setup.sh your_bitwarden_email@example.com"
    print_info ""
    print_info "Without Bitwarden, you can manually create secrets file:"
    print_info "  ~/.zsh_gnohj_env.local (gitignored, sourced by ~/.zsh_gnohj_env)"
  else
    if ! command -v rbw &>/dev/null; then
      print_warning "rbw not available. Cannot fetch secrets from Bitwarden."
      print_info "Install rbw via nix-darwin and try again."
      print_info ""
      print_info "Without Bitwarden, you can manually create secrets file:"
      print_info "  ~/.zsh_gnohj_env.local (gitignored, sourced by ~/.zsh_gnohj_env)"
    else
      print_info "Setting up Bitwarden access for SSH keys and environment secrets..."

      # Configure rbw email
      CURRENT_EMAIL=$(rbw config show 2>/dev/null | grep '"email"' | cut -d'"' -f4)
      if [ "$CURRENT_EMAIL" != "$BW_EMAIL" ]; then
        rbw config set email "$BW_EMAIL"
        print_info "Configured rbw email: $BW_EMAIL"
      else
        print_success "rbw email already configured: $BW_EMAIL"
      fi

      # Configure pinentry for macOS
      if [ "$OS" = "Darwin" ]; then
        rbw config set pinentry pinentry-mac
        print_info "Configured rbw to use pinentry-mac"
      fi

      print_info "Please enter your Bitwarden master password to unlock the vault."
      print_info "This will be used for:"
      print_info "  • SSH private key (for git operations)"
      print_info "  • Environment variable secrets (API keys, tokens)"
      echo ""

      if ! eval "$(rbw unlock)"; then
        print_error "Failed to unlock Bitwarden (incorrect password?). Continuing without Bitwarden setup."
        print_info ""
        print_info "You can manually create ~/.zsh_gnohj_env.local with your secrets"
      else
        print_success "Vault unlocked successfully."
        print_info "The vault will remain unlocked for this session."
        print_info ""
        print_info "Environment secrets will be fetched from Bitwarden via chezmoi:"
        print_info "  • Secrets cached in ~/.zsh_gnohj_env.secrets (auto-generated)"
        print_info "  • Only re-fetched when secret list changes (fast!)"
        print_info "  • Run 'chezmoi apply' to trigger initial fetch"
        echo ""

        print_info "Syncing vault..."
        if ! rbw sync; then
          print_error "Failed to sync Bitwarden vault. Continuing without Bitwarden setup."
        else
          print_success "Vault synced successfully."
          print_info "Fetching SSH key..."

          PRIVATE_ZEY=$(rbw get "$ZZH_ZEY_ZECRET_NAME" --full)

          print_info "Configuring SSH..."
          mkdir -p "$HOME/.ssh"
          chmod 700 "$HOME/.ssh"
          # Remove any blank lines from the key (Bitwarden notes may add extra newlines)
          printf "%s" "$PRIVATE_ZEY" | grep -v '^$' >"$HOME/.ssh/id_ed25519"
          chmod 600 "$HOME/.ssh/id_ed25519"

          # Generate public key from private key
          ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
          chmod 644 "$HOME/.ssh/id_ed25519.pub"
          print_info "Generated public key from private key"

          # Add GitHub to known_hosts only if not already present. Pin GitHub's
          # PUBLISHED host keys rather than ssh-keyscan (trust-on-first-use), so a
          # hostile/MITM'd network at bootstrap can't get a forged key pinned. Verify
          # against https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
          touch "$HOME/.ssh/known_hosts" # Ensure file exists
          if ! grep -q "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
            {
              echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
              echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4mpXNJ5DZ76SzTS8jFxdEUgIw=="
            } >>"$HOME/.ssh/known_hosts"
            print_info "Added github.com to known_hosts (pinned published keys)"
          fi
          print_success "SSH key configured successfully."
          echo ""
          print_success "Bitwarden is ready for environment secrets!"
          print_info "Your shell will automatically load secrets from Bitwarden when unlocked."
        fi
      fi
    fi
  fi
else
  print_success "SSH key already exists. Bitwarden unlock not required."
  print_info ""
  print_info "To load environment secrets from Bitwarden:"
  print_info "  1. Run: eval \"\$(rbw unlock)\""
  print_info "  2. Run: chezmoi apply"
  print_info "  3. Secrets will be cached in ~/.zsh_gnohj_env.secrets"
  print_info ""
  print_info "Or manually create ~/.zsh_gnohj_env.local with your secrets"
fi

# --- PHASE 3: SWITCH TO ZSH ---
print_info "› Phase 3: Configuring shell..."

if command -v zsh >/dev/null; then
  # Check if current shell is zsh (any zsh path)
  if [[ "$SHELL" == *"zsh"* ]]; then
    print_success "Default shell is already zsh ($SHELL)"
  else
    print_info "Switching default shell to zsh..."
    $SUDO chsh -s "$(command -v zsh)" "$USER"
    print_success "Default shell changed to zsh (restart required)"
  fi
else
  print_warning "zsh not found. Please install via nix-darwin."
fi

# --- PHASE 4: INSTALL MISE ---
# mise is installed via its official installer (not nixpkgs) because the
# aarch64-darwin binary cache often lags behind upstream and forces a slow
# source build during darwin-rebuild. The installer drops it at ~/.local/bin/mise
# which is already on PATH via .zshrc.
print_info "› Phase 4: Installing mise..."

if command -v mise &>/dev/null; then
  print_success "mise is already available"
  mise --version
else
  print_info "Installing mise via https://mise.run ..."
  if curl -fsSL https://mise.run | sh; then
    export PATH="$HOME/.local/bin:$PATH"
    print_success "mise installed at $(command -v mise)"
    mise --version
  else
    print_error "mise install failed"
    exit 1
  fi
fi

# --- PHASE 5: APPLY DOTFILES WITH CHEZMOI ---
print_info "› Phase 5: Applying dotfiles with chezmoi..."

CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"

# Initialize chezmoi if not already done
if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
  print_info "Initializing chezmoi with dotfiles repository..."

  if [ -d "$PWD/.git" ] && git -C "$PWD" config --get remote.origin.url | grep -q "dotfiles"; then
    print_info "Running from dotfiles repository, using current directory..."
    chezmoi init --apply --source "$PWD"
  else
    print_info "Cloning dotfiles from $DOTFILES_REPO..."
    chezmoi init --apply "$DOTFILES_REPO"
  fi

  print_success "Dotfiles initialized and applied"
else
  print_success "Chezmoi is already initialized"
  print_info "Applying latest dotfiles..."
  # Use --force to auto-accept source version when files conflict
  # This makes the script non-interactive
  chezmoi apply --force
  print_success "Dotfiles applied"
fi

# --- PHASE 5.5: WORK ACCOUNT AND SECRETS TEMPLATE SETUP ---
print_info "› Phase 5.5: Configuring work account state..."

WORK_ORGS_FILE="$HOME/.local/state/claude/work-orgs"
WORK_EMAIL_FILE="$HOME/.local/state/claude/work-email"
mkdir -p "$HOME/.local/state/claude"

if [ ! -f "$WORK_ORGS_FILE" ] || [ ! -s "$WORK_ORGS_FILE" ]; then
  echo ""
  print_info "Work GitHub org (e.g. iheartmedia) - routes Claude Code to your work account."
  printf "  Enter org name, or press Enter to skip: "
  read -r WORK_ORG
  if [ -n "$WORK_ORG" ]; then
    printf '%s\n' "$WORK_ORG" >"$WORK_ORGS_FILE"
    print_success "Work org saved → $WORK_ORG"
  else
    print_warning "Skipped. Run later: claude-account add-work-org <org>"
  fi
else
  print_success "Work orgs already configured: $(cat "$WORK_ORGS_FILE")"
fi

if [ ! -f "$WORK_EMAIL_FILE" ] || [ ! -s "$WORK_EMAIL_FILE" ]; then
  echo ""
  print_info "Work email (used by tmux-dash row coloring and claude-account label-for-email)."
  printf "  Enter email, or press Enter to skip: "
  read -r WORK_EMAIL_INPUT
  if [ -n "$WORK_EMAIL_INPUT" ]; then
    printf '%s\n' "$WORK_EMAIL_INPUT" >"$WORK_EMAIL_FILE"
    print_success "Work email saved → $WORK_EMAIL_INPUT"
  else
    print_warning "Skipped. Run later: claude-account set-work-email <email>"
  fi
else
  print_success "Work email already configured: $(cat "$WORK_EMAIL_FILE")"
fi

# Generate a fill-in-the-blank template for secrets so Bitwarden is never a hard blocker.
LOCAL_TEMPLATE="$HOME/.zsh_gnohj_env.local.template"
VARS_FILE="$HOME/.config/bitwarden/vars.txt"
if [ -f "$VARS_FILE" ] && [ ! -f "$LOCAL_TEMPLATE" ]; then
  {
    printf '# Fill in values manually if not using Bitwarden.\n'
    printf '# Copy to ~/.zsh_gnohj_env.local and populate - it is sourced automatically.\n\n'
    while IFS= read -r var; do
      [ -z "$var" ] && continue
      printf 'export %s=""\n' "$var"
    done <"$VARS_FILE"
  } >"$LOCAL_TEMPLATE"
  print_success "Created ~/.zsh_gnohj_env.local.template (fill-in-the-blank for all secrets)"
fi

# --- PHASE 6: INSTALL LANGUAGE RUNTIMES ---
print_info "› Phase 6: Installing language runtimes via mise..."

if command -v mise &>/dev/null; then
  print_info "Installing language runtimes from ~/.config/mise/config.toml..."
  mise install
  print_success "Language runtimes installed"

  print_info "Installing global tools via mise tasks..."
  mise run setup-global-tools
  print_success "Global tools installed"
else
  print_warning "mise not found. Skipping language runtime installation."
fi

# --- PHASE 6.5: SYMLINK ICLOUD VAULT TO ~/Obsidian ---
print_info "› Phase 6.5: Configuring iCloud-backed Obsidian vault..."

ICLOUD_OBSIDIAN="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian"

if [ -L "$HOME/Obsidian" ]; then
  print_success "~/Obsidian symlink exists → $(readlink "$HOME/Obsidian")"
elif [ -e "$HOME/Obsidian" ]; then
  print_error "~/Obsidian exists but is NOT a symlink."
  print_error "This will conflict with iCloud sync. Inspect and remove before continuing."
  print_info "  Expected: a symlink to \"$ICLOUD_OBSIDIAN\""
  exit 1
elif [ -d "$ICLOUD_OBSIDIAN" ]; then
  ln -s "$ICLOUD_OBSIDIAN" "$HOME/Obsidian"
  print_success "Created symlink ~/Obsidian → iCloud Obsidian path"
else
  print_warning "iCloud Obsidian path not found yet."
  print_info "  Expected: $ICLOUD_OBSIDIAN"
  print_info "  iCloud may still be syncing. Once vault appears, re-run user-setup.sh."
  print_info "  Skipping vault setup — second-brain is NOT git-cloned (iCloud is source of truth)."
fi

if [ -d "$HOME/Obsidian/second-brain" ]; then
  print_success "Vault present at ~/Obsidian/second-brain"
else
  print_warning "~/Obsidian/second-brain not found. Wait for iCloud sync to complete."
  print_info "  Verify with: ls -la \"$ICLOUD_OBSIDIAN/second-brain\""
fi

# --- PHASE 7: CLONE PRIVATE REPOSITORIES ---
print_info "› Phase 7: Cloning private repositories..."

# Verify SSH auth before attempting clones. Notes on the probe:
#   - GitHub's `ssh -T` exits 1 even on success, so we grep stderr, not $?.
#   - Accept a key file OR a loaded agent identity (Bitwarden/1Password/keychain).
#   - Seed known_hosts first: with BatchMode=yes a missing host key fails host-key
#     verification silently, which looks identical to an auth failure (false negative
#     on fresh machines / before ~/.ssh dotfiles are applied). We pin GitHub's
#     PUBLISHED host keys rather than ssh-keyscan (trust-on-first-use), so a
#     hostile/MITM'd network at bootstrap can't get a forged key pinned. Verify
#     against https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
#   - Cold first-connect to github.com can exceed 8s on a fresh boot, so use a 15s
#     timeout and retry a few times before warning.
REPOS_FILE="$HOME/.config/repos-clone.txt"
SSH_OK=false
if [ -f "$HOME/.ssh/id_ed25519" ] || ssh-add -l >/dev/null 2>&1; then
  if ! ssh-keygen -F github.com >/dev/null 2>&1; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    {
      echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
      echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4mpXNJ5DZ76SzTS8jFxdEUgIw=="
    } >> "$HOME/.ssh/known_hosts"
  fi
  for _ in 1 2 3; do
    if ssh -o BatchMode=yes -o ConnectTimeout=15 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
      SSH_OK=true
      break
    fi
    sleep 2
  done
fi
if [ "$SSH_OK" = "false" ]; then
  print_warning "SSH key not authenticated with GitHub - private repo cloning will likely fail."
  print_info "  If you skipped Bitwarden in Phase 2, add your SSH key manually:"
  print_info "    cp <your_key> ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519"
  print_info "  Then add the public key to GitHub and re-run this script."
fi

if [ -f "$REPOS_FILE" ]; then
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    repo=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $2}')
    dest="${dest/#\~/$HOME}"

    if [ -d "$dest/.git" ]; then
      print_success "Already cloned: $dest"
    else
      mkdir -p "$(dirname "$dest")"
      if git clone "$repo" "$dest"; then
        print_success "Cloned: $dest"
      else
        print_warning "Failed to clone: $repo"
      fi
    fi
  done < "$REPOS_FILE"
else
  print_warning "No repos-clone.txt found at $REPOS_FILE, skipping"
fi

# --- PHASE 8: INSTALL RUST TOOLS FROM SOURCE ---
print_info "› Phase 8: Installing Rust tools from source..."

CARGO_FILE="$HOME/.config/cargo-installs.txt"

if [ -f "$CARGO_FILE" ] && command -v cargo &>/dev/null; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    repo=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $2}')
    dest="${dest/#\~/$HOME}"
    binary=$(basename "$dest")

    if command -v "$binary" &>/dev/null; then
      print_success "Already installed: $binary"
    else
      if [ ! -d "$dest/.git" ]; then
        mkdir -p "$(dirname "$dest")"
        git clone "$repo" "$dest"
      fi
      cargo install --path "$dest"
      print_success "Installed: $binary"
    fi
  done < "$CARGO_FILE"
elif [ ! -f "$CARGO_FILE" ]; then
  print_warning "No cargo-installs.txt found, skipping"
elif ! command -v cargo &>/dev/null; then
  print_warning "cargo not found, skipping Rust tool installs"
fi

# --- PHASE 9: CONFIGURE CLAUDE CODE MCP SERVERS ---
print_info "› Phase 9: Configuring Claude Code MCP servers..."

MCP_FILE="$HOME/.config/claude-mcp-servers.txt"

if [ -f "$MCP_FILE" ] && command -v claude &>/dev/null; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    type=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    rest=$(echo "$line" | cut -d' ' -f3-)

    if claude mcp get "$name" -s user &>/dev/null 2>&1; then
      print_success "MCP already configured: $name"
    else
      if [ "$type" = "http" ]; then
        claude mcp add -s user --transport http "$name" "$rest"
      else
        claude mcp add -s user "$name" -- $rest
      fi
      print_success "Added MCP server: $name"
    fi
  done < "$MCP_FILE"
elif [ ! -f "$MCP_FILE" ]; then
  print_warning "No claude-mcp-servers.txt found, skipping"
elif ! command -v claude &>/dev/null; then
  print_warning "claude not found, skipping MCP setup"
fi

# --- COMPLETION ---
echo ""
print_success "=========================================="
print_success "User Setup Complete!"
print_success "=========================================="
echo ""

if [ -n "$BW_EMAIL" ] && [ "$SHELL" != "$(command -v zsh)" ]; then
  print_warning "Shell changed to zsh. Please log out and back in for it to take effect."
fi

# --- MANUAL STEPS CHECKLIST ---
# Scan for anything that still needs human action and print a consolidated list.
echo ""
echo "=============================================="
echo "  What Still Needs Manual Attention"
echo "=============================================="
echo ""

PENDING=0

# Obsidian vault (cs/cr --add-dir fails without it)
if [ ! -d "$HOME/Obsidian/second-brain" ]; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] Obsidian vault not synced yet"
  echo "    iCloud may still be downloading. Once it appears, re-run:"
  echo "      bash user-setup.sh"
  echo "    Expected: $HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian"
  echo ""
fi

# App Store sign-in + mas apps
if ! mas account &>/dev/null 2>&1; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] App Store - not signed in"
  echo "    Sign in via App Store.app, then install:"
  echo "      mas install 497799835   # Xcode"
  echo "      mas install 1193539993  # Brother iPrint&Scan"
  echo "      mas install 310633997   # WhatsApp Messenger"
  echo ""
fi

# Claude OAuth tokens
MISSING_CLAUDE_TOKENS=""
for ACCT in personal work; do
  if ! security find-generic-password -a "$USER" -s "claude-oauth-$ACCT" -w &>/dev/null 2>&1; then
    MISSING_CLAUDE_TOKENS="$MISSING_CLAUDE_TOKENS $ACCT"
  fi
done
if [ -n "$MISSING_CLAUDE_TOKENS" ]; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] Claude OAuth tokens missing for:$MISSING_CLAUDE_TOKENS"
  echo "    For each missing account (run interactively, not piped):"
  echo "      claude setup-token"
  echo "      pbpaste | claude-account set-token <personal|work>"
  echo ""
fi

# Work org / work email state files
if [ ! -s "$HOME/.local/state/claude/work-orgs" ]; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] Work GitHub org not configured (claude-account always resolves to personal)"
  echo "      claude-account add-work-org <github-org-name>"
  echo ""
fi
if [ ! -s "$HOME/.local/state/claude/work-email" ]; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] Work email not configured (tmux-dash row coloring will not work)"
  echo "      claude-account set-work-email <your-work-email>"
  echo ""
fi

# Atuin sync login
if command -v atuin &>/dev/null && ! atuin status 2>/dev/null | grep -qF '[Remote]'; then
  PENDING=$((PENDING + 1))
  echo "[$PENDING] Atuin shell history not synced"
  echo "      atuin login"
  echo ""
fi

# GPG signing keys
if command -v gpg &>/dev/null; then
  GPG_COUNT=$(gpg --list-secret-keys 2>/dev/null | grep -c "^sec" || true)
  if [ "${GPG_COUNT:-0}" -eq 0 ]; then
    PENDING=$((PENDING + 1))
    echo "[$PENDING] GPG signing keys not imported (needed if you sign commits)"
    echo "      gpg --import your-key.asc"
    echo "      git config --global user.signingkey <key-id>"
    echo ""
  fi
fi

# TCC permissions - always required on a fresh machine, cannot be detected programmatically
PENDING=$((PENDING + 1))
echo "[$PENDING] TCC Permissions (System Settings > Privacy & Security)"
echo "    Cannot be scripted - must be granted manually."
echo "    Accessibility:    AeroSpace, borders (x4), Ghostty, kanata, kitty, Raycast, sketchybar, skhd"
echo "    Full Disk Access: Ghostty, kitty"
echo "    Input Monitoring: kanata  <-- re-grant after any kanata Homebrew upgrade"
echo "    Automation:       AeroSpace, Ghostty, osascript, Raycast, sketchybar, skhd"
echo "    Screen Recording: Raycast"
echo "    Driver Extensions: org.pqrs.Karabiner-DriverKit-VirtualHIDDevice (kanata's driver)"
echo "                       <-- Login Items & Extensions; approve after the v6.2.0 pkg installs"
echo "    See MANUAL_SETUP.md for full details and the correct grant order."
echo ""

# AlDente - no config file, always remind
PENDING=$((PENDING + 1))
echo "[$PENDING] AlDente: open the app and set charge limit to 80-90%"
echo ""

# Raycast - no portable config file, always remind
PENDING=$((PENDING + 1))
echo "[$PENDING] Raycast: import settings from a backup export"
echo "    (Raycast Pro users: enable cloud sync instead)"
echo ""

echo "----------------------------------------------"
if [ "$PENDING" -gt 0 ]; then
  echo "  $PENDING item(s) need attention. Run this script again after"
  echo "  completing them - it is safe to re-run."
else
  echo "  All checks passed. Nothing left to do."
fi
echo "=============================================="
echo ""
echo "Config locations:"
echo "  System:    ~/.nix/ (nix-darwin flake)"
echo "  Dotfiles:  ~/.local/share/chezmoi/"
echo "  Languages: ~/.config/mise/config.toml"
echo ""

exit 0
