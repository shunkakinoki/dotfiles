#!/usr/bin/env bash
set -euo pipefail

found_checkout=false
while IFS= read -r -d '' package_json; do
  if ! warm_command=$("@jq@/bin/jq" -r '(.scripts? // {})["ci:box-warm"] | select(type == "string" and length > 0)' "$package_json"); then
    continue
  fi
  [ -n "$warm_command" ] || continue
  found_checkout=true
  repository_dir=${package_json%/package.json}
  cd "$repository_dir"
  if "@bunBin@" run ci:box-warm; then
    exit 0
  fi
done < <("@findutils@/bin/find" "$HOME/ghq/github.com" -mindepth 3 -maxdepth 3 -type f -name package.json -print0 2>/dev/null)

if [ "$found_checkout" = true ]; then
  echo "all ghq checkouts exposing ci:box-warm failed" >&2
  exit 1
fi
echo "could not find a ghq checkout exposing ci:box-warm" >&2
exit 1
