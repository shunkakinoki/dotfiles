set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_coxech_function.fish

# ── with args: prompt taken from argv ─────────────────────
set log1 (mktemp)
function codex; echo $argv >> $log1; end

_coxech_function hello world

@test "with args uses exec subcommand" (grep -c -- " exec " $log1) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log1) -ge 1
@test "with args uses the cliproxy profile" (grep -c -- "--profile cliproxy" $log1) -ge 1
@test "with args keeps experimental reasoning summaries" (grep -c "model_reasoning_summary_format=experimental" $log1) -ge 1
@test "with args includes bypass flag" (grep -c -- "--dangerously-bypass-approvals-and-sandbox" $log1) -ge 1

# ── empty prompt aborts ───────────────────────────────────
set log2 (mktemp)
function codex; echo $argv >> $log2; end

_coxech_function "" 2>/dev/null

@test "an empty prompt does not launch codex" (wc -l < $log2 | string trim) -eq 0

rm -f $log1 $log2
