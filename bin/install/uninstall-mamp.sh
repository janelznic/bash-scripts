#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"
. "$SCRIPT_DIR/_common/_help.sh"

show_help() { print_help_uninstall_mamp; }

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

log "Starting MAMP uninstall on macOS."

require_command brew

if [ "$CHECK_ONLY" = "true" ]; then
  log "Check-only mode: verifying uninstall state without making changes."
  # Checks: commands absent (avoid set -e by using if/else)
  if command -v httpd >/dev/null 2>&1; then st=1; else st=0; fi; check_result "httpd binary absent" "$st" "Found in PATH"
  if command -v php   >/dev/null 2>&1; then st=1; else st=0; fi; check_result "php binary absent" "$st" "Found in PATH"
  if command -v mysql >/dev/null 2>&1; then st=1; else st=0; fi; check_result "mysql binary absent" "$st" "Found in PATH"

  # Services stopped
  brew services list >/tmp/_brew_services_$$ 2>/dev/null || true
  grep -E '^httpd\s' /tmp/_brew_services_$$ >/dev/null 2>&1; svc_httpd=$?
  grep -E '^php\s' /tmp/_brew_services_$$ >/dev/null 2>&1; svc_php=$?
  grep -E '^mysql\s' /tmp/_brew_services_$$ >/dev/null 2>&1; svc_mysql=$?
  rm -f /tmp/_brew_services_$$
  if [ $svc_httpd -ne 0 ]; then st=0; else st=1; fi; check_result "httpd service stopped/absent" "$st" "Service still listed"
  if [ $svc_php   -ne 0 ]; then st=0; else st=1; fi; check_result "php service stopped/absent" "$st" "Service still listed"
  if [ $svc_mysql -ne 0 ]; then st=0; else st=1; fi; check_result "mysql service stopped/absent" "$st" "Service still listed"

  # Ports not listening: 80 (httpd), 3306 (mysql)
  if is_port_listening 80; then st=1; else st=0; fi;   check_result "Port 80 not listening" "$st" "Listener detected"
  if is_port_listening 3306; then st=1; else st=0; fi; check_result "Port 3306 not listening" "$st" "Listener detected"

  # Paths removed
  BREW_PREFIX=$(brew --prefix)
  PMA_DIR="$BREW_PREFIX/var/www/phpmyadmin"
  HTTPD_LOG_DIR="$BREW_PREFIX/var/log/httpd"
  MYSQL_DATA_DIR="$BREW_PREFIX/var/mysql"
  if [ -e "$PMA_DIR" ]; then st=1; else st=0; fi;        check_result "phpMyAdmin directory removed" "$st" "Exists: $PMA_DIR"
  if [ -e "$HTTPD_LOG_DIR" ]; then st=1; else st=0; fi;  check_result "httpd logs removed" "$st" "Exists: $HTTPD_LOG_DIR"
  if [ -e "$MYSQL_DATA_DIR" ]; then st=1; else st=0; fi; check_result "MySQL data dir removed" "$st" "Exists: $MYSQL_DATA_DIR"

  # Hosts entry removed
  if has_hosts_entry "test.localhost"; then st=1; else st=0; fi; check_result "Hosts entry removed (test.localhost)" "$st" "Entry present"

  # Managed vhosts removed
  if no_managed_vhosts_present; then st=0; else st=1; fi; check_result "Managed vhosts removed" "$st" "Managed vhosts still present"

  print_checks_summary
  exit 0
fi

# Stop services (try non-sudo, then sudo)
stop_brew_service() { brew services stop "$1" || sudo brew services stop "$1" || true; }
stop_brew_service httpd
stop_brew_service php
stop_brew_service mysql

# Paths
BREW_PREFIX=$(brew --prefix)
APACHE_CONF="$BREW_PREFIX/etc/httpd/httpd.conf"
PMA_DIR="$BREW_PREFIX/var/www/phpmyadmin"

# Remove hosts entry and vhost symlink; purge dir if requested
if [ "$NON_INTERACTIVE" = "true" ] || confirm "Remove hosts entry for test.localhost?"; then
  remove_hosts_entry "test.localhost"
fi
remove_test_vhost_symlink
[ "$PURGE" = "true" ] && purge_test_vhost_dir

# Paths
BREW_PREFIX=$(brew --prefix)
APACHE_CONF="$BREW_PREFIX/etc/httpd/httpd.conf"
PMA_DIR="$BREW_PREFIX/var/www/phpmyadmin"
HTTPD_LOG_DIR="$BREW_PREFIX/var/log/httpd"
PHP_LOG_DIR="$BREW_PREFIX/var/log"
MYSQL_DATA_DIR="$BREW_PREFIX/var/mysql"

# Always uninstall packages (even without --purge)
brew uninstall httpd || true
brew uninstall php || true
brew uninstall mysql || true
log "Homebrew packages uninstalled (httpd, php, mysql)."

if [ "$PURGE" = "true" ]; then
  # Remove phpMyAdmin directory
  if [ -d "$PMA_DIR" ]; then
    rm -rf "$PMA_DIR"
    log "Purged phpMyAdmin directory: $PMA_DIR"
  fi
  # Remove logs and caches for httpd/php/mysql (best-effort)
  [ -d "$HTTPD_LOG_DIR" ] && rm -rf "$HTTPD_LOG_DIR" && log "Purged httpd logs: $HTTPD_LOG_DIR"
  # Remove php-fpm logs if present
  find "$PHP_LOG_DIR" -maxdepth 1 -name 'php-fpm*' -exec rm -f {} \; 2>/dev/null || true
  # Remove MySQL data directory
  [ -d "$MYSQL_DATA_DIR" ] && rm -rf "$MYSQL_DATA_DIR" && log "Purged MySQL data dir: $MYSQL_DATA_DIR"
  # Remove all managed vhosts recorded by installer
  remove_all_managed_vhosts
fi

# Optionally clean Apache httpd.conf entries we added (best-effort)
if [ -f "$APACHE_CONF" ]; then
  # Remove IncludeOptional user vhosts line
  sudo sed -i.bak "/IncludeOptional $(APACHE_USER_VHOSTS_DIR | sed 's|/|\\/|g')\/\*.conf/d" "$APACHE_CONF" || true
  # Remove phpMyAdmin Alias block
  sudo awk 'BEGIN{skip=0} /Alias \/phpmyadmin/{skip=1} skip && /<Directory/{next} skip && /<\/Directory>/{skip=0; next} !skip {print}' "$APACHE_CONF" | sudo tee "$APACHE_CONF.tmp" >/dev/null || true
  if [ -s "$APACHE_CONF.tmp" ]; then sudo mv "$APACHE_CONF.tmp" "$APACHE_CONF"; fi
fi

# Already uninstalled above; purge handles deep cleanup

print_summary
echo "macOS MAMP uninstall complete."
echo "- Services stopped: httpd, php, mysql"
echo "- Purge: $PURGE"
