#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r -d '' package_json; do
  if ! "@gnugrep@/bin/grep" -q '"ci:box-warm"' "$package_json"; then
    continue
  fi
  repository_dir=${package_json%/package.json}
  cd "$repository_dir"
  exec "@bunBin@" run ci:box-warm
done < <("@findutils@/bin/find" "$HOME/ghq/github.com" -mindepth 3 -maxdepth 3 -type f -name package.json -print0 2>/dev/null)

echo "could not find a ghq checkout exposing ci:box-warm" >&2
exit 1
