#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'config/k3s/activate.sh'
SCRIPT="$PWD/config/k3s/activate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'sudo detection'
It 'checks for sudo command'
When run bash -c "grep 'command -v sudo' '$SCRIPT'"
The output should include 'command -v sudo'
End

It 'checks NixOS wrapper path'
When run bash -c "grep '/run/wrappers/bin/sudo' '$SCRIPT'"
The output should include '/run/wrappers/bin/sudo'
End

It 'warns when sudo not found'
When run bash -c "grep 'sudo not found' '$SCRIPT'"
The output should include 'sudo not found'
End
End

Describe 'config sync'
It 'creates /etc/rancher/k3s directory'
When run bash -c "grep '/etc/rancher/k3s' '$SCRIPT'"
The output should include '/etc/rancher/k3s'
End

It 'copies config.yaml'
When run bash -c "grep 'config.yaml' '$SCRIPT'"
The output should include 'config.yaml'
End

It 'skips if config file missing'
When run bash -c "grep -A 1 '! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'authorized_keys management'
It 'declares a placeholder for galactica authorized key'
When run bash -c "grep 'GALACTICA_AUTHORIZED_KEY' '$SCRIPT'"
The output should include '@galacticaAuthorizedKey@'
End

It 'defines an idempotent ensure_authorized_key helper'
When run bash -c "grep 'ensure_authorized_key' '$SCRIPT'"
The output should include 'ensure_authorized_key'
End

It 'guards against unsubstituted placeholder'
When run bash -c "grep -E '\\\"@\\\"\\*\\\"@\\\"' '$SCRIPT'"
The output should include '@'
End

It 'uses fixed-string match against authorized_keys'
When run bash -c "grep 'grep -qxF' '$SCRIPT'"
The output should include 'grep -qxF'
End

ensure_authorized_key_function() {
  cat <<'BASH'
ensure_authorized_key() {
local key="$1"
local ssh_dir="$HOME/.ssh"
local auth_file="$ssh_dir/authorized_keys"
if [ -z "$key" ] || [[ "$key" == "@"*"@" ]]; then
return 0
fi
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$auth_file"
chmod 600 "$auth_file"
if grep -qxF "$key" "$auth_file"; then
return 0
fi
if [ -s "$auth_file" ] && [ "$(tail -c1 "$auth_file" | wc -l)" -eq 0 ]; then
printf '\n' >>"$auth_file"
fi
printf '%s\n' "$key" >>"$auth_file"
}
BASH
}

It 'appends the key when authorized_keys does not exist'
When run bash -c '
tmp=$(mktemp -d)
HOME="$tmp"
'"$(ensure_authorized_key_function)"'
ensure_authorized_key "ssh-ed25519 AAAATEST test@example"
grep -qxF "ssh-ed25519 AAAATEST test@example" "$tmp/.ssh/authorized_keys"
'
The status should be success
End

It 'is idempotent on repeated runs'
When run bash -c '
tmp=$(mktemp -d)
HOME="$tmp"
'"$(ensure_authorized_key_function)"'
ensure_authorized_key "ssh-ed25519 AAAATEST test@example"
ensure_authorized_key "ssh-ed25519 AAAATEST test@example"
ensure_authorized_key "ssh-ed25519 AAAATEST test@example"
count=$(grep -cxF "ssh-ed25519 AAAATEST test@example" "$tmp/.ssh/authorized_keys")
test "$count" = "1"
'
The status should be success
End

It 'preserves existing keys when appending'
When run bash -c '
tmp=$(mktemp -d)
HOME="$tmp"
mkdir -p "$tmp/.ssh"
printf "ssh-ed25519 AAAAEXISTING old@example\n" >"$tmp/.ssh/authorized_keys"
'"$(ensure_authorized_key_function)"'
ensure_authorized_key "ssh-ed25519 AAAANEW new@example"
grep -qxF "ssh-ed25519 AAAAEXISTING old@example" "$tmp/.ssh/authorized_keys" &&
grep -qxF "ssh-ed25519 AAAANEW new@example" "$tmp/.ssh/authorized_keys"
'
The status should be success
End

It 'no-ops when given an unsubstituted placeholder'
When run bash -c '
tmp=$(mktemp -d)
HOME="$tmp"
'"$(ensure_authorized_key_function)"'
ensure_authorized_key "@galacticaAuthorizedKey@"
test ! -e "$tmp/.ssh/authorized_keys"
'
The status should be success
End
End
End
