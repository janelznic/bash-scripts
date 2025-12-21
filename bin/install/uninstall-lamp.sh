#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"

show_help() {
cat <<'EOF'
Name: LAMP Uninstaller (Debian 13)

Description:
  Stops services and removes resources created by the LAMP installer.

Author:
  Jan Elznic <jan@elznic.com>, https://janelznic.cz

Usage:
  sudo bin/install/uninstall-lamp.sh [--purge] [--non-interactive]

Options:
  --help             Show this help
  --purge            Remove all created resources and purge packages (apache2, php, mysql/mariadb, phpmyadmin)
  --non-interactive  Skip confirmations

Removes:
  - Services: apache2, php-fpm, mysql/mariadb (stopped always; purged with --purge)
  - Test vhost symlink and site at ~/www/test (entire directory on --purge)
  - Hosts entry for test.localhost
  - Apache confs: user-vhosts, php-fpm-handler, phpmyadmin (disabled and removed)
EOF
}

NON_INTERACTIVE="false"
PURGE="false"
for arg in "${@:-}"; do
  case "$arg" in
    --help) show_help; exit 0;;
    --purge) PURGE="true";;
    --non-interactive) NON_INTERACTIVE="true";;
  esac
done

log "Starting LAMP uninstall on Debian."

# Stop services
sudo systemctl stop apache2 || true
sudo systemctl stop mariadb || true
sudo systemctl stop mysql || true
sudo systemctl stop php*-fpm || true

# Disable services
sudo systemctl disable apache2 || true
sudo systemctl disable mariadb || true
sudo systemctl disable mysql || true
sudo systemctl disable php*-fpm || true

# Remove Apache confs
sudo a2disconf user-vhosts || true
sudo a2disconf php-fpm-handler || true
sudo a2disconf phpmyadmin || true
sudo rm -f /etc/apache2/conf-available/user-vhosts.conf || true
sudo rm -f /etc/apache2/conf-available/php-fpm-handler.conf || true
sudo rm -f /etc/apache2/conf-available/phpmyadmin.conf || true

# Remove hosts entry
if grep -qE "\stest.localhost(\s|$)" /etc/hosts; then
  if [ "$NON_INTERACTIVE" = "true" ] || confirm "Remove hosts entry for test.localhost?"; then
    sudo sed -i.bak "/test\.localhost/d" /etc/hosts
    log "Removed hosts entry for test.localhost"
  fi
fi

# Remove test vhost symlink and directory
VHOST_SYMLINK="$(APACHE_USER_VHOSTS_DIR)/test.conf"
TEST_DIR="$(TEST_VHOST_BASE)"
if [ -L "$VHOST_SYMLINK" ] || [ -e "$VHOST_SYMLINK" ]; then
  rm -f "$VHOST_SYMLINK"
  log "Removed vhost symlink: $VHOST_SYMLINK"
fi

if [ "$PURGE" = "true" ]; then
  if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
    log "Purged test site directory: $TEST_DIR"
  fi
fi

# Purge packages on --purge
if [ "$PURGE" = "true" ]; then
  if [ "$NON_INTERACTIVE" = "true" ] || confirm "Purge Apache, PHP, MySQL/MariaDB, phpMyAdmin packages?"; then
    sudo apt-get update -y || true
    sudo apt-get purge -y apache2 php php-fpm php-curl php-mbstring php-intl php-gd php-xml php-zip php-bcmath php-soap php-mysql mysql-server mariadb-server phpmyadmin || true
    sudo apt-get autoremove -y || true
    log "Packages purged and dependencies autoremoved."
  fi
fi

# Restart apache to apply removal of confs (if still installed)
sudo systemctl restart apache2 || true

print_summary
echo "Debian LAMP uninstall complete."
echo "- Services stopped: apache2, php-fpm, mysql/mariadb"
echo "- Purge: $PURGE"
