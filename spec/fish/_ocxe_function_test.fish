set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish
source $fn/_ocxe_function.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function opencode; echo $argv >> $log1; end

_ocxe_function

@test "no args runs a standalone TUI on the remote CLIProxy model" (grep -c "^--model shunkakinoki/deepseek-v4.1-flash --standalone\$" $log1) -eq 1
@test "no args skips run subcommand" (grep -c "^run " $log1) -eq 0

# ── with args: run mode ──────────────────────────────────
set log2 (mktemp)
function opencode; echo $argv >> $log2; end

_ocxe_function hello world

@test "with args uses run subcommand" (grep -c "^run " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
