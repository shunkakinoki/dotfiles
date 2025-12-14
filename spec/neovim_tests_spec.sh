#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'neovim/run_tests.sh'
SCRIPT="$PWD/home-manager/programs/neovim/run_tests.sh"

Describe 'script structure'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses set -e for error handling'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'nvim detection'
It 'checks for nvim command'
When run bash -c "grep 'command -v nvim' '$SCRIPT'"
The output should include 'command -v nvim'
End

It 'shows error when nvim not found'
When run bash -c "grep 'Neovim is not installed' '$SCRIPT'"
The output should include 'Neovim is not installed'
End
End

Describe 'plenary.nvim handling'
It 'uses default PLENARY_DIR'
When run bash -c "grep 'PLENARY_DIR=' '$SCRIPT'"
The output should include '/tmp/plenary.nvim'
End

It 'clones plenary.nvim from GitHub'
When run bash -c "grep 'nvim-lua/plenary.nvim' '$SCRIPT'"
The output should include 'plenary.nvim'
End

It 'uses depth 1 for shallow clone'
When run bash -c "grep -- '--depth 1' '$SCRIPT' 2>&1"
The output should include '--depth 1'
End
End

Describe 'test execution'
It 'runs nvim in headless mode'
When run bash -c "grep -- '--headless' '$SCRIPT' 2>&1"
The output should include '--headless'
End

It 'uses minimal_init.lua'
When run bash -c "grep 'minimal_init.lua' '$SCRIPT'"
The output should include 'minimal_init.lua'
End

It 'runs plenary test harness'
When run bash -c "grep 'plenary.test_harness' '$SCRIPT'"
The output should include 'plenary.test_harness'
End

It 'runs tests in sequential mode'
When run bash -c "grep 'sequential = true' '$SCRIPT'"
The output should include 'sequential = true'
End
End

Describe 'output formatting'
It 'defines RED color'
When run bash -c "grep 'RED=' '$SCRIPT'"
The output should include 'RED='
End

It 'defines GREEN color'
When run bash -c "grep 'GREEN=' '$SCRIPT'"
The output should include 'GREEN='
End

It 'defines YELLOW color'
When run bash -c "grep 'YELLOW=' '$SCRIPT'"
The output should include 'YELLOW='
End

It 'shows success message on pass'
When run bash -c "grep 'All tests passed' '$SCRIPT'"
The output should include 'All tests passed'
End

It 'shows failure message on fail'
When run bash -c "grep 'Tests failed' '$SCRIPT'"
The output should include 'Tests failed'
End
End

Describe 'exit code handling'
It 'captures test exit code'
When run bash -c "grep 'EXIT_CODE=' '$SCRIPT'"
The output should include 'EXIT_CODE='
End

It 'exits with test exit code'
When run bash -c "grep 'exit \$EXIT_CODE' '$SCRIPT'"
The output should include 'exit $EXIT_CODE'
End
End

End
