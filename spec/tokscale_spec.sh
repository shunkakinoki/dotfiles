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

It 'prefetches Cursor usage CSV before submit'
When run bash -c "cat '$SCRIPT'"
The output should include 'prefetch_cursor_usage'
The output should include 'export-usage-events-csv'
The output should include 'junhoyeo/tokscale#1175'
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
The output should include 'no Cursor credentials, skipping prefetch'
The stderr should include 'actual Tokscale failure'
The status should be failure
End
End

Describe 'cursor usage prefetch'
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
echo submitted
exit 0
EOF
  chmod +x "$MOCK_BIN/timeout" "$MOCK_BIN/bun"
}

write_cursor_creds() {
  mkdir -p "$FAKE_HOME/.config/tokscale"
  cat >"$FAKE_HOME/.config/tokscale/cursor-credentials.json" <<'EOF'
{"version":1,"activeAccountId":"user_test","accounts":{"user_test":{"sessionToken":"user_test%3A%3AeyJ"}}}
EOF
}

cleanup_prefetch() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$FAKE_HOME"
}

Describe 'successful CSV download'
setup() {
  install_common_mocks
  write_cursor_creds
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' 'Date,Cloud Agent ID' '"2026-08-22T00:00:00.000Z","","","Included","test","No","0","1","0","1","2","Included"' >"$out"
EOF
  chmod +x "$MOCK_BIN/curl"
}

Before 'setup'
After 'cleanup_prefetch'

It 'writes the Cursor usage CSV then submits'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The output should include 'prefetching Cursor usage CSV'
The output should include 'wrote'
The output should include 'submitted'
The status should be success
The file "$FAKE_HOME/.config/tokscale/cursor-cache/usage.csv" should be exist
The contents of file "$FAKE_HOME/.config/tokscale/cursor-cache/usage.csv" should start with 'Date,'
End
End

Describe 'download failure'
setup() {
  install_common_mocks
  write_cursor_creds
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 22
EOF
  chmod +x "$MOCK_BIN/curl"
}

Before 'setup'
After 'cleanup_prefetch'

It 'still submits when prefetch fails'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The stderr should include 'Cursor usage prefetch failed'
The output should include 'submitted'
The status should be success
End
End

Describe 'invalid CSV'
setup() {
  install_common_mocks
  write_cursor_creds
  mkdir -p "$FAKE_HOME/.config/tokscale/cursor-cache"
  printf '%s\n' 'Date,previous' >"$FAKE_HOME/.config/tokscale/cursor-cache/usage.csv"
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' '{"error":"nope"}' >"$out"
EOF
  chmod +x "$MOCK_BIN/curl"
}

Before 'setup'
After 'cleanup_prefetch'

It 'keeps the previous cache when the response is not CSV'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The stderr should include 'non-CSV'
The output should include 'submitted'
The status should be success
The contents of file "$FAKE_HOME/.config/tokscale/cursor-cache/usage.csv" should equal 'Date,previous'
End
End

Describe 'missing credentials'
setup() {
  install_common_mocks
}

Before 'setup'
After 'cleanup_prefetch'

It 'skips prefetch and still submits'
When run env HOME="$FAKE_HOME" bash "$SCRIPT"
The output should include 'no Cursor credentials, skipping prefetch'
The output should include 'submitted'
The status should be success
End
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

It 'puts curl and jq on the service PATH for Cursor prefetch'
When run bash -c "cat '$CONFIG'"
The output should include 'pkgs.curl'
The output should include 'pkgs.jq'
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
