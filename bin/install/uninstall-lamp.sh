#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"
. "$SCRIPT_DIR/_common/_help.sh"

show_help() { print_help_uninstall_lamp; }

NON_INTERACTIVE="false"
PURGE="false"
CHECK_ONLY="false"
for arg in "${@:-}"; do
  case "$arg" in
    --help) show_help; exit 0;;
    --purge) PURGE="true";;
    --non-interactive) NON_INTERACTIVE="true";;
    --check) CHECK_ONLY="true";;
  esac
done

log "Starting LAMP uninstall on Debian."

if [ "$CHECK_ONLY" = "true" ]; then
  log "Check-only mode: verifying uninstall state without making changes."
  # Binaries absent
  if command -v apache2 >/dev/null 2>&1; then st=1; else st=0; fi; check_result "apache2 binary absent" "$st" "Found in PATH"
  if command -v php     >/dev/null 2>&1; then st=1; else st=0; fi; check_result "php binary absent" "$st" "Found in PATH"
  if command -v php-fpm >/dev/null 2>&1; then st=1; else st=0; fi; check_result "php-fpm binary absent" "$st" "Found in PATH"
  if command -v mysql   >/dev/null 2>&1; then st=1; else st=0; fi; check_result "mysql binary absent" "$st" "Found in PATH"
  if command -v mariadb >/dev/null 2>&1; then st=1; else st=0; fi; check_result "mariadb binary absent" "$st" "Found in PATH"

  # Services inactive/not found
  systemctl is-active --quiet apache2;  if [ $? -ne 0 ]; then st=0; else st=1; fi; check_result "apache2 service inactive/absent" "$st" "Service active"
  systemctl is-active --quiet mysql;    if [ $? -ne 0 ]; then st=0; else st=1; fi; check_result "mysql service inactive/absent" "$st" "Service active"
  systemctl is-active --quiet mariadb;  if [ $? -ne 0 ]; then st=0; else st=1; fi; check_result "mariadb service inactive/absent" "$st" "Service active"
  # php-fpm wildcard
  if compgen -G "/lib/systemd/system/php*-fpm.service" >/dev/null; then
    for s in /lib/systemd/system/php*-fpm.service; do
      svc=$(basename "$s" .service)
      systemctl is-active --quiet "$svc"; if [ $? -ne 0 ]; then st=0; else st=1; fi; check_result "$svc inactive/absent" "$st" "Service active"
    done
  else
    check_result "php-fpm services inactive/absent" 0
  fi

  # Ports not listening
  if is_port_listening 80;   then st=1; else st=0; fi; check_result "Port 80 not listening" "$st" "Listener detected"
  if is_port_listening 3306; then st=1; else st=0; fi; check_result "Port 3306 not listening" "$st" "Listener detected"

  # Paths removed
  if [ -e "/usr/share/phpmyadmin" ]; then st=1; else st=0; fi; check_result "phpMyAdmin directory removed" "$st" "Exists"
  if [ -e "/var/log/apache2" ]; then st=1; else st=0; fi;     check_result "Apache logs removed" "$st" "Exists"
  if [ -e "/var/lib/mysql" ]; then st=1; else st=0; fi;       check_result "MySQL data dir removed" "$st" "Exists"
  if [ -e "/var/lib/mariadb" ]; then st=1; else st=0; fi;     check_result "MariaDB data dir removed" "$st" "Exists"

  # Hosts entry removed
  if has_hosts_entry "test.localhost"; then st=1; else st=0; fi; check_result "Hosts entry removed (test.localhost)" "$st" "Entry present"

  # Managed vhosts removed
  if no_managed_vhosts_present; then st=0; else st=1; fi; check_result "Managed vhosts removed" "$st" "Managed vhosts still present"

  print_checks_summary
  exit 0
fi

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
