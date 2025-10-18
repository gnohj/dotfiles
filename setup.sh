#!/usr/bin/env bash
# Setup script for dotfiles - integrates Bitwarden SSH key management
# Usage: ./setup.sh [bitwarden_email] [github_username]

set -euo pipefail

# --- Configuration ---
ZZH_ZEY_ZECRET_NAME="GITHUB_ZZH_PRIVATE_ZEY"
BW_EMAIL="${1:-}"
GIT_USERNAME="${2:-}"

print_info() {
  printf "\n\e[1;34m%s\e[0m\n" "$1"
}

# --- Platform Detection ---
OS="$(uname -s)"
case "$OS" in
Linux)
  SUDO="sudo"
  ;;
Darwin)
  SUDO=""
  ;;
*)
  echo "Unsupported operating system: $OS" >&2
  exit 1
  ;;
esac

# --- PHASE 1: INSTALL BASE TOOLS ---
print_info "› Phase 1: Installing base tools..."

if [ "$OS" = "Darwin" ]; then
  if ! command -v brew &>/dev/null; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  for pkg in git rbw; do
    if ! brew list "$pkg" &>/dev/null; then
      print_info "Installing $pkg..."
      brew install "$pkg"
    fi
  done
elif [ "$OS" = "Linux" ]; then
  echo "TODO"
fi

# --- PHASE 2: SSH KEY SETUP FROM BITWARDEN ---
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  print_info "SSH key already exists. Skipping Bitwarden setup."
else
  if [ -z "$BW_EMAIL" ] || [ -z "$GIT_USERNAME" ]; then
    print_info "⚠️  Skipping SSH key setup (no Bitwarden credentials provided)"
    print_info "To set up SSH keys from Bitwarden, run:"
    print_info "  ./setup.sh your_email@example.com your_github_username"
  else
    print_info "Setting up SSH key from Bitwarden..."

    # Configure rbw
    mkdir -p "$HOME/.config/rbw"
    printf "[main]\nemail = %s\n" "$BW_EMAIL" >"$HOME/.config/rbw/config.ini"

    print_info "Please enter your Bitwarden master password to unlock the vault."
    if ! eval "$(rbw unlock)"; then
      echo "Failed to unlock Bitwarden (incorrect password?). Continuing without SSH setup." >&2
    else
      print_info "Vault unlocked successfully."

      print_info "Syncing vault..."
      if ! rbw sync; then
        echo "Failed to sync Bitwarden vault. Continuing without SSH setup." >&2
      else
        print_info "Vault synced successfully. Fetching SSH key..."
        PRIVATE_ZEY=$(rbw get "$ZZH_ZEY_ZECRET_NAME")

        print_info "Configuring SSH..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        printf "%s" "$PRIVATE_ZEY" >"$HOME/.ssh/id_ed25519"
        chmod 600 "$HOME/.ssh/id_ed25519"

        # Add GitHub to known_hosts only if not already present
        if ! grep -q "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
          ssh-keyscan github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
        fi
        print_info "SSH key configured successfully."
      fi
    fi
  fi
fi

# --- PHASE 3: SWITCH TO ZSH ---
print_info "› Phase 3: Configuring shell..."
if command -v zsh >/dev/null; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    print_info "Switching default shell to zsh..."
    $SUDO chsh -s "$(command -v zsh)" "$USER"
  fi
fi

# --- PHASE 4: INSTALL MISE ---
print_info "› Phase 4: Installing mise..."
if ! command -v mise >/dev/null; then
  echo "Installing mise..."
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# --- PHASE 5: APPLY DOTFILES WITH CHEZMOI ---
print_info "› Phase 5: Applying dotfiles with chezmoi..."

if command -v chezmoi >/dev/null; then
  # Use existing chezmoi
  chezmoi init --apply --source "$PWD"
elif mise which chezmoi >/dev/null 2>&1; then
  # Use mise's chezmoi
  mise exec chezmoi -- chezmoi init --apply --source "$PWD"
else
  # Install chezmoi via mise and use it
  echo "Installing chezmoi via mise..."
  mise use -g chezmoi
  mise exec chezmoi -- chezmoi init --apply --source "$PWD"
fi

print_info "✅ Setup complete! Your dotfiles have been applied."
if [ -n "$BW_EMAIL" ]; then
  print_info "Note: You may need to log out and back in for shell changes to take effect."
fi

exit 0
