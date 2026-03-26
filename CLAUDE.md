# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles and configuration repository for macOS/Linux development environments. It contains configuration files for various development tools, shell scripts for automation, and infrastructure/monitoring setups.

**Language**: Primarily shell scripts (bash), configuration files, and documentation in Chinese.

**Key Characteristics**:
- Git submodules: `vimfiles`, `power-shell-config`
- No build system (no Makefile, package.json, etc.)
- No automated tests - this is a configuration/dotfiles repo
- Repository is public - never commit sensitive information

## Directory Structure

```
.
├── scripts/           # Utility shell scripts for system operations
│   ├── kubernetes/    # K8s-related scripts
│   ├── mysql/         # MySQL backup/maintenance scripts
│   └── setup_myfiles.sh  # Personal directory structure setup
├── ops/monitoring/macos-server/  # Prometheus/Grafana/Alertmanager stack
├── openclaw/          # OpenClaw gateway configuration schema tools
├── k8s/              # Kubernetes certificates and configs
├── docker/           # Docker compose files and container scripts
├── vimfiles/         # Vim configuration (git submodule)
├── nvim/             # Neovim configuration scripts
├── git/              # Git configuration
├── zsh/              # Zsh configuration
├── fish/             # Fish shell configuration
├── tmux/             # Tmux configuration
├── alacritty/        # Terminal emulator config
├── kitty/            # Terminal emulator config
├── helix/            # Helix editor config
├── emacs/            # Emacs configuration
└── [various other tool configs]/
```

## Common Operations

### Working with Scripts

Most scripts are standalone bash scripts. Before running:
1. Check the script header for dependencies
2. Scripts may need executable permissions: `chmod +x script.sh`

Key scripts:
- `scripts/setup_myfiles.sh` - Sets up personal directory structure at `~/MyFiles`
- `openclaw/dump-openclaw-config-schema.sh` - Generates JSON schema for OpenClaw config

### Monitoring Stack (macos-server)

Located at `ops/monitoring/macos-server/` - A complete Prometheus/Grafana/Alertmanager setup.

**Installation and Management**:
```bash
cd ops/monitoring/macos-server

# Setup
cp env.example .env
# Edit .env with your settings (GRAFANA_ADMIN_PASSWORD, BARK_DEVICE_KEY, etc.)

./install.sh    # Auto-detects Docker vs native mode
./start.sh      # Start all services
./stop.sh       # Stop all services
./status.sh     # Check service status
./migrate.sh    # Migrate from native to Docker mode
```

**Configuration Rendering**:
```bash
./render-configs.sh  # Renders templates to .rendered/ directory
```

**Ports**:
- 3000: Grafana (default bind: 0.0.0.0)
- 9090: Prometheus (default bind: 127.0.0.1)
- 9093: Alertmanager (default bind: 127.0.0.1)
- 9100: node_exporter (default bind: 0.0.0.0)

**Key Files**:
- `prometheus.yml` - Main Prometheus config template
- `alert.rules.yml` - Alerting rules template
- `alertmanager.yml` - Alertmanager config template
- `targets/node_exporters.yml` - Scrape targets
- `env.example` - Environment variable template

### Git Submodules

```bash
# Initialize submodules
git submodule update --init --recursive

# Update submodules
git submodule update --recursive --remote
```

Submodules:
- `vimfiles` → https://github.com/lihuu/vimfiles.git
- `power-shell-config` → https://github.com/lihuu/power-shell-config.git

### Vim/Neovim

- `vimfiles/` is a submodule managed separately
- `nvim/` contains backup and install scripts for Neovim
- See `vimfiles/README.md` for detailed vim plugin documentation

## Architecture Notes

### macOS Monitoring Stack

The monitoring setup supports dual deployment modes:

1. **Docker Mode** (preferred if Docker available):
   - Prometheus, Alertmanager, Grafana run in containers
   - node_exporter runs on host via Homebrew
   - Uses `host.docker.internal:9100` to scrape host metrics

2. **Native Mode** (fallback):
   - All services installed via Homebrew
   - Direct localhost communication

**Configuration Flow**:
1. Templates (`.yml` files in root) contain placeholders
2. `render-configs.sh` processes templates using `.env` values
3. Rendered configs go to `.rendered/` directory (gitignored)
4. Services use rendered configs

**Alerting Channels**:
- Bark (via webhook bridge: `bridges/bark_webhook_bridge.py`)
- Telegram (native Alertmanager integration)
- Both can be configured simultaneously in `.env`

### Script Conventions

- Shell scripts use bash
- Scripts often include color output definitions
- Many scripts check for dependencies before running
- Backup scripts use `rsync` with archive mode

### OpenClaw Schema Generation

The `openclaw/` directory contains:
- `dump-openclaw-config-schema.sh` - Generates schema from running OpenClaw gateway
- `jq-usage.md` - Documentation for jq JSON processing
- `openclaw.schema.json` - Generated JSON schema

The script requires `openclaw` CLI to be installed and configured.

## Working Guidelines

1. **Configuration Changes**: When modifying monitoring configs, always update the template files, not the rendered files in `.rendered/`

2. **Adding New Targets**: Edit `ops/monitoring/macos-server/targets/node_exporters.yml` and restart the stack

3. **Environment Variables**: Never commit `.env` files - they contain sensitive configuration

4. **Documentation**: This repo uses Chinese for documentation (see `AGENTS.md` for detailed context)

5. **Safety**: This is a public repository - never include:
   - API keys or tokens
   - Private certificates
   - Personal passwords
   - Internal hostnames/IPs

## Reference: AGENTS.md

The repository includes `AGENTS.md` which provides detailed guidance in Chinese about:
- Role positioning (SRE/DevOps/Platform Engineer perspective)
- Working style preferences
- Security baselines
- Output and collaboration requirements

Consult `AGENTS.md` for the complete context when working on this repository.
