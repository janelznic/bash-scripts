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
  read -r MYSQL_ROOT_PASSWORD
  if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD="$default"
    warn "Empty input; defaulting MySQL root password to: $MYSQL_ROOT_PASSWORD"
  else
    log "MySQL root password captured: $MYSQL_ROOT_PASSWORD"
  fi
}

# ---------- Verification helpers ----------
CHECKS_TOTAL=0
CHECKS_OK=0

check_result() {
  local label="$1"; local ok="$2"; local detail="${3:-}"
  CHECKS_TOTAL=$((CHECKS_TOTAL+1))
  if [ "$ok" = "0" ]; then
    CHECKS_OK=$((CHECKS_OK+1))
    printf "✅ %s\n" "$label"
  else
    if [ -n "$detail" ]; then
      printf "❌ %s — %s\n" "$label" "$detail"
    else
      printf "❌ %s\n" "$label"
    fi
  fi
}

command_absent() { command -v "$1" >/dev/null 2>&1; return $([ $? -ne 0 ] && echo 0 || echo 1); }

path_absent() { [ ! -e "$1" ]; return $([ $? -eq 0 ] && echo 0 || echo 1); }

is_port_listening() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  elif command -v netstat >/dev/null 2>&1; then
    netstat -an | grep -E "\.${port} .*LISTEN" >/dev/null 2>&1
    return $?
  else
    # Fallback using nc (may not be reliable for listeners)
    return 1
  fi
}

print_checks_summary() {
  echo ""
  echo "Verification summary: $CHECKS_OK/$CHECKS_TOTAL checks passed"
}

# ---------- Apache port helpers ----------
APACHE_PORT_DEFAULT=80

parse_apache_port() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --apache-port=*) APACHE_PORT="${arg#*=}" ;;
    esac
  done
  # Handle separated form
  local i=1
  while [ $i -le $# ]; do
    arg="${!i}"
    if [ "$arg" = "--apache-port" ]; then
      i=$((i+1))
      APACHE_PORT="${!i:-}"
      break
    fi
    i=$((i+1))
  done
}

prompt_apache_port() {
  local default="${1:-$APACHE_PORT_DEFAULT}"
  local non_interactive="${2:-false}"
  if [ -n "${APACHE_PORT:-}" ]; then
    return
  fi
  if [ "$non_interactive" = "true" ]; then
    APACHE_PORT="$default"
    log "Using default Apache port (non-interactive): $APACHE_PORT"
    return
  fi
  printf "Enter Apache port (e.g. 80 or 8080): "
  read -r APACHE_PORT
  if ! echo "$APACHE_PORT" | grep -qE '^[0-9]+$'; then
    APACHE_PORT="$default"
    warn "Invalid input; defaulting Apache port to: $APACHE_PORT"
  else
    log "Apache port captured: $APACHE_PORT"
  fi
}
