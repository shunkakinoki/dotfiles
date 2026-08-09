#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'pre-linkGeneration cleanup scripts'
CASS="$PWD/home-manager/programs/cass/activate-cleanup-sources.sh"
HERMES="$PWD/home-manager/services/hermes/activate-cleanup-units.sh"

setup() {
  WORK="$(mktemp -d)"
}

cleanup() {
  rm -rf "$WORK"
}

Before 'setup'
After 'cleanup'

Describe 'cass sources cleanup'
It 'removes a hydrated sources.toml'
When run bash -c "touch '$WORK/sources.toml'; bash '$CASS' '$WORK/sources.toml'; test -e '$WORK/sources.toml' && echo present || echo removed"
The output should eq 'removed'
End

It 'succeeds when the file is absent'
When run bash "$CASS" "$WORK/missing.toml"
The status should be success
End

It 'requires the path argument'
When run bash "$CASS"
The status should be failure
The stderr should include 'sources.toml path required'
End
End

Describe 'hermes unit cleanup'
It 'removes a writable unit copy'
When run bash -c "mkdir -p '$WORK/u'; touch '$WORK/u/hermes-gateway.service'; bash '$HERMES' '$WORK/u' hermes-gateway.service; test -e '$WORK/u/hermes-gateway.service' && echo present || echo removed"
The output should eq 'removed'
End

# A symlink is already store-managed; deleting it would undo linkGeneration's
# own work, so it must survive.
It 'leaves a store symlink alone'
When run bash -c "mkdir -p '$WORK/u'; touch '$WORK/target'; ln -s '$WORK/target' '$WORK/u/hermes-dashboard.service'; bash '$HERMES' '$WORK/u' hermes-dashboard.service; test -L '$WORK/u/hermes-dashboard.service' && echo present || echo removed"
The output should eq 'present'
End

It 'handles several units in one call'
When run bash -c "mkdir -p '$WORK/u'; touch '$WORK/u/a.service' '$WORK/u/b.service'; bash '$HERMES' '$WORK/u' a.service b.service missing.service; ls '$WORK/u' | wc -l | tr -d ' '"
The output should eq '0'
End

It 'requires the unit directory argument'
When run bash "$HERMES"
The status should be failure
The stderr should include 'unit directory required'
End
End

Describe 'nix wiring'
It 'cass references the external script'
When run bash -c "cat '$PWD/home-manager/programs/cass/default.nix'"
The output should include 'activate-cleanup-sources.sh'
End

It 'hermes references the external script'
When run bash -c "cat '$PWD/home-manager/services/hermes/default.nix'"
The output should include 'activate-cleanup-units.sh'
End

# The repo forbids inline shell in Nix; `make shell-inline-check` enforces it.
It 'neither nix file inlines a bash -c block'
When run bash -c "cat '$PWD/home-manager/programs/cass/default.nix' '$PWD/home-manager/services/hermes/default.nix'"
The output should not include 'bin/bash -c'
End

# Home Manager aborts in checkLinkTargets ("would be clobbered"), which runs
# before linkGeneration. Anchoring the cleanup to linkGeneration is too late --
# it only appeared to work when sibling DAG ordering happened to be favourable.
It 'runs the cass cleanup before checkLinkTargets'
When run bash -c "grep -A1 'cassSourcesCleanup' '$PWD/home-manager/programs/cass/default.nix' | head -1"
The output should include 'entryBefore [ "checkLinkTargets" ]'
End

It 'runs the hermes cleanup before checkLinkTargets'
When run bash -c "grep -A1 'hermesCleanup' '$PWD/home-manager/services/hermes/default.nix' | head -1"
The output should include 'entryBefore [ "checkLinkTargets" ]'
End
End

End
