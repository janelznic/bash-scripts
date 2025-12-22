#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"
. "$SCRIPT_DIR/_common/_help.sh"
. "$SCRIPT_DIR/_common/_brew.sh"
. "$SCRIPT_DIR/_common/_checks.sh"

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

# Ensure Homebrew commands run as the owning user even if script is run with sudo
brew_as_user() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew "$@"
  else
    brew "$@"
  fi
}
brew_services_as_user() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew services "$@"
  else
    brew services "$@"
  fi
}

# Get brew prefix under the same user context
brew_prefix() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" brew --prefix
  else
    brew --prefix
  fi
}

if [ "$CHECK_ONLY" = "true" ]; then
  log "Check-only mode: verifying uninstall state without making changes."
  check_macos_mamp_state "uninstalled"
  exit 0
fi

# Stop services (run as Homebrew user)
brew_services_as_user stop httpd || true
brew_services_as_user stop php || true
brew_services_as_user stop mysql || true

# Paths
BREW_PREFIX=$(brew_prefix)
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

# Always uninstall packages (even without --purge). Force and ignore deps when necessary.
brew_as_user uninstall --force httpd || true
brew_as_user uninstall --ignore-dependencies --force php || true
brew_as_user uninstall --force mysql || true

# Fallback: remove lingering Cellar directories if brew couldn't
CELLAR_DIR="$BREW_PREFIX/Cellar"
[ -d "$CELLAR_DIR/httpd" ] && sudo rm -rf "$CELLAR_DIR/httpd"
[ -d "$CELLAR_DIR/php" ] && sudo rm -rf "$CELLAR_DIR/php"
[ -d "$CELLAR_DIR/mysql" ] && sudo rm -rf "$CELLAR_DIR/mysql"

# Remove remaining opt symlinks and bin/sbin shims for these formulae
for f in httpd php mysql; do
  [ -e "$BREW_PREFIX/opt/$f" ] && sudo rm -rf "$BREW_PREFIX/opt/$f"
  [ -e "$BREW_PREFIX/bin/$f" ] && sudo rm -f "$BREW_PREFIX/bin/$f"
  [ -e "$BREW_PREFIX/sbin/$f" ] && sudo rm -f "$BREW_PREFIX/sbin/$f"
done

# Cleanup unneeded dependencies and symlinks
brew_as_user autoremove || true
brew_as_user cleanup -s || true
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

# Post-uninstall verification
if [ "$CHECK_ONLY" != "true" ]; then
  log "Running post-uninstall verification (--check)."
  "$SCRIPT_DIR/uninstall-mamp.sh" --check
fi
