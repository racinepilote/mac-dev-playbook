#!/usr/bin/env bash
set -euo pipefail

# --- macOS Dev Playbook Bootstrap ---
# Compatible: macOS 26+ / Apple Silicon / Homebrew 4.x / Ansible 2.20+

export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press any key once the installation is complete."
    read -n 1 -s
fi

# Rosetta 2 (Apple Silicon only)
if [ "$(uname -m)" = "arm64" ] && ! /usr/bin/pgrep -q oahd; then
    echo "Installing Rosetta 2..."
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

# Homebrew
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# pipx + Ansible (isolated, no sudo, PEP 668 compliant)
if ! command -v pipx &>/dev/null; then
    echo "Installing pipx..."
    brew install pipx
    pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v ansible &>/dev/null; then
    echo "Installing Ansible via pipx..."
    pipx install ansible-core
fi

# Clone playbook
PLAYBOOK_DIR="$HOME/.mac-dev/mac-dev-playbook"
if [ -d "$PLAYBOOK_DIR/.git" ]; then
    echo "Updating playbook..."
    git -C "$PLAYBOOK_DIR" pull --ff-only
else
    echo "Cloning playbook..."
    mkdir -p "$(dirname "$PLAYBOOK_DIR")"
    git clone https://github.com/racinepilote/mac-dev-playbook.git "$PLAYBOOK_DIR"
fi

cd "$PLAYBOOK_DIR"

# Install Ansible dependencies
ansible-galaxy install -r requirements.yml

# Prompt for sudo password once and keep the credential alive
# This prevents Ansible from freezing when sudo cache expires mid-run
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

# Run playbook
ansible-playbook main.yml --ask-become-pass

echo "Done!"
