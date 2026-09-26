#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/shared/merge-orchestration-hooks.sh'
SCRIPT="$PWD/config/shared/merge-orchestration-hooks.sh"

setup() {
  TMP_HOME="$(mktemp -d)"
  TMP_BIN="$TMP_HOME/bin"
  mkdir -p "$TMP_BIN"
  cat >"$TMP_BIN/orchestration" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1 $2 $3" == 'hooks render --harness' ]]
if [[ $4 == opencode ]]; then
  printf 'export const P = async () => ({ "chat.message": async () => {} });\n'
else
  printf '{"description":"orchestration","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"should-not-install"}]}],"UserPromptSubmit":[{"hooks":[{"type":"command","command":"receipt %s","timeout":5}]}]}}\n' "$4"
fi
SH
  chmod +x "$TMP_BIN/orchestration"
}
cleanup() { rm -rf "$TMP_HOME"; }
BeforeEach 'setup'
AfterEach 'cleanup'

Parameters
claude
codex
devin
End

It "merges the $1 prompt receipt idempotently without replacing existing hooks"
printf '{"model":"preserved","hooks":{"SessionStart":[],"UserPromptSubmit":[{"hooks":[{"type":"command","command":"existing"}]}]}}\n' >"$TMP_HOME/target.json"
chmod 600 "$TMP_HOME/target.json"
When run bash -c 'HOME="$1" PATH="$2:$PATH" bash "$3" "$4" "$1/target.json" "$(command -v jq)" && cp "$1/target.json" "$1/first.json" && HOME="$1" PATH="$2:$PATH" bash "$3" "$4" "$1/target.json" "$(command -v jq)" && cmp -s "$1/first.json" "$1/target.json" && jq -e --arg h "$4" '\''.model == "preserved" and (.hooks.SessionStart | length == 0) and ([.hooks.UserPromptSubmit[].hooks[].command] == ["existing", "receipt \($h)"])'\'' "$1/target.json" >/dev/null && [[ $(stat -c %a "$1/target.json" 2>/dev/null || stat -f %Lp "$1/target.json") == 600 ]]' _ "$TMP_HOME" "$TMP_BIN" "$SCRIPT" "$1"
The status should be success
End

It 'writes the rendered opencode plugin module'
When run bash -c 'HOME="$1" PATH="$2:$PATH" bash "$3" opencode "$1/.config/opencode/plugins/orchestration-prompt-receipt.js" "$(command -v jq)" && grep -q "\"chat.message\"" "$1/.config/opencode/plugins/orchestration-prompt-receipt.js"' _ "$TMP_HOME" "$TMP_BIN" "$SCRIPT"
The status should be success
End

It 'renders from the canonical checkout when no orchestration command is on PATH'
ENTRY="$TMP_HOME/ghq/github.com/shunkakinokisoftware/shunkakinokisoftware/orchestration/cli/src/index.ts"
mkdir -p "$(dirname "$ENTRY")"
printf '{"hooks":{}}\n' >"$TMP_HOME/target.json"
When run bash -c 'mv "$2/orchestration" "$3" && HOME="$1" PATH="/usr/bin:/bin" bash "$4" claude "$1/target.json" "$(command -v jq)" && jq -e '\''.hooks.UserPromptSubmit[0].hooks[0].command == "receipt claude"'\'' "$1/target.json" >/dev/null' _ "$TMP_HOME" "$TMP_BIN" "$ENTRY" "$SCRIPT"
The status should be success
End

It 'skips hosts without an orchestration checkout'
printf '{"hooks":{}}\n' >"$TMP_HOME/target.json"
When run bash -c 'HOME="$1" PATH="/usr/bin:/bin" bash "$2" claude "$1/target.json" "$(command -v jq)" && jq -e '\''.hooks == {}'\'' "$1/target.json" >/dev/null' _ "$TMP_HOME" "$SCRIPT"
The status should be success
End

It 'fails activation when the renderer fails'
printf '{"hooks":{}}\n' >"$TMP_HOME/target.json"
printf '#!/usr/bin/env bash\nexit 3\n' >"$TMP_BIN/orchestration"
When run bash -c 'HOME="$1" PATH="$2:$PATH" bash "$3" claude "$1/target.json" "$(command -v jq)"' _ "$TMP_HOME" "$TMP_BIN" "$SCRIPT"
The status should be failure
The stderr should include 'failed to render live claude orchestration hooks'
End
End
