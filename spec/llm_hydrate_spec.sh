#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/llm/hydrate.sh'
SCRIPT="$PWD/config/llm/hydrate.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed -e 's|@awk@|awk|g' -e 's|@jq@|jq|g' "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'hydrates the cliproxyapi alias from CLIPROXY_API_KEY'
When run bash -c 'HOME="'"$TEMP_HOME"'" LLM_USER_PATH="'"$TEMP_HOME"'/llm" CLIPROXY_API_KEY="shared-key" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; jq -r .cliproxyapi "'"$TEMP_HOME"'/llm/keys.json"'
The status should be success
The output should equal 'shared-key'
End

It 'prefers an inherited key over the dotenv value'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/dotfiles"; printf '\''CLIPROXY_API_KEY=dotenv-key\n'\'' >"'"$TEMP_HOME"'/dotfiles/.env"; HOME="'"$TEMP_HOME"'" LLM_USER_PATH="'"$TEMP_HOME"'/llm" CLIPROXY_API_KEY="inherited-key" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; jq -r .cliproxyapi "'"$TEMP_HOME"'/llm/keys.json"'
The status should be success
The output should equal 'inherited-key'
End

It 'preserves existing LLM keys'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/llm"; printf '\''{"openai":"existing"}\n'\'' >"'"$TEMP_HOME"'/llm/keys.json"; HOME="'"$TEMP_HOME"'" LLM_USER_PATH="'"$TEMP_HOME"'/llm" CLIPROXY_API_KEY="shared-key" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; jq -r .openai "'"$TEMP_HOME"'/llm/keys.json"'
The status should be success
The output should equal 'existing'
End

It 'leaves a malformed existing keys file unchanged'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/llm"; printf '\''{malformed\n'\'' >"'"$TEMP_HOME"'/llm/keys.json"; HOME="'"$TEMP_HOME"'" LLM_USER_PATH="'"$TEMP_HOME"'/llm" CLIPROXY_API_KEY="shared-key" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/llm/keys.json"'
The status should be success
The output should equal '{malformed'
End

It 'falls back to the CLIProxy config key'
When run bash -c 'mkdir -p "'"$TEMP_HOME"'/.cli-proxy-api"; printf '\''api-keys:\n  - "config-key"\n'\'' >"'"$TEMP_HOME"'/.cli-proxy-api/config.yaml"; HOME="'"$TEMP_HOME"'" LLM_USER_PATH="'"$TEMP_HOME"'/llm" env -u CLIPROXY_API_KEY bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; jq -r .cliproxyapi "'"$TEMP_HOME"'/llm/keys.json"'
The status should be success
The output should equal 'config-key'
End

End
