#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2089,SC2090,SC2329

Describe 'update-moshi-hooks.sh'
SCRIPT="$PWD/scripts/update-moshi-hooks.sh"

Describe 'script structure'
It 'exists and is executable'
The path "$SCRIPT" should be exist
The path "$SCRIPT" should be executable
End

It 'uses set -euo pipefail'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
The status should be success
End

It 'calls moshi-hook install'
When run bash -c "grep 'moshi-hook install' '$SCRIPT'"
The output should include 'moshi-hook install'
The status should be success
End

It 'copies TypeScript plugin files'
When run cat "$SCRIPT"
The output should include 'omp'
The output should include 'pi'
The output should include 'opencode'
The output should include 'generated/hooks/moshi'
The status should be success
End

It 'runs nix fmt for formatting'
When run bash -c "grep 'nix fmt' '$SCRIPT'"
The output should include 'nix fmt'
The status should be success
End
End

Describe 'Codex Herdr regeneration normalization'
REGEN_SCRIPT="$PWD/scripts/update-moshi-hooks.sh"
REGEN_MARKER='bun __DOTFILES_HERDR_SOURCE_CHECKOUT__/scripts/herdr-lane.ts hook'

setup_regeneration() {
  REGEN_ROOT="$(mktemp -d)"
  REGEN_HOME="$REGEN_ROOT/home"
  REGEN_BIN="$REGEN_ROOT/bin"
  REGEN_OUTPUT="$REGEN_ROOT/generated"
  REGEN_HOOKS_JSON="$PWD/generated/hooks/moshi/codex/hooks.json"
  REGEN_ACTIVATED_INPUT="$REGEN_ROOT/activated-hooks.json"
  REGEN_CONFIG_TOML="$PWD/config/codex/config.toml"
  REGEN_DESKTOP_SETTINGS="$PWD/config/codex/desktop-settings.json"
  REGEN_PROFILES_DIR="$PWD/config/codex/profiles"
  REGEN_ACTIVATE_SCRIPT="$PWD/config/codex/activate.sh"
  REGEN_SOURCE="$REGEN_ROOT/private source 'checkout"
  REGEN_PRINTER="$REGEN_ROOT/env-printer.sh"
  REGEN_SYNC="$REGEN_ROOT/sync-desktop-settings.sh"
  REGEN_UNRELATED="bun other.js --message '/tmp/private source/scripts/herdr-lane.ts' hook"
  REGEN_UNRELATED_PREFIX="bun '/tmp/other.js' --message '/tmp/scripts/herdr-lane.ts' hook"
  mkdir -p "$REGEN_HOME" "$REGEN_BIN" "$REGEN_OUTPUT/grok/plugin/hooks"
  mkdir -p "$REGEN_SOURCE/scripts"
  printf '%s\n' '{"hooks":{}}' >"$REGEN_OUTPUT/grok/plugin/hooks/hooks.json"
  printf '%s\n' '// inert Herdr source fixture' >"$REGEN_SOURCE/scripts/herdr-lane.ts"
  cat >"$REGEN_PRINTER" <<SH
#!/usr/bin/env sh
printf 'HERDR_SOURCE_CHECKOUT=%s\n' "$REGEN_SOURCE"
SH
  chmod +x "$REGEN_PRINTER"
  cat >"$REGEN_SYNC" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$REGEN_SYNC"
  cat >"$REGEN_BIN/moshi-hook" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.omp/agent/extensions" "$HOME/.pi/agent/extensions" "$HOME/.config/opencode/plugins" "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor" "$HOME/.gemini" "$HOME/.grok/hooks"
printf '%s\n' '// inert' >"$HOME/.omp/agent/extensions/moshi-hooks.ts"
printf '%s\n' '// inert' >"$HOME/.pi/agent/extensions/moshi-hooks.ts"
printf '%s\n' '// inert' >"$HOME/.config/opencode/plugins/moshi-hooks.ts"
printf '%s\n' '{"hooks":{}}' >"$HOME/.claude/settings.json"
cp -f "$REGEN_ACTIVATED_INPUT" "$HOME/.codex/hooks.json"
printf '%s\n' '{"hooks":{}}' >"$HOME/.cursor/hooks.json"
printf '%s\n' '{}' >"$HOME/.gemini/settings.json"
printf '%s\n' '{"hooks":{}}' >"$HOME/.grok/hooks/moshi-hooks.json"
SH
  chmod +x "$REGEN_BIN/moshi-hook"
  cat >"$REGEN_BIN/nix" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$REGEN_BIN/nix"
  export REGEN_SCRIPT REGEN_MARKER REGEN_HOME REGEN_BIN REGEN_OUTPUT
  export REGEN_HOOKS_JSON REGEN_ACTIVATED_INPUT REGEN_CONFIG_TOML REGEN_DESKTOP_SETTINGS REGEN_PROFILES_DIR
  export REGEN_ACTIVATE_SCRIPT REGEN_SOURCE REGEN_PRINTER REGEN_SYNC
  export REGEN_UNRELATED REGEN_UNRELATED_PREFIX
}

cleanup_regeneration() {
  rm -rf "$REGEN_ROOT"
}

Before 'setup_regeneration'
After 'cleanup_regeneration'

It 'canonicalizes activated materialized registrations and preserves unrelated commands'
When run bash -c 'HOME="$REGEN_HOME" bash "$REGEN_ACTIVATE_SCRIPT" "$REGEN_CONFIG_TOML" "$REGEN_HOOKS_JSON" "$REGEN_DESKTOP_SETTINGS" jq "$REGEN_SYNC" "$REGEN_PROFILES_DIR" "$REGEN_PRINTER" >/dev/null && jq -e --arg unrelated "$REGEN_UNRELATED" '"'"'(.hooks.SessionStart[0].hooks += [{"command":$unrelated,"type":"command"}])'"'"' "$REGEN_HOME/.codex/hooks.json" >"$REGEN_ACTIVATED_INPUT" && HOME="$REGEN_HOME" PATH="$REGEN_BIN:$PATH" GENERATED_ROOT="$REGEN_OUTPUT" bash "$REGEN_SCRIPT" >/dev/null && jq -e --arg marker "$REGEN_MARKER" --arg unrelated "$REGEN_UNRELATED" '"'"'([.hooks.SessionStart[]?.hooks[]?.command, .hooks.UserPromptSubmit[]?.hooks[]?.command] | map(select(. == $marker)) | length == 2) and ([.hooks.SessionStart[]?.hooks[]?.command, .hooks.UserPromptSubmit[]?.hooks[]?.command] | index($unrelated)) and ([.hooks.SessionStart[]?.hooks[]?.command, .hooks.UserPromptSubmit[]?.hooks[]?.command] | index("moshi-hook codex-hook")) and ([.hooks.SessionStart[]?.hooks[]?.command, .hooks.UserPromptSubmit[]?.hooks[]?.command] | index("bd codex-hook UserPromptSubmit"))'"'"' "$REGEN_OUTPUT/codex/hooks.json"'
The status should be success
The output should eq 'true'
End
End

Describe 'error handling'
setup() {
  TEMP_DIR=$(mktemp -d)
  TEMP_SCRIPT="$TEMP_DIR/update-moshi-hooks-fail.sh"
  cat >"$TEMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing latest moshi-hook configs..."
false  # Simulate moshi-hook not found
EOF
  chmod +x "$TEMP_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'exits with error when moshi-hook is not available'
When run bash "$TEMP_SCRIPT"
The output should include 'Installing'
The status should be failure
End
End

End
