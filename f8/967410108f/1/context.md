# Session Context

## User Prompts

### Prompt 1

migrate opencode config to use Themes
Set your UI theme in tui.json.

tui.json
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "tokyonight"
}

### Prompt 2

make format and create PR

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

### Prompt 4

i don't think you need config/opencode/tui.tpl.json? it completely relies on non-llm characteristics

