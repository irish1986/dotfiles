#!/bin/bash

install_on_ubuntu() {
    sudo apt-get update
    sudo apt-get install -y ansible
}

OS="$(uname -s)"
case "${OS}" in
    Linux*)
        if [ -f /etc/lsb-release ]; then
            install_on_ubuntu
        else
            echo "Unsupported Linux distribution"
            exit 1
        fi
        ;;
esac

ansible-playbook ~/.bootstrap/setup.yml --ask-become-pass

echo "Ansible installation complete."

