#!/usr/bin/env bash
# Shared PreToolUse hook for Claude Code and Codex Write/Edit operations.
# Blocks writes containing secrets detected by gitleaks.
# See: https://zenn.dev/takna/articles/secret-leak-prevention-4-layer
set -euo pipefail

# Hook is supplementary, not primary defense. Skip silently if deps missing.
command -v jq >/dev/null 2>&1 || exit 0
command -v gitleaks >/dev/null 2>&1 || exit 0

PAYLOAD=$(cat)

# Extract content across Claude and Codex payload shapes (Write/Edit/MultiEdit).
CONTENT=$(printf '%s' "$PAYLOAD" | jq -r '
  .tool_input.content //
  .tool_input.new_string //
  .tool.input.content //
  .tool.input.new_string //
  .toolInput.content //
  .toolInput.new_string //
  (.tool_input.edits // [] | map(.new_string) | join("\n")) //
  (.tool.input.edits // [] | map(.new_string) | join("\n")) //
  empty
' 2>/dev/null)

[[ -z $CONTENT || $CONTENT == "null" ]] && exit 0

TMP_DIR=$(mktemp -d -t secret-guard.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
printf '%s' "$CONTENT" >"$TMP_DIR/payload.txt"

CONFIG_ARG=()
if [[ -f "$PWD/.gitleaks.toml" ]]; then
  CONFIG_ARG=(--config "$PWD/.gitleaks.toml")
elif [[ -n ${GITLEAKS_CONFIG:-} && -f $GITLEAKS_CONFIG ]]; then
  CONFIG_ARG=(--config "$GITLEAKS_CONFIG")
elif [[ -f "$HOME/.config/gitleaks/config.toml" ]]; then
  CONFIG_ARG=(--config "$HOME/.config/gitleaks/config.toml")
fi

if gitleaks dir "$TMP_DIR" "${CONFIG_ARG[@]}" --no-banner --redact >/dev/null 2>&1; then
  exit 0
fi

cat >&2 <<'EOF'
secret-guard: Blocked Write/Edit due to detected secrets.
- Move credentials to .gitignore'd paths (_credentials/, *.secret.md, etc.)
- Use explicit placeholders like <PLACEHOLDER> or DUMMY_PASSWORD
- See: https://zenn.dev/takna/articles/secret-leak-prevention-4-layer
EOF
exit 2
