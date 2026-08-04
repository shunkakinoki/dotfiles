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

functions -e caam
set claude_swap_log (mktemp)
set -gx MOCK_CLAUDE_HEALTH critical
set -gx CLAUDE_SWAP_FALLBACK_ACCOUNT fallback@example.com
function caam
  echo $argv >> $caam_log
  if test "$argv[1]" = precheck; and test "$argv[2]" = claude
    echo '{"recommended":{"name":"primary@example.com"}}'
  else if test "$argv[1]" = ls; and test "$argv[2]" = claude
    echo '{"profiles":[{"name":"primary@example.com","system":false,"health":{"status":"'$MOCK_CLAUDE_HEALTH'"}}]}'
  end
end
function claude-swap
  echo $argv >> $claude_swap_log
end

_caam_exec_function claude --print fallback

@test "uses isolated claude-swap when CAAM recommends a critical Claude profile" \
  (cat $claude_swap_log) = "run fallback@example.com -- --print fallback"

set -gx MOCK_CLAUDE_HEALTH healthy
_caam_exec_function claude --print primary

@test "keeps CAAM authoritative while its recommended Claude profile is usable" \
  (tail -n 1 $caam_log) = "run claude --precheck -- --print primary"
@test "does not invoke claude-swap for a healthy CAAM profile" \
  (count (cat $claude_swap_log)) -eq 1

set -e CAAM_ROTATION_ENABLED
set -e CLAUDE_SWAP_FALLBACK_ACCOUNT MOCK_CLAUDE_HEALTH
rm -f $direct_log $caam_log $xdg_log $claude_swap_log
