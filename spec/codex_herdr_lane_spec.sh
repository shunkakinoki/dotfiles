#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2089,SC2090

Describe 'Codex Herdr native lane hooks'
CODEX_HOOKS="$PWD/generated/hooks/moshi/codex/hooks.json"
CODEX_ACTIVATE="$PWD/config/codex/activate.sh"
ENV_PRINTER="$PWD/home-manager/modules/dotenv/print-env-file.sh"
HERDR_MARKER='bun __DOTFILES_HERDR_SOURCE_CHECKOUT__/scripts/herdr-lane.ts hook'

setup() {
  ROUTING_ROOT="$(mktemp -d)"
  ROUTING_BIN="$ROUTING_ROOT/bin"
  ROUTING_SOURCE="$ROUTING_ROOT/source with 'quote'"
  ROUTING_CWD="$ROUTING_ROOT/other-cwd"
  ROUTING_LOG="$ROUTING_ROOT/routing.log"
  mkdir -p "$ROUTING_BIN" "$ROUTING_SOURCE/scripts" "$ROUTING_CWD"
  cat >"$ROUTING_BIN/bun" <<'STUB'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >>"$HERDR_ROUTING_LOG"
STUB
  chmod +x "$ROUTING_BIN/bun"
  export CODEX_HOOKS CODEX_ACTIVATE ENV_PRINTER ROUTING_ROOT ROUTING_BIN ROUTING_SOURCE ROUTING_CWD
  export HERDR_ROUTING_LOG="$ROUTING_LOG"
  printf '%s\n' '#!/usr/bin/env TypeScript' >"$ROUTING_SOURCE/scripts/herdr-lane.ts"
}

cleanup() {
  rm -rf "$ROUTING_ROOT"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'registers SessionStart only for native startup and resume'
When run jq -e --arg command "$HERDR_MARKER" '[.hooks.SessionStart[] | select(.matcher == "startup|resume") | .hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'registers UserPromptSubmit with the native lane command'
When run jq -e --arg command "$HERDR_MARKER" '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(. == $command)' "$CODEX_HOOKS"
The status should be success
The output should eq 'true'
End

It 'materializes and routes the registered command from another cwd'
When run bash -c 'activation_home="$ROUTING_ROOT/home"; mkdir -p "$activation_home/dotfiles"; printf "HERDR_SOURCE_CHECKOUT=%s\\n" "$ROUTING_SOURCE" >"$activation_home/dotfiles/.env"; printf "#!/usr/bin/env bash\\nexit 0\\n" >"$ROUTING_ROOT/sync.sh"; chmod +x "$ROUTING_ROOT/sync.sh"; HOME="$activation_home" bash "$CODEX_ACTIVATE" "$PWD/config/codex/config.toml" "$CODEX_HOOKS" "$PWD/config/codex/desktop-settings.json" "$(command -v jq)" "$ROUTING_ROOT/sync.sh" "$PWD/config/codex/profiles" "$ENV_PRINTER"; command=$(jq -r ".hooks.UserPromptSubmit[]?.hooks[]?.command" "$activation_home/.codex/hooks.json" | grep -F scripts/herdr-lane.ts); (cd "$ROUTING_CWD" && HOME="$activation_home" PATH="$ROUTING_BIN:$PATH" bash -c "$command")'
The status should be success
The contents of file "$ROUTING_LOG" should include "$ROUTING_CWD|$ROUTING_SOURCE/scripts/herdr-lane.ts hook"
End

It 'omits the optional Herdr entries when no private source is configured'
When run bash -c 'activation_home="$ROUTING_ROOT/home"; mkdir -p "$activation_home"; printf "#!/usr/bin/env bash\\nexit 0\\n" >"$ROUTING_ROOT/sync.sh"; chmod +x "$ROUTING_ROOT/sync.sh"; HOME="$activation_home" bash "$CODEX_ACTIVATE" "$PWD/config/codex/config.toml" "$CODEX_HOOKS" "$PWD/config/codex/desktop-settings.json" "$(command -v jq)" "$ROUTING_ROOT/sync.sh" "$PWD/config/codex/profiles" "$ENV_PRINTER"; jq -e "[.. | objects | .command? // empty] | all(.[]; . == \"$HERDR_MARKER\" | not)" "$activation_home/.codex/hooks.json"'
The status should be success
The output should eq 'true'
End

It 'leaves prior hooks intact when the private environment printer fails'
When run bash -c 'activation_home="$ROUTING_ROOT/home"; mkdir -p "$activation_home/.codex"; cp -f "$CODEX_HOOKS" "$activation_home/.codex/hooks.json"; printf "#!/usr/bin/env bash\\nexit 0\\n" >"$ROUTING_ROOT/sync.sh"; chmod +x "$ROUTING_ROOT/sync.sh"; printf "#!/usr/bin/env bash\\nexit 7\\n" >"$ROUTING_ROOT/failing-printer.sh"; chmod +x "$ROUTING_ROOT/failing-printer.sh"; if HOME="$activation_home" bash "$CODEX_ACTIVATE" "$PWD/config/codex/config.toml" "$CODEX_HOOKS" "$PWD/config/codex/desktop-settings.json" "$(command -v jq)" "$ROUTING_ROOT/sync.sh" "$PWD/config/codex/profiles" "$ROUTING_ROOT/failing-printer.sh" 2>/dev/null; then exit 1; fi; cmp -s "$CODEX_HOOKS" "$activation_home/.codex/hooks.json"'
The status should be success
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
