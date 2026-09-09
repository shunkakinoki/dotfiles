#!/usr/bin/env bash

Describe 'Herdr pane placement'
It 'preserves recovery scopes and isolates ordinary workers before launch'
When run python3 "$PWD/spec/herdr_pane_scope_test.py"
The status should be success
The stderr should include 'OK'
End
End
