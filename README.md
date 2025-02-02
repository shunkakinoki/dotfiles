# dotfiles

Cross-platform dotfiles with macOS & Linux support

## Features
- ✅ GitHub Codespaces compatible
- 🖥️ OS-aware configuration
- 🔄 Safe symlinking with backups
- 📦 Package manager bootstrap
- 🧪 Validation testing

## Installation
```bash
# Local installation
make install

# Codespaces will auto-install during creation
```

## GitHub Codespaces Setup
1. Add this repository in your [GitHub Codespaces settings](https://github.com/settings/codespaces)
2. Codespaces will automatically:
   - Clone your dotfiles
   - Run `install.sh` to set up symlinks
   - Use platform-specific configurations

## Structure
```
.dotfiles/
├── install.sh       # Codespaces entry point
├── dotfiles/
│   ├── common/       # Shared configs (e.g., .bashrc, .vimrc)
│   ├── osx/          # macOS-specific (e.g., .macos)
│   ├── linux/        # Linux-specific (e.g., .xinitrc)
│   └── symlink.sh    # Intelligent symlink creator
├── scripts/
│   ├── setup/        # OS bootstrap scripts
│   ├── brew.sh       # Homebrew installer
│   └── apt.sh        # Apt package installer
├── Makefile          # Primary interface
└── .gitignore
```

## Customization
1. Add common configs to `dotfiles/common/`
2. Place OS-specific files in respective folders
3. Update package lists in `scripts/`
