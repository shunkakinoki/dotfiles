# Session Context

## User Prompts

### Prompt 1

how to see git notes

### Prompt 2

can you list all refs/notes/commits

### Prompt 3

why? git-ai is supposed to push to main

### Prompt 4

hmm yea pleaes check why it's not pushing

### Prompt 5

yea let's chain the hooks

### Prompt 6

nah; keep the cargo git-ai

### Prompt 7

ah; so it will still work w/ the git-ai binary being in .cargo/bin?'

### Prompt 8

no; the git-ai needs to be called from ~/.cargo/bin/git-ai make it work as is

### Prompt 9

confirm it's now working

### Prompt 10

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

### Prompt 11

add path for bash as well and push?

