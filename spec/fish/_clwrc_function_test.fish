set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_clwrc_function.fish

# ── basic: resolves symlink and runs node with remote-control --worktree ──
set log1 (mktemp)
set fake_cli (mktemp)

function which; echo $fake_cli; end
function realpath; echo $argv[1]; end
function node; echo "node" $argv >> $log1; end

_clwrc_function

@test "calls node directly (not claude symlink)" (grep -c "^node" $log1) -ge 1
@test "passes remote-control subcommand" (grep -c "remote-control" $log1) -ge 1
@test "passes --worktree flag" (grep -c -- "--worktree" $log1) -ge 1

# ── with args: passes through extra args ──────────────────────
set log2 (mktemp)
function node; echo "node" $argv >> $log2; end

_clwrc_function --name mysession

@test "passes extra args through" (grep -c -- "--name" $log2) -ge 1
@test "still includes remote-control with args" (grep -c "remote-control" $log2) -ge 1
@test "still includes --worktree with args" (grep -c -- "--worktree" $log2) -ge 1

rm -f $log1 $log2 $fake_cli
