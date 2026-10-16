#!/usr/bin/env bash
# Remove gh credential sections from ~/.gitconfig that pin a /nix/store gh path.
# A hand-run `gh auth setup-git` writes an empty `helper =` reset plus a store
# path that Nix GC later deletes; the reset also masks the Home Manager helper.
# Also remove a generic [credential] section whose only key is an empty helper.
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

# ~/.gitconfig is read after ~/.config/git/config, so a lone generic
# `[credential] helper =` reset clears the Home Manager gh helper.
GENERIC_KEYS=$("$GIT_BIN" config --file "$GITCONFIG" --name-only --get-regexp '^credential\.[^.]+$' || true)
if [[ $GENERIC_KEYS == credential.helper && -z $("$GIT_BIN" config --file "$GITCONFIG" --get credential.helper) ]]; then
  "$GIT_BIN" config --file "$GITCONFIG" --remove-section credential
  echo "Removed empty credential helper reset from $GITCONFIG"
fi
