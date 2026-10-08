#!/usr/bin/env bash

Describe 'CI box warm runner'
SCRIPT="$PWD/home-manager/services/ci-box-warm/run.sh"

It 'discovers a ghq checkout by its CI command'
When run cat "$SCRIPT"
The output should include 'ghq/github.com'
The output should include '"ci:box-warm"'
The output should include 'exec "@bunBin@" run ci:box-warm'
End

It 'fails clearly when no checkout exposes the command'
When run bash -c "sed 's#@gnugrep@/bin/grep#grep#; s#@findutils@/bin/find#find#; s#@bunBin@#bun#' '$SCRIPT' | HOME=\"$(mktemp -d)\" bash"
The status should be failure
The error should include 'could not find a ghq checkout exposing ci:box-warm'
End
End
