bash-scripts
------------
* Bash scripts for Debian
* Maintainer: [Jan Elznic](https://janelznic.cz), <jan@elznic.com>


## config-user.sh
* Set up basic user configuration for SSH, Vim, Bash (aliases), Git & NPM
```bash
curl -sL https://raw.githubusercontent.com/janelznic/bash-scripts/master/bin/config-user.sh.sh | bash -
```


## mountall.sh
* Mount remote connection via Samba from file `data/mount_servers.dat` to `/home/<user>/mnt/<user@server>`


## sshfsall.sh
* Mount remote connection via SSHFS from file `data/sshfs_servers.dat` to `/home/<user>/mnt/<user@server>`


MIT License Copyright (c) 2016-2019 Jan Elznic
