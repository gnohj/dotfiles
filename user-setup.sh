#!/usr/bin/env bash
# User setup script - Configures user-level dotfiles and development tools

# Prerequisites:
#   - Nix and nix-darwin should be installed (run system-setup.sh first)
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
  print_info "Please run system-setup.sh first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/system-setup.sh | bash"
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

# --- PHASE 2: SSH KEY AND SECRETS SETUP FROM BITWARDEN ---
print_info "› Phase 2: Setting up SSH keys and secrets from Bitwarden..."

# Check if we need to unlock Bitwarden
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

          # Add GitHub to known_hosts only if not already present
          touch "$HOME/.ssh/known_hosts" # Ensure file exists
          if ! grep -q "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
            ssh-keyscan github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
            print_info "Added github.com to known_hosts"
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
echo "  • System: ~/nix/nix-darwin/"
echo "  • Dotfiles: ~/.local/share/chezmoi/"
echo "  • Languages: ~/.config/mise/config.toml"
echo ""

exit 0
