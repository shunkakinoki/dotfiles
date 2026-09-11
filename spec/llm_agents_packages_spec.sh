#!/usr/bin/env bash

Describe 'Cross-platform llm-agents packages'

PACKAGES="$PWD/home-manager/packages/default.nix"
OVERLAY="$PWD/overlays/default.nix"

It 'uses the upstream Cursor Agent package'
When run grep -Fx '  pkgs.llm-agents.cursor-agent' "$PACKAGES"
The output should include '  pkgs.llm-agents.cursor-agent'
End

It 'keeps Grok in the shared package set'
When run bash -c "line=\$(grep -nF 'pkgs.llm-agents.grok' \"$PACKAGES\" | cut -d: -f1); boundary=\$(grep -nF '++ lib.optionals stdenv.hostPlatform.isDarwin' \"$PACKAGES\" | cut -d: -f1); test -n \"\$line\" -a -n \"\$boundary\" -a \"\$line\" -lt \"\$boundary\""
The status should be success
End

It 'includes Muse Code in the shared package set'
When run grep -Fx '  pkgs.llm-agents.muse-code' "$PACKAGES"
The output should include '  pkgs.llm-agents.muse-code'
End

It 'guards the Linux-only Grok wrapBuddy override'
When run bash -c "grep -F 'linuxGrokOverrides' \"$OVERLAY\" >/dev/null && grep -F 'prev.stdenv.hostPlatform.isLinux' \"$OVERLAY\" >/dev/null"
The status should be success
End

It 'does not retain the separate nixpkgs Cursor CLI'
When run grep -Fx '  cursor-cli' "$PACKAGES"
The status should not be success
End

End
