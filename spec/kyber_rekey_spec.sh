#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'kyber/rekey-galactica.sh'
SCRIPT="$PWD/named-hosts/kyber/rekey-galactica.sh"

Describe 'script structure'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'exits on error (set -e)'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'Tailscale SSH integration'
It 'uses tailscale ssh command'
When run bash -c "grep 'tailscale ssh' '$SCRIPT'"
The output should include 'tailscale ssh'
End

It 'connects to galactica host'
When run bash -c "grep 'galactica' '$SCRIPT'"
The output should include 'galactica'
End

It 'runs make rekey-galactica remotely'
When run bash -c "grep 'make rekey-galactica' '$SCRIPT'"
The output should include 'make rekey-galactica'
End
End

Describe 'failure handling'
It 'shows error message on SSH failure'
When run bash -c "grep 'Tailscale SSH failed' '$SCRIPT'"
The output should include 'Tailscale SSH failed'
End

It 'provides manual instructions'
When run bash -c "grep -A 5 'run this manually' '$SCRIPT'"
The output should include 'cd ~/dotfiles'
End

It 'exits with failure code on SSH error'
When run bash -c "grep 'exit 1' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'success behavior'
It 'pulls changes after rekey'
When run bash -c "grep 'git pull' '$SCRIPT'"
The output should include 'git pull'
End

It 'shows completion message'
When run bash -c "grep 'Done' '$SCRIPT'"
The output should include 'Done'
End

It 'suggests make switch'
When run bash -c "grep 'make switch' '$SCRIPT'"
The output should include 'make switch'
End
End

Describe 'output messages'
It 'shows rekey message'
When run bash -c "grep 'Rekeying galactica' '$SCRIPT'"
The output should include 'Rekeying galactica'
End

It 'explains what the script does'
When run bash -c "grep 'This will:' '$SCRIPT'"
The output should include 'This will:'
End
End

End
