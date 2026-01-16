---
name: add-skill
description: Install agent skills from git repositories using add-skill CLI. Use when the user asks to "add a skill", "install a skill", "get skills from", or wants to extend coding agent capabilities with new skills from GitHub or other git sources.
metadata:
  author: shunkakinoki
  version: "1.0.0"
---

# Add Skill

Install agent skills from any git repository using `npx add-skill`.

## When to Use

- User wants to install new skills from a repository
- User wants to list available skills from a skill repository
- User wants to install skills globally or per-project
- User mentions skill repositories like `vercel-labs/agent-skills`

## Quick Start

```bash
# List skills in a repository
npx add-skill <source> --list

# Install all skills from a repository globally
npx add-skill <source> -g -y

# Install specific skills
npx add-skill <source> --skill <skill-name> -g
```

## Source Formats

```bash
# GitHub shorthand
npx add-skill vercel-labs/agent-skills

# Full GitHub URL
npx add-skill https://github.com/vercel-labs/agent-skills

# Direct path to a skill in a repo
npx add-skill https://github.com/vercel-labs/agent-skills/tree/main/skills/frontend-design

# GitLab URL
npx add-skill https://gitlab.com/org/repo

# Any git URL
npx add-skill git@github.com:vercel-labs/agent-skills.git
```

## Options

| Option | Description |
|--------|-------------|
| `-g, --global` | Install to user directory instead of project |
| `-a, --agent <agents...>` | Target specific agents: `opencode`, `claude-code`, `codex`, `cursor`, `antigravity` |
| `-s, --skill <skills...>` | Install specific skills by name |
| `-l, --list` | List available skills without installing |
| `-y, --yes` | Skip all confirmation prompts |

## Installation Paths

### Project-level (default)
| Agent | Path |
|-------|------|
| Claude Code | `.claude/skills/<name>/` |
| OpenCode | `.opencode/skill/<name>/` |
| Codex | `.codex/skills/<name>/` |
| Cursor | `.cursor/skills/<name>/` |

### Global (`--global`)
| Agent | Path |
|-------|------|
| Claude Code | `~/.claude/skills/<name>/` |
| OpenCode | `~/.config/opencode/skill/<name>/` |
| Codex | `~/.codex/skills/<name>/` |
| Cursor | `~/.cursor/skills/<name>/` |

## Examples

```bash
# List available skills
npx add-skill vercel-labs/agent-skills --list

# Install all skills globally for Claude Code
npx add-skill vercel-labs/agent-skills -g -a claude-code -y

# Install specific skill
npx add-skill vercel-labs/agent-skills --skill frontend-design -g -y

# Install to current project
npx add-skill vercel-labs/agent-skills --skill vercel-deploy -y
```

## Popular Skill Repositories

- `vercel-labs/agent-skills` - Official Vercel skills (deployment, React best practices, web design guidelines)

## Reference

- [add-skill CLI](https://github.com/vercel-labs/add-skill)
- [Agent Skills Specification](https://agentskills.io)
