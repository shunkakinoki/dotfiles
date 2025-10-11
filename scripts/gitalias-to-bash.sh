#!/usr/bin/env bash
# Convert GitAlias to bash aliases

set -euo pipefail

GITALIAS_URL="https://raw.githubusercontent.com/GitAlias/gitalias/main/gitalias.txt"
TEMP_FILE=$(mktemp)

# Download GitAlias file
curl -fsSL "$GITALIAS_URL" -o "$TEMP_FILE"

# Parse and convert to bash aliases
grep -E "^\s*[a-zA-Z0-9_-]+\s*=" "$TEMP_FILE" | while IFS= read -r line; do
  # Skip lines that are comments or complex multiline aliases
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # Extract alias name and command, properly trimming whitespace
  alias_name=$(echo "$line" | awk -F'=' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
  alias_cmd=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/^\s+//')

  # Skip empty aliases
  [[ -z "$alias_name" || -z "$alias_cmd" ]] && continue

  # Skip complex aliases that have problematic quoting or multi-line constructs
  # Skip if contains: trailing backslash, "!, %C (color codes), starts with !, GIT_, @{, nested quotes, or backslash-quote
  if [[ "$alias_cmd" =~ \\$ ]] || [[ "$alias_cmd" =~ %C ]] || [[ "$alias_cmd" =~ ^! ]] || [[ "$alias_cmd" =~ GIT_ ]] || [[ "$alias_cmd" =~ \![[:space:]] ]] || [[ "$alias_cmd" =~ ![a-z] ]] || [[ "$alias_cmd" =~ @\{ ]] || [[ "$alias_cmd" =~ \"-[a-z] ]] || [[ "$alias_cmd" =~ \\\' ]] || [[ "$alias_cmd" =~ \"! ]]; then
    continue
  fi

  # Escape single quotes in the command
  alias_cmd="${alias_cmd//\'/\'\\\'\'}"

  # Output bash alias
  echo "alias g${alias_name}='git ${alias_cmd}'"
done

# Cleanup
rm -f "$TEMP_FILE"
