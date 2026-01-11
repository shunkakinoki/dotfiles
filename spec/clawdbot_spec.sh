#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'clawdbot/extract-secrets.sh'
SCRIPT="$PWD/home-manager/modules/clawdbot/extract-secrets.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'directory configuration'
It 'uses ~/.config/clawdbot for secrets'
When run bash -c "grep 'CLAWDBOT_DIR=' '$SCRIPT'"
The output should include '.config/clawdbot'
End

It 'reads from cliproxyapi auth directory'
When run bash -c "grep 'CLIPROXY_AUTH_DIR=' '$SCRIPT'"
The output should include '.cli-proxy-api/objectstore/auths'
End

It 'reads from dotfiles .env file'
When run bash -c "grep 'DOTFILES_ENV=' '$SCRIPT'"
The output should include 'dotfiles/.env'
End
End

Describe 'directory creation'
It 'creates clawdbot directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'CLAWDBOT_DIR'
End

It 'sets secure permissions on directory'
When run bash -c "grep 'chmod 700' '$SCRIPT'"
The output should include 'CLAWDBOT_DIR'
End
End

Describe 'telegram token extraction'
It 'extracts CLAWDBOT_TELEGRAM_TOKEN from .env'
When run bash -c "grep 'CLAWDBOT_TELEGRAM_TOKEN' '$SCRIPT'"
The output should include 'telegram-token'
End

It 'strips quotes from extracted values'
When run bash -c "grep '@tr@' '$SCRIPT'"
The output should include "-d '\"'"
End
End

Describe 'claude oauth extraction'
It 'finds claude auth JSON file'
When run bash -c "grep 'claude-\*.json' '$SCRIPT'"
The output should include 'CLIPROXY_AUTH_DIR'
End

It 'extracts access_token using jq'
When run bash -c "grep '@jq@' '$SCRIPT'"
The output should include 'access_token'
End

It 'writes to anthropic-key file'
When run bash -c "grep 'anthropic-key' '$SCRIPT'"
The output should include 'CLAWDBOT_DIR'
End
End

Describe 'fallback behavior'
It 'falls back to .env for anthropic key'
When run bash -c "grep 'CLAWDBOT_ANTHROPIC_KEY' '$SCRIPT'"
The output should include 'anthropic-key'
End
End

Describe 'security'
It 'sets secure permissions on secret files'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'CLAWDBOT_DIR'
End
End

End
