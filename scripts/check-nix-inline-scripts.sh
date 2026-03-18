#!/usr/bin/env bash
# Fail if any .nix file passes an inline string literal to write*Script* functions.
# All script content must live in external files referenced via builtins.readFile
# or pkgs.replaceVars, not embedded as inline '' strings.
#
# Catches shell writers: writeScript, writeShellScript, writeShellScriptBin, writeScriptBin
# Catches Python writers: writePython3, writePython3Bin
# Does NOT flag: writeText (used for config files, not scripts)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXCLUDE_DIRS=(--exclude-dir='.git' --exclude-dir='result' --exclude-dir='.direnv' --exclude-dir='.worktrees')

shell_violations=$(grep -rn \
  --include='*.nix' \
  -E 'write(Shell)?(Script|ScriptBin)[[:space:]]+"[^"]+"+[[:space:]]+'"''" \
  "$ROOT" \
  "${EXCLUDE_DIRS[@]}" |
  grep -v "^Binary" || true)

python_violations=$(grep -rn \
  --include='*.nix' \
  -E 'writePython3(Bin)?[[:space:]]+"[^"]+"+[[:space:]]+' \
  "$ROOT" \
  "${EXCLUDE_DIRS[@]}" |
  grep -v "^Binary" || true)

violations="${shell_violations}${python_violations}"

if [ -n "$violations" ]; then
  echo "ERROR: Inline script strings found in Nix files." >&2
  echo "All scripts must be external files referenced via builtins.readFile or pkgs.replaceVars." >&2
  echo "" >&2
  echo "$violations" >&2
  exit 1
fi

echo "✓ No inline shell or Python scripts in Nix files"
