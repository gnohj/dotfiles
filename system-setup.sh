#!/usr/bin/env bash
# System setup script - Installs Nix and system configuration
#
# Platform Support:
#   - macOS: Uses nix-darwin for system configuration
#   - Linux: TODO
#
# Usage: ./system-setup.sh [FLAKE_NAME]
#   FLAKE_NAME: Optional flake configuration name (default: macbook_silicon)
#   Examples:
#     ./system-setup.sh                    # Uses default: macbook_silicon
#     ./system-setup.sh macbook_intel      # For Intel Macs

set -euo pipefail

FLAKE_NAME="${1:-macbook_silicon}"

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

require_macos
detect_platform

print_info "System Setup for macOS ($NIX_SYSTEM)"
echo "This script will install:"
echo "  • Nix package manager"
echo "  • nix-darwin (macOS system configuration)"
echo ""
print_info "Using flake configuration: $FLAKE_NAME"
echo ""

# --- Request sudo access upfront ---
# This caches credentials so user doesn't need to enter password multiple times
# sudo timeout is typically 5 minutes (configurable in /etc/sudoers)
print_info "This script requires sudo access for:"
print_info "  • Installing nix-darwin system configuration"
print_info "  • Installing Homebrew packages (via nix-darwin)"
echo ""
sudo -v

# Keep sudo alive in background while script runs
# This updates the timestamp every 50 seconds until script exits
while true; do
  sudo -n true
  sleep 50
  kill -0 "$$" || exit
done 2>/dev/null &

# --- PHASE 1: INSTALL NIX ---
print_info "› Phase 1: Installing Nix package manager..."

if command -v nix &>/dev/null; then
  print_success "Nix is already installed"
  nix --version
else
  print_info "Installing Nix (Determinate Systems installer)..."

  # Use Determinate Systems installer (handles multi-user, SELinux, etc.)
  # --no-confirm: Skip interactive prompts for automated installation
  #
  # What this installs on macOS:
  # - 1 encrypted APFS volume at /nix (auto-mounted on boot)
  # - 32 build users (32 cores on M2)(_nixbld1-32, UIDs 351-382) for parallel builds
  # - /etc/fstab, /etc/synthetic.conf, /etc/nix/nix.conf
  # - Shell integration (zsh/bash) via /etc/profile.d/nix-daemon.sh
  # - LaunchDaemon for Nix daemon (multi-user mode)
  # - Time Machine exclusions for /nix
  # - Fully reversible (clean uninstall available) - can run uninstaller to remove any traces of nix - and return machine back to its original pre-nix tate
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install --no-confirm

  print_success "Nix installed successfully"
  echo ""
  print_warning "Please open a NEW terminal window and re-run this script:"
  print_info "  ./system-setup.sh"
  echo ""
  print_info "This is required for Nix to be available in your shell PATH."
  exit 0
fi

# --- PHASE 2: CHECK NIX CONFIGURATION ---
print_info "› Phase 2: Checking Nix configuration..."

CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
NIX_CONFIG_DIR="$CHEZMOI_SOURCE/dot_nix"
DOTFILES_REPO="https://github.com/gnohj/dotfiles.git"

if [ ! -d "$CHEZMOI_SOURCE" ]; then
  print_info "Chezmoi source directory not found. Cloning dotfiles..."

  if git clone "$DOTFILES_REPO" "$CHEZMOI_SOURCE"; then
    print_success "Dotfiles cloned to $CHEZMOI_SOURCE"
  else
    print_error "Failed to clone dotfiles repository"
    print_info "Please manually clone: git clone $DOTFILES_REPO $CHEZMOI_SOURCE"
    exit 1
  fi
fi

if [ ! -d "$CHEZMOI_SOURCE/dot_nix" ]; then
  print_error "Nix configuration not found in dotfiles repository"
  print_info "Expected: $CHEZMOI_SOURCE/dot_nix/"
  print_info "Please ensure your dotfiles repo contains the nix configuration"
  exit 1
fi

print_success "Nix config found in chezmoi source directory"

# Check if chezmoi has been applied to ~/.nix
if [ -f "$NIX_CONFIG_DIR/flake.nix" ]; then
  print_success "Nix config already applied at $NIX_CONFIG_DIR"
else
  print_info "Nix config exists in chezmoi but not yet applied"
  print_info "It will be applied when you run: chezmoi apply"
  print_warning "For now, creating symlink to chezmoi source..."

  # Create symlink as temporary solution
  ln -sf "$CHEZMOI_SOURCE/dot_nix" "$NIX_CONFIG_DIR"
  print_success "Symlinked ~/.nix to chezmoi source"
fi

# --- PHASE 3: INSTALL NIX-DARWIN ---
print_info "› Phase 3: Installing nix-darwin..."

if command -v darwin-rebuild &>/dev/null; then
  print_success "nix-darwin is already installed"
else
  print_info "Running initial nix-darwin installation..."

  # First-time installation using nix run
  # flake.nix is guaranteed to exist from Phase 2
  sudo nix run nix-darwin -- switch --flake "$NIX_CONFIG_DIR#$FLAKE_NAME"
  print_success "nix-darwin installed successfully"

  echo ""
  print_warning "Please reload your shell to get darwin-rebuild in PATH:"
  print_info "  source ~/.zshrc"
  print_info ""
  print_info "Then re-run this script to continue with Phase 4:"
  print_info "  ./system-setup.sh"
  echo ""
  exit 0
fi

# --- PHASE 4: APPLY NIX-DARWIN CONFIGURATION ---
print_info "› Phase 4: Applying system configuration..."

if [ -f "$NIX_CONFIG_DIR/flake.nix" ]; then
  cd "$NIX_CONFIG_DIR"

  print_info "Building and switching to nix-darwin configuration..."
  sudo darwin-rebuild switch --flake "$NIX_CONFIG_DIR#$FLAKE_NAME"

  print_success "System configuration applied successfully"
else
  print_warning "No flake.nix found, skipping configuration apply"
  exit 1
fi

# --- COMPLETION ---
echo ""
print_success "=========================================="
print_success "System Setup Complete!"
print_success "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open a new terminal to ensure Nix is in your PATH"
echo "  2. Run user-setup.sh to configure dotfiles and dev tools:"
echo "     curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/user-setup.sh | bash"
echo ""
echo "Configuration location: $NIX_CONFIG_DIR"
echo "To update system packages: sudo darwin-rebuild switch --flake $NIX_CONFIG_DIR#$FLAKE_NAME"
echo ""

exit 0
