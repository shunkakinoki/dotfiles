set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caxeh_function.fish

set log1 (mktemp)
function cursor-agent; echo $argv >> $log1; end

_caxeh_function hello world

@test "with args uses --print flag" (grep -c -- "--print" $log1) -ge 1
@test "with args uses --force" (grep -c -- "--force" $log1) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log1) -ge 1

rm -f $log1
