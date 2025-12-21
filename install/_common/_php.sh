#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/_utils.sh"

install_php_mac() {
  require_command brew
  brew install php || true
  # Ensure PHP-FPM runs
  brew services start php || brew services restart php || true
  log "PHP installed and PHP-FPM started on macOS."
}

install_php_debian() {
  sudo apt-get update -y
  # PHP-FPM and common extensions
  sudo apt-get install -y \
    php php-fpm php-curl php-mbstring php-intl php-gd php-xml php-zip php-bcmath php-soap php-mysql
  sudo systemctl enable --now php*-fpm || true
  log "PHP-FPM and common extensions installed on Debian."
}
