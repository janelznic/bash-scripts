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

log "Starting MAMP setup for macOS (Apple Silicon)."

require_command brew

if [ "$CHECK_ONLY" = "true" ]; then
  log "Check-only mode: verifying install state without making changes."
  check_macos_mamp_state "installed"
  exit 0
fi

if [ "$NON_INTERACTIVE" != "true" ]; then
  confirm "Proceed to install Apache, PHP, MySQL, and phpMyAdmin via Homebrew?" || die "Aborted by user."
fi

# Install core components
brew install httpd || true
install_php_mac
install_mysql_mac

# Install phpMyAdmin (latest)
PHPMYADMIN_DIR=$(install_phpmyadmin_mac)

# Prepare vhosts and test site
create_user_vhosts_dir
create_test_vhost_structure
write_test_vhost_conf
symlink_test_vhost_into_user_dir
add_hosts_entry_if_missing

# Configure Apache to chosen port, modules, PHP-FPM handler, include vhosts, and phpMyAdmin alias
configure_apache_mac "$PHPMYADMIN_DIR" "$APACHE_PORT"

log "Ensuring PHP common extensions are available (curl, mbstring, intl, gd, xml, zip, bcmath, soap)."
log "On macOS via Homebrew PHP, most common extensions are builtin; PECL-managed ones can be added later if needed."

print_summary
echo "macOS MAMP setup complete."
echo "- Apache config includes: $(APACHE_USER_VHOSTS_DIR)/*.conf"
echo "- Test site: http://test.localhost (added to /etc/hosts)"
echo "- phpMyAdmin: http://localhost/phpmyadmin"
