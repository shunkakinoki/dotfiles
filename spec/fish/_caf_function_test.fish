set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_caf_function.fish

# Isolate state so the pid file never touches the real HOME.
set tmpdir (mktemp -d)
set -x HOME $tmpdir

# Stub system commands so no real sleep keeper or sudo is invoked.
function uname
    echo Linux
end
function systemd-inhibit
    echo $argv
end
function systemctl
    true
end

# `command -q` resolves external commands, not functions, so provide a real
# `noctalia` on PATH that records its args. This lets us assert the exact v5
# subcommands (`msg caffeine-enable` / `msg caffeine-disable`) so a typo or a
# future IPC rename is caught instead of silently passing.
set -x NOCTALIA_LOG $tmpdir/noctalia.log
mkdir -p $tmpdir/bin
printf '#!/bin/sh\necho "$@" >> "$NOCTALIA_LOG"\n' >$tmpdir/bin/noctalia
chmod +x $tmpdir/bin/noctalia
set -x PATH $tmpdir/bin $PATH

# ── unknown argument ──────────────────────────────────────
_caf_function bogus >/dev/null 2>&1
@test "unknown argument returns 1" $status = 1

set usage (_caf_function bogus 2>&1)
@test "unknown argument prints usage" (string match -q "*Usage: caf*" "$usage"; echo $status) = 0

# ── status with no keeper running ─────────────────────────
set out (_caf_function status 2>/dev/null)
@test "status reports inactive without pid file" (string match -q "*caf inactive*" "$out"; echo $status) = 0

# ── on enables caffeine via the v5 noctalia subcommand ────
_caf_function on >/dev/null 2>&1
@test "on enables caffeine via noctalia" (grep -qF 'msg caffeine-enable' $NOCTALIA_LOG; echo $status) = 0

# ── off with a keeper running ─────────────────────────────
_caf_function off >/dev/null 2>&1
@test "off restores normal sleep" $status = 0
@test "off disables caffeine via noctalia" (grep -qF 'msg caffeine-disable' $NOCTALIA_LOG; echo $status) = 0

rm -rf $tmpdir
