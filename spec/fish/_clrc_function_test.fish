set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_clrc_function.fish

# ── basic: resolves symlink and runs binary with remote-control ──
set log1 (mktemp)
set fake_cli (mktemp)
chmod +x $fake_cli
echo '#!/bin/sh
echo "$0" "$@" >> '$log1 > $fake_cli

function which; echo $fake_cli; end
function realpath; echo $argv[1]; end

_clrc_function

@test "runs resolved binary directly" (grep -c $fake_cli $log1) -ge 1
@test "passes remote-control subcommand" (grep -c "remote-control" $log1) -ge 1
@test "passes --permission-mode auto" (grep -c -- "auto" $log1) -ge 1

# ── with args: passes through extra args ──────────────────────
set log2 (mktemp)
echo '#!/bin/sh
echo "$0" "$@" >> '$log2 > $fake_cli

_clrc_function --name mysession

@test "passes extra args through" (grep -c -- "--name" $log2) -ge 1
@test "still includes remote-control with args" (grep -c "remote-control" $log2) -ge 1
@test "still includes auto with args" (grep -c -- "auto" $log2) -ge 1

rm -f $log1 $log2 $fake_cli
