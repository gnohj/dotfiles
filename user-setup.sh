#!/usr/bin/env bash
# User setup script - Configures user-level dotfiles and development tools

# Prerequisites:
#   - Nix and nix-darwin should be installed (run system-setup.sh first)
#   - This script handles: chezmoi dotfiles, mise (languages only), SSH keys

set -euo pipefail

# --- Load System Utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/system-utils.sh" ]; then
  source "${SCRIPT_DIR}/system-utils.sh"
else
  echo "Error: Cannot find system-utils.sh" >&2
  exit 1
fi

# --- Configuration ---
ZZH_ZEY_ZECRET_NAME="GITHUB_ZZH_PRIVATE_ZEY"
BW_EMAIL="${1:-}"
GIT_USERNAME="${2:-}"
DOTFILES_REPO="https://github.com/gnohj/dotfiles.git"

# --- Platform Detection ---
detect_platform
# $SUDO is now set by detect_platform()

print_info "User Setup for $OS"
echo "This script will configure:"
echo "  • SSH keys from Bitwarden (optional)"
echo "  • mise (language runtimes)"
echo "  • chezmoi (dotfiles)"
echo ""

# --- PHASE 1: VERIFY PREREQUISITES ---
print_info "› Phase 1: Verifying prerequisites..."

# Check if Nix is installed
if ! command -v nix &>/dev/null; then
  print_warning "Nix is not installed!"
  print_info "Please run system-setup.sh first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/system-setup.sh | bash"
  exit 1
fi

print_success "Nix is installed"

# Source nix profile if not already in PATH
if [ "$OS" = "Darwin" ] && [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Check if nix-darwin is installed (macOS only)
if [ "$OS" = "Darwin" ]; then
  if command -v darwin-rebuild &>/dev/null; then
    print_success "nix-darwin is installed"
  else
    print_warning "nix-darwin not found. System packages may not be available."
  fi
fi

# --- PHASE 2: SSH KEY SETUP FROM BITWARDEN ---
print_info "› Phase 2: Setting up SSH keys..."

if [ -f "$HOME/.ssh/id_ed25519" ]; then
  print_success "SSH key already exists. Skipping Bitwarden setup."
else
  if [ -z "$BW_EMAIL" ] || [ -z "$GIT_USERNAME" ]; then
    print_warning "Skipping SSH key setup (no Bitwarden credentials provided)"
    print_info "To set up SSH keys from Bitwarden, run:"
    print_info "  ./user-setup.sh your_email@example.com your_github_username"
  else
    if ! command -v rbw &>/dev/null; then
      print_warning "rbw not available. Cannot fetch SSH key from Bitwarden."
      print_info "Install rbw via nix-darwin and try again."
    else
      print_info "Setting up SSH key from Bitwarden..."

      # Configure rbw
      mkdir -p "$HOME/.config/rbw"
      printf "[main]\nemail = %s\n" "$BW_EMAIL" >"$HOME/.config/rbw/config.ini"

      print_info "Please enter your Bitwarden master password to unlock the vault."
      if ! eval "$(rbw unlock)"; then
        print_error "Failed to unlock Bitwarden (incorrect password?). Continuing without SSH setup."
      else
        print_success "Vault unlocked successfully."

        print_info "Syncing vault..."
        if ! rbw sync; then
          print_error "Failed to sync Bitwarden vault. Continuing without SSH setup."
        else
          print_success "Vault synced successfully."
          print_info "Fetching SSH key..."

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
          print_success "SSH key configured successfully."
        fi
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
    print_success "Default shell changed to zsh (restart required)"
  else
    print_success "Default shell is already zsh"
  fi
else
  print_warning "zsh not found. Please install via nix-darwin."
fi

# --- PHASE 4: VERIFY MISE ---
print_info "› Phase 4: Verifying mise..."

if command -v mise &>/dev/null; then
  print_success "mise is available"
  mise --version
else
  print_error "mise not found!"
  print_info "mise should be installed via nix-darwin."
  print_info "It should already be in common/packages.nix"
  exit 1
fi

# --- PHASE 5: APPLY DOTFILES WITH CHEZMOI ---
print_info "› Phase 5: Applying dotfiles with chezmoi..."

CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"

# Initialize chezmoi if not already done
if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
  print_info "Initializing chezmoi with dotfiles repository..."

  if [ -d "$PWD/.git" ] && git -C "$PWD" config --get remote.origin.url | grep -q "dotfiles"; then
    # We're running from within the dotfiles repo
    print_info "Running from dotfiles repository, using current directory..."
    chezmoi init --apply --source "$PWD"
  else
    # Clone from GitHub
    print_info "Cloning dotfiles from $DOTFILES_REPO..."
    chezmoi init --apply "$DOTFILES_REPO"
  fi

  print_success "Dotfiles initialized and applied"
else
  print_success "Chezmoi is already initialized"
  print_info "Applying latest dotfiles..."
  chezmoi apply
  print_success "Dotfiles applied"
fi

# --- PHASE 6: INSTALL LANGUAGE RUNTIMES ---
print_info "› Phase 6: Installing language runtimes via mise..."

if command -v mise &>/dev/null; then
  print_info "Installing language runtimes from ~/.config/mise/config.toml..."
  mise install
  print_success "Language runtimes installed"
else
  print_warning "mise not found. Skipping language runtime installation."
fi

# --- COMPLETION ---
echo ""
print_success "=========================================="
print_success "User Setup Complete!"
print_success "=========================================="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or source your shell config:"
echo "     source ~/.zshrc"
echo ""
echo "  2. Verify installations:"
echo "     • System packages: darwin-rebuild switch --flake ~/.config/nix-darwin"
echo "     • Dotfiles: chezmoi status"
echo "     • Languages: mise list"
echo ""

if [ -n "$BW_EMAIL" ] && [ "$SHELL" != "$(command -v zsh)" ]; then
  print_warning "Shell changed to zsh. Please log out and back in for it to take effect."
fi

echo "Configuration locations:"
echo "  • System: ~/.config/nix-darwin/"
echo "  • Dotfiles: ~/.local/share/chezmoi/"
echo "  • Languages: ~/.config/mise/config.toml"
echo ""

exit 0
