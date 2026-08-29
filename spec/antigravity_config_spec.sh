#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'config/antigravity'
SCRIPT="$PWD/config/antigravity/activate.sh"
SETTINGS="$PWD/config/antigravity/settings.json"
HOOKS="$PWD/config/antigravity/hooks.json"
WRAPPER="$PWD/config/antigravity/agy.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  TEMP_BIN="$TEMP_HOME/bin"
  TRACES_LOG="$TEMP_HOME/traces.log"
  AGY_LOG="$TEMP_HOME/agy.log"
  mkdir -p "$TEMP_BIN"
  : >"$TRACES_LOG"
  : >"$AGY_LOG"
  cat >"$TEMP_BIN/traces" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TRACES_LOG"
STUB
  cat >"$TEMP_BIN/agy-real" <<'STUB'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >>"$AGY_LOG"
printf '%s\n' 'agy-ok'
STUB
  chmod +x "$TEMP_BIN/traces" "$TEMP_BIN/agy-real"
  export TEMP_BIN TRACES_LOG AGY_LOG
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'creates writable default-backend Antigravity CLI settings'
When run bash -c 'HOME="$1" bash "$2" "$3" "$4" jq && jq -e '\''.model == "gemini-3.7-flash-high" and has("modelProvider") == false and (.permissions.allow | index("read_file(*)") != null)'\'' "$1/.gemini/antigravity-cli/settings.json" >/dev/null && find "$1/.gemini/antigravity-cli/settings.json" -prune -perm 600 -print -quit | grep -q .' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS" "$HOOKS"
The status should be success
The path "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should be file
The path "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should be writable
End

It 'preserves runtime preferences while removing the legacy explicit provider'
mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
cat >"$TEMP_HOME/.gemini/antigravity-cli/settings.json" <<'JSON'
{
  "modelProvider": "legacy",
  "model": "legacy-model",
  "showTips": false,
  "futureSetting": "preserved"
}
JSON
When run bash -c 'HOME="$1" bash "$2" "$3" "$4" jq && jq -e '\''.model == "gemini-3.7-flash-high" and has("modelProvider") == false and .showTips == false and .futureSetting == "preserved" and (.permissions.allow | index("read_file(*)") != null)'\'' "$1/.gemini/antigravity-cli/settings.json" >/dev/null && find "$1/.gemini/antigravity-cli/settings.json" -prune -perm 600 -print -quit | grep -q .' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS" "$HOOKS"
The status should be success
End

It 'fails closed without overwriting malformed runtime settings'
mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
printf '%s\n' '{broken' >"$TEMP_HOME/.gemini/antigravity-cli/settings.json"
When run bash -c 'HOME="$1" bash "$2" "$3" "$4" jq' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS" "$HOOKS"
The status should be failure
The error should include 'refusing to replace invalid Antigravity settings'
The contents of file "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should equal '{broken'
End

It 'installs every managed named hook into the global customization root'
When run bash -c 'HOME="$1" bash "$2" "$3" "$4" jq && jq -e '\''(keys == ["moshi-hook", "traces-share-to-traces"]) and (.["traces-share-to-traces"].Stop | length == 1)'\'' "$1/.gemini/config/hooks.json" >/dev/null && find "$1/.gemini/config/hooks.json" -prune -perm 644 -print -quit | grep -q .' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS" "$HOOKS"
The status should be success
The path "$TEMP_HOME/.gemini/config/hooks.json" should be file
The path "$TEMP_HOME/.gemini/config/hooks.json" should be writable
End

It 'uses the official Traces Antigravity Stop hook verbatim'
When run jq -r '.["traces-share-to-traces"].Stop[0].command' "$HOOKS"
The output should equal "traces hook agent agent-done --agent antigravity >/dev/null 2>&1; printf %s '{\"decision\":\"\"}'"
End

It 'reverts named hooks written by other tools'
mkdir -p "$TEMP_HOME/.gemini/config"
cat >"$TEMP_HOME/.gemini/config/hooks.json" <<'JSON'
{
  "moshi-hook": {
    "enabled": true,
    "Stop": [
      {
        "type": "command",
        "command": "/nix/store/stale-moshi-hook/bin/moshi-hook antigravity-hook Stop",
        "timeout": 5
      }
    ]
  },
  "orca-status": {
    "enabled": true
  }
}
JSON
When run bash -c 'HOME="$1" bash "$2" "$3" "$4" jq && jq -e '\''(has("orca-status") | not) and (.["moshi-hook"].Stop[0].command == "moshi-hook antigravity-hook Stop")'\'' "$1/.gemini/config/hooks.json" >/dev/null' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS" "$HOOKS"
The status should be success
End

It 'pins no absolute Nix store paths or home directories in managed hooks'
When run bash -c 'grep -qE "/nix/store|/Users/" "$1" && exit 1 || exit 0' _ "$HOOKS"
The status should be success
End

Describe 'CLI wrapper'
It 'installs official Traces Git hooks before starting Antigravity in a worktree'
mkdir -p "$TEMP_HOME/repo"
git -C "$TEMP_HOME/repo" init -q
When run bash -c 'cd "$1" && PATH="$2:$PATH" TRACES_LOG="$3" AGY_LOG="$4" ANTIGRAVITY_CLI_BIN="$2/agy-real" bash "$5" --print hello' _ "$TEMP_HOME/repo" "$TEMP_BIN" "$TRACES_LOG" "$AGY_LOG" "$WRAPPER"
The status should be success
The output should equal 'agy-ok'
The contents of file "$TRACES_LOG" should equal 'setup git'
The contents of file "$AGY_LOG" should equal '<--print>
<hello>'
End

It 'does not run Traces setup outside a Git worktree'
When run bash -c 'cd "$1" && PATH="$2:$PATH" TRACES_LOG="$3" AGY_LOG="$4" ANTIGRAVITY_CLI_BIN="$2/agy-real" bash "$5" --version && test ! -s "$3"' _ "$TEMP_HOME" "$TEMP_BIN" "$TRACES_LOG" "$AGY_LOG" "$WRAPPER"
The status should be success
The output should equal 'agy-ok'
The contents of file "$AGY_LOG" should equal '<--version>'
End
End

It 'contains no remaining CCS integration outside this regression check'
When run bash -c "! git grep -niE '(^|[^[:alnum:]_])(ccs|claude code switch)([^[:alnum:]_]|$)' -- ':!spec/antigravity_config_spec.sh'"
The status should be success
End
End
