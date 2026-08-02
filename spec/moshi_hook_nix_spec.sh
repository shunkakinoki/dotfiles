#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'declarative moshi-hook ownership'

It 'has no imperative moshi-hook generator'
The path "scripts/update-moshi-hooks.sh" should not be exist
End

It 'has no imperative moshi-hook update target'
When run grep -F 'moshi-update' Makefile
The status should be failure
End

It 'renders every agent hook through pkgs.replaceVars'
When run bash -c '
  for module in \
    config/claude/default.nix \
    config/codex/default.nix \
    config/cursor/default.nix \
    config/gemini/default.nix \
    config/grok/default.nix \
    config/omp/default.nix \
    config/opencode/default.nix \
    config/pi/default.nix
  do
    grep -Fq "pkgs.replaceVars" "$module" || exit 1
    grep -Fq '\''moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";'\'' "$module" || exit 1
  done
'
The status should be success
End

It 'keeps templates independent of a machine-local binary path'
When run bash -c '
  grep -RInE "(/\.local/bin|/opt/homebrew/bin)/moshi-hook" \
    config/claude/settings.json \
    config/codex/hooks.json \
    config/cursor/hooks.json \
    config/gemini/settings.json \
    config/grok/plugin/hooks/hooks.json \
    config/omp/moshi-hooks.ts \
    config/opencode/moshi-hooks.ts \
    config/pi/moshi-hooks.ts
'
The status should be failure
End

It 'uses the Nix substitution placeholder in every hook template'
When run bash -c '
  for template in \
    config/claude/settings.json \
    config/codex/hooks.json \
    config/cursor/hooks.json \
    config/gemini/settings.json \
    config/grok/plugin/hooks/hooks.json \
    config/omp/moshi-hooks.ts \
    config/opencode/moshi-hooks.ts \
    config/pi/moshi-hooks.ts
  do
    grep -Fq "@moshiHook@" "$template" || exit 1
  done
'
The status should be success
End

It 'deploys OMP hooks from the supported extensions path'
When run grep -F '.omp/agent/extensions/moshi-hooks.ts' config/omp/default.nix
The output should include '.omp/agent/extensions/moshi-hooks.ts'
The status should be success
End

It 'does not deploy the retired OMP post-hook path'
When run grep -RFl '.omp/agent/hooks/post/moshi-hooks.ts' config home-manager
The status should be failure
End

End
