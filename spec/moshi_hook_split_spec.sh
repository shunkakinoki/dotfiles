#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329,SC2034

Describe 'moshi hook split'
EXTRACT="$PWD/scripts/extract-moshi-hooks.sh"
MERGE="$PWD/config/shared/merge-moshi-hooks.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  LIVE="$TEMP_DIR/live.json"
  MIXED="$TEMP_DIR/mixed.json"
  INVALID="$TEMP_DIR/invalid.json"
  EMPTY_FRAGMENT="$TEMP_DIR/empty-fragment.json"
  FRAGMENT="$TEMP_DIR/fragment.json"
  BASE="$TEMP_DIR/base.json"

  cat >"$LIVE" <<'JSON'
{
  "permissions": { "allow": ["Bash"] },
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "moshi-hook session-start" }] },
      { "hooks": [{ "type": "command", "command": "security.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "moshi-hook stop" }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "dcg-guard.sh" }] }
    ]
  }
}
JSON

  cat >"$MIXED" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "moshi-hook stop" },
          { "type": "command", "command": "notify.sh" }
        ]
      }
    ]
  }
}
JSON

  printf 'not json\n' >"$INVALID"
  printf '{"hooks":{}}\n' >"$EMPTY_FRAGMENT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

Describe 'extract-moshi-hooks.sh'
It 'exists and is executable'
The path "$EXTRACT" should be exist
The path "$EXTRACT" should be executable
End

It 'keeps only moshi hook entries and drops everything else'
When run bash -c 'bash "$1" "$2" "$3" && jq -cS "." "$3"' _ "$EXTRACT" "$LIVE" "$FRAGMENT"
The status should be success
The output should eq '{"hooks":{"SessionStart":[{"hooks":[{"command":"moshi-hook session-start","type":"command"}]}],"Stop":[{"hooks":[{"command":"moshi-hook stop","type":"command"}]}]}}'
End

It 'fails when a single hook entry mixes moshi and non-moshi commands'
When run bash "$EXTRACT" "$MIXED" "$FRAGMENT"
The status should be failure
The stderr should include 'mixes moshi and non-moshi commands'
End
End

Describe 'merge-moshi-hooks.sh'
It 'exists and is executable'
The path "$MERGE" should be exist
The path "$MERGE" should be executable
End

It 'round-trips the split back into the original set of commands'
When run bash -c '
  bash "$1" "$2" "$3" || exit 1
  jq -S "delpaths([[\"hooks\",\"SessionStart\",0],[\"hooks\",\"Stop\"]])" "$2" >"$4" || exit 1
  bash "$5" "$4" "$3" jq |
    jq -e --slurpfile live "$2" "([.. | objects | .command? // empty] | sort) == (\$live[0] | [.. | objects | .command? // empty] | sort)" >/dev/null
' _ "$EXTRACT" "$LIVE" "$FRAGMENT" "$BASE" "$MERGE"
The status should be success
End

It 'preserves non-hook configuration from the base document'
When run bash -c '
  bash "$1" "$2" "$3" || exit 1
  bash "$4" "$2" "$3" jq | jq -c ".permissions"
' _ "$EXTRACT" "$LIVE" "$FRAGMENT" "$MERGE"
The status should be success
The output should eq '{"allow":["Bash"]}'
End

It 'is idempotent and does not duplicate an already merged entry'
When run bash -c '
  bash "$1" "$2" "$3" || exit 1
  bash "$4" "$2" "$3" jq >"$5" || exit 1
  bash "$4" "$5" "$3" jq | jq -e --slurpfile once "$5" ". == \$once[0]" >/dev/null
' _ "$EXTRACT" "$LIVE" "$FRAGMENT" "$MERGE" "$BASE"
The status should be success
End

It 'fails when the base document is not valid JSON'
When run bash "$MERGE" "$INVALID" "$EMPTY_FRAGMENT" jq
The status should be failure
The stderr should include 'failed to merge'
End
End
End
