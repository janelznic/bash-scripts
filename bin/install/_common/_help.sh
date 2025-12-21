#!/usr/bin/env bash
set -euo pipefail

print_help() {
cat <<'EOF'
Name: MAMP/LAMP Installer Scripts

Description:
  One-command installers to provision the latest Apache (httpd), PHP, MySQL, and phpMyAdmin
  with required modules and a ready-to-use test VirtualHost.

Author:
  Jan Elznic <jan@elznic.com>, https://janelznic.cz

Usage:
  macOS (Apple Silicon M1 Max):
    sudo install/install-mamp.sh [options]

  Debian 13 Trixie:
    sudo install/install-lamp.sh [options]

Options:
  --help                 Show this help and exit
  --non-interactive      Skip confirmations (use defaults)
  --mysql-root-password  Set MySQL root password (otherwise prompted; default 'aaa')

Defaults:
  - Apache listens on localhost:80
  - VirtualHosts are included from ~/virtualhosts/apache2/*
  - MySQL root password: "aaa" (exactly, as requested)
  - phpMyAdmin at http://localhost/phpmyadmin
  - Apache modules enabled: proxy, proxy_http, proxy_fcgi, rewrite, alias
  - PHP-FPM is used with common PHP extensions (curl, mbstring, intl, gd, xml, zip, bcmath, soap)
  - Test vhost created under ~/www/test with logs and wwwroot

Notes:
  - These scripts will prompt for any missing parameters at the start (unless --non-interactive is provided).
  - They modify system/service configuration and may require sudo/root privileges.
EOF
}

print_help_uninstall_mamp() {
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

print_help_uninstall_lamp() {
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

