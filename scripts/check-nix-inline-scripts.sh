#!/usr/bin/env bash
# Fail if any .nix file contains inline scripts.
# Catches:
#   1. write*Script* functions with inline string literals
#   2. home.activation blocks with inline shell (must delegate to bash)
#
# All script content must live in external .sh files referenced via
# builtins.readFile, pkgs.replaceVars, or ${pkgs.bash}/bin/bash ${./script.sh}
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREP_EXCLUDE=(--exclude-dir='.git' --exclude-dir='result' --exclude-dir='.direnv' --exclude-dir='.worktrees' --exclude-dir='worktrees' --exclude-dir='.conductor')
FIND_PRUNE=(-path '*/.git' -o -path '*/result' -o -path '*/.direnv' -o -path '*/.worktrees' -o -path '*/worktrees' -o -path '*/.conductor')

# --- Check 1: writeScript / writePython3 with inline strings ---
shell_violations=$(grep -rn \
  --include='*.nix' \
  -E 'write(Shell)?(Script|ScriptBin)[[:space:]]+"[^"]+"+[[:space:]]+'"''" \
  "$ROOT" \
  "${GREP_EXCLUDE[@]}" |
  grep -v "^Binary" || true)

python_violations=$(grep -rn \
  --include='*.nix' \
  -E 'writePython3(Bin)?[[:space:]]+"[^"]+"+[[:space:]]+' \
  "$ROOT" \
  "${GREP_EXCLUDE[@]}" |
  grep -v "^Binary" || true)

# --- Check 2: home.activation blocks with inline shell ---
# Strategy: find activation script bodies (between '' delimiters) and require
# them to contain only:
#   - export statements
#   - lib.optionalString export interpolations
#   - a delegated bash script invocation
#   - argument continuation lines for that bash invocation
activation_violations=""
while IFS= read -r nix_file; do
  result=$(awk '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function is_single_arg(line) {
      return line ~ /^(".*"|\$\{.*\}|[^[:space:];|&<>`]+)[[:space:]]*\\?$/
    }

    function is_bash_delegate(line) {
      return line ~ /^(\$DRY_RUN_CMD[[:space:]]+)?[^[:space:];|&<>`]*bin\/bash([[:space:]]+(".*"|\$\{.*\}|[^[:space:];|&<>`]+))+([[:space:]]+\|\|[[:space:]]+true)?[[:space:]]*\\?$/
    }

    function block_has_violation(  i, n, line, saw_bash_call, saw_content) {
      saw_bash_call = 0
      saw_content = 0
      n = split(body, lines, "\n")

      for (i = 1; i <= n; i++) {
        line = trim(lines[i])

        if (line == "" || line ~ /^#/) continue
        saw_content = 1

        if (line ~ /&&|;|`|[<>]/) return 1
        if (line ~ /\|/ && line !~ /[[:space:]]\|\|[[:space:]]+true[[:space:]]*\\?$/) return 1

        if (line ~ /^export /) continue
        if (line ~ /^\$\{lib\.optionalString/) continue
        if (is_bash_delegate(line)) {
          saw_bash_call = 1
          continue
        }
        if (saw_bash_call && is_single_arg(line)) continue

        return 1
      }

      return saw_content && !saw_bash_call
    }

    /home\.activation\.[a-zA-Z]/ { in_activation = 1 }
    in_activation && /'"''"'$/ && !body_started {
      body_started = 1
      body = ""
      next
    }
    body_started && /^[[:space:]]*'"''"';/ {
      if (block_has_violation()) {
        printf "%s: inline shell in home.activation block\n", FILENAME
      }
      in_activation = 0
      body_started = 0
      body = ""
      next
    }
    body_started {
      body = body "\n" $0
    }
  ' "$nix_file")
  if [ -n "$result" ]; then
    activation_violations="${activation_violations}${result}
"
  fi
done < <(find "$ROOT" \( "${FIND_PRUNE[@]}" \) -prune -o -name '*.nix' -type f -print)

violations="${shell_violations}${python_violations}${activation_violations}"

if [ -n "$violations" ]; then
  echo "ERROR: Inline scripts found in Nix files." >&2
  echo "All scripts must be external files referenced via builtins.readFile, pkgs.replaceVars," >&2
  # shellcheck disable=SC2016
  echo 'or ${pkgs.bash}/bin/bash ${./script.sh}.' >&2
  echo "" >&2
  echo "$violations" >&2
  exit 1
fi

echo "No inline shell or Python scripts in Nix files"
