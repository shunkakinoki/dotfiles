#!/usr/bin/env bash

Describe 'DSH CLIProxy settings'
PATCH="$PWD/config/dsh/settings.yaml"
TEMPLATE="$PWD/config/dsh/settings.tpl.yaml"

It 'selects DeepSeek Flash as the web profile default'
When run grep -E '^  model: deepseek-v4-flash$' "$PATCH"
The status should be success
The output should include 'model: deepseek-v4-flash'
End

It 'routes the native adapter through remote CLIProxy'
When run bash -c "grep -E '^(  apiKeyEnv: CLIPROXY_API_KEY|  baseURL: https://cliproxy.shunkakinoki.com/v1)$' '$PATCH'"
The status should be success
The output should include 'apiKeyEnv: CLIPROXY_API_KEY'
The output should include 'baseURL: https://cliproxy.shunkakinoki.com/v1'
End

It 'keeps the generated settings aligned with its template'
When run bash -c "diff -u <(sed 's/__DEEPSEEK_FLASH__/deepseek-v4-flash/g' '$TEMPLATE') '$PATCH'"
The status should be success
End

It 'hydrates settings through a merge instead of replacing user state'
When run bash -c "grep -F \".[0] * .[1]\" '$PWD/config/dsh/hydrate.sh'"
The status should be success
The output should include '.[0] * .[1]'
End
End
