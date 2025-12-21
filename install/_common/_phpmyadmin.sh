#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/_utils.sh"

PHPMYADMIN_DOWNLOAD_URL="https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"

install_phpmyadmin_mac() {
  require_command curl
  local target_root="$(brew --prefix)/var/www/phpmyadmin"
  ensure_dir "$target_root"

  local tmp="$(mktemp -d)"
  curl -fsSL "$PHPMYADMIN_DOWNLOAD_URL" -o "$tmp/pma.tar.gz"
  tar -xzf "$tmp/pma.tar.gz" -C "$tmp"
  local extracted
  extracted=$(find "$tmp" -maxdepth 1 -type d -name "phpMyAdmin-*" | head -n1)
  rsync -a "$extracted/" "$target_root/"
  rm -rf "$tmp"

  # Basic config.inc.php with random blowfish secret
  local cfg="$target_root/config.inc.php"
  if [ ! -f "$cfg" ]; then
    local secret; secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    cat > "$cfg" <<EOF
<?php
$cfg = array();
$cfg['blowfish_secret'] = '$secret';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['host'] = 'localhost';
EOF
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
    sudo rsync -a "$extracted/" "$target_root/"
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
