#!/usr/bin/env bash
# Copy managed Grok config and install the shared-security-hook plugin.
# Grok performs atomic writes to config.toml that break symlinks, so force-copy.
# Grok loads Claude Code plugins from ~/.grok/plugins/; this installs one that wires the
# shared security hooks (Grok has no user-scoped ~/.grok/hooks/ directory).
# Usage: activate.sh <config_toml> <plugin_dir>
set -euo pipefail
CONFIG_TOML="$1"
PLUGIN_DIR="$2"

mkdir -p ~/.grok/plugins
cp -f "$CONFIG_TOML" ~/.grok/config.toml
chmod 600 ~/.grok/config.toml

# Refresh the managed plugin from the (read-only) Nix store copy.
# rm first so cp recreates the dir instead of nesting into an existing one.
rm -rf ~/.grok/plugins/dotfiles-security
cp -fR "$PLUGIN_DIR" ~/.grok/plugins/dotfiles-security
chmod -R u+w ~/.grok/plugins/dotfiles-security
