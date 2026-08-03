set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish
set -e CAAM_ROTATION_ENABLED

set direct_log (mktemp)
function codex; echo $argv >> $direct_log; end

_caam_exec_function codex exec hello

@test "runs the native executable when rotation is disabled" (cat $direct_log) = "exec hello"

set caam_log (mktemp)
set xdg_log (mktemp)
function caam
  echo $argv >> $caam_log
  if test "$argv[1]" = precheck
    echo '{"recommended":{"name":"work@example.com"}}'
  else if test "$argv[1]" = exec
    echo "$XDG_CONFIG_HOME" >> $xdg_log
  end
end
set -gx CAAM_ROTATION_ENABLED 1

_caam_exec_function codex exec hello

@test "prechecks codex when rotation is enabled" (head -n 1 $caam_log) = "precheck codex --format json"
@test "executes the recommended isolated codex profile" (tail -n 1 $caam_log) = "exec codex work@example.com -- exec hello"

_caam_exec_function cursor-agent --print hello

@test "prechecks cursor-agent as cursor" (tail -n 2 $caam_log | head -n 1) = "precheck cursor --format json"
@test "executes the recommended isolated cursor profile" (tail -n 1 $caam_log) = "exec cursor work@example.com -- --print hello"

_caam_exec_function opencode run hello

@test "prechecks opencode when rotation is enabled" (tail -n 2 $caam_log | head -n 1) = "precheck opencode --format json"
@test "executes the recommended isolated opencode profile" (tail -n 1 $caam_log) = "exec opencode work@example.com -- run hello"
@test "shares the host XDG config with isolated opencode" (tail -n 1 $xdg_log) = "$HOME/.config"

function caam; return 1; end
_caam_exec_function codex exec fallback

@test "falls back to native codex when precheck fails" (tail -n 1 $direct_log) = "exec fallback"

set -e CAAM_ROTATION_ENABLED
rm -f $direct_log $caam_log $xdg_log
