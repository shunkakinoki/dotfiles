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
function noctalia
    true
end
function systemctl
    true
end

# ── unknown argument ──────────────────────────────────────
_caf_function bogus >/dev/null 2>&1
@test "unknown argument returns 1" $status = 1

set usage (_caf_function bogus 2>&1)
@test "unknown argument prints usage" (string match -q "*Usage: caf*" "$usage"; echo $status) = 0

# ── status with no keeper running ─────────────────────────
set out (_caf_function status 2>/dev/null)
@test "status reports inactive without pid file" (string match -q "*caf inactive*" "$out"; echo $status) = 0

# ── off with no keeper running ────────────────────────────
_caf_function off >/dev/null 2>&1
@test "off restores normal sleep" $status = 0

rm -rf $tmpdir
