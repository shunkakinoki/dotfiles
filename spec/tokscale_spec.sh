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

It 'submits OpenCode separately from every configured client family'
When run bash -c "cat '$SCRIPT'"
The output should include '--client opencode'
The output should include 'remaining_clients=('
The output should include 'amp'
The output should include 'commandcode'
The output should include 'copilot'
The output should include 'cursor'
The output should include 'gemini'
The output should include 'pi'
End

It 'allows each isolated scan up to fifteen minutes'
When run bash -c "cat '$SCRIPT'"
The output should include 'timeout 900'
The output should not include 'timeout 240'
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

Describe 'submission workflow'
SCRIPT="$PWD/home-manager/services/tokscale/submit.sh"
setup() {
  MOCK_BIN=$(mktemp -d)
  MOCK_ORIGINAL_PATH="$PATH"
  export PATH="$MOCK_BIN:$PATH"
  FAKE_HOME=$(mktemp -d)
  mkdir -p "$FAKE_HOME/.bun/install/global/node_modules/tokscale"
  touch "$FAKE_HOME/.bun/install/global/node_modules/tokscale/bin.js"
  CALL_LOG="$FAKE_HOME/calls.log"
  export CALL_LOG

  cat >"$MOCK_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ "${USE_SYSTEMD_RUN:-0}" == 1 ]]
EOF
  cat >"$MOCK_BIN/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf 'systemd-run:%s\n' "$*" >>"$CALL_LOG"
while [[ "$1" == --* ]]; do
  shift
done
"$@"
EOF
  cat >"$MOCK_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
printf 'timeout:%s\n' "$*" >>"$CALL_LOG"
shift
"$@"
EOF
  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
printf 'bun:%s\n' "$*" >>"$CALL_LOG"
if [[ "${FAIL_OPENCODE:-0}" == 1 && "$*" == *'--client opencode'* ]]; then
  exit 42
fi
exit 0
EOF
  chmod +x \
    "$MOCK_BIN/systemctl" \
    "$MOCK_BIN/systemd-run" \
    "$MOCK_BIN/timeout" \
    "$MOCK_BIN/bun"
}

cleanup() {
  export PATH="$MOCK_ORIGINAL_PATH"
  rm -rf "$MOCK_BIN" "$FAKE_HOME"
}

Before 'setup'
After 'cleanup'

It 'runs OpenCode first and then the remaining clients through bounded phases'
When run env HOME="$FAKE_HOME" bash -c 'bash "$1"; status=$?; cat "$CALL_LOG"; exit "$status"' _ "$SCRIPT"
The line 1 of output should include 'timeout:900 bun'
The line 1 of output should include '--client opencode'
The line 2 of output should include 'bun:'
The line 2 of output should include '--client opencode'
The line 3 of output should include 'timeout:900 bun'
The line 3 of output should include 'amp'
The line 3 of output should include 'copilot'
The line 3 of output should include 'cursor'
The line 3 of output should include 'gemini'
The line 4 of output should include 'bun:'
The status should be success
End

It 'runs the second phase and propagates the first phase status after failure'
When run env HOME="$FAKE_HOME" FAIL_OPENCODE=1 bash -c 'bash "$1"; status=$?; cat "$CALL_LOG"; exit "$status"' _ "$SCRIPT"
The line 1 of output should include '--client opencode'
The line 3 of output should include 'amp'
The status should equal 42
End

It 'passes the managed environment into systemd-isolated phases'
When run env HOME="$FAKE_HOME" USE_SYSTEMD_RUN=1 bash -c 'bash "$1"; status=$?; cat "$CALL_LOG"; exit "$status"' _ "$SCRIPT"
The line 1 of output should include 'systemd-run:--user --wait --collect --pipe --quiet'
The line 1 of output should include '--property=KillMode=control-group'
The line 1 of output should include '--setenv=HOME='
The line 1 of output should include '--setenv=PATH='
The line 1 of output should include '--setenv=SSL_CERT_FILE='
The line 2 of output should include 'timeout:900 bun'
The line 4 of output should include 'systemd-run:'
The line 5 of output should include 'timeout:900 bun'
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

Describe 'managed Tokscale version'
PACKAGE_JSON="$PWD/package.json"

It 'requires the scanner-fixed Tokscale release'
When run jq -r '.dependencies.tokscale' "$PACKAGE_JSON"
The output should equal '^4.13.0'
End

End
