#!/usr/bin/env bash
set -euo pipefail

# Homebrew helpers to run under invoking user context when script is run with sudo
brew_as_user() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew "$@"
  else
    brew "$@"
  fi
}

brew_services_as_user() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew services "$@"
  else
    brew services "$@"
  fi
}

brew_prefix() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew --prefix
  else
    brew --prefix
  fi
}
