#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/opencode/opencode-lane.sh'
SCRIPT="$PWD/config/opencode/opencode-lane.sh"

setup() {
  FAKE_BIN=$(mktemp -d)
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@"' >"$FAKE_BIN/opencode"
  chmod +x "$FAKE_BIN/opencode"
}

cleanup() {
  rm -rf "$FAKE_BIN"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'seats the model and forwards the remaining arguments'
When run env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --model openfactor/deepseek-v4.1-flash --auto
The status should be success
The output should eq "--model
openfactor/deepseek-v4.1-flash
--auto"
End

It 'rejects a launch without a model'
When run env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --auto
The status should eq 64
The stderr should include 'usage: opencode-lane --model'
End

It 'rejects an empty model'
When run env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --model ''
The status should eq 64
The stderr should include 'usage: opencode-lane --model'
End
End
