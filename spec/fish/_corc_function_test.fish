set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_corc_function.fish

# -- basic: resolves symlink and runs codex remote-control ---------------------
set log1 (mktemp)
set fake_cli (mktemp)
chmod +x $fake_cli
echo '#!/bin/sh
echo "$0" "$@" >> '$log1 >$fake_cli

function which; echo $fake_cli; end
function realpath; echo $argv[1]; end

_corc_function

@test "runs resolved binary directly" (grep -c $fake_cli $log1) -ge 1
@test "passes remote-control subcommand" (grep -c "remote-control" $log1) -ge 1
@test "skips Claude-only worktree spawn flag" (grep -c -- "--spawn" $log1) -eq 0
@test "skips Claude-only permission mode flag" (grep -c -- "--permission-mode" $log1) -eq 0

# -- with args: passes through Codex remote-control args -----------------------
set log2 (mktemp)
echo '#!/bin/sh
echo "$0" "$@" >> '$log2 >$fake_cli

_corc_function --enable remote_control

@test "passes extra args through" (grep -c -- "--enable" $log2) -ge 1
@test "still includes remote-control with args" (grep -c "remote-control" $log2) -ge 1
@test "still skips Claude-only worktree spawn flag" (grep -c -- "--spawn" $log2) -eq 0

rm -f $log1 $log2 $fake_cli
