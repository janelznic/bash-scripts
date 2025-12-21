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

# MySQL root password handling (shared)
parse_mysql_root_password() {
  # Parses --mysql-root-password <pwd> or --mysql-root-password=<pwd>
  local arg
  for arg in "$@"; do
    case "$arg" in
      --mysql-root-password=*) MYSQL_ROOT_PASSWORD="${arg#*=}" ;;
    esac
  done
  # Handle separated form
  local i=1
  while [ $i -le $# ]; do
    arg="${!i}"
    if [ "$arg" = "--mysql-root-password" ]; then
      i=$((i+1))
      MYSQL_ROOT_PASSWORD="${!i:-}"
      break
    fi
    i=$((i+1))
  done
}

prompt_mysql_root_password() {
  local default="${1:-aaa}"
  local non_interactive="${2:-false}"
  if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
    return
  fi
  if [ "$non_interactive" = "true" ]; then
    MYSQL_ROOT_PASSWORD="$default"
    log "Using default MySQL root password (non-interactive): $MYSQL_ROOT_PASSWORD"
    return
  fi
  printf "Enter MySQL root password: "
  read -r -s MYSQL_ROOT_PASSWORD
  echo ""
  if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD="$default"
    warn "Empty input; defaulting MySQL root password to: $MYSQL_ROOT_PASSWORD"
  else
    log "MySQL root password captured."
  fi
}
