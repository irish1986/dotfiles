#!/bin/bash

set -eu

sudo apt update && sudo apt install pipx -y
pipx install --include-deps ansible
pipx ensurepath
echo "Ansible package installed."

ansible-playbook ~/.bootstrap/setup.yml --ask-become-pass
echo "Ansible installation complete."
