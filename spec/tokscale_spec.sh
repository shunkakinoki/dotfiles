#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'tokscale/submit.sh'
SCRIPT="$PWD/home-manager/services/tokscale/submit.sh"

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'has a descriptive comment mentioning Tokscale'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'Tokscale'
End

It 'invokes tokscale submit through bun'
When run bash -c "cat '$SCRIPT'"
The output should include 'bun'
The output should include 'submit'
End

It 'runs non-interactively (stdin from /dev/null)'
When run bash -c "cat '$SCRIPT'"
The output should include '/dev/null'
End

It 'uses the bun global tokscale entrypoint'
When run bash -c "cat '$SCRIPT'"
The output should include '.bun/install/global/node_modules/tokscale/bin.js'
End
End

Describe 'network handling'
It 'does not gate Tokscale on an unrelated endpoint'
When run grep -F '1.1.1.1' "$SCRIPT"
The status should be failure
End
End

Describe 'missing tokscale guard'
setup() {
  FAKE_HOME=$(mktemp -d)
}

cleanup() {
  rm -rf "$FAKE_HOME"
}

Before 'setup'
After 'cleanup'

It 'skips and exits 0 when tokscale is not installed'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The output should include 'not installed'
The status should be success
End
End

End

Describe 'submission failure'
SCRIPT="$PWD/home-manager/services/tokscale/submit.sh"
setup() {
  MOCK_BIN=$(mktemp -d)
  MOCK_ORIGINAL_PATH="$PATH"
  export PATH="$MOCK_BIN:$PATH"
  FAKE_HOME=$(mktemp -d)
  mkdir -p "$FAKE_HOME/.bun/install/global/node_modules/tokscale"
  touch "$FAKE_HOME/.bun/install/global/node_modules/tokscale/bin.js"
  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
echo 'actual Tokscale failure' >&2
exit 42
EOF
  chmod +x "$MOCK_BIN/bun"
}

cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$FAKE_HOME"
}

Before 'setup'
After 'cleanup'

It 'propagates the real Tokscale exit status'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The stderr should include 'actual Tokscale failure'
The status should be failure
End
End

Describe 'tokscale service schedule'
CONFIG="$PWD/home-manager/services/tokscale/default.nix"

It 'uses fixed three-hour calendar slots on macOS'
When run bash -c "awk '/calendarHours = \\[/,/\\];/' '$CONFIG' | grep -Eo '[0-9]+' | paste -sd, -"
The output should equal '0,3,6,9,12,15,18,21'
End

It 'maps the fixed hours to launchd calendar intervals at minute zero'
When run bash -c "grep -A4 -F 'StartCalendarInterval = map' '$CONFIG'"
The output should include 'Hour = hour;'
The output should include 'Minute = 0;'
End

It 'sets the macOS PATH through the launchd environment key'
When run bash -c "grep -F 'EnvironmentVariables = {' '$CONFIG'"
The output should include 'EnvironmentVariables'
End

It 'does not use the ignored Environment key'
When run bash -c "grep -F 'Environment = {' '$CONFIG'"
The status should be failure
End

It 'does not use a load-relative interval on macOS'
When run bash -c "grep -F 'StartInterval' '$CONFIG'"
The status should be failure
End

It 'installs the Linux cron schedule during Home Manager activation'
When run bash -c "grep -F 'installTokscaleCron' '$CONFIG'"
The output should include 'installTokscaleCron'
End

It 'does not define a systemd service or timer'
When run bash -c "grep -F 'systemd.user' '$CONFIG'"
The status should be failure
End

End

Describe 'tokscale cron activation'
ACTIVATOR="$PWD/home-manager/services/tokscale/activate-cron.sh"

setup() {
  MOCK_BIN=$(mktemp -d)
  CRONTAB_STATE=$(mktemp)
  export CRONTAB_STATE
  MOCK_ORIGINAL_PATH="$PATH"
  export PATH="$MOCK_BIN:$PATH"
  cat >"$MOCK_BIN/crontab" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -l)
    cat "$CRONTAB_STATE"
    ;;
  -)
    cat >"$CRONTAB_STATE"
    ;;
  *)
    exit 2
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/crontab"
}

cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN"
  rm -f "$CRONTAB_STATE"
}

Before 'setup'
After 'cleanup'

It 'installs the fixed three-hour cron expression and preserves existing entries'
echo 'MAILTO=ops@example.com' >"$CRONTAB_STATE"
When run bash -c "'$ACTIVATOR' 'echo submit' && cat '$CRONTAB_STATE'"
The output should include 'MAILTO=ops@example.com'
The output should include '0 */3 * * * echo submit'
The status should be success
End

It 'replaces its managed block idempotently'
When run bash -c "'$ACTIVATOR' 'echo old' && '$ACTIVATOR' 'echo new' && grep -c '^# BEGIN home-manager tokscale$' '$CRONTAB_STATE' && grep -c 'echo new$' '$CRONTAB_STATE'"
The line 1 of output should eq '1'
The line 2 of output should eq '1'
The status should be success
End

End
