#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/kyber/find.sh'
SCRIPT="$PWD/named-hosts/kyber/find.sh"

setup() {
  HOME="$SHELLSPEC_TMPBASE/kyber-find-home"
  mkdir -p "$HOME/ghq/github.com/org/repo" "$HOME/.herdr/worktrees/lane/tree"
  STUB="$SHELLSPEC_TMPBASE/native-find"
  {
    echo '#!/usr/bin/env bash'
    echo 'echo "native-find $*"'
  } >"$STUB"
  chmod +x "$STUB"
}
BeforeEach 'setup'

guard() { bash "$SCRIPT" "$STUB" "$@"; }

Describe 'broad roots'
Parameters
/
/home
/root
End

It "rejects an unbounded traversal of a broad root"
When run guard "$1"
The status should eq 2
The stderr should include 'narrow the search'
End
End

It 'rejects the home directory itself'
When run guard "$HOME"
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects the ghq forge root, which holds every checkout'
When run guard "$HOME/ghq/github.com"
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a worktree lane root, which holds every tree in the lane'
When run guard "$HOME/.herdr/worktrees/lane"
The status should eq 2
The stderr should include 'narrow the search'
End

It 'allows a single worktree below its lane'
When run guard "$HOME/.herdr/worktrees/lane/tree"
The status should be success
The output should include 'native-find'
End

It 'allows a narrow project root'
When run guard "$HOME/ghq/github.com/org/repo" -name '*.nix'
The status should be success
The output should include "-name *.nix"
End

Describe 'depth bounds'
It 'allows a broad root when a leading depth bound keeps it shallow'
When run guard "$HOME" -maxdepth 1 -name '*.log'
The status should be success
The output should include 'native-find'
End

It 'rejects a leading depth bound that is too deep to bound the traversal'
When run guard "$HOME" -maxdepth 3
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a depth bound that does not lead, so a predicate cannot authorize the walk'
When run guard "$HOME" -name '*.log' -maxdepth 1
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a repeated depth bound, since a later one can widen the first'
When run guard "$HOME" -maxdepth 1 -o -maxdepth 9
The status should eq 2
The stderr should include 'narrow the search'
End
End

Describe 'root discovery'
It 'rejects -files0-from, whose roots cannot be checked'
When run guard "$HOME/ghq/github.com/org/repo" -files0-from list
The status should eq 2
The stderr should include 'explicit search roots'
End

It 'skips option arguments when collecting roots'
When run guard -L "$HOME/ghq/github.com/org/repo"
The status should be success
The output should include 'native-find'
End

It 'treats the argument of -D as a flag value, not a root'
When run guard -D tree "$HOME/ghq/github.com/org/repo"
The status should be success
The output should include 'native-find'
End

It 'checks every root, not just the first'
When run guard "$HOME/ghq/github.com/org/repo" "$HOME"
The status should eq 2
The stderr should include 'narrow the search'
End
End

Describe 'passthrough'
It 'forwards --help without a root check'
When run guard --help
The status should be success
The output should include 'native-find --help'
End

It 'forwards --version without a root check'
When run guard --version
The status should be success
The output should include 'native-find --version'
End
End
End
