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
  --help           Show this help and exit
  --non-interactive   Skip confirmations (use defaults)

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
