#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'kyber/find.sh'
SCRIPT="$PWD/named-hosts/kyber/find.sh"

# The wrapper execs the native find it is handed, so a stub prints the argv it
# would have run and keeps the assertions independent of the host's findutils.
# The stub has to be a script rather than a builtin, or findutils flags such as
# --version would be consumed by the stub itself.
setup_stub() {
  STUB="$SHELLSPEC_TMPBASE/native-find"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@"\n' >"$STUB"
  chmod +x "$STUB"
}
BeforeAll 'setup_stub'

guarded_find() {
  HOME=/home/tester bash "$SCRIPT" "$STUB" "$@"
}

Describe 'broad traversal rejection'
It 'rejects the filesystem root'
When run guarded_find /
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects the home directory'
When run guarded_find /home/tester
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a worktree collection without a project segment'
When run guarded_find /home/tester/.herdr/worktrees/dotfiles
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a broad root reached through a relative path'
When run guarded_find /home/tester/ghq/github.com/..
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a broad root hidden behind other roots'
When run guarded_find /home/tester/src /
The status should eq 2
The stderr should include 'narrow the search'
End
End

Describe 'permitted traversal'
It 'allows a project directory'
When run guarded_find /home/tester/ghq/github.com/owner/repo -name '*.ts'
The status should be success
The output should include '/home/tester/ghq/github.com/owner/repo'
End

It 'allows a worktree once it names a project'
When run guarded_find /home/tester/.herdr/worktrees/dotfiles/lane-1
The status should be success
The output should include '/home/tester/.herdr/worktrees/dotfiles/lane-1'
End

It 'allows a broad root bounded by a leading depth limit'
When run guarded_find / -maxdepth 1 -name 'etc'
The status should be success
The output should include '-maxdepth'
End

It 'defaults to the current directory when no root is given'
When run guarded_find -name '*.sh'
The status should be success
The output should include '-name'
End

It 'passes option-only invocations through'
When run guarded_find --version
The status should be success
The output should include '--version'
End
End

Describe 'depth bound integrity'
It 'ignores a depth limit that only appears after a filter'
When run guarded_find / -name 'x' -maxdepth 1
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a depth bound weakened by a second -maxdepth'
When run guarded_find / -maxdepth 1 -name 'x' -maxdepth 9
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects a depth limit deeper than two levels'
When run guarded_find / -maxdepth 3
The status should eq 2
The stderr should include 'narrow the search'
End

It 'rejects reading roots from a file'
When run guarded_find -maxdepth 1 -files0-from roots.txt
The status should eq 2
The stderr should include 'explicit search roots'
End
End

End
