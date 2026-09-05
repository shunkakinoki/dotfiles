#!/usr/bin/env bash
# Remove hm-backup files from ~/.codex. Home Manager only manages files two
# levels deep there, and ~/.codex/worktrees holds full repository checkouts
# that would take a full sweep tens of minutes to walk.
find ~/.codex -maxdepth 2 -name "*.hm-backup*" -delete 2>/dev/null || true
