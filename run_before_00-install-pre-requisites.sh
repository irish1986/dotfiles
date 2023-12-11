#!/bin/bash

set -eu

sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
echo "System updated."

sudo apt update && sudo apt install apt-transport-https curl git gpg gnupg openssh-server htop p7zip-full software-properties-common tmux tree virtualbox vlc wget
echo "Default package installed."
