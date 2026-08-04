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

# Interactive TTY path: when stdout is a TTY and the isolated profile dir exists,
# run the binary directly with CODEX_HOME/HOME instead of `caam exec` (which
# wraps stdout and breaks Codex's TUI). fishtape has no TTY, so exercise the
# branch via a fake isatty + temp profile directory.
set fake_xdg (mktemp -d)
set direct_env_log (mktemp)
set -gx XDG_DATA_HOME "$fake_xdg"
mkdir -p "$fake_xdg/caam/profiles/codex/work@example.com/home" \
  "$fake_xdg/caam/profiles/codex/work@example.com/codex_home"
functions -e isatty
function isatty
  test "$argv[1]" = stdout
end
functions -e codex
function codex
  echo "HOME=$HOME" >> $direct_env_log
  echo "CODEX_HOME=$CODEX_HOME" >> $direct_env_log
  echo $argv >> $direct_env_log
end
set caam_log (mktemp)
functions -e caam
function caam
  echo $argv >> $caam_log
  if test "$argv[1]" = precheck
    echo '{"recommended":{"name":"work@example.com"}}'
  end
end

_caam_exec_function codex --dangerously-bypass-approvals-and-sandbox

@test "skips caam exec for interactive TTY codex" (count (cat $caam_log)) -eq 1
@test "prechecks only for interactive TTY codex" (cat $caam_log) = "precheck codex --format json"
@test "runs codex directly with isolated CODEX_HOME on TTY" \
  (grep -c "CODEX_HOME=$fake_xdg/caam/profiles/codex/work@example.com/codex_home" $direct_env_log) -eq 1
@test "runs codex directly with isolated HOME on TTY" \
  (grep -c "HOME=$fake_xdg/caam/profiles/codex/work@example.com/home" $direct_env_log) -eq 1

functions -e isatty
set -e XDG_DATA_HOME
rm -rf $fake_xdg
rm -f $direct_env_log

function caam; return 1; end
functions -e codex
function codex; echo $argv >> $direct_log; end
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
