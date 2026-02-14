# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Fix PR #799 GitHub Actions Failures

## Context

PR #799 (`feat/hyprland-keybinds-and-shell-compat`) adds `/bin/{bash,fish,zsh}` symlinks via a new home-manager activation module. The activation script hardcodes `/run/wrappers/bin/sudo`, which only exists on NixOS. This breaks both the **E2E Ubuntu** and **Docker build** CI jobs — they run on standard Ubuntu where sudo is at `/usr/bin/sudo`.

## Root Cause

**Single root cause for all 3 failing jobs:**

```
Act...

### Prompt 2

is make format passing?

### Prompt 3

still failing why

