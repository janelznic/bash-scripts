#!/bin/bash

# Reading input variables
FULLNAME=$(getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1)
read -p "Your e-mail for Git: " GIT_EMAIL

# SSH
mkdir ~/.ssh
touch ~/.ssh/authorized_keys
echo "You can edit your public keys on: ~/.ssh/authorized_keys"

# Vim
if [ ! -f ~/.vimrc ]; then
    echo "syntax on" >> ~/.vimrc
    echo "set mouse-=a" >> ~/.vimrc
fi

# Bash aliases
echo "alias ll='ls -la'" >> ~/.bashrc
echo "alias e='exit'" >> ~/.bashrc

# Git
git config --global user.name "${FULLNAME}"
git config --global user.email "${GIT_EMAIL}"
git config --global color.ui auto

git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'

# NodeJS
if [ ! -d ~/.npm-global ]; then
    mkdir ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo "export PATH=~/.npm-global/bin:\$PATH" >> ~/.profile
    source ~/.profile
fi

# Status
echo "Done."
