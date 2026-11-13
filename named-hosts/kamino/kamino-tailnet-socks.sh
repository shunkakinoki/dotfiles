#!/usr/bin/env bash
# Bound only to the tailnet address: the proxy has no auth, so the tailnet ACL
# is what limits it to the cliproxy pod. @tailscale@ and @microsocks@ are
# substituted by pkgs.replaceVars.
set -eu
ip=$(@tailscale@ ip -4)
exec @microsocks@ -i "$ip" -p 1080
