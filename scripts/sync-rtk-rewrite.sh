#!/usr/bin/env bash
# sync-rtk-rewrite.sh — Sync rtk-rewrite.sh from upstream rtk repo via raw GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://raw.githubusercontent.com/rtk-ai/rtk/main/.claude/hooks/rtk-rewrite.sh"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$URL" -o "$tmpfile"

cp "$tmpfile" "$ROOT/config/claude/hooks/rtk-rewrite.sh"
cp "$tmpfile" "$ROOT/config/codex/hooks/rtk-rewrite.sh"
