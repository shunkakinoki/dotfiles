#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'statusline.sh'
SCRIPT="$PWD/config/claude/statusline.sh"

strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*m//g'
}

run_statusline() {
  bash "$SCRIPT"
}

run_statusline_plain() {
  run_statusline | strip_ansi
}

statusline_payload() {
  local current_dir="$1"
  printf '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "%s"}}' "$current_dir"
}

statusline_payload_with_cost() {
  local current_dir="$1"
  local total_cost_usd="$2"
  printf '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "%s"}, "cost": {"total_cost_usd": %s}}' "$current_dir" "$total_cost_usd"
}

run_statusline_plain_json() {
  printf '%s\n' "$1" | run_statusline_plain
}

Describe 'basic output'
It 'outputs directory and model name'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/myproject"}}'
When run run_statusline_plain
The status should be success
The output should include 'myproject'
The output should include 'claude-sonnet-4'
End

It 'handles missing model gracefully'
Data '{"workspace": {"current_dir": "/tmp/test"}}'
When run run_statusline_plain
The status should be success
The output should include 'test'
End

It 'handles empty JSON input'
Data '{}'
When run run_statusline_plain
The status should be success
The output should include '0%'
End
End

Describe 'context window display'
It 'shows context percentage when usage is provided'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 50000, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}'
When run run_statusline_plain
The status should be success
The output should include '25%'
End

It 'shows 0% when no usage data'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000}}'
When run run_statusline_plain
The status should be success
The output should include '0%'
End

It 'includes progress bar characters'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 100000, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}'
When run run_statusline_plain
The status should be success
The output should include '%'
End
End

Describe 'git integration'
setup() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
}
cleanup() {
  cd / || exit 1
  rm -rf "$TEMP_DIR"
}
Before 'setup'
After 'cleanup'

It 'shows branch name in git repo'
When run run_statusline_plain_json "$(statusline_payload "$TEMP_DIR")"
The status should be success
The output should match pattern '*master*|*main*'
End

It 'shows file count when there are changes'
echo "test content" >"$TEMP_DIR/testfile.txt"
When run run_statusline_plain_json "$(statusline_payload "$TEMP_DIR")"
The status should be success
The output should include '1 files'
End
End

Describe 'non-git directory'
setup() {
  TEMP_DIR=$(mktemp -d)
}
cleanup() {
  rm -rf "$TEMP_DIR"
}
Before 'setup'
After 'cleanup'

It 'works without git info'
When run run_statusline_plain_json "$(statusline_payload "$TEMP_DIR")"
The status should be success
The output should not include '('
End
End

Describe 'cost display'
setup() {
  TEMP_DIR=$(mktemp -d)
}
cleanup() {
  rm -rf "$TEMP_DIR"
}
Before 'setup'
After 'cleanup'

It 'shows cost when provided'
When run run_statusline_plain_json "$(statusline_payload_with_cost "$TEMP_DIR" 0.0123)"
The status should be success
# shellcheck disable=SC2016
The output should include '$0.0123'
End

It 'hides cost when not provided'
When run run_statusline_plain_json "$(statusline_payload "$TEMP_DIR")"
The status should be success
The output should not include '[$'
End
End
End
