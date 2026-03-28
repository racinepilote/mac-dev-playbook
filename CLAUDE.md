# CLAUDE.md — Instructions pour Claude Code

## Projet

Playbook Ansible pour configurer des machines macOS. Deux modes :

- **Desktop** (`main.yml`) — poste de développement complet (Homebrew, dotfiles, iTerm, Sublime, Dock, MAS apps)
- **Serveur** (`server.yml` + `radiko.yml`) — Mac mini serveur Radiko (Plane, Cloudflare Tunnel, Docker)

Inventaire : localhost uniquement (`ansible_connection=local`). Toutes les tâches s'exécutent localement.

## Structure du répertoire

```
mac-dev-playbook/
├── main.yml                # Playbook desktop
├── server.yml              # Playbook serveur (Mac mini)
├── radiko.yml              # Setup Radiko/Plane (nécessite Docker)
├── install.sh              # Script bootstrap (première installation)
├── ansible.cfg             # Config Ansible (become=true global)
├── inventory               # Localhost uniquement
├── requirements.yml        # Dépendances Galaxy
├── default.config.yml      # Variables par défaut (commité)
├── config.yml              # Overrides desktop (gitignored)
├── server.config.yml       # Variables serveur (commité)
├── .env                    # Secrets : PLANE_API_KEY (gitignored)
├── tasks/
│   ├── sudoers.yml         # Configuration NOPASSWD
│   ├── terminal.yml        # Thème Terminal.app
│   ├── dockitems.yml       # Layout du Dock
│   ├── iterm.yml           # Fonts et profils iTerm2
│   ├── iterm-beautify.yml  # Oh My Zsh, Pure prompt, thème Snazzy
│   ├── osx.yml             # Réglages macOS + remap Caps Lock
│   ├── extra-packages.yml  # npm, pip, gem, composer (global)
│   ├── sublime-text.yml    # Config Sublime Text
│   ├── vim.yml             # Vundle + plugins Vim
│   ├── config.yml          # Deploy ~/.config (gh, git, gcloud, IDE)
│   └── radiko/
│       ├── power.yml       # Empêcher le sleep (pmset)
│       ├── ssh.yml         # Activer Remote Login + hardening
│       ├── cloudflared.yml # Tunnel Cloudflare → tasks.radiko.ca
│       ├── clone.yml       # Clone du repo Radiko
│       ├── plane.yml       # Déploiement Plane (Docker Compose)
│       └── plane-mcp.yml   # Serveur MCP Plane pour Claude Code
├── files/                  # Fichiers statiques (config, iterm, sublime, zsh)
├── templates/              # Templates Jinja2
├── roles/                  # Rôles Galaxy (osx-command-line-tools, dotfiles)
└── tests/                  # Fichiers de test
```

## Système de configuration

Trois couches de variables avec précédence :

1. `default.config.yml` — valeurs par défaut pour tous les modes (commité)
2. `config.yml` — overrides desktop, spécifique à chaque machine (gitignored)
3. `server.config.yml` — variables serveur (commité, chargé explicitement par `server.yml`)

**Desktop :** `default.config.yml` → surchargé par `config.yml`
**Serveur :** `default.config.yml` → surchargé par `server.config.yml`

Toggles booléens : `configure_dotfiles`, `configure_terminal`, `configure_osx`, `configure_dock`, `configure_sudoers`, `configure_sublime`, `configure_config`, `configure_iterm_beautify`.

## Commandes essentielles

### Bootstrap (première installation)

```bash
./install.sh          # Mode desktop
./install.sh server   # Mode serveur
```

Le script installe Xcode CLI Tools, Rosetta 2, Homebrew, pipx, Ansible, puis exécute le playbook.

### Mode desktop

```bash
ansible-playbook main.yml --ask-become-pass
ansible-playbook main.yml --ask-become-pass --tags "homebrew,dotfiles"
```

### Mode serveur

```bash
# Premier run (NOPASSWD pas encore configuré) :
sudo -v && ansible-playbook server.yml --ask-become-pass

# Après le premier run (NOPASSWD actif), le flag n'est plus nécessaire :
ansible-playbook server.yml
ansible-playbook server.yml --tags "homebrew"

# Radiko/Plane (Docker Desktop doit tourner) :
ansible-playbook radiko.yml
```

### Dépendances Galaxy

```bash
ansible-galaxy install -r requirements.yml
```

### Linting

```bash
ansible-lint           # Utilise .ansible-lint
yamllint .             # Utilise .yamllint
```

## Stratégie sudo / become

`ansible.cfg` définit `become = true` globalement — toutes les tâches utilisent sudo.

### Le problème `--ask-become-pass`

Sur une machine fraîche, sudo demande un mot de passe → `--ask-become-pass` est obligatoire.

### Solution : NOPASSWD après le premier run

`server.config.yml` a `configure_sudoers: true`. La tâche `tasks/sudoers.yml` écrit `%admin ALL=(ALL) NOPASSWD: ALL` dans `/private/etc/sudoers.d/custom`. Une fois exécutée, sudo ne demande plus de mot de passe.

**Workflow recommandé (serveur) :**

1. Premier run : `sudo -v && ansible-playbook server.yml --ask-become-pass`
2. Tous les runs suivants : `ansible-playbook server.yml` (sans flag)

### Alternatives

**Exécuter sudoers isolément d'abord :**

```bash
sudo -v && ansible-playbook server.yml --ask-become-pass --tags sudoers
# Ensuite :
ansible-playbook server.yml
```

**Configuration manuelle (une seule fois) :**

```bash
sudo visudo -f /private/etc/sudoers.d/custom
# Ajouter : %admin ALL=(ALL) NOPASSWD: ALL
```

### Mode desktop

`config.yml` a `configure_sudoers: false` → `--ask-become-pass` est toujours requis. Pour l'éliminer, mettre `configure_sudoers: true` dans `config.yml` ou faire la config manuelle ci-dessus.

## Tags disponibles

### Desktop (`main.yml`)

`homebrew`, `dotfiles`, `mas`, `dock`, `sudoers`, `terminal`, `macos`, `dev`, `iterm-beautify`, `osx`, `extra-packages`, `sublime-text`, `vim`, `config`, `post`

### Serveur (`server.yml`)

`setup`, `homebrew`, `dotfiles`, `sudoers`, `power`, `ssh`, `cloudflared`, `plane`, `plane-mcp`

### Radiko (`radiko.yml`)

`clone`, `plane`, `plane-start`, `plane-mcp`, `plane-mcp-install`, `plane-mcp-test`, `plane-mcp-config`

Usage : `ansible-playbook <playbook> --tags "tag1,tag2"`

## Conventions

- **Langue :** noms de tâches et commentaires en **français**
- **YAML :** indentation 2 espaces, max 180 caractères par ligne (`.yamllint`)
- **Nommage fichiers :** minuscules, tirets pour les mots composés (`plane-mcp.yml`)
- **Variables :** snake_case, préfixées par domaine (`plane_port`, `cloudflared_hostname`)
- **Tags :** minuscules, tirets, appliqués à chaque tâche

## Ne JAMAIS faire

- **Ne jamais commit** `.env`, `.env.radiko`, ou `config.yml` — ils sont gitignored
- **Ne jamais retirer** `become = true` de `ansible.cfg` — toutes les tâches attendent les privilèges root
- **Ne jamais modifier** `default.config.yml` pour des overrides machine-spécifiques — utiliser `config.yml` (desktop) ou `server.config.yml` (serveur)
- **Ne jamais lancer** `radiko.yml` sans Docker Desktop actif
- **Ne jamais hardcoder** de secrets dans les fichiers commités — utiliser `.env` et `lookup('file', ...)`

## Dépendances externes (Galaxy)

- Collection `geerlingguy.mac` (rôles homebrew, mas, dock)
- Rôle `elliotweiser.osx-command-line-tools`
- Rôle `geerlingguy.dotfiles`
