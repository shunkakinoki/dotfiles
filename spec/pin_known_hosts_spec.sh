#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/programs/ssh/pin-known-hosts.sh'
SCRIPT="$PWD/home-manager/programs/ssh/pin-known-hosts.sh"

setup() {
  WORK=$(mktemp -d)
  HOME="$WORK/home"
  export HOME
  mkdir -p "$HOME/.ssh"
  DECLARED="$WORK/declared"
  sed 's|@awk@|awk|g' "$SCRIPT" >"$WORK/pin-known-hosts.sh"
  RUN="$WORK/pin-known-hosts.sh"
}

cleanup() {
  rm -rf "$WORK"
}

BeforeEach 'setup'
AfterEach 'cleanup'

pin() {
  printf '%s\n' "$1" >"$HOME/.ssh/known_hosts"
  printf '%s\n' "$2" >"$DECLARED"
  bash "$RUN" "$DECLARED"
  cat "$HOME/.ssh/known_hosts"
}

It 'replaces a superseded key for a declared host'
When call pin 'matic.example ssh-ed25519 SUPERSEDED' 'matic.example ssh-ed25519 CURRENT'
The output should equal 'matic.example ssh-ed25519 CURRENT'
End

It 'drops a declared host key type the repository no longer declares'
When call pin 'matic.example ecdsa-sha2-nistp256 SUPERSEDED' 'matic.example ssh-ed25519 CURRENT'
The output should equal 'matic.example ssh-ed25519 CURRENT'
End

It 'drops a superseded key listed beside another pattern'
When call pin 'matic.example,203.0.113.7 ssh-ed25519 SUPERSEDED' 'matic.example ssh-ed25519 CURRENT'
The output should equal 'matic.example ssh-ed25519 CURRENT'
End

It 'keeps entries for hosts the repository does not declare'
When call pin 'other.example ssh-ed25519 KEEP' 'matic.example ssh-ed25519 CURRENT'
The line 1 of output should equal 'other.example ssh-ed25519 KEEP'
The line 2 of output should equal 'matic.example ssh-ed25519 CURRENT'
End

pin_twice() {
  printf '%s\n' "$1" >"$HOME/.ssh/known_hosts"
  printf '%s\n' "$2" >"$DECLARED"
  bash "$RUN" "$DECLARED"
  bash "$RUN" "$DECLARED"
  cat "$HOME/.ssh/known_hosts"
}

It 'settles after repeated switches'
When call pin_twice 'matic.example ssh-ed25519 SUPERSEDED' 'matic.example ssh-ed25519 CURRENT'
The output should equal 'matic.example ssh-ed25519 CURRENT'
End
End
