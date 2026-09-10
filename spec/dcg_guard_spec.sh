#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'shared hooks/dcg-guard.sh'
SCRIPT="$PWD/config/shared/hooks/dcg-guard.sh"
BASH_BIN="$(command -v bash)"

setup() {
  TEMP_DIR="$(mktemp -d)"
  MOCK_BIN="$TEMP_DIR/bin"
  mkdir -p "$MOCK_BIN"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'blocks when dcg is missing'
When run env -i PATH="$MOCK_BIN" "$BASH_BIN" --noprofile --norc "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED by dcg-guard.sh: dcg is unavailable'
End

It 'blocks when dcg is present but not executable'
printf '%s\n' '#!/bin/sh' 'exit 0' >"$MOCK_BIN/dcg"
chmod 644 "$MOCK_BIN/dcg"
When run env -i PATH="$MOCK_BIN" "$BASH_BIN" --noprofile --norc "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED by dcg-guard.sh: dcg is unavailable'
End

It 'preserves successful dcg output and enables fail-closed parsing'
cat >"$MOCK_BIN/dcg" <<'SH'
#!/bin/sh
IFS= read -r input || true
printf 'fail_closed=%s input=%s\n' "${DCG_FAIL_CLOSED:-}" "$input"
SH
chmod 755 "$MOCK_BIN/dcg"
Data '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
When run env -i PATH="$MOCK_BIN:/usr/bin:/bin" "$BASH_BIN" --noprofile --norc "$SCRIPT"
The status should be success
The output should eq 'fail_closed=1 input={"tool_name":"Bash","tool_input":{"command":"git status"}}'
End

It 'preserves an intentional dcg block'
cat >"$MOCK_BIN/dcg" <<'SH'
#!/bin/sh
echo 'blocked by mock dcg' >&2
exit 2
SH
chmod 755 "$MOCK_BIN/dcg"
When run env -i PATH="$MOCK_BIN:/usr/bin:/bin" "$BASH_BIN" --noprofile --norc "$SCRIPT"
The status should eq 2
The stderr should include 'blocked by mock dcg'
The stderr should not include 'dcg failed with status'
End

It 'maps an abnormal dcg failure to a hard refusal'
cat >"$MOCK_BIN/dcg" <<'SH'
#!/bin/sh
exit 1
SH
chmod 755 "$MOCK_BIN/dcg"
When run env -i PATH="$MOCK_BIN:/usr/bin:/bin" "$BASH_BIN" --noprofile --norc "$SCRIPT"
The status should eq 2
The stderr should include 'dcg failed with status 1'
End

It 'routes every tracked dcg hook through the wrapper'
When run bash -c '
  commands="$(
  for config in \
    generated/hooks/moshi/claude/settings.json \
    generated/hooks/moshi/codex/hooks.json \
    config/copilot/config.json; do
    jq -r ".. | objects | .command? // empty" "$config"
  done
  )"
  grep -Fqx "dcg" <<<"$commands" && exit 1
  grep -Fqx "command -v dcg >/dev/null 2>&1 && dcg" <<<"$commands" && exit 1
  printf "%s\n" "$commands"
'
The status should be success
The output should include '$HOME/dotfiles/config/shared/hooks/dcg-guard.sh'
End

End
