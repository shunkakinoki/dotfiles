# Session Context

## User Prompts

### Prompt 1

add make reset command that clears git submodule and resets git status to no changed

### Prompt 2

yes; but use the existing make cmds that does that

### Prompt 3

ok create PR

### Prompt 4

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

