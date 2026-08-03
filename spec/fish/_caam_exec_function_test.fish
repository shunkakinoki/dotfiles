set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish

set direct_log (mktemp)
function codex; echo $argv >> $direct_log; end

_caam_exec_function codex exec hello

@test "runs the native executable when rotation is disabled" (cat $direct_log) = "exec hello"

set caam_log (mktemp)
function caam
  echo $argv >> $caam_log
  if test "$argv[1]" = precheck
    echo '{"recommended":{"name":"work@example.com"}}'
  end
end
set -gx CAAM_ROTATION_ENABLED 1

_caam_exec_function codex exec hello

@test "prechecks codex when rotation is enabled" (head -n 1 $caam_log) = "precheck codex --format json"
@test "executes the recommended isolated codex profile" (tail -n 1 $caam_log) = "exec codex work@example.com -- exec hello"

_caam_exec_function cursor-agent --print hello

@test "maps cursor-agent to the cursor profile" (tail -n 1 $caam_log) = "run cursor --precheck -- --print hello"

function caam; return 1; end
_caam_exec_function codex exec fallback

@test "falls back to native codex when precheck fails" (tail -n 1 $direct_log) = "exec fallback"

set -e CAAM_ROTATION_ENABLED
rm -f $direct_log $caam_log
