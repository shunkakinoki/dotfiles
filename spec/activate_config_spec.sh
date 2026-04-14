#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/codex/activate.sh'
SCRIPT="$PWD/config/codex/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates hooks directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.codex/hooks'
End

It 'copies config.toml with restricted permissions'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'chmod 600'
End

It 'config.toml defaults to never approval policy'
When run bash -c "grep '^approval_policy = \"never\"$' '$PWD/config/codex/config.toml'"
The output should include 'approval_policy = "never"'
End

It 'config.toml defaults to danger-full-access sandbox'
When run bash -c "grep '^sandbox_mode = \"danger-full-access\"$' '$PWD/config/codex/config.toml'"
The output should include 'sandbox_mode = "danger-full-access"'
End

It 'config template defaults to never approval policy'
When run bash -c "grep '^approval_policy = \"never\"$' '$PWD/config/codex/config.tpl.toml'"
The output should include 'approval_policy = "never"'
End

It 'config template defaults to danger-full-access sandbox'
When run bash -c "grep '^sandbox_mode = \"danger-full-access\"$' '$PWD/config/codex/config.tpl.toml'"
The output should include 'sandbox_mode = "danger-full-access"'
End

It 'copies hooks.json'
When run bash -c "grep 'HOOKS_JSON' '$SCRIPT'"
The output should include 'HOOKS_JSON'
End
End

Describe 'config/claude/activate.sh'
SCRIPT="$PWD/config/claude/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates .claude directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.claude'
End

It 'copies settings.json'
When run bash -c "grep 'SETTINGS_JSON' '$SCRIPT'"
The output should include 'SETTINGS_JSON'
End
End

Describe 'config/cursor/activate.sh'
SCRIPT="$PWD/config/cursor/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates .cursor directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.cursor'
End
End

Describe 'config/omp/activate.sh'
SCRIPT="$PWD/config/omp/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates agent and extensions directories'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'extensions'
End

It 'creates swarm-extension symlink'
When run bash -c "grep 'ln -sfn' '$SCRIPT'"
The output should include 'swarm-extension'
End
End

Describe 'config/gemini/activate.sh'
SCRIPT="$PWD/config/gemini/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'only copies if settings.json does not exist'
When run bash -c "grep '! -f' '$SCRIPT'"
The output should include 'settings.json'
End
End

Describe 'config/serena/activate.sh'
SCRIPT="$PWD/config/serena/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'replaces symlinks with real files'
When run bash -c "grep -- '-L' '$SCRIPT'"
The output should include '-L'
End

It 'makes file writable'
When run bash -c "grep 'chmod u+w' '$SCRIPT'"
The output should include 'chmod u+w'
End
End

Describe 'config/git-ai/activate.sh'
SCRIPT="$PWD/config/git-ai/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates .git-ai directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.git-ai'
End

It 'injects git_path via jq'
When run bash -c "grep 'jq' '$SCRIPT'"
The output should include 'git_path'
End
End

Describe 'config/obsidian/activate.sh'
SCRIPT="$PWD/config/obsidian/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'substitutes home directory placeholder'
When run bash -c "grep '__HOME_DIR__' '$SCRIPT'"
The output should include '__HOME_DIR__'
End

It 'creates obsidian config directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'obsidian'
End
End

Describe 'config/obsidian/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/config/obsidian/default.nix"
The output should include '"${config.home.homeDirectory}"'
End
End
