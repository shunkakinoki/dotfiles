#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/handy/hydrate.sh'
SCRIPT="$PWD/config/handy/hydrate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'inputs'
It 'reads the post-llm-update template'
When run bash -c "grep 'TEMPLATE=' '$SCRIPT'"
The output should include 'settings_store.template.json'
End

It 'sources OPENROUTER_API_KEY from dotfiles .env'
When run bash -c "grep -E 'OPENROUTER_API_KEY|ENV_FILE=' '$SCRIPT'"
The output should include 'OPENROUTER_API_KEY'
The output should include 'dotfiles/.env'
End

It 'substitutes __OPENROUTER_API_KEY__ placeholder via sed'
When run bash -c "grep '__OPENROUTER_API_KEY__' '$SCRIPT'"
The output should include '__OPENROUTER_API_KEY__'
End
End

Describe 'destination'
It 'targets the macOS Application Support path'
When run bash -c "grep -F 'Library/Application Support/com.pais.handy' '$SCRIPT'"
The output should include 'com.pais.handy'
End

It 'targets the Linux XDG_DATA_HOME path'
When run bash -c "grep -F 'XDG_DATA_HOME' '$SCRIPT'"
The output should include 'com.pais.handy'
End
End

Describe 'hydration'
setup_hydrate() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles/config/handy"

  cat >"$TEMP_HOME/dotfiles/config/handy/settings_store.template.json" <<'JSON'
{"settings":{"post_process_api_keys":{"openrouter":"__OPENROUTER_API_KEY__"}}}
JSON

  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OPENROUTER_API_KEY=sk-test-or-key
ENV

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed -e 's|@sed@|sed|g' "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_hydrate() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_hydrate'
After 'cleanup_hydrate'

It 'substitutes the OpenRouter API key into the destination file'
DEST_REL="Library/Application Support/com.pais.handy/settings_store.json"
if [ "$(uname -s)" != "Darwin" ]; then
  DEST_REL=".local/share/com.pais.handy/settings_store.json"
fi
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/'"$DEST_REL"'"'
The status should be success
The output should include 'sk-test-or-key'
The output should not include '__OPENROUTER_API_KEY__'
End
End

End
