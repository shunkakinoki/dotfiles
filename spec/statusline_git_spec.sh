#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'statusline-git.sh'
SCRIPT="$PWD/config/claude/statusline-git.sh"

Describe 'basic output'
It 'outputs directory and model name'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/myproject"}}'
When run bash "$SCRIPT"
The status should be success
The output should include 'myproject'
The output should include 'claude-sonnet-4'
End

It 'handles missing model gracefully'
Data '{"workspace": {"current_dir": "/tmp/test"}}'
When run bash "$SCRIPT"
The status should be success
The output should include 'test'
End

It 'handles empty JSON input'
Data '{}'
When run bash "$SCRIPT"
The status should be success
The output should include '0%'
End
End

Describe 'context window display'
It 'shows context percentage when usage is provided'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 50000, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}'
When run bash "$SCRIPT"
The status should be success
The output should include '25%'
End

It 'shows 0% when no usage data'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000}}'
When run bash "$SCRIPT"
The status should be success
The output should include '0%'
End

It 'includes progress bar characters'
Data '{"model": {"display_name": "claude-sonnet-4"}, "workspace": {"current_dir": "/tmp/test"}, "context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 100000, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}'
When run bash "$SCRIPT"
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
When run bash -c 'echo "{\"model\": {\"display_name\": \"claude-sonnet-4\"}, \"workspace\": {\"current_dir\": \"'"$TEMP_DIR"'\"}}" | bash '"$SCRIPT"
The status should be success
The output should match pattern '*master*|*main*'
End

It 'shows file count when there are changes'
echo "test content" >"$TEMP_DIR/testfile.txt"
When run bash -c 'echo "{\"model\": {\"display_name\": \"claude-sonnet-4\"}, \"workspace\": {\"current_dir\": \"'"$TEMP_DIR"'\"}}" | bash '"$SCRIPT"
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
When run bash -c 'echo "{\"model\": {\"display_name\": \"claude-sonnet-4\"}, \"workspace\": {\"current_dir\": \"'"$TEMP_DIR"'\"}}" | bash '"$SCRIPT"
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
When run bash -c 'echo "{\"model\": {\"display_name\": \"claude-sonnet-4\"}, \"workspace\": {\"current_dir\": \"'"$TEMP_DIR"'\"}, \"cost\": {\"total_cost_usd\": 0.0123}}" | bash '"$SCRIPT"
The status should be success
# shellcheck disable=SC2016
The output should include '$0.0123'
End

It 'hides cost when not provided'
When run bash -c 'echo "{\"model\": {\"display_name\": \"claude-sonnet-4\"}, \"workspace\": {\"current_dir\": \"'"$TEMP_DIR"'\"}}" | bash '"$SCRIPT"
The status should be success
The output should not include '[$'
End
End
End
