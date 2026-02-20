# Session Context

## User Prompts

### Prompt 1

how to add keybindings for ghostty for panels like command + | to split, etc.

### Prompt 2

no for macos

### Prompt 3

add both?

### Prompt 4

ok how to nativate between panes in ghostty

### Prompt 5

yes

### Prompt 6

how would you press on macos?

### Prompt 7

no i want both

### Prompt 8

alt is option on mac?

### Prompt 9

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

Generated with [AI_TOOL] by [AI_M...

