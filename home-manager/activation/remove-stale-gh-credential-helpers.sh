#!/usr/bin/env bash
# Remove gh credential sections from ~/.gitconfig that pin a /nix/store gh path.
# A hand-run `gh auth setup-git` writes an empty `helper =` reset plus a store
# path that Nix GC later deletes; the reset also masks the Home Manager helper.
# Usage: remove-stale-gh-credential-helpers.sh <git_bin> <gitconfig>
set -euo pipefail
GIT_BIN="$1"
GITCONFIG="$2"

if [[ ! -f $GITCONFIG ]]; then
  exit 0
fi

for URL in https://github.com https://gist.github.com; do
  SECTION="credential.$URL"
  HELPERS=$("$GIT_BIN" config --file "$GITCONFIG" --get-all "$SECTION.helper" || true)
  if [[ $HELPERS == */nix/store/* ]]; then
    "$GIT_BIN" config --file "$GITCONFIG" --remove-section "$SECTION"
    echo "Removed stale $SECTION from $GITCONFIG"
  fi
done
