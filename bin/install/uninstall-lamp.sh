#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"
. "$SCRIPT_DIR/_common/_help.sh"

show_help() { print_help_uninstall_lamp; }

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

# Remove hosts entry and vhost symlink; purge dir if requested
if [ "$NON_INTERACTIVE" = "true" ] || confirm "Remove hosts entry for test.localhost?"; then
  remove_hosts_entry "test.localhost"
fi
remove_test_vhost_symlink
[ "$PURGE" = "true" ] && purge_test_vhost_dir

# Always uninstall packages (remove but keep configs)
sudo apt-get update -y || true
sudo apt-get remove -y apache2 php php-fpm php-curl php-mbstring php-intl php-gd php-xml php-zip php-bcmath php-soap php-mysql mysql-server mariadb-server phpmyadmin || true
sudo apt-get autoremove -y || true
log "Packages removed and dependencies autoremoved."

# On --purge, deep clean logs, data and configs
if [ "$PURGE" = "true" ]; then
  sudo apt-get purge -y apache2 php php-fpm php-curl php-mbstring php-intl php-gd php-xml php-zip php-bcmath php-soap php-mysql mysql-server mariadb-server phpmyadmin || true
  sudo apt-get autoremove -y || true
  # Remove logs and data directories
  sudo rm -rf /var/log/apache2 || true
  sudo rm -rf /var/log/mysql /var/log/mariadb || true
  sudo rm -rf /var/lib/mysql /var/lib/mariadb || true
  # Remove phpMyAdmin files if present
  sudo rm -rf /usr/share/phpmyadmin || true
  # Remove all managed vhosts recorded by installer
  remove_all_managed_vhosts
  log "Purged logs, data directories, phpMyAdmin, and managed vhosts."
fi

# Restart apache to apply removal of confs (if still installed)
sudo systemctl restart apache2 || true

print_summary
echo "Debian LAMP uninstall complete."
echo "- Services stopped: apache2, php-fpm, mysql/mariadb"
echo "- Purge: $PURGE"
