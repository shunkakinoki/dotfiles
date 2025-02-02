# dotfiles

Cross-platform dotfiles with macOS & Linux support

## Features
- 🖥️ OS-aware configuration
- 🔄 Safe symlinking with backups
- 📦 Package manager bootstrap
- 🧪 Validation testing

## Installation
```bash
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

## Structure
```
.dotfiles/
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
