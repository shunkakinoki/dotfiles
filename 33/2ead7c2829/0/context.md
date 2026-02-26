# Session Context

## User Prompts

### Prompt 1

…n [$] is 📦 v0.1.0 via 🥟 v1.3.9 via 🐍 v3.13.12 via 🦀 v1.93.1 on ☁️  shun@horizon.io
❯ _tsh_function
string replace: --\d{8}-\d{6}\.txt$: unknown option

~/.config/fish/functions/_tsh_function.fish (line 1):
in command substitution
    called on line 24 of file ~/.config/fish/functions/_tsh_function.fish
in function '_tsh_function'

(Type 'help string' for related documentation)
 why

### Prompt 2

ok create PR

### Prompt 3

Base directory for this skill: /Users/shunkakinoki/.claude/skills/pr-create

# /pr-create — Create pull requests

Create GitHub PRs with proper formatting, labeling, and quality checks.

## Quick Workflow

```bash
# 1. Stage and commit
git add .
git commit -m "feat: add feature"

# 2. Push branch
git push -u origin feature-branch

# 3. Create PR
gh pr create \
  --title "feat: add feature" \
  --body "## Changes
- Added feature X

## Testing
- All checks pass

Generated with [AI_TOOL] by [AI_...

