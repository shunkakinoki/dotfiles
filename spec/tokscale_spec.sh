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

It 'allows a Kyber cold scan to run for up to fifteen minutes'
When run bash -c "grep -F 'timeout 900 bun' '$SCRIPT'"
The output should include 'timeout 900 bun'
End

It 'uses the bun global tokscale entrypoint'
When run bash -c "cat '$SCRIPT'"
The output should include '.bun/install/global/node_modules/tokscale/bin.js'
End

It 'runs the managed Cursor sync helper before submit'
When run bash -c "cat '$SCRIPT'"
The output should include 'sync-cursor.py'
The output should not include 'export-usage-events-csv'
End

It 'syncs the Antigravity cache before submit'
When run bash -c "cat '$SCRIPT'"
The output should include 'antigravity sync'
End

It 'bounds the Antigravity sync and never lets it block submit'
When run bash -c "cat '$SCRIPT'"
The output should include 'timeout 300 bun'
The output should include 'Antigravity sync failed'
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
The output should include 'No saved Cursor credentials; skipping Cursor sync'
The stderr should include 'actual Tokscale failure'
The status should be failure
End
End

Describe 'managed Cursor sync'
SCRIPT="$PWD/home-manager/services/tokscale/submit.sh"

install_common_mocks() {
  MOCK_BIN=$(mktemp -d)
  MOCK_ORIGINAL_PATH="$PATH"
  export PATH="$MOCK_BIN:$PATH"
  FAKE_HOME=$(mktemp -d)
  mkdir -p "$FAKE_HOME/.bun/install/global/node_modules/tokscale"
  touch "$FAKE_HOME/.bun/install/global/node_modules/tokscale/bin.js"
  cat >"$MOCK_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"antigravity sync"*) exit "${ANTIGRAVITY_FIXTURE_STATUS:-0}" ;;
  *) echo submitted; exit "${SUBMIT_FIXTURE_STATUS:-0}" ;;
esac
EOF
  cat >"$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
echo 'Cursor helper called'
exit "${CURSOR_FIXTURE_STATUS:-0}"
EOF
  chmod +x "$MOCK_BIN/timeout" "$MOCK_BIN/bun" "$MOCK_BIN/python3"
}

cleanup_prefetch() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$FAKE_HOME"
}

Before 'install_common_mocks'
After 'cleanup_prefetch'

It 'runs the Cursor helper and uploads available data'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The output should include 'Cursor helper called'
The output should include 'submitted'
The status should be success
End

It 'uploads existing data but reports a failed Cursor refresh'
When run env HOME="$FAKE_HOME" CURSOR_FIXTURE_STATUS=17 bash "$SCRIPT"
The output should include 'submitted'
The stderr should include 'Cursor sync incomplete'
The status should equal 17
End

It 'preserves the real upload failure when Cursor refresh also fails'
When run env HOME="$FAKE_HOME" CURSOR_FIXTURE_STATUS=17 SUBMIT_FIXTURE_STATUS=42 bash "$SCRIPT"
The output should include 'submitted'
The stderr should include 'Cursor sync incomplete'
The status should equal 42
End

It 'uploads when Antigravity is unavailable'
When run env HOME="$FAKE_HOME" ANTIGRAVITY_FIXTURE_STATUS=1 bash "$SCRIPT"
The output should include 'submitted'
The stderr should include 'Antigravity sync failed'
The status should be success
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

It 'submits when the macOS user agent loads after startup'
When run bash -c "grep -F 'RunAtLoad = true;' '$CONFIG'"
The output should include 'RunAtLoad = true;'
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

It 'defines a Linux systemd oneshot service'
When run bash -c "cat '$CONFIG'"
The output should include 'systemd.user.services.tokscale'
The output should include 'Type = "oneshot";'
The output should include 'ExecStart ='
End

It 'gives the Linux service its managed runtime environment'
When run bash -c "cat '$CONFIG'"
The output should include 'HOME='
The output should include 'home.homeDirectory'
The output should include 'PATH='
The output should include 'binPath'
End

It 'provides the managed Python runtime and Cursor helper'
When run bash -c "cat '$CONFIG'"
The output should include 'pkgs.python3'
The output should include './sync-cursor.py'
End

It 'runs the Linux timer on fixed three-hour wall-clock slots'
When run bash -c "cat '$CONFIG'"
The output should include 'systemd.user.timers.tokscale'
The output should include 'OnCalendar = "*-*-* 0/3:00:00";'
The output should include 'Persistent = true;'
The output should include 'Unit = "tokscale.service";'
End

It 'submits shortly after Linux boot'
When run bash -c "grep -F 'OnBootSec = \"1min\";' '$CONFIG'"
The output should include 'OnBootSec = "1min";'
End

It 'enables the Linux timer without requiring cron'
When run bash -c "cat '$CONFIG'"
The output should include 'WantedBy = [ "timers.target" ];'
The output should not include 'installTokscaleCron'
The output should not include 'crontab'
End

End
