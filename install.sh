#!/usr/bin/env bash
set -euo pipefail

# --- macOS Dev Playbook Bootstrap ---
# Compatible: macOS 14+ (Sonoma) / Intel & Apple Silicon / Homebrew 4.x / Ansible 2.20+
#
# Usage:
#   ./install.sh          # Mode desktop (main.yml)
#   ./install.sh server   # Mode serveur Mac mini (server.yml + radiko.yml)

MODE="${1:-desktop}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

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

# Homebrew (Intel = /usr/local, Apple Silicon = /opt/homebrew)
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
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
if [ "$MODE" = "server" ]; then
    echo "=== Mode SERVEUR (Mac mini) ==="
    ansible-playbook server.yml --ask-become-pass
    echo ""
    echo "=== Radiko / Plane setup ==="
    echo "Assurez-vous que Docker Desktop est lance avant de continuer."
    read -p "Docker est pret? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ansible-playbook radiko.yml --ask-become-pass
    else
        echo "Lancez plus tard: ansible-playbook radiko.yml --ask-become-pass"
    fi
else
    echo "=== Mode DESKTOP ==="
    ansible-playbook main.yml --ask-become-pass
fi

echo "Done!"
