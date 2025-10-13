# Dotfiles

Comprehensive Nix-based dotfiles for managing system configurations across macOS (via nix-darwin), NixOS, and Linux (via home-manager).

## Quick Installation

```bash
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | sh
```

## Features

- **Multi-Platform Support**: macOS (nix-darwin), NixOS, and Linux (home-manager)
- **Nix Flakes**: Modern, reproducible configuration management
- **Modular Architecture**: Organized configurations for programs, services, and system settings
- **Automated Formatting**: Integrated code formatting with Biome and treefmt
- **CI/CD Pipeline**: Automated testing and dependency updates

## Usage

### Build System

```bash
make install    # Full installation (recommended for new setups)
make build      # Build configuration only
make switch     # Apply configuration changes
make update     # Update all configurations and dependencies
make format     # Format all code
```

### Key Components

- **Development Tools**: Neovim, Fish shell, tmux, fzf, ripgrep, and more
- **Version Control**: Enhanced Git configuration with aliases
- **Terminal**: Ghostty terminal with custom configurations
- **macOS Automation**: Hammerspoon and Karabiner Elements
- **Services**: Code syncing, dotfiles updates, and Ollama

## Structure

```
.
├── flake.nix           # Main Nix flake configuration
├── home-manager/       # User-level configurations
├── nix-darwin/         # macOS-specific system configuration
├── hosts/              # Platform-specific host configurations
├── config/             # Application configurations
└── scripts/            # Utility scripts
```

## Documentation

- [CLAUDE.md](./CLAUDE.md) - Development guidelines and architecture
- [FAQ.md](./FAQ.md) - Troubleshooting and common issues
- [REFERENCES.md](./REFERENCES.md) - Credits and inspiration

## Requirements

- Nix with flakes enabled
- macOS (for nix-darwin) or Linux (for home-manager)
- Git for version control

## Credits

This configuration is inspired by various community dotfiles. See [REFERENCES.md](./REFERENCES.md) for the complete list.

## License

[MIT](./LICENSE)
