#!/usr/bin/env bash
# Merge a local indexing exclusion without replacing generated credentials.
# Restart the daemon separately when applying changes to a running instance.
set -euo pipefail

CONFIG_FILE="$1"
PROVIDER="$2"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"

umask 077
mkdir -p "$CONFIG_DIR"
work_dir="$(mktemp -d "$CONFIG_DIR/.provider-settings.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

if [ -f "$CONFIG_FILE" ]; then
  if ! python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$CONFIG_FILE" 2>/dev/null; then
    echo 'ERROR: refusing to replace invalid AgentsView TOML' >&2
    exit 1
  fi
  if ! dasel query -i toml -o json <"$CONFIG_FILE" >"$work_dir/current.json" 2>/dev/null; then
    echo 'ERROR: refusing to replace invalid AgentsView TOML' >&2
    exit 1
  fi
else
  printf '{}\n' >"$work_dir/current.json"
fi

if ! jq -e '
  type == "object" and (
    (has("disabled_agents") | not) or
    (.disabled_agents | type == "array" and all(.[]; type == "string"))
  )
' "$work_dir/current.json" >/dev/null; then
  echo 'ERROR: disabled_agents must be an array of provider names' >&2
  exit 1
fi

if jq -e --arg provider "$PROVIDER" \
  '(.disabled_agents // []) | index($provider) != null' \
  "$work_dir/current.json" >/dev/null; then
  exit 0
fi

jq --arg provider "$PROVIDER" \
  '.disabled_agents = ((.disabled_agents // []) + [$provider])' \
  "$work_dir/current.json" >"$work_dir/updated.json"
dasel query -i json -o toml <"$work_dir/updated.json" >"$work_dir/config.toml"
# TOML-to-JSON conversion must not change unrelated types or values.
if ! python3 - "$CONFIG_FILE" "$work_dir/config.toml" "$PROVIDER" 2>/dev/null <<'PYTHON'
import pathlib
import sys
import tomllib
original, updated, provider = sys.argv[1:]
p = pathlib.Path(original)
expected = tomllib.loads(p.read_text()) if p.exists() else {}
expected["disabled_agents"] = expected.get("disabled_agents", []) + [provider]
if tomllib.loads(pathlib.Path(updated).read_text()) != expected:
    sys.exit(1)
PYTHON
then
  echo 'ERROR: refusing a lossy AgentsView configuration update' >&2
  exit 1
fi
chmod 600 "$work_dir/config.toml"
mv -f "$work_dir/config.toml" "$CONFIG_FILE"
