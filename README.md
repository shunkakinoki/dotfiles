# Dotfiles

Cross-platform dotfiles management using Nix Home Manager for macOS and Ubuntu.

## Features

- Cross-platform configuration management using Nix Home Manager
- Consistent development environment across macOS and Ubuntu
- Declarative configuration for reproducible setups
- Version controlled dotfiles and package management
- Automated installation and setup process

## Prerequisites

- Nix Package Manager
- Git
- Home Manager

## Installation

### 1. Install Nix Package Manager

#### macOS
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

#### Ubuntu
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 2. Install Home Manager

After installing Nix, set up your environment:

```bash
# Source Nix environment (add this to your shell's rc file)
source ~/.nix-profile/etc/profile.d/nix.sh
```

Home Manager will be automatically installed when needed.

### 3. Clone and Setup

1. Clone this repository:
```bash
git clone https://github.com/shunkakinoki/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

2. Apply the Home Manager configuration:
```bash
# Ensure Nix environment is sourced
source ~/.nix-profile/etc/profile.d/nix.sh

# Apply configuration (will install Home Manager if needed)
make switch
```

## Synchronization

To sync changes across machines:

1. On the source machine:
```bash
git add .
git commit -m "Update configuration"
git push
```

2. On other machines:
```bash
cd ~/.dotfiles
git pull
home-manager switch
```

## Included Tools and Configurations

- Shell: Zsh with Oh My Zsh
- Editor: Neovim with essential plugins
- Version Control: Git with sensible defaults
- Terminal Multiplexer: Tmux
- Development Tools:
  - ripgrep
  - fd
  - fzf
  - jq
  - tree
- Programming Languages:
  - Node.js
  - Python 3
  - Rust

## Troubleshooting

If you encounter issues:

1. Ensure Nix and Home Manager are properly installed:
```bash
nix --version
home-manager --version
```

2. Check for configuration errors:
```bash
home-manager build
```

3. View Home Manager logs:
```bash
journalctl -u home-manager-shunkakinoki
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

You can contribute in two ways:

### Quick PR Creation

Use our one-line command to create PRs directly:
```bash
# Basic usage (auto-fills PR title and body from commit)
make pr m='Your commit message' b='your-branch-name'

# With custom PR title
make pr m='Your commit message' b='your-branch-name' t='Your PR title'
```

For example:
```bash
# Auto-filled PR title/body
make pr m='Add new zsh aliases' b='zsh-aliases'

# Custom PR title
make pr m='Add new zsh aliases' b='zsh-aliases' t='feat: Enhanced ZSH Configuration'
```

This will:
1. Create a new feature branch
2. Add all changes
3. Commit with your message
4. Push to GitHub
5. Create a PR using GitHub CLI
   - If no title (`t`) is provided, it will auto-fill from the commit
   - If title is provided, it will use that with the commit message as the PR body

Prerequisites:
- GitHub CLI is included in the Nix configuration
- Authenticate with GitHub:
```bash
gh auth login
```

### Manual Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Before Submitting

Make sure to:
- Run `make format` to format Nix files
- Run `make format-check` to verify formatting
- Test your changes with `make switch`

## Acknowledgments

- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Oh My Zsh](https://ohmyz.sh/)

## Development Workflow

This repository follows a PR-based workflow to ensure configuration stability.

### Code Formatting

All Nix files must be formatted using `nixpkgs-fmt`