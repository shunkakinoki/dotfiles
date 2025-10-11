# GitAlias Integration - Usage Guide

## Quick Setup

Add one line to your shell's RC file:

```bash
# For Bash (~/.bashrc)
source /path/to/gitalias.bash

# For Zsh (~/.zshrc)
source /path/to/gitalias.zsh

# For Fish (~/.config/fish/config.fish)
source /path/to/gitalias.fish
```

## Common Aliases Loaded

### Basic Commands
- `ga` → `git add`
- `gaa` → `git add --all`
- `gap` → `git add --patch`
- `gb` → `git branch`
- `gc` → `git commit`
- `gcm` → `git commit --message`
- `gca` → `git commit --amend`
- `gco` → `git checkout`
- `gd` → `git diff`
- `gf` → `git fetch`
- `gl` → `git log`
- `gm` → `git merge`
- `gp` → `git pull`
- `gs` → `git status`
- `gw` → `git whatchanged`

### Advanced Commands
- `gau` → `git add --update`
- `gbm` → `git branch --merged`
- `gbnm` → `git branch --no-merged`
- `gcaa` → `git commit --amend --all`
- `gcaam` → `git commit --amend --all --message`
- `gcaane` → `git commit --amend --all --no-edit`
- `gci` → `git commit --interactive`
- `gbv` → `git branch --verbose`
- `gbvv` → `git branch --verbose --verbose`
- `gbranches` → `git branch -a`

### Branch Management
- `gbed` → `git branch --edit-description`
- `gbm` → `git branch --merged`
- `gbnm` → `git branch --no-merged`

### Commit Operations
- `gc` → `git commit`
- `gca` → `git commit --amend`
- `gcam` → `git commit --amend --message`
- `gcane` → `git commit --amend --no-edit`
- `gci` → `git commit --interactive`
- `gcm` → `git commit --message`

## Verification

After sourcing, verify the aliases are loaded:

```bash
# Bash/Zsh
alias | grep "^g" | wc -l
# Should show 138-144

# Fish
abbr | grep "^abbr -a g" | wc -l
# Should show ~151 (with some warnings)
```

## Examples

```bash
# Instead of: git add --all
gaa

# Instead of: git commit --message "Fix bug"
gcm "Fix bug"

# Instead of: git commit --amend --no-edit
gcane

# Instead of: git branch --verbose
gbv

# Instead of: git add --patch
gap
```

## Updating

The aliases are fetched fresh from GitAlias each time your shell loads. To get the latest aliases, simply restart your shell or source the file again:

```bash
source /path/to/gitalias.bash  # or .zsh or .fish
```

## Manual Generation

You can also generate and save the aliases to a file:

```bash
# Generate bash aliases
bash scripts/gitalias-to-bash.sh > my-git-aliases.sh

# Generate zsh aliases
zsh scripts/gitalias-to-zsh.sh > my-git-aliases.zsh

# Generate fish abbreviations
fish scripts/gitalias-to-fish.fish > my-git-abbrs.fish
```

Then source the generated file instead of the dynamic loader.
