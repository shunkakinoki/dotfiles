#!/usr/bin/env bash

set -euo pipefail

# Export HOST for Nix impure builds (used by lib/host.nix to detect kyber/galactica)
# This is needed because systemd doesn't inherit the shell environment
export HOST="${HOST:-$(/usr/bin/hostname 2>/dev/null || hostname 2>/dev/null || echo '')}"

bash "$HOME/dotfiles/home-manager/activation/check-host-identity.sh" "$HOST"

cd ~/dotfiles

# An activation that fails partway leaves newly added timers enabled but never
# started, so their services stop running until a later switch succeeds. This
# runs on every exit, including no-change runs, so a failed start is retried.
start_enabled_timers() {
  local units unit
  command -v systemctl >/dev/null 2>&1 || return 0
  if ! units=$(systemctl --user list-unit-files --type=timer --state=enabled --no-legend 2>&1); then
    echo "WARNING: Could not list enabled timers: $units" >&2
    return 0
  fi
  while read -r unit _; do
    [ -n "$unit" ] || continue
    systemctl --user start -- "$unit" || echo "WARNING: Could not start $unit" >&2
  done <<<"$units"
}
trap start_enabled_timers EXIT

if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "ERROR: Deployment checkout is not main; preserve its work before restoring automatic updates." >&2
  exit 1
fi

# The Moshi adapters are moshi-hook output that hosts never edit by hand. A
# regeneration on a host captures its own moshi-hook version and binary path,
# and the dirty-checkout guard below would then block every future update.
# Restore only when nothing else is dirty, so a blocked run leaves every edit.
if [ -n "$(git ls-files generated/hooks/moshi)" ] &&
  ! git diff --quiet HEAD -- generated/hooks/moshi &&
  git diff --quiet HEAD -- . ':(exclude)generated/hooks/moshi'; then
  echo "Restoring host-regenerated Moshi adapters under generated/hooks/moshi."
  git restore --source=HEAD --staged --worktree -- generated/hooks/moshi
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Deployment checkout has uncommitted changes; leaving them intact." >&2
  exit 1
fi

# Upstream images move independently of this repository, so check them before
# the no-changes exit. Swapping the CLIProxyAPI container drops every fleet
# model request for its restart, so only the 18:00 UTC run swaps images. A
# systemd user session on a non-NixOS host can lack the docker group, which the
# service's own start wrapper also handles.
if [ "$HOST" = "kyber" ] && [ "$(date -u +%H)" = 18 ]; then
  if docker info >/dev/null 2>&1; then
    make cliproxy-update || echo "⚠️  cliproxy-update failed" >&2
  elif [ -x /usr/bin/sg ]; then
    /usr/bin/sg docker -c "make cliproxy-update" || echo "⚠️  cliproxy-update failed" >&2
  else
    echo "⚠️  Skipping cliproxy-update (docker not accessible)" >&2
  fi
fi

# The marker records the last commit whose install succeeded. HEAD cannot serve
# as that record, not even as a fallback: the fast-forward below moves HEAD before
# installation runs, so a failed install would be skipped as "no changes" forever.
INSTALLED_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-updater/installed-commit"
CURRENT_COMMIT=$(git rev-parse HEAD)
INSTALLED_COMMIT=$(cat "$INSTALLED_MARKER" 2>/dev/null || true)

# Fetch latest changes
git fetch origin main

# Get the latest remote commit
REMOTE_COMMIT=$(git rev-parse origin/main)

if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "ERROR: Local main has unpublished or divergent commits; refusing to replace them." >&2
  exit 1
fi

git merge --ff-only origin/main

# Check if there are any changes
if [ "$INSTALLED_COMMIT" = "$REMOTE_COMMIT" ]; then
  echo "No changes detected (current: ${CURRENT_COMMIT:0:8}). Skipping build and switch."
  exit 0
fi

echo "Changes detected: ${CURRENT_COMMIT:0:8} -> ${REMOTE_COMMIT:0:8} (installed: ${INSTALLED_COMMIT:0:8})"

# A local Home Manager activation can add substantial space to the Nix store
# while compiling large Rust packages. Kamino executor admission requires 40
# GiB free plus 2 GiB per new lane. Reserve 64 GiB before an automated local
# build, based on the 42 GiB one-lane floor and roughly 20 GB of K4 store growth
# observed during its updater run, plus margin. That growth is not a per-build
# maximum. An already installed activation closure can still be applied with
# local Nix builds disabled.
MIN_FREE_FOR_LOCAL_BUILD_KIB=$((64 * 1024 * 1024))
MIN_EXECUTOR_RESERVE_KIB=$((42 * 1024 * 1024))
if [ "${AUTOMATED_UPDATE:-}" = true ] && [[ "$HOST" =~ ^kamino[0-9]+$ ]]; then
  AVAILABLE_KIB=$(df -Pk / 2>/dev/null | awk 'NR == 2 { print $4 }')
  if [[ ! "$AVAILABLE_KIB" =~ ^[0-9]+$ ]]; then
    echo "Deferring automated Kamino install: root free space could not be read; installed marker is unchanged." >&2
    exit 0
  fi

  if [ "$AVAILABLE_KIB" -lt "$MIN_EXECUTOR_RESERVE_KIB" ]; then
    AVAILABLE_GIB=$((AVAILABLE_KIB / 1024 / 1024))
    echo "Deferring automated Kamino install: ${AVAILABLE_GIB} GiB free is below the 42 GiB executor reserve; installed marker is unchanged." >&2
    exit 0
  fi

  if [ "$AVAILABLE_KIB" -lt "$MIN_FREE_FOR_LOCAL_BUILD_KIB" ]; then
    ACTIVATION=".#homeConfigurations.${HOST}.activationPackage"
    if ! nix --offline --extra-experimental-features 'nix-command flakes' \
      path-info --recursive --impure --no-update-lock-file "$ACTIVATION" >/dev/null 2>&1; then
      AVAILABLE_GIB=$((AVAILABLE_KIB / 1024 / 1024))
      echo "Deferring automated Kamino install: ${AVAILABLE_GIB} GiB free and the activation closure is not fully in the local Nix store. Free more disk or run an operator-managed build; installed marker is unchanged." >&2
      exit 0
    fi

    # The entire activation closure is already in the local store, so applying
    # it needs no compilation or cache download. Keep any other Nix operation
    # in this automated install from starting a local build at low headroom.
    NIX_CONFIG="${NIX_CONFIG:-}"
    if [ -n "$NIX_CONFIG" ]; then
      NIX_CONFIG+=$'\n'
    fi
    NIX_CONFIG+="max-jobs = 0"
    export NIX_CONFIG
    echo "Applying the store-resident Kamino activation with local Nix builds disabled (${AVAILABLE_KIB} KiB free)."
  fi
fi

# Bootstrap's install.sh fetches again; install the revision already checked above.
make install

# `make install` never touches agent rules, skills, or MCP configs, so without
# this every host keeps the dotagents output it was provisioned with.
make dotagents-switch-sync

if [ "$(git rev-parse HEAD)" != "$REMOTE_COMMIT" ]; then
  echo "ERROR: Checkout changed during installation; refusing to mark it installed." >&2
  exit 1
fi

mkdir -p "$(dirname "$INSTALLED_MARKER")"
printf '%s\n' "$REMOTE_COMMIT" >"$INSTALLED_MARKER"
