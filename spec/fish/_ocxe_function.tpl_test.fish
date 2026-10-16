set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caam_exec_function.fish
source $fn/_ocxe_function.tpl.fish

# ── no args: interactive mode ─────────────────────────────
set log1 (mktemp)
function opencode; echo $argv "config=$OPENCODE_CONFIG_CONTENT" >> $log1; end

_ocxe_function

@test "no args seats templated remote CLIProxy model via config env" (grep -c 'config={"model":"shunkakinoki/__DEEPSEEK_FLASH__"}' $log1) -ge 1
@test "no args passes no model flag" (grep -c -- "-m " $log1) -eq 0
@test "no args skips run subcommand" (grep -c "^run " $log1) -eq 0

# ── with args: run mode ──────────────────────────────────
set log2 (mktemp)
function opencode; echo $argv >> $log2; end

_ocxe_function hello world

@test "with args uses run subcommand" (grep -c "^run " $log2) -ge 1
@test "with args builds prompt" (grep -c "hello world" $log2) -ge 1

rm -f $log1 $log2
