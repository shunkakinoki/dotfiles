#!/bin/sh

set -e

repo_dir=${1:-.}
if [ "$#" -gt 0 ]; then
  shift
fi

nix_github_token=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
  nix_github_token="$GITHUB_TOKEN"
elif [ -n "${GITHUB_TOKEN_FILE:-}" ] && [ -r "$GITHUB_TOKEN_FILE" ]; then
  nix_github_token=$(cat "$GITHUB_TOKEN_FILE")
fi

if [ -n "$nix_github_token" ]; then
  if [ -n "${NIX_CONFIG:-}" ]; then
    NIX_CONFIG="${NIX_CONFIG}
access-tokens = github.com=$nix_github_token"
  else
    NIX_CONFIG="access-tokens = github.com=$nix_github_token"
  fi
  export NIX_CONFIG
fi
unset nix_github_token

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix unavailable; skipping cache warmup"
  exit 0
fi

nix flake metadata "$repo_dir" "$@" --no-write-lock-file >/dev/null
