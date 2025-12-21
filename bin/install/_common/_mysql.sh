#!/usr/bin/env bash
set -euo pipefail

# Source utils relative to this helper file (robust across CWD)
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_THIS_DIR/_utils.sh"

MYSQL_ROOT_PASSWORD_DEFAULT="aaa"

configure_mysql_root_password() {
  local pass="${1:-${MYSQL_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD_DEFAULT}}"

  if command -v mysql >/dev/null 2>&1; then
    # Try MySQL 8+ component uninstall for validate_password (may fail harmlessly)
    mysql -h 127.0.0.1 -uroot <<SQL || true
UNINSTALL COMPONENT 'file://component_validate_password';
SQL

    # Attempt password set using mysql_native_password
    mysql -h 127.0.0.1 -uroot <<SQL || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '$pass';
FLUSH PRIVILEGES;
SQL
    log "MySQL root password configured."
    return
  fi

  if command -v mariadb >/dev/null 2>&1; then
    # MariaDB often uses unix_socket plugin for root. Switch to password.
    sudo mariadb -u root <<SQL || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '$pass';
FLUSH PRIVILEGES;
SQL
    log "MariaDB root password configured."
    return
  elif command -v mysql >/dev/null 2>&1; then
    mysql -h 127.0.0.1 -uroot <<SQL || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '$pass';
FLUSH PRIVILEGES;
SQL
    log "MySQL root password configured (fallback)."
    return
  fi

  warn "MySQL/MariaDB client not found; ensure the server installed and running before setting password."
}

install_mysql_mac() {
  require_command brew
  brew install mysql || true
  brew services start mysql || brew services restart mysql || true
  log "MySQL installed and started on macOS."
  configure_mysql_root_password "$MYSQL_ROOT_PASSWORD_DEFAULT"
}

install_mysql_debian() {
  sudo apt-get update -y
  # Prefer Oracle MySQL if available; otherwise MariaDB
  if apt-cache show mysql-server >/dev/null 2>&1; then
    sudo apt-get install -y mysql-server
    sudo systemctl enable --now mysql
  else
    sudo apt-get install -y mariadb-server
    sudo systemctl enable --now mariadb || sudo systemctl enable --now mysql || true
  fi
  log "MySQL/MariaDB installed and started on Debian."
  configure_mysql_root_password "$MYSQL_ROOT_PASSWORD_DEFAULT"
}
