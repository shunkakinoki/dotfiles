#!/usr/bin/env bash

Describe 'Cross-platform llm-agents packages'

PACKAGES="$PWD/home-manager/packages/default.nix"
OVERLAY="$PWD/overlays/default.nix"

It 'uses the upstream Cursor Agent package'
When run grep -Fx '  pkgs.llm-agents.cursor-agent' "$PACKAGES"
The output should include '  pkgs.llm-agents.cursor-agent'
End

It 'installs OpenCode and Grok as npm globals so T3 Code can upgrade them'
When run bash -c "jq -e '.dependencies[\"@opencode/cli\"] and (.dependencies[\"opencode-ai\"] | not) and .dependencies[\"@xai-official/grok\"]' \"$PWD/package.json\" >/dev/null && ! grep -Eq '^  (pkgs\.llm-agents\.grok|opencode)\$' \"$PACKAGES\" && ! grep -Eq '^ +(opencode|linuxGrokOverrides|// linuxGrokOverrides)\$' \"$OVERLAY\""
The status should be success
End

It 'includes Muse Code in the shared package set'
When run grep -Fx '  pkgs.llm-agents.muse-code' "$PACKAGES"
The output should include '  pkgs.llm-agents.muse-code'
End

It 'does not retain the separate nixpkgs Cursor CLI'
When run grep -Fx '  cursor-cli' "$PACKAGES"
The status should not be success
End

End
