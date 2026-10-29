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

scan_with_deletion() {
  stat() {
    rm -f "$HOME/Desktop/Screenshot deleted.png"
    command stat "$@"
  }
  export -f stat
  bash "$SCRIPT"
}

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

It 'uses the copier named by CLIPBOARD_COPY_IMAGE'
cat >"$HOME/fast-copy" <<'EOF'
#!/usr/bin/env bash
printf 'fast %s\n' "$1" >>"$HOME/copied"
EOF
chmod +x "$HOME/fast-copy"
touch "$HOME/Desktop/Screenshot new.png"
When call env CLIPBOARD_COPY_IMAGE="$HOME/fast-copy" bash "$SCRIPT"
The status should be success
The result of function copied should eq "fast $HOME/Desktop/Screenshot new.png"
End

It 'fails when clipboard-copy-image is missing'
rm "$HOME/.local/scripts/clipboard-copy-image"
When call bash "$SCRIPT"
The status should be failure
The stderr should include 'clipboard-copy-image not found'
End

It 'ignores a screenshot removed during the directory scan'
touch "$HOME/Desktop/Screenshot deleted.png"
When call scan_with_deletion
The status should be success
The result of function copied should eq ''
End

It 'copies remaining screenshots when another disappears during the scan'
touch "$HOME/Desktop/Screenshot deleted.png" "$HOME/Desktop/Screenshot kept.png"
When call scan_with_deletion
The status should be success
The result of function copied should eq "$HOME/Desktop/Screenshot kept.png"
End

It 'still reports clipboard copy failures'
printf '#!/usr/bin/env bash\nexit 7\n' >"$HOME/.local/scripts/clipboard-copy-image"
touch "$HOME/Desktop/Screenshot new.png"
When call bash "$SCRIPT"
The status should eq 7
End
End
