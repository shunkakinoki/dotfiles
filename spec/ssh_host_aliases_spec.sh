#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'SSH host command generation'
setup() {
  mock_bin_setup ssh tailscale
  nix-instantiate --eval --strict --json --expr '
    import ./home-manager/programs/ssh/host-aliases.nix {
      "beskar" = {};
      "new-host second-host" = {};
      "github.com" = {};
      "*" = {};
      "*.example" = {};
      "!excluded" = {};
      "bad?host" = {};
      "[ab]host" = {};
      "internal-label".data.header = "Host actual-host";
      "match-rule".data.header = "Match user ubuntu";
    }
  ' >"$MOCK_BIN/aliases.json"
  jq -r 'to_entries[] | "alias \(.key)=\(.value | @sh)"' "$MOCK_BIN/aliases.json" >"$MOCK_BIN/aliases.sh"
  cat >"$MOCK_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'SSH_ARG=%s\n' "$@"
exit "${MOCK_SSH_RESULT:-0}"
EOF
  cat >"$MOCK_BIN/tailscale" <<'EOF'
#!/usr/bin/env bash
printf 'TAILSCALE_ARG=%s\n' "$@"
EOF
}
cleanup() { mock_bin_cleanup; }
Before setup
After cleanup

It 'generates commands for concrete names including new and grouped SSH aliases'
When run jq -c 'keys' "$MOCK_BIN/aliases.json"
The output should eq '["actual-host","beskar","github.com","new-host","second-host"]'
End

It 'connects to the alias and preserves arguments with spaces in Fish'
When run fish --no-config -c 'source "$MOCK_BIN/aliases.sh"; beskar printf "%s" "hello world"'
The status should be success
The output should eq 'SSH_ARG=beskar
SSH_ARG=printf
SSH_ARG=%s
SSH_ARG=hello world'
End

It 'preserves SSH failures in Fish'
When run env MOCK_SSH_RESULT=37 fish --no-config -c 'source "$MOCK_BIN/aliases.sh"; beskar'
The status should eq 37
The output should eq 'SSH_ARG=beskar'
End

It 'forwards remote command arguments through the existing Kyber shortcut'
When run fish --no-config -c 'source home-manager/programs/fish/functions/_kyber_function.fish; _kyber_function echo "hello world"'
The status should be success
The output should eq 'SSH_ARG=kyber
SSH_ARG=echo
SSH_ARG=hello world'
End

It 'preserves the existing Matic Tailscale shortcut and its arguments'
When run fish --no-config -c 'source home-manager/programs/fish/functions/_matic_function.fish; _matic_function echo "hello world"'
The status should be success
The output should eq 'TAILSCALE_ARG=ssh
TAILSCALE_ARG=shunkakinoki@matic
TAILSCALE_ARG=echo
TAILSCALE_ARG=hello world'
End

It 'works in Bash with the same generated aliases'
When run bash --noprofile --norc -c 'shopt -s expand_aliases; source "$MOCK_BIN/aliases.sh"; eval "second-host uptime"'
The status should be success
The output should eq 'SSH_ARG=second-host
SSH_ARG=uptime'
End

It 'works in Zsh with the same generated aliases'
When run zsh -df -c 'source "$MOCK_BIN/aliases.sh"; eval "new-host uptime"'
The status should be success
The output should eq 'SSH_ARG=new-host
SSH_ARG=uptime'
End
End
