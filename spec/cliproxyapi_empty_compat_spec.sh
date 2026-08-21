#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi empty openai-compatibility entries'
SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/start.sh"

setup_empty_compat() {
  TEMP_COMPAT=$(mktemp -d)
  sed -n '/^cliproxy_drop_empty_compat_providers() {/,/^} # cliproxy_drop_empty_compat_providers$/p' "$SCRIPT" >"$TEMP_COMPAT/filter.sh"
  cat >>"$TEMP_COMPAT/filter.sh" <<'BASH'
cliproxy_drop_empty_compat_providers "$1" "$2"
BASH
  cat >"$TEMP_COMPAT/config.yaml" <<'YAML'
port: 8317
openai-compatibility:
  - name: "openrouter"
    priority: 100
    api-key-entries:
      - api-key: "DUMMY_PASSWORD"
    models:
      - name: "deepseek-v4-flash"
        alias: "deepseek-v4-flash"
  - name: "aliyun"
    priority: 200
    api-key-entries:
      - api-key: ""
    models:
      - name: "deepseek-v4-flash-0731"
        alias: "deepseek-v4-flash"
  - name: "verboo"
    priority: 150
    api-key-entries:
      - api-key: ""
  - name: "opencode"
    priority: 300
    api-key-entries: []
# Official OpenAI compatibility provider reference
# openai-compatibility:
#   - name: "openrouter"
#     api-key-entries:
#       - api-key: "DUMMY_PASSWORD"
routing:
  session-affinity: true
YAML
}

cleanup_empty_compat() {
  rm -rf "$TEMP_COMPAT"
}

Before 'setup_empty_compat'
After 'cleanup_empty_compat'

It 'drops empty-key providers after hydrate so later hops can bind'
When run bash -c "bash '$TEMP_COMPAT/filter.sh' '$TEMP_COMPAT/config.yaml' '$TEMP_COMPAT/out.yaml'; cat '$TEMP_COMPAT/out.yaml'"
The output should include 'name: "openrouter"'
The output should include 'api-key: "DUMMY_PASSWORD"'
The output should include 'session-affinity: true'
The output should include '#   - name: "openrouter"'
The output should not include 'name: "aliyun"'
The output should not include 'name: "verboo"'
The output should not include 'name: "opencode"'
The error should include 'Dropping openai-compatibility provider with empty api-key'
The status should be success
End

It 'invokes the empty-key filter after secret substitution'
When run bash -c "grep -n 'cliproxy_drop_empty_compat_providers \"\$CONFIG\"' '$SCRIPT'"
The output should include 'cliproxy_drop_empty_compat_providers "$CONFIG"'
The status should be success
End
End
