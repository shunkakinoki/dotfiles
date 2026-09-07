set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_cliproxyapi_priority_function.fish

set tmpdir (mktemp -d)
set -x HOME $tmpdir
set auth_dir $tmpdir/.cli-proxy-api/objectstore/auths
mkdir -p $auth_dir

# ── missing auth dir ──────────────────────────────────────
set -x HOME $tmpdir/absent
_cliproxyapi_priority_function >/dev/null 2>&1
@test "missing auth dir returns 1" $status = 1
set -x HOME $tmpdir

# ── argument validation ───────────────────────────────────
_cliproxyapi_priority_function abc >/dev/null 2>&1
@test "non-numeric priority returns 1" $status = 1

_cliproxyapi_priority_function 300 400 >/dev/null 2>&1
@test "extra arguments return 1" $status = 1

# ── empty auth dir ────────────────────────────────────────
_cliproxyapi_priority_function >/dev/null 2>&1
@test "empty auth dir succeeds" $status = 0

# ── bumps unset and zero priorities ───────────────────────
echo '{"provider":"codex","account":"a@example.com","priority":0}' >$auth_dir/codex-zero.json
echo '{"provider":"claude","account":"b@example.com"}' >$auth_dir/claude-unset.json
echo '{"provider":"gemini","account":"c@example.com","priority":300}' >$auth_dir/gemini-set.json

_cliproxyapi_priority_function >/dev/null 2>&1
@test "sweep succeeds" $status = 0
@test "zero priority is bumped" (jq -r .priority $auth_dir/codex-zero.json) = 300
@test "missing priority is added" (jq -r .priority $auth_dir/claude-unset.json) = 300
@test "already-set priority is kept" (jq -r .priority $auth_dir/gemini-set.json) = 300

# ── other credential fields survive the rewrite ───────────
@test "account field is preserved" (jq -r .account $auth_dir/codex-zero.json) = a@example.com
@test "provider field is preserved" (jq -r .provider $auth_dir/claude-unset.json) = claude

# ── explicit priority argument ────────────────────────────
_cliproxyapi_priority_function 150 >/dev/null 2>&1
@test "explicit priority is applied" (jq -r .priority $auth_dir/codex-zero.json) = 150

# ── unparseable credential is reported, not silently skipped ─
echo 'not json' >$auth_dir/broken.json
_cliproxyapi_priority_function >/dev/null 2>&1
@test "unparseable credential returns 1" $status = 1
@test "valid credentials still patched alongside a broken one" (jq -r .priority $auth_dir/codex-zero.json) = 300

rm -rf $tmpdir
