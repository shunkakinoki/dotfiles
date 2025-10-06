# GitAlias Shell Integration

Programmatically load all [GitAlias](https://github.com/GitAlias/gitalias) aliases into bash, zsh, and fish shells.

## Features

- **138-144 Git aliases** automatically loaded from the official GitAlias repository
- **Multi-shell support**: bash, zsh, and fish
- **Dynamic loading**: Always gets the latest aliases from GitAlias
- **Prefix convention**: All aliases are prefixed with `g` (e.g., `ga` for `git add`)
- **Smart filtering**: Complex multi-line aliases are filtered out for compatibility

## Quick Start

### Nix Integration (Recommended)

The GitAlias integration is **automatically built into the shell configurations** via Nix. The aliases are generated at build time and injected directly into your shell configs.

**How it works:**
- `home-manager/programs/gitalias/default.nix` - Nix module that fetches GitAlias and generates shell-specific aliases
- `home-manager/programs/bash/default.nix` - Automatically includes GitAlias for Bash
- `home-manager/programs/zsh/default.nix` - Automatically includes GitAlias for Zsh
- `home-manager/programs/fish/default.nix` - Automatically includes GitAlias for Fish

**Usage:**
Simply rebuild your Nix configuration:
```bash
make build    # or make switch
```

The GitAlias aliases (136-142 aliases) will be automatically available in your shell!

### Build-Time Generation (Standalone)

For non-Nix users, generate static alias files at build time using Make:

```bash
# Generate all alias files
make gitalias-generate

# Test the generated files
make gitalias-test

# Clean generated files
make gitalias-clean
```

Then source the static files:

```bash
# Bash (~/.bashrc)
source /path/to/gitalias-static.bash

# Zsh (~/.zshrc)
source /path/to/gitalias-static.zsh

# Fish (~/.config/fish/config.fish)
source /path/to/gitalias-static.fish
```

### Runtime Generation (Alternative)

For dynamic loading that fetches latest aliases on each shell startup:

```bash
# Bash
source /path/to/gitalias.bash

# Zsh
source /path/to/gitalias.zsh

# Fish
source /path/to/gitalias.fish
```

## Example Aliases

Once loaded, you can use shortcuts like:

```bash
ga                    # git add
gaa                   # git add --all
gc                    # git commit
gcm "message"         # git commit --message "message"
gca                   # git commit --amend
gs                    # git status
gd                    # git diff
gl                    # git log
gb                    # git branch
go branch-name        # git checkout branch-name
gp                    # git pull
gf                    # git fetch
gm                    # git merge
```

## Files

### Nix Integration
- `home-manager/programs/gitalias/default.nix` - Main Nix module (fetches & generates aliases)
- `home-manager/programs/bash/default.nix` - Bash config with GitAlias integration
- `home-manager/programs/zsh/default.nix` - Zsh config with GitAlias integration
- `home-manager/programs/fish/default.nix` - Fish config with GitAlias integration

### Standalone Scripts
- `gitalias.bash` - Runtime loader for bash
- `gitalias.zsh` - Runtime loader for zsh
- `gitalias.fish` - Runtime loader for fish
- `scripts/gitalias-to-bash.sh` - Generator script for bash aliases
- `scripts/gitalias-to-zsh.sh` - Generator script for zsh aliases
- `scripts/gitalias-to-fish.fish` - Generator script for fish abbreviations
- `gitalias-static.{bash,zsh,fish}` - Pre-generated static files (from `make gitalias-generate`)

## Manual Generation

You can also generate the aliases manually:

```bash
# Bash/Zsh aliases
bash scripts/gitalias-to-bash.sh > my-git-aliases.sh
source my-git-aliases.sh

# Fish abbreviations
fish scripts/gitalias-to-fish.fish > my-git-abbrs.fish
source my-git-abbrs.fish
```

## How It Works

### Nix Build-Time Generation

1. `home-manager/programs/gitalias/default.nix` fetches GitAlias from GitHub using `pkgs.fetchurl`
2. Generator scripts (written in bash) parse the git config format to extract alias definitions
3. At Nix build time, aliases are converted to shell-specific format:
   - Bash: `alias gXXX='git XXX'`
   - Zsh: `alias gXXX='git XXX'`
   - Fish: `abbr -a gXXX 'git XXX'`
4. Complex aliases (shell functions, color codes, special syntax) are filtered out
5. The generated aliases are embedded directly into shell init files via Nix string interpolation
6. All aliases are prefixed with `g` to avoid conflicts

### Manual Generation

1. Scripts download the latest `gitalias.txt` from the GitAlias repository
2. Parse git config format to extract alias definitions
3. Convert to shell-specific format
4. Prefix all aliases with `g` to avoid conflicts

## Status

| Shell | Aliases Loaded | Status |
|-------|----------------|--------|
| Bash  | 138           | ✅ Working |
| Zsh   | 144           | ✅ Working |
| Fish  | 151           | ⚠️  Some errors (WIP) |

## Notes

- Fish uses abbreviations instead of aliases for better interactive experience
- Complex multi-line aliases with backslash continuations, shell functions (`!`), color codes (`%C`), or special Git syntax (`@{upstream}`) are filtered out for compatibility
- Requires `curl` for downloading the GitAlias file
- The scripts download aliases fresh each time they're run
- Bash and Zsh fully supported; Fish integration is a work in progress

## Credits

- [GitAlias](https://github.com/GitAlias/gitalias) - The comprehensive git alias collection
- Created for Shun Kakinoki's dotfiles repository
