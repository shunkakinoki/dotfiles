#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Codex Herdr native lane hooks'
CODEX_HOOKS="$PWD/generated/hooks/moshi/codex/hooks.json"
HERDR_COMMAND='bun /absolute/source-checkout/scripts/herdr-lane.ts hook'

setup() {
  ROUTING_ROOT="$(mktemp -d)"
  ROUTING_BIN="$ROUTING_ROOT/bin"
  ROUTING_SOURCE="$ROUTING_ROOT/source"
  ROUTING_CWD="$ROUTING_ROOT/other-cwd"
  ROUTING_LOG="$ROUTING_ROOT/routing.log"
  mkdir -p "$ROUTING_BIN" "$ROUTING_SOURCE/scripts" "$ROUTING_CWD"
  cat >"$ROUTING_BIN/bun" <<'STUB'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >>"$HERDR_ROUTING_LOG"
STUB
  chmod +x "$ROUTING_BIN/bun"
  export CODEX_HOOKS ROUTING_BIN ROUTING_SOURCE ROUTING_CWD
  export HERDR_ROUTING_LOG="$ROUTING_LOG"
}

cleanup() {
  rm -rf "$ROUTING_ROOT"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'registers SessionStart only for native startup and resume'
When run jq -e --arg command "$HERDR_COMMAND" '[.hooks.SessionStart[] | select(.matcher == "startup|resume") | .hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'registers UserPromptSubmit with the native lane command'
When run jq -e --arg command "$HERDR_COMMAND" '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'routes the registered command from another cwd to the configured source'
When run bash -c 'command=$(jq -r "[.hooks.UserPromptSubmit[]?.hooks[]?.command] | map(select(startswith(\"bun /absolute/source-checkout/\"))) | first" "$CODEX_HOOKS"); command=${command/\/absolute\/source-checkout/$ROUTING_SOURCE}; (cd "$ROUTING_CWD" && PATH="$ROUTING_BIN:$PATH" bash -c "$command")'
The status should be success
The contents of file "$ROUTING_LOG" should include "$ROUTING_CWD|$ROUTING_SOURCE/scripts/herdr-lane.ts hook"
End

It 'preserves the existing Codex hook fixture'
When run jq -e '[.. | objects | .command? // empty] as $registered | all(["moshi-hook codex-hook", "bd codex-hook SessionStart", "bd codex-hook UserPromptSubmit", "$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh session-start --agent codex # traces hook agent", "$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh prompt-submitted --agent codex # traces hook agent"][]; . as $expected | any($registered[]; . == $expected))' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'does not add an actor or synthetic receipt fallback'
When run jq -e '[.. | objects | .command? // empty] | all(.[]; test("BEADS_ACTOR|parent.*export|receipt|generation"; "i") | not)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End
End
