#!/usr/bin/env bash
# Update GitAlias file from upstream

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GITALIAS_FILE="$REPO_ROOT/home-manager/programs/git/gitalias.txt"

echo "Downloading latest gitalias.txt from GitHub..."
curl -fsSL https://raw.githubusercontent.com/GitAlias/gitalias/main/gitalias.txt -o "$GITALIAS_FILE"

echo "✅ Updated gitalias.txt"
echo "📝 Review changes and commit if needed"
