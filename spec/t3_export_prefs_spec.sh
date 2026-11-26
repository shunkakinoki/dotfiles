#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'scripts/t3-export-prefs.sh'
SCRIPT="$PWD/scripts/t3-export-prefs.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  cat >"$TEMP_DIR/models.json" <<'JSON'
{
  "claude-opus": "claude-opus-5-5",
  "gpt": "gpt-6.1-sol",
  "gpt-sol": "gpt-6.1-sol",
  "gpt-luna": "gpt-6-luna",
  "gemini-neon": "gemini-4-neon",
  "deepseek-flash": "deepseek-v4.1-flash-1017",
  "deepseek-flash-uncensored": "deepseek-v4.1-flash-uncensored"
}
JSON
  cat >"$TEMP_DIR/server-settings.tpl.json" <<'JSON'
{
  "backgroundActivity": {"schemaVersion": 1},
  "favorites": [],
  "providerModelPreferences": {},
  "providerInstances": {
    "claude-cliproxy": {"driver": "claudeAgent"}
  }
}
JSON
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'exports favorites, providerModelPreferences, and model selections with placeholders'
cat >"$TEMP_DIR/settings.json" <<'JSON'
{
  "favorites": [
    {"provider": "claude-cliproxy", "model": "claude-opus-5-5"},
    {"provider": "codex-cliproxy", "model": "gpt-6.2-sol"},
    {"provider": "codex", "model": "gpt-6.1-sol"},
    {"provider": "antigravity", "model": "gemini-4-neon"},
    {"provider": "opencode", "model": "shunkakinoki/deepseek-v4.1-flash-uncensored"},
    {"provider": "opencode", "model": "shunkakinoki/deepseek-v4.1-flash"}
  ],
  "providerModelPreferences": {
    "codex-cliproxy": {
      "hiddenModels": ["gpt-6-luna"],
      "modelOrder": ["gpt-6.2-sol", "gpt-6.1-sol"]
    }
  },
  "defaultModelSelection": {"instanceId": "claude-cliproxy", "model": "claude-opus-5-5"},
  "fallbackModelSelection": {"instanceId": "codex-cliproxy", "model": "gpt-6.2-sol"},
  "textGenerationModelSelection": {"instanceId": "codex-cliproxy", "model": "gpt-6-luna"},
  "reviewGuideModelSelection": {"instanceId": "codex-cliproxy", "model": "gpt-6.1-sol"}
}
JSON
When run bash -c "bash '$SCRIPT' '$TEMP_DIR/settings.json' '$TEMP_DIR/server-settings.tpl.json' '$TEMP_DIR/models.json' >/dev/null && jq -e '.favorites == [{\"provider\": \"claude-cliproxy\", \"model\": \"__CLAUDE_OPUS__\"}, {\"provider\": \"codex-cliproxy\", \"model\": \"gpt-6.2-sol\"}, {\"provider\": \"codex\", \"model\": \"__GPT__\"}, {\"provider\": \"antigravity\", \"model\": \"__GEMINI_NEON__\"}, {\"provider\": \"opencode\", \"model\": \"shunkakinoki/__DEEPSEEK_FLASH_UNCENSORED__\"}, {\"provider\": \"opencode\", \"model\": \"shunkakinoki/__DEEPSEEK_FLASH_UNVERSIONED__\"}] and .providerModelPreferences[\"codex-cliproxy\"].hiddenModels == [\"__GPT_LUNA__\"] and .providerModelPreferences[\"codex-cliproxy\"].modelOrder == [\"gpt-6.2-sol\", \"__GPT__\"] and .defaultModelSelection == {\"instanceId\": \"claude-cliproxy\", \"model\": \"__CLAUDE_OPUS__\"} and .fallbackModelSelection == {\"instanceId\": \"codex-cliproxy\", \"model\": \"gpt-6.2-sol\"} and .textGenerationModelSelection == {\"instanceId\": \"codex-cliproxy\", \"model\": \"__GPT_LUNA__\"} and .reviewGuideModelSelection == {\"instanceId\": \"codex-cliproxy\", \"model\": \"__GPT__\"} and .providerInstances[\"claude-cliproxy\"].driver == \"claudeAgent\"' '$TEMP_DIR/server-settings.tpl.json' >/dev/null"
The status should be success
End

It 'normalizes null providerModelPreferences to an empty object'
cat >"$TEMP_DIR/settings.json" <<'JSON'
{
  "favorites": [],
  "providerModelPreferences": null
}
JSON
When run bash -c "bash '$SCRIPT' '$TEMP_DIR/settings.json' '$TEMP_DIR/server-settings.tpl.json' '$TEMP_DIR/models.json' >/dev/null && jq -e '.favorites == [] and .providerModelPreferences == {}' '$TEMP_DIR/server-settings.tpl.json' >/dev/null"
The status should be success
End

It 'fails cleanly when settings.json is missing'
When run bash "$SCRIPT" "$TEMP_DIR/missing.json" "$TEMP_DIR/server-settings.tpl.json" "$TEMP_DIR/models.json"
The status should be failure
The stderr should include 'settings not found'
End

It 'fails cleanly when settings.json is malformed'
echo 'not json' >"$TEMP_DIR/settings.json"
When run bash "$SCRIPT" "$TEMP_DIR/settings.json" "$TEMP_DIR/server-settings.tpl.json" "$TEMP_DIR/models.json"
The status should be failure
The stderr should include 'not valid JSON'
End
End
