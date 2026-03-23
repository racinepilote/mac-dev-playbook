# Mac Development Ansible Playbook

This playbook installs and configures the software I use on my Mac for development. Built on top of [geerlingguy/mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook).

**Requirements:** macOS 26+ (Apple Silicon), Homebrew 4.x, Ansible 2.20+, mas 1.8+

## Quick Start

Bootstrap a fresh Mac from scratch:

```bash
curl -fsSL https://raw.githubusercontent.com/racinepilote/mac-dev-playbook/main/install.sh | bash
```

The script handles everything: Xcode CLI Tools, Rosetta 2, Homebrew, pipx, Ansible, cloning the repo, and running the playbook.

## Manual Installation

1. Install Xcode Command Line Tools:

       xcode-select --install

2. Install Homebrew, pipx, and Ansible:

       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
       brew install pipx
       pipx ensurepath
       pipx install ansible-core

3. Clone and run:

       git clone https://github.com/racinepilote/mac-dev-playbook.git
       cd mac-dev-playbook
       ansible-galaxy install -r requirements.yml
       ansible-playbook main.yml --ask-become-pass

## Running Specific Tags

```bash
ansible-playbook main.yml --ask-become-pass --tags "homebrew,dotfiles"
```

Available tags: `homebrew`, `dotfiles`, `mas`, `dock`, `macos`, `dev`, `osx`, `extra-packages`, `sublime-text`, `vim`, `config`, `sudoers`, `terminal`, `post`

## What Gets Installed

### Homebrew Cask Apps

1Password, Chrome, Claude, Docker, Dropbox, Firefox, Geekbench, iTerm2, JetBrains Toolbox, LICEcap, Microsoft Office, Microsoft Remote Desktop, Microsoft Teams, Notion, NordVPN, Postman, Slack, Stats, Sublime Text, TG Pro, Transmission, Transmit, Visual Studio Code, Zoom

### Homebrew Packages

autoconf, bash-completion, cowsay, doxygen, gettext, gh, gifsicle, git, go, gpg, httpie, iperf, libevent, mas, nmap, node, nvm, openssl, php, pv, readline, redis, sqlite, ssh-copy-id, terraform, wget, yarn, zsh-history-substring-search

### Mac App Store (via mas)

Xcode, Paprika, Apple Developer

> **Note:** mas 1.8+ requires you to be signed into the App Store manually before running the playbook. The `signin` command has been removed.

### NPM Global Packages

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`@anthropic-ai/claude-code`)

### Dotfiles

My [dotfiles](https://github.com/racinepilote/dotfiles) are symlinked into the home directory: `.zshrc`, `.gitconfig`, `.gitignore`, `.gitmessage`, `.aliases`, `.inputrc`, `.osx`, `.vimrc`

### ~/.config

The `config` tag deploys configuration files for: GitHub CLI (`gh`), global git ignore, Google Cloud SDK (`gcloud`), GitHub Copilot IntelliJ MCP.

### Dock

The playbook clears default Dock items and sets up a custom layout: Messages, Mail, Calendar, Safari, Sublime Text, iTerm, Chrome, Firefox, Postman, Slack, Microsoft Teams, Xcode, Notion, 1Password, Activity Monitor, Claude

### macOS Settings

The `.osx` dotfile configures macOS preferences. Caps Lock is remapped to Escape via a launch agent.

## Overriding Defaults

Create a `config.yml` to override anything in `default.config.yml`:

```yaml
homebrew_installed_packages:
  - git
  - go
  - node

homebrew_cask_apps:
  - docker
  - firefox

npm_packages:
  - name: "@anthropic-ai/claude-code"
    state: present
    executable: /opt/homebrew/bin/npm

configure_dock: true
configure_config: true
configure_sublime: true
```

The `config.yml` file is gitignored -- it contains your personal overrides and stays local (or in iCloud).

## Manual Steps

Some things still require manual setup after running the playbook:

1. Sign into the Mac App Store (required for mas to install apps)
2. `gcloud auth login` for Google Cloud credentials
3. `gh auth login` for GitHub CLI authentication
4. Commit/push any local dotfiles changes before re-running the playbook

## Based On

[Jeff Geerling's mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook) -- check out [Ansible for DevOps](https://www.ansiblefordevops.com/) for more.
