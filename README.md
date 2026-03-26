# Mac Development Ansible Playbook

This playbook installs and configures the software I use on my Mac for development. Built on top of [geerlingguy/mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook).

Two modes are available:
- **Desktop** (`main.yml`) — Full dev workstation setup (laptop)
- **Server** (`server.yml`) — Minimal Mac mini server for Radiko (Plane, Cloudflare Tunnel, Docker)

## Quick Start

### Desktop (laptop)

```bash
curl -fsSL https://raw.githubusercontent.com/racinepilote/mac-dev-playbook/main/install.sh | bash
```

### Server (Mac mini)

```bash
curl -fsSL https://raw.githubusercontent.com/racinepilote/mac-dev-playbook/main/install.sh | bash -s server
```

The script handles everything: Xcode CLI Tools, Rosetta 2, Homebrew, pipx, Ansible, cloning the repo, and running the playbook.

---

## Server Setup (Mac mini Radiko)

**Target:** Mac mini 2018 (Intel i5 6-core, 32GB RAM, macOS Sonoma)

### What it installs

| Component | Details |
|-----------|---------|
| **Homebrew packages** | git, gh, gpg, httpie, node, ssh-copy-id, tmux, wget, openssl, readline, zsh-history-substring-search |
| **Homebrew casks** | Docker Desktop, Claude |
| **Cloudflare Tunnel** | Expose Plane on `tasks.radiko.ca` |
| **Plane** | Self-hosted project management via Docker Compose (port 4680) |
| **Plane MCP** | Claude Code integration via plane-mcp-server |
| **Power management** | No sleep, no hibernation, wake on network, auto-restart on power failure |
| **SSH** | Remote Login enabled |
| **Sudoers** | NOPASSWD for admin group |

### Step-by-step (fresh Mac mini)

#### 1. Pre-requis manuels (une seule fois)

Ces etapes ne peuvent pas etre automatisees par Apple:

```bash
# Activer SSH (System Settings > General > Sharing > Remote Login > ON)
# Ou si Full Disk Access est donne a Terminal:
sudo systemsetup -setremotelogin on

# Activer Docker Desktop au login
# Docker Desktop > Settings > General > Start Docker Desktop when you sign in
```

#### 2. Bootstrap

```bash
# Sur le Mac mini directement (ou via SSH apres etape 1)
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install pipx
pipx ensurepath
pipx install ansible-core
export PATH="$HOME/.local/bin:$PATH"
```

#### 3. Clone et install

```bash
cd ~
git clone https://github.com/racinepilote/mac-dev-playbook.git
cd mac-dev-playbook
ansible-galaxy install -r requirements.yml
```

#### 4. Configurer le fichier .env

```bash
echo "PLANE_API_KEY=votre_cle_api_plane" > .env
```

> Si c'est une nouvelle installation de Plane, mettre `PLANE_API_KEY=placeholder` puis mettre a jour apres le premier login dans Plane.

#### 5. Lancer le playbook serveur

```bash
ansible-playbook server.yml --ask-become-pass
```

#### 6. Configurer Cloudflare Tunnel (une seule fois)

```bash
# Login interactif (ouvre un navigateur)
cloudflared tunnel login

# Le playbook fait le reste
ansible-playbook server.yml --ask-become-pass --tags cloudflared
```

#### 7. Configurer Plane .env pour le domaine public

Apres que le tunnel fonctionne:

```bash
cd ~/radiko/plane/deployments/cli/community
sed -i '' 's|WEB_URL=.*|WEB_URL=https://tasks.radiko.ca|' .env
sed -i '' 's|CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=https://tasks.radiko.ca,http://localhost:4680|' .env
docker compose restart
```

### Tags disponibles (serveur)

```bash
ansible-playbook server.yml --ask-become-pass --tags "TAG"
```

| Tag | Description |
|-----|-------------|
| `homebrew` | Packages et cask apps |
| `dotfiles` | Symlink dotfiles |
| `sudoers` | NOPASSWD config |
| `power` | Desactiver sleep/hibernation |
| `ssh` | Activer Remote Login |
| `cloudflared` | Cloudflare Tunnel |
| `plane` | Installer/demarrer Plane |
| `plane-mcp` | Configurer MCP pour Claude Code |

### Migration Plane (d'une machine a l'autre)

```bash
# === Sur la machine SOURCE ===
cd ~/radiko/plane/deployments/cli/community

# Dump la DB
docker compose exec -e PGPASSWORD=plane plane-db pg_dump -U plane plane > ~/plane-backup.sql

# Backup MinIO (uploads)
docker compose cp plane-minio:/data ~/plane-minio-backup

# === Copier sur la machine CIBLE ===
scp ~/plane-backup.sql user@cible:~/
scp -r ~/plane-minio-backup user@cible:~/

# === Sur la machine CIBLE ===
cd ~/radiko/plane/deployments/cli/community
docker compose up -d
sleep 15

# Drop et restaure la DB
docker compose exec -e PGPASSWORD=plane -T plane-db psql -U plane -d postgres -c "DROP DATABASE plane;"
docker compose exec -e PGPASSWORD=plane -T plane-db psql -U plane -d postgres -c "CREATE DATABASE plane OWNER plane;"
docker compose exec -e PGPASSWORD=plane -T plane-db psql -U plane plane < ~/plane-backup.sql

# Restaure MinIO
docker compose cp ~/plane-minio-backup/. plane-minio:/data

# Redemarrer
docker compose restart
```

### Connexion SSH depuis le laptop

```bash
# Generer une cle (si pas deja fait)
ssh-keygen -t ed25519 -C "votre@email.com"

# Copier la cle sur le Mac mini (demande le mot de passe une derniere fois)
ssh-copy-id user@radikos-mini.localdomain

# Connecter
ssh user@radikos-mini.localdomain
```

### Architecture serveur

```
Internet
    |
    v
Cloudflare (tasks.radiko.ca)
    |
    v
cloudflared tunnel (launchd service)
    |
    v
Docker Compose (port 4680)
    |
    +-- proxy (Caddy) :80/:443
    +-- web (frontend)
    +-- api (backend)
    +-- worker / beat-worker
    +-- space / admin / live
    +-- plane-db (PostgreSQL)
    +-- plane-redis (Valkey)
    +-- plane-mq (RabbitMQ)
    +-- plane-minio (S3 storage)
```

### Apres un reboot du Mac mini

Tout redemarre automatiquement:
1. macOS boot
2. Docker Desktop demarre (auto-login)
3. Tous les containers Plane redemarrent (`restart: always`)
4. cloudflared demarre via launchd
5. `tasks.radiko.ca` est live

---

## Desktop Setup (laptop)

### Manual Installation

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

### Running Specific Tags

```bash
ansible-playbook main.yml --ask-become-pass --tags "homebrew,dotfiles"
```

Available tags: `homebrew`, `dotfiles`, `mas`, `dock`, `macos`, `dev`, `osx`, `extra-packages`, `sublime-text`, `vim`, `config`, `sudoers`, `terminal`, `post`

### What Gets Installed

#### Homebrew Cask Apps

1Password, Chrome, Claude, Docker, Dropbox, Firefox, Geekbench, iTerm2, JetBrains Toolbox, LICEcap, Microsoft Office, Microsoft Remote Desktop, Microsoft Teams, Notion, NordVPN, Postman, Slack, Stats, Sublime Text, TG Pro, Transmission, Transmit, Visual Studio Code, Zoom

#### Homebrew Packages

autoconf, bash-completion, cowsay, doxygen, gettext, gh, gifsicle, git, go, gpg, httpie, iperf, libevent, mas, nmap, node, nvm, openssl, php, pv, readline, redis, sqlite, ssh-copy-id, terraform, wget, yarn, zsh-history-substring-search

#### Mac App Store (via mas)

Xcode, Paprika, Apple Developer

> **Note:** mas 1.8+ requires you to be signed into the App Store manually before running the playbook.

#### Dotfiles

My [dotfiles](https://github.com/racinepilote/dotfiles) are symlinked into the home directory: `.zshrc`, `.gitconfig`, `.gitignore`, `.gitmessage`, `.aliases`, `.inputrc`, `.osx`, `.vimrc`

#### Dock

The playbook clears default Dock items and sets up a custom layout: Messages, Mail, Calendar, Safari, Sublime Text, iTerm, Chrome, Firefox, Postman, Slack, Microsoft Teams, Xcode, Notion, 1Password, Activity Monitor, Claude

### Overriding Defaults

Create a `config.yml` to override anything in `default.config.yml`:

```yaml
homebrew_installed_packages:
  - git
  - go
  - node

homebrew_cask_apps:
  - docker
  - firefox

configure_dock: true
configure_sublime: true
```

The `config.yml` file is gitignored -- it contains your personal overrides and stays local.

### Manual Steps (desktop)

1. Sign into the Mac App Store (required for mas to install apps)
2. `gcloud auth login` for Google Cloud credentials
3. `gh auth login` for GitHub CLI authentication
4. Commit/push any local dotfiles changes before re-running the playbook

### Connecting to the Mac mini server (MCP)

Pour que Claude Code sur le laptop parle a Plane sur le Mac mini, le fichier `~/radiko/.mcp.json` doit pointer vers le serveur:

```json
{
  "mcpServers": {
    "plane": {
      "type": "stdio",
      "command": "uvx",
      "args": ["plane-mcp-server", "stdio"],
      "env": {
        "PLANE_API_KEY": "votre_cle_api",
        "PLANE_BASE_URL": "http://radikos-mini.localdomain:4680",
        "PLANE_WORKSPACE_SLUG": "radiko"
      }
    }
  }
}
```

---

## File Structure

```
mac-dev-playbook/
  main.yml              # Playbook desktop (laptop)
  server.yml            # Playbook serveur (Mac mini)
  radiko.yml            # Playbook Radiko standalone
  default.config.yml    # Config par defaut
  server.config.yml     # Config serveur (versionne)
  config.yml            # Config desktop (gitignore, local)
  .env                  # PLANE_API_KEY (gitignore)
  install.sh            # Script bootstrap
  inventory             # 127.0.0.1 localhost
  requirements.yml      # Ansible Galaxy deps
  tasks/
    radiko/
      plane.yml         # Setup Plane Docker
      plane-mcp.yml     # Setup MCP Claude Code
      cloudflared.yml   # Cloudflare Tunnel
      ssh.yml           # Remote Login SSH
      power.yml         # Disable sleep
      clone.yml         # Clone repo Radiko
    config.yml          # Deploy ~/.config files
    dockitems.yml       # Dock layout
    extra-packages.yml  # npm, pip, gem, composer
    iterm.yml           # iTerm2 profiles
    iterm-beautify.yml  # Oh My Zsh, themes
    osx.yml             # macOS settings
    sublime-text.yml    # Sublime Text config
    sudoers.yml         # NOPASSWD config
    terminal.yml        # Terminal.app theme
    vim.yml             # Vundle + plugins
```

## Based On

[Jeff Geerling's mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook) -- check out [Ansible for DevOps](https://www.ansiblefordevops.com/) for more.
