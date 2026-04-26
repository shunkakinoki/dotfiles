#!/usr/bin/env bash
# Smart wrapper that handles both NixOS and non-NixOS Linux.
# On NixOS: docker group is properly inherited, or use /run/wrappers/bin/sg.
# On non-NixOS: systemd user session may lack docker group, use /usr/bin/sg.
# @bash@, @start_script@, @docker@ are substituted by pkgs.replaceVars.
SCRIPT="@bash@/bin/bash @start_script@"

# Ensure docker group exists and user is a member (non-NixOS)
if ! getent group docker >/dev/null 2>&1; then
  sudo groupadd docker 2>/dev/null || true
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER" 2>/dev/null || true
fi

# Try docker directly first (works on NixOS or when user has docker group)
if @docker@/bin/docker info >/dev/null 2>&1; then
  exec $SCRIPT
fi

# Docker not accessible directly, try sg to switch group
if [ -x /run/wrappers/bin/sg ]; then
  exec /run/wrappers/bin/sg docker -c "$SCRIPT"
elif [ -x /usr/bin/sg ]; then
  exec /usr/bin/sg docker -c "$SCRIPT"
else
  echo "ERROR: Cannot access Docker. User not in docker group and no sg binary found." >&2
  exit 1
fi
