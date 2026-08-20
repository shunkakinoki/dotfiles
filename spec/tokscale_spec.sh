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

It 'submits OpenCode separately from the remaining active clients'
When run bash -c "cat '$SCRIPT'"
The output should include '--client opencode'
The output should include 'antigravity-cli,claude,codex,droid,grok,hermes,openclaw'
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
