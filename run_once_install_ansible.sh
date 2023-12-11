#!/bin/bash

install_on_ubuntu() {
    sudo apt update && sudo apt install pipx -y
    pipx install --include-deps ansible
    pipx ensurepath
}

ansible-playbook ~/.bootstrap/setup.yml --ask-become-pass

echo "Ansible installation complete."
