#!/usr/bin/env bash
# @git@, @mirrorDir@, @remoteUrl@, @userEmail@ are substituted by pkgs.replaceVars.
# `bd` is resolved via PATH (user-installed in ~/.local/bin).
#
# Triggered by launchd/systemd when the dolt manifest changes. Exports the
# full beads_global database to JSONL and pushes it to refs/heads/main of
# the beads GitHub repo so the data renders in the GitHub UI. Dolt's native
# git+https push only writes refs/dolt/data, which GitHub does not render.

set -euo pipefail

MIRROR="@mirrorDir@"
REMOTE="@remoteUrl@"
GIT="@git@/bin/git"
USER_EMAIL="@userEmail@"

export PATH="/etc/profiles/per-user/${USER}/bin:${HOME}/.nix-profile/bin:${HOME}/.local/bin:/run/current-system/sw/bin:/usr/bin:/bin"

if ! command -v bd >/dev/null 2>&1; then
  echo "bd not on PATH; cannot export beads database" >&2
  exit 1
fi

mkdir -p "$(dirname "${MIRROR}")"

if [ ! -d "${MIRROR}/.git" ]; then
  "${GIT}" clone --depth 1 "${REMOTE}" "${MIRROR}"
fi

cd "${MIRROR}"
"${GIT}" fetch --depth 1 origin main
"${GIT}" reset --hard origin/main

bd --global export --all >issues.jsonl.tmp
mv issues.jsonl.tmp issues.jsonl

if "${GIT}" diff --quiet -- issues.jsonl; then
  echo "no JSONL changes; skipping commit"
  exit 0
fi

"${GIT}" add issues.jsonl
"${GIT}" \
  -c "user.name=beads-backup" \
  -c "user.email=${USER_EMAIL}" \
  commit -m "chore(beads): refresh issues.jsonl snapshot"
"${GIT}" push origin main
