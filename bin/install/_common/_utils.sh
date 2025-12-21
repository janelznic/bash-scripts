#!/usr/bin/env bash
set -euo pipefail

# Common utilities (logging, checks, path helpers)

_AUTHOR_NAME="Jan Elznic"
_AUTHOR_EMAIL="jan@elznic.com"
_AUTHOR_URL="https://janelznic.cz"

log() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
error() { printf "[ERROR] %s\n" "$*" 1>&2; }
die() { error "$*"; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found. Please install it first."
}

ensure_dir() {
  local d="$1"; shift || true
  if [ ! -d "$d" ]; then
    mkdir -p "$d"
    log "Created directory: $d"
  fi
}

symlink_force() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -f "$dst"
  fi
  ln -s "$src" "$dst"
  log "Symlinked $dst -> $src"
}

detect_user_home() {
  # Prefer invoking user's home when running under sudo
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    eval echo "~$SUDO_USER"
  else
    echo "$HOME"
  fi
}

confirm() {
  local prompt="$1"
  local default_yes="${2:-yes}"
  local yn="[Y/n]"
  if [ "$default_yes" != "yes" ]; then yn="[y/N]"; fi
  read -r -p "$prompt $yn " ans || true
  if [ -z "$ans" ]; then
    [ "$default_yes" = "yes" ] && return 0 || return 1
  fi
  case "$ans" in
    y|Y|yes|YES) return 0;;
    *) return 1;;
  esac
}

print_summary() {
  echo ""
  echo "Setup complete. Author: $_AUTHOR_NAME <$_AUTHOR_EMAIL>, $_AUTHOR_URL"
}
