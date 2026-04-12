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
# Strategy: find activation script bodies (between '' delimiters) that contain
# shell commands beyond allowed patterns (exports, bash delegation, DRY_RUN_CMD).
#
# We use awk to extract activation block bodies and check each one.
activation_violations=""
while IFS= read -r nix_file; do
  # Extract activation block bodies using awk
  # Looks for: home.activation.NAME = ... ''  ...  '';
  # Allows: export, $DRY_RUN_CMD, ${pkgs.bash}/bin/bash, empty lines, comments
  result=$(awk '
    /home\.activation\.[a-zA-Z]/ { in_activation = 1; name = $0 }
    in_activation && /'"''"'$/ && !body_started {
      body_started = 1
      body = ""
      line_count = 0
      next
    }
    body_started && /^[[:space:]]*'"''"';/ {
      # End of body - check it
      if (line_count > 0) {
        # Check each non-empty line
        has_violation = 0
        split(body, lines, "\n")
        has_bash_call = 0
        for (i in lines) {
          line = lines[i]
          # Strip leading whitespace
          gsub(/^[[:space:]]+/, "", line)
          # Skip empty lines
          if (line == "") continue
          # Allow: export statements
          if (line ~ /^export /) continue
          # Allow: nix conditional expressions (lib.optionalString)
          if (line ~ /^\$\{lib\.optionalString/) continue
          # Allow: bash delegation line ($DRY_RUN_CMD ${pkgs.bash}/bin/bash ...)
          if (line ~ /bin\/bash/) { has_bash_call = 1; continue }
          # Allow: line continuations (trailing \) for multi-line bash calls
          if (line ~ /\\$/) continue
          # Allow: nix interpolation lines (start with ${ - args to bash call)
          if (line ~ /^\$\{/) continue
          # Allow: quoted nix interpolation args (bash call continuation args)
          if (line ~ /^".*"$/) continue
          # Allow: bare identifiers (e.g. GPG fingerprints passed as args)
          if (line ~ /^[A-Za-z0-9_-]+$/) continue
          # Anything else is a violation - including bare $DRY_RUN_CMD commands
          has_violation = 1
        }
        if (has_violation) {
          printf "%s: inline shell in home.activation block\n", FILENAME
        }
      }
      in_activation = 0
      body_started = 0
      body = ""
      line_count = 0
      next
    }
    body_started {
      body = body "\n" $0
      line_count++
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
