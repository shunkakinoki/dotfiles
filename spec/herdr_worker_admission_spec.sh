#!/usr/bin/env bash

Describe 'Herdr worker admission'
It 'preserves valid launches and rejects inconsistent or duplicate workers'
When run python3 "$PWD/spec/herdr_worker_admission_test.py"
The status should be success
The stderr should include 'OK'
End
End
