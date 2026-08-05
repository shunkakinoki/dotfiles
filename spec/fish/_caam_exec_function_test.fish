set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish
set -e CAAM_ROTATION_ENABLED

set direct_log (mktemp)
function codex; echo $argv >> $direct_log; end

_caam_exec_function codex exec hello

@test "runs the native executable when rotation is disabled" (cat $direct_log) = "exec hello"

set caam_log (mktemp)
function caam
  echo $argv >> $caam_log
end
set -gx CAAM_ROTATION_ENABLED 1

# fishtape has no TTY, so the non-interactive caam run path is exercised here.
_caam_exec_function codex exec hello

@test "runs vault-backed caam run for non-TTY codex" (tail -n 1 $caam_log) = "run codex --precheck -- exec hello"

_caam_exec_function cursor-agent --print hello

@test "maps cursor-agent to cursor for caam run" (tail -n 1 $caam_log) = "run cursor --precheck -- --print hello"

_caam_exec_function opencode run hello

@test "runs vault-backed caam run for opencode" (tail -n 1 $caam_log) = "run opencode --precheck -- run hello"

# Interactive TTY: only activate when active usage is near the limit.
set direct_env_log (mktemp)
functions -e isatty
function isatty
  test "$argv[1]" = stdout
end
functions -e codex
function codex
  echo $argv >> $direct_env_log
end
set caam_log (mktemp)
set -gx MOCK_ACTIVE_USAGE 10
functions -e caam
function caam
  echo $argv >> $caam_log
  if test "$argv[1]" = precheck
    echo '{"recommended":{"name":"backup@example.com","usage_percent":0},"backups":[{"name":"work@example.com","usage_percent":'$MOCK_ACTIVE_USAGE'}]}'
  else if test "$argv[1]" = ls
    echo '{"profiles":[{"name":"work@example.com","active":true,"system":false,"health":{"status":"warning"}},{"name":"backup@example.com","active":false,"system":false,"health":{"status":"healthy"}}]}'
  end
end

_caam_exec_function codex --dangerously-bypass-approvals-and-sandbox

@test "skips activate on interactive TTY when usage is low" (count (cat $caam_log)) -eq 2
@test "prechecks before interactive TTY launch" (head -n 1 $caam_log) = "precheck codex --format json"
@test "lists profiles before interactive TTY launch" (tail -n 1 $caam_log) = "ls codex --json"
@test "runs codex directly on interactive TTY when usage is low" \
  (cat $direct_env_log) = "--dangerously-bypass-approvals-and-sandbox"

set -gx MOCK_ACTIVE_USAGE 85
set caam_log (mktemp)
set direct_env_log (mktemp)
_caam_exec_function codex --dangerously-bypass-approvals-and-sandbox

@test "activates recommended profile when interactive usage is near limit" \
  (tail -n 1 $caam_log) = "activate codex backup@example.com"
@test "runs codex directly after near-limit activate" \
  (cat $direct_env_log) = "--dangerously-bypass-approvals-and-sandbox"

# Force non-TTY for remaining tests (claude uses caam run when stdout is not a TTY).
functions -e isatty
function isatty; return 1; end
rm -f $direct_env_log
set -e MOCK_ACTIVE_USAGE

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
rm -f $direct_log $caam_log $claude_swap_log
