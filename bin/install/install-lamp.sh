#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_help.sh"
. "$SCRIPT_DIR/_common/_apache.sh"
. "$SCRIPT_DIR/_common/_php.sh"
. "$SCRIPT_DIR/_common/_mysql.sh"
. "$SCRIPT_DIR/_common/_phpmyadmin.sh"
. "$SCRIPT_DIR/_common/_checks.sh"

NON_INTERACTIVE="false"
CHECK_ONLY="false"
for arg in "$@"; do
  case "$arg" in
    --help) print_help; exit 0;;
    --non-interactive) NON_INTERACTIVE="true";;
    --check) CHECK_ONLY="true";;
  esac
done

# Parse and prompt for MySQL root password (shared) unless in check-only mode
if [ "$CHECK_ONLY" != "true" ]; then
  parse_mysql_root_password "$@"
  prompt_mysql_root_password "aaa" "$NON_INTERACTIVE"
  parse_apache_port "$@"
  prompt_apache_port 80 "$NON_INTERACTIVE"
fi

log "Starting LAMP setup for Debian 13 Trixie."

if [ "$CHECK_ONLY" = "true" ]; then
  log "Check-only mode: verifying install state without making changes."
  check_debian_lamp_state "installed"
  exit 0
fi

if [ "$NON_INTERACTIVE" != "true" ]; then
  confirm "Proceed to install Apache2, PHP-FPM + common extensions, MySQL/MariaDB, and phpMyAdmin via apt?" || die "Aborted by user."
fi

# Install Apache2
sudo apt-get update -y
sudo apt-get install -y apache2 curl rsync

# Install PHP and common extensions
install_php_debian

# Install MySQL or MariaDB and set root password
install_mysql_debian

# Install phpMyAdmin (prefer apt, else manual)
PHPMYADMIN_DIR=$(install_phpmyadmin_debian)

# Prepare vhosts and test site
create_user_vhosts_dir
create_test_vhost_structure
write_test_vhost_conf
symlink_test_vhost_into_user_dir
add_hosts_entry_if_missing

# Configure Apache: enable modules, include vhosts, PHP-FPM handler, phpMyAdmin alias on chosen port
configure_apache_debian "$PHPMYADMIN_DIR" "$APACHE_PORT"

print_summary
echo "Debian LAMP setup complete."
echo "- Apache includes: $(APACHE_USER_VHOSTS_DIR)/*.conf"
echo "- Test site: http://test.localhost (added to /etc/hosts)"
echo "- phpMyAdmin: http://localhost/phpmyadmin"
