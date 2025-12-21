bash-scripts
------------
* Bash scripts for Debian
* Maintainer: [Jan Elznic](https://janelznic.cz), <jan@elznic.com>


## config-user.sh
* Set up basic user configuration for SSH, Vim, Bash (aliases), Git & NPM
```bash
curl -sL https://raw.githubusercontent.com/janelznic/bash-scripts/master/bin/config-user.sh | bash -
```


## mountall.sh
* Mount remote connection via Samba from file `data/mount_servers.dat` to `/home/<user>/mnt/<user@server>`


## sshfsall.sh
* Mount remote connection via SSHFS from file `data/sshfs_servers.dat` to `/home/<user>/mnt/<user@server>`


MIT License Copyright (c) 2016-2019 Jan Elznic

## Web Stack Installers (MAMP/LAMP)

Scripts to install and uninstall Apache, PHP, MySQL, and phpMyAdmin with a ready-to-use test VirtualHost.

- macOS (Apple Silicon M1 Max): [bin/install/install-mamp.sh](bin/install/install-mamp.sh)
- Debian 13 Trixie: [bin/install/install-lamp.sh](bin/install/install-lamp.sh)
- macOS Uninstall: [bin/install/uninstall-mamp.sh](bin/install/uninstall-mamp.sh)
- Debian Uninstall: [bin/install/uninstall-lamp.sh](bin/install/uninstall-lamp.sh)

### Features
- Apache listens on `localhost:80`.
- Enables modules: proxy, proxy_http, proxy_fcgi, rewrite, alias.
- Includes VirtualHosts from `~/virtualhosts/apache2/*.conf`.
- MySQL root password set to `aaa`.
 - MySQL root password prompted at start (or via `--mysql-root-password` option; defaults to `aaa`).
- phpMyAdmin served at `http://localhost/phpmyadmin`.
- Test VirtualHost created under `~/www/test` with:
	- Config: `~/www/test/conf/httpd.conf` → symlinked to `~/virtualhosts/apache2/test.conf`
	- Logs: `~/www/test/log`
	- DocumentRoot: `~/www/test/wwwroot`

### Usage
macOS (requires Homebrew and sudo):
```bash
cd ~/git/bash-scripts/bin/install
sudo ./install-mamp.sh            # install and configure (prompts for MySQL root password)
sudo ./install-mamp.sh --mysql-root-password mysecret  # provide password via flag
sudo ./uninstall-mamp.sh          # stop services, remove created resources
sudo ./uninstall-mamp.sh --purge  # additionally uninstall Homebrew httpd/php/mysql
```

Debian 13 (requires sudo):
```bash
cd ~/git/bash-scripts/bin/install
sudo ./install-lamp.sh            # install and configure (prompts for MySQL root password)
sudo ./install-lamp.sh --mysql-root-password mysecret  # provide password via flag
sudo ./uninstall-lamp.sh          # stop services, remove created resources
sudo ./uninstall-lamp.sh --purge  # additionally purge apt packages
```

### Help
Each installer/uninstaller supports `--help` and `--non-interactive`:
```bash
./install-mamp.sh --help
./install-lamp.sh --help
./uninstall-mamp.sh --help
./uninstall-lamp.sh --help
```

### Notes
- The scripts may prompt for confirmation unless `--non-interactive` is used.
- macOS Apache runs via Homebrew services and is reconfigured to port 80; this may require sudo and can change ownership of some Homebrew paths.
- Common PHP extensions are installed on Debian; on macOS most common extensions are built-in with Homebrew PHP. Additional PECL extensions can be added separately if needed.
