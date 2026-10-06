#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'screenshot-clipboard/copy-latest.sh'
SCRIPT="$PWD/home-manager/services/screenshot-clipboard/copy-latest.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/Desktop" "$TEMP_HOME/.local/scripts"
  cat >"$TEMP_HOME/.local/scripts/clipboard-copy-image" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"$HOME/copied"
EOF
  chmod +x "$TEMP_HOME/.local/scripts/clipboard-copy-image"
  export HOME="$TEMP_HOME" XDG_STATE_HOME="$TEMP_HOME/.state"
}
cleanup() {
  rm -rf "$TEMP_HOME"
  unset TEMP_HOME XDG_STATE_HOME
}
Before 'setup'
After 'cleanup'

copied() { cat "$HOME/copied" 2>/dev/null || true; }

It 'is syntactically valid bash'
When run bash -n "$SCRIPT"
The status should be success
End

It 'copies a fresh top-level screenshot'
touch "$HOME/Desktop/Screenshot new.png"
When call bash "$SCRIPT"
The status should be success
The result of function copied should eq "$HOME/Desktop/Screenshot new.png"
End

It 'copies the same screenshot only once'
touch "$HOME/Desktop/Screenshot new.png"
run_twice() { bash "$SCRIPT" && bash "$SCRIPT"; }
When call run_twice
The status should be success
The result of function copied should eq "$HOME/Desktop/Screenshot new.png"
End

It 'ignores stale screenshots'
touch -t 202001010000 "$HOME/Desktop/Screenshot old.png"
When call bash "$SCRIPT"
The status should be success
The result of function copied should eq ''
End

It 'ignores non-screenshot files'
touch "$HOME/Desktop/notes.png"
When call bash "$SCRIPT"
The status should be success
The result of function copied should eq ''
End

It 'fails when clipboard-copy-image is missing'
rm "$HOME/.local/scripts/clipboard-copy-image"
When call bash "$SCRIPT"
The status should be failure
The stderr should include 'clipboard-copy-image not found'
End
End
