#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'config/shared/hooks/roborev-agent.sh'
It 'uses the local RoboRev daemon'
When run grep -F '127.0.0.1:7373' "$PWD/config/shared/hooks/roborev-agent.sh"
The output should include '127.0.0.1:7373'
End

Describe 'outside a branch checkout'
HOOK="$PWD/config/shared/hooks/roborev-agent.sh"
setup_detached() {
  FAKE_HOME="$(mktemp -d)"
  REPO="$(mktemp -d)"
  mkdir -p "$FAKE_HOME/.local/bin"
  printf '#!/bin/sh\necho called\n' >"$FAKE_HOME/.local/bin/roborev"
  chmod +x "$FAKE_HOME/.local/bin/roborev"
  git -C "$REPO" init -q -b main
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}
cleanup_detached() { rm -rf "$FAKE_HOME" "$REPO"; }
BeforeEach 'setup_detached'
AfterEach 'cleanup_detached'

run_hook() {
  cd "$REPO" && HOME="$FAKE_HOME" bash "$HOOK" claude </dev/null
}

It 'calls the daemon on a branch'
When run run_hook
The output should equal 'called'
End

It 'skips the daemon on a detached HEAD'
detach_and_run() {
  git -C "$REPO" checkout -q --detach && run_hook
}
When run detach_and_run
The status should be success
The output should equal ''
End

It 'skips the daemon outside a git repository'
run_outside() {
  cd "$FAKE_HOME" && HOME="$FAKE_HOME" GIT_CEILING_DIRECTORIES="$FAKE_HOME/.." bash "$HOOK" claude </dev/null
}
When run run_outside
The status should be success
The output should equal ''
End

It 'skips the daemon inside a bare repository'
run_bare() {
  git init -q --bare -b main "$REPO/bare.git" && cd "$REPO/bare.git" && HOME="$FAKE_HOME" bash "$HOOK" claude </dev/null
}
When run run_bare
The status should be success
The output should equal ''
End
End

Describe 'config/factory/activate-settings.sh'
SCRIPT="$PWD/config/factory/activate-settings.sh"
SETTINGS="$PWD/config/factory/settings.json"

It 'recognizes the managed RoboRev hook'
When run grep -F 'dotfiles/config/shared/hooks/roborev-agent.sh' "$SCRIPT"
The output should include 'dotfiles/config/shared/hooks/roborev-agent.sh'
End

It 'uses Droid Core DeepSeek Flash as the Factory session default'
When run jq -e '.sessionDefaultSettings.model == "deepseek-v4-flash-0731" and any(.customModels[]; .id == "custom:deepseek-v4.1-flash-0" and .baseUrl == "https://cliproxy.shunkakinoki.com/v1" and .apiKey == "CLIPROXY_API_KEY") and any(.customModels[]; .id == "custom:gpt-6-luna-1" and .model == "gpt-6-luna" and .baseUrl == "https://cliproxy.shunkakinoki.com/v1" and .apiKey == "CLIPROXY_API_KEY") and any(.customModels[]; .id == "custom:free-2" and .model == "free" and .baseUrl == "https://cliproxy.shunkakinoki.com/v1" and .apiKey == "CLIPROXY_API_KEY")' "$SETTINGS"
The status should be success
The output should equal 'true'
End

It 'replaces every managed custom model id on merge'
When run grep -F 'map(.id)) as $managed_ids' "$SCRIPT"
The output should include '$managed_ids'
End

It 'drops the retired local Ollama Gemma custom model'
When run grep -F 'custom:gemma3:4b-0' "$SCRIPT"
The output should include 'custom:gemma3:4b-0'
End
End
End
