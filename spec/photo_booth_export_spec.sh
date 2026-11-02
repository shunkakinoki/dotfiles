#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'photo-booth-export/export.sh'
SCRIPT="$PWD/home-manager/services/photo-booth-export/export.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  LIBRARY="$TEMP_HOME/Pictures/Photo Booth Library/Pictures"
  mkdir -p "$LIBRARY" "$TEMP_HOME/Desktop"
  export HOME="$TEMP_HOME" XDG_STATE_HOME="$TEMP_HOME/.state"
}
cleanup() {
  rm -rf "$TEMP_HOME"
  unset TEMP_HOME XDG_STATE_HOME
}
Before 'setup'
After 'cleanup'

desktop() { ls -A "$HOME/Desktop"; }

It 'is syntactically valid bash'
When run bash -n "$SCRIPT"
The status should be success
End

It 'does nothing when the library is missing'
rm -rf "$HOME/Pictures"
When run bash "$SCRIPT"
The status should be success
The result of function desktop should eq ''
End

It 'does not export captures that predate the first run'
echo old >"$LIBRARY/Photo on 1-1-26 at 00.00.jpg"
When run bash "$SCRIPT"
The status should be success
The result of function desktop should eq ''
End

It 'exports new photos and movies'
export_new() {
  bash "$SCRIPT"
  echo photo >"$LIBRARY/Photo on 1-1-26 at 00.00.jpg"
  echo movie >"$LIBRARY/Movie on 1-1-26 at 00.01.mov"
  bash "$SCRIPT"
}
When call export_new
The status should be success
The lines of result of function desktop should eq 2
The contents of file "$HOME/Desktop/Movie on 1-1-26 at 00.01.mov" should eq movie
The contents of file "$HOME/Desktop/Photo on 1-1-26 at 00.00.jpg" should eq photo
End

It 'does not restore an export deleted from the Desktop'
export_delete_rerun() {
  bash "$SCRIPT"
  echo photo >"$LIBRARY/Photo.jpg"
  bash "$SCRIPT"
  rm "$HOME/Desktop/Photo.jpg"
  bash "$SCRIPT"
}
When call export_delete_rerun
The status should be success
The result of function desktop should eq ''
End

It 'does not overwrite an existing Desktop file'
export_conflict() {
  bash "$SCRIPT"
  echo mine >"$HOME/Desktop/Photo.jpg"
  echo photo >"$LIBRARY/Photo.jpg"
  bash "$SCRIPT"
}
When call export_conflict
The status should be success
The contents of file "$HOME/Desktop/Photo.jpg" should eq mine
End

It 'retries a file that is still empty on a later run'
export_retry() {
  bash "$SCRIPT"
  : >"$LIBRARY/Movie.mov"
  bash "$SCRIPT"
  echo movie >"$LIBRARY/Movie.mov"
  bash "$SCRIPT"
}
When call export_retry
The status should be success
The contents of file "$HOME/Desktop/Movie.mov" should eq movie
End
End
