#!/usr/bin/env bash
# Fail if any .nix file passes an inline string literal to write*Script* functions.
# All script content must live in external files referenced via builtins.readFile
# or pkgs.replaceVars, not embedded as inline '' strings.
#
# Catches: writeScript, writeShellScript, writeShellScriptBin, writeScriptBin
# Does NOT flag: writeText (used for config files, not scripts)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

violations=$(grep -rn \
  --include='*.nix' \
  -P "write(Shell)?(Script|ScriptBin)\s+\"[^\"]+\"\s+''" \
  "$ROOT" \
  --exclude-dir='.git' \
  --exclude-dir='result' \
  --exclude-dir='.direnv' \
  --exclude-dir='.worktrees' \
  | grep -v "^Binary" || true)

if [ -n "$violations" ]; then
  echo "ERROR: Inline script strings found in Nix files." >&2
  echo "All scripts must be external files referenced via builtins.readFile or pkgs.replaceVars." >&2
  echo "" >&2
  echo "$violations" >&2
  exit 1
fi

echo "✓ No inline scripts in Nix files"
