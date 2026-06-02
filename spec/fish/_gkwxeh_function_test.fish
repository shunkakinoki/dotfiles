set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_gkwxeh_function.fish

set log1 (mktemp)
function grok; echo $argv >> $log1; end

_gkwxeh_function hello world

@test "with args uses --single flag" (grep -c -- "--single" $log1) -ge 1
@test "with args uses --worktree flag" (grep -c -- "--worktree" $log1) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log1) -ge 1

rm -f $log1
