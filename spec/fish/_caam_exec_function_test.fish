set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish

set direct_log (mktemp)
function codex; echo $argv >> $direct_log; end

_caam_exec_function codex exec hello

@test "runs the native executable when rotation is disabled" (cat $direct_log) = "exec hello"

set caam_log (mktemp)
function caam; echo $argv >> $caam_log; end
set -gx CAAM_ROTATION_ENABLED 1

_caam_exec_function codex exec hello

@test "routes through caam precheck when rotation is enabled" (cat $caam_log) = "run codex --precheck -- exec hello"

_caam_exec_function cursor-agent --print hello

@test "maps cursor-agent to the cursor profile" (tail -n 1 $caam_log) = "run cursor --precheck -- --print hello"

set -e CAAM_ROTATION_ENABLED
rm -f $direct_log $caam_log
