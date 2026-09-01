#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/moshi-hook'
MODULE="$PWD/home-manager/services/moshi-hook/default.nix"
PI_HOOK="$PWD/generated/hooks/moshi/pi/moshi-hooks.ts"
OPENCODE_HOOK="$PWD/generated/hooks/moshi/opencode/moshi-hooks.ts"
OMP_HOOK="$PWD/generated/hooks/moshi/omp/moshi-hooks.ts"

It 'is imported by the shared services module'
When run grep -F './moshi-hook' "$PWD/home-manager/services/default.nix"
The output should include './moshi-hook'
End

It 'exposes moshi-hook at ~/.local/bin for hardcoded plugin spawn paths'
When run cat "$MODULE"
The output should include '.local/bin/moshi-hook'
The output should include 'force = true'
End

It 'uses Homebrew moshi-hook on Darwin'
When run cat "$MODULE"
The output should include 'pkgs.stdenv.hostPlatform.isDarwin'
The output should include '/opt/homebrew/bin/moshi-hook'
End

It 'uses the Nix overlay package on Linux'
When run cat "$MODULE"
The output should include 'pkgs.moshi-hook'
End

It 'keeps Pi OpenCode and OMP adapters portable across installations'
When run bash -c "grep -c 'const helperBinary = \"moshi-hook\";' '$PI_HOOK' '$OPENCODE_HOOK' '$OMP_HOOK'"
The output should include "$PI_HOOK:1"
The output should include "$OPENCODE_HOOK:1"
The output should include "$OMP_HOOK:1"
End

It 'swallows socket errors so a missing moshi-hook daemon cannot crash Pi'
When run grep -n 'sock.on("error"' "$PI_HOOK"
The output should include 'sock.on("error"'
End

It 'does not embed machine-specific helper paths in generated adapters'
When run bash -c "! grep -Eq '(/opt/homebrew/bin|process\.env\.HOME.*local/bin)' '$PI_HOOK' '$OPENCODE_HOOK' '$OMP_HOOK'"
The status should be success
End
End
