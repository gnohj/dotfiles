#!/usr/bin/env bash
# System utils - Platform detection and utility functions

print_info() {
  printf "\n\e[1;34m%s\e[0m\n" "$1"
}

print_success() {
  printf "\e[1;32m✓ %s\e[0m\n" "$1"
}

print_warning() {
  printf "\e[1;33m⚠ %s\e[0m\n" "$1"
}

print_error() {
  printf "\e[1;31m✗ %s\e[0m\n" "$1" >&2
}

detect_os() {
  OS="$(uname -s)"
  export OS

  case "$OS" in
  Darwin)
    export OS_TYPE="macos"
    ;;
  Linux)
    export OS_TYPE="linux"
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      export LINUX_DISTRO="$ID"
    fi
    ;;
  *)
    print_error "Unsupported OS: $OS"
    return 1
    ;;
  esac
}

detect_arch() {
  ARCH="$(uname -m)"
  export ARCH

  case "$ARCH" in
  arm64 | aarch64)
    export ARCH_TYPE="arm64"
    if [ "$OS" = "Darwin" ]; then
      export NIX_SYSTEM="aarch64-darwin"
    else
      export NIX_SYSTEM="aarch64-linux"
    fi
    ;;
  x86_64 | amd64)
    export ARCH_TYPE="x86_64"
    if [ "$OS" = "Darwin" ]; then
      export NIX_SYSTEM="x86_64-darwin"
    else
      export NIX_SYSTEM="x86_64-linux"
    fi
    ;;
  *)
    print_error "Unsupported architecture: $ARCH"
    return 1
    ;;
  esac
}

# --- Combined Platform Info ---
detect_platform() {
  detect_os || return 1
  detect_arch || return 1

  case "$OS_TYPE" in
  linux)
    export SUDO="sudo"
    ;;
  macos)
    export SUDO=""
    ;;
  esac

  print_info "Platform Detection"
  echo "  OS:           $OS ($OS_TYPE)"
  echo "  Architecture: $ARCH ($ARCH_TYPE)"
  echo "  Nix System:   $NIX_SYSTEM"

  if [ "$OS_TYPE" = "linux" ] && [ -n "$LINUX_DISTRO" ]; then
    echo "  Linux Distro: $LINUX_DISTRO"
  fi
}

require_macos() {
  detect_os
  if [ "$OS_TYPE" != "macos" ]; then
    print_error "This script requires macOS"
    exit 1
  fi
}

require_linux() {
  detect_os
  if [ "$OS_TYPE" != "linux" ]; then
    print_error "This script requires Linux"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
