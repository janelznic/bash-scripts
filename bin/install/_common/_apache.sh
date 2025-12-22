#!/usr/bin/env bash
set -euo pipefail

# Source utils relative to this helper file (robust across CWD)
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_THIS_DIR/_utils.sh"
# Optional brew helpers on macOS
if command -v brew >/dev/null 2>&1 && [ -f "$_THIS_DIR/_brew.sh" ]; then
  . "$_THIS_DIR/_brew.sh"
fi

APACHE_USER_VHOSTS_DIR() { echo "$(detect_user_home)/virtualhosts/apache2"; }
TEST_VHOST_BASE() { echo "$(detect_user_home)/www/test"; }

create_user_vhosts_dir() {
  ensure_dir "$(APACHE_USER_VHOSTS_DIR)"
}

create_test_vhost_structure() {
  local base; base="$(TEST_VHOST_BASE)"
  ensure_dir "$base/conf"
  ensure_dir "$base/log"
  ensure_dir "$base/wwwroot"
}

write_test_vhost_conf() {
  local base; base="$(TEST_VHOST_BASE)"
  local port="${1:-80}"
  local docroot="$base/wwwroot"
  local logs="$base/log"
  local conf="$base/conf/httpd.conf"
  local server_name="test.localhost"

  cat > "$conf" <<EOF
<VirtualHost *:$port>
    ServerName $server_name
    ServerAlias $server_name
    DocumentRoot "$docroot"

    ErrorLog "$logs/error.log"
    CustomLog "$logs/access.log" combined

    <Directory "$docroot">
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
</VirtualHost>
EOF
  log "Wrote test vhost: $conf"
}

symlink_test_vhost_into_user_dir() {
  local src dst
  src="$(TEST_VHOST_BASE)/conf/httpd.conf"
  dst="$(APACHE_USER_VHOSTS_DIR)/test.conf"
  symlink_force "$src" "$dst"
  record_managed_vhost "test.conf"
}

add_hosts_entry_if_missing() {
  local host="test.localhost"
  if ! grep -qE "\s$host(\s|$)" /etc/hosts; then
    echo "127.0.0.1    $host" | sudo tee -a /etc/hosts >/dev/null
    log "Added /etc/hosts entry for $host"
  fi
}

# Common cleanup helpers
remove_hosts_entry() {
  local host="${1:-test.localhost}"
  if grep -qE "\s$host(\s|$)" /etc/hosts; then
    sudo sed -i.bak "/$(printf '%s' "$host" | sed 's/[][$.*^|+?(){}\\]/\\&/g')/d" /etc/hosts
    log "Removed hosts entry for $host"
  fi
}

has_hosts_entry() {
  local host="$1"
  grep -qE "\s$host(\s|$)" /etc/hosts
  return $?
}

remove_test_vhost_symlink() {
  local link
  link="$(APACHE_USER_VHOSTS_DIR)/test.conf"
  if [ -L "$link" ] || [ -e "$link" ]; then
    rm -f "$link"
    log "Removed vhost symlink: $link"
  fi
}

purge_test_vhost_dir() {
  local base; base="$(TEST_VHOST_BASE)"
  if [ -d "$base" ]; then
    rm -rf "$base"
    log "Purged test site directory: $base"
  fi
}

# Managed vhosts manifest helpers
_managed_manifest_path() {
  echo "$(APACHE_USER_VHOSTS_DIR)/.managed_vhosts"
}

record_managed_vhost() {
  local name="$1"
  ensure_dir "$(APACHE_USER_VHOSTS_DIR)"
  local mf; mf="$(_managed_manifest_path)"
  if ! grep -qxF "$name" "$mf" 2>/dev/null; then
    echo "$name" >> "$mf"
    log "Recorded managed vhost: $name"
  fi
}

remove_all_managed_vhosts() {
  local mf; mf="$(_managed_manifest_path)"
  if [ -f "$mf" ]; then
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      local path="$(APACHE_USER_VHOSTS_DIR)/$name"
      if [ -L "$path" ] || [ -e "$path" ]; then
        rm -f "$path"
        log "Removed managed vhost: $path"
      fi
    done < "$mf"
    rm -f "$mf"
    log "Cleared managed vhosts manifest."
  fi
}

no_managed_vhosts_present() {
  local mf; mf="$(_managed_manifest_path)"
  if [ -f "$mf" ]; then
    # If manifest exists and any listed file remains, return 1
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      local path="$(APACHE_USER_VHOSTS_DIR)/$name"
      if [ -e "$path" ] || [ -L "$path" ]; then
        return 1
      fi
    done < "$mf"
  fi
  return 0
}

# macOS Homebrew httpd paths and configuration
apache_mac_paths() {
  local brew_prefix; brew_prefix=$(brew --prefix)
  echo "$brew_prefix" "$brew_prefix/etc/httpd/httpd.conf" "$brew_prefix/etc/httpd/extra"
}

configure_apache_mac() {
  require_command brew
  local brew_prefix conf extra
  read -r brew_prefix conf extra < <(apache_mac_paths)
  # Normalize brew_prefix via helper if available
  if command -v brew_prefix >/dev/null 2>&1; then
    brew_prefix="$(brew_prefix)"
    conf="$brew_prefix/etc/httpd/httpd.conf"
    extra="$brew_prefix/etc/httpd/extra"
  fi
  local docroot="$brew_prefix/var/www"
  local port="${2:-80}"

  # Ensure required modules are loaded in httpd.conf
  sudo sed -i.bak \
    -e 's|^#\?LoadModule alias_module.*|LoadModule alias_module lib/httpd/modules/mod_alias.so|' \
    -e 's|^#\?LoadModule rewrite_module.*|LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so|' \
    -e 's|^#\?LoadModule proxy_module.*|LoadModule proxy_module lib/httpd/modules/mod_proxy.so|' \
    -e 's|^#\?LoadModule proxy_http_module.*|LoadModule proxy_http_module lib/httpd/modules/mod_proxy_http.so|' \
    -e 's|^#\?LoadModule proxy_fcgi_module.*|LoadModule proxy_fcgi_module lib/httpd/modules/mod_proxy_fcgi.so|' \
    "$conf"

  # Listen on chosen port (remove any default 8080 lines in main conf)
  if grep -q '^Listen ' "$conf"; then
    sudo sed -i.bak -e "s/^Listen .*/Listen $port/" "$conf"
    sudo sed -i '' -e '/^Listen 8080$/d' "$conf" || true
  else
    echo "Listen $port" | sudo tee -a "$conf" >/dev/null
  fi

  # Set global ServerName to suppress FQDN warning
  if grep -qE '^#?ServerName\s' "$conf"; then
    sudo sed -i '' -E 's|^#?ServerName\s.*|ServerName localhost|' "$conf"
  else
    echo "ServerName localhost" | sudo tee -a "$conf" >/dev/null
  fi

  # Include user's virtualhosts directory
  local include_line="IncludeOptional $(APACHE_USER_VHOSTS_DIR)/*.conf"
  if ! grep -qF "$include_line" "$conf"; then
    echo "$include_line" | sudo tee -a "$conf" >/dev/null
    log "Added IncludeOptional for user vhosts into $conf"
  fi

  # Configure global PHP-FPM handler (brew PHP-FPM default socket)
  local php_sock="$brew_prefix/var/run/php-fpm.sock"
  local php_snippet="\n<IfModule proxy_fcgi_module>\n  <FilesMatch \.php$>\n    SetHandler \"proxy:unix:$php_sock|fcgi://localhost\"\n  </FilesMatch>\n</IfModule>\n"
  if ! grep -q "php-fpm.sock" "$conf"; then
    printf "%b" "$php_snippet" | sudo tee -a "$conf" >/dev/null
    log "Configured PHP-FPM handler in $conf"
  fi

  # Configure phpMyAdmin alias (path provided by caller)
  local pma_path="${1:-}"
  if [ -n "$pma_path" ]; then
    local pma_snippet="\nAlias /phpmyadmin $pma_path\n<Directory $pma_path>\n  Options FollowSymLinks\n  AllowOverride All\n  Require all granted\n</Directory>\n"
    if ! grep -q "Alias /phpmyadmin" "$conf"; then
      printf "%b" "$pma_snippet" | sudo tee -a "$conf" >/dev/null
      log "Added phpMyAdmin alias into $conf"
    fi
  fi

  # Ensure DocumentRoot directory block permits access
  if ! grep -q "<Directory $docroot>" "$conf"; then
    cat <<EOF | sudo tee -a "$conf" >/dev/null
<Directory $docroot>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
EOF
  fi

  # Create a default index.html to avoid 403 when no index exists
  if [ ! -f "$docroot/index.html" ]; then
    echo "<html><body><h1>Apache is running</h1></body></html>" | sudo tee "$docroot/index.html" >/dev/null
  fi

  # Restart httpd via brew services (root domain for port 80)
  sudo brew services stop httpd || true
  sudo brew services start httpd
}

# Debian Apache configuration using a2enmod and conf-available
configure_apache_debian() {
  require_command a2enmod
  sudo a2enmod alias rewrite proxy proxy_http proxy_fcgi

  # User vhosts include via a2enconf
  local conf_file="/etc/apache2/conf-available/user-vhosts.conf"
  echo "# Include user virtualhosts\nIncludeOptional $(APACHE_USER_VHOSTS_DIR)/*.conf" | sudo tee "$conf_file" >/dev/null
  sudo a2enconf user-vhosts

  # Ensure Apache listens on chosen port (default 80)
  local port="${2:-80}"
  sudo sed -i "s/^Listen .*/Listen $port/" /etc/apache2/ports.conf || true

  # Configure global PHP-FPM handler (Debian default socket)
  local php_sock="/run/php/php-fpm.sock"
  local p="/etc/apache2/conf-available/php-fpm-handler.conf"
  cat | sudo tee "$p" >/dev/null <<EOF
<IfModule proxy_fcgi_module>
  <FilesMatch \.php$>
    SetHandler "proxy:unix:$php_sock|fcgi://localhost/"
  </FilesMatch>
</IfModule>
EOF
  sudo a2enconf php-fpm-handler

  # phpMyAdmin alias when installed manually at /usr/share/phpmyadmin or as package
  local pma_dir="${1:-/usr/share/phpmyadmin}"
  local pma_conf="/etc/apache2/conf-available/phpmyadmin.conf"
  if [ -d "$pma_dir" ]; then
    cat | sudo tee "$pma_conf" >/dev/null <<EOF
Alias /phpmyadmin $pma_dir
<Directory $pma_dir>
  Options FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>
EOF
    sudo a2enconf phpmyadmin
  fi

  sudo systemctl restart apache2
}
