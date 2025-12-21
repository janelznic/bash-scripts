#!/usr/bin/env bash
set -euo pipefail

# Shared check routines for install/uninstall verification
# Depends on: _utils.sh (check_result, is_port_listening, print_checks_summary)
# Optionally uses: _brew.sh for Homebrew context on macOS

_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_THIS_DIR/_utils.sh"
# _brew.sh may not exist on Debian; source conditionally
if [ -f "$_THIS_DIR/_brew.sh" ]; then
  . "$_THIS_DIR/_brew.sh"
fi
. "$_THIS_DIR/_apache.sh"

# Helper: run a labeled check comparing actual vs expected (1 present, 0 absent)
_run_check() {
  local label="$1"; local actual="$2"; local expect="$3"; local detail="${4:-}"
  local ok
  if [ "$actual" = "$expect" ]; then ok=0; else ok=1; fi
  check_result "$label" "$ok" "$detail"
}

# macOS (Homebrew) MAMP checks
check_macos_mamp_state() {
  local mode="$1" # 'installed' or 'uninstalled'
  local expect_present expect_absent
  if [ "$mode" = "installed" ]; then
    expect_present=1; expect_absent=0
  else
    expect_present=0; expect_absent=1
  fi

  # Resolve brew prefix under proper user context
  local BREW_PREFIX
  if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew_prefix)
  else
    BREW_PREFIX="/opt/homebrew" # fallback
  fi

  # Binary presence (under brew prefix)
  bin_in_brew_present() {
    local b="$1"; local p
    p=$(command -v "$b" 2>/dev/null || true)
    if [ -n "$p" ] && [[ "$p" == "$BREW_PREFIX"* ]]; then echo 1; else echo 0; fi
  }
  _run_check "httpd binary $( [ "$mode" = installed ] && echo present || echo absent )" \
    "$(bin_in_brew_present httpd)" "$expect_present" "Found in PATH"
  _run_check "php binary $( [ "$mode" = installed ] && echo present || echo absent )" \
    "$(bin_in_brew_present php)" "$expect_present" "Found in PATH"
  _run_check "mysql binary $( [ "$mode" = installed ] && echo present || echo absent )" \
    "$(bin_in_brew_present mysql)" "$expect_present" "Found in PATH"

  # Services listed in brew services
  local svc_httpd=0 svc_php=0 svc_mysql=0
  if command -v brew >/dev/null 2>&1; then
    brew_services_as_user list >/tmp/_brew_services_$$ 2>/dev/null || true
    if grep -E '^httpd\s' /tmp/_brew_services_$$ >/dev/null 2>&1; then svc_httpd=1; else svc_httpd=0; fi
    if grep -E '^php\s'   /tmp/_brew_services_$$ >/dev/null 2>&1; then svc_php=1;   else svc_php=0;   fi
    if grep -E '^mysql\s' /tmp/_brew_services_$$ >/dev/null 2>&1; then svc_mysql=1; else svc_mysql=0; fi
    rm -f /tmp/_brew_services_$$ || true
  fi
  _run_check "httpd service $( [ "$mode" = installed ] && echo listed/active || echo stopped/absent )" "$svc_httpd" "$expect_present" "Service state differs"
  _run_check "php service $( [ "$mode" = installed ] && echo listed/active || echo stopped/absent )" "$svc_php" "$expect_present" "Service state differs"
  _run_check "mysql service $( [ "$mode" = installed ] && echo listed/active || echo stopped/absent )" "$svc_mysql" "$expect_present" "Service state differs"

  # Ports listening
  local http_listen=0 mysql_listen=0
  if is_port_listening 80; then http_listen=1; else http_listen=0; fi
  if is_port_listening 3306; then mysql_listen=1; else mysql_listen=0; fi
  _run_check "Port 80 $( [ "$mode" = installed ] && echo listening || echo not listening )" "$http_listen" "$expect_present" "Listener state differs"
  _run_check "Port 3306 $( [ "$mode" = installed ] && echo listening || echo not listening )" "$mysql_listen" "$expect_present" "Listener state differs"

  # Paths
  local PMA_DIR="$BREW_PREFIX/var/www/phpmyadmin"
  local HTTPD_LOG_DIR="$BREW_PREFIX/var/log/httpd"
  local MYSQL_DATA_DIR="$BREW_PREFIX/var/mysql"
  local pma_present=0 httpd_logs_present=0 mysql_data_present=0
  [ -e "$PMA_DIR" ] && pma_present=1
  [ -e "$HTTPD_LOG_DIR" ] && httpd_logs_present=1
  [ -e "$MYSQL_DATA_DIR" ] && mysql_data_present=1
  _run_check "phpMyAdmin directory $( [ "$mode" = installed ] && echo present || echo removed )" "$pma_present" "$expect_present" "Exists: $PMA_DIR"
  _run_check "httpd logs $( [ "$mode" = installed ] && echo present || echo removed )" "$httpd_logs_present" "$expect_present" "Exists: $HTTPD_LOG_DIR"
  _run_check "MySQL data dir $( [ "$mode" = installed ] && echo present || echo removed )" "$mysql_data_present" "$expect_present" "Exists: $MYSQL_DATA_DIR"

  # Hosts entry
  local hosts_present=0
  if has_hosts_entry "test.localhost"; then hosts_present=1; else hosts_present=0; fi
  _run_check "Hosts entry $( [ "$mode" = installed ] && echo present || echo removed ) (test.localhost)" "$hosts_present" "$expect_present" "Entry differs"

  # Managed vhosts
  local managed_present=0
  local mf="$(APACHE_USER_VHOSTS_DIR)/.managed_vhosts"
  if [ -f "$mf" ]; then
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      local path="$(APACHE_USER_VHOSTS_DIR)/$name"
      if [ -e "$path" ] || [ -L "$path" ]; then managed_present=1; break; fi
    done < "$mf"
  fi
  _run_check "Managed vhosts $( [ "$mode" = installed ] && echo present || echo removed )" "$managed_present" "$expect_present" "Managed vhosts state differs"

  print_checks_summary
}

# Debian LAMP checks
check_debian_lamp_state() {
  local mode="$1" # 'installed' or 'uninstalled'
  local expect_present expect_absent
  if [ "$mode" = "installed" ]; then
    expect_present=1; expect_absent=0
  else
    expect_present=0; expect_absent=1
  fi

  # Binaries
  bin_present() { command -v "$1" >/dev/null 2>&1 && echo 1 || echo 0; }
  _run_check "apache2 binary $( [ "$mode" = installed ] && echo present || echo absent )" "$(bin_present apache2)" "$expect_present" "Found in PATH"
  _run_check "php binary $( [ "$mode" = installed ] && echo present || echo absent )" "$(bin_present php)" "$expect_present" "Found in PATH"
  _run_check "php-fpm binary $( [ "$mode" = installed ] && echo present || echo absent )" "$(bin_present php-fpm)" "$expect_present" "Found in PATH"
  _run_check "mysql binary $( [ "$mode" = installed ] && echo present || echo absent )" "$(bin_present mysql)" "$expect_present" "Found in PATH"
  _run_check "mariadb binary $( [ "$mode" = installed ] && echo present || echo absent )" "$(bin_present mariadb)" "$expect_present" "Found in PATH"

  # Services via systemctl
  svc_present() { systemctl is-active --quiet "$1" && echo 1 || echo 0; }
  _run_check "apache2 service $( [ "$mode" = installed ] && echo active || echo inactive/absent )" "$(svc_present apache2)" "$expect_present" "Service state differs"
  _run_check "mysql service $( [ "$mode" = installed ] && echo active || echo inactive/absent )" "$(svc_present mysql)" "$expect_present" "Service state differs"
  _run_check "mariadb service $( [ "$mode" = installed ] && echo active || echo inactive/absent )" "$(svc_present mariadb)" "$expect_present" "Service state differs"
  # php-fpm wildcard services
  local fpm_any=0
  if compgen -G "/lib/systemd/system/php*-fpm.service" >/dev/null; then
    for s in /lib/systemd/system/php*-fpm.service; do
      svc=$(basename "$s" .service)
      local active=$(svc_present "$svc")
      _run_check "$svc $( [ "$mode" = installed ] && echo active || echo inactive/absent )" "$active" "$expect_present" "Service state differs"
      [ "$active" = "1" ] && fpm_any=1
    done
  else
    _run_check "php-fpm services $( [ "$mode" = installed ] && echo present/active || echo inactive/absent )" 0 "$expect_absent"
  fi

  # Ports listening
  local http_listen=0 mysql_listen=0
  if is_port_listening 80; then http_listen=1; else http_listen=0; fi
  if is_port_listening 3306; then mysql_listen=1; else mysql_listen=0; fi
  _run_check "Port 80 $( [ "$mode" = installed ] && echo listening || echo not listening )" "$http_listen" "$expect_present" "Listener state differs"
  _run_check "Port 3306 $( [ "$mode" = installed ] && echo listening || echo not listening )" "$mysql_listen" "$expect_present" "Listener state differs"

  # Paths
  local pma_present=0 apache_logs_present=0 mysql_data_present=0 mariadb_data_present=0
  [ -e "/usr/share/phpmyadmin" ] && pma_present=1
  [ -e "/var/log/apache2" ] && apache_logs_present=1
  [ -e "/var/lib/mysql" ] && mysql_data_present=1
  [ -e "/var/lib/mariadb" ] && mariadb_data_present=1
  _run_check "phpMyAdmin directory $( [ "$mode" = installed ] && echo present || echo removed )" "$pma_present" "$expect_present" "Exists"
  _run_check "Apache logs $( [ "$mode" = installed ] && echo present || echo removed )" "$apache_logs_present" "$expect_present" "Exists"
  _run_check "MySQL data dir $( [ "$mode" = installed ] && echo present || echo removed )" "$mysql_data_present" "$expect_present" "Exists"
  _run_check "MariaDB data dir $( [ "$mode" = installed ] && echo present || echo removed )" "$mariadb_data_present" "$expect_present" "Exists"

  # Hosts entry
  local hosts_present=0
  if has_hosts_entry "test.localhost"; then hosts_present=1; else hosts_present=0; fi
  _run_check "Hosts entry $( [ "$mode" = installed ] && echo present || echo removed ) (test.localhost)" "$hosts_present" "$expect_present" "Entry differs"

  # Managed vhosts
  local managed_present=0
  local mf="$(APACHE_USER_VHOSTS_DIR)/.managed_vhosts"
  if [ -f "$mf" ]; then
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      local path="$(APACHE_USER_VHOSTS_DIR)/$name"
      if [ -e "$path" ] || [ -L "$path" ]; then managed_present=1; break; fi
    done < "$mf"
  fi
  _run_check "Managed vhosts $( [ "$mode" = installed ] && echo present || echo removed )" "$managed_present" "$expect_present" "Managed vhosts state differs"

  print_checks_summary
}
