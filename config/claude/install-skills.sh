#!/usr/bin/env bash
# Install agent skills from external repositories
# Usage: ./install-skills.sh
# Docs: https://agentskills.io

set -euo pipefail

echo "Installing agent skills..."

# Install Vercel agent-skills (React best practices + Web design guidelines)
# https://github.com/vercel-labs/agent-skills
npx add-skill vercel-labs/agent-skills \
  --agent claude-code \
  --skill vercel-react-best-practices \
  --skill web-design-guidelines \
  --yes

echo "Done! Skills installed to ~/.claude/skills/"
