#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/opencode/opencode.sh'
SCRIPT="$PWD/config/opencode/opencode.sh"

setup() {
  FAKE_BUN=$(mktemp -d)
  mkdir -p "$FAKE_BUN/install/global/node_modules/@opencode/cli/bin"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "db=%s\n" "$OPENCODE_DB"' 'printf "%s\n" "$@"' \
    >"$FAKE_BUN/install/global/node_modules/@opencode/cli/bin/opencode.exe"
  chmod +x "$FAKE_BUN/install/global/node_modules/@opencode/cli/bin/opencode.exe"
}

cleanup() {
  rm -rf "$FAKE_BUN"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'runs the TUI standalone on the v2 database'
When run env BUN_INSTALL="$FAKE_BUN" bash "$SCRIPT" --auto
The status should be success
The output should eq "db=opencode-v2.db
--standalone
--auto"
End

It 'runs one-shot prompts standalone and keeps their model'
When run env BUN_INSTALL="$FAKE_BUN" bash "$SCRIPT" run --model shunkakinoki/free --format json hi
The status should be success
The output should eq "db=opencode-v2.db
run
--standalone
--model
shunkakinoki/free
--format
json
hi"
End

It 'passes subcommands through unchanged on the v2 database'
When run env BUN_INSTALL="$FAKE_BUN" bash "$SCRIPT" session list --format json
The status should be success
The output should eq "db=opencode-v2.db
session
list
--format
json"
End

It 'rejects a TUI model flag'
When run env BUN_INSTALL="$FAKE_BUN" bash "$SCRIPT" --model shunkakinoki/free --auto
The status should eq 64
The stderr should include 'OPENCODE_CONFIG_CONTENT'
End

It 'rejects an inline TUI model flag'
When run env BUN_INSTALL="$FAKE_BUN" bash "$SCRIPT" --auto --model=shunkakinoki/free
The status should eq 64
The stderr should include 'takes no --model'
End

It 'fails when the v2 package is missing'
When run env BUN_INSTALL="$FAKE_BUN/missing" bash "$SCRIPT" --auto
The status should eq 127
The stderr should include '@opencode/cli is not installed'
End
End
