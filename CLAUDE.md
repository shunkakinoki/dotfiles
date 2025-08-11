# CLAUDE.md - Development Guidelines for Shun Kakinoki's Dotfiles

## Project Overview

This is a comprehensive Nix-based dotfiles repository that manages system configurations across macOS (via nix-darwin), NixOS, and Linux (via home-manager). The repository provides a unified configuration system for development environments, applications, and system settings.

## Architecture

### Core Structure

- **Nix Flakes**: Modern Nix configuration using `flake.nix` as the entry point
- **Multi-Platform Support**: Supports macOS (nix-darwin), NixOS, and Linux (home-manager)
- **Modular Configuration**: Organized into logical modules for different system components

### Key Directories

- `home-manager/`: User-level configurations (programs, services, dotfiles)
- `nix-darwin/`: macOS-specific system configuration
- `hosts/`: Platform-specific host configurations
- `config/`: Application-specific configurations (Hammerspoon, Karabiner, Starship)
- `programs/`: Individual program configurations
- `services/`: Background services and automation

## Build System & Commands

### Primary Commands

```bash
# Full installation (recommended for new setups)
make install

# Build configuration only
make build

# Apply configuration changes
make switch

# Update all configurations and dependencies
make update

# Format all code
make format

# Check formatting
make format-check
```

### Quick Installation

```bash
curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | sh
```

### Development Workflow

1. **Setup**: Run `make install` for initial setup
2. **Development**: Make changes to Nix files
3. **Test**: Run `make build` to verify configuration builds
4. **Apply**: Run `make switch` to activate changes
5. **Format**: Run `make format` before committing

## Key Configuration Files

### System Configuration

- `flake.nix`: Main Nix flake configuration with inputs and outputs
- `Makefile`: Build system with cross-platform support
- `install.sh`: Automated installation script

### Code Quality & Formatting

- `biome.json`: JavaScript/TypeScript/JSON formatting rules
  - 2-space indentation
  - 80-character line width
  - Double quotes, trailing commas (ES5)
- `treefmt.toml`: Multi-language formatting configuration
- `renovate.json`: Automated dependency management

### Development Tools

- **Terminal**: Fish shell with extensive customizations
- **Editor**: Neovim with Lua configuration
- **Version Control**: Git with enhanced configuration
- **Multiplexer**: tmux with custom settings
- **CLI Tools**: fzf, ripgrep, fd, bat, lsd, zoxide, and more

## Platform-Specific Features

### macOS (nix-darwin)

- **Homebrew Integration**: Managed through Nix configuration
- **System Preferences**: Dock, fonts, security, networking
- **Applications**: Both Nix packages and Homebrew casks
- **Window Management**: Hammerspoon for automation
- **Keyboard**: Karabiner Elements for key remapping

### Linux/NixOS

- **Home Manager**: User environment management
- **Minimal Dependencies**: Core tools without GUI applications
- **Container Support**: Docker-friendly configurations

## Development Guidelines

### Code Style

- **Nix Files**: Use nixfmt for formatting (automated via `make format`)
- **Shell Scripts**: Use shfmt with 2-space indentation
- **JSON/JS/TS**: Use Biome with project-specific rules
- **Commit Messages**: Follow semantic commit conventions

### File Organization

- Keep configurations modular and platform-specific
- Use `default.nix` files for module exports
- Organize by function rather than file type
- Document complex configurations with comments

### Dependencies

- Prefer Nix packages over external package managers
- Use Homebrew only for macOS-specific applications
- Pin important dependencies in flake.lock
- Use Renovate for automated dependency updates

## Automation & CI/CD

### GitHub Actions

- **Nix Builds**: Test configurations on macOS, Linux, and NixOS
- **Formatting**: Enforce code formatting standards
- **E2E Testing**: Full installation testing across platforms
- **Dependency Updates**: Automated via Renovate

### Services

- **Code Syncer**: Automated code synchronization
- **Dotfiles Updater**: Regular configuration updates
- **Ollama**: Local AI model management

## Troubleshooting

### Common Issues

- **Dock Items Lost (macOS)**: See FAQ.md for resolution steps
- **Nix Daemon Issues**: Run `make nix-connect` to restart daemon
- **Build Failures**: Check system compatibility and dependencies

### Debug Commands

```bash
# Check Nix environment
make nix-check

# Verify build without applying
make build

# Format check before committing
make format-check

# View detailed build logs
nix build --show-trace
```

## Key Applications & Tools

### Development

- **Claude Code**: AI-powered development assistant
- **Cursor**: AI-enhanced code editor
- **Visual Studio Code**: Primary editor
- **Ghostty**: Modern terminal emulator
- **Docker Desktop**: Container development

### Communication & Productivity

- **Claude**: AI assistant application
- **ChatGPT**: AI chat interface
- **Discord/Slack**: Team communication
- **Notion**: Note-taking and planning
- **Linear**: Project management

### System Utilities

- **Raycast**: Launcher and productivity tool
- **Hammerspoon**: macOS automation
- **RescueTime**: Time tracking
- **Screen Studio**: Screen recording

## References & Inspiration

This configuration draws inspiration from several notable dotfiles repositories:

- Mitchell Hashimoto's nixos-config
- Dustin Lyons' nixos-config
- takeokunn's nix-configuration
- See REFERENCES.md for complete list

## Getting Help

- **FAQ**: Check FAQ.md for common issues
- **Documentation**: Refer to inline comments in configuration files
- **Community**: Follow referenced repositories for similar patterns
- **Issues**: Open GitHub issues for bugs or feature requests

---

_This configuration is designed to be both powerful and maintainable, with emphasis on reproducibility across different systems and environments._
