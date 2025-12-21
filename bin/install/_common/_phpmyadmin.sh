#!/usr/bin/env bash
set -euo pipefail

# Source utils relative to this helper file (robust across CWD)
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_THIS_DIR/_utils.sh"
if [ -f "$_THIS_DIR/_brew.sh" ]; then
  . "$_THIS_DIR/_brew.sh"
fi

PHPMYADMIN_DOWNLOAD_URL="https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"

install_phpmyadmin_mac() {
  require_command curl
  local brew_prefix
  if command -v brew_prefix >/dev/null 2>&1; then
    brew_prefix=$(brew_prefix)
  else
    brew_prefix=$(brew --prefix)
  fi
  # Ensure parent web root exists first (with sudo fallback)
  if ! mkdir -p "$brew_prefix/var/www" >/dev/null 2>&1; then
    sudo mkdir -p "$brew_prefix/var/www"
  fi
  local target_root="$brew_prefix/var/www/phpmyadmin"
  if ! mkdir -p "$target_root" >/dev/null 2>&1; then
    sudo mkdir -p "$target_root"
  fi

  local tmp="$(mktemp -d)"
  curl -fsSL "$PHPMYADMIN_DOWNLOAD_URL" -o "$tmp/pma.tar.gz"
  tar -xzf "$tmp/pma.tar.gz" -C "$tmp"
  local extracted
  extracted=$(find "$tmp" -maxdepth 1 -type d -name "phpMyAdmin-*" | head -n1)
  if [ -z "$extracted" ]; then
    die "Failed to extract phpMyAdmin archive."
  fi
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$extracted/" "$target_root/" || sudo rsync -a "$extracted/" "$target_root/"
  else
    cp -R "$extracted/"* "$target_root/" || sudo cp -R "$extracted/"* "$target_root/"
  fi
  rm -rf "$tmp"

  # Basic config.inc.php with random blowfish secret
  local cfg="$target_root/config.inc.php"
  if [ ! -f "$cfg" ]; then
    local secret; secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    sudo bash -c "cat > '$cfg' <<EOF
<?php
$cfg = array();
$cfg['blowfish_secret'] = '$secret';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['host'] = 'localhost';
EOF
"
    log "phpMyAdmin configured at $target_root"
  fi

  echo "$target_root"
}

install_phpmyadmin_debian() {
  local target_root="/usr/share/phpmyadmin"
  if apt-cache show phpmyadmin >/dev/null 2>&1; then
    sudo apt-get install -y phpmyadmin || true
    target_root="/usr/share/phpmyadmin"
  else
    require_command curl
    target_root="/usr/share/phpmyadmin"
    sudo mkdir -p "$target_root"
    local tmp="$(mktemp -d)"
    curl -fsSL "$PHPMYADMIN_DOWNLOAD_URL" -o "$tmp/pma.tar.gz"
    tar -xzf "$tmp/pma.tar.gz" -C "$tmp"
    local extracted
    extracted=$(find "$tmp" -maxdepth 1 -type d -name "phpMyAdmin-*" | head -n1)
    if [ -z "$extracted" ]; then
      die "Failed to extract phpMyAdmin archive."
    fi
    if command -v rsync >/dev/null 2>&1; then
      sudo rsync -a "$extracted/" "$target_root/"
    else
      sudo cp -R "$extracted/"* "$target_root/"
    fi
    rm -rf "$tmp"
  fi

  # Basic config.inc.php
  local cfg="$target_root/config.inc.php"
  if [ ! -f "$cfg" ]; then
    local secret; secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    sudo bash -c "cat > '$cfg' <<'EOF'
<?php
$cfg = array();
$cfg['blowfish_secret'] = '$secret';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['host'] = 'localhost';
EOF
"
    log "phpMyAdmin configured at $target_root"
  fi

  echo "$target_root"
}
