#!/usr/bin/env bash
# Hydrate roborev config from .env secrets
# ROBOREV_REPOS: comma-separated list of repos (e.g. "org/repo1,org/repo2")
# shellcheck source=/dev/null
set -euo pipefail

CONFIG_DIR="${HOME}/.roborev"
CONFIG="${CONFIG_DIR}/config.toml"
TEMPLATE="@template@"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

ROBOREV_REPOS="${ROBOREV_REPOS:-}"
if [ -z "$ROBOREV_REPOS" ] && [ -n "${ROBOREV_CI_REPOS:-}" ]; then
  ROBOREV_REPOS="$ROBOREV_CI_REPOS"
  echo "Warning: ROBOREV_CI_REPOS is deprecated; rename it to ROBOREV_REPOS" >&2
fi

if [ -z "$ROBOREV_REPOS" ]; then
  echo "Warning: ROBOREV_REPOS not set, skipping roborev hydration" >&2
  exit 0
fi

# Build TOML array from comma-separated list
IFS=',' read -ra REPOS <<<"$ROBOREV_REPOS"
VALID_REPOS=()
TOML_REPOS=""
for value in "${REPOS[@]}"; do
  repo="$(echo "$value" | xargs)"
  owner="${repo%%/*}"
  name="${repo#*/}"
  if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || \
    [ "$owner" = "." ] || [ "$owner" = ".." ] || \
    [ "$name" = "." ] || [ "$name" = ".." ]; then
    echo "Warning: ignoring invalid RoboRev repository: $repo" >&2
    continue
  fi
  if [ "${#VALID_REPOS[@]}" -gt 0 ]; then
    TOML_REPOS+=", "
  fi
  TOML_REPOS+="\"${repo}\""
  VALID_REPOS+=("$repo")
done

if [ "${#VALID_REPOS[@]}" -eq 0 ]; then
  echo "Warning: ROBOREV_REPOS contains no valid repositories, skipping roborev hydration" >&2
  exit 0
fi

mkdir -p "$CONFIG_DIR"

@sed@ \
  -e "s|\"__ROBOREV_REPOS__\"|${TOML_REPOS}|g" \
  "$TEMPLATE" >"$CONFIG"
chmod 600 "$CONFIG"

echo "Generated roborev config at $CONFIG" >&2

ROBOREV_BIN="${HOME}/.local/bin/roborev"
if [ ! -x "$ROBOREV_BIN" ]; then
  echo "Warning: RoboRev binary not found; skipping Git hook installation" >&2
  exit 0
fi

for repo in "${VALID_REPOS[@]}"; do
  repo_path="${HOME}/ghq/github.com/${repo}"
  if [ ! -d "$repo_path" ]; then
    echo "Warning: RoboRev repository checkout not found: $repo_path" >&2
    continue
  fi

  if ! (
    cd "$repo_path"
    "$ROBOREV_BIN" install-hook --binary "$ROBOREV_BIN"
  ); then
    echo "Warning: failed to install RoboRev Git hook in $repo_path" >&2
  fi
done
