#!/usr/bin/env bash

export PATH="$HOME/Library/Python/3.8/bin:/opt/homebrew/bin:$PATH"

xcode-select --install

arch_name="$(uname -m)"

if [ "${arch_name}" = "arm64" ]; then
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

INSTALLER_ROOT="$HOME/.mac-dev"
ANSIBLE_DIR="$INSTALLER_ROOT/mac-dev-playbook"

set -e;
mkdir -p "$INSTALLER_ROOT"
cd "$INSTALLER_ROOT"

# Install requirements
sudo easy_install pip
sudo pip3 install --upgrade pip
sudo pip3 install ansible

# Grab latest playbook and unzip
curl -LO https://github.com/racinepilote/mac-dev-playbook/archive/main.zip
rm -rf "$ANSIBLE_DIR"
unzip main.zip -d "$ANSIBLE_DIR"
rm main.zip
cd "$ANSIBLE_DIR"

# Install deps + run
ansible-galaxy install -r requirements.yml
ansible-playbook main.yml -i inventory -K

echo "Done!"