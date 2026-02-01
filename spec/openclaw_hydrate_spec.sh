#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/openclaw/hydrate.sh'
SCRIPT="$PWD/config/openclaw/hydrate.sh"

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
It 'uses ~/.openclaw for state directory'
When run bash -c "grep 'STATE_DIR=' '$SCRIPT'"
The output should include '.openclaw'
End

It 'uses ~/.config/openclaw for secrets'
When run bash -c "grep 'SECRETS_DIR=' '$SCRIPT'"
The output should include '.config/openclaw'
End

It 'keeps legacy ~/.config/clawdbot fallback'
When run bash -c "grep 'LEGACY_SECRETS_DIR=' '$SCRIPT'"
The output should include '.config/clawdbot'
End

It 'reads from dotfiles .env file'
When run bash -c "grep 'ENV_FILE=' '$SCRIPT'"
The output should include 'dotfiles/.env'
End
End

Describe 'secret loading'
It 'loads CLIPROXY_API_KEY from file'
When run bash -c "grep 'CLIPROXY_API_KEY' '$SCRIPT'"
The output should include 'cliproxy-key'
End

It 'loads TELEGRAM_TOKEN from file'
When run bash -c "grep 'TELEGRAM_TOKEN' '$SCRIPT'"
The output should include 'telegram-token'
End

It 'loads GATEWAY_TOKEN from file'
When run bash -c "grep 'GATEWAY_TOKEN' '$SCRIPT'"
The output should include 'gateway-token'
End

It 'loads ANTHROPIC_API_KEY from file'
When run bash -c "grep 'ANTHROPIC_API_KEY' '$SCRIPT'"
The output should include 'anthropic-key'
End
End

Describe 'config generation'
It 'uses sed to substitute values in template'
When run bash -c "grep '@sed@' '$SCRIPT'"
The output should include '@sed@'
End

It 'substitutes CLIPROXY_API_KEY in template'
When run bash -c "grep '__CLIPROXY_API_KEY__' '$SCRIPT'"
The output should include 'CLIPROXY_API_KEY'
End

It 'substitutes TELEGRAM_TOKEN in template'
When run bash -c "grep '__TELEGRAM_TOKEN__' '$SCRIPT'"
The output should include 'TELEGRAM_TOKEN'
End

It 'creates state directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'STATE_DIR'
End
End

Describe 'execution'
It 'exports ANTHROPIC_API_KEY when set'
When run bash -c "grep 'export ANTHROPIC_API_KEY' '$SCRIPT'"
The output should include 'export ANTHROPIC_API_KEY'
End

It 'starts openclaw gateway'
When run bash -c "grep 'exec.*openclaw.*gateway' '$SCRIPT'"
The output should include 'gateway'
End
End

End
