#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/codex/activate.sh'
SCRIPT="$PWD/config/codex/activate.sh"
HOOKS_JSON="$PWD/config/codex/hooks.json"
CONFIG_TOML="$PWD/config/codex/config.toml"
DESKTOP_SETTINGS_JSON="$PWD/config/codex/desktop-settings.json"

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

It 'copies hooks.json'
When run bash -c "grep 'HOOKS_JSON' '$SCRIPT'"
The output should include 'HOOKS_JSON'
End

It 'declares the Codex Desktop Git and worktree preferences'
When run jq -r '[.["git-branch-prefix"], .["git-pull-request-merge-method"], .["git-always-force-push"], .["git-create-pull-request-as-draft"], .["worktree-auto-cleanup-enabled"], .["worktree-keep-count"]] | @tsv' "$DESKTOP_SETTINGS_JSON"
The output should eq 'codex/	squash	true	true	true	300'
End

It 'persists inline review delivery through config.toml'
When run grep -qF 'reviewDelivery = "inline"' "$CONFIG_TOML"
The status should be success
End

It 'merges managed Desktop settings without replacing unrelated state'
TMP_HOME="$(mktemp -d)"
mkdir -p "$TMP_HOME/.codex"
cat >"$TMP_HOME/.codex/.codex-global-state.json" <<'JSON'
{
  "unrelated-top-level": "preserved",
  "electron-persisted-atom-state": {
    "unrelated-setting": 42,
    "git-always-force-push": false
  }
}
JSON

When run bash -c 'HOME="$1" bash "$2" "$3" "$4" "$5" "$6" && jq -r ".[\"unrelated-top-level\"], .[\"electron-persisted-atom-state\"][\"unrelated-setting\"], .[\"electron-persisted-atom-state\"][\"git-always-force-push\"], .[\"electron-persisted-atom-state\"][\"git-pull-request-merge-method\"], .[\"electron-persisted-atom-state\"][\"worktree-keep-count\"]" "$1/.codex/.codex-global-state.json"' _ "$TMP_HOME" "$SCRIPT" "$CONFIG_TOML" "$HOOKS_JSON" "$DESKTOP_SETTINGS_JSON" "$(command -v jq)"
The status should be success
The line 1 should eq 'preserved'
The line 2 should eq '42'
The line 3 should eq 'true'
The line 4 should eq 'squash'
The line 5 should eq '300'
End

It 'registers the shared main/master push blocker'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$HOOKS_JSON"
The output should include 'config/shared/hooks/block-git-push.sh'
End

It 'registers the shared GitHub settings blocker'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$HOOKS_JSON"
The output should include 'config/shared/hooks/block-gh-settings.sh'
End

It 'registers dcg in the Bash pre-tool hook chain'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$HOOKS_JSON"
The output should include 'command -v dcg >/dev/null 2>&1 && dcg'
End
End

Describe 'config/copilot/activate.sh'
SCRIPT="$PWD/config/copilot/activate.sh"
CONFIG_JSON="$PWD/config/copilot/config.json"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates .copilot directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.copilot'
End

It 'registers dcg in the pre-tool hook chain'
When run jq -r '.hooks.preToolUse[].command' "$CONFIG_JSON"
The output should include 'command -v dcg >/dev/null 2>&1 && dcg'
End

It 'registers rtk rewrite in the pre-tool hook chain'
When run jq -r '.hooks.preToolUse[].command' "$CONFIG_JSON"
The output should include '$HOME/dotfiles/config/shared/hooks/rtk-rewrite.sh'
End

It 'registers security in the pre-tool hook chain'
When run jq -r '.hooks.preToolUse[].command' "$CONFIG_JSON"
The output should include '$HOME/dotfiles/config/shared/hooks/security.sh'
End

It 'replaces existing config with the managed config'
TMP_HOME="$(mktemp -d)"
mkdir -p "$TMP_HOME/.copilot"
cat >"$TMP_HOME/.copilot/config.json" <<'JSON'
{
  "banner": "never",
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "command": "existing-hook",
        "timeout": 1
      }
    ]
  }
}
JSON

When run bash -c 'HOME="$1" bash "$2" "$3" && jq -r ".disableAllHooks, (.hooks.preToolUse[].command)" "$1/.copilot/config.json"' _ "$TMP_HOME" "$SCRIPT" "$CONFIG_JSON"
The status should be success
The output should include 'false'
The output should include 'command -v dcg >/dev/null 2>&1 && dcg'
End
End

Describe 'config/copilot/default.nix'
DEFAULT_NIX="$PWD/config/copilot/default.nix"

It 'no longer deploys per-agent rtk-rewrite or security copies (now sourced from shared/hooks)'
When run cat "$DEFAULT_NIX"
The output should not include '.copilot/hooks/rtk-rewrite.sh'
The output should not include '.copilot/hooks/security.sh'
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

Describe 'config/dcg/activate.sh'
SCRIPT="$PWD/config/dcg/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates packs directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.config/dcg/packs'
End

It 'copies config.toml'
When run bash -c "grep 'CONFIG_TOML' '$SCRIPT'"
The output should include 'CONFIG_TOML'
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

Describe 'config/grok/activate.sh'
SCRIPT="$PWD/config/grok/activate.sh"
HOOKS_JSON="$PWD/config/grok/plugin/hooks/hooks.json"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates the .grok directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.grok'
End

It 'copies config.toml'
When run bash -c "grep 'CONFIG_TOML' '$SCRIPT'"
The output should include 'CONFIG_TOML'
End

It 'copies config.toml with restricted permissions'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'chmod 600'
End

It 'installs the security-hook plugin'
When run bash -c "grep 'PLUGIN_DIR' '$SCRIPT'"
The output should include 'PLUGIN_DIR'
End

It 'registers the shared security hook'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash|bash|shell") | .hooks[].command' "$HOOKS_JSON"
The output should include 'config/shared/hooks/security.sh'
End

It 'registers the shared main/master push blocker'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash|bash|shell") | .hooks[].command' "$HOOKS_JSON"
The output should include 'config/shared/hooks/block-git-push.sh'
End

It 'registers the shared GitHub settings blocker'
When run jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash|bash|shell") | .hooks[].command' "$HOOKS_JSON"
The output should include 'config/shared/hooks/block-gh-settings.sh'
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
