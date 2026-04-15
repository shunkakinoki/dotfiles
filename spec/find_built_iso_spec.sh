#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/find-built-iso.sh'
SCRIPT="$PWD/scripts/find-built-iso.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'ISO discovery'
setup_iso_fixture() {
  local temp_dir="$1"
  mkdir -p "$temp_dir/out/iso"
  : >"$temp_dir/out/iso/test.iso"
}

It 'finds an ISO beneath a symlinked result directory'
temp_dir="$(mktemp -d)"
setup_iso_fixture "$temp_dir"
ln -s "$temp_dir/out" "$temp_dir/result"

When run bash "$SCRIPT" "$temp_dir/result"
The status should be success
The output should equal "$temp_dir/result/iso/test.iso"

rm -rf "$temp_dir"
End

It 'returns a direct ISO file path'
temp_dir="$(mktemp -d)"
: >"$temp_dir/direct.iso"

When run bash "$SCRIPT" "$temp_dir/direct.iso"
The status should be success
The output should equal "$temp_dir/direct.iso"

rm -rf "$temp_dir"
End

It 'returns the resolved ISO file for a symlinked result file'
temp_dir="$(mktemp -d)"
expected_path="$(cd "$temp_dir" && pwd -P)/direct.iso"
: >"$temp_dir/direct.iso"
ln -s "$temp_dir/direct.iso" "$temp_dir/result"

When run bash "$SCRIPT" "$temp_dir/result"
The status should be success
The output should equal "$expected_path"

rm -rf "$temp_dir"
End

It 'fails when no ISO exists'
temp_dir="$(mktemp -d)"
mkdir -p "$temp_dir/out"
ln -s "$temp_dir/out" "$temp_dir/result"

When run bash "$SCRIPT" "$temp_dir/result"
The status should not be success

rm -rf "$temp_dir"
End
End

End
