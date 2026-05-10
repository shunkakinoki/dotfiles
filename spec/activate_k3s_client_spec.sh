#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/k3s/activate-client.sh'
SCRIPT="$PWD/config/k3s/activate-client.sh"

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

Describe 'tailscale check'
It 'checks if tailscale is available'
When run bash -c "grep 'command -v tailscale' '$SCRIPT'"
The output should include 'command -v tailscale'
End

It 'checks tailscale status before proceeding'
When run bash -c "grep 'tailscale status' '$SCRIPT'"
The output should include 'tailscale status'
End
End

Describe 'kubeconfig fetch'
It 'uses scp to fetch kubeconfig'
When run bash -c "grep 'scp' '$SCRIPT'"
The output should include 'scp'
End

It 'sources the tailscale DNS from a Nix-templated placeholder'
When run bash -c "grep '^KYBER_HOST=' '$SCRIPT'"
The output should include '@kyberHost@'
End

It 'sources the remote ssh user from a Nix-templated placeholder'
When run bash -c "grep '^KYBER_USER=' '$SCRIPT'"
The output should include '@kyberUser@'
End

It 'composes REMOTE_HOST from the templated user and host'
When run bash -c "grep '^REMOTE_HOST=' '$SCRIPT'"
The output should include '${KYBER_USER}@${KYBER_HOST}'
End

It 'sets restrictive permissions on kubeconfig'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'chmod 600'
End
End

Describe 'failure visibility'
It 'does not silently discard scp stderr'
When run bash -c "grep 'scp ' '$SCRIPT'"
The output should not include '2>/dev/null'
End

It 'logs scp failures to stderr'
When run bash -c "grep 'failed to fetch kubeconfig' '$SCRIPT'"
The output should include 'failed to fetch kubeconfig'
End
End

Describe 'server URL rewrite'
It 'rewrites the loopback server URL to the Nix-managed cluster URL'
When run bash -c "grep 'sed -i.bak' '$SCRIPT'"
The output should include 'https://127.0.0.1:6443'
The output should include 'KYBER_API_URL'
End

It 'sources the cluster URL from a Nix-templated placeholder'
When run bash -c "grep '^KYBER_API_URL=' '$SCRIPT'"
The output should include '@kyberApiUrl@'
End

It 'removes the sed backup file'
When run bash -c "grep 'rm -f .*\.bak' '$SCRIPT'"
The output should include '.bak'
End

rewrite_kubeconfig_function() {
cat <<'BASH'
rewrite_kubeconfig() {
local file="$1"
local url="$2"
sed -i.bak "s|https://127.0.0.1:6443|${url}|g" "$file"
rm -f "$file.bak"
}
BASH
}

It 'rewrites a sample kubeconfig server URL in place'
When run bash -c '
tmp=$(mktemp -d)
cfg="$tmp/config"
printf "clusters:\n- cluster:\n    server: https://127.0.0.1:6443\n  name: default\n" >"$cfg"
'"$(rewrite_kubeconfig_function)"'
rewrite_kubeconfig "$cfg" "https://kyber.tail950b36.ts.net:6443"
grep -q "server: https://kyber.tail950b36.ts.net:6443" "$cfg" &&
  ! grep -q "127.0.0.1" "$cfg" &&
  test ! -e "$cfg.bak"
'
The status should be success
End
End
End
