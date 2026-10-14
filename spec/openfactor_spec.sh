#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'config/openfactor/install.sh'
SCRIPT="$PWD/config/openfactor/install.sh"
BASH_BIN="$(command -v bash)"
BASH_DIR="$(dirname "$BASH_BIN")"

It 'uses the OpenFactor CLI as the single host hook installer'
When run head -1 "$SCRIPT"
The output should equal '#!/usr/bin/env bash'
End

It 'skips cleanly when the published CLI cannot be installed'
TMP_HOME="$(mktemp -d)"
When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" OPENFACTOR_RELEASE_ROOT="file://$TMP_HOME/missing" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The error should include 'OpenFactor CLI install failed; skipping orchestration hook registration'
End

It 'installs the published CLI for the openfactor tenant before registering hooks'
TMP_HOME="$(mktemp -d)"
RELEASES="$TMP_HOME/releases"
mkdir -p "$RELEASES"
cat >"$RELEASES/install.sh" <<'SH'
#!/bin/sh
printf 'tenant=%s root=%s\n' "$1" "$CLI_RELEASE_ROOT" >&2
mkdir -p "$CLI_INSTALL_DIR"
printf '#!/bin/sh\nprintf "%%s\\n" "$*"\n' >"$CLI_INSTALL_DIR/$1"
chmod +x "$CLI_INSTALL_DIR/$1"
SH

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" OPENFACTOR_RELEASE_ROOT="file://$RELEASES" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The output should equal 'hooks install --scope host --json'
The error should include "tenant=openfactor root=file://$RELEASES"
The path "$TMP_HOME/.local/bin/openfactor" should be executable
End

It 'upgrades the managed CLI through its own release channel'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/.local/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*"
SH
chmod +x "$TMP_BIN/openfactor"

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The output should equal 'hooks install --scope host --json'
The error should equal 'upgrade'
End

It 'delegates host registration to the CLI'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*"
SH
chmod +x "$TMP_BIN/openfactor"

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$1:$3" "$2"' _ "$TMP_BIN" "$SCRIPT" "$BASH_DIR"
The output should equal 'hooks install --scope host --json'
The status should be success
End

It 'warns and continues when the CLI cannot register hooks'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
echo 'Unknown command: hooks install' >&2
exit 2
SH
chmod +x "$TMP_BIN/openfactor"

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$1:$3" "$2"' _ "$TMP_BIN" "$SCRIPT" "$BASH_DIR"
The status should be success
The error should include 'OpenFactor hook registration failed; continuing activation'
End

It 'leaves generated plugins exactly as the CLI wrote them'
TMP_HOME="$(mktemp -d)"
PLUGIN="$TMP_HOME/.config/opencode/plugins/openfactor-hooks.ts"
EXT="$TMP_HOME/.pi/agent/extensions/openfactor-hooks.ts"
mkdir -p "$(dirname "$PLUGIN")" "$(dirname "$EXT")"
printf 'const events = new Set(["message.part.delta"]);\n' >"$PLUGIN"
printf 'spawn(client, ["pi-hook", event], { stdio: ["pipe"] });\n' >"$EXT"
cp "$PLUGIN" "$TMP_HOME/plugin.orig"
cp "$EXT" "$TMP_HOME/ext.orig"

leave_untouched() {
  env -u XDG_CONFIG_HOME HOME="$TMP_HOME" OPENFACTOR_BIN=/usr/bin/true "$BASH_BIN" "$SCRIPT" &&
    cmp "$PLUGIN" "$TMP_HOME/plugin.orig" &&
    cmp "$EXT" "$TMP_HOME/ext.orig"
}

When run leave_untouched
The status should be success
End

Describe 'daemon socket gate'
setup_gate() {
  TMP_HOME="$(mktemp -d)"
  CONFIG="$TMP_HOME/.claude/settings.json"
  mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.local/state/openfactor/hooks" "$TMP_HOME/bin"
  printf '{"configPath":"%s"}\n' "$CONFIG" >"$TMP_HOME/.local/state/openfactor/hooks/claude-host.json"
  cat >"$CONFIG" <<'JSON'
{"hooks":{
  "PreToolUse":[{"hooks":[{"type":"command","command":"openfactor claude-hook PreToolUse"}]}],
  "UserPromptSubmit":[{"hooks":[{"type":"command","command":"openfactor claude-hook UserPromptSubmit"}]}],
  "Stop":[{"hooks":[{"type":"command","command":"other-tool openfactor claude-hook Stop"}]}]
}}
JSON
  printf '#!/bin/sh\necho "ran $*"\n' >"$TMP_HOME/bin/openfactor"
  chmod +x "$TMP_HOME/bin/openfactor"
}
cleanup_gate() { rm -rf "$TMP_HOME"; }
BeforeEach 'setup_gate'
AfterEach 'cleanup_gate'

install_twice() {
  env -u XDG_STATE_HOME HOME="$TMP_HOME" OPENFACTOR_BIN=/usr/bin/true bash "$SCRIPT" &&
    env -u XDG_STATE_HOME HOME="$TMP_HOME" OPENFACTOR_BIN=/usr/bin/true bash "$SCRIPT" &&
    jq -r '.hooks | .PreToolUse[0].hooks[0].command, .UserPromptSubmit[0].hooks[0].command, .Stop[0].hooks[0].command' "$CONFIG"
}

It 'gates tool hooks on the daemon socket and leaves prompt hooks alone'
When run install_twice
The status should be success
The line 1 of output should equal "sh -c 'test -S \"\${OPENFACTOR_ORCHESTRATION_SOCKET:-\${OPENFACTOR_ORCHESTRATION_STATE:-.orchestration-state}/daemon.sock}\" || exit 0; exec openfactor claude-hook PreToolUse'"
The line 2 of output should equal 'openfactor claude-hook UserPromptSubmit'
The line 3 of output should equal 'other-tool openfactor claude-hook Stop'
End

run_gated() {
  env -u XDG_STATE_HOME HOME="$TMP_HOME" OPENFACTOR_BIN=/usr/bin/true bash "$SCRIPT" &&
    cd "$TMP_HOME" &&
    PATH="$TMP_HOME/bin:$PATH" sh -c "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$CONFIG")" &&
    mkdir -p .orchestration-state &&
    python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' .orchestration-state/daemon.sock &&
    PATH="$TMP_HOME/bin:$PATH" sh -c "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$CONFIG")"
}

It 'runs the CLI only when the daemon socket exists'
When run run_gated
The status should be success
The output should equal 'ran claude-hook PreToolUse'
End
End

It 'warns and continues when OPENFACTOR_BIN is not executable'
TMP_HOME="$(mktemp -d)"
When run env HOME="$TMP_HOME" OPENFACTOR_BIN="$TMP_HOME/missing" "$BASH_BIN" "$SCRIPT"
The status should be success
The error should include 'OpenFactor CLI is not executable'
End
End
