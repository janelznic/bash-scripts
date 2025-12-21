#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common/_utils.sh"
. "$SCRIPT_DIR/_common/_apache.sh"

show_help() {
cat <<'EOF'
Name: MAMP Uninstaller (macOS)

Description:
  Stops services and removes resources created by the MAMP installer.

Author:
  Jan Elznic <jan@elznic.com>, https://janelznic.cz

Usage:
  sudo bin/install/uninstall-mamp.sh [--purge] [--non-interactive]

Options:
  --help             Show this help
  --purge            Remove all created resources and uninstall packages (httpd, php, mysql)
  --non-interactive  Skip confirmations

Removes:
  - Brew services: httpd, php, mysql (stopped always; uninstalled with --purge)
  - Test vhost symlink and site at ~/www/test (entire directory on --purge)
  - Hosts entry for test.localhost
  - phpMyAdmin files under $(brew --prefix)/var/www/phpmyadmin (on --purge)
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

log "Starting MAMP uninstall on macOS."

require_command brew

# Stop services
brew services stop httpd || true
brew services stop php || true
brew services stop mysql || true

# Paths
BREW_PREFIX=$(brew --prefix)
APACHE_CONF="$BREW_PREFIX/etc/httpd/httpd.conf"
PMA_DIR="$BREW_PREFIX/var/www/phpmyadmin"

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

# Remove phpMyAdmin directory on purge
if [ "$PURGE" = "true" ]; then
  if [ -d "$PMA_DIR" ]; then
    rm -rf "$PMA_DIR"
    log "Purged phpMyAdmin directory: $PMA_DIR"
  fi
fi

# Optionally clean Apache httpd.conf entries we added (best-effort)
if [ -f "$APACHE_CONF" ]; then
  # Remove IncludeOptional user vhosts line
  sudo sed -i.bak "/IncludeOptional $(APACHE_USER_VHOSTS_DIR | sed 's|/|\\/|g')\/\*.conf/d" "$APACHE_CONF" || true
  # Remove phpMyAdmin Alias block
  sudo awk 'BEGIN{skip=0} /Alias \/phpmyadmin/{skip=1} skip && /<Directory/{next} skip && /<\/Directory>/{skip=0; next} !skip {print}' "$APACHE_CONF" | sudo tee "$APACHE_CONF.tmp" >/dev/null || true
  if [ -s "$APACHE_CONF.tmp" ]; then sudo mv "$APACHE_CONF.tmp" "$APACHE_CONF"; fi
fi

# Uninstall packages on purge
if [ "$PURGE" = "true" ]; then
  if [ "$NON_INTERACTIVE" = "true" ] || confirm "Uninstall Homebrew httpd, php, and mysql?"; then
    brew uninstall httpd || true
    brew uninstall php || true
    brew uninstall mysql || true
    log "Homebrew packages uninstalled (httpd, php, mysql)."
  fi
fi

print_summary
echo "macOS MAMP uninstall complete."
echo "- Services stopped: httpd, php, mysql"
echo "- Purge: $PURGE"
