#!/usr/bin/env bash
# T3 Code launches Grok through this wrapper. Grok's update (T3's Update button
# runs `grok update`) reinstalls @xai-official/grok with npm, which runs with
# ignore-scripts=true here, so the postinstall that repoints ~/.grok/bin/grok at
# the new version is skipped and every launch keeps running the old binary.
set -euo pipefail

grok="$(command -v grok)" || {
  echo "grok: not found on PATH" >&2
  exit 127
}

pkg_dir="$(dirname "$(dirname "$(realpath "$grok")")")"
if [ -f "$pkg_dir/package.json" ] && [ -f "$pkg_dir/bin/postinstall.js" ]; then
  version="$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$pkg_dir/package.json" | head -n 1)"
  if [ -n "$version" ] &&
    [ "$(readlink "${GROK_HOME:-$HOME/.grok}/bin/grok" 2>/dev/null)" != "grok-${version}" ]; then
    # stdout carries the ACP stream and `--version`, so keep postinstall off it.
    (cd "$pkg_dir" && node bin/postinstall.js) >&2 ||
      echo "grok: postinstall failed for ${version}" >&2
  fi
fi

exec "$grok" "$@"
