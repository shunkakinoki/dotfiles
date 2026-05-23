#!/usr/bin/env bash
# Cursor on macOS launches GUI apps with a minimal PATH that excludes
# ~/.cargo/bin, ~/.nix-profile/bin, /opt/homebrew/bin, etc.
# This wrapper exports a full PATH then execs the given command.
# Usage (in hooks.json):
#   {"command": "$HOME/.cursor/hooks/with-env.sh /path/to/hook.sh"}
export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
exec "$@"
